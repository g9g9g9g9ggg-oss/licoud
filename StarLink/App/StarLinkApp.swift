import SwiftUI

@main
struct StarLinkApp: App {
    @State private var dependencies: AppDependencies

    init() {
        let deps = AppDependencies()
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
