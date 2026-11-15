#if DEBUG
import XCTest
@testable import StarLink

@MainActor
final class MockTransportTests: XCTestCase {
    func testSendDeliversAckAndReadReceipt() async throws {
        let transport = MockTransport(
            ackDelay: .milliseconds(30),
            readDelay: .milliseconds(30),
            repliesEnabled: false
        )
        var acked: [String] = []
        var read: [String] = []
        transport.onAck = { acked.append($0) }
        transport.onReadReceipt = { read.append($0) }

        try await transport.send(clientMsgID: "m1", conversationID: "c1", text: "hello")
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(acked, ["m1"])
        XCTAssertEqual(read, ["m1"])
    }

    func testFailTagThrowsSendFailed() async {
        let transport = MockTransport(repliesEnabled: false)
        do {
            try await transport.send(clientMsgID: "m2", conversationID: "c1", text: "这单 #FAIL 了")
            XCTFail("含 FAIL 应当抛出 sendFailed")
        } catch {
            // 预期路径
        }
    }

    func testReplyGeneratesIncomingMessage() async throws {
        let transport = MockTransport(
            ackDelay: .milliseconds(10),
            readDelay: .milliseconds(10),
            replyDelay: .milliseconds(10)
        )
        var received: [IncomingMessage] = []
        transport.onIncoming = { received.append($0) }

        try await transport.send(clientMsgID: "m3", conversationID: "c7", text: "在吗")
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.conversationID, "c7")
    }
}
#endif
