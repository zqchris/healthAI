import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputMessage: String = ""
    @Published var isTyping: Bool = false
    @Published var apiConfig: GPTAPIConfig = GPTAPIConfig.defaultConfig
    @Published var currentResponse: String = ""
    @Published var showSettings: Bool = false
    @Published var errorMessage: String?
    @Published var apiType: String = "openai" // 默认为OpenAI
    
    private var chatService: ChatService
    private var cancellables = Set<AnyCancellable>()
    
    init(chatService: ChatService = ChatService()) {
        self.chatService = chatService
        // 初始系统消息设置
        loadSavedSettings()
        
        // 添加系统消息
        addSystemMessage("你是一个健康AI助手，你可以帮助用户解答健康相关的问题，给出科学的健康建议。")
        
        // 监听服务错误
        chatService.$error
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error.localizedDescription
            }
            .store(in: &cancellables)
    }
    
    private func loadSavedSettings() {
        if UserDefaults.standard.string(forKey: "api_key") != nil {
            let savedKey = UserDefaults.standard.string(forKey: "api_key") ?? ""
            let savedBaseURL = UserDefaults.standard.string(forKey: "base_url") ?? "https://api.openai.com/v1/chat/completions"
            let savedOrg = UserDefaults.standard.string(forKey: "organization")
            let savedType = UserDefaults.standard.string(forKey: "api_type") ?? "openai"
            
            // 使用存储的API类型，不再自动判断
            apiType = savedType
            
            if apiType == "anthropic" {
                apiConfig = GPTAPIConfig(
                    apiKey: savedKey,
                    model: "claude-3-opus-20240229",
                    baseURL: savedBaseURL,
                    organization: savedOrg
                )
            } else {
                apiConfig = GPTAPIConfig(
                    apiKey: savedKey,
                    model: "gpt-4o",
                    baseURL: savedBaseURL,
                    organization: savedOrg
                )
            }
            
            // 传递当前API类型
            chatService.updateConfig(apiConfig: apiConfig, apiType: apiType)
        }
    }
    
    // 发送消息
    func sendMessage() {
        guard !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 清除之前的错误
        errorMessage = nil
        
        let userMessage = ChatMessage(role: .user, content: inputMessage)
        messages.append(userMessage)
        
        // 清空输入并开始响应
        let userInput = inputMessage
        inputMessage = ""
        isTyping = true
        currentResponse = ""
        
        // 创建初始的AI响应消息
        let assistantMessage = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)
        
        // 发送API请求
        chatService.sendStreamingChatRequest(
            messages: self.messages.filter { $0.role != .assistant || $0.content.count > 0 },
            onReceive: { [weak self] newContent in
                guard let self = self else { return }
                self.currentResponse += newContent
                
                // 更新最后一条消息的内容
                if var lastMessage = self.messages.last, lastMessage.role == .assistant {
                    let updatedMessage = ChatMessage(id: lastMessage.id, role: .assistant, content: self.currentResponse, timestamp: lastMessage.timestamp)
                    if let index = self.messages.lastIndex(where: { $0.id == lastMessage.id }) {
                        self.messages[index] = updatedMessage
                    }
                }
            },
            onComplete: { [weak self] in
                guard let self = self else { return }
                self.isTyping = false
                
                // 如果没有收到任何内容但没有错误，显示一个通用错误
                if self.currentResponse.isEmpty && self.messages.last?.content.isEmpty == true && self.errorMessage == nil {
                    self.errorMessage = "无法从API获取响应，请检查您的API设置和网络连接。"
                }
            }
        )
    }
    
    // 添加系统消息
    private func addSystemMessage(_ content: String) {
        let systemMessage = ChatMessage(role: .system, content: content)
        messages.append(systemMessage)
    }
    
    // 更新API类型
    func updateAPIType(_ type: String) {
        apiType = type
        
        // 根据类型更新模型和URL
        if type == "anthropic" {
            apiConfig.model = "claude-3-opus-20240229"
            if !apiConfig.baseURL.contains("anthropic") {
                apiConfig.baseURL = "https://api.anthropic.com/v1/messages"
            }
        } else {
            apiConfig.model = "gpt-4o"
            if !apiConfig.baseURL.contains("openai") {
                apiConfig.baseURL = "https://api.openai.com/v1/chat/completions"
            }
        }
    }
    
    // 保存API设置
    func saveAPISettings() {
        // 根据apiType设置正确的模型
        if apiType == "anthropic" {
            apiConfig.model = "claude-3-opus-20240229"
        } else {
            apiConfig.model = "gpt-4o"
        }
        
        // 传递apiType到ChatService
        chatService.updateConfig(apiConfig: apiConfig, apiType: apiType)
        
        // 保存到UserDefaults
        UserDefaults.standard.set(apiConfig.apiKey, forKey: "api_key")
        UserDefaults.standard.set(apiConfig.model, forKey: "model")
        UserDefaults.standard.set(apiConfig.baseURL, forKey: "base_url")
        UserDefaults.standard.set(apiConfig.organization, forKey: "organization")
        UserDefaults.standard.set(apiType, forKey: "api_type")
        
        // 关闭设置页面
        showSettings = false
    }
    
    // 清空聊天记录
    func clearChat() {
        // 保留系统消息
        let systemMessages = messages.filter { $0.role == .system }
        messages = systemMessages
        currentResponse = ""
        errorMessage = nil
    }
} 