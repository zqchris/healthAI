import CoreData

/// 负责管理Core Data持久性存储和上下文
class PersistenceController {
    // 单例模式
    static let shared = PersistenceController()
    
    // NSPersistentContainer的公共实例，用于整个应用
    let container: NSPersistentContainer
    
    // 测试环境的初始化方法，使用内存存储
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        
        // 创建预览数据
        let viewContext = controller.container.viewContext
        
        // 创建示例用户
        let newUser = CDUser(context: viewContext)
        newUser.id = UUID()
        newUser.name = "测试用户"
        newUser.age = 35
        newUser.gender = "男"
        newUser.height = 175.0
        newUser.weight = 70.0
        newUser.email = "test@example.com"
        newUser.lastSync = Date()
        
        // 创建一些示例健康数据
        let calendar = Calendar.current
        let today = Date()
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            // 添加健康数据
            let healthData = CDHealthData(context: viewContext)
            healthData.id = UUID()
            healthData.date = date
            healthData.stepCount = Double.random(in: 5000...15000)
            healthData.heartRate = Double.random(in: 60...100)
            healthData.activeEnergy = Double.random(in: 200...800)
            
            // 添加睡眠详情
            let sleepDetail = CDSleepDetail(context: viewContext)
            sleepDetail.id = UUID()
            sleepDetail.asleepDuration = Double.random(in: 6...9) * 3600 // 6-9小时（秒）
            sleepDetail.inBedDuration = sleepDetail.asleepDuration + Double.random(in: 0...30) * 60 // 额外0-30分钟
            sleepDetail.deepSleepDuration = sleepDetail.asleepDuration * Double.random(in: 0.15...0.25)
            sleepDetail.remSleepDuration = sleepDetail.asleepDuration * Double.random(in: 0.2...0.3)
            sleepDetail.coreSleepDuration = sleepDetail.asleepDuration - sleepDetail.deepSleepDuration - sleepDetail.remSleepDuration
            sleepDetail.sleepEfficiency = Double.random(in: 0.75...0.95) * 100
            sleepDetail.wakeCount = Int16.random(in: 0...5)
            sleepDetail.sleepHeartRate = Double.random(in: 50...65)
            sleepDetail.sleepRespiratoryRate = Double.random(in: 12...18)
            sleepDetail.sleepBodyTemperature = Double.random(in: 36.3...36.8)
            
            // 关联睡眠详情与健康数据
            healthData.sleepDetail = sleepDetail
            sleepDetail.healthData = healthData
        }
        
        do {
            try viewContext.save()
        } catch {
            // 处理错误
            let nsError = error as NSError
            fatalError("创建预览持久性控制器时发生未解析错误 \(nsError), \(nsError.userInfo)")
        }
        
        return controller
    }()
    
    /// 初始化持久化控制器
    /// - Parameter inMemory: 如果为true，将使用内存存储而不是持久化存储
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "HealthModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                // 替换为合适的错误处理代码，例如向用户显示错误
                fatalError("无法加载持久化存储: \(error), \(error.userInfo)")
            }
        }
        
        // 合并策略
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    /// 创建背景上下文进行操作
    /// - Returns: NSManagedObjectContext
    func backgroundContext() -> NSManagedObjectContext {
        return container.newBackgroundContext()
    }
    
    /// 保存上下文中的更改
    /// - Parameter context: 要保存的上下文
    func save(context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // 替换为适当的错误处理
                let nsError = error as NSError
                print("保存上下文时发生未解析错误 \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    /// 将HealthKit健康数据保存到Core Data
    /// - Parameters:
    ///   - healthData: 健康数据
    ///   - completion: 完成回调
    func saveHealthData(_ healthData: [DailyHealthData], completion: @escaping (Bool) -> Void) {
        let context = container.newBackgroundContext()
        
        context.perform {
            for dailyData in healthData {
                // 查询是否已有该日期的数据
                let fetchRequest: NSFetchRequest<CDHealthData> = CDHealthData.fetchRequest()
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month, .day], from: dailyData.date)
                guard let dayStart = calendar.date(from: components) else { continue }
                let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart)
                let predicate = NSPredicate(format: "date >= %@ AND date < %@", dayStart as NSDate, nextDay! as NSDate)
                fetchRequest.predicate = predicate
                
                do {
                    let existingData = try context.fetch(fetchRequest)
                    
                    let healthData: CDHealthData
                    if let firstExisting = existingData.first {
                        // 更新现有数据
                        healthData = firstExisting
                    } else {
                        // 创建新数据
                        healthData = CDHealthData(context: context)
                        healthData.id = UUID()
                        healthData.date = dayStart
                    }
                    
                    // 设置健康数据
                    if let stepCount = dailyData.stepCount {
                        healthData.stepCount = stepCount
                    }
                    
                    if let heartRate = dailyData.heartRate {
                        healthData.heartRate = heartRate
                    }
                    
                    if let activeEnergy = dailyData.activeEnergy {
                        healthData.activeEnergy = activeEnergy
                    }
                    
                    // 设置睡眠详情
                    if let sleepDetail = dailyData.sleepDetail {
                        let cdSleepDetail: CDSleepDetail
                        
                        if let existingSleep = healthData.sleepDetail {
                            // 更新现有睡眠数据
                            cdSleepDetail = existingSleep
                        } else {
                            // 创建新的睡眠数据
                            cdSleepDetail = CDSleepDetail(context: context)
                            cdSleepDetail.id = UUID()
                            cdSleepDetail.healthData = healthData
                            healthData.sleepDetail = cdSleepDetail
                        }
                        
                        // 设置睡眠详情属性
                        if let asleepDuration = sleepDetail.asleepDuration {
                            cdSleepDetail.asleepDuration = asleepDuration
                        }
                        
                        if let inBedDuration = sleepDetail.inBedDuration {
                            cdSleepDetail.inBedDuration = inBedDuration
                        }
                        
                        if let deepSleepDuration = sleepDetail.deepSleepDuration {
                            cdSleepDetail.deepSleepDuration = deepSleepDuration
                        }
                        
                        if let remSleepDuration = sleepDetail.remSleepDuration {
                            cdSleepDetail.remSleepDuration = remSleepDuration
                        }
                        
                        if let coreSleepDuration = sleepDetail.coreSleepDuration {
                            cdSleepDetail.coreSleepDuration = coreSleepDuration
                        }
                        
                        if let sleepEfficiency = sleepDetail.sleepEfficiency {
                            cdSleepDetail.sleepEfficiency = sleepEfficiency
                        }
                        
                        if let sleepLatency = sleepDetail.sleepLatency {
                            cdSleepDetail.sleepLatency = sleepLatency
                        }
                        
                        if let wakeCount = sleepDetail.wakeCount {
                            cdSleepDetail.wakeCount = Int16(wakeCount)
                        }
                        
                        if let startTime = sleepDetail.startTime {
                            cdSleepDetail.startTime = startTime
                        }
                        
                        if let endTime = sleepDetail.endTime {
                            cdSleepDetail.endTime = endTime
                        }
                        
                        if let sleepHeartRate = sleepDetail.sleepHeartRate {
                            cdSleepDetail.sleepHeartRate = sleepHeartRate
                        }
                        
                        if let sleepRespiratoryRate = sleepDetail.sleepRespiratoryRate {
                            cdSleepDetail.sleepRespiratoryRate = sleepRespiratoryRate
                        }
                        
                        if let sleepBodyTemperature = sleepDetail.sleepBodyTemperature {
                            cdSleepDetail.sleepBodyTemperature = sleepBodyTemperature
                        }
                    }
                } catch {
                    print("保存健康数据时发生错误: \(error.localizedDescription)")
                    completion(false)
                    return
                }
            }
            
            // 保存上下文
            do {
                try context.save()
                completion(true)
            } catch {
                print("保存上下文时发生错误: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    /// 从Core Data读取健康数据
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    ///   - completion: 完成回调
    func fetchHealthData(startDate: Date, endDate: Date, completion: @escaping ([DailyHealthData]?) -> Void) {
        let context = container.newBackgroundContext()
        
        context.perform {
            let fetchRequest: NSFetchRequest<CDHealthData> = CDHealthData.fetchRequest()
            let predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
            fetchRequest.predicate = predicate
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDHealthData.date, ascending: true)]
            
            do {
                let results = try context.fetch(fetchRequest)
                
                // 将Core Data实体转换为模型对象
                var dailyHealthData: [DailyHealthData] = []
                
                for result in results {
                    var sleepDetail: SleepDetail?
                    
                    if let cdSleepDetail = result.sleepDetail {
                        sleepDetail = SleepDetail(
                            inBedDuration: cdSleepDetail.inBedDuration,
                            asleepDuration: cdSleepDetail.asleepDuration,
                            deepSleepDuration: cdSleepDetail.deepSleepDuration,
                            remSleepDuration: cdSleepDetail.remSleepDuration,
                            coreSleepDuration: cdSleepDetail.coreSleepDuration,
                            sleepEfficiency: cdSleepDetail.sleepEfficiency,
                            sleepLatency: cdSleepDetail.sleepLatency,
                            wakeCount: Int(cdSleepDetail.wakeCount),
                            startTime: cdSleepDetail.startTime,
                            endTime: cdSleepDetail.endTime,
                            sleepHeartRate: cdSleepDetail.sleepHeartRate,
                            sleepRespiratoryRate: cdSleepDetail.sleepRespiratoryRate,
                            sleepBodyTemperature: cdSleepDetail.sleepBodyTemperature
                        )
                    }
                    
                    let healthData = DailyHealthData(
                        date: result.date!,
                        stepCount: result.stepCount,
                        activeEnergy: result.activeEnergy,
                        heartRate: result.heartRate,
                        sleepDetail: sleepDetail
                    )
                    
                    dailyHealthData.append(healthData)
                }
                
                completion(dailyHealthData)
            } catch {
                print("获取健康数据时发生错误: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    /// 生成健康数据摘要
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    ///   - completion: 完成回调
    func generateHealthSummary(startDate: Date, endDate: Date, completion: @escaping (HealthDataSummary?) -> Void) {
        fetchHealthData(startDate: startDate, endDate: endDate) { dailyData in
            guard let data = dailyData else {
                completion(nil)
                return
            }
            
            var summary = HealthDataSummary()
            summary.startDate = startDate
            summary.endDate = endDate
            summary.dailyData = data
            
            // 计算总步数和平均值
            var totalSteps: Double = 0
            var totalHeartRate: Double = 0
            var heartRateCount: Int = 0
            var totalActiveEnergy: Double = 0
            var totalSleepDuration: TimeInterval = 0
            var sleepDays: Int = 0
            
            // 日常数据字典
            var dailySteps: [Date: Double] = [:]
            var dailyHeartRate: [Date: Double] = [:]
            var dailyActiveEnergy: [Date: Double] = [:]
            var dailySleep: [Date: TimeInterval] = [:]
            var sleepDetails: [Date: SleepDetail] = [:]
            
            for item in data {
                // 步数数据
                if let steps = item.stepCount {
                    totalSteps += steps
                    dailySteps[item.date] = steps
                }
                
                // 心率数据
                if let heartRate = item.heartRate {
                    totalHeartRate += heartRate
                    heartRateCount += 1
                    dailyHeartRate[item.date] = heartRate
                }
                
                // 活动能量数据
                if let energy = item.activeEnergy {
                    totalActiveEnergy += energy
                    dailyActiveEnergy[item.date] = energy
                }
                
                // 睡眠数据
                if let sleep = item.sleepDetail, let duration = sleep.asleepDuration {
                    totalSleepDuration += duration
                    sleepDays += 1
                    dailySleep[item.date] = duration
                    sleepDetails[item.date] = sleep
                }
            }
            
            // 设置摘要数据
            summary.stepCount = totalSteps
            summary.totalActiveEnergy = totalActiveEnergy
            
            if heartRateCount > 0 {
                summary.averageHeartRate = totalHeartRate / Double(heartRateCount)
            }
            
            if sleepDays > 0 {
                summary.sleepDuration = totalSleepDuration
                summary.averageSleepDuration = totalSleepDuration / Double(sleepDays)
            }
            
            summary.dailySteps = dailySteps
            summary.dailyHeartRate = dailyHeartRate
            summary.dailyActiveEnergy = dailyActiveEnergy
            summary.dailySleep = dailySleep
            summary.sleepDetails = sleepDetails
            
            completion(summary)
        }
    }
} 