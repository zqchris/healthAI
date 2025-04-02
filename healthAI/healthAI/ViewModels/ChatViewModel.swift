import Foundation
import Combine
import SwiftUI

// 引入 HealthKit 相关
import HealthKit

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
    
    // 添加 HealthKitManager
    private let healthKitManager = HealthKitManager()
    // 存储获取到的健康数据 System Prompt
    private var healthDataSystemPrompt: String? = nil

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

        // ViewModel 初始化时，尝试获取健康数据
        Task {
            await fetchAndPrepareHealthData()
        }
    }
    
    // 加载保存的设置
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
        
        // 准备发送给 API 的消息
        var apiMessages = [ChatMessage]()
        
        // 检查是否需要添加健康数据 System Prompt
        if let healthPrompt = healthDataSystemPrompt, !healthPrompt.isEmpty {
            // 如果消息历史中还没有包含健康数据的 System Prompt，则添加
            let hasHealthPrompt = messages.contains(where: { 
                $0.role == .system && $0.content.contains("健康数据")
            })
            
            if !hasHealthPrompt {
                apiMessages.append(ChatMessage(role: .system, content: healthPrompt))
            }
        }
        
        // 添加历史消息
        apiMessages.append(contentsOf: messages)
        
        // 在开始AI回复前，先创建AI响应的消息占位符
        let responseId = UUID()
        let assistantMessage = ChatMessage(id: responseId, role: .assistant, content: "")
        messages.append(assistantMessage)
        
        // 发送API请求
        chatService.sendStreamingChatRequest(
            messages: apiMessages,
            onReceive: { [weak self] newContent in
                guard let self = self else { return }
                self.currentResponse += newContent
                
                // 查找并更新已存在的AI回复消息，避免创建新的气泡
                if let index = self.messages.firstIndex(where: { $0.id == responseId }) {
                    let updatedMessage = ChatMessage(id: responseId, role: .assistant, content: self.currentResponse, timestamp: self.messages[index].timestamp)
                    self.messages[index] = updatedMessage
                }
            },
            onComplete: { [weak self] in
                guard let self = self else { return }
                self.isTyping = false
                
                // 检查AI是否有回复内容
                if self.currentResponse.isEmpty {
                    // 如果没有回复内容且没有已知错误，显示一个通用错误
                    if self.errorMessage == nil {
                        self.errorMessage = "无法从API获取响应，请检查您的API设置和网络连接。"
                    }
                    
                    // 移除空的回复消息
                    if let index = self.messages.firstIndex(where: { $0.id == responseId }) {
                        self.messages.remove(at: index)
                    }
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
 
    // 获取并准备健康数据的方法
    func fetchAndPrepareHealthData() async {
        print("ChatViewModel: 开始准备健康数据...")
        
        // 捕获所有可能的异常
        do {
            // 请求授权时添加更详细的错误处理
            var authorizationSuccess = false
            var authorizationError: Error? = nil
            
            // 使用信号量等待同步结果
            let semaphore = DispatchSemaphore(value: 0)
            
            // 请求健康数据访问权限
            DispatchQueue.global().async { [weak self] in
                guard let self = self else {
                    print("ChatViewModel: self 已被释放")
                    semaphore.signal()
                    return
                }
                
                print("ChatViewModel: 正在请求 HealthKit 授权...")
                self.healthKitManager.requestAuthorization { success, error in
                    authorizationSuccess = success
                    authorizationError = error
                    semaphore.signal()
                }
            }
            
            // 等待授权结果（最多5秒）
            if semaphore.wait(timeout: .now() + 5) == .timedOut {
                print("ChatViewModel: 授权请求超时")
                // 即使超时也继续，可能已经获得授权
            }
            
            if let error = authorizationError {
                print("ChatViewModel: 健康数据授权失败: \(error.localizedDescription)")
                // 仍然继续，可能是用户此前已授权
            }
            
            // 即使授权失败，也尝试获取数据（可能用户此前已授权）
            print("ChatViewModel: 尝试获取健康数据...")
            
            do {
                let healthSummary = try await self.healthKitManager.fetchHealthData()
                print("ChatViewModel: 成功获取健康数据")
                
                // 格式化数据并存储
                let prompt = self.healthKitManager.formatHealthDataForPrompt(summary: healthSummary)
                
                // 使用线程安全的方式更新系统提示
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.healthDataSystemPrompt = prompt
                    print("ChatViewModel: 已更新健康数据 System Prompt (长度: \(prompt.count)字符)")
                    
                    // 在UI中显示数据已加载的提示（如果界面上还没有消息）
                    if self.messages.filter({ $0.role != .system }).isEmpty {
                        let infoMessage = ChatMessage(role: .assistant, content: "已加载您的健康数据，您可以开始提问了。")
                        self.messages.append(infoMessage)
                    }
                }
            } catch {
                print("ChatViewModel: 获取健康数据时出错: \(error.localizedDescription)")
                // 即使获取数据失败，应用也应继续工作
                DispatchQueue.main.async { [weak self] in
                    // 显示一个温和的错误提示，而不是阻止应用继续
                    self?.errorMessage = "无法获取健康数据，但您仍然可以使用其他功能。"
                    
                    // 3秒后自动清除错误消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.errorMessage = nil
                    }
                }
            }
        } catch {
            print("ChatViewModel: 处理健康数据过程中出现未捕获的错误: \(error)")
            // 即使出错，应用也应继续工作
        }
    }
} 