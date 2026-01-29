import Foundation

// 消息模型
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    var content: String
    var timestamp: Date
    
    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// 消息角色
enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// API配置
struct GPTAPIConfig: Codable {
    var apiKey: String
    var model: String
    var baseURL: String
    var organization: String?
    
    static let defaultConfig = GPTAPIConfig(
        apiKey: "",
        model: "gpt-4o",
        baseURL: "https://api.openai.com/v1/chat/completions",
        organization: nil
    )
}

// OpenAI API请求模型
struct ChatCompletionRequest: Codable {
    var model: String
    var messages: [ChatRequestMessage]
    var stream: Bool = true
    var temperature: Double = 1.0
    var max_tokens: Int = 2048
    var top_p: Double = 1.0
    
    struct ChatRequestMessage: Codable {
        var role: String
        var content: String
    }
}

// Claude/Anthropic API请求模型
struct ClaudeCompletionRequest: Codable {
    var model: String
    var messages: [ClaudeMessage]
    var max_tokens: Int = 2048
    var stream: Bool = true
    var temperature: Double = 1.0
    var system: String?
    
    struct ClaudeMessage: Codable {
        var role: String
        var content: [ContentBlock]
    }
    
    struct ContentBlock: Codable {
        var type: String
        var text: String
    }
}

// API响应模型
struct ChatCompletionResponse: Decodable {
    var id: String
    var object: String
    var created: Int
    var model: String
    var choices: [Choice]
    var usage: Usage?
    
    struct Choice: Decodable {
        var index: Int
        var message: Message
        var finish_reason: String?
    }
    
    struct Message: Decodable {
        var role: String
        var content: String
    }
    
    struct Usage: Decodable {
        var prompt_tokens: Int
        var completion_tokens: Int
        var total_tokens: Int
    }
}

// Claude响应模型
struct ClaudeCompletionResponse: Decodable {
    var id: String
    var type: String
    var role: String
    var content: [ContentBlock]
    var model: String
    var stop_reason: String?
    var stop_sequence: String?
    var usage: Usage?
    
    struct ContentBlock: Decodable {
        var type: String
        var text: String
    }
    
    struct Usage: Decodable {
        var input_tokens: Int
        var output_tokens: Int
    }
}

// 流式响应处理 - OpenAI
struct ChatCompletionStreamResponse: Decodable {
    var id: String?
    var object: String?
    var created: Int?
    var model: String?
    var choices: [Choice]?
    
    struct Choice: Decodable {
        var index: Int?
        var delta: Delta?
        var finish_reason: String?
    }
    
    struct Delta: Decodable {
        var role: String?
        var content: String?
    }
}

// Claude流式响应
struct ClaudeStreamResponse: Decodable {
    var type: String
    var message: ClaudeStreamMessage?
    var delta: DeltaBlock?
    
    struct ClaudeStreamMessage: Decodable {
        var id: String
        var type: String
        var role: String
        var content: [ContentBlock]
        var model: String
    }
    
    struct DeltaBlock: Decodable {
        var type: String
        var text: String
    }
    
    struct ContentBlock: Decodable {
        var type: String
        var text: String
    }
} 