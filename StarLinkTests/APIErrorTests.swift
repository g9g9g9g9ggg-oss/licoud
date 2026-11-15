import XCTest
@testable import StarLink

/// 设计书 8.1：错误 → 用户文案映射（任务书 0.3：短句）
final class APIErrorTests: XCTestCase {
    func testOfflineMessage() {
        XCTAssertEqual(APIError.offline.userMessage, "网络不可用，请检查网络")
    }

    func testTimeoutMessage() {
        XCTAssertEqual(APIError.timeout.userMessage, "连接超时，请重试")
    }

    func testInvalidCredentialsMessage() {
        XCTAssertEqual(APIError.invalidCredentials.userMessage, "账号或密码错误")
    }

    func testServerMessage() {
        XCTAssertEqual(APIError.server(500, "boom").userMessage, "服务暂不可用，请稍后再试")
    }

    func testUnknownAndDecodingShareFallback() {
        XCTAssertEqual(APIError.unknown.userMessage, "出错了，请重试")
        XCTAssertEqual(APIError.decoding.userMessage, "出错了，请重试")
    }

    func testAllMessagesAreShort() {
        for error in [APIError.offline, .timeout, .invalidCredentials, .unauthorized,
                      .server(500, ""), .decoding, .unknown] {
            XCTAssertLessThanOrEqual(error.userMessage.count, 12, "\(error) 文案应 ≤ 12 字")
        }
    }
}
