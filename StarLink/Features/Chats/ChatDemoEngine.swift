#if DEBUG
import Foundation
import Observation
import SwiftData

/// 聊天引擎（第二期预写）：消息收发状态机、未读数、触感、种子数据
/// 真实接口 / 实时通道留桩——三问确认后只替换 MessageTransport 实现，本类不动
@MainActor
final class ChatDemoEngine {
    static let shared = ChatDemoEngine()

    private(set) var container: ModelContainer
    private let context: ModelContext
    private let transport: MessageTransport
    private var haptic = HapticService()

    /// 当前登录用户（MainTabView 出现时从 SessionStore 对齐；种子数据按 TEST_1001）
    var myUserID = "1001"
    /// 正在查看的会话：其新消息不累计未读（ChatView 生命周期维护）
    var activeConversationID: String?

    init(container: ModelContainer? = nil, transport: MessageTransport? = nil) {
        let resolvedContainer = container ?? StarLinkModelContainer.make()
        self.container = resolvedContainer
        self.context = resolvedContainer.mainContext
        self.transport = transport ?? MockTransport()
        installTransportCallbacks()
        seedIfNeeded()
    }

    /// 由 MainTabView 在出现时对齐真实登录用户与全局触感实例
    func attach(hapticService: HapticService, myUserID: String) {
        self.haptic = hapticService
        self.myUserID = myUserID
    }

    // MARK: - 发送

    func sendMessage(_ text: String, in conversation: Conversation) async {
        let message = Message(
            id: UUID().uuidString,
            conversationID: conversation.id,
            senderID: myUserID,
            kind: .text,
            text: text,
            state: .sending,
            sentAt: Date()
        )
        await performSend(message, in: conversation, transportText: text)
    }

    /// 图片消息（本地闭环）：压缩落库走完整状态机；上传链路 TODO(第二期接口)
    func sendImage(rawData: Data, in conversation: Conversation) async {
        guard let imageData = ImageResizer.resize(data: rawData, maxDimension: 1280, quality: 0.8) else {
            return
        }
        let message = Message(
            id: UUID().uuidString,
            conversationID: conversation.id,
            senderID: myUserID,
            kind: .image,
            text: "[图片]",
            state: .sending,
            sentAt: Date(),
            imageData: imageData
        )
        await performSend(message, in: conversation, transportText: "[图片]")
    }

    private func performSend(_ message: Message, in conversation: Conversation, transportText: String) async {
        message.conversation = conversation
        conversation.lastMessageText = message.text
        conversation.lastMessageAt = message.sentAt
        context.insert(message)
        save()

        do {
            try await transport.send(clientMsgID: message.id, conversationID: conversation.id, text: transportText)
            // 正常路径：sent/read 由回执回调推进（真实通道亦然）
        } catch {
            message.state = .failed
            save()
        }
    }

    /// 点击失败气泡的状态图标重发
    func retryMessage(_ message: Message) {
        guard message.state == .failed else { return }
        message.state = .sending
        save()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.transport.send(clientMsgID: message.id, conversationID: message.conversationID, text: message.text)
            } catch {
                message.state = .failed
                self.save()
            }
        }
    }

    // MARK: - 接收

    private func installTransportCallbacks() {
        transport.onIncoming = { [weak self] incoming in
            self?.handleIncoming(incoming)
        }
        transport.onAck = { [weak self] clientMsgID in
            self?.handleAck(clientMsgID)
        }
        transport.onReadReceipt = { [weak self] clientMsgID in
            self?.handleReadReceipt(clientMsgID)
        }
    }

    /// 通道回调入口（测试可见：单测直接投喂 IncomingMessage 验证未读/预览逻辑）
    func handleIncoming(_ incoming: IncomingMessage) {
        guard let conversation = conversation(withID: incoming.conversationID) else { return }
        let senderID = incoming.senderID.isEmpty ? conversation.peerID : incoming.senderID
        let message = Message(
            id: incoming.clientMsgID,
            conversationID: conversation.id,
            senderID: senderID,
            kind: .text,
            text: incoming.text,
            state: .sent,
            sentAt: incoming.sentAt
        )
        message.conversation = conversation
        conversation.lastMessageText = incoming.text
        conversation.lastMessageAt = incoming.sentAt
        context.insert(message)

        if conversation.id != activeConversationID {
            conversation.unreadCount += 1
            haptic.fire(.messageReceived)
        }
        save()
    }

    private func handleAck(_ clientMsgID: String) {
        guard let message = message(withID: clientMsgID) else { return }
        message.state = .sent
        haptic.fire(.sendSuccess)
        save()
    }

    private func handleReadReceipt(_ clientMsgID: String) {
        guard let message = message(withID: clientMsgID) else { return }
        message.state = .read
        save()
    }

    // MARK: - 会话操作

    func markConversationRead(withID id: String) {
        guard let conversation = conversation(withID: id) else { return }
        conversation.unreadCount = 0
        save()
    }

    func deleteConversation(_ conversation: Conversation) {
        context.delete(conversation)
        save()
    }

    func conversation(withID id: String) -> Conversation? {
        var descriptor = FetchDescriptor<Conversation>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// 联系人一步开聊：按 peerID 找会话，没有则创建（会话 ID 确定性：conv-<peerID>）
    func findOrCreateConversation(peerID: String, peerName: String) -> Conversation {
        if let existing = fetchConversation(peerID: peerID) {
            return existing
        }
        let conversation = Conversation(id: "conv-\(peerID)", peerID: peerID, peerName: peerName)
        context.insert(conversation)
        save()
        return conversation
    }

    private func fetchConversation(peerID: String) -> Conversation? {
        var descriptor = FetchDescriptor<Conversation>(predicate: #Predicate { $0.peerID == peerID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func message(withID id: String) -> Message? {
        var descriptor = FetchDescriptor<Message>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: - 种子数据（单机演示用，正式第二期由真实数据替代）

    private func seedIfNeeded() {
        let count = (try? context.fetchCount(FetchDescriptor<Conversation>())) ?? 0
        guard count == 0 else { return }

        let zhang = Conversation(id: "conv-1002", peerID: "1002", peerName: "TEST_张三")
        let li = Conversation(id: "conv-1003", peerID: "1003", peerName: "TEST_李四", unreadCount: 2)
        context.insert(zhang)
        context.insert(li)

        let base = Calendar.current.date(byAdding: .hour, value: -26, to: Date()) ?? Date()
        let zhangMessages: [(sender: String, text: String, state: MessageState, sentAt: Date)] = [
            ("1002", "在吗，昨天那批客户资料我更新了", .read, base),
            (myUserID, "收到，我看一下", .read, base.addingTimeInterval(120)),
            ("1002", "重点是后面三条跟进记录", .read, base.addingTimeInterval(180)),
        ]
        for item in zhangMessages {
            let message = Message(
                id: UUID().uuidString, conversationID: zhang.id, senderID: item.sender,
                kind: .text, text: item.text, state: item.state, sentAt: item.sentAt
            )
            message.conversation = zhang
            context.insert(message)
        }
        zhang.lastMessageText = "重点是后面三条跟进记录"
        zhang.lastMessageAt = base.addingTimeInterval(180)

        let liBase = Calendar.current.date(byAdding: .hour, value: -70, to: Date()) ?? Date()
        let liMessages: [(sender: String, text: String, sentAt: Date)] = [
            ("1003", "周四的客户回访我排到上午了", liBase),
            ("1003", "你那边资料记得同步我一份", liBase.addingTimeInterval(90)),
        ]
        for item in liMessages {
            let message = Message(
                id: UUID().uuidString, conversationID: li.id, senderID: item.sender,
                kind: .text, text: item.text, state: .read, sentAt: item.sentAt
            )
            message.conversation = li
            context.insert(message)
        }
        li.lastMessageText = "你那边资料记得同步我一份"
        li.lastMessageAt = liBase.addingTimeInterval(90)

        save()
    }

    private func save() {
        try? context.save()
    }
}
#endif
