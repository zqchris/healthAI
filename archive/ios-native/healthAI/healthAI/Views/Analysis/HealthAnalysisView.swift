import SwiftUI

struct HealthAnalysisView: View {
    @ObservedObject private var healthDataService = HealthDataService.shared
    @State private var healthScore: Int = 0
    @State private var selectedTimeRange: TimeRange = .twoWeeks
    @State private var isLoading = true
    @State private var showingRefreshIndicator = false
    
    // 时间范围枚举
    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "一周"
        case twoWeeks = "两周"
        case month = "一个月"
        
        var id: String { self.rawValue }
        
        // 计算对应的天数
        var days: Int {
            switch self {
            case .week: return 7
            case .twoWeeks: return 14
            case .month: return 30
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 时间范围选择
                Picker("时间范围", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onChange(of: selectedTimeRange) { newValue in
                    loadData(forceUpdate: true)
                }
                
                if isLoading {
                    ProgressView("加载健康数据...")
                        .padding()
                } else if let errorMessage = healthDataService.errorMessage {
                    // 这里之前有ErrorView的定义，现在已移至SharedViews.swift
                    ErrorView(errorMessage: errorMessage) {
                        loadData(forceUpdate: true)
                    }
                } else if let summary = healthDataService.healthSummary {
                    // 健康评分卡片
                    HealthScoreCard(score: healthScore)
                    
                    // 各维度健康分析
                    if let dailySteps = summary.dailySteps, !dailySteps.isEmpty {
                        ActivityAnalysisCard(summary: summary)
                    }
                    
                    if let sleepDetails = summary.sleepDetails, !sleepDetails.isEmpty {
                        SleepAnalysisCard(summary: summary)
                    }
                    
                    if let dailyHeartRate = summary.dailyHeartRate, !dailyHeartRate.isEmpty {
                        HeartRateAnalysisCard(summary: summary)
                    }
                    
                    // 健康状况综合分析
                    HealthSummaryCard(summary: summary, score: healthScore)
                    
                    // 上次更新时间
                    if let lastSync = healthDataService.lastSyncDate {
                        Text("上次更新: \(formatDate(lastSync))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // 这里之前有NoDataView的定义，现在已移至SharedViews.swift
                    NoDataView {
                        loadData(forceUpdate: true)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("健康分析")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingRefreshIndicator = true
                    loadData(forceUpdate: true)
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading || showingRefreshIndicator)
            }
        }
        .onAppear {
            loadData()
        }
        .onChange(of: healthDataService.healthSummary) { newValue in
            if let summary = newValue {
                calculateHealthScore(summary: summary)
            }
        }
    }
    
    // 加载数据
    private func loadData(forceUpdate: Bool = false) {
        isLoading = true
        
        // 获取对应时间范围的开始日期
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate
        
        // 从本地数据库获取指定时间范围的数据
        healthDataService.getHealthData(from: startDate, to: endDate) { summary in
            if let summary = summary {
                DispatchQueue.main.async {
                    healthDataService.healthSummary = summary
                    isLoading = false
                    showingRefreshIndicator = false
                }
            } else {
                // 如果本地没有数据，尝试从HealthKit获取
                healthDataService.loadHealthData(forceUpdate: forceUpdate)
                
                // 在加载完成后更新状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoading = healthDataService.isLoading
                    showingRefreshIndicator = false
                }
            }
        }
    }
    
    // 计算健康评分
    private func calculateHealthScore(summary: HealthDataSummary) {
        self.healthScore = healthDataService.calculateHealthScore(from: summary)
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// 健康评分卡片
struct HealthScoreCard: View {
    let score: Int
    
    var body: some View {
        VStack(spacing: 10) {
            Text("健康评分")
                .font(.headline)
            
            ZStack {
                Circle()
                    .stroke(
                        Color.gray.opacity(0.2),
                        lineWidth: 15
                    )
                
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(
                            lineWidth: 15,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: score)
                
                VStack {
                    Text("\(score)")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                    
                    Text(scoreEvaluation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 200, height: 200)
            .padding()
        }
        .padding()
        .cardStyle()
    }
    
    // 根据分数返回颜色
    private var scoreColor: Color {
        ThemeManager.DataColors.healthScore(score)
    }
    
    // 根据分数返回评价
    private var scoreEvaluation: String {
        switch score {
        case 0..<40: return "需要改善"
        case 40..<70: return "一般"
        case 70..<90: return "良好"
        default: return "优秀"
        }
    }
}

// 活动分析卡片
struct ActivityAnalysisCard: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "figure.walk")
                    .font(.title2)
                    .foregroundColor(Color.green)
                
                Text("活动分析")
                    .font(.headline)
                
                Spacer()
            }
            
            Divider()
            
            if let dailySteps = summary.dailySteps, !dailySteps.isEmpty {
                // 计算平均步数
                let totalSteps = dailySteps.values.reduce(0, +)
                let avgSteps = totalSteps / Double(dailySteps.count)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("平均步数")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(avgSteps)) 步/天")
                            .font(.title3)
                            .bold()
                    }
                    
                    Spacer()
                    
                    // 步数评价
                    Text(stepEvaluation(avgSteps))
                        .font(.subheadline)
                        .padding(8)
                        .background(stepEvaluationColor(avgSteps).opacity(0.2))
                        .foregroundColor(stepEvaluationColor(avgSteps))
                        .cornerRadius(8)
                }
                
                // 活动趋势分析
                if dailySteps.count > 1 {
                    let trend = calculateStepTrend(dailySteps)
                    
                    HStack {
                        Text("活动趋势:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(trend.description)
                            .font(.subheadline)
                            .foregroundColor(trend.color)
                        
                        Image(systemName: trend.icon)
                            .foregroundColor(trend.color)
                    }
                }
            }
            
            if let dailyEnergy = summary.dailyActiveEnergy, !dailyEnergy.isEmpty {
                Divider()
                
                // 计算平均消耗能量
                let totalEnergy = dailyEnergy.values.reduce(0, +)
                let avgEnergy = totalEnergy / Double(dailyEnergy.count)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("平均活动能量")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(avgEnergy)) 千卡/天")
                            .font(.title3)
                            .bold()
                    }
                    
                    Spacer()
                    
                    // 能量消耗评价
                    Text(energyEvaluation(avgEnergy))
                        .font(.subheadline)
                        .padding(8)
                        .background(energyEvaluationColor(avgEnergy).opacity(0.2))
                        .foregroundColor(energyEvaluationColor(avgEnergy))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .cardStyle()
    }
    
    // 步数评价
    private func stepEvaluation(_ steps: Double) -> String {
        switch steps {
        case 0..<3000: return "活动不足"
        case 3000..<7500: return "基本活动"
        case 7500..<10000: return "活动良好"
        default: return "活动充分"
        }
    }
    
    // 步数评价颜色
    private func stepEvaluationColor(_ steps: Double) -> Color {
        switch steps {
        case 0..<3000: return .red
        case 3000..<7500: return .orange
        case 7500..<10000: return .blue
        default: return .green
        }
    }
    
    // 能量评价
    private func energyEvaluation(_ energy: Double) -> String {
        switch energy {
        case 0..<100: return "活动不足"
        case 100..<300: return "基本活动"
        case 300..<500: return "活动良好"
        default: return "活动充分"
        }
    }
    
    // 能量评价颜色
    private func energyEvaluationColor(_ energy: Double) -> Color {
        switch energy {
        case 0..<100: return .red
        case 100..<300: return .orange
        case 300..<500: return .blue
        default: return .green
        }
    }
    
    // 计算步数趋势：比较前后时间段的平均步数
    private func calculateStepTrend(_ dailySteps: [Date: Double]) -> (description: String, color: Color, icon: String) {
        let sortedData = dailySteps.sorted(by: { $0.key < $1.key })
        
        // 如果只有一天数据，无法判断趋势
        if sortedData.count <= 1 {
            return ("数据不足", .gray, "minus")
        }
        
        // 计算前半部分和后半部分的平均值
        let midIndex = sortedData.count / 2
        let firstHalf = sortedData[0..<midIndex]
        let secondHalf = sortedData[midIndex..<sortedData.count]
        
        let firstHalfAvg = firstHalf.map({ $0.value }).reduce(0, +) / Double(firstHalf.count)
        let secondHalfAvg = secondHalf.map({ $0.value }).reduce(0, +) / Double(secondHalf.count)
        
        // 计算变化百分比
        let percentChange = (secondHalfAvg - firstHalfAvg) / firstHalfAvg * 100
        
        // 根据变化返回趋势
        if abs(percentChange) < 5 {
            return ("保持稳定", .blue, "equal")
        } else if percentChange > 0 {
            return ("上升趋势", .green, "arrow.up")
        } else {
            return ("下降趋势", .red, "arrow.down")
        }
    }
}

// 睡眠分析卡片
struct SleepAnalysisCard: View {
    let summary: HealthDataSummary
    
    // 计算平均睡眠时间
    private var averageSleepTime: TimeInterval {
        if let sleepDetails = summary.sleepDetails, !sleepDetails.isEmpty {
            var totalSleep: TimeInterval = 0
            for (_, detail) in sleepDetails {
                if let duration = detail.asleepDuration {
                    totalSleep += duration
                }
            }
            return totalSleep / Double(sleepDetails.count)
        }
        return 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .font(.title2)
                    .foregroundColor(Color.blue)
                
                Text("睡眠分析")
                    .font(.headline)
                
                Spacer()
            }
            
            Divider()
            
            if let sleepDetails = summary.sleepDetails, !sleepDetails.isEmpty {
                // 使用计算属性中的平均睡眠时间
                let avgSleep = averageSleepTime
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("平均睡眠时间")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(formatDuration(avgSleep))
                            .font(.title3)
                            .bold()
                    }
                    
                    Spacer()
                    
                    // 睡眠评价
                    Text(sleepEvaluation(avgSleep))
                        .font(.subheadline)
                        .padding(8)
                        .background(sleepEvaluationColor(avgSleep).opacity(0.2))
                        .foregroundColor(sleepEvaluationColor(avgSleep))
                        .cornerRadius(8)
                }
                
                // 睡眠质量分析
                if let avgDetail = calculateAverageSleepDetail(sleepDetails) {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("睡眠质量分析")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let sleepEfficiency = avgDetail.sleepEfficiency {
                            HStack {
                                Text("睡眠效率:")
                                    .font(.subheadline)
                                
                                Text("\(Int(sleepEfficiency))%")
                                    .font(.subheadline)
                                    .bold()
                                
                                Spacer()
                                
                                // 睡眠效率评价
                                Text(sleepEfficiencyEvaluation(sleepEfficiency))
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(sleepEfficiencyColor(sleepEfficiency).opacity(0.2))
                                    .foregroundColor(sleepEfficiencyColor(sleepEfficiency))
                                    .cornerRadius(4)
                            }
                        }
                        
                        // 睡眠阶段分布
                        if let deep = avgDetail.deepSleepDuration,
                           let rem = avgDetail.remSleepDuration,
                           let core = avgDetail.coreSleepDuration,
                           let total = avgDetail.asleepDuration, total > 0 {
                            
                            let deepPercent = deep / total * 100
                            let remPercent = rem / total * 100
                            let corePercent = core / total * 100
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("睡眠阶段分布:")
                                    .font(.subheadline)
                                
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.purple)
                                        .frame(width: max(30, CGFloat(deepPercent) * 2), height: 18)
                                        .overlay(
                                            Text("\(Int(deepPercent))%")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                        )
                                    
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: max(30, CGFloat(remPercent) * 2), height: 18)
                                        .overlay(
                                            Text("\(Int(remPercent))%")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                        )
                                    
                                    Rectangle()
                                        .fill(Color.cyan)
                                        .frame(width: max(30, CGFloat(corePercent) * 2), height: 18)
                                        .overlay(
                                            Text("\(Int(corePercent))%")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                        )
                                }
                                .cornerRadius(4)
                                
                                HStack {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.purple)
                                            .frame(width: 8, height: 8)
                                        Text("深睡")
                                            .font(.caption2)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 8, height: 8)
                                        Text("REM")
                                            .font(.caption2)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.cyan)
                                            .frame(width: 8, height: 8)
                                        Text("核心睡眠")
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .cardStyle()
    }
    
    // 计算平均睡眠详情：汇总所有日期的睡眠数据并计算各项指标的平均值
    private func calculateAverageSleepDetail(_ sleepDetails: [Date: SleepDetail]) -> SleepDetail? {
        var result = SleepDetail()
        var asleepCount = 0
        var inBedCount = 0
        var deepCount = 0
        var remCount = 0
        var coreCount = 0
        var efficiencyCount = 0
        var wakeCount = 0
        var heartRateCount = 0
        var respiratoryRateCount = 0
        var temperatureCount = 0
        
        for (_, detail) in sleepDetails {
            if let asleep = detail.asleepDuration {
                result.asleepDuration = (result.asleepDuration ?? 0) + asleep
                asleepCount += 1
            }
            
            if let inBed = detail.inBedDuration {
                result.inBedDuration = (result.inBedDuration ?? 0) + inBed
                inBedCount += 1
            }
            
            if let deep = detail.deepSleepDuration {
                result.deepSleepDuration = (result.deepSleepDuration ?? 0) + deep
                deepCount += 1
            }
            
            if let rem = detail.remSleepDuration {
                result.remSleepDuration = (result.remSleepDuration ?? 0) + rem
                remCount += 1
            }
            
            if let core = detail.coreSleepDuration {
                result.coreSleepDuration = (result.coreSleepDuration ?? 0) + core
                coreCount += 1
            }
            
            if let efficiency = detail.sleepEfficiency {
                result.sleepEfficiency = (result.sleepEfficiency ?? 0) + efficiency
                efficiencyCount += 1
            }
            
            if let wake = detail.wakeCount {
                result.wakeCount = (result.wakeCount ?? 0) + wake
                wakeCount += 1
            }
            
            if let hr = detail.sleepHeartRate {
                result.sleepHeartRate = (result.sleepHeartRate ?? 0) + hr
                heartRateCount += 1
            }
            
            if let rr = detail.sleepRespiratoryRate {
                result.sleepRespiratoryRate = (result.sleepRespiratoryRate ?? 0) + rr
                respiratoryRateCount += 1
            }
            
            if let temp = detail.sleepBodyTemperature {
                result.sleepBodyTemperature = (result.sleepBodyTemperature ?? 0) + temp
                temperatureCount += 1
            }
        }
        
        // 计算平均值
        if asleepCount > 0 {
            result.asleepDuration = result.asleepDuration! / Double(asleepCount)
        }
        
        if inBedCount > 0 {
            result.inBedDuration = result.inBedDuration! / Double(inBedCount)
        }
        
        if deepCount > 0 {
            result.deepSleepDuration = result.deepSleepDuration! / Double(deepCount)
        }
        
        if remCount > 0 {
            result.remSleepDuration = result.remSleepDuration! / Double(remCount)
        }
        
        if coreCount > 0 {
            result.coreSleepDuration = result.coreSleepDuration! / Double(coreCount)
        }
        
        if efficiencyCount > 0 {
            result.sleepEfficiency = result.sleepEfficiency! / Double(efficiencyCount)
        }
        
        if wakeCount > 0 {
            result.wakeCount = result.wakeCount! / wakeCount
        }
        
        if heartRateCount > 0 {
            result.sleepHeartRate = result.sleepHeartRate! / Double(heartRateCount)
        }
        
        if respiratoryRateCount > 0 {
            result.sleepRespiratoryRate = result.sleepRespiratoryRate! / Double(respiratoryRateCount)
        }
        
        if temperatureCount > 0 {
            result.sleepBodyTemperature = result.sleepBodyTemperature! / Double(temperatureCount)
        }
        
        return result
    }
    
    // 睡眠评价
    private func sleepEvaluation(_ duration: TimeInterval) -> String {
        let hours = duration / 3600
        switch hours {
        case 0..<5: return "睡眠不足"
        case 5..<7: return "睡眠偏少"
        case 7...9: return "睡眠充足"
        default: return "睡眠过多"
        }
    }
    
    // 睡眠评价颜色
    private func sleepEvaluationColor(_ duration: TimeInterval) -> Color {
        let hours = duration / 3600
        switch hours {
        case 0..<5: return .red
        case 5..<7: return .orange
        case 7...9: return .green
        default: return .orange
        }
    }
    
    // 睡眠效率评价
    private func sleepEfficiencyEvaluation(_ efficiency: Double) -> String {
        switch efficiency {
        case 0..<70: return "较差"
        case 70..<80: return "一般"
        case 80..<90: return "良好"
        default: return "优秀"
        }
    }
    
    // 睡眠效率颜色
    private func sleepEfficiencyColor(_ efficiency: Double) -> Color {
        switch efficiency {
        case 0..<70: return .red
        case 70..<80: return .orange
        case 80..<90: return .blue
        default: return .green
        }
    }
    
    // 格式化持续时间：将 TimeInterval 转换为 "X小时Y分钟" 格式的字符串
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)小时\(minutes)分钟"
    }
}

// 心率分析卡片
struct HeartRateAnalysisCard: View {
    let summary: HealthDataSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundColor(Color.red)
                
                Text("心率分析")
                    .font(.headline)
                
                Spacer()
            }
            
            Divider()
            
            if let heartRate = summary.averageHeartRate {
                HStack {
                    VStack(alignment: .leading) {
                        Text("平均静息心率")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(heartRate)) 次/分钟")
                            .font(.title3)
                            .bold()
                    }
                    
                    Spacer()
                    
                    // 心率评价
                    Text(heartRateEvaluation(heartRate))
                        .font(.subheadline)
                        .padding(8)
                        .background(heartRateEvaluationColor(heartRate).opacity(0.2))
                        .foregroundColor(heartRateEvaluationColor(heartRate))
                        .cornerRadius(8)
                }
                
                Divider()
                
                // 心率风险评估
                VStack(alignment: .leading, spacing: 8) {
                    Text("心率状况评估:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(heartRateRiskAssessment(heartRate))
                        .font(.body)
                }
            }
        }
        .padding()
        .cardStyle()
    }
    
    // 心率评价
    private func heartRateEvaluation(_ rate: Double) -> String {
        switch rate {
        case 0..<50: return "心率过缓"
        case 50..<60: return "心率偏低"
        case 60...100: return "心率正常"
        default: return "心率偏快"
        }
    }
    
    // 心率评价颜色
    private func heartRateEvaluationColor(_ rate: Double) -> Color {
        switch rate {
        case 0..<50: return .purple
        case 50..<60: return .blue
        case 60...100: return .green
        default: return .orange
        }
    }
    
    // 心率风险评估：根据静息心率提供健康状况描述
    private func heartRateRiskAssessment(_ rate: Double) -> String {
        switch rate {
        case 0..<50:
            return "您的平均静息心率偏低，可能表示良好的心肺功能，但也可能与某些健康问题相关。如果您感到头晕、疲劳或无力，建议咨询医生。"
        case 50..<60:
            return "您的平均静息心率较低，对于经常锻炼的人来说是正常的，表示良好的心肺功能。保持规律的生活方式和锻炼习惯。"
        case 60...100:
            return "您的平均静息心率处于健康范围内，表明心脏功能良好。继续保持健康的生活方式和定期运动。"
        case 100...110:
            return "您的平均静息心率略高，可能与压力、咖啡因摄入或缺乏运动有关。建议增加有氧运动并注意休息。"
        default:
            return "您的平均静息心率偏高，长期处于这一水平可能增加心血管疾病风险。建议咨询医生，并考虑生活方式的调整。"
        }
    }
}

// 健康综合分析卡片
struct HealthSummaryCard: View {
    let summary: HealthDataSummary
    let score: Int
    
    // 计算睡眠部分数据
    private var averageSleepData: (hours: Double, description: String)? {
        if let sleepDetails = summary.sleepDetails, !sleepDetails.isEmpty {
            var totalSleep: TimeInterval = 0
            for (_, detail) in sleepDetails {
                if let duration = detail.asleepDuration {
                    totalSleep += duration
                }
            }
            let avgSleep = totalSleep / Double(sleepDetails.count)
            let sleepHours = avgSleep / 3600
            
            let description: String
            if sleepHours < 6 {
                description = "睡眠时间不足，可能影响日间精力和长期健康。"
            } else if sleepHours < 7 {
                description = "睡眠时间略低于推荐水平，建议适当增加。"
            } else if sleepHours <= 9 {
                description = "睡眠时长理想，有助于身体恢复和心理健康。"
            } else {
                description = "睡眠时间较长，虽然充足的睡眠很重要，但过长的睡眠也可能与某些健康问题相关。"
            }
            
            return (sleepHours, description)
        }
        return nil
    }
    
    // 预先计算推荐数组
    private var recommendations: [String] {
        return generateRecommendations()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(.indigo)
                
                Text("健康综合分析")
                    .font(.headline)
                
                Spacer()
            }
            
            Divider()
            
            Text(generateHealthSummary())
                .font(.body)
                .lineSpacing(4)
            
            Divider()
            
            Text("改善建议")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ForEach(recommendations, id: \.self) { recommendation in
                HStack(alignment: .top) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text(recommendation)
                        .font(.body)
                }
                .padding(.vertical, 3)
            }
        }
        .padding()
        .cardStyle()
    }
    
    // 生成健康总结：根据各项健康指标（评分、步数、睡眠、心率）生成一段综合性的描述文字
    private func generateHealthSummary() -> String {
        var summaryParts: [String] = []
        
        // 综合评分部分
        let scoreDescription: String
        switch score {
        case 0..<40:
            scoreDescription = "您的健康状况需要改善，多项健康指标未达到理想水平。"
        case 40..<70:
            scoreDescription = "您的健康状况一般，部分健康指标良好，但仍有改善空间。"
        case 70..<90:
            scoreDescription = "您的健康状况良好，大部分健康指标处于理想水平。"
        default:
            scoreDescription = "您的健康状况优秀，各项健康指标均处于理想水平。"
        }
        summaryParts.append(scoreDescription)
        
        // 步数部分
        if let dailySteps = summary.dailySteps, !dailySteps.isEmpty {
            let totalSteps = dailySteps.values.reduce(0, +)
            let avgSteps = totalSteps / Double(dailySteps.count)
            let stepsDescription: String
            
            if avgSteps < 5000 {
                stepsDescription = "日均步数较少，建议增加日常活动量。"
            } else if avgSteps < 10000 {
                stepsDescription = "日均步数适中，可以进一步增加活动量以获得更好的健康效益。"
            } else {
                stepsDescription = "日均步数充足，保持良好的活动水平。"
            }
            summaryParts.append(stepsDescription)
        }
        
        // 睡眠部分
        if let sleepData = averageSleepData {
            summaryParts.append(sleepData.description)
        }
        
        // 心率部分
        if let heartRate = summary.averageHeartRate {
            let heartRateDescription: String
            if heartRate < 50 {
                heartRateDescription = "静息心率较低，对于训练有素的运动员可能是正常的，但对普通人可能需要关注。"
            } else if heartRate < 60 {
                heartRateDescription = "静息心率良好，表明心肺功能较强。"
            } else if heartRate <= 100 {
                heartRateDescription = "静息心率在正常范围内。"
            } else {
                heartRateDescription = "静息心率偏高，可能与压力、缺乏运动或其他因素有关。"
            }
            summaryParts.append(heartRateDescription)
        }
        
        return summaryParts.joined(separator: " ")
    }
    
    // 生成健康建议：根据各项健康指标的具体数值，生成个性化的改善建议列表
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        // 步数建议
        if let dailySteps = summary.dailySteps, !dailySteps.isEmpty {
            let totalSteps = dailySteps.values.reduce(0, +)
            let avgSteps = totalSteps / Double(dailySteps.count)
            
            if avgSteps < 5000 {
                recommendations.append("每天尝试达到至少7,000步，可以通过散步、爬楼梯或简单家务活动增加步数")
            } else if avgSteps < 7500 {
                recommendations.append("逐步增加日常步行量，目标达到10,000步/天")
            } else if avgSteps < 10000 {
                recommendations.append("保持当前活动水平，并考虑增加中高强度活动")
            }
        }
        
        // 睡眠建议
        if let sleepData = averageSleepData {
            let sleepHours = sleepData.hours
            
            if sleepHours < 7 {
                recommendations.append("建立规律的睡眠习惯，每晚保证7-8小时的睡眠时间")
                recommendations.append("睡前一小时避免使用电子设备，创造安静、黑暗的睡眠环境")
            } else if sleepHours > 9 {
                recommendations.append("尝试保持更规律的睡眠时间，避免在周末过度补眠")
            }
            
            // 检查深度睡眠
            if let sleepDetails = summary.sleepDetails {
                let avgSleepDetail = calculateAverageSleepDetail(sleepDetails)
                if let deepSleep = avgSleepDetail?.deepSleepDuration,
                   let total = avgSleepDetail?.asleepDuration, total > 0 {
                    let deepSleepPercent = deepSleep / total * 100
                    if deepSleepPercent < 10 {
                        recommendations.append("提高睡眠质量，考虑白天适当运动，睡前避免咖啡因和酒精")
                    }
                }
            }
        }
        
        // 心率建议
        if let heartRate = summary.averageHeartRate {
            if heartRate > 80 {
                recommendations.append("定期进行有氧运动，如快走、游泳或骑车，帮助降低静息心率")
                recommendations.append("学习并实践放松技巧，如深呼吸或冥想，以减轻压力")
            } else if heartRate < 50 && heartRate > 40 {
                recommendations.append("关注并记录任何可能的症状，如疲劳或头晕")
            } else if heartRate <= 40 {
                recommendations.append("咨询医疗专业人士，评估心率偏低的原因")
            }
        }
        
        // 如果没有足够建议，添加一些通用建议
        if recommendations.isEmpty {
            recommendations.append("每天保持至少30分钟中等强度的体力活动")
            recommendations.append("保持均衡饮食，多摄入蔬菜、水果和全谷物")
            recommendations.append("确保充足睡眠和适当休息，减少压力")
            recommendations.append("每年进行一次全面体检")
        }
        
        return recommendations
    }
    
    // 计算平均睡眠详情（此为 HealthSummaryCard 内部版本，仅关注总睡眠和深度睡眠用于推荐）
    private func calculateAverageSleepDetail(_ sleepDetails: [Date: SleepDetail]) -> SleepDetail? {
        var result = SleepDetail()
        var asleepCount = 0
        var deepCount = 0
        
        for (_, detail) in sleepDetails {
            if let asleep = detail.asleepDuration {
                result.asleepDuration = (result.asleepDuration ?? 0) + asleep
                asleepCount += 1
            }
            
            if let deep = detail.deepSleepDuration {
                result.deepSleepDuration = (result.deepSleepDuration ?? 0) + deep
                deepCount += 1
            }
        }
        
        // 计算平均值
        if asleepCount > 0 {
            result.asleepDuration = result.asleepDuration! / Double(asleepCount)
        }
        
        if deepCount > 0 {
            result.deepSleepDuration = result.deepSleepDuration! / Double(deepCount)
        }
        
        return result
    }
} 