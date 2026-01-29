import SwiftUI
import UIKit

// 键盘隐藏扩展
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// 增强的ScrollView，支持点击隐藏键盘
struct DismissKeyboardScrollView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            content
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.endEditing()
            }
        )
    }
}

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
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            // 添加通知监听，当键盘要隐藏时响应
            NotificationCenter.default.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { _ in
                textField.resignFirstResponder()
            }
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            // 移除通知监听
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        }
    }
}

// 预设输入按钮视图
struct QuickInputButtonsView: View {
    var onSelect: (String) -> Void
    let questions: [String]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(questions, id: \.self) { question in
                    Button(action: {
                        onSelect(question)
                    }) {
                        Text(question)
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

// 新增：初始化/加载视图
struct InitializationView: View {
    @Binding var initializationError: String?
    let retryAction: () async -> Void // 接收异步重试操作
    
    var body: some View {
        VStack(spacing: 16) {
            if let error = initializationError {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                    .padding()
                
                Text("初始化出错")
                    .font(.headline)
                
                Text(error)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Button("重试") {
                    Task {
                        await retryAction()
                    }
                }
                .padding()
                .buttonStyle(.borderedProminent) // 使用更标准的按钮样式
                .padding(.top)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                
                Text("正在初始化...")
                    .font(.headline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

// 新增：主聊天界面视图
struct MainChatInterfaceView: View {
    @ObservedObject var viewModel: ChatViewModel // 接收 ViewModel
    @Binding var showQuickInput: Bool // 接收绑定
    
    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { scrollView in
                DismissKeyboardScrollView {
                    LazyVStack(spacing: 0) {
                        // 按时间戳排序消息，确保顺序正确
                        let sortedMessages = viewModel.messages.filter { $0.role != .system }.sorted(by: { $0.timestamp < $1.timestamp })
                        
                        ForEach(Array(sortedMessages.enumerated()), id: \.element.id) { index, message in
                            ChatBubble(
                                message: message,
                                isLastMessage: index == sortedMessages.count - 1
                            )
                        }
                        
                        // 如果AI正在输入，显示一个带有打字动画的气泡
                        if viewModel.isTyping {
                            ChatTypingBubble()
                                .id("typingIndicator")
                                .padding(.vertical, 4)
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
                            if let lastMessage = viewModel.messages.filter { $0.role != .system }.sorted(by: { $0.timestamp < $1.timestamp }).last {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                                
                                // 调试消息排序
                                print("消息顺序更新 - 总数: \(viewModel.messages.count), 最新消息: \(lastMessage.role) at \(lastMessage.timestamp)")
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
                            if let lastMessage = viewModel.messages.filter { $0.role != .system }.sorted(by: { $0.timestamp < $1.timestamp }).last {
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
                QuickInputButtonsView(onSelect: { phrase in
                    viewModel.inputMessage = phrase
                }, questions: viewModel.suggestedQuestions)
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
    }
}

// 添加ChatTypingBubble组件，在AI气泡内显示打字动画
struct ChatTypingBubble: View {
    @State private var showDot1 = false
    @State private var showDot2 = false
    @State private var showDot3 = false
    
    var body: some View {
        HStack(alignment: .bottom) {
            Image(systemName: "heart.text.square.fill")
                .foregroundColor(.mint)
                .font(.system(size: 26))
                .padding(.top, 4)
                .padding(.trailing, 2)
                
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                        .scaleEffect(showDot1 ? 1 : 0.5)
                        .opacity(showDot1 ? 1 : 0.5)
                    
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                        .scaleEffect(showDot2 ? 1 : 0.5)
                        .opacity(showDot2 ? 1 : 0.5)
                    
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 6, height: 6)
                        .scaleEffect(showDot3 ? 1 : 0.5)
                        .opacity(showDot3 ? 1 : 0.5)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .onAppear {
            // 创建循环动画
            withAnimation(Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0)) {
                showDot1 = true
            }
            withAnimation(Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0.2)) {
                showDot2 = true
            }
            withAnimation(Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0.4)) {
                showDot3 = true
            }
        }
    }
}

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showQuickInput = false
    @State private var isInitialized = false
    @State private var initializationError: String? = nil
    
    var body: some View {
        ZStack {
            // 使用提取的视图
            if !isInitialized {
                InitializationView(initializationError: $initializationError, retryAction: initializeViewModel)
            } else {
                MainChatInterfaceView(viewModel: viewModel, showQuickInput: $showQuickInput)
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
                    .onTapGesture {
                        UIApplication.shared.endEditing() // 点击背景隐藏键盘
                    }
            }
        }
        .task {
            if !isInitialized {
                await initializeViewModel()
            }
        }
        .onAppear {
            // 检查API密钥是否已设置，如果未设置则自动打开设置页面
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if viewModel.apiConfig.apiKey.isEmpty && isInitialized {
                    viewModel.showSettings = true
                }
            }
        }
    }
    
    // 异步初始化ViewModel
    private func initializeViewModel() async {
        do {
            DispatchQueue.main.async {
                self.initializationError = nil
                self.isInitialized = false
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000) // 短暂延迟以显示加载
            
            // 这里可以添加ViewModel的异步初始化逻辑（如果需要）
            // 例如: await viewModel.loadInitialData()
            
            DispatchQueue.main.async {
                self.isInitialized = true
                
                // 初始化完成后检查API密钥
                if self.viewModel.apiConfig.apiKey.isEmpty {
                    self.viewModel.showSettings = true
                }
            }
        } catch let error as NSError {
            print("初始化错误: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.initializationError = error.localizedDescription
            }
        } catch {
            print("未知初始化错误")
            DispatchQueue.main.async {
                self.initializationError = "初始化过程中发生未知错误，请重试。"
            }
        }
    }
}

struct ChatViewError: Identifiable {
    let id = UUID()
    let message: String
} 