import Foundation
import SwiftData

// 第二期预写（附录 B 已批准范围变更）：本地消息模型
// 说明：全部包在 #if DEBUG，Release 正式构建不含预写代码；第二期开工后去条件编译直接启用

enum MessageKind: String, Codable {
    case text
    case image  // TODO(第二期联调): 图片上传接入后启用
}

/// 发送状态机（设计书 6.1）：sending → sent → read；failed 可重发回到 sending
enum MessageState: String, Codable {
    case sending, sent, failed, read
}

@Model
final class Conversation {
    @Attribute(.unique) var id: String
    var peerID: String
    var peerName: String
    var unreadCount: Int
    var lastMessageText: String
    var lastMessageAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    init(
        id: String,
        peerID: String,
        peerName: String,
        unreadCount: Int = 0,
        lastMessageText: String = "",
        lastMessageAt: Date = Date()
    ) {
        self.id = id
        self.peerID = peerID
        self.peerName = peerName
        self.unreadCount = unreadCount
        self.lastMessageText = lastMessageText
        self.lastMessageAt = lastMessageAt
    }
}

@Model
final class Message {
    /// 客户端消息 ID（UUID），状态回执按此关联；服务端若无此字段走变更申请
    @Attribute(.unique) var id: String
    var conversationID: String
    var senderID: String
    var kindRaw: String
    var text: String
    var stateRaw: String
    var sentAt: Date
    /// 图片消息载荷（第二期预写，本地闭环；上传链路接通后为远端 URL 的本地缓存）
    @Attribute(.externalStorage) var imageData: Data?
    var conversation: Conversation?

    var kind: MessageKind {
        get { MessageKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    var state: MessageState {
        get { MessageState(rawValue: stateRaw) ?? .sent }
        set { stateRaw = newValue.rawValue }
    }

    init(
        id: String,
        conversationID: String,
        senderID: String,
        kind: MessageKind,
        text: String,
        state: MessageState,
        sentAt: Date,
        imageData: Data? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.kindRaw = kind.rawValue
        self.text = text
        self.stateRaw = state.rawValue
        self.sentAt = sentAt
        self.imageData = imageData
    }
}

/// 会话时间展示（任务书 0.3 质感：今天 HH:mm / 昨天 / 更早 M/d）
enum ChatTimeFormatter {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    static func string(for date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            return timeFormatter.string(from: date)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "昨天"
        }
        return dateFormatter.string(from: date)
    }
}
