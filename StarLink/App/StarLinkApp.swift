import SwiftUI

@main
struct StarLinkApp: App {
    @State private var dependencies: AppDependencies

    init() {
        let deps = AppDependencies()
        #if DEBUG
        // UI 测试钩子：带 UITEST_FRESH 启动参数时清空本地登录态（Release 不编译）
        if ProcessInfo.processInfo.arguments.contains("UITEST_FRESH") {
            deps.sessionStore.clearPersistedForUITest()
        }
        #endif
        deps.sessionStore.restore()
        _dependencies = State(initialValue: deps)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies.sessionStore)
                .environment(dependencies.hapticService)
        }
    }
}
