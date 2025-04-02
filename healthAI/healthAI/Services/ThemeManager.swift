import SwiftUI

// 自定义阴影结构体
struct Shadow {
    var color: Color
    var radius: CGFloat
    var x: CGFloat
    var y: CGFloat
}

/// 主题管理器：负责管理应用的颜色、字体和其他视觉样式
class ThemeManager {
    // 单例模式
    static let shared = ThemeManager()
    
    private init() {} // 私有初始化方法确保单例模式
    
    // MARK: - 颜色系统
    
    // 主色调
    var primaryColor: Color {
        Color("PrimaryColor", bundle: nil)
    }
    
    // 次要颜色
    var secondaryColor: Color {
        Color("SecondaryColor", bundle: nil)
    }
    
    // 强调色
    var accentColor: Color {
        Color("AccentColor", bundle: nil)
    }
    
    // 背景色
    var backgroundColor: Color {
        Color(UIColor.systemBackground)
    }
    
    // 次要背景色
    var secondaryBackgroundColor: Color {
        Color(UIColor.secondarySystemBackground)
    }
    
    // 数据可视化色彩
    struct DataColors {
        // 步数数据颜色
        static let steps = Color.blue
        
        // 心率数据颜色
        static let heartRate = Color.red
        
        // 睡眠数据颜色
        static let sleep = Color.purple
        
        // 活动能量颜色
        static let energy = Color.orange
        
        // 健康评分颜色
        static func healthScore(_ score: Int) -> Color {
            switch score {
            case 0..<40: return .red
            case 40..<70: return .orange
            case 70..<90: return .yellow
            default: return .green
            }
        }
    }
    
    // MARK: - 字体系统
    
    // 标题字体
    func titleFont(_ size: CGFloat = 24) -> Font {
        Font.system(size: size, weight: .bold, design: .rounded)
    }
    
    // 子标题字体
    func subtitleFont(_ size: CGFloat = 18) -> Font {
        Font.system(size: size, weight: .semibold, design: .rounded)
    }
    
    // 正文字体
    func bodyFont(_ size: CGFloat = 16) -> Font {
        Font.system(size: size, weight: .regular, design: .default)
    }
    
    // 小标签字体
    func captionFont(_ size: CGFloat = 12) -> Font {
        Font.system(size: size, weight: .regular, design: .default)
    }
    
    // MARK: - 阴影与效果
    
    // 卡片阴影
    var cardShadow: Shadow {
        Shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // 轻度阴影
    var lightShadow: Shadow {
        Shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // 卡片圆角度数
    var cardCornerRadius: CGFloat {
        12.0
    }
    
    // 内边距
    var standardPadding: CGFloat {
        16.0
    }
    
    // MARK: - 样式修饰符
    
    // 卡片样式修饰符
    func cardStyle<T: View>(_ content: T) -> some View {
        content
            .padding(standardPadding)
            .background(backgroundColor)
            .cornerRadius(cardCornerRadius)
            .shadow(color: cardShadow.color, 
                   radius: cardShadow.radius, 
                   x: cardShadow.x, 
                   y: cardShadow.y)
    }
    
    // 主按钮样式
    func primaryButtonStyle<T: View>(_ content: T) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(primaryColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 扩展 View 添加便捷方法
extension View {
    // 应用卡片样式
    func cardStyle() -> some View {
        ThemeManager.shared.cardStyle(self)
    }
    
    // 应用主按钮样式
    func primaryButtonStyle() -> some View {
        ThemeManager.shared.primaryButtonStyle(self)
    }
}

// MARK: - 自定义文本样式
struct TitleTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(ThemeManager.shared.titleFont())
            .foregroundColor(.primary)
    }
}

struct SubtitleTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(ThemeManager.shared.subtitleFont())
            .foregroundColor(.primary)
    }
}

struct BodyTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(ThemeManager.shared.bodyFont())
            .foregroundColor(.primary)
    }
}

struct CaptionTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(ThemeManager.shared.captionFont())
            .foregroundColor(.secondary)
    }
}

// 给 Text 添加便捷扩展方法
extension Text {
    func titleStyle() -> some View {
        self.modifier(TitleTextStyle())
    }
    
    func subtitleStyle() -> some View {
        self.modifier(SubtitleTextStyle())
    }
    
    func bodyStyle() -> some View {
        self.modifier(BodyTextStyle())
    }
    
    func captionStyle() -> some View {
        self.modifier(CaptionTextStyle())
    }
} 