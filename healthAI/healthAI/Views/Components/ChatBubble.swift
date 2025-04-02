import SwiftUI

// 聊天消息气泡组件
struct ChatBubble: View {
    let message: ChatMessage
    let isLastMessage: Bool
    
    var body: some View {
        HStack(alignment: .top) {
            if message.role == .assistant {
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(.mint)
                    .font(.system(size: 26))
                    .padding(.top, 4)
                    .padding(.trailing, 2)
            } else if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .font(.body)
                    .padding(14)
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .background(
                        message.role == .user ? 
                            Color.blue : 
                            Color(UIColor.secondarySystemBackground)
                    )
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = message.content
                        }) {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                    }
                
                // 始终显示时间戳，不仅是最后一条消息
                HStack {
                    if message.role == .assistant {
                        // 使用自定义格式显示时间戳，包含时分秒
                        Text(formatTimestamp(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        // 使用自定义格式显示时间戳，包含时分秒
                        Text(formatTimestamp(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                .padding(message.role == .user ? .trailing : .leading, 8)
                .padding(.top, 2)
            }
            
            if message.role == .user {
                // 移除额外的Spacer，避免双重右对齐
            }
        }
        .padding(message.role == .user ? .trailing : .leading, 16)
        .padding(.vertical, 4)
        .id(message.id) // 用于滚动到最新消息
    }
}

// 更现代的打字指示器
struct TypingIndicator: View {
    @State private var typingAnimation = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.text.square.fill")
                .foregroundColor(.mint)
                .font(.system(size: 26))
            
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(.gray)
                        .scaleEffect(typingAnimation ? 1 : 0.6)
                        .opacity(typingAnimation ? 1 : 0.4)
                        .animation(
                            Animation.easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: typingAnimation
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
        }
        .padding(.vertical, 6)
        .padding(.leading, 8)
        .onAppear {
            typingAnimation = true
        }
    }
}

// 添加时间格式化功能
private func formatTimestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: date)
} 