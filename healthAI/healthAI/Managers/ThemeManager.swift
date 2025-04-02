import SwiftUI

class ThemeManager {
    static let shared = ThemeManager()
    
    // 主题颜色
    let primaryColor = Color("PrimaryColor")
    let secondaryColor = Color("SecondaryColor")
    let accentColor = Color("AccentColor")
    
    // 私有初始化器，确保单例模式
    private init() {}
    
    // MARK: - 数据颜色
    struct DataColors {
        // 已有颜色
        static let steps = Color.green
        static let heartRate = Color.red
        static let energy = Color.orange
        static let sleep = Color.blue
        
        // 新增颜色
        static let distance = Color.blue
        static let flights = Color.orange
        static let exerciseTime = Color.green
        static let standTime = Color.purple
        static let restingHeartRate = Color.pink
        static let heartRateVariability = Color.red.opacity(0.7)
        static let respiratoryRate = Color.cyan
        static let oxygenSaturation = Color.blue
        static let bloodPressure = Color.red
        static let bodyTemperature = Color.orange
        static let bodyMass = Color.blue
        static let bodyMassIndex = Color.purple
        static let bodyFatPercentage = Color.orange
        static let dietaryEnergy = Color.green
        static let dietaryWater = Color.cyan
        
        // 健康评分颜色
        static func healthScore(_ score: Int) -> Color {
            switch score {
            case 0..<40: return .red
            case 40..<70: return .orange
            case 70..<90: return .blue
            default: return .green
            }
        }
    } 
} 