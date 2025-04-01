import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationView {
                ChatView()
            }
            .tabItem {
                Label("健康顾问", systemImage: "heart.text.square")
            }
            
            Text("健康数据")
                .tabItem {
                    Label("健康数据", systemImage: "heart.circle")
                }
            
            Text("分析")
                .tabItem {
                    Label("分析", systemImage: "chart.bar")
                }
            
            Text("我的")
                .tabItem {
                    Label("我的", systemImage: "person.circle")
                }
        }
    }
} 