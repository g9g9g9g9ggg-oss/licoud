#if DEBUG
import XCTest
@testable import StarLink

/// 引擎测试：断言目标是引擎的 @Observable UI 状态（uiConversations / uiMessages）
@MainActor
final class ChatDemoEngineTests: XCTestCase {
    private func makeEngine(repliesEnabled: Bool = false) -> ChatDemoEngine {
        ChatDemoEngine(
            container: StarLinkModelContainer.make(inMemory: true),
            transport: MockTransport(
                ackDelay: .milliseconds(30),
                readDelay: .milliseconds(30),
                replyDelay: .milliseconds(30),
                repliesEnabled: repliesEnabled
            )
        )
    }

    func testSeedCreatesTwoConversationsWithUnread() {
        let engine = makeEngine()
        let list = engine.conversations()
        XCTAssertEqual(list.count, 2)
        XCTAssertTrue(list.contains { $0.unreadCount > 0 }, "种子数据应包含未读会话")
        XCTAssertEqual(engine.messages(for: "conv-1002").count, 3, "张三种子应含 3 条消息")
        XCTAssertEqual(engine.messages(for: "conv-1003").count, 2, "李四种子应含 2 条消息")
    }

    func testSendMessageAdvancesToReadAndUpdatesPreview() async throws {
        let engine = makeEngine()

        await engine.sendMessage("你好，在吗", in: "conv-1002")
        try await Task.sleep(for: .milliseconds(400))

        let list = engine.messages(for: "conv-1002")
        let sent = list.last { $0.text == "你好，在吗" }
        XCTAssertEqual(sent?.state, .read, "回执链 sending→sent→read 应走完")
        XCTAssertEqual(engine.conversation("conv-1002")?.lastMessageText, "你好，在吗")
    }

    func testFailTagMarksMessageFailed() async {
        let engine = makeEngine()

        await engine.sendMessage("这单 #fail 了", in: "conv-1002")

        let failed = engine.messages(for: "conv-1002").last { $0.text == "这单 #fail 了" }
        XCTAssertEqual(failed?.state, .failed)
    }

    func testIncomingBumpsUnreadAndPreview() {
        let engine = makeEngine()
        let before = engine.conversation("conv-1002")!.unreadCount

        engine.handleIncoming(IncomingMessage(
            conversationID: "conv-1002",
            senderID: "1002",
            text: "资料发你了",
            clientMsgID: UUID().uuidString,
            sentAt: Date()
        ))

        let after = engine.conversation("conv-1002")!
        XCTAssertEqual(after.unreadCount, before + 1)
        XCTAssertEqual(after.lastMessageText, "资料发你了")
        XCTAssertEqual(engine.messages(for: "conv-1002").last?.text, "资料发你了")
    }

    func testIncomingToActiveConversationDoesNotBumpUnread() {
        let engine = makeEngine()
        engine.activeConversationID = "conv-1002"
        let before = engine.conversation("conv-1002")!.unreadCount

        engine.handleIncoming(IncomingMessage(
            conversationID: "conv-1002",
            senderID: "1002",
            text: "看到了吗",
            clientMsgID: UUID().uuidString,
            sentAt: Date()
        ))

        XCTAssertEqual(engine.conversation("conv-1002")?.unreadCount, before)
    }

    func testMarkConversationReadClearsUnread() {
        let engine = makeEngine()
        XCTAssertEqual(engine.conversation("conv-1003")?.unreadCount, 2)

        engine.markConversationRead(withID: "conv-1003")

        XCTAssertEqual(engine.conversation("conv-1003")?.unreadCount, 0)
    }

    func testFindOrCreateConversationIsIdempotent() {
        let engine = makeEngine()
        let first = engine.findOrCreateConversation(peerID: "1004", peerName: "TEST_王五")
        XCTAssertEqual(first.id, "conv-1004")

        let second = engine.findOrCreateConversation(peerID: "1004", peerName: "TEST_王五")
        XCTAssertEqual(first.id, second.id, "重复调用不应新建会话")
        XCTAssertEqual(engine.conversations().count, 3)
    }

    func testDeleteConversationRemovesFromUI() {
        let engine = makeEngine()
        engine.deleteConversation("conv-1003")
        XCTAssertNil(engine.conversation("conv-1003"))
        XCTAssertEqual(engine.conversations().count, 1)
        XCTAssertEqual(engine.messages(for: "conv-1003").count, 0)
    }
}
#endif
