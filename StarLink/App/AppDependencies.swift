import Foundation

/// 依赖组装（设计书第 2 章）：mock / 真实实现在此切换，视图零感知
final class AppDependencies {
    let sessionStore: SessionStore
    let hapticService = HapticService()

    init() {
        let keychain = KeychainStore()
        #if DEBUG
        let loginService: LoginServicing = AppConfig.useMockServices
            ? MockLoginService()
            : AuthService(apiClient: APIClient(baseURL: AppConfig.apiBaseURL, tokenStore: keychain))
        #else
        let loginService = AuthService(apiClient: APIClient(baseURL: AppConfig.apiBaseURL, tokenStore: keychain))
        #endif
        self.sessionStore = SessionStore(loginService: loginService, keychain: keychain)
    }
}
