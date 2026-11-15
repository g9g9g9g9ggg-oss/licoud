#if DEBUG
import SwiftData
import XCTest
@testable import StarLink

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

    private func conversations(of engine: ChatDemoEngine) -> [Conversation] {
        (try? engine.container.mainContext.fetch(FetchDescriptor<Conversation>())) ?? []
    }

    private func messages(of engine: ChatDemoEngine, text: String) -> [Message] {
        (try? engine.container.mainContext.fetch(
            FetchDescriptor<Message>(predicate: #Predicate { $0.text == text })
        )) ?? []
    }

    func testSeedCreatesTwoConversationsWithUnread() {
        let engine = makeEngine()
        let list = conversations(of: engine)
        XCTAssertEqual(list.count, 2)
        XCTAssertTrue(list.contains { $0.unreadCount > 0 }, "种子数据应包含未读会话")
    }

    func testSendMessageAdvancesToReadAndUpdatesPreview() async throws {
        let engine = makeEngine()
        let conversation = conversations(of: engine).first { $0.id == "conv-1002" }!

        await engine.sendMessage("你好，在吗", in: conversation)
        try await Task.sleep(for: .milliseconds(400))

        let sent = messages(of: engine, text: "你好，在吗")
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?.state, .read, "回执链 sending→sent→read 应走完")
        XCTAssertEqual(conversations(of: engine).first { $0.id == "conv-1002" }?.lastMessageText, "你好，在吗")
    }

    func testFailTagMarksMessageFailed() async {
        let engine = makeEngine()
        let conversation = conversations(of: engine).first { $0.id == "conv-1002" }!

        await engine.sendMessage("这单 #fail 了", in: conversation)

        let failed = messages(of: engine, text: "这单 #fail 了")
        XCTAssertEqual(failed.count, 1)
        XCTAssertEqual(failed.first?.state, .failed)
    }

    func testIncomingBumpsUnreadAndPreview() {
        let engine = makeEngine()
        let before = conversations(of: engine).first { $0.id == "conv-1002" }!.unreadCount

        engine.handleIncoming(IncomingMessage(
            conversationID: "conv-1002",
            senderID: "1002",
            text: "资料发你了",
            clientMsgID: UUID().uuidString,
            sentAt: Date()
        ))

        let after = conversations(of: engine).first { $0.id == "conv-1002" }!
        XCTAssertEqual(after.unreadCount, before + 1)
        XCTAssertEqual(after.lastMessageText, "资料发你了")
    }

    func testIncomingToActiveConversationDoesNotBumpUnread() {
        let engine = makeEngine()
        engine.activeConversationID = "conv-1002"
        let before = conversations(of: engine).first { $0.id == "conv-1002" }!.unreadCount

        engine.handleIncoming(IncomingMessage(
            conversationID: "conv-1002",
            senderID: "1002",
            text: "看到了吗",
            clientMsgID: UUID().uuidString,
            sentAt: Date()
        ))

        XCTAssertEqual(conversations(of: engine).first { $0.id == "conv-1002" }?.unreadCount, before)
    }

    func testMarkConversationReadClearsUnread() {
        let engine = makeEngine()
        XCTAssertEqual(conversations(of: engine).first { $0.id == "conv-1003" }?.unreadCount, 2)

        engine.markConversationRead(withID: "conv-1003")

        XCTAssertEqual(conversations(of: engine).first { $0.id == "conv-1003" }?.unreadCount, 0)
    }

    func testFindOrCreateConversationIsIdempotent() {
        let engine = makeEngine()
        let first = engine.findOrCreateConversation(peerID: "1004", peerName: "TEST_王五")
        XCTAssertEqual(first.id, "conv-1004")

        let second = engine.findOrCreateConversation(peerID: "1004", peerName: "TEST_王五")
        XCTAssertEqual(first.id, second.id, "重复调用不应新建会话")
        XCTAssertEqual(conversations(of: engine).count, 3)
    }
}
#endif
