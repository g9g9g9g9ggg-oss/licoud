import Foundation
import Observation
import SwiftData

// 第二期预写（附录 B 已批准范围变更）：聊天引擎
// 架构说明：UI 层数据源为本类的 @Observable 状态（uiConversations / uiMessages），
// SwiftData 仅作持久化底层——规避 @Query 在部分 iOS 版本真机上推送视图不刷新的问题。

@MainActor
final class ChatDemoEngine {
    static let shared = ChatDemoEngine()

    private(set) var container: ModelContainer
    private let context: ModelContext
    private let transport: MessageTransport
    private var haptic = HapticService()

    var myUserID = "1001"
    /// 正在查看的会话：其新消息不累计未读（ChatView 生命周期维护）
    var activeConversationID: String?

    // UI 层唯一数据源（@Observable；字典/数组更新一律整体重赋值以触发观察）
    private(set) var uiConversations: [ChatConversation] = []
    private(set) var uiMessages: [String: [ChatMessage]] = [:]

    init(container: ModelContainer? = nil, transport: MessageTransport? = nil) {
        let resolvedContainer = container ?? StarLinkModelContainer.make()
        self.container = resolvedContainer
        self.context = resolvedContainer.mainContext
        self.transport = transport ?? MockTransport()
        installTransportCallbacks()
        seedIfNeeded()
        loadUIFromStore()
    }

    /// 由 App 启动时对齐真实登录用户与全局触感实例
    func attach(hapticService: HapticService, myUserID: String) {
        self.haptic = hapticService
        self.myUserID = myUserID
    }

    // MARK: - UI 读取

    func conversations() -> [ChatConversation] {
        uiConversations.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    func messages(for conversationID: String) -> [ChatMessage] {
        (uiMessages[conversationID] ?? []).sorted { $0.sentAt < $1.sentAt }
    }

    func conversation(_ id: String) -> ChatConversation? {
        uiConversations.first { $0.id == id }
    }

    // MARK: - 发送

    func sendMessage(_ text: String, in conversationID: String) async {
        guard let conversation = storeConversation(withID: conversationID) else { return }
        let message = Message(
            id: UUID().uuidString,
            conversationID: conversationID,
            senderID: myUserID,
            kind: .text,
            text: text,
            state: .sending,
            sentAt: Date()
        )
        performStoreInsert(message, in: conversation)
        pushMessageUI(message)
        syncConversationUI(conversation)
        await dispatchSend(message, transportText: text)
    }

    /// 图片消息（本地闭环）：压缩落库走完整状态机；上传链路 TODO(第二期接口)
    func sendImage(rawData: Data, in conversationID: String) async {
        guard let conversation = storeConversation(withID: conversationID) else { return }
        guard let imageData = ImageResizer.resize(data: rawData, maxDimension: 1280, quality: 0.8) else { return }
        let message = Message(
            id: UUID().uuidString,
            conversationID: conversationID,
            senderID: myUserID,
            kind: .image,
            text: "[图片]",
            state: .sending,
            sentAt: Date(),
            imageData: imageData
        )
        performStoreInsert(message, in: conversation)
        pushMessageUI(message)
        syncConversationUI(conversation)
        await dispatchSend(message, transportText: "[图片]")
    }

    /// 点击失败气泡的状态图标重发
    func retryMessage(_ chatMessage: ChatMessage) {
        guard chatMessage.state == .failed, let stored = storeMessage(withID: chatMessage.id) else { return }
        stored.state = .sending
        save()
        updateMessageUI(stored)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.transport.send(clientMsgID: stored.id, conversationID: stored.conversationID, text: stored.text)
            } catch {
                stored.state = .failed
                self.save()
                self.updateMessageUI(stored)
            }
        }
    }

    private func performStoreInsert(_ message: Message, in conversation: Conversation) {
        message.conversation = conversation
        conversation.lastMessageText = message.text
        conversation.lastMessageAt = message.sentAt
        context.insert(message)
        save()
    }

    private func dispatchSend(_ message: Message, transportText: String) async {
        do {
            try await transport.send(clientMsgID: message.id, conversationID: message.conversationID, text: transportText)
            // 正常路径：sent/read 由回执回调推进
        } catch {
            message.state = .failed
            save()
            updateMessageUI(message)
        }
    }

    // MARK: - 接收 / 回执

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
        guard let conversation = storeConversation(withID: incoming.conversationID) else { return }
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
        pushMessageUI(message)
        syncConversationUI(conversation)
    }

    private func handleAck(_ clientMsgID: String) {
        guard let message = storeMessage(withID: clientMsgID) else { return }
        message.state = .sent
        haptic.fire(.sendSuccess)
        save()
        updateMessageUI(message)
    }

    private func handleReadReceipt(_ clientMsgID: String) {
        guard let message = storeMessage(withID: clientMsgID) else { return }
        message.state = .read
        save()
        updateMessageUI(message)
    }

    // MARK: - 会话操作

    func markConversationRead(withID id: String) {
        guard let conversation = storeConversation(withID: id) else { return }
        conversation.unreadCount = 0
        save()
        syncConversationUI(conversation)
    }

    func deleteConversation(_ conversationID: String) {
        guard let conversation = storeConversation(withID: conversationID) else { return }
        context.delete(conversation)
        save()
        uiConversations.removeAll { $0.id == conversationID }
        uiMessages[conversationID] = nil
    }

    /// 联系人一步开聊：按 peerID 找会话，没有则创建
    func findOrCreateConversation(peerID: String, peerName: String) -> ChatConversation {
        if let existing = fetchStoreConversation(peerID: peerID) {
            syncConversationUI(existing)
            return uiConversation(from: existing)
        }
        let conversation = Conversation(id: "conv-\(peerID)", peerID: peerID, peerName: peerName)
        context.insert(conversation)
        save()
        syncConversationUI(conversation)
        return uiConversation(from: conversation)
    }

    // MARK: - Store ↔ UI 同步

    private func uiConversation(from c: Conversation) -> ChatConversation {
        ChatConversation(
            id: c.id,
            peerID: c.peerID,
            peerName: c.peerName,
            unreadCount: c.unreadCount,
            lastMessageText: c.lastMessageText,
            lastMessageAt: c.lastMessageAt
        )
    }

    private func uiMessage(from m: Message) -> ChatMessage {
        ChatMessage(
            id: m.id,
            senderID: m.senderID,
            kind: m.kind,
            text: m.text,
            state: m.state,
            sentAt: m.sentAt,
            imageData: m.imageData
        )
    }

    private func syncConversationUI(_ conversation: Conversation) {
        let snapshot = uiConversation(from: conversation)
        if let index = uiConversations.firstIndex(where: { $0.id == snapshot.id }) {
            uiConversations[index] = snapshot
        } else {
            uiConversations.append(snapshot)
        }
        uiConversations.sort { $0.lastMessageAt > $1.lastMessageAt }
    }

    private func pushMessageUI(_ message: Message) {
        var list = uiMessages[message.conversationID] ?? []
        list.append(uiMessage(from: message))
        uiMessages[message.conversationID] = list
    }

    private func updateMessageUI(_ message: Message) {
        var list = uiMessages[message.conversationID] ?? []
        if let index = list.firstIndex(where: { $0.id == message.id }) {
            list[index] = uiMessage(from: message)
            uiMessages[message.conversationID] = list
        }
    }

    private func loadUIFromStore() {
        do {
            let conversationDescriptor = FetchDescriptor<Conversation>(
                sortBy: [SortDescriptor(\.lastMessageAt, order: .reverse)]
            )
            uiConversations = try context.fetch(conversationDescriptor).map { uiConversation(from: $0) }
            let messageDescriptor = FetchDescriptor<Message>(sortBy: [SortDescriptor(\.sentAt)])
            var grouped: [String: [ChatMessage]] = [:]
            for stored in try context.fetch(messageDescriptor) {
                grouped[stored.conversationID, default: []].append(uiMessage(from: stored))
            }
            uiMessages = grouped
        } catch {
            uiConversations = []
            uiMessages = [:]
        }
    }

    // MARK: - Store 查询

    private func storeConversation(withID id: String) -> Conversation? {
        var descriptor = FetchDescriptor<Conversation>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchStoreConversation(peerID: String) -> Conversation? {
        var descriptor = FetchDescriptor<Conversation>(predicate: #Predicate { $0.peerID == peerID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func storeMessage(withID id: String) -> Message? {
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
