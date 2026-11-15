import XCTest
@testable import StarLink

/// 设计书 8.1：restore 有/无 token 两路径；login 成功落 Keychain；logout 清理
final class SessionStoreTests: XCTestCase {
    private var keychain: KeychainStore!

    override func setUp() {
        super.setUp()
        keychain = KeychainStore(service: "com.starlink.ios.tests.\(UUID().uuidString)")
    }

    private func makeStore() -> SessionStore {
        SessionStore(loginService: MockLoginService(), keychain: keychain)
    }

    func testRestoreWithoutTokenIsLoggedOut() {
        let store = makeStore()
        store.restore()
        XCTAssertEqual(store.state, .loggedOut)
    }

    func testLoginSuccessBecomesLoggedInAndPersists() async throws {
        let store = makeStore()
        try await store.login(account: "TEST_1001", password: "123456")

        XCTAssertEqual(store.state, .loggedIn(User(id: "1001", name: "TEST_1001", role: "staff")))
        XCTAssertNotNil(keychain.readString(for: .token))
        XCTAssertEqual(keychain.readUser()?.id, "1001")

        // 模拟杀进程重开：新建 store（同一 keychain）后 restore 应保持登录
        let relaunched = makeStore()
        relaunched.restore()
        XCTAssertEqual(relaunched.state, .loggedIn(User(id: "1001", name: "TEST_1001", role: "staff")))
    }

    func testLogoutClearsStateAndKeychain() async throws {
        let store = makeStore()
        try await store.login(account: "TEST_1001", password: "123456")

        store.logout()

        XCTAssertEqual(store.state, .loggedOut)
        XCTAssertNil(keychain.readString(for: .token))
        XCTAssertNil(keychain.readUser())

        let relaunched = makeStore()
        relaunched.restore()
        XCTAssertEqual(relaunched.state, .loggedOut)
    }

    func testLoginFailureStaysLoggedOut() async {
        let store = makeStore()
        do {
            try await store.login(account: "TEST_1001", password: "wrong")
            XCTFail("应当抛出 invalidCredentials")
        } catch {
            XCTAssertEqual(error as? APIError, .invalidCredentials)
        }
        XCTAssertEqual(store.state, .loggedOut)
        XCTAssertNil(keychain.readString(for: .token))
    }
}
