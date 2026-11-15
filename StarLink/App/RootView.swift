import SwiftUI

/// 根视图（设计书 4.1）：依登录态切换，系统弹簧动画，不自定义转场
struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(HapticService.self) private var haptic

    var body: some View {
        ZStack {
            switch session.state {
            case .launching:
                ProgressView()
            case .loggedOut:
                LoginView()
                    .transition(.opacity)
            case .loggedIn:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: session.state)
        .haptics(haptic)
    }
}
