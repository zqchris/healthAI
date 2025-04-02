import SwiftUI

struct APISettingsView: View {
    @Binding var apiConfig: GPTAPIConfig
    @Binding var showSettings: Bool
    @Binding var apiType: String
    var onSave: () -> Void
    var onUpdateType: (String) -> Void
    
    @State private var showHelp = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API类型").bold()) {
                    Picker("API服务商", selection: $apiType) {
                        Text("OpenAI").tag("openai")
                        Text("Anthropic (Claude)").tag("anthropic")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: apiType) { newValue in
                        onUpdateType(newValue)
                    }
                }
                
                Section(header: Text("API密钥").bold(), footer: Text("您的密钥将安全地存储在设备上").foregroundColor(.gray)) {
                    SecureField("API密钥", text: $apiConfig.apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                    
                    if !apiConfig.apiKey.isEmpty {
                        Label("密钥已设置", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                Section(header: Text("高级设置（可选）").bold(), footer: Text("如果您使用自定义API端点，可以在此处修改").foregroundColor(.gray)) {
                    TextField("API端点", text: $apiConfig.baseURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    
                    TextField("组织ID (可选)", text: Binding(
                        get: { apiConfig.organization ?? "" },
                        set: { apiConfig.organization = $0.isEmpty ? nil : $0 }
                    ))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                }
                
                Section {
                    Button(action: {
                        showHelp.toggle()
                    }) {
                        Label("如何获取API密钥", systemImage: "questionmark.circle")
                    }
                    .foregroundColor(.blue)
                }
                
                Section {
                    HStack {
                        Spacer()
                        Button(action: {
                            onSave()
                        }) {
                            Text("保存设置")
                                .fontWeight(.semibold)
                                .frame(height: 44)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .foregroundColor(.blue)
                        .disabled(apiConfig.apiKey.isEmpty)
                        Spacer()
                    }
                }
            }
            .navigationTitle("API设置")
            .navigationBarItems(trailing: Button("关闭") {
                showSettings = false
            })
            .alert(isPresented: $showHelp) {
                Alert(
                    title: Text("如何获取API密钥"),
                    message: Text(getHelpText()),
                    dismissButton: .default(Text("了解"))
                )
            }
        }
    }
    
    private func getHelpText() -> String {
        if apiType == "openai" {
            return "1. 访问 OpenAI 官网 (openai.com)\n2. 创建或登录您的账户\n3. 进入API部分\n4. 创建新的API密钥\n5. 复制密钥并粘贴到此处"
        } else {
            return "1. 访问 Anthropic 官网 (anthropic.com)\n2. 创建或登录您的账户\n3. 进入API设置\n4. 创建新的API密钥\n5. 复制密钥并粘贴到此处"
        }
    }
} 