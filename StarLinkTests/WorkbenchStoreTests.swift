#if DEBUG
import XCTest
@testable import StarLink

/// 工作台 Mock 存储打磨包测试：持久化回路 / 客服码 CRUD / 快捷栏 / 意图 / 会话置顶排序
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

    func testSeedPopulatesAllModules() {
        let store = makeStore()
        XCTAssertFalse(store.welcomeText.isEmpty)
        XCTAssertEqual(store.qrSlots.count, 2)
        XCTAssertEqual(store.qrSlots.map(\.id), ["online", "offline"])
        XCTAssertFalse(store.quickTexts.isEmpty)
        XCTAssertFalse(store.libraryImages.isEmpty)
        XCTAssertFalse(store.quickImages.isEmpty)
        XCTAssertFalse(store.intents.isEmpty)
    }

    func testPersistRoundtrip() {
        let store = makeStore()
        store.updateWelcome(text: "自定义欢迎语", enabled: false)
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.welcomeText, "自定义欢迎语")
        XCTAssertFalse(reloaded.welcomeEnabled)
    }

    // MARK: - 客服码

    func testProduceCodeRefreshesURLAndExpiry() {
        let store = makeStore()
        let oldURL = store.qrSlots[0].content?.url
        store.produceCode(slotID: "online")
        let newContent = store.qrSlots[0].content
        XCTAssertNotEqual(newContent?.url, oldURL)
        XCTAssertTrue(newContent?.url.contains("/online/") ?? false)
        XCTAssertTrue(newContent!.expiresAt > Date())
    }

    func testToggleDisableAndDeleteCode() {
        let store = makeStore()
        store.updateSlotContent(slotID: "offline") { $0.isDisabled.toggle() }
        XCTAssertEqual(store.qrSlots[1].content?.isDisabled, true)
        store.deleteCode(slotID: "offline")
        XCTAssertNil(store.qrSlots[1].content)
    }

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
