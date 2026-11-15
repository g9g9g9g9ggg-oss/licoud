import XCTest
@testable import StarLink

/// 设计书 8.1：存 / 读 / 删 / 键不存在 / 全清
final class KeychainStoreTests: XCTestCase {
    private var store: KeychainStore!

    override func setUp() {
        super.setUp()
        // 每个用例独立 service，避免用例间互相污染
        store = KeychainStore(service: "com.starlink.ios.tests.\(UUID().uuidString)")
    }

    func testSaveAndReadString() throws {
        try store.saveString("token-abc", for: .token)
        XCTAssertEqual(store.readString(for: .token), "token-abc")
    }

    func testReadNonexistentReturnsNil() {
        XCTAssertNil(store.readString(for: .token))
        XCTAssertNil(store.readUser())
    }

    func testDeleteRemovesValue() throws {
        try store.saveString("token-abc", for: .token)
        store.delete(.token)
        XCTAssertNil(store.readString(for: .token))
    }

    func testDeleteNonexistentDoesNotThrow() {
        store.delete(.token)
        XCTAssertNil(store.readString(for: .token))
    }

    func testSaveAndReadUser() throws {
        let user = User(id: "1001", name: "TEST_1001", role: "staff")
        try store.saveUser(user)
        XCTAssertEqual(store.readUser(), user)
    }

    func testDeleteAllClearsEveryKey() throws {
        try store.saveString("token-abc", for: .token)
        try store.saveUser(User(id: "1001", name: "TEST_1001", role: "staff"))
        store.deleteAll()
        XCTAssertNil(store.readString(for: .token))
        XCTAssertNil(store.readUser())
    }

    func testOverwriteLatestValueWins() throws {
        try store.saveString("old", for: .token)
        try store.saveString("new", for: .token)
        XCTAssertEqual(store.readString(for: .token), "new")
    }
}
