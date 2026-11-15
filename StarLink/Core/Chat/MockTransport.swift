#if DEBUG
import Foundation

/// 本地回环通道（设计书 6.1 MockTransport）：单机自测发送状态机 + 自动回复
/// 时延可注入（单元测试用毫秒级）；第二期正式接入时换 WebSocketTransport，协议不变
@MainActor
final class MockTransport: MessageTransport {
    var onIncoming: ((IncomingMessage) -> Void)?
    var onAck: ((String) -> Void)?
    var onReadReceipt: ((String) -> Void)?

    private let ackDelay: Duration
    private let readDelay: Duration
    private let replyDelay: Duration
    private let repliesEnabled: Bool

    private let replies = ["收到", "好的，我看一下", "稍等，马上处理", "明白", "这个我来跟进"]
    private var replyIndex = 0

    init(
        ackDelay: Duration = .milliseconds(600),
        readDelay: Duration = .milliseconds(1200),
        replyDelay: Duration = .milliseconds(1800),
        repliesEnabled: Bool = true
    ) {
        self.ackDelay = ackDelay
        self.readDelay = readDelay
        self.replyDelay = replyDelay
        self.repliesEnabled = repliesEnabled
    }

    func send(clientMsgID: String, conversationID: String, text: String) async throws {
        // 演示失败链路：文本含 FAIL（大小写不限）即发送失败，点重发可恢复
        if text.uppercased().contains("FAIL") {
            throw TransportError.sendFailed
        }

        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.ackDelay)
            self.onAck?(clientMsgID)
            try? await Task.sleep(for: self.readDelay)
            self.onReadReceipt?(clientMsgID)
            guard self.repliesEnabled else { return }
            try? await Task.sleep(for: self.replyDelay)
            let reply = self.replies[self.replyIndex % self.replies.count]
            self.replyIndex += 1
            self.onIncoming?(IncomingMessage(
                conversationID: conversationID,
                text: reply,
                clientMsgID: UUID().uuidString,
                sentAt: Date()
            ))
        }
    }
}
#endif
