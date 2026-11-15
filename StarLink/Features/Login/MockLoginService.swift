import Foundation

#if DEBUG
/// 本地 mock（设计书 5.2）：仅 DEBUG 编译进包；800ms 延迟模拟真实网络手感
/// 账号规则见 README-MAC.md 的 Mock 账号表
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
#endif
