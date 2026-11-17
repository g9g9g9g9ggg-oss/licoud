#if DEBUG
import XCTest
@testable import StarLink

/// 码池存储测试：领取扣余量 / 删除进锁定期 / 统计 / 延长 / 编辑 / 持久化回路 / 快捷栏 / 意图 / 置顶排序
@MainActor
final class WorkbenchStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "WorkbenchStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        if let suiteName { defaults.removePersistentDomain(forName: suiteName) }
        super.tearDown()
    }

    private func makeStore() -> WorkbenchStore {
        WorkbenchStore(defaults: defaults)
    }

    // MARK: - 种子与持久化

    func testSeedStartsWithDemoCode() {
        let store = makeStore()
        XCTAssertEqual(store.codes.count, 1, "预置演示码A（模拟扫码可达）")
        XCTAssertEqual(store.codes.first?.remark, "演示码A")
        XCTAssertEqual(store.codes.first?.codeNo, "45646")
        XCTAssertEqual(store.codes.first?.displayState, .active)
        XCTAssertEqual(store.poolRemaining, 660)
        XCTAssertEqual(store.totalCustomers, 15)
        XCTAssertFalse(store.welcomeText.isEmpty)
        XCTAssertFalse(store.quickTexts.isEmpty)
        XCTAssertFalse(store.libraryImages.isEmpty)
        XCTAssertFalse(store.quickImages.isEmpty)
        XCTAssertFalse(store.intents.isEmpty)
    }

    func testPersistRoundtrip() {
        let store = makeStore()
        store.updateWelcome(text: "自定义欢迎语", enabled: false)
        _ = store.claimCode(remark: "阿萨", style: .baiyuJinsha, badgeMode: .show, bottomText: "", logoMode: .brand)
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.welcomeText, "自定义欢迎语")
        XCTAssertFalse(reloaded.welcomeEnabled)
        XCTAssertEqual(reloaded.codes.count, 2)
        XCTAssertEqual(reloaded.codes.first(where: { $0.remark == "阿萨" })?.style, .baiyuJinsha)
    }

    // MARK: - 码池领取 / 统计 / 锁定期

    func testClaimDecrementsPoolAndIncrementsActive() {
        let store = makeStore()
        let before = store.poolRemaining
        let code = store.claimCode(remark: "地方g", style: .molvJinyu, badgeMode: .show, bottomText: "扫码咨询", logoMode: .brand)
        XCTAssertNotNil(code)
        XCTAssertEqual(store.poolRemaining, before - 1)
        XCTAssertEqual(store.activeCodes.count, 1)
        XCTAssertEqual(store.codes.first(where: { $0.remark == "地方g" })?.style, .molvJinyu)
        XCTAssertEqual(store.codes.first(where: { $0.remark == "地方g" })?.displayBottomText, "扫码咨询")
    }

    func testLockCodeMovesToLockedState() {
        let store = makeStore()
        let code = store.claimCode(remark: "曼斯", style: .mojinCatEye, badgeMode: .hidden, bottomText: "扫码咨询", logoMode: .none)
        XCTAssertNotNil(code)
        store.lockCode(id: code!.id)
        XCTAssertEqual(store.lockedCodes.count, 1)
        XCTAssertEqual(store.activeCodes.count, 0)
        XCTAssertNotNil(store.codes.first(where: { $0.id == code!.id })?.lockedUntil)
    }

    func testExtendCodeAfterExpiry() {
        let store = makeStore()
        let code = store.claimCode(remark: "是否", style: .zanglanJinyu, badgeMode: .show, bottomText: "", logoMode: .brand)
        XCTAssertNotNil(code)
        // 模拟过期：把有效期拨回过去
        if let index = store.codes.firstIndex(where: { $0.id == code!.id }) {
            store.codes[index].expiresAt = Date().addingTimeInterval(-3600)
        }
        XCTAssertEqual(store.expiredCodes.count, 1)
        store.extendCode(id: code!.id)
        XCTAssertEqual(store.expiredCodes.count, 0)
        XCTAssertTrue(store.codes.first(where: { $0.id == code!.id })!.expiresAt > Date())
    }

    func testUpdateCodeRemark() {
        let store = makeStore()
        let code = store.claimCode(remark: "临时名", style: .baiyuJinsha, badgeMode: .show, bottomText: "", logoMode: .none)
        store.updateCodeRemark(id: code!.id, remark: "地方g")
        XCTAssertEqual(store.codes.first(where: { $0.id == code!.id })?.remark, "地方g")
    }

    // MARK: - 模拟扫码（客户体系主链路）


    // MARK: - 快捷文字

    func testQuickTextCRUDAndMove() {
        let store = makeStore()
        let original = store.quickTexts
        store.moveQuickText(id: original[1].id, offset: -1)
        XCTAssertEqual(store.quickTexts[0].id, original[1].id)
        store.deleteQuickText(id: original[0].id)
        XCTAssertFalse(store.quickTexts.contains(where: { $0.id == original[0].id }))
    }

    // MARK: - 意图

    func testIntentAddSaveToggleDelete() {
        let store = makeStore()
        let before = store.intents.count
        let intent = store.addIntent(name: "测试意图")
        XCTAssertEqual(store.intents.count, before + 1)

        var modified = intent
        modified.phrases = ["你好", "在吗"]
        modified.textReply = TextReply(isEnabled: true, content: "您好～")
        store.saveIntent(modified)
        let saved = store.intents.first(where: { $0.id == intent.id })
        XCTAssertEqual(saved?.phrases, ["你好", "在吗"])
        XCTAssertEqual(saved?.textReply.content, "您好～")

        store.toggleIntent(id: intent.id, isEnabled: false)
        XCTAssertFalse(store.intents.first(where: { $0.id == intent.id })!.isEnabled)

        store.deleteIntent(id: intent.id)
        XCTAssertEqual(store.intents.count, before)
    }

    // MARK: - 会话置顶排序（内存引擎，避免污染共享单例）

    func testConversationPinSort() {
        let engine = ChatDemoEngine(
            container: StarLinkModelContainer.make(inMemory: true),
            transport: MockTransport(repliesEnabled: false)
        )
        let conversations = engine.conversations()
        guard conversations.count >= 2 else {
            XCTFail("种子会话不足")
            return
        }
        let second = conversations[1]
        engine.setPinned(true, forConversationID: second.id)
        XCTAssertEqual(engine.conversations().first?.id, second.id)
        XCTAssertTrue(engine.conversations().first!.isPinned)
        engine.setPinned(false, forConversationID: second.id)
        XCTAssertFalse(engine.conversations().contains(where: { $0.id == second.id && $0.isPinned }))
    }
}
#endif
