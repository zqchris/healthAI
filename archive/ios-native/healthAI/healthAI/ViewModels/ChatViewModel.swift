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
    
    // Add state for suggested questions
    @Published var suggestedQuestions: [String] = ["帮我分析健康数据", "如何改善睡眠质量？"] // Default questions
    
    private var chatService: ChatService
    private var cancellables = Set<AnyCancellable>()
    
    // 添加 HealthKitManager
    private let healthKitManager = HealthKitManager()
    // 存储获取到的健康数据 System Prompt
    private var healthDataSystemPrompt: String? = nil

    // Observe HealthDataService for summary updates
    @ObservedObject private var healthDataService = HealthDataService.shared

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

        // Add initial welcome message if chat is empty
        if messages.filter({ $0.role != .system }).isEmpty {
            if apiConfig.apiKey.isEmpty {
                messages.append(ChatMessage(role: .assistant, content: "API密钥未设置，请在设置中配置您的API密钥。配置完成后，您可以开始提问。"))
                errorMessage = "API密钥未设置，请在设置中配置您的API密钥"
            } else {
                messages.append(ChatMessage(role: .assistant, content: "已加载您的健康数据，您可以开始提问了。"))
            }
        }
        
        // Observe health summary changes
        observeHealthSummary()
    }
    
    // 加载保存的设置
    private func loadSavedSettings() {
        let savedKey = UserDefaults.standard.string(forKey: "api_key") ?? ""
        let savedBaseURL = UserDefaults.standard.string(forKey: "base_url") ?? "https://api.openai.com/v1/chat/completions"
        let savedOrg = UserDefaults.standard.string(forKey: "organization")
        let savedType = UserDefaults.standard.string(forKey: "api_type") ?? "openai"
        
        print("加载API设置 - API Key: \(savedKey.isEmpty ? "未设置" : "已设置"), 类型: \(savedType)")
        
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
    
    // 发送消息
    func sendMessage() {
        guard !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 清除之前的错误
        errorMessage = nil
        
        // 创建用户消息并使用当前时间作为时间戳
        let userMessageTimestamp = Date()
        let userMessage = ChatMessage(role: .user, content: inputMessage, timestamp: userMessageTimestamp)
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
        
        // 移除预设的时间戳，使用实际接收响应时的时间
        
        // 发送API请求
        chatService.sendStreamingChatRequest(
            messages: apiMessages,
            onReceive: { [weak self] newContent in
                guard let self = self else { return }
                
                // 使用打字机效果更新响应，使用实际的时间戳
                self.processIncomingResponse(newContent)
            },
            onComplete: { [weak self] in
                guard let self = self else { return }
                self.isTyping = false
                
                // 检查AI是否有回复内容
                if self.currentResponse.isEmpty && self.errorMessage == nil {
                    // 如果没有回复内容且没有已知错误，显示一个通用错误
                    self.errorMessage = "无法从API获取响应，请检查您的API设置和网络连接。"
                }
            }
        )
    }
    
    // 修改处理打字机效果的方法，确保安全更新消息内容，并使用实际时间戳
    private func processIncomingResponse(_ newContent: String) {
        DispatchQueue.main.async {
            // 更新当前累积的响应
            self.currentResponse += newContent
            
            // 按照时间戳从后向前查找最后一条AI消息
            let sortedMessages = self.messages.sorted(by: { $0.timestamp < $1.timestamp })
            if let lastIndex = sortedMessages.lastIndex(where: { $0.role == .assistant }) {
                // 找到对应的真实索引
                if let realIndex = self.messages.firstIndex(where: { $0.id == sortedMessages[lastIndex].id }) {
                    // 安全地更新现有消息
                    self.messages[realIndex].content = self.currentResponse
                    
                    // 重要：确保AI响应时间戳总是在最后一条用户消息之后
                    if let lastUserMessage = self.messages.filter({ $0.role == .user }).sorted(by: { $0.timestamp < $1.timestamp }).last {
                        // 确保AI响应时间总是比最后一条用户消息晚至少1秒
                        let currentTime = Date()
                        let userTime = lastUserMessage.timestamp
                        // 如果当前时间早于或等于用户消息时间，设置为用户消息时间+1秒
                        if currentTime <= userTime {
                            self.messages[realIndex].timestamp = userTime.addingTimeInterval(1)
                        } else {
                            self.messages[realIndex].timestamp = currentTime
                        }
                    }
                }
            } else {
                // 如果没有已有的AI回复消息，创建一个新的
                // 重要：确保时间戳总是在最后一条用户消息之后
                var timestamp = Date()
                if let lastUserMessage = self.messages.filter({ $0.role == .user }).sorted(by: { $0.timestamp < $1.timestamp }).last {
                    // 如果当前时间早于或等于用户消息时间，设置为用户消息时间+1秒
                    if timestamp <= lastUserMessage.timestamp {
                        timestamp = lastUserMessage.timestamp.addingTimeInterval(1)
                    }
                }
                
                let assistantMessage = ChatMessage(role: .assistant, content: self.currentResponse, timestamp: timestamp)
                self.messages.append(assistantMessage)
                
                print("消息时间戳 - 用户: \(self.messages.filter { $0.role == .user }.last?.timestamp ?? Date()) - AI: \(assistantMessage.timestamp)")
            }
        }
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

    // Function to observe health summary
    private func observeHealthSummary() {
        healthDataService.$healthSummary
            .receive(on: DispatchQueue.main)
            .sink { [weak self] summary in
                guard let self = self, let summary = summary else { return }
                // Trigger generation when summary is available/updated
                Task {
                    await self.generateSuggestedQuestions(summary: summary)
                }
            }
            .store(in: &cancellables)
            
        // Also fetch initially if summary already exists
        if let initialSummary = healthDataService.healthSummary {
             Task {
                 await self.generateSuggestedQuestions(summary: initialSummary)
             }
        }
    }

    // Function to generate suggested questions (Implementation needed)
    private func generateSuggestedQuestions(summary: HealthDataSummary) async {
        print("Health summary updated, attempting to generate suggested questions...")
        // 1. Format prompt using summary data (e.g., score, steps, sleep)
        //    Keep the prompt concise but informative.
        let prompt = formatSuggestionPrompt(summary: summary)
        
        // 2. Call ChatService (needs a new method)
        do {
            // TODO: Implement chatService.fetchSuggestedQuestions
             let questions = try await chatService.fetchSuggestedQuestions(prompt: prompt)
            // Ensure questions are not empty and update
             if !questions.isEmpty {
                 // Limit to 3-4 questions for UI neatness
                 self.suggestedQuestions = Array(questions.prefix(4))
                 print("Suggested questions updated: \\(self.suggestedQuestions)")
             } else {
                 print("AI returned empty suggestions.")
                 // Keep default or fallback questions if needed
                 // self.suggestedQuestions = ["Default question 1", "Default question 2"]
             }
        } catch {
            print("Error fetching suggested questions: \\(error.localizedDescription)")
            // Handle error - maybe keep default questions or show an error indicator?
            // For now, just keep the existing/default ones
        }
    }
    
    // Helper to format the prompt for the AI
    private func formatSuggestionPrompt(summary: HealthDataSummary) -> String {
        // Extract key metrics - handle nil values gracefully
        let score = HealthDataService.shared.calculateHealthScore(from: summary) // Recalculate or get score
        
        // Safely calculate average steps, making avgSteps optional
        let avgSteps: Double? = {
            guard let dailySteps = summary.dailySteps, !dailySteps.isEmpty else {
                return nil
            }
            let totalSteps = dailySteps.values.reduce(0, +)
            let count = Double(dailySteps.count)
            return totalSteps / count
        }()
        
        let avgSleepHours = (summary.averageSleepDuration ?? 0) / 3600
        
        var summaryText = "用户健康数据摘要：\\n"
        summaryText += "- 健康评分: \\(score)/100\\n"
        if let avgSteps = avgSteps, avgSteps > 0 {
             summaryText += "- 平均步数: \\(Int(avgSteps)) 步/天\\n"
        }
        if avgSleepHours > 0 {
             summaryText += "- 平均睡眠: \\(String(format: \"%.1f\", avgSleepHours)) 小时/天\\n"
        }
        if let avgHr = summary.averageHeartRate {
            summaryText += "- 平均心率: \\(Int(avgHr)) 次/分钟\\n"
        }
        
        // Add more key data points if desired...
        
        summaryText += "\\n根据以上数据，为用户生成3-4个简短的、可以直接点击提问的建议（例如：'如何提高我的步数？' 或 '我的睡眠质量怎么样？'）。请直接返回问题列表，每个问题占一行，不要添加任何其他说明文字。"
        
        return summaryText
    }
} 