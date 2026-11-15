import Foundation

/// 端点定义：路径 / 方法 / 请求体 / 是否携带 Token（设计书 3.1）
/// 路径不带前导斜杠，由 APIClient 拼接 baseURL
struct APIEndpoint {
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    let path: String
    let method: Method
    let body: Data?
    let requiresAuth: Bool

    static func login(_ request: LoginRequest) throws -> APIEndpoint {
        APIEndpoint(
            path: "api/v1/auth/login",
            method: .post,
            body: try JSONEncoder().encode(request),
            requiresAuth: false
        )
    }
}
