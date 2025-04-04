import SwiftUI

// 加载中视图
struct LoadingView: View {
    var body: some View {
        ProgressView("正在加载健康数据...")
            .padding()
    }
}

// 错误视图
struct ErrorView: View {
    let errorMessage: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("加载健康数据时出错")
                .font(.headline)
            
            Text(errorMessage)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("重试") {
                retryAction()
            }
            .primaryButtonStyle()
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
            .primaryButtonStyle()
        }
        .padding()
    }
} 