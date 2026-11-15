import Foundation

/// 当前登录用户（设计书 5.1，字段待后台确认后对齐）
struct User: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let role: String
}

/// 登录接口请求体
struct LoginRequest: Codable, Sendable {
    let account: String
    let password: String
}

/// 登录接口响应（expiresIn 无此字段时按长期有效处理）
struct LoginResponse: Codable, Sendable {
    let token: String
    let expiresIn: Int?
    let user: User
}
