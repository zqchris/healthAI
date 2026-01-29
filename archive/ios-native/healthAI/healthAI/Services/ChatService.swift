import Foundation
import Combine

class ChatService: ObservableObject {
    private var apiConfig: GPTAPIConfig
    private var cancellables = Set<AnyCancellable>()
    private var forcedAPIType: String = "openai" // 默认使用OpenAI
    
    @Published var isLoading = false
    @Published var error: Error?
    
    init(apiConfig: GPTAPIConfig = GPTAPIConfig.defaultConfig) {
        self.apiConfig = apiConfig
    }
    
    // 更新API配置
    func updateConfig(apiConfig: GPTAPIConfig, apiType: String = "openai") {
        self.apiConfig = apiConfig
        self.forcedAPIType = apiType
    }
    
    // 判断是否使用Anthropic API - 现在只依赖明确设置的APIType
    private var isAnthropicAPI: Bool {
        return forcedAPIType == "anthropic" || apiConfig.baseURL.contains("anthropic.com")
    }
    
    // 发送聊天请求并获取流式响应
    func sendStreamingChatRequest(messages: [ChatMessage], onReceive: @escaping (String) -> Void, onComplete: @escaping () -> Void) {
        guard !apiConfig.apiKey.isEmpty else {
            self.error = NSError(domain: "ChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API密钥未设置，请在设置中配置您的API密钥"])
            onComplete()
            return
        }
        
        isLoading = true
        error = nil
        
        // 根据API类型准备请求
        if isAnthropicAPI {
            sendAnthropicStreamingRequest(messages: messages, onReceive: onReceive, onComplete: onComplete)
        } else {
            sendOpenAIStreamingRequest(messages: messages, onReceive: onReceive, onComplete: onComplete)
        }
    }
    
    // OpenAI流式请求
    private func sendOpenAIStreamingRequest(messages: [ChatMessage], onReceive: @escaping (String) -> Void, onComplete: @escaping () -> Void) {
        // 准备请求数据
        let requestMessages = messages.map { ChatCompletionRequest.ChatRequestMessage(role: $0.role.rawValue, content: $0.content) }
        
        let request = ChatCompletionRequest(
            model: apiConfig.model,
            messages: requestMessages,
            stream: true,
            temperature: 1.0,
            max_tokens: 2048,
            top_p: 1.0
        )
        
        guard let url = URL(string: apiConfig.baseURL) else {
            self.error = NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的API URL"])
            isLoading = false
            onComplete()
            return
        }
        
        guard let jsonData = try? JSONEncoder().encode(request) else {
            self.error = NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无法编码请求数据"])
            isLoading = false
            onComplete()
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiConfig.apiKey)", forHTTPHeaderField: "Authorization")
        
        if let organization = apiConfig.organization, !organization.isEmpty {
            urlRequest.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        urlRequest.httpBody = jsonData
        
        // 打印部分请求信息(隐藏完整key)
        let apiKeyPrefix = String(apiConfig.apiKey.prefix(min(10, apiConfig.apiKey.count))) + "..."
        print("[OpenAI] 发送API请求到: \(url.absoluteString)")
        print("[OpenAI] 使用API密钥前缀: \(apiKeyPrefix)")
        
        performAPIRequest(urlRequest: urlRequest, onReceive: onReceive, onComplete: onComplete)
    }
    
    // Anthropic/Claude流式请求
    private func sendAnthropicStreamingRequest(messages: [ChatMessage], onReceive: @escaping (String) -> Void, onComplete: @escaping () -> Void) {
        // 提取系统消息
        let systemMessage = messages.first { $0.role == .system }?.content
        
        // 准备Claude消息格式
        var claudeMessages: [ClaudeCompletionRequest.ClaudeMessage] = []
        
        for message in messages.filter({ $0.role != .system }) {
            // 转换消息到Claude格式
            let contentBlock = ClaudeCompletionRequest.ContentBlock(type: "text", text: message.content)
            let claudeRole = message.role == .user ? "user" : "assistant"
            let claudeMessage = ClaudeCompletionRequest.ClaudeMessage(role: claudeRole, content: [contentBlock])
            claudeMessages.append(claudeMessage)
        }
        
        let request = ClaudeCompletionRequest(
            model: apiConfig.model,
            messages: claudeMessages,
            max_tokens: 2048,
            stream: true,
            temperature: 1.0,
            system: systemMessage
        )
        
        guard let url = URL(string: apiConfig.baseURL) else {
            self.error = NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的API URL"])
            isLoading = false
            onComplete()
            return
        }
        
        guard let jsonData = try? JSONEncoder().encode(request) else {
            self.error = NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无法编码请求数据"])
            isLoading = false
            onComplete()
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("\(apiConfig.apiKey)", forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        urlRequest.httpBody = jsonData
        
        // 打印部分请求信息(隐藏完整key)
        let apiKeyPrefix = String(apiConfig.apiKey.prefix(min(10, apiConfig.apiKey.count))) + "..."
        print("[Claude] 发送API请求到: \(url.absoluteString)")
        print("[Claude] 使用API密钥前缀: \(apiKeyPrefix)")
        
        performAPIRequest(urlRequest: urlRequest, onReceive: onReceive, onComplete: onComplete)
    }
    
    // 执行API请求
    private func performAPIRequest(urlRequest: URLRequest, onReceive: @escaping (String) -> Void, onComplete: @escaping () -> Void) {
        let session = URLSession.shared
        
        let task = session.dataTask(with: urlRequest) { [weak self] data, response, error in
            defer { 
                DispatchQueue.main.async {
                    self?.isLoading = false 
                    onComplete()
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self?.error = error
                    print("API请求错误: \(error.localizedDescription)")
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self?.error = NSError(domain: "ChatService", code: 0, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"])
                }
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    if let data = data, let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // 处理不同的错误格式
                        if let errorMessage = errorResponse["error"] as? [String: Any],
                           let message = errorMessage["message"] as? String {
                            self?.error = NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
                        } else if let errorString = errorResponse["error"] as? String {
                            self?.error = NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorString])
                        } else {
                            self?.error = NSError(domain: "ChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API返回错误: \(httpResponse.statusCode)"])
                        }
                    } else {
                        self?.error = NSError(domain: "ChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP错误: \(httpResponse.statusCode)"])
                    }
                    print("HTTP错误: \(httpResponse.statusCode)")
                    if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                        print("响应内容: \(responseStr)")
                    }
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self?.error = NSError(domain: "ChatService", code: 0, userInfo: [NSLocalizedDescriptionKey: "无数据返回"])
                }
                return
            }
            
            // 处理响应
            let responseText = String(decoding: data, as: UTF8.self)
            
            if self?.isAnthropicAPI == true {
                // 处理Claude API响应
                self?.handleClaudeResponse(responseText: responseText, onReceive: onReceive)
            } else {
                // 处理OpenAI响应
                self?.handleOpenAIResponse(responseText: responseText, onReceive: onReceive)
            }
        }
        
        task.resume()
    }
    
    // 处理OpenAI响应
    private func handleOpenAIResponse(responseText: String, onReceive: @escaping (String) -> Void) {
        print("收到OpenAI响应")
        
        // 尝试处理SSE流式响应
        if responseText.contains("data:") {
            // OpenAI格式的流式响应
            let events = responseText.components(separatedBy: "data: ")
            
            for event in events {
                let trimmedEvent = event.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if trimmedEvent == "[DONE]" || trimmedEvent.isEmpty {
                    continue
                }
                
                do {
                    if let jsonData = trimmedEvent.data(using: .utf8) {
                        if let streamResponse = try? JSONDecoder().decode(ChatCompletionStreamResponse.self, from: jsonData) {
                            if let content = streamResponse.choices?.first?.delta?.content, !content.isEmpty {
                                DispatchQueue.main.async {
                                    onReceive(content)
                                }
                            }
                        } else {
                            print("无法解码流响应: \(trimmedEvent)")
                        }
                    }
                } catch {
                    print("处理响应错误: \(error)")
                    DispatchQueue.main.async {
                        self.error = error
                    }
                }
            }
        } else {
            // 尝试作为常规JSON响应解析
            do {
                if let data = responseText.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    if let response = try? decoder.decode(ChatCompletionResponse.self, from: data) {
                        if let content = response.choices.first?.message.content {
                            DispatchQueue.main.async {
                                onReceive(content)
                            }
                        }
                    } else {
                        print("无法解码为标准响应格式")
                        
                        // 尝试解析其他可能的响应格式
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let content = json["content"] as? String {
                                DispatchQueue.main.async {
                                    onReceive(content)
                                }
                            } else if let completion = json["completion"] as? String {
                                DispatchQueue.main.async {
                                    onReceive(completion)
                                }
                            } else {
                                print("未找到可识别的内容字段")
                                DispatchQueue.main.async {
                                    self.error = NSError(domain: "ChatService", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法提取API响应中的内容"])
                                }
                            }
                        } else {
                            print("无法解析响应为JSON")
                            DispatchQueue.main.async {
                                self.error = NSError(domain: "ChatService", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解析API响应"])
                            }
                        }
                    }
                }
            } catch {
                print("解析响应JSON错误: \(error)")
                DispatchQueue.main.async {
                    self.error = error
                }
            }
        }
    }
    
    // 处理Claude响应
    private func handleClaudeResponse(responseText: String, onReceive: @escaping (String) -> Void) {
        print("收到Claude响应")
        
        // Claude的流式响应是按行分割的JSON对象
        let lines = responseText.components(separatedBy: .newlines)
        
        for line in lines where !line.isEmpty {
            do {
                if let data = line.data(using: .utf8),
                   let response = try? JSONDecoder().decode(ClaudeStreamResponse.self, from: data) {
                    
                    if response.type == "content_block_delta" && response.delta?.type == "text" {
                        let text = response.delta?.text ?? ""
                        if !text.isEmpty {
                            DispatchQueue.main.async {
                                onReceive(text)
                            }
                        }
                    } else if response.type == "message" {
                        for block in response.message?.content ?? [] where block.type == "text" {
                            DispatchQueue.main.async {
                                onReceive(block.text)
                            }
                        }
                    }
                } else {
                    print("无法解码Claude响应行: \(line)")
                }
            } catch {
                print("处理Claude响应错误: \(error)")
            }
        }
    }
    
    // 发送常规聊天请求
    func sendChatRequest(messages: [ChatMessage]) -> AnyPublisher<ChatCompletionResponse, Error> {
        guard !apiConfig.apiKey.isEmpty else {
            return Fail(error: NSError(domain: "ChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API密钥未设置"])).eraseToAnyPublisher()
        }
        
        let requestMessages = messages.map { ChatCompletionRequest.ChatRequestMessage(role: $0.role.rawValue, content: $0.content) }
        
        let request = ChatCompletionRequest(
            model: apiConfig.model,
            messages: requestMessages,
            stream: false,
            temperature: 1.0,
            max_tokens: 2048,
            top_p: 1.0
        )
        
        guard let url = URL(string: apiConfig.baseURL) else {
            return Fail(error: NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的API URL"])).eraseToAnyPublisher()
        }
        
        guard let jsonData = try? JSONEncoder().encode(request) else {
            return Fail(error: NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无法编码请求数据"])).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 根据API密钥格式设置不同的授权头
        if isAnthropicAPI {
            // Anthropic/Claude API格式
            urlRequest.setValue(apiConfig.apiKey, forHTTPHeaderField: "x-api-key")
            urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        } else {
            // 标准OpenAI格式
            urlRequest.setValue("Bearer \(apiConfig.apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        if let organization = apiConfig.organization, !organization.isEmpty {
            urlRequest.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        urlRequest.httpBody = jsonData
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "ChatService", code: 0, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"])
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let errorMessage = errorResponse["error"] as? [String: Any],
                           let message = errorMessage["message"] as? String {
                            throw NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
                        } else if let errorString = errorResponse["error"] as? String {
                            throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorString])
                        } else {
                            throw NSError(domain: "ChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API返回错误: \(httpResponse.statusCode)"])
                        }
                    } else {
                        throw NSError(domain: "ChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP错误: \(httpResponse.statusCode)"])
                    }
                }
                
                return data
            }
            .decode(type: ChatCompletionResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // 新增：获取建议问题
    func fetchSuggestedQuestions(prompt: String) async throws -> [String] {
        guard !apiConfig.apiKey.isEmpty else {
            throw NSError(domain: "ChatService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API密钥未设置"])
        }
        
        // 主线程更新状态
        await MainActor.run {
             self.isLoading = true
             self.error = nil
         }
         
        defer {
            Task { @MainActor in self.isLoading = false }
        }

        let url: URL
        let urlRequest: URLRequest
        
        do {
            // 根据API类型构建请求
            if isAnthropicAPI {
                let claudeMessage = ClaudeCompletionRequest.ClaudeMessage(role: "user", content: [ClaudeCompletionRequest.ContentBlock(type: "text", text: prompt)])
                let request = ClaudeCompletionRequest(
                    model: apiConfig.model,
                    messages: [claudeMessage],
                    max_tokens: 150, // Keep response short
                    stream: false,
                    temperature: 0.7 // Slightly creative but focused
                )
                guard let requestUrl = URL(string: apiConfig.baseURL) else {
                    throw NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的API URL"])
                }
                url = requestUrl
                
                guard let jsonData = try? JSONEncoder().encode(request) else {
                    throw NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无法编码请求数据"])
                }
                
                var mutableRequest = URLRequest(url: url)
                mutableRequest.httpMethod = "POST"
                mutableRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                mutableRequest.setValue("\(apiConfig.apiKey)", forHTTPHeaderField: "x-api-key")
                mutableRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                mutableRequest.httpBody = jsonData
                urlRequest = mutableRequest
                print("[Claude Suggest] 发送请求到: \(url.absoluteString)")
            } else {
                let openaiMessage = ChatCompletionRequest.ChatRequestMessage(role: "user", content: prompt)
                let request = ChatCompletionRequest(
                    model: apiConfig.model,
                    messages: [openaiMessage],
                    stream: false,
                    temperature: 0.7,
                    max_tokens: 150 // Limit token usage
                )
                guard let requestUrl = URL(string: apiConfig.baseURL) else {
                    throw NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的API URL"])
                }
                url = requestUrl
                
                guard let jsonData = try? JSONEncoder().encode(request) else {
                    throw NSError(domain: "ChatService", code: 400, userInfo: [NSLocalizedDescriptionKey: "无法编码请求数据"])
                }
                
                var mutableRequest = URLRequest(url: url)
                mutableRequest.httpMethod = "POST"
                mutableRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                mutableRequest.setValue("Bearer \(apiConfig.apiKey)", forHTTPHeaderField: "Authorization")
                if let organization = apiConfig.organization, !organization.isEmpty {
                     mutableRequest.setValue(organization, forHTTPHeaderField: "OpenAI-Organization")
                }
                mutableRequest.httpBody = jsonData
                urlRequest = mutableRequest
                print("[OpenAI Suggest] 发送请求到: \(url.absoluteString)")
            }
        } catch {
            await MainActor.run { self.error = error }
            throw error // Rethrow after setting error state
        }

        // 执行网络请求
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ChatService", code: 0, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error message from response body
            var errorMessage = "API返回错误: \(httpResponse.statusCode)"
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let apiError = errorResponse["error"] as? [String: Any], let message = apiError["message"] as? String {
                    errorMessage = message
                } else if let errorString = errorResponse["error"] as? String {
                    errorMessage = errorString
                }
            }
            throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        // 解码响应并提取问题列表
        do {
            var responseContent: String = ""
            if isAnthropicAPI {
                // Decode Claude Response (assuming non-streamed response structure)
                let decoder = JSONDecoder()
                let claudeResponse = try decoder.decode(ClaudeCompletionResponse.self, from: data)
                // Combine content from all text blocks
                responseContent = claudeResponse.content.compactMap { $0.text }.joined(separator: "\n")
            } else {
                // Decode OpenAI Response
                let decoder = JSONDecoder()
                let openAIResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
                responseContent = openAIResponse.choices.first?.message.content ?? ""
            }
            
            // 解析内容为问题列表 (按行分割，去除空行)
            let questions = responseContent.split(separator: "\n")
                                         .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                         .filter { !$0.isEmpty }
            
            return questions
            
        } catch {
            print("解码建议问题响应错误: \(error)")
            throw NSError(domain: "ChatService", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解析建议问题响应: \(error.localizedDescription)"])
        }
    }
} 