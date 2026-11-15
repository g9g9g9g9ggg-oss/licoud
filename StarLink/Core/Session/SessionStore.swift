import Foundation
import Observation

/// 登录态中枢（设计书 3.3）
/// 启动 restore() 纯本地判定：Keychain 有 token 即进主框架（杀进程重开仍登录）
/// 运行中收到 .unauthorized 再回落登录页
@Observable
final class SessionStore {
    enum State: Equatable {
        case launching
        case loggedOut
        case loggedIn(User)
    }

    private(set) var state: State = .launching

    private let loginService: LoginServicing
    private let keychain: KeychainStore

    init(loginService: LoginServicing, keychain: KeychainStore = KeychainStore()) {
        self.loginService = loginService
        self.keychain = keychain
    }

    var currentUser: User? {
        if case let .loggedIn(user) = state { return user }
        return nil
    }

    /// App 启动即调
    func restore() {
        if keychain.readString(for: .token) != nil, let user = keychain.readUser() {
            state = .loggedIn(user)
        } else {
            state = .loggedOut
        }
    }

    func login(account: String, password: String) async throws {
        let response = try await loginService.login(
            request: .init(account: account, password: password)
        )
        try? keychain.saveString(response.token, for: .token)
        try? keychain.saveUser(response.user)
        state = .loggedIn(response.user)
    }

    /// 登出：清 Keychain → 登录页。根视图切换，无导航栈可返回内页（设计书 4.5）
    func logout() {
        keychain.deleteAll()
        state = .loggedOut
    }
}
