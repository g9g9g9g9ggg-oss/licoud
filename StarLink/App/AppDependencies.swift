import Foundation

/// 依赖组装（设计书第 2 章）：mock / 真实实现在此切换，视图零感知
/// 免费账号阶段：useMockServices=true 让 Release 真机包也能登录（mock 登录）；
/// 接入真实后台后置 false（届时再把 MockLoginService 恢复 DEBUG 门控）。
final class AppDependencies {
    let sessionStore: SessionStore
    let hapticService = HapticService()

    init() {
        let keychain = KeychainStore()
        let loginService: LoginServicing = AppConfig.useMockServices
            ? MockLoginService()
            : AuthService(apiClient: APIClient(baseURL: AppConfig.apiBaseURL, tokenStore: keychain))
        self.sessionStore = SessionStore(loginService: loginService, keychain: keychain)
    }
}
