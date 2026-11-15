import SwiftUI

/// 底部四 Tab 主框架（设计书 4.3）：系统 TabView + SF Symbols
/// Tab 切换动效走系统；选中态由系统着色，不另做 fill 切换
struct MainTabView: View {
    #if DEBUG
    @Environment(SessionStore.self) private var session
    @Environment(HapticService.self) private var haptic
    #endif

    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            #if DEBUG
            // 第二期 UI 层预写（附录 B 已批准）：Debug 构建进聊天 Demo，Release 仍为占位页
            NavigationStack {
                ConversationListView()
                    .modelContainer(ChatDemoEngine.shared.container)
            }
            .tabItem { Label("消息", systemImage: "message") }
            .tag(0)
            .onAppear {
                ChatDemoEngine.shared.attach(
                    hapticService: haptic,
                    myUserID: session.currentUser?.id ?? "1001"
                )
            }
            #else
            NavigationStack {
                PlaceholderTabView(title: "消息", systemImage: "message", description: "暂无消息")
            }
            .tabItem { Label("消息", systemImage: "message") }
            .tag(0)
            #endif

            NavigationStack {
                PlaceholderTabView(title: "客户", systemImage: "person.2", description: "暂无客户")
            }
            .tabItem { Label("客户", systemImage: "person.2") }
            .tag(1)

            NavigationStack {
                PlaceholderTabView(title: "工作台", systemImage: "square.grid.2x2", description: "功能建设中")
            }
            .tabItem { Label("工作台", systemImage: "square.grid.2x2") }
            .tag(2)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
            .tag(3)
        }
        .onAppear {
            #if DEBUG
            // UI 测试钩子：直接落在「我的」Tab，绕开模拟器 Tab 点击不稳定问题
            if ProcessInfo.processInfo.arguments.contains("UITEST_OPEN_PROFILE") {
                selection = 3
            }
            #endif
        }
    }
}

/// 第一期占位页：系统 ContentUnavailableView（iOS 17），后续各期整页替换
struct PlaceholderTabView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(description))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
    }
}
