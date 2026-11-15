import Foundation

/// 本地 mock 登录服务（设计书 5.2）
/// 说明：为让免费账号阶段的 Release 真机包可用，mock 不再限定 DEBUG；
/// 接入真实后台时将 AppConfig.useMockServices 置 false，并恢复 DEBUG 门控。
struct MockLoginService: LoginServicing {
    func login(request: LoginRequest) async throws -> LoginResponse {
        try await Task.sleep(for: .milliseconds(800))

        guard request.account.hasPrefix("TEST_") else {
            throw APIError.invalidCredentials
        }
        if request.account == "TEST_offline" {
            throw APIError.offline
        }
        guard request.password == "123456" else {
            throw APIError.invalidCredentials
        }

        let name = String(request.account.dropFirst(5))
        return LoginResponse(
            token: "TEST-token-\(name)",
            expiresIn: 7200,
            user: User(id: name, name: "TEST_\(name)", role: "staff")
        )
    }
}
