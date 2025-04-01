import SwiftUI

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
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .padding(12)
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .background(
                        message.role == .user ? 
                            Color.blue : 
                            Color(UIColor.secondarySystemBackground)
                    )
                    .cornerRadius(16)
                    .contextMenu {
                        Button(action: {
                            UIPasteboard.general.string = message.content
                        }) {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                    }
                
                if isLastMessage {
                    HStack {
                        if message.role == .assistant {
                            Text(message.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                    .padding(message.role == .user ? .trailing : .leading, 8)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: message.role == .user ? nil : .infinity, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .user {
                Spacer(minLength: 30)
            }
        }
        .padding(message.role == .user ? .leading : .trailing, 60)
        .padding(.vertical, 4)
        .id(message.id) // 用于滚动到最新消息
    }
}

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
                        .opacity(typingAnimation ? 1 : 0.3)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                            value: typingAnimation
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .onAppear {
            typingAnimation = true
        }
    }
} 