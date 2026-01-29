//
//  healthAIApp.swift
//  healthAI
//
//  Created by Chris Zhang on 4/1/25.
//

import SwiftUI

@main
struct healthAIApp: App {
    // 使用StateObject确保持久化控制器在整个应用生命周期内保持一个实例
    @StateObject private var healthKitManager = HealthKitManager()
    
    // 使用环境对象持有CoreData持久化控制器
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(healthKitManager)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                // 设置全局强调色
                .accentColor(ThemeManager.shared.accentColor)
                // 添加全局上下文
                .onAppear {
                    // 配置应用外观
                    configureAppearance()
                }
        }
    }
    
    // 配置应用全局外观
    private func configureAppearance() {
        // 配置标签栏外观
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // 配置导航栏外观
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        
        // 打印当前主题颜色，用于调试
        let primaryColor = ThemeManager.shared.primaryColor
        print("应用启动，主题色已配置")
    }
}
