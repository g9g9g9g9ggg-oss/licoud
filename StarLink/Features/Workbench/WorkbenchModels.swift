import Foundation
import UIKit

// 码池（原工作台，机主 2026-11-16 指示更名重构）：Mock 数据模型
// 参考：机主提供的 STARLINK MATRIX 码池界面（统计卡/新建二维码三步/四款样式卡）
// 演示期纯本地持久化；「以后对接码池（后端分发链接）」时仅替换 Store 实现

import Foundation

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

/// 文字回复
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

/// 提示词触发意图
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

/// 码池二维码卡片样式（四款，对应机主参考图 4-7）
enum QRCardStyle: String, Codable, CaseIterable, Identifiable {
    case mojinCatEye      // 墨金·猫眼
    case baiyuJinsha      // 白玉金沙·默认
    case molvJinyu        // 墨绿·金舆
    case zanglanJinyu     // 藏蓝·金舆

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mojinCatEye: return "墨金·猫眼"
        case .baiyuJinsha: return "白玉金沙"
        case .molvJinyu: return "墨绿·金舆"
        case .zanglanJinyu: return "藏蓝·金舆"
        }
    }

    var subtitle: String {
        switch self {
        case .mojinCatEye: return "深邃底 · 金舆绿码 · 暗码"
        case .baiyuJinsha: return "米白底 · 黑码 · 默认"
        case .molvJinyu: return "深绿底 · 金舆绿码"
        case .zanglanJinyu: return "米白底 · 黑码 · 金舆蓝"
        }
    }

    /// 卡片外底色（渐变两端）
    var cardBackground: (UIColor, UIColor) {
        switch self {
        case .mojinCatEye: return (UIColor(red: 0.10, green: 0.09, blue: 0.03, alpha: 1), UIColor(red: 0.04, green: 0.03, blue: 0.01, alpha: 1))
        case .baiyuJinsha: return (UIColor(red: 0.99, green: 0.97, blue: 0.91, alpha: 1), UIColor(red: 0.96, green: 0.92, blue: 0.82, alpha: 1))
        case .molvJinyu: return (UIColor(red: 0.05, green: 0.18, blue: 0.11, alpha: 1), UIColor(red: 0.03, green: 0.10, blue: 0.06, alpha: 1))
        case .zanglanJinyu: return (UIColor(red: 0.99, green: 0.97, blue: 0.91, alpha: 1), UIColor(red: 0.95, green: 0.91, blue: 0.80, alpha: 1))
        }
    }

    /// 金边
    var borderColor: UIColor {
        UIColor(red: 0.83, green: 0.68, blue: 0.22, alpha: 1)  // 金 #D4AD38
    }

    /// 码盒底色（米白）
    var qrBoxColor: UIColor {
        switch self {
        case .mojinCatEye: return UIColor(red: 0.94, green: 0.90, blue: 0.78, alpha: 1)
        default: return UIColor.white
        }
    }

    /// 码点颜色（暗色款用色码）
    var qrTint: UIColor {
        switch self {
        case .mojinCatEye: return UIColor(red: 0.29, green: 0.25, blue: 0.06, alpha: 1)   // 暗金褐
        case .baiyuJinsha: return UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)   // 黑
        case .molvJinyu: return UIColor(red: 0.10, green: 0.29, blue: 0.18, alpha: 1)     // 墨绿
        case .zanglanJinyu: return UIColor(red: 0.10, green: 0.16, blue: 0.35, alpha: 1)  // 藏蓝
        }
    }

    /// 底部文字颜色
    var labelColor: UIColor {
        switch self {
        case .mojinCatEye: return UIColor(red: 0.94, green: 0.90, blue: 0.78, alpha: 1)
        case .baiyuJinsha: return UIColor(red: 0.63, green: 0.47, blue: 0.16, alpha: 1)
        case .molvJinyu: return UIColor(red: 0.83, green: 0.68, blue: 0.22, alpha: 1)
        case .zanglanJinyu: return UIColor(red: 0.63, green: 0.47, blue: 0.16, alpha: 1)
        }
    }

    /// 页内缩略预览时的主背景（SwiftUI 侧渐变用）
    var isDark: Bool {
        switch self {
        case .mojinCatEye, .molvJinyu: return true
        default: return false
        }
    }
}

/// 徽章来源（图8 第 3 步）
enum QRBadgeMode: String, Codable, CaseIterable, Identifiable {
    case show      // 默认显示
    case hidden    // 不显示

    var id: String { rawValue }
    var title: String {
        switch self {
        case .show: return "默认显示"
        case .hidden: return "不显示"
        }
    }
}

/// Logo 来源（图8 第 3 步）
enum QRLogoMode: String, Codable, CaseIterable, Identifiable {
    case none       // 不使用
    case brand      // 品牌Logo（星标）
    case upload     // 上传Logo（第二期接图库）

    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "不使用"
        case .brand: return "品牌Logo"
        case .upload: return "上传Logo"
        }
    }
}

/// 码池二维码状态
enum PoolCodeState: String, Codable {
    case active      // 有效中
    case locked      // 锁定期（删除后 7 天）
    case expired     // 已过期
}

/// 码池二维码（一张获客码）
struct PoolCode: Codable, Identifiable, Equatable {
    let id: String
    var remark: String                 // 备注 = 码名（分发识别用，如「阿萨」「地方g」）
    var url: String                    // 码池分发链接（mock；对接后由码池后端下发）
    var style: QRCardStyle
    var badgeMode: QRBadgeMode
    var bottomText: String             // 底部文字（≤24 字，空 = 扫码咨询）
    var logoMode: QRLogoMode
    var customers: Int                 // 扫码客户数（mock 0 起）
    var createdAt: Date
    var expiresAt: Date
    var state: PoolCodeState
    var lockedUntil: Date?             // 删除 → 锁定期 7 天

    /// 展示用底部文字
    var displayBottomText: String {
        bottomText.isEmpty ? "扫码咨询" : bottomText
    }

    /// 展示状态（有效期过 → 已失效）
    var displayState: PoolCodeState {
        if state == .active && expiresAt < Date() { return .expired }
        return state
    }
}

/// 快捷图片（图库条目）
struct LibraryImage: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var imageData: Data
}
