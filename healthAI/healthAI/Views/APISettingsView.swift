import SwiftUI

struct APISettingsView: View {
    @Binding var apiConfig: GPTAPIConfig
    @Binding var showSettings: Bool
    @Binding var apiType: String
    var onSave: () -> Void
    var onUpdateType: (String) -> Void
    
    @State private var isSecured = true
    @State private var customBaseURL = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API 提供商")) {
                    Picker("API 类型", selection: $apiType) {
                        Text("OpenAI").tag("openai")
                        Text("Anthropic/Claude").tag("anthropic")
                        Text("其他").tag("other")
                    }
                    .onChange(of: apiType) { newValue in
                        onUpdateType(newValue)
                    }
                }
                
                Section(header: Text("API 配置")) {
                    VStack(alignment: .leading) {
                        Text("API 密钥")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            if isSecured {
                                SecureField(apiType == "anthropic" ? "输入 Claude API 密钥" : "输入 OpenAI API 密钥", text: $apiConfig.apiKey)
                                    .textContentType(.password)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                TextField(apiType == "anthropic" ? "输入 Claude API 密钥" : "输入 OpenAI API 密钥", text: $apiConfig.apiKey)
                                    .textContentType(.password)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            
                            Button(action: {
                                isSecured.toggle()
                            }) {
                                Image(systemName: isSecured ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    HStack {
                        Text("模型")
                        Spacer()
                        Text(apiType == "anthropic" ? "claude-3-opus-20240229" : "gpt-4o")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("高级设置")) {
                    Toggle("自定义API端点", isOn: $customBaseURL)
                    
                    if customBaseURL {
                        TextField("API 基础 URL", text: $apiConfig.baseURL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    TextField("组织 ID（可选）", text: Binding(
                        get: { apiConfig.organization ?? "" },
                        set: { apiConfig.organization = $0.isEmpty ? nil : $0 }
                    ))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                }
                
                Section(footer: Text("请确保您选择了正确的API类型，并输入了对应的API密钥和端点。OpenAI的密钥需要以「Bearer」方式传递，而Claude需要使用「x-api-key」方式。")) {
                    Button("保存设置") {
                        onSave()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("API 设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showSettings = false
                    }
                }
            }
            .onAppear {
                // 设置自定义URL标志
                if apiType == "other" || 
                   (apiType == "openai" && !apiConfig.baseURL.contains("api.openai.com")) ||
                   (apiType == "anthropic" && !apiConfig.baseURL.contains("api.anthropic.com")) {
                    customBaseURL = true
                }
            }
        }
    }
} 