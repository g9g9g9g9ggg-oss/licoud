import Foundation
import Observation

/// 跨 Tab 通信（打磨包）：Tab 选择 + 快捷文字/图片的去向
/// 工作台「点 = 填入防误触 / 直接发送」跳回消息 Tab 经此中转
@Observable
final class TabRouter {
    static let shared = TabRouter()
    private init() {}

    var selection: Int = 0
}

/// 会话草稿箱：快捷文字「点 = 填入」投递到这里，ChatView 出现/变更时消费
@Observable
final class ChatDraftBox {
    static let shared = ChatDraftBox()
    private init() {}

    var pendingText: String?

    /// 取走待填文字（一次性）
    func consumeText() -> String? {
        guard let text = pendingText else { return nil }
        pendingText = nil
        return text
    }
}
