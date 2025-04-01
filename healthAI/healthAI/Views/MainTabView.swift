import SwiftUI
import HealthKit

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        TabView(selection: $selectedTab) {
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
            }
            .tabItem {
                Label("健康顾问", systemImage: "heart.text.square")
            }
            .tag(0)
            
            // 健康数据标签
            NavigationStack {
                HealthDataView()
                    .navigationTitle("健康数据")
            }
            .tabItem {
                Label("健康数据", systemImage: "heart.circle")
            }
            .tag(1)
            
            // 分析标签
            Text("分析")
                .tabItem {
                    Label("分析", systemImage: "chart.bar")
                }
                .tag(2)
            
            // 我的标签
            Text("我的")
                .tabItem {
                    Label("我的", systemImage: "person.circle")
                }
                .tag(3)
        }
        .onAppear {
            // 设置UI界面外观
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().scrollEdgeAppearance = appearance
            
            // 移除无用的do-catch块，因为内部没有抛出错误
            // 直接初始化相关操作
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
}

// 新增：健康数据视图
struct HealthDataView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var healthSummary: HealthDataSummary?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if isLoading {
                LoadingView()
            } else if let error = errorMessage {
                ErrorView(error: error, retryAction: loadHealthData)
            } else if let summary = healthSummary {
                // 显示健康数据摘要
                HealthDataContentView(summary: summary)
            } else {
                NoDataView(loadAction: loadHealthData)
            }
        }
        .onAppear {
            loadHealthData()
        }
        .refreshable {
            loadHealthData()
        }
    }
    
    private func loadHealthData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 请求授权
                await withCheckedContinuation { continuation in
                    healthKitManager.requestAuthorization { success, error in
                        if let error = error {
                            print("健康数据授权失败: \(error)")
                        }
                        continuation.resume()
                    }
                }
                
                // 获取健康数据
                let summary = try await healthKitManager.fetchHealthData()
                
                // 在主线程更新UI
                DispatchQueue.main.async {
                    self.healthSummary = summary
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "获取健康数据失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
    
    private func formattedDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
}

// 加载中视图
struct LoadingView: View {
    var body: some View {
        ProgressView("正在加载健康数据...")
            .padding()
    }
}

// 错误视图
struct ErrorView: View {
    let error: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("加载健康数据时出错")
                .font(.headline)
            
            Text(error)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("重试") {
                retryAction()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// 无数据视图
struct NoDataView: View {
    let loadAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("未获取到健康数据")
                .font(.headline)
            
            Text("请确保您已在设置中授权此应用访问健康数据")
                .multilineTextAlignment(.center)
                .padding()
            
            Button("授权并获取数据") {
                loadAction()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
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
                // 标题
                Text("过去7天健康数据摘要")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top)
                
                // 步数卡片和详情
                StepsDataSection(summary: summary)
                
                // 心率卡片和详情
                HeartRateDataSection(summary: summary)
                
                // 活动能量卡片和详情
                EnergyDataSection(summary: summary)
                
                // 睡眠数据卡片和详情
                SleepDataSection(summary: summary)
                
                // 更新时间
                Text("数据更新时间: \(dateFormatter.string(from: Date()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom)
            }
            .padding()
        }
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
                color: .blue
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
                color: .red
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
                color: .orange
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
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            let sortedDays = data.keys.sorted()
            
            ForEach(sortedDays, id: \.self) { day in
                if let value = data[day] {
                    DailyDataRow(
                        day: day,
                        value: value,
                        dateFormatter: dateFormatter,
                        weekDayFormatter: weekDayFormatter,
                        valueFormatter: valueFormatter
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// 新增：每日数据行组件
struct DailyDataRow<T: Numeric>: View {
    let day: Date
    let value: T
    let dateFormatter: DateFormatter
    let weekDayFormatter: DateFormatter
    let valueFormatter: (T) -> String
    
    var body: some View {
        HStack {
            Text("\(dateFormatter.string(from: day)) (\(weekDayFormatter.string(from: day)))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(valueFormatter(value))
                .font(.subheadline)
                .foregroundColor(.primary)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

// 睡眠数据区域
struct SleepDataSection: View {
    let summary: HealthDataSummary
    
    var body: some View {
        // 卡片：睡眠数据
        VStack(alignment: .leading, spacing: 15) {
            Text("睡眠数据")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let avgSleep = summary.averageSleepDuration {
                AverageSleepView(avgSleep: avgSleep, sleepDetail: summary.averageSleepDetail)
                
                Divider()
                
                if let dailySleep = summary.dailySleep {
                    if dailySleep.isEmpty {
                        Text("未获取到每日睡眠详情数据")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    } else {
                        DailySleepDetailsView(dailySleep: dailySleep, sleepDetails: summary.sleepDetails)
                    }
                } else {
                    Text("未获取到每日睡眠详情数据")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            } else {
                Text("未获取到睡眠数据")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// 平均睡眠视图
struct AverageSleepView: View {
    let avgSleep: TimeInterval
    let sleepDetail: SleepDetail?
    
    var body: some View {
        VStack(spacing: 8) {
            let hours = Int(avgSleep / 3600)
            let minutes = Int((avgSleep.truncatingRemainder(dividingBy: 3600)) / 60)
            
            HStack {
                Text("平均每日睡眠:")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(hours)小时\(minutes)分钟")
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
            }
            
            // 添加睡眠阶段详情
            if let sleepDetail = sleepDetail {
                SleepStagesView(avgSleep: avgSleep, sleepDetail: sleepDetail)
            }
        }
    }
}

// 睡眠阶段视图
struct SleepStagesView: View {
    let avgSleep: TimeInterval
    let sleepDetail: SleepDetail
    
    var body: some View {
        VStack(spacing: 8) {
            if let deepSleep = sleepDetail.deepSleepDuration {
                SleepStageRow(
                    title: "深度睡眠:",
                    duration: deepSleep,
                    percentage: avgSleep > 0 ? (deepSleep / avgSleep) * 100 : 0
                )
            }
            
            if let remSleep = sleepDetail.remSleepDuration {
                SleepStageRow(
                    title: "REM睡眠:",
                    duration: remSleep,
                    percentage: avgSleep > 0 ? (remSleep / avgSleep) * 100 : 0
                )
            }
            
            if let coreSleep = sleepDetail.coreSleepDuration {
                SleepStageRow(
                    title: "核心睡眠:",
                    duration: coreSleep,
                    percentage: avgSleep > 0 ? (coreSleep / avgSleep) * 100 : 0
                )
            }
            
            if let efficiency = sleepDetail.sleepEfficiency {
                HStack {
                    Text("睡眠效率:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(efficiency))%")
                        .foregroundColor(.primary)
                }
            }
            
            if let wakeCount = sleepDetail.wakeCount, wakeCount > 0 {
                HStack {
                    Text("夜间醒来次数:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(wakeCount)次")
                        .foregroundColor(.primary)
                }
            }
            
            // 添加睡眠期间生理数据
            Divider()
            
            if let heartRate = sleepDetail.sleepHeartRate {
                HStack {
                    Text("睡眠心率:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(heartRate))次/分钟")
                        .foregroundColor(.primary)
                }
            }
            
            if let respiratoryRate = sleepDetail.sleepRespiratoryRate {
                HStack {
                    Text("睡眠呼吸率:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(respiratoryRate))次/分钟")
                        .foregroundColor(.primary)
                }
            }
            
            if let bodyTemperature = sleepDetail.sleepBodyTemperature {
                HStack {
                    Text("睡眠体温:")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f°C", bodyTemperature))
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

// 睡眠阶段行
struct SleepStageRow: View {
    let title: String
    let duration: TimeInterval
    let percentage: Double
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            
            Text("\(hours)小时\(minutes)分钟 (\(Int(percentage))%)")
                .foregroundColor(.primary)
        }
    }
}

// 每日睡眠详情视图
struct DailySleepDetailsView: View {
    let dailySleep: [Date: TimeInterval]
    let sleepDetails: [Date: SleepDetail]?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每日睡眠详情:")
                .foregroundColor(.secondary)
                .padding(.bottom, 5)
            
            // 按日期降序排序，最近的日期在前
            let sortedDays = dailySleep.keys.sorted(by: >)
            
            if sortedDays.isEmpty {
                Text("无可用睡眠数据")
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else {
                // 显示所有可用的睡眠数据
                ForEach(sortedDays, id: \.self) { day in
                    if let sleepTime = dailySleep[day] {
                        DailySleepRow(day: day, sleepTime: sleepTime, detail: sleepDetails?[day])
                    }
                }
            }
        }
    }
}

// 每日睡眠行
struct DailySleepRow: View {
    let day: Date
    let sleepTime: TimeInterval
    let detail: SleepDetail?
    
    // 将格式化器从body内部移到外部
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dayFormatter.string(from: day))
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                Spacer()
                
                let hours = Int(sleepTime / 3600)
                let minutes = Int((sleepTime.truncatingRemainder(dividingBy: 3600)) / 60)
                
                Text("\(hours)小时\(minutes)分钟")
                    .foregroundColor(.primary)
            }
            
            // 显示详细的睡眠阶段数据
            if let detail = detail {
                SleepStageTagsView(sleepTime: sleepTime, detail: detail)
                
                // 显示睡眠期间生理数据
                HStack(spacing: 8) {
                    if let heartRate = detail.sleepHeartRate {
                        PhysioDataTag(
                            title: "心率",
                            value: "\(Int(heartRate))次/分",
                            color: .red
                        )
                    }
                    
                    if let respiratoryRate = detail.sleepRespiratoryRate {
                        PhysioDataTag(
                            title: "呼吸率",
                            value: "\(Int(respiratoryRate))次/分",
                            color: .green
                        )
                    }
                    
                    if let bodyTemperature = detail.sleepBodyTemperature {
                        PhysioDataTag(
                            title: "体温",
                            value: String(format: "%.1f°C", bodyTemperature),
                            color: .orange
                        )
                    }
                    
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

// 睡眠阶段标签视图
struct SleepStageTagsView: View {
    let sleepTime: TimeInterval
    let detail: SleepDetail
    
    var body: some View {
        HStack(spacing: 4) {
            if let deep = detail.deepSleepDuration {
                SleepStageTag(
                    title: "深睡",
                    percentage: Int((deep / sleepTime) * 100),
                    color: .indigo
                )
            }
            
            if let rem = detail.remSleepDuration {
                SleepStageTag(
                    title: "REM",
                    percentage: Int((rem / sleepTime) * 100),
                    color: .blue
                )
            }
            
            if let core = detail.coreSleepDuration {
                SleepStageTag(
                    title: "核心",
                    percentage: Int((core / sleepTime) * 100),
                    color: .cyan
                )
            }
            
            Spacer()
        }
    }
}

// 睡眠阶段标签
struct SleepStageTag: View {
    let title: String
    let percentage: Int
    let color: Color
    
    var body: some View {
        Text("\(title):\(percentage)%")
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .cornerRadius(4)
    }
}

// 生理数据标签
struct PhysioDataTag: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption2)
                .foregroundColor(color)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

// 健康数据卡片组件
struct HealthDataCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
} 