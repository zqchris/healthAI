import SwiftUI
import UIKit

// UITextView的包装器，支持中文输入和回车键提交
struct TextView: UIViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = UIColor.secondarySystemBackground
        textView.isScrollEnabled = true
        textView.layer.cornerRadius = 20
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        textView.autocorrectionType = .default
        textView.keyboardType = .default
        textView.returnKeyType = .send
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextView
        
        init(_ parent: TextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                parent.onCommit()
                return false
            }
            return true
        }
    }
}

// UITextField包装器，保持美观UI并支持回车发送
struct CustomTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void
    var isEnabled: Bool
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.backgroundColor = UIColor.secondarySystemBackground
        textField.placeholder = placeholder
        textField.borderStyle = .none
        textField.returnKeyType = .send
        textField.isEnabled = isEnabled
        textField.clearButtonMode = .whileEditing
        textField.autocorrectionType = .default
        textField.layer.cornerRadius = 20
        
        // 添加内边距
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: textField.frame.height))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        
        // 添加右边距，如果需要的话
        let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: textField.frame.height))
        textField.rightView = rightPaddingView
        textField.rightViewMode = .always
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.isEnabled = isEnabled
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CustomTextField
        
        init(_ parent: CustomTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let text = textField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parent.onCommit()
            }
            return false
        }
    }
}

// 预设输入按钮视图
struct QuickInputButtonsView: View {
    var onSelect: (String) -> Void
    
    let phrases = ["您好", "谢谢", "帮我分析健康数据", "如何改善睡眠质量？", "推荐健康食品"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(phrases, id: \.self) { phrase in
                    Button(action: {
                        onSelect(phrase)
                    }) {
                        Text(phrase)
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(14)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var scrollToBottom = false
    @State private var showQuickInput = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.messages.filter { $0.role != .system }.enumerated()), id: \.element.id) { index, message in
                            ChatBubble(
                                message: message,
                                isLastMessage: index == viewModel.messages.filter { $0.role != .system }.count - 1
                            )
                        }
                        
                        if viewModel.isTyping {
                            TypingIndicator()
                                .padding(.leading, 8)
                                .padding(.top, 8)
                                .id("typingIndicator")
                        }
                        
                        // 在没有消息时显示引导文本
                        if viewModel.messages.filter({ $0.role != .system }).isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "heart.text.square.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.mint.opacity(0.7))
                                
                                Text("欢迎使用健康AI助手")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                
                                Text("您可以向我询问任何健康相关的问题，我会尽力为您提供专业的建议。")
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                if viewModel.apiConfig.apiKey.isEmpty {
                                    Button(action: {
                                        viewModel.showSettings = true
                                    }) {
                                        Text("设置API密钥")
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                    .padding(.top, 8)
                                }
                                
                                // 添加快速输入提示
                                Button {
                                    showQuickInput.toggle()
                                } label: {
                                    HStack {
                                        Image(systemName: "text.bubble")
                                        Text("使用快速输入短语")
                                    }
                                    .font(.footnote)
                                    .foregroundColor(.blue)
                                }
                                .padding(.top, 20)
                            }
                            .padding(40)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if !viewModel.messages.isEmpty {
                        withAnimation {
                            if let lastMessage = viewModel.messages.last {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: viewModel.isTyping) { isTyping in
                    if isTyping {
                        withAnimation {
                            scrollView.scrollTo("typingIndicator", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.currentResponse) { _ in
                    if !viewModel.messages.isEmpty {
                        withAnimation {
                            if let lastMessage = viewModel.messages.last {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // 错误信息显示
            if let errorMessage = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("发生错误")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Spacer()
                        Button {
                            viewModel.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 快速输入短语按钮
            if showQuickInput {
                QuickInputButtonsView { phrase in
                    viewModel.inputMessage = phrase
                }
                .padding(.vertical, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 输入区域
            HStack(alignment: .center) {
                // 快速输入按钮
                Button {
                    withAnimation {
                        showQuickInput.toggle()
                    }
                } label: {
                    Image(systemName: showQuickInput ? "text.bubble.fill" : "text.bubble")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                }
                .padding(.leading, 4)
                
                // 自定义输入框
                CustomTextField(
                    text: $viewModel.inputMessage,
                    placeholder: "输入消息...",
                    onCommit: viewModel.sendMessage,
                    isEnabled: !viewModel.isTyping
                )
                .frame(height: 40)
                .padding(.vertical, 4)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(20)
                .opacity(viewModel.isTyping ? 0.6 : 1.0)
                
                Button(action: {
                    viewModel.sendMessage()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(viewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTyping ? .gray : .blue)
                }
                .disabled(viewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTyping)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .navigationTitle("健康顾问")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showSettings) {
            APISettingsView(
                apiConfig: $viewModel.apiConfig,
                showSettings: $viewModel.showSettings,
                apiType: $viewModel.apiType,
                onSave: viewModel.saveAPISettings,
                onUpdateType: viewModel.updateAPIType
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        viewModel.showSettings = true
                    }) {
                        Label("API设置", systemImage: "gear")
                    }
                    
                    Button(action: {
                        viewModel.clearChat()
                    }) {
                        Label("清空聊天", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

struct ChatViewError: Identifiable {
    let id = UUID()
    let message: String
} 