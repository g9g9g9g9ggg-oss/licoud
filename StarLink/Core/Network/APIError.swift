import Foundation

/// 统一错误模型 + 用户文案映射（设计书 3.1）
enum APIError: Error, Equatable {
    case offline
    case timeout
    case invalidCredentials
    case unauthorized
    case server(Int, String)
    case decoding
    case unknown

    /// 用户文案（任务书 0.3：短句，≤ 12 字）
    var userMessage: String {
        switch self {
        case .offline:            return "网络不可用，请检查网络"
        case .timeout:            return "连接超时，请重试"
        case .invalidCredentials: return "账号或密码错误"
        case .unauthorized:       return "登录已过期，请重新登录"
        case .server:             return "服务暂不可用，请稍后再试"
        case .decoding, .unknown: return "出错了，请重试"
        }
    }
}
