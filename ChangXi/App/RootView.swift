import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("首页", systemImage: "sparkles") }

            NavigationStack { ChatView() }
                .tabItem { Label("常曦", systemImage: "message.fill") }

            NavigationStack {
                ContentUnavailableView("服务", systemImage: "cross.case.fill", description: Text("服务入口将在下一阶段接入。"))
            }
            .tabItem { Label("服务", systemImage: "square.grid.2x2.fill") }

            NavigationStack {
                ContentUnavailableView("我的", systemImage: "person.crop.circle", description: Text("账户与健康资料将在下一阶段接入。"))
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
    }
}
