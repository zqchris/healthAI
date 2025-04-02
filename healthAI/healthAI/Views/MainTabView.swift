import SwiftUI
import HealthKit

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showError = false
    @State private var errorMessage = ""
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        VStack(spacing: 0) {
            // 主内容区域
            ZStack {
                // 根据选中的标签显示不同内容
                if selectedTab == 0 {
                    // 健康顾问标签
                    NavigationStack {
                        ZStack {
                            // 主视图
                            ChatView()
                            
                            // 错误提示覆盖层
                            if showError {
                                VStack {
                                    Spacer()
                                    
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        
                                        Text(errorMessage)
                                            .font(.footnote)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Button {
                                            withAnimation {
                                                showError = false
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                    .shadow(radius: 2)
                                }
                                .transition(.move(edge: .bottom))
                                .zIndex(100)
                            }
                        }
                        .navigationTitle("健康AI助手")
                    }
                }
                else if selectedTab == 1 {
                    // 健康数据标签
                    NavigationStack {
                        HealthDataView()
                            .navigationTitle("健康数据")
                    }
                }
                else if selectedTab == 2 {
                    // 分析标签
                    NavigationStack {
                        HealthAnalysisView()
                            .navigationTitle("健康分析")
                    }
                }
                else {
                    // 我的标签
                    NavigationStack {
                        ProfileView()
                            .navigationTitle("我的")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 自定义底部标签栏
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            // 在应用启动或返回前台时尝试加载健康数据
            HealthDataService.shared.loadHealthData()
        }
    }
    
    // 显示错误消息
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        withAnimation {
            showError = true
        }
        
        // 3秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.showError = false
            }
        }
    }
    
    // 自定义TabBar
    struct CustomTabBar: View {
        @Binding var selectedTab: Int
        let primaryColor = ThemeManager.shared.primaryColor
        
        var body: some View {
            HStack {
                ForEach(0..<4) { index in
                    Button(action: {
                        withAnimation {
                            selectedTab = index
                        }
                    }) {
                        TabBarItem(
                            icon: tabIcon(for: index),
                            title: tabTitle(for: index),
                            isSelected: selectedTab == index,
                            primaryColor: primaryColor
                        )
                    }
                }
            }
            .padding(.vertical, 10)
            .background(
                Rectangle()
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: -1)
                    .edgesIgnoringSafeArea(.bottom)
            )
        }
        
        // 获取标签图标
        private func tabIcon(for index: Int) -> String {
            switch index {
            case 0: return "heart.text.square"
            case 1: return "heart.circle"
            case 2: return "chart.bar"
            case 3: return "person.circle"
            default: return "questionmark"
            }
        }
        
        // 获取标签标题
        private func tabTitle(for index: Int) -> String {
            switch index {
            case 0: return "健康顾问"
            case 1: return "健康数据"
            case 2: return "分析"
            case 3: return "我的"
            default: return ""
            }
        }
    }
    
    // TabBar项目
    struct TabBarItem: View {
        let icon: String
        let title: String
        let isSelected: Bool
        let primaryColor: Color
        
        var body: some View {
            VStack(spacing: 4) {
                // 保持图标形状不变，只改变颜色
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? primaryColor : .gray)
                
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? primaryColor : .gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// 个人资料视图
struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var apiConfig = GPTAPIConfig.defaultConfig
    @State private var showSettings = false
    @State private var apiType = "openai"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 个人资料卡片
                VStack(spacing: 15) {
                    // 头像
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(ThemeManager.shared.primaryColor)
                    
                    // 用户名
                    Text("测试用户")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // 用户基本信息
                    HStack(spacing: 20) {
                        VStack {
                            Text("年龄")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("35")
                                .font(.headline)
                        }
                        
                        Divider()
                            .frame(height: 20)
                        
                        VStack {
                            Text("身高")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("175cm")
                                .font(.headline)
                        }
                        
                        Divider()
                            .frame(height: 20)
                        
                        VStack {
                            Text("体重")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("70kg")
                                .font(.headline)
                        }
                    }
                }
                .padding()
                .cardStyle()
                
                // 设置菜单
                settingsMenuSection
                
                // 应用信息
                appInfoSection
            }
            .padding()
        }
        .onAppear {
            // 加载保存的API设置
            loadSavedAPISettings()
        }
    }
    
    // 加载保存的API设置
    private func loadSavedAPISettings() {
        if let savedKey = UserDefaults.standard.string(forKey: "api_key") {
            let savedBaseURL = UserDefaults.standard.string(forKey: "base_url") ?? "https://api.openai.com/v1/chat/completions"
            let savedOrg = UserDefaults.standard.string(forKey: "organization")
            let savedType = UserDefaults.standard.string(forKey: "api_type") ?? "openai"
            
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
        }
    }
    
    // 设置菜单部分
    private var settingsMenuSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("设置")
                .font(.headline)
                .padding(.leading)
            
            VStack(spacing: 0) {
                // 个人资料设置
                NavigationLink(destination: Text("个人资料设置（待开发）")) {
                    settingsRow(icon: "person.fill", title: "个人资料", color: .blue)
                }
                
                Divider()
                    .padding(.leading, 50)
                
                // 通知设置
                NavigationLink(destination: Text("通知设置（待开发）")) {
                    settingsRow(icon: "bell.fill", title: "通知", color: .orange)
                }
                
                Divider()
                    .padding(.leading, 50)
                
                // 隐私设置
                NavigationLink(destination: Text("隐私设置（待开发）")) {
                    settingsRow(icon: "lock.fill", title: "隐私与数据", color: .green)
                }
                
                Divider()
                    .padding(.leading, 50)
                
                // API设置
                NavigationLink(destination: APISettingsView(
                    apiConfig: $apiConfig,
                    showSettings: $showSettings,
                    apiType: $apiType,
                    onSave: saveAPISettings,
                    onUpdateType: updateAPIType
                )) {
                    settingsRow(icon: "key.fill", title: "API设置", color: .purple)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    // API设置的保存方法
    private func saveAPISettings() {
        // 保存到UserDefaults
        UserDefaults.standard.set(apiConfig.apiKey, forKey: "api_key")
        UserDefaults.standard.set(apiConfig.model, forKey: "model")
        UserDefaults.standard.set(apiConfig.baseURL, forKey: "base_url")
        UserDefaults.standard.set(apiConfig.organization, forKey: "organization")
        UserDefaults.standard.set(apiType, forKey: "api_type")
        
        // 更新显示状态
        showSettings = false
    }
    
    // 更新API类型
    private func updateAPIType(_ type: String) {
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
    
    // 应用信息部分
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("关于")
                .font(.headline)
                .padding(.leading)
            
            VStack(spacing: 0) {
                // 帮助中心
                NavigationLink(destination: Text("帮助中心（待开发）")) {
                    settingsRow(icon: "questionmark.circle.fill", title: "帮助中心", color: .cyan)
                }
                
                Divider()
                    .padding(.leading, 50)
                
                // 关于我们
                NavigationLink(destination: Text("关于我们（待开发）")) {
                    settingsRow(icon: "info.circle.fill", title: "关于我们", color: .indigo)
                }
                
                Divider()
                    .padding(.leading, 50)
                
                // 版本信息
                HStack {
                    Image(systemName: "applescript.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .frame(width: 30)
                        .padding(.horizontal, 10)
                    
                    Text("版本")
                    
                    Spacer()
                    
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing)
                }
                .padding(.vertical, 12)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    // 设置行项目
    private func settingsRow(icon: String, title: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
                .padding(.horizontal, 10)
            
            Text(title)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.trailing)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// 健康数据视图
struct HealthDataView: View {
    @StateObject private var healthDataService = HealthDataService.shared
    
    var body: some View {
        ZStack {
            // 背景
            Color(UIColor.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
            
            if healthDataService.isLoading {
                LoadingView()
            } else if let error = healthDataService.errorMessage {
                ErrorView(errorMessage: error) {
                    healthDataService.loadHealthData(forceUpdate: true)
                }
            } else if let summary = healthDataService.healthSummary {
                // 显示健康数据摘要
                HealthDataContentView(summary: summary)
            } else {
                NoDataView {
                    healthDataService.loadHealthData(forceUpdate: true)
                }
            }
        }
        .onAppear {
            if healthDataService.healthSummary == nil && !healthDataService.isLoading {
                healthDataService.loadHealthData()
            }
        }
        .refreshable {
            healthDataService.loadHealthData(forceUpdate: true)
        }
    }
}

// 健康数据内容视图
struct HealthDataContentView: View {
    let summary: HealthDataSummary
    
    // 将格式化器从body内部移到外部
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 顶部概览卡片
                VStack {
                    HStack {
                        // 标题带小图标
                        HStack(spacing: 10) {
                            Image(systemName: "heart.circle.fill")
                                .foregroundColor(ThemeManager.shared.primaryColor)
                                .font(.title)
                            
                            Text("健康数据摘要")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // 分类数据标题
                Text("活动与运动")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                
                // 步数卡片和详情
                StepsDataSection(summary: summary)
                    .padding(.horizontal)
                
                // 距离数据
                if summary.totalDistanceWalkingRunning != nil || summary.dailyDistanceWalkingRunning?.isEmpty == false {
                    DistanceDataSection(summary: summary)
                        .padding(.horizontal)
                }
                
                // 爬楼数据
                if summary.totalFlightsClimbed != nil || summary.dailyFlightsClimbed?.isEmpty == false {
                    FlightsClimbedDataSection(summary: summary)
                        .padding(.horizontal)
                }
                
                // 活动能量卡片和详情
                EnergyDataSection(summary: summary)
                    .padding(.horizontal)
                
                // 锻炼时间
                if summary.totalExerciseTime != nil || summary.dailyExerciseTime?.isEmpty == false {
                    ExerciseTimeDataSection(summary: summary)
                        .padding(.horizontal)
                }
                
                // 分类数据标题
                Text("生命体征")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.top)
                
                // 心率卡片和详情
                HeartRateDataSection(summary: summary)
                    .padding(.horizontal)
                
                // 静息心率
                if summary.averageRestingHeartRate != nil || summary.dailyRestingHeartRate?.isEmpty == false {
                    RestingHeartRateDataSection(summary: summary)
                        .padding(.horizontal)
                }
                
                // 呼吸率
                if summary.averageRespiratoryRate != nil || summary.dailyRespiratoryRate?.isEmpty == false {
                    RespiratoryRateDataSection(summary: summary)
                        .padding(.horizontal)
                }
                
                // 血氧
                if summary.averageOxygenSaturation != nil || summary.dailyOxygenSaturation?.isEmpty == false {
                    OxygenSaturationDataSection(summary: summary)
                        .padding(.horizontal)
                }
                
                // 血压
                if summary.dailyBloodPressure?.isEmpty == false {
                    BloodPressureDataSection(summary: summary)
                        .padding(.horizontal)
                }
                
                // 体温
                if summary.averageBodyTemperature != nil || summary.dailyBodyTemperature?.isEmpty == false {
                    BodyTemperatureDataSection(summary: summary)
                        .padding(.horizontal)
                }
                
                // 分类数据标题
                Text("睡眠")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.top)
                
                // 睡眠数据卡片和详情
                SleepDataSection(summary: summary)
                    .padding(.horizontal)
                
                // 分类数据标题
                Text("体重与体型")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.top)
                
                // 体重
                if summary.averageBodyMass != nil || summary.dailyBodyMass?.isEmpty == false {
                    BodyMassDataSection(summary: summary)
                        .padding(.horizontal)
                }
                
                // BMI
                if summary.averageBodyMassIndex != nil || summary.dailyBodyMassIndex?.isEmpty == false {
                    BodyMassIndexDataSection(summary: summary)
                        .padding(.horizontal)
                }
                
                // 体脂率
                if summary.averageBodyFatPercentage != nil || summary.dailyBodyFatPercentage?.isEmpty == false {
                    BodyFatDataSection(summary: summary)
                        .padding(.horizontal)
                }
                
                // 分类数据标题
                Text("营养")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.top)
                
                // 摄入能量
                if summary.totalDietaryEnergy != nil || summary.dailyDietaryEnergy?.isEmpty == false {
                    DietaryEnergyDataSection(summary: summary)
                        .padding(.horizontal)
                }
                
                // 饮水量
                if summary.totalDietaryWater != nil || summary.dailyDietaryWater?.isEmpty == false {
                    DietaryWaterDataSection(summary: summary)
                        .padding(.horizontal)
                }
                
                // 更新时间
                HStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let lastSync = HealthDataService.shared.lastSyncDate {
                            Text("更新于: \(dateFormatter.string(from: lastSync))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("更新于: \(dateFormatter.string(from: Date()))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground).opacity(0.6))
                    .cornerRadius(8)
                    Spacer()
                }
                .padding(.top, 5)
                .padding(.bottom)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// 步数数据区域
struct StepsDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：步数
            HealthDataCard(
                title: "步数",
                value: summary.stepCount != nil ? "\(Int(summary.stepCount!)) 步" : "未获取数据",
                icon: "figure.walk",
                color: ThemeManager.DataColors.steps
            )
            
            // 详细步数数据
            if let dailySteps = summary.dailySteps, !dailySteps.isEmpty {
                DailyDataView(
                    title: "每日步数",
                    data: dailySteps,
                    valueFormatter: { "\(Int($0)) 步" }
                )
            }
        }
    }
}

// 心率数据区域
struct HeartRateDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：心率
            HealthDataCard(
                title: "平均心率",
                value: summary.averageHeartRate != nil ? "\(Int(summary.averageHeartRate!)) 次/分钟" : "未获取数据",
                icon: "heart",
                color: ThemeManager.DataColors.heartRate
            )
            
            // 详细心率数据
            if let dailyHeartRate = summary.dailyHeartRate, !dailyHeartRate.isEmpty {
                DailyDataView(
                    title: "每日心率",
                    data: dailyHeartRate,
                    valueFormatter: { "\(Int($0)) 次/分钟" }
                )
            }
        }
    }
}

// 能量数据区域
struct EnergyDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：活动能量
            HealthDataCard(
                title: "总活动能量",
                value: summary.totalActiveEnergy != nil ? "\(Int(summary.totalActiveEnergy!)) 千卡" : "未获取数据",
                icon: "flame",
                color: ThemeManager.DataColors.energy
            )
            
            // 详细活动能量数据
            if let dailyEnergy = summary.dailyActiveEnergy, !dailyEnergy.isEmpty {
                DailyDataView(
                    title: "每日活动能量",
                    data: dailyEnergy,
                    valueFormatter: { "\(Int($0)) 千卡" }
                )
            }
        }
    }
}

// 睡眠数据区域
struct SleepDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：睡眠时间
            HealthDataCard(
                title: "平均睡眠时间",
                value: summary.averageSleepDuration != nil ? formatDuration(summary.averageSleepDuration!) : "未获取数据",
                icon: "bed.double.fill",
                color: ThemeManager.DataColors.sleep
            )
            
            // 详细睡眠数据
            if let dailySleep = summary.dailySleep, !dailySleep.isEmpty {
                DailyDataView(
                    title: "每日睡眠",
                    data: dailySleep,
                    valueFormatter: { formatDuration($0) }
                )
            }
            
            // 睡眠阶段数据
            if let sleepDetails = summary.sleepDetails, !sleepDetails.isEmpty {
                SleepStagesView(sleepDetails: sleepDetails)
            }
        }
    }
    
    // 格式化持续时间
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)小时\(minutes)分钟"
    }
}

// 睡眠阶段视图
struct SleepStagesView: View {
    let sleepDetails: [Date: SleepDetail]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(ThemeManager.DataColors.sleep)
                
                Text("睡眠阶段详情")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding([.horizontal, .top])
            
            Divider()
                .padding(.horizontal)
            
            // 睡眠阶段数据
            let avgDetail = calculateAverageSleepDetail()
            
            VStack(alignment: .leading, spacing: 15) {
                if let deepSleep = avgDetail.deepSleep,
                   let remSleep = avgDetail.remSleep,
                   let coreSleep = avgDetail.coreSleep,
                   let total = avgDetail.total, total > 0 {
                    
                    // 计算百分比
                    let deepPercent = (deepSleep / total) * 100
                    let remPercent = (remSleep / total) * 100
                    let corePercent = (coreSleep / total) * 100
                    
                    // 睡眠阶段百分比指示器
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("深度睡眠")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Text(formatDuration(deepSleep))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        ZStack(alignment: .leading) {
                            // 背景条
                            RoundedRectangle(cornerRadius: 3)
                                .foregroundColor(.gray.opacity(0.2))
                                .frame(width: 100, height: 8)
                            
                            // 填充条
                            RoundedRectangle(cornerRadius: 3)
                                .foregroundColor(.purple)
                                .frame(width: min(CGFloat(deepPercent), 100), height: 8)
                        }
                        
                        Text("\(Int(deepPercent))%")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                            .frame(width: 45, alignment: .trailing)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("REM睡眠")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Text(formatDuration(remSleep))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        ZStack(alignment: .leading) {
                            // 背景条
                            RoundedRectangle(cornerRadius: 3)
                                .foregroundColor(.gray.opacity(0.2))
                                .frame(width: 100, height: 8)
                            
                            // 填充条
                            RoundedRectangle(cornerRadius: 3)
                                .foregroundColor(.blue)
                                .frame(width: min(CGFloat(remPercent), 100), height: 8)
                        }
                        
                        Text("\(Int(remPercent))%")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .frame(width: 45, alignment: .trailing)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("核心睡眠")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Text(formatDuration(coreSleep))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        ZStack(alignment: .leading) {
                            // 背景条
                            RoundedRectangle(cornerRadius: 3)
                                .foregroundColor(.gray.opacity(0.2))
                                .frame(width: 100, height: 8)
                            
                            // 填充条
                            RoundedRectangle(cornerRadius: 3)
                                .foregroundColor(.teal)
                                .frame(width: min(CGFloat(corePercent), 100), height: 8)
                        }
                        
                        Text("\(Int(corePercent))%")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.teal)
                            .frame(width: 45, alignment: .trailing)
                    }
                } else {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "moon.zzz")
                                .font(.title)
                                .foregroundColor(.secondary)
                            
                            Text("睡眠阶段数据不足")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    // 计算平均睡眠阶段数据
    private func calculateAverageSleepDetail() -> (deepSleep: TimeInterval?, remSleep: TimeInterval?, coreSleep: TimeInterval?, total: TimeInterval?) {
        var totalDeepSleep: TimeInterval = 0
        var totalRemSleep: TimeInterval = 0
        var totalCoreSleep: TimeInterval = 0
        var totalSleep: TimeInterval = 0
        
        var deepCount = 0
        var remCount = 0
        var coreCount = 0
        var totalCount = 0
        
        for (_, detail) in sleepDetails {
            if let deep = detail.deepSleepDuration {
                totalDeepSleep += deep
                deepCount += 1
            }
            
            if let rem = detail.remSleepDuration {
                totalRemSleep += rem
                remCount += 1
            }
            
            if let core = detail.coreSleepDuration {
                totalCoreSleep += core
                coreCount += 1
            }
            
            if let total = detail.asleepDuration {
                totalSleep += total
                totalCount += 1
            }
        }
        
        // 计算平均值，如果没有数据则返回nil
        let avgDeepSleep = deepCount > 0 ? totalDeepSleep / Double(deepCount) : nil
        let avgRemSleep = remCount > 0 ? totalRemSleep / Double(remCount) : nil
        let avgCoreSleep = coreCount > 0 ? totalCoreSleep / Double(coreCount) : nil
        let avgTotalSleep = totalCount > 0 ? totalSleep / Double(totalCount) : nil
        
        return (avgDeepSleep, avgRemSleep, avgCoreSleep, avgTotalSleep)
    }
    
    // 格式化持续时间
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)小时\(minutes)分钟"
    }
}

// 健康数据卡片组件
struct HealthDataCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(color)
                    .cornerRadius(8)
                
                // 标题
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 2)
            
            // 分隔线
            Rectangle()
                .fill(color.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal)
            
            // 数据值
            HStack {
                Spacer()
                
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.vertical, 12)
                
                Spacer()
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// 通用每日数据视图
struct DailyDataView<T: Numeric>: View {
    let title: String
    let data: [Date: T]
    let valueFormatter: (T) -> String
    
    // 将格式化器从body内部移到外部
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
    
    private var weekDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding([.horizontal, .top])
                
                Spacer()
            }
            
            Divider()
                .padding(.horizontal)
            
            // 数据内容
            let sortedDays = data.keys.sorted()
            
            VStack(spacing: 0) {
                ForEach(sortedDays, id: \.self) { day in
                    if let value = data[day] {
                        DailyDataRow(
                            day: day,
                            value: value,
                            dateFormatter: dateFormatter,
                            weekDayFormatter: weekDayFormatter,
                            valueFormatter: valueFormatter
                        )
                        
                        if day != sortedDays.last {
                            Divider()
                                .padding(.leading, 65)
                                .padding(.trailing)
                        }
                    }
                }
            }
            .padding(.vertical, 5)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// 每日数据行
struct DailyDataRow<T: Numeric>: View {
    let day: Date
    let value: T
    let dateFormatter: DateFormatter
    let weekDayFormatter: DateFormatter
    let valueFormatter: (T) -> String
    
    var body: some View {
        HStack(spacing: 15) {
            // 日期圆形背景
            ZStack {
                Circle()
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .frame(width: 45, height: 45)
                
                VStack(spacing: 0) {
                    Text(day.formatted(.dateTime.day()))
                        .font(.system(size: 16, weight: .bold))
                    Text(day.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(weekDayFormatter.string(from: day))
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text(valueFormatter(value))
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.trailing)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// 距离数据区域
struct DistanceDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：距离
            HealthDataCard(
                title: "步行/跑步距离",
                value: summary.totalDistanceWalkingRunning != nil ? String(format: "%.2f 公里", summary.totalDistanceWalkingRunning! / 1000) : "未获取数据",
                icon: "figure.walk.motion",
                color: .blue
            )
            
            // 详细距离数据
            if let dailyDistance = summary.dailyDistanceWalkingRunning, !dailyDistance.isEmpty {
                DailyDataView(
                    title: "每日距离",
                    data: dailyDistance,
                    valueFormatter: { String(format: "%.2f 公里", $0 / 1000) }
                )
            }
        }
    }
}

// 爬楼数据区域
struct FlightsClimbedDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：爬楼
            HealthDataCard(
                title: "爬楼层数",
                value: summary.totalFlightsClimbed != nil ? "\(Int(summary.totalFlightsClimbed!)) 层" : "未获取数据",
                icon: "stairs",
                color: .orange
            )
            
            // 详细爬楼数据
            if let dailyFlights = summary.dailyFlightsClimbed, !dailyFlights.isEmpty {
                DailyDataView(
                    title: "每日爬楼",
                    data: dailyFlights,
                    valueFormatter: { "\(Int($0)) 层" }
                )
            }
        }
    }
}

// 锻炼时间数据区域
struct ExerciseTimeDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：锻炼时间
            HealthDataCard(
                title: "锻炼时间",
                value: summary.totalExerciseTime != nil ? formatDuration(summary.totalExerciseTime!) : "未获取数据",
                icon: "figure.mixed.cardio",
                color: .green
            )
            
            // 详细锻炼时间数据
            if let dailyExercise = summary.dailyExerciseTime, !dailyExercise.isEmpty {
                DailyDataView(
                    title: "每日锻炼",
                    data: dailyExercise,
                    valueFormatter: { formatDuration($0) }
                )
            }
        }
    }
    
    // 格式化持续时间
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// 静息心率数据区域
struct RestingHeartRateDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：静息心率
            HealthDataCard(
                title: "平均静息心率",
                value: summary.averageRestingHeartRate != nil ? "\(Int(summary.averageRestingHeartRate!)) 次/分钟" : "未获取数据",
                icon: "heart.fill",
                color: .pink
            )
            
            // 详细静息心率数据
            if let dailyRestingHeartRate = summary.dailyRestingHeartRate, !dailyRestingHeartRate.isEmpty {
                DailyDataView(
                    title: "每日静息心率",
                    data: dailyRestingHeartRate,
                    valueFormatter: { "\(Int($0)) 次/分钟" }
                )
            }
        }
    }
}

// 呼吸率数据区域
struct RespiratoryRateDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：呼吸率
            HealthDataCard(
                title: "平均呼吸率",
                value: summary.averageRespiratoryRate != nil ? "\(Int(summary.averageRespiratoryRate!)) 次/分钟" : "未获取数据",
                icon: "lungs.fill",
                color: .cyan
            )
            
            // 详细呼吸率数据
            if let dailyRespiratoryRate = summary.dailyRespiratoryRate, !dailyRespiratoryRate.isEmpty {
                DailyDataView(
                    title: "每日呼吸率",
                    data: dailyRespiratoryRate,
                    valueFormatter: { "\(Int($0)) 次/分钟" }
                )
            }
        }
    }
}

// 血氧数据区域
struct OxygenSaturationDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：血氧
            HealthDataCard(
                title: "平均血氧饱和度",
                value: summary.averageOxygenSaturation != nil ? String(format: "%.1f%%", summary.averageOxygenSaturation! * 100) : "未获取数据",
                icon: "drop.fill",
                color: .blue
            )
            
            // 详细血氧数据
            if let dailyOxygenSaturation = summary.dailyOxygenSaturation, !dailyOxygenSaturation.isEmpty {
                DailyDataView(
                    title: "每日血氧",
                    data: dailyOxygenSaturation,
                    valueFormatter: { String(format: "%.1f%%", $0 * 100) }
                )
            }
        }
    }
}

// 血压数据区域
struct BloodPressureDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：血压 - 使用平均值
            let avgSystolic = summary.averageBloodPressureSystolic
            let avgDiastolic = summary.averageBloodPressureDiastolic
            
            let bloodPressureText = (avgSystolic != nil && avgDiastolic != nil) ? 
                "\(Int(avgSystolic!))/\(Int(avgDiastolic!)) mmHg" : "未获取数据"
            
            HealthDataCard(
                title: "平均血压",
                value: bloodPressureText,
                icon: "waveform.path.ecg",
                color: .red
            )
            
            // 详细血压数据
            if let dailyBloodPressure = summary.dailyBloodPressure, !dailyBloodPressure.isEmpty {
                DailyDataView(
                    title: "每日血压",
                    data: dailyBloodPressure.mapValues { $0.systolic },
                    valueFormatter: { bp in
                        if let systolic = summary.dailyBloodPressure?[bp.key]?.systolic,
                           let diastolic = summary.dailyBloodPressure?[bp.key]?.diastolic {
                            return "\(Int(systolic))/\(Int(diastolic)) mmHg"
                        } else {
                            return "无数据"
                        }
                    }
                )
            }
        }
    }
}

// 体温数据区域
struct BodyTemperatureDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：体温
            HealthDataCard(
                title: "平均体温",
                value: summary.averageBodyTemperature != nil ? String(format: "%.1f°C", summary.averageBodyTemperature!) : "未获取数据",
                icon: "thermometer",
                color: .orange
            )
            
            // 详细体温数据
            if let dailyBodyTemperature = summary.dailyBodyTemperature, !dailyBodyTemperature.isEmpty {
                DailyDataView(
                    title: "每日体温",
                    data: dailyBodyTemperature,
                    valueFormatter: { String(format: "%.1f°C", $0) }
                )
            }
        }
    }
}

// 体重数据区域
struct BodyMassDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：体重
            HealthDataCard(
                title: "平均体重",
                value: summary.averageBodyMass != nil ? String(format: "%.1f kg", summary.averageBodyMass!) : "未获取数据",
                icon: "scalemass.fill",
                color: .blue
            )
            
            // 详细体重数据
            if let dailyBodyMass = summary.dailyBodyMass, !dailyBodyMass.isEmpty {
                DailyDataView(
                    title: "每日体重",
                    data: dailyBodyMass,
                    valueFormatter: { String(format: "%.1f kg", $0) }
                )
            }
        }
    }
}

// BMI数据区域
struct BodyMassIndexDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：BMI
            HealthDataCard(
                title: "平均BMI",
                value: summary.averageBodyMassIndex != nil ? String(format: "%.1f", summary.averageBodyMassIndex!) : "未获取数据",
                icon: "person.fill",
                color: .purple
            )
            
            // 详细BMI数据
            if let dailyBodyMassIndex = summary.dailyBodyMassIndex, !dailyBodyMassIndex.isEmpty {
                DailyDataView(
                    title: "每日BMI",
                    data: dailyBodyMassIndex,
                    valueFormatter: { String(format: "%.1f", $0) }
                )
            }
        }
    }
}

// 体脂率数据区域
struct BodyFatDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：体脂率
            HealthDataCard(
                title: "平均体脂率",
                value: summary.averageBodyFatPercentage != nil ? String(format: "%.1f%%", summary.averageBodyFatPercentage! * 100) : "未获取数据",
                icon: "figure.arms.open",
                color: .orange
            )
            
            // 详细体脂率数据
            if let dailyBodyFatPercentage = summary.dailyBodyFatPercentage, !dailyBodyFatPercentage.isEmpty {
                DailyDataView(
                    title: "每日体脂率",
                    data: dailyBodyFatPercentage,
                    valueFormatter: { String(format: "%.1f%%", $0 * 100) }
                )
            }
        }
    }
}

// 饮食能量数据区域
struct DietaryEnergyDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：摄入能量
            HealthDataCard(
                title: "总摄入能量",
                value: summary.totalDietaryEnergy != nil ? "\(Int(summary.totalDietaryEnergy!)) 千卡" : "未获取数据",
                icon: "fork.knife",
                color: .green
            )
            
            // 详细摄入能量数据
            if let dailyDietaryEnergy = summary.dailyDietaryEnergy, !dailyDietaryEnergy.isEmpty {
                DailyDataView(
                    title: "每日摄入能量",
                    data: dailyDietaryEnergy,
                    valueFormatter: { "\(Int($0)) 千卡" }
                )
            }
        }
    }
}

// 饮水数据区域
struct DietaryWaterDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(spacing: 10) {
            // 卡片：饮水量
            HealthDataCard(
                title: "总饮水量",
                value: summary.totalDietaryWater != nil ? String(format: "%.1f 升", summary.totalDietaryWater! / 1000) : "未获取数据",
                icon: "drop.fill",
                color: .cyan
            )
            
            // 详细饮水量数据
            if let dailyDietaryWater = summary.dailyDietaryWater, !dailyDietaryWater.isEmpty {
                DailyDataView(
                    title: "每日饮水量",
                    data: dailyDietaryWater,
                    valueFormatter: { String(format: "%.1f 升", $0 / 1000) }
                )
            }
        }
    }
} 