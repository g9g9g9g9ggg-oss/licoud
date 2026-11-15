import Foundation

/// 通道侧送达的新消息
struct IncomingMessage {
    let conversationID: String
    var senderID: String = ""
    let text: String
    let clientMsgID: String
    let sentAt: Date
}

enum TransportError: Error {
    case sendFailed
}

/// 实时通道抽象（设计书 6.1）：三问确认后用 WebSocket / 轮询实现同一协议，只换实现不动上层
/// onAck = 送达回执（sent）；onReadReceipt = 已读回执（read）
@MainActor
protocol MessageTransport: AnyObject {
    var onIncoming: ((IncomingMessage) -> Void)? { get set }
    var onAck: ((_ clientMsgID: String) -> Void)? { get set }
    var onReadReceipt: ((_ clientMsgID: String) -> Void)? { get set }

    func send(clientMsgID: String, conversationID: String, text: String) async throws
}
