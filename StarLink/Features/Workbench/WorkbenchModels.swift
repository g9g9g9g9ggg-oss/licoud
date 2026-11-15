import Foundation

// 工作台 Mock 数据模型（设计：《工作台Tab3-iOS界面设计.md》+《工作台V1.0-设计套件.md》三、交互细化）
// 演示期纯本地存储（UserDefaults JSON）；第二期接 workspace 接口族时仅替换 Store 实现

/// 意图匹配方式（keyword 先行；semantic/ai 灰显「即将上线」）
enum MatchMode: String, Codable, CaseIterable, Identifiable {
    case keyword
    case semantic
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyword: return "关键词"
        case .semantic: return "语义"
        case .ai: return "AI"
        }
    }
}

/// 文字回复（trigger_reply 按 (intent_id, reply_type) 各一行 → 本地合并进意图）
struct TextReply: Codable, Equatable {
    var isEnabled: Bool
    var content: String
}

/// 图片回复（最多 3 张，本地 mock 存图名）
struct ImageReply: Codable, Equatable {
    var isEnabled: Bool
    var imageNames: [String]

    static let maxImages = 3
}

/// 提示词触发意图：说法（本地攒着、一次保存）+ 文字/图片两个回复视角
struct WorkbenchIntent: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var matchMode: MatchMode
    var isEnabled: Bool
    var phrases: [String]
    var textReply: TextReply
    var imageReply: ImageReply
}

/// 快捷文字（点 = 填入防误触；长按 = 编辑/删除/排序）
struct QuickText: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var content: String
}

/// 客服码槽位内容：生产后可编辑备注 / 停用 / 删除
struct QRSlotContent: Codable, Equatable {
    var url: String
    var note: String
    var expiresAt: Date
    var isDisabled: Bool
    /// 绑定客服（在线/不在线身份各绑一名员工）
    var boundPeerName: String
}

/// 客服码区（框1 = 在线客服码，框2 = 不在线客服码）；内容可空 = 待生产
struct QRSlot: Codable, Identifiable, Equatable {
    let id: String          // "online" / "offline"
    var title: String       // 在线客服码 / 不在线客服码
    var content: QRSlotContent?
}

/// 本地图库条目（快捷图片与图片回复共用；mock 生成）
struct LibraryImage: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var imageData: Data
}
