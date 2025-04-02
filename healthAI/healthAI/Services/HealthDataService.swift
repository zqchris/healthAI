import Foundation
import SwiftUI
import Combine

/// 健康数据服务：负责协调HealthKit数据和本地数据库之间的数据流
class HealthDataService: ObservableObject {
    // 单例模式
    static let shared = HealthDataService()
    
    // 依赖
    private let healthKitManager = HealthKitManager()
    private let persistenceController = PersistenceController.shared
    
    // 发布者
    @Published var isLoading = false
    @Published var healthSummary: HealthDataSummary?
    @Published var lastSyncDate: Date?
    @Published var errorMessage: String?
    
    // 用于取消异步任务
    private var loadingCancellable: AnyCancellable?
    
    // 默认时间范围：过去14天
    private var defaultDateRange: (start: Date, end: Date) {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -14, to: end) ?? end
        return (start, end)
    }
    
    private init() {
        // 从UserDefaults加载上次同步时间
        lastSyncDate = UserDefaults.standard.object(forKey: "lastHealthDataSync") as? Date
    }
    
    /// 加载健康数据
    /// - Parameter forceUpdate: 是否强制从HealthKit更新
    func loadHealthData(forceUpdate: Bool = false) {
        isLoading = true
        errorMessage = nil
        
        // 检查是否强制更新或者需要更新(超过3小时)
        let shouldUpdateFromHealthKit = forceUpdate || shouldRefreshFromHealthKit()
        
        if shouldUpdateFromHealthKit {
            // 从HealthKit获取并更新数据
            loadFromHealthKit()
        } else {
            // 从本地数据库加载
            loadFromLocalDatabase()
        }
    }
    
    /// 检查是否应该从HealthKit刷新数据
    private func shouldRefreshFromHealthKit() -> Bool {
        guard let lastSync = lastSyncDate else {
            return true // 没有上次同步记录，应该刷新
        }
        
        // 如果上次同步时间超过3小时，应该刷新
        let threeHoursAgo = Calendar.current.date(byAdding: .hour, value: -3, to: Date()) ?? Date()
        return lastSync < threeHoursAgo
    }
    
    /// 从HealthKit获取数据
    private func loadFromHealthKit() {
        // 请求授权
        healthKitManager.requestAuthorization { [weak self] success, error in
            guard let self = self else { return }
            
            if !success {
                DispatchQueue.main.async {
                    self.errorMessage = error?.localizedDescription ?? "未能获取HealthKit授权"
                    self.isLoading = false
                }
                return
            }
            
            // 获取数据
            Task {
                do {
                    // 从HealthKit获取数据
                    let summary = try await self.healthKitManager.fetchHealthData()
                    
                    // 保存到CoreData
                    if let dailyData = summary.dailyData {
                        self.persistenceController.saveHealthData(dailyData) { success in
                            if success {
                                print("健康数据成功保存到本地数据库")
                                
                                // 更新最后同步时间
                                self.lastSyncDate = Date()
                                UserDefaults.standard.set(self.lastSyncDate, forKey: "lastHealthDataSync")
                            } else {
                                print("保存健康数据到本地数据库失败")
                            }
                        }
                    }
                    
                    // 在主线程更新UI
                    DispatchQueue.main.async {
                        self.healthSummary = summary
                        self.isLoading = false
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "获取健康数据失败: \(error.localizedDescription)"
                        self.isLoading = false
                        
                        // 如果HealthKit获取失败，尝试从本地加载
                        self.loadFromLocalDatabase()
                    }
                }
            }
        }
    }
    
    /// 从本地数据库加载数据
    private func loadFromLocalDatabase() {
        let (startDate, endDate) = defaultDateRange
        
        persistenceController.generateHealthSummary(startDate: startDate, endDate: endDate) { [weak self] summary in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let summary = summary {
                    self.healthSummary = summary
                    self.isLoading = false
                } else {
                    // 如果本地没有数据，尝试从HealthKit获取
                    if self.errorMessage == nil {
                        self.loadFromHealthKit()
                    } else {
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    /// 根据日期范围获取健康数据
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    ///   - completion: 完成回调
    func getHealthData(from startDate: Date, to endDate: Date, completion: @escaping (HealthDataSummary?) -> Void) {
        persistenceController.generateHealthSummary(startDate: startDate, endDate: endDate, completion: completion)
    }
    
    /// 计算健康分数
    /// - Parameter summary: 健康数据摘要
    /// - Returns: 健康分数(0-100)
    func calculateHealthScore(from summary: HealthDataSummary) -> Int {
        var score = 0
        var factorsCount = 0
        
        // 步数评分(10000步为满分)
        if let totalSteps = summary.stepCount {
            let daysCount = Calendar.current.dateComponents([.day], from: summary.startDate ?? Date(), to: summary.endDate ?? Date()).day ?? 1
            let avgSteps = totalSteps / Double(daysCount)
            let stepsScore = min(Int(avgSteps / 10000.0 * 25), 25)
            score += stepsScore
            factorsCount += 1
        }
        
        // 心率评分(60-100为正常范围)
        if let avgHeartRate = summary.averageHeartRate {
            let heartRateScore: Int
            if avgHeartRate < 50 {
                heartRateScore = 15 // 过低
            } else if avgHeartRate < 60 {
                heartRateScore = 20 // 稍低
            } else if avgHeartRate <= 100 {
                heartRateScore = 25 // 理想范围
            } else if avgHeartRate <= 120 {
                heartRateScore = 15 // 偏高
            } else {
                heartRateScore = 10 // 过高
            }
            score += heartRateScore
            factorsCount += 1
        }
        
        // 睡眠评分(7-9小时为理想)
        if let avgSleepDuration = summary.averageSleepDuration {
            let sleepHours = avgSleepDuration / 3600.0
            let sleepScore: Int
            if sleepHours < 5 {
                sleepScore = 10 // 严重不足
            } else if sleepHours < 7 {
                sleepScore = 15 // 不足
            } else if sleepHours <= 9 {
                sleepScore = 25 // 理想范围
            } else if sleepHours <= 10 {
                sleepScore = 20 // 稍多
            } else {
                sleepScore = 15 // 过多
            }
            score += sleepScore
            factorsCount += 1
        }
        
        // 活动能量评分(每天300千卡为标准)
        if let totalEnergy = summary.totalActiveEnergy {
            let daysCount = Calendar.current.dateComponents([.day], from: summary.startDate ?? Date(), to: summary.endDate ?? Date()).day ?? 1
            let avgEnergy = totalEnergy / Double(daysCount)
            let energyScore = min(Int(avgEnergy / 300.0 * 25), 25)
            score += energyScore
            factorsCount += 1
        }
        
        // 如果没有足够的因素，使用默认分数
        if factorsCount == 0 {
            return 50
        }
        
        // 计算平均分数并转换为0-100
        let avgScore = score / factorsCount
        return avgScore * 4 // 将25分制转换为100分制
    }
} 