import SwiftUI
import SwiftData

/// 底部四 Tab 主框架（设计书 4.3）：系统 TabView + SF Symbols
/// useMockServices=true 时「消息」Tab 显示本地聊天 Demo（免费账号阶段的可演示形态）
/// modelContainer 挂在 TabView 层（覆盖所有推送视图；视图层读引擎 @Observable 状态）
struct MainTabView: View {
    #if DEBUG
    @Environment(SessionStore.self) private var session
    #endif

    /// Tab 选择走共享路由（工作台「点 = 填入/发送」需要跨 Tab 跳回消息）
    @State private var router = TabRouter.shared

    var body: some View {
        TabView(selection: Bindable(router).selection) {
            if AppConfig.useMockServices {
                NavigationStack {
                    ConversationListView()
                }
                .tabItem { Label("消息", systemImage: "message") }
                .tag(0)
            } else {
                NavigationStack {
                    PlaceholderTabView(title: "消息", systemImage: "message", description: "暂无消息")
                }
                .tabItem { Label("消息", systemImage: "message") }
                .tag(0)
            }

            NavigationStack {
                PlaceholderTabView(title: "AI", systemImage: "sparkles", description: "预留接口 · 暂未开放")
            }
            .tabItem { Label("AI", systemImage: "sparkles") }
            .tag(1)

            if AppConfig.useMockServices {
                NavigationStack {
                    WorkbenchView()
                }
                .tabItem { Label("码池", systemImage: "qrcode") }
                .tag(2)
            } else {
                NavigationStack {
                    PlaceholderTabView(title: "码池", systemImage: "qrcode", description: "功能建设中")
                }
                .tabItem { Label("码池", systemImage: "qrcode") }
                .tag(2)
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
            .tag(3)
        }
        .modelContainer(ChatDemoEngine.shared.container)
        .onAppear {
            #if DEBUG
            // UI 测试钩子：直接落在「我的」Tab / 登录后自动登出（仅 DEBUG）
            if ProcessInfo.processInfo.arguments.contains("UITEST_OPEN_PROFILE") {
                router.selection = 3
            }
            // UI 测试钩子：UITEST_OPEN_TAB_<n> 直接落在第 n 个 Tab（0=消息 2=工作台…）
            for arg in ProcessInfo.processInfo.arguments where arg.hasPrefix("UITEST_OPEN_TAB_") {
                if let tab = Int(arg.dropFirst("UITEST_OPEN_TAB_".count)), (0..<4).contains(tab) {
                    router.selection = tab
                }
            }
            if ProcessInfo.processInfo.arguments.contains("UITEST_LOGOUT_AUTO") {
                session.logout()
            }
            // UI 测试钩子：启动后自动向首个会话发一条消息（真机免触验证 @Observable 实时刷新）
            if ProcessInfo.processInfo.arguments.contains("UITEST_AUTOSEND") {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    guard let conv = ChatDemoEngine.shared.conversations().first else { return }
                    await ChatDemoEngine.shared.sendMessage(
                        "UITEST_AUTOSEND-\(Int(Date().timeIntervalSince1970))", in: conv.id
                    )
                }
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
