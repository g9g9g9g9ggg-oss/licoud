import Foundation

/// 登录服务协议：真实 / Mock 可替换（设计书 1.1、5.2）
protocol LoginServicing: Sendable {
    func login(request: LoginRequest) async throws -> LoginResponse
}

/// 真实实现：接后台测试环境后启用（设计书 5.1，字段待后台确认）
/// 登录接口的 401 映射为「账号或密码错误」，其余接口的 401 由 SessionStore 处理登出
struct AuthService: LoginServicing {
    let apiClient: APIClient

    func login(request: LoginRequest) async throws -> LoginResponse {
        do {
            return try await apiClient.request(try .login(request))
        } catch let error as APIError where error == .unauthorized {
            throw APIError.invalidCredentials
        }
    }
}
