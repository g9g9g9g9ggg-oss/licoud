import XCTest
@testable import StarLink

/// 设计书 8.1：mock 三路径（成功 / 密码错 / offline）
final class MockLoginServiceTests: XCTestCase {
    private let service = MockLoginService()

    func testSuccessReturnsTESTUser() async throws {
        let response = try await service.login(
            request: .init(account: "TEST_1001", password: "123456")
        )
        XCTAssertEqual(response.user.id, "1001")
        XCTAssertEqual(response.user.name, "TEST_1001")
        XCTAssertEqual(response.user.role, "staff")
        XCTAssertTrue(response.token.hasPrefix("TEST-token-"))
    }

    func testWrongPasswordThrowsInvalidCredentials() async {
        do {
            _ = try await service.login(request: .init(account: "TEST_1001", password: "wrong"))
            XCTFail("应当抛出 invalidCredentials")
        } catch {
            XCTAssertEqual(error as? APIError, .invalidCredentials)
        }
    }

    func testOfflineAccountThrowsOffline() async {
        do {
            _ = try await service.login(request: .init(account: "TEST_offline", password: "123456"))
            XCTFail("应当抛出 offline")
        } catch {
            XCTAssertEqual(error as? APIError, .offline)
        }
    }

    func testNonTESTAccountThrowsInvalidCredentials() async {
        do {
            _ = try await service.login(request: .init(account: "admin", password: "123456"))
            XCTFail("应当抛出 invalidCredentials")
        } catch {
            XCTAssertEqual(error as? APIError, .invalidCredentials)
        }
    }
}
