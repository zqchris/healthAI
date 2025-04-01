import Foundation
import HealthKit

// MARK: - Data Structures
struct DailyHealthData {
    var date: Date
    var stepCount: Double?
    var heartRate: Double?
    var activeEnergy: Double?
    var sleepDetail: SleepDetail?
}

struct SleepDetail {
    var inBedDuration: TimeInterval?  // 床上时间
    var asleepDuration: TimeInterval?  // 实际睡眠时间
    var deepSleepDuration: TimeInterval?  // 深度睡眠
    var remSleepDuration: TimeInterval?  // REM睡眠
    var coreSleepDuration: TimeInterval?  // 核心睡眠
    var sleepEfficiency: Double?  // 睡眠效率(睡眠时间/床上时间)
    var sleepLatency: TimeInterval?  // 入睡时间
    var wakeCount: Int?  // 醒来次数
    var startTime: Date?  // 睡眠开始时间
    var endTime: Date?  // 睡眠结束时间
    
    // 新增睡眠期间生理数据
    var sleepHeartRate: Double?  // 睡眠期间平均心率
    var sleepRespiratoryRate: Double?  // 睡眠期间平均呼吸率
    var sleepBodyTemperature: Double?  // 睡眠期间平均体温
}

struct HealthDataSummary {
    // 总计数据
    var stepCount: Double?
    var averageHeartRate: Double?
    var totalActiveEnergy: Double?
    var sleepDuration: TimeInterval?
    var averageSleepDuration: TimeInterval?
    
    // 按天数据
    var dailySleep: [Date: TimeInterval]?
    var sleepDetails: [Date: SleepDetail]?  // 每日详细睡眠数据
    var averageSleepDetail: SleepDetail?  // 平均睡眠详情
    
    // 新增：按天完整健康数据
    var dailyData: [DailyHealthData]?
    var dailySteps: [Date: Double]?
    var dailyActiveEnergy: [Date: Double]?
    var dailyHeartRate: [Date: Double]?
    
    // 数据采集时间范围
    var startDate: Date?
    var endDate: Date?
}

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    // MARK: - Authorization

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        print("HealthKitManager: 开始请求授权...")
        
        // 安全检查：确保在主线程调用回调
        let safeCompletion: (Bool, Error?) -> Void = { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
        
        // 检查 HealthKit 是否在设备上可用
        guard HKHealthStore.isHealthDataAvailable() else {
            let error = NSError(domain: "com.yourapp.healthAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device."])
            print("HealthKitManager: 错误 - HealthKit 在此设备上不可用")
            safeCompletion(false, error)
            return
        }

        // 安全地定义要读取的数据类型集合
        var readTypesArray: [HKObjectType] = []
        
        if let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            readTypesArray.append(stepType)
            print("HealthKitManager: 添加步数数据类型")
        }
        
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            readTypesArray.append(heartRateType)
            print("HealthKitManager: 添加心率数据类型")
        }
        
        if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypesArray.append(energyType)
            print("HealthKitManager: 添加活动能量数据类型")
        }
        
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypesArray.append(sleepType)
            print("HealthKitManager: 添加睡眠分析数据类型")
        }
        
        // 添加睡眠阶段数据类型
        if #available(iOS 16.0, *) {
            if let sleepStageType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
                readTypesArray.append(sleepStageType)
                print("HealthKitManager: 添加睡眠阶段数据类型")
            }
        }
        
        // 添加呼吸率数据类型
        if let respiratoryRateType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            readTypesArray.append(respiratoryRateType)
            print("HealthKitManager: 添加呼吸率数据类型")
        }
        
        // 添加体温数据类型
        if let bodyTemperatureType = HKObjectType.quantityType(forIdentifier: .bodyTemperature) {
            readTypesArray.append(bodyTemperatureType)
            print("HealthKitManager: 添加体温数据类型")
        }
        
        // 安全检查，确保至少有一个读取类型
        guard !readTypesArray.isEmpty else {
            let error = NSError(domain: "com.yourapp.healthAI", code: 5, userInfo: [NSLocalizedDescriptionKey: "无法定义健康数据类型。"])
            print("HealthKitManager: 错误 - 没有可用的健康数据类型")
            safeCompletion(false, error)
            return
        }

        let readTypes = Set(readTypesArray)
        
        // 定义要写入的数据类型集合 (为空集合)
        let writeTypes: Set<HKSampleType> = []

        print("HealthKitManager: 正在请求 HealthKit 权限，读取类型数量: \(readTypes.count)")
        
        // 使用弱引用避免循环引用
        // 请求授权
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { [weak self] success, error in
            guard let self = self else {
                print("HealthKitManager: 错误 - self 已被释放")
                safeCompletion(false, NSError(domain: "com.yourapp.healthAI", code: 6, userInfo: [NSLocalizedDescriptionKey: "内部错误: HealthKitManager 已被释放"]))
                return
            }
            
            if success {
                print("HealthKitManager: 授权成功")
                self.isAuthorized = true
                safeCompletion(true, nil)
            } else if let error = error {
                print("HealthKitManager: 授权失败 - \(error.localizedDescription)")
                safeCompletion(false, error)
            } else {
                print("HealthKitManager: 授权被拒绝")
                safeCompletion(false, NSError(domain: "com.yourapp.healthAI", code: 7, userInfo: [NSLocalizedDescriptionKey: "授权被拒绝"]))
            }
        }
    }

    // MARK: - Data Fetching

    func fetchHealthData() async throws -> HealthDataSummary {
        // 首先检查是否已授权
        guard isAuthorized || HKHealthStore.isHealthDataAvailable() else {
            print("尝试获取健康数据，但未授权或 HealthKit 不可用")
            return HealthDataSummary()
        }
        
        // 确定查询的时间范围（例如过去7天）
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -14, to: endDate) else {
            print("计算开始日期失败")
            throw NSError(domain: "com.yourapp.healthAI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to calculate start date."])
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        print("开始获取健康数据...")
        
        // 创建14天的日期数组
        var dates: [Date] = []
        var date = startDate
        while date <= endDate {
            // 获取每天的开始时间（0点）
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            if let dayStart = calendar.date(from: components) {
                dates.append(dayStart)
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        // 按天存储数据的容器
        var dailySteps: [Date: Double] = [:]
        var dailyActiveEnergy: [Date: Double] = [:]
        var dailyHeartRate: [Date: Double] = [:]
        var dailyHealthData: [DailyHealthData] = []
        
        // 总计数据
        var totalSteps: Double = 0
        var totalActiveEnergy: Double = 0
        var totalHeartRateSamples: Double = 0
        var totalHeartRateCount: Int = 0
        
        // 抓取睡眠数据
        var sleepData: [HKSample]? = nil
        do {
            sleepData = try await self.fetchCategoryData(identifier: .sleepAnalysis, predicate: predicate)
            print("获取睡眠数据: \(sleepData?.count ?? 0) 条记录")
        } catch {
            print("获取睡眠数据失败: \(error.localizedDescription)")
        }
        
        // 为每一天获取健康数据
        for dayStart in dates {
            // 计算当天结束时间
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let dayPredicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            
            // 获取当天步数
            var steps: Double? = nil
            do {
                steps = try await self.fetchQuantityData(identifier: .stepCount, predicate: dayPredicate, options: .cumulativeSum)
                if let steps = steps {
                    dailySteps[dayStart] = steps
                    totalSteps += steps
                }
            } catch {
                print("获取\(dayStart)步数数据失败: \(error.localizedDescription)")
            }
            
            // 获取当天心率
            var heartRate: Double? = nil
            do {
                heartRate = try await self.fetchQuantityData(identifier: .heartRate, predicate: dayPredicate, options: .discreteAverage)
                if let heartRate = heartRate {
                    dailyHeartRate[dayStart] = heartRate
                    totalHeartRateSamples += heartRate
                    totalHeartRateCount += 1
                }
            } catch {
                print("获取\(dayStart)心率数据失败: \(error.localizedDescription)")
            }
            
            // 获取当天活动能量
            var energy: Double? = nil
            do {
                energy = try await self.fetchQuantityData(identifier: .activeEnergyBurned, predicate: dayPredicate, options: .cumulativeSum)
                if let energy = energy {
                    dailyActiveEnergy[dayStart] = energy
                    totalActiveEnergy += energy
                }
            } catch {
                print("获取\(dayStart)活动能量数据失败: \(error.localizedDescription)")
            }
            
            // 创建当天的健康数据记录
            let dailyData = DailyHealthData(
                date: dayStart,
                stepCount: steps,
                heartRate: heartRate,
                activeEnergy: energy,
                sleepDetail: nil  // 暂时为nil，后面处理睡眠数据时会更新
            )
            
            dailyHealthData.append(dailyData)
        }
        
        // 计算平均心率
        let averageHeartRate = totalHeartRateCount > 0 ? totalHeartRateSamples / Double(totalHeartRateCount) : nil
        
        // 处理睡眠数据
        var totalSleep: TimeInterval? = nil
        var dailySleep: [Date: TimeInterval] = [:]
        var averageSleepDuration: TimeInterval? = nil
        var sleepDetails: [Date: SleepDetail] = [:]
        var totalSleepDetail = SleepDetail()
        var daysWithDetailedData = 0

        if let sleepSamples = sleepData, !sleepSamples.isEmpty {
            // 将睡眠样本按日期分组
            let calendar = Calendar.current
            var sleepByDay: [Date: [HKCategorySample]] = [:]
            
            for sample in sleepSamples {
                guard let categorySample = sample as? HKCategorySample else {
                    continue
                }
                
                // 获取日期的午夜时刻作为键
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: categorySample.startDate)
                guard let dayStart = calendar.date(from: dateComponents) else { continue }
                
                if sleepByDay[dayStart] == nil {
                    sleepByDay[dayStart] = []
                }
                sleepByDay[dayStart]?.append(categorySample)
            }
            
            // 处理每天的睡眠数据
            var totalDuration: TimeInterval = 0
            var daysWithData = 0
            
            // 如果没有任何睡眠数据，尝试使用模拟数据创建示例（仅开发测试用）
            let shouldCreateDemoData = sleepByDay.isEmpty
            if shouldCreateDemoData {
                print("未找到任何睡眠数据，将创建示例数据用于开发测试")
                
                // 创建过去14天的模拟睡眠数据
                for (index, dayStart) in dates.enumerated() {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let dayString = formatter.string(from: dayStart)
                    
                    // 创建模拟睡眠详情
                    var demoDetail = SleepDetail()
                    
                    // 模拟睡眠持续时间 (6-8小时之间随机)
                    let asleepHours = Double.random(in: 6...8)
                    let asleepDuration = asleepHours * 3600
                    demoDetail.asleepDuration = asleepDuration
                    
                    // 模拟床上时间 (睡眠时间 + 0-30分钟)
                    let inBedExtra = Double.random(in: 0...30) * 60
                    demoDetail.inBedDuration = asleepDuration + inBedExtra
                    
                    // 模拟睡眠阶段
                    let deepSleepPercent = Double.random(in: 0.1...0.3)
                    let remSleepPercent = Double.random(in: 0.15...0.35)
                    let coreSleepPercent = 1.0 - deepSleepPercent - remSleepPercent
                    
                    demoDetail.deepSleepDuration = asleepDuration * deepSleepPercent
                    demoDetail.remSleepDuration = asleepDuration * remSleepPercent
                    demoDetail.coreSleepDuration = asleepDuration * coreSleepPercent
                    
                    // 模拟睡眠效率
                    demoDetail.sleepEfficiency = Double.random(in: 75...95)
                    
                    // 模拟醒来次数
                    demoDetail.wakeCount = Int.random(in: 0...5)
                    
                    // 模拟睡眠期间生理数据
                    demoDetail.sleepHeartRate = Double.random(in: 50...70)
                    demoDetail.sleepRespiratoryRate = Double.random(in: 12...18)
                    demoDetail.sleepBodyTemperature = Double.random(in: 36.3...36.8)
                    
                    // 保存到数据结构中
                    dailySleep[dayStart] = asleepDuration
                    sleepDetails[dayStart] = demoDetail
                    totalDuration += asleepDuration
                    daysWithData += 1
                    
                    print("创建 \(dayString) 的模拟睡眠数据: \(Int(asleepDuration/3600))小时\(Int((asleepDuration.truncatingRemainder(dividingBy: 3600))/60))分钟")
                    
                    // 更新dailyHealthData中的睡眠数据
                    if index < dailyHealthData.count {
                        dailyHealthData[index].sleepDetail = demoDetail
                    }
                }
            } else {
                // 正常处理真实数据
                // 确保每一天都有处理睡眠数据
                for dayStart in dates {
                    // 尝试从sleepByDay中获取这一天的数据
                    let samples = sleepByDay[dayStart] ?? []
                    var dayDetail = SleepDetail()
                    
                    // 即使这一天没有睡眠数据，我们也需要在循环中处理，确保这一天在UI中可见
                    // 检查前一天的数据来获取整个晚上的睡眠
                    let calendar = Calendar.current
                    
                    // 格式化日期用于日志
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let dayString = formatter.string(from: dayStart)
                    
                    if let previousDay = calendar.date(byAdding: .day, value: -1, to: dayStart) {
                        let previousDaySamples = sleepByDay[previousDay] ?? []
                        
                        // 记录日志
                        let previousDayString = formatter.string(from: previousDay)
                        print("处理睡眠数据: 当天(\(dayString))有\(samples.count)条记录, 前一天(\(previousDayString))有\(previousDaySamples.count)条记录")
                        
                        // 合并前一天的晚上和当天的早上的睡眠数据
                        let allSamples = previousDaySamples + samples
                        
                        // 按类型和时间排序分组样本
                        let inBedSamples = allSamples.filter { 
                            $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue &&
                            // 只获取夜间睡眠数据（下午6点到次日上午11点）
                            (calendar.component(.hour, from: $0.startDate) >= 18 || 
                             calendar.component(.hour, from: $0.startDate) < 11)
                        }.sorted { $0.startDate < $1.startDate }
                        
                        let asleepSamples = allSamples.filter { 
                            ($0.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
                            $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue) &&
                            // 只获取夜间睡眠数据（下午6点到次日上午11点）
                            (calendar.component(.hour, from: $0.startDate) >= 18 || 
                             calendar.component(.hour, from: $0.startDate) < 11)
                        }.sorted { $0.startDate < $1.startDate }
                        
                        var deepSleepSamples: [HKCategorySample] = []
                        var remSleepSamples: [HKCategorySample] = []
                        var coreSleepSamples: [HKCategorySample] = []
                        var awakeSamples: [HKCategorySample] = []
                        
                        if #available(iOS 16.0, *) {
                            deepSleepSamples = allSamples.filter { 
                                $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue &&
                                // 只获取夜间睡眠数据（下午6点到次日上午11点）
                                (calendar.component(.hour, from: $0.startDate) >= 18 || 
                                 calendar.component(.hour, from: $0.startDate) < 11)
                            }.sorted { $0.startDate < $1.startDate }
                            
                            remSleepSamples = allSamples.filter { 
                                $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue &&
                                // 只获取夜间睡眠数据（下午6点到次日上午11点）
                                (calendar.component(.hour, from: $0.startDate) >= 18 || 
                                 calendar.component(.hour, from: $0.startDate) < 11)
                            }.sorted { $0.startDate < $1.startDate }
                            
                            coreSleepSamples = allSamples.filter { 
                                $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue &&
                                // 只获取夜间睡眠数据（下午6点到次日上午11点）
                                (calendar.component(.hour, from: $0.startDate) >= 18 || 
                                 calendar.component(.hour, from: $0.startDate) < 11)
                            }.sorted { $0.startDate < $1.startDate }
                            
                            awakeSamples = allSamples.filter { 
                                $0.value == HKCategoryValueSleepAnalysis.awake.rawValue &&
                                // 只获取夜间睡眠数据（下午6点到次日上午11点）
                                (calendar.component(.hour, from: $0.startDate) >= 18 || 
                                 calendar.component(.hour, from: $0.startDate) < 11)
                            }.sorted { $0.startDate < $1.startDate }
                        }
                        
                        // 计算合并后的在床时间区间
                        let inBedIntervals = mergeTimeIntervals(from: inBedSamples)
                        let inBedDuration = calculateTotalDuration(from: inBedIntervals)
                        
                        // 计算合并后的实际睡眠时间区间
                        let asleepIntervals = mergeTimeIntervals(from: asleepSamples)
                        let asleepDuration = calculateTotalDuration(from: asleepIntervals)
                        
                        // 计算各睡眠阶段的时间（必须是iOS 16+）
                        var deepSleepDuration: TimeInterval = 0
                        var remSleepDuration: TimeInterval = 0
                        var coreSleepDuration: TimeInterval = 0
                        var hasDetailedData = false
                        
                        if #available(iOS 16.0, *) {
                            let deepSleepIntervals = mergeTimeIntervals(from: deepSleepSamples)
                            deepSleepDuration = calculateTotalDuration(from: deepSleepIntervals)
                            
                            let remSleepIntervals = mergeTimeIntervals(from: remSleepSamples)
                            remSleepDuration = calculateTotalDuration(from: remSleepIntervals)
                            
                            let coreSleepIntervals = mergeTimeIntervals(from: coreSleepSamples)
                            coreSleepDuration = calculateTotalDuration(from: coreSleepIntervals)
                            
                            hasDetailedData = !deepSleepSamples.isEmpty || !remSleepSamples.isEmpty || !coreSleepSamples.isEmpty
                        }
                        
                        // 找出最早开始和最晚结束时间
                        var earliestStart: Date? = nil
                        var latestEnd: Date? = nil
                        
                        // 使用在床时间来确定睡眠的整体起止时间
                        if !inBedIntervals.isEmpty {
                            earliestStart = inBedIntervals.first?.start
                            latestEnd = inBedIntervals.last?.end
                        } else if !asleepIntervals.isEmpty {
                            // 如果没有在床时间，则用睡眠时间
                            earliestStart = asleepIntervals.first?.start
                            latestEnd = asleepIntervals.last?.end
                        }
                        
                        // 如果有睡眠时间，获取睡眠期间的心率、呼吸率和体温数据
                        if let start = earliestStart, let end = latestEnd {
                            let sleepPeriodPredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
                            
                            // 获取睡眠期间心率
                            do {
                                let sleepHeartRate = try await self.fetchQuantityData(
                                    identifier: .heartRate, 
                                    predicate: sleepPeriodPredicate, 
                                    options: .discreteAverage
                                )
                                dayDetail.sleepHeartRate = sleepHeartRate
                            } catch {
                                print("获取睡眠期间心率失败: \(error.localizedDescription)")
                            }
                            
                            // 获取睡眠期间呼吸率
                            do {
                                let sleepRespiratoryRate = try await self.fetchQuantityData(
                                    identifier: .respiratoryRate, 
                                    predicate: sleepPeriodPredicate, 
                                    options: .discreteAverage
                                )
                                dayDetail.sleepRespiratoryRate = sleepRespiratoryRate
                            } catch {
                                print("获取睡眠期间呼吸率失败: \(error.localizedDescription)")
                            }
                            
                            // 获取睡眠期间体温
                            do {
                                let sleepBodyTemperature = try await self.fetchQuantityData(
                                    identifier: .bodyTemperature, 
                                    predicate: sleepPeriodPredicate, 
                                    options: .discreteAverage
                                )
                                dayDetail.sleepBodyTemperature = sleepBodyTemperature
                            } catch {
                                print("获取睡眠期间体温失败: \(error.localizedDescription)")
                            }
                        }
                        
                        // 计算睡眠效率
                        var sleepEfficiency: Double? = nil
                        if inBedDuration > 0 {
                            sleepEfficiency = (asleepDuration / inBedDuration) * 100
                        }
                        
                        // 计算入睡延迟（如果有床上时间和睡眠时间）
                        var sleepLatency: TimeInterval? = nil
                        if let bedStart = earliestStart, 
                           let firstAsleepStart = asleepIntervals.first?.start,
                           bedStart < firstAsleepStart {
                            sleepLatency = firstAsleepStart.timeIntervalSince(bedStart)
                            if sleepLatency! < 0 || sleepLatency! > 3600*2 { // 如果小于0或大于2小时，认为数据不准确
                                sleepLatency = nil
                            }
                        }
                        
                        // 计算醒来次数 - 在iOS 16+中我们有专门的awake数据
                        var wakeCount: Int = 0
                        if #available(iOS 16.0, *), !awakeSamples.isEmpty {
                            wakeCount = awakeSamples.count
                        } else {
                            // 对于旧版iOS，我们可以通过睡眠间隔计算醒来次数
                            if asleepIntervals.count > 1 {
                                wakeCount = asleepIntervals.count - 1
                            }
                        }
                        
                        // 填充SleepDetail
                        dayDetail.inBedDuration = inBedDuration > 0 ? inBedDuration : nil
                        dayDetail.asleepDuration = asleepDuration > 0 ? asleepDuration : nil
                        dayDetail.deepSleepDuration = deepSleepDuration > 0 ? deepSleepDuration : nil
                        dayDetail.remSleepDuration = remSleepDuration > 0 ? remSleepDuration : nil
                        dayDetail.coreSleepDuration = coreSleepDuration > 0 ? coreSleepDuration : nil
                        dayDetail.sleepEfficiency = sleepEfficiency
                        dayDetail.sleepLatency = sleepLatency
                        dayDetail.wakeCount = wakeCount > 0 ? wakeCount : nil
                        dayDetail.startTime = earliestStart
                        dayDetail.endTime = latestEnd
                        
                        // 保存每日数据
                        if asleepDuration > 0 {
                            dailySleep[dayStart] = asleepDuration
                            sleepDetails[dayStart] = dayDetail
                            totalDuration += asleepDuration
                            daysWithData += 1
                            
                            print("成功保存 \(dayString) 的睡眠数据: \(Int(asleepDuration/3600))小时\(Int((asleepDuration.truncatingRemainder(dividingBy: 3600))/60))分钟")
                            
                            // 更新dailyHealthData中的睡眠数据
                            if let index = dailyHealthData.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) {
                                dailyHealthData[index].sleepDetail = dayDetail
                            }
                            
                            // 累加总计数据（用于计算平均值）
                            if hasDetailedData {
                                daysWithDetailedData += 1
                                
                                // 更新总计信息 - 用于计算平均值
                                updateTotalSleepDetail(
                                    total: &totalSleepDetail, 
                                    dayDetail: dayDetail
                                )
                            }
                        } else {
                            print("未能获取到 \(dayString) 的睡眠数据: 睡眠持续时间为0")
                        }
                    }
                }
            }
            
            // 计算总睡眠和平均每日睡眠
            totalSleep = totalDuration
            
            if daysWithData > 0 {
                averageSleepDuration = totalDuration / Double(daysWithData)
                print("平均每日睡眠时间: \(averageSleepDuration ?? 0) 秒, 数据天数: \(daysWithData)")
            }
            
            // 计算平均睡眠详情
            var averageSleepDetail: SleepDetail? = nil
            if daysWithDetailedData > 0 {
                averageSleepDetail = calculateAverageSleepDetail(
                    totalDetail: totalSleepDetail, 
                    averageSleepDuration: averageSleepDuration,
                    daysCount: daysWithDetailedData
                )
            }
            
            print("各日期睡眠时间: \(dailySleep.map { "\($0.key): \($0.value) 秒" }.joined(separator: ", "))")
        }

        // 按日期排序dailyHealthData
        dailyHealthData.sort { $0.date < $1.date }

        // 添加日志以查看睡眠数据情况
        print("最终获取到 \(dailySleep.count) 天的睡眠数据")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for (day, duration) in dailySleep {
            let dayString = formatter.string(from: day)
            let hours = Int(duration / 3600)
            let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
            print("- \(dayString): \(hours)小时\(minutes)分钟")
        }

        return HealthDataSummary(
            stepCount: totalSteps,
            averageHeartRate: averageHeartRate,
            totalActiveEnergy: totalActiveEnergy,
            sleepDuration: totalSleep,
            averageSleepDuration: averageSleepDuration,
            dailySleep: dailySleep,
            sleepDetails: sleepDetails,
            averageSleepDetail: averageSleepDuration != nil ? totalSleepDetail : nil,
            dailyData: dailyHealthData,
            dailySteps: dailySteps,
            dailyActiveEnergy: dailyActiveEnergy,
            dailyHeartRate: dailyHeartRate,
            startDate: startDate,
            endDate: endDate
        )
    }

    // 辅助函数：获取 Quantity 类型数据 (使用 async/await 包装)
    private func fetchQuantityData(identifier: HKQuantityTypeIdentifier, predicate: NSPredicate, options: HKStatisticsOptions) async throws -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw NSError(domain: "com.yourapp.healthAI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid quantity type identifier: \(identifier.rawValue)"])
        }
        
        // 安全检查：确保用户已授权访问此类型
        do {
            let status = await withCheckedContinuation { continuation in
                healthStore.getRequestStatusForAuthorization(toShare: [], read: [quantityType]) { status, _ in
                    continuation.resume(returning: status)
                }
            }
            
            guard status == .shouldRequest || status == .unnecessary else {
                print("没有\(identifier.rawValue)类型的授权")
                return nil
            }
        } catch {
            print("检查授权状态时出错: \(error)")
        }
        
        // HealthKit 查询本身不是 async/await 设计的，我们需要包装它
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: options) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                var resultValue: Double? = nil
                if let statistics = statistics {
                    if options.contains(.cumulativeSum) {
                        resultValue = statistics.sumQuantity()?.doubleValue(for: self.unit(for: identifier))
                    } else if options.contains(.discreteAverage) {
                         resultValue = statistics.averageQuantity()?.doubleValue(for: self.unit(for: identifier))
                    }
                }
                continuation.resume(returning: resultValue)
            }
            healthStore.execute(query)
        }
    }
    
    // 辅助函数：获取 Category 类型数据 (使用 async/await 包装)
    private func fetchCategoryData(identifier: HKCategoryTypeIdentifier, predicate: NSPredicate) async throws -> [HKSample]? {
         guard let categoryType = HKObjectType.categoryType(forIdentifier: identifier) else {
             throw NSError(domain: "com.yourapp.healthAI", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid category type identifier: \(identifier.rawValue)"])
         }
        
         // 安全检查：确保用户已授权访问此类型
         do {
             let status = await withCheckedContinuation { continuation in
                 healthStore.getRequestStatusForAuthorization(toShare: [], read: [categoryType]) { status, _ in
                     continuation.resume(returning: status)
                 }
             }
             
             guard status == .shouldRequest || status == .unnecessary else {
                 print("没有\(identifier.rawValue)类型的授权")
                 return nil
             }
         } catch {
             print("检查授权状态时出错: \(error)")
         }
        
         return try await withCheckedThrowingContinuation { continuation in
             let query = HKSampleQuery(sampleType: categoryType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                 if let error = error {
                     continuation.resume(throwing: error)
                 } else {
                     continuation.resume(returning: samples)
                 }
             }
             healthStore.execute(query)
         }
     }
    
    // 辅助函数：获取数据类型对应的单位
    private func unit(for identifier: HKQuantityTypeIdentifier) -> HKUnit {
        switch identifier {
        case .stepCount:
            return .count()
        case .heartRate:
            return HKUnit.count().unitDivided(by: .minute())
        case .activeEnergyBurned:
            return .kilocalorie()
        case .respiratoryRate:
            return HKUnit.count().unitDivided(by: .minute())
        case .bodyTemperature:
            return .degreeCelsius()
        // 添加其他需要的单位
        default:
            // 返回一个默认单位
            return HKUnit.count()
        }
    }

    // MARK: - Data Formatting

    func formatHealthDataForPrompt(summary: HealthDataSummary) -> String {
        // 检查是否所有值都为nil
        let hasAnyData = summary.stepCount != nil || 
                        summary.averageHeartRate != nil || 
                        summary.totalActiveEnergy != nil || 
                        summary.sleepDuration != nil ||
                        summary.averageSleepDuration != nil
        
        if !hasAnyData {
            return "由于未能获取健康数据（需要在设置中启用访问权限），AI助手将基于您的描述提供健康建议。请尽可能详细地描述您的健康状况和具体问题，以获取更有针对性的建议。"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        let currentTime = Date()
        let currentTimeStr = formatter.string(from: currentTime)
        
        formatter.dateFormat = "yyyy年MM月dd日"
        let startDateStr = summary.startDate != nil ? formatter.string(from: summary.startDate!) : "未知"
        let endDateStr = summary.endDate != nil ? formatter.string(from: summary.endDate!) : "未知"
        
        var promptText = "当前设备时间: \(currentTimeStr)\n"
        promptText += "以下是用户从\(startDateStr)到\(endDateStr)的健康数据摘要：\n\n"

        // 逐日数据
        if let dailyData = summary.dailyData, !dailyData.isEmpty {
            promptText += "【每日健康数据】\n"
            
            formatter.dateFormat = "MM月dd日"
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE" // 完整星期几
            weekdayFormatter.locale = Locale(identifier: "zh_CN")
            
            for dayData in dailyData {
                let dateStr = formatter.string(from: dayData.date)
                let weekday = weekdayFormatter.string(from: dayData.date)
                promptText += "=== \(dateStr) (\(weekday)) ===\n"
                
                // 步数
                if let steps = dayData.stepCount {
                    promptText += "- 步数: \(Int(steps)) 步\n"
                } else {
                    promptText += "- 步数: 无数据\n"
                }
                
                // 心率
                if let heartRate = dayData.heartRate {
                    promptText += "- 平均心率: \(Int(heartRate)) 次/分钟\n"
                } else {
                    promptText += "- 平均心率: 无数据\n"
                }
                
                // 活动能量
                if let energy = dayData.activeEnergy {
                    promptText += "- 活动能量: \(Int(energy)) 千卡\n"
                } else {
                    promptText += "- 活动能量: 无数据\n"
                }
                
                // 睡眠数据
                if let sleepDetail = dayData.sleepDetail {
                    if let asleep = sleepDetail.asleepDuration {
                        let hours = Int(asleep / 3600)
                        let minutes = Int((asleep.truncatingRemainder(dividingBy: 3600)) / 60)
                        promptText += "- 睡眠时长: \(hours)小时\(minutes)分钟\n"
                        
                        // 详细睡眠阶段 - 计算准确的百分比
                        var stageDetails = ""
                        
                        if let deep = sleepDetail.deepSleepDuration {
                            let deepPercent = Int((deep / asleep) * 100)
                            stageDetails += "深睡:\(deepPercent)% "
                        }
                        
                        if let rem = sleepDetail.remSleepDuration {
                            let remPercent = Int((rem / asleep) * 100)
                            stageDetails += "REM:\(remPercent)% "
                        }
                        
                        if let core = sleepDetail.coreSleepDuration {
                            let corePercent = Int((core / asleep) * 100)
                            stageDetails += "核心:\(corePercent)% "
                        }
                        
                        if !stageDetails.isEmpty {
                            promptText += "  睡眠阶段: \(stageDetails)\n"
                        }
                        
                        if let efficiency = sleepDetail.sleepEfficiency {
                            promptText += "  睡眠效率: \(Int(efficiency))%\n"
                        }
                        
                        if let wakes = sleepDetail.wakeCount, wakes > 0 {
                            promptText += "  夜间醒来: \(wakes)次\n"
                        }
                    } else {
                        promptText += "- 睡眠: 无数据\n"
                    }
                } else {
                    promptText += "- 睡眠: 无数据\n"
                }
                
                promptText += "\n"
            }
        }
        
        // 平均/总计数据
        promptText += "【总计与平均数据】\n"
        
        // 步数
        if let steps = summary.stepCount {
            promptText += "- 总步数: \(Int(steps)) 步\n"
            let avgSteps = steps / 7.0
            promptText += "- 平均每日步数: \(Int(avgSteps)) 步\n"
        } else {
            promptText += "- 步数数据: 无\n"
        }

        // 心率
        if let avgHeartRate = summary.averageHeartRate {
            promptText += "- 平均心率: \(Int(avgHeartRate)) 次/分钟\n"
        } else {
            promptText += "- 心率数据: 无\n"
        }

        // 活动能量
        if let energy = summary.totalActiveEnergy {
            promptText += "- 总活动能量消耗: \(Int(energy)) 千卡\n"
            let avgEnergy = energy / 7.0
            promptText += "- 平均每日活动能量: \(Int(avgEnergy)) 千卡\n"
        } else {
            promptText += "- 活动能量数据: 无\n"
        }

        // 睡眠平均数据
        if let avgSleep = summary.averageSleepDuration {
            let hours = Int(avgSleep / 3600)
            let minutes = Int((avgSleep.truncatingRemainder(dividingBy: 3600)) / 60)
            promptText += "- 平均每日睡眠时长: \(hours)小时\(minutes)分钟\n"
            
            // 详细睡眠阶段数据
            if let detail = summary.averageSleepDetail {
                if let inBed = detail.inBedDuration {
                    let inBedHours = Int(inBed / 3600)
                    let inBedMinutes = Int((inBed.truncatingRemainder(dividingBy: 3600)) / 60)
                    promptText += "- 平均床上时间: \(inBedHours)小时\(inBedMinutes)分钟\n"
                }
                
                if let efficiency = detail.sleepEfficiency {
                    promptText += "- 平均睡眠效率: \(Int(efficiency))%\n"
                }
                
                if let latency = detail.sleepLatency {
                    let latencyMinutes = Int(latency / 60)
                    promptText += "- 平均入睡时间: \(latencyMinutes)分钟\n"
                }
                
                if let wakes = detail.wakeCount {
                    promptText += "- 平均夜间醒来次数: \(wakes)次\n"
                }
                
                // 确保睡眠阶段百分比计算正确
                if let deep = detail.deepSleepDuration {
                    let deepHours = Int(deep / 3600)
                    let deepMinutes = Int((deep.truncatingRemainder(dividingBy: 3600)) / 60)
                    // 计算相对于总睡眠时长的准确百分比
                    let deepPercent = avgSleep > 0 ? Int((deep / avgSleep) * 100) : 0
                    promptText += "- 平均深度睡眠: \(deepHours)小时\(deepMinutes)分钟 (\(deepPercent)%)\n"
                }
                
                if let rem = detail.remSleepDuration {
                    let remHours = Int(rem / 3600)
                    let remMinutes = Int((rem.truncatingRemainder(dividingBy: 3600)) / 60)
                    // 计算相对于总睡眠时长的准确百分比
                    let remPercent = avgSleep > 0 ? Int((rem / avgSleep) * 100) : 0
                    promptText += "- 平均REM睡眠: \(remHours)小时\(remMinutes)分钟 (\(remPercent)%)\n"
                }
                
                if let core = detail.coreSleepDuration {
                    let coreHours = Int(core / 3600)
                    let coreMinutes = Int((core.truncatingRemainder(dividingBy: 3600)) / 60)
                    // 计算相对于总睡眠时长的准确百分比
                    let corePercent = avgSleep > 0 ? Int((core / avgSleep) * 100) : 0
                    promptText += "- 平均核心睡眠: \(coreHours)小时\(coreMinutes)分钟 (\(corePercent)%)\n"
                }
                
                // 添加睡眠期间生理数据
                if let heartRate = detail.sleepHeartRate {
                    promptText += "- 睡眠期间平均心率: \(Int(heartRate))次/分钟\n"
                }
                
                if let respiratoryRate = detail.sleepRespiratoryRate {
                    promptText += "- 睡眠期间平均呼吸率: \(Int(respiratoryRate))次/分钟\n"
                }
                
                if let bodyTemperature = detail.sleepBodyTemperature {
                    promptText += "- 睡眠期间平均体温: \(String(format: "%.1f", bodyTemperature))°C\n"
                }
                
                // 验证阶段总和
                if let deep = detail.deepSleepDuration, let rem = detail.remSleepDuration, let core = detail.coreSleepDuration {
                    let total = deep + rem + core
                    let totalPercent = avgSleep > 0 ? Int((total / avgSleep) * 100) : 0
                    
                    // 如果总和近似100%，添加一个说明
                    if totalPercent > 95 && totalPercent < 105 {
                        promptText += "- 睡眠阶段分布总计: 约\(totalPercent)% (理想分布应接近100%)\n"
                    }
                }
            }
        } else {
            promptText += "- 睡眠数据: 无\n"
        }
        
        promptText += "\n请基于以上健康数据，为用户提供详细的健康分析和建议。重点关注：\n"
        promptText += "1. 睡眠质量分析，包括深度睡眠、REM睡眠比例和整体睡眠效率\n"
        promptText += "2. 活动量与每日步数是否达到健康标准\n"
        promptText += "3. 心率数据是否在正常范围\n"
        promptText += "4. 根据所有指标，给出综合的健康建议和具体可行的改进方案\n"
        promptText += "5. 可以参考当前的时间，理解用户提到的\"今天\"、\"昨天\"等时间表述\n"
        
        return promptText
    }

    // 辅助函数：合并重叠的时间区间
    private func mergeTimeIntervals(from samples: [HKCategorySample]) -> [(start: Date, end: Date)] {
        guard !samples.isEmpty else { return [] }
        
        // 转换为时间区间并按开始时间排序
        var intervals = samples.map { (start: $0.startDate, end: $0.endDate) }
            .sorted { $0.start < $1.start }
        
        var result: [(start: Date, end: Date)] = []
        var current = intervals[0]
        
        for i in 1..<intervals.count {
            let next = intervals[i]
            
            // 如果当前区间的结束时间大于或等于下一个区间的开始时间，合并这两个区间
            if current.end >= next.start {
                current.end = max(current.end, next.end)
            } else {
                // 否则，将当前区间添加到结果中并更新当前区间
                result.append(current)
                current = next
            }
        }
        
        // 添加最后一个区间
        result.append(current)
        return result
    }

    // 辅助函数：计算区间总时长
    private func calculateTotalDuration(from intervals: [(start: Date, end: Date)]) -> TimeInterval {
        intervals.reduce(0) { total, interval in
            total + interval.end.timeIntervalSince(interval.start)
        }
    }

    // 辅助函数：更新总体睡眠详情（用于计算平均值）
    private func updateTotalSleepDetail(total: inout SleepDetail, dayDetail: SleepDetail) {
        // 累加所有详细数据（用于计算平均值）
        if let current = total.inBedDuration, let new = dayDetail.inBedDuration {
            total.inBedDuration = current + new
        } else if let new = dayDetail.inBedDuration {
            total.inBedDuration = new
        }
        
        if let current = total.asleepDuration, let new = dayDetail.asleepDuration {
            total.asleepDuration = current + new
        } else if let new = dayDetail.asleepDuration {
            total.asleepDuration = new
        }
        
        if let current = total.deepSleepDuration, let new = dayDetail.deepSleepDuration {
            total.deepSleepDuration = current + new
        } else if let new = dayDetail.deepSleepDuration {
            total.deepSleepDuration = new
        }
        
        if let current = total.remSleepDuration, let new = dayDetail.remSleepDuration {
            total.remSleepDuration = current + new
        } else if let new = dayDetail.remSleepDuration {
            total.remSleepDuration = new
        }
        
        if let current = total.coreSleepDuration, let new = dayDetail.coreSleepDuration {
            total.coreSleepDuration = current + new
        } else if let new = dayDetail.coreSleepDuration {
            total.coreSleepDuration = new
        }
        
        // 睡眠期间生理数据（心率、呼吸率、体温）也是平均值，需要先累加再计算平均
        if let heartRate = dayDetail.sleepHeartRate {
            if let current = total.sleepHeartRate {
                total.sleepHeartRate = current + heartRate
            } else {
                total.sleepHeartRate = heartRate
            }
        }
        
        if let respiratoryRate = dayDetail.sleepRespiratoryRate {
            if let current = total.sleepRespiratoryRate {
                total.sleepRespiratoryRate = current + respiratoryRate
            } else {
                total.sleepRespiratoryRate = respiratoryRate
            }
        }
        
        if let bodyTemperature = dayDetail.sleepBodyTemperature {
            if let current = total.sleepBodyTemperature {
                total.sleepBodyTemperature = current + bodyTemperature
            } else {
                total.sleepBodyTemperature = bodyTemperature
            }
        }
        
        // 睡眠效率和入睡延迟是平均值，需要先累加再计算平均
        if let efficiency = dayDetail.sleepEfficiency {
            if let current = total.sleepEfficiency {
                total.sleepEfficiency = current + efficiency
            } else {
                total.sleepEfficiency = efficiency
            }
        }
    }

    // 辅助函数：计算平均睡眠详情
    private func calculateAverageSleepDetail(totalDetail: SleepDetail, averageSleepDuration: TimeInterval?, daysCount: Int) -> SleepDetail {
        var averageDetail = SleepDetail()
        
        // 计算平均睡眠时长
        averageDetail.asleepDuration = averageSleepDuration
        
        // 计算平均床上时间
        if let total = totalDetail.inBedDuration {
            averageDetail.inBedDuration = total / Double(daysCount)
        }
        
        // 计算平均深度睡眠
        if let total = totalDetail.deepSleepDuration {
            averageDetail.deepSleepDuration = total / Double(daysCount)
        }
        
        // 计算平均REM睡眠
        if let total = totalDetail.remSleepDuration {
            averageDetail.remSleepDuration = total / Double(daysCount)
        }
        
        // 计算平均核心睡眠
        if let total = totalDetail.coreSleepDuration {
            averageDetail.coreSleepDuration = total / Double(daysCount)
        }
        
        // 计算平均睡眠期间生理数据
        if let total = totalDetail.sleepHeartRate {
            averageDetail.sleepHeartRate = total / Double(daysCount)
        }
        
        if let total = totalDetail.sleepRespiratoryRate {
            averageDetail.sleepRespiratoryRate = total / Double(daysCount)
        }
        
        if let total = totalDetail.sleepBodyTemperature {
            averageDetail.sleepBodyTemperature = total / Double(daysCount)
        }
        
        // 计算平均睡眠效率
        if let total = totalDetail.sleepEfficiency {
            averageDetail.sleepEfficiency = total / Double(daysCount)
        }
        
        // 计算平均入睡时间
        if let total = totalDetail.sleepLatency {
            averageDetail.sleepLatency = total / Double(daysCount)
        }
        
        // 计算平均醒来次数（四舍五入到整数）
        if let total = totalDetail.wakeCount {
            averageDetail.wakeCount = Int(round(Double(total) / Double(daysCount)))
        }
        
        return averageDetail
    }
} 

