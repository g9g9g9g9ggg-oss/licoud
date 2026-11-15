import Foundation
import OSLog

/// 统一网络入口：Token 注入、错误归一、超时 15s、脱敏日志（设计书 3.1）
/// 业务层只面对 APIEndpoint 与已解码模型；日志只打路径/状态码/耗时，不打敏感字段
final class APIClient: Sendable {
    private let baseURL: URL
    private let tokenStore: KeychainStore
    private let session: URLSession
    private let logger = Logger(subsystem: "com.starlink.ios", category: "api")

    init(baseURL: URL, tokenStore: KeychainStore) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: configuration)
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let data = try await send(endpoint)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    func requestVoid(_ endpoint: APIEndpoint) async throws {
        _ = try await send(endpoint)
    }

    private func send(_ endpoint: APIEndpoint) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if endpoint.requiresAuth,
           let token = tokenStore.readString(for: .token) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let started = Date()
        do {
            let (data, response) = try await session.data(for: request)
            let elapsed = Date().timeIntervalSince(started)
            guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
            logger.info("\(endpoint.path, privacy: .public) \(http.statusCode, privacy: .public) \(elapsed, privacy: .public)s")
            switch http.statusCode {
            case 200..<300:
                return data
            case 401:
                throw APIError.unauthorized
            case 400..<500:
                let message = (try? JSONDecoder().decode(ServerMessage.self, from: data))?.message ?? ""
                throw APIError.server(http.statusCode, message)
            default:
                throw APIError.server(http.statusCode, "internal")
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError
            where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw APIError.offline
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.unknown
        }
    }
}

private struct ServerMessage: Decodable {
    let code: String?
    let message: String
}
