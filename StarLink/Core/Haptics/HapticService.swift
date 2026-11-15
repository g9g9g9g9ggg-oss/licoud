import Foundation
import Observation

/// 触感唯一入口（设计书 3.4）：业务只调 fire(场景)，反馈由根视图统一挂载
/// 各期使用计划：第一期只搭架子不调用；二期 sendSuccess / messageReceived；四期 toggleChanged
@Observable
final class HapticService {
    enum Scenario: Equatable {
        case messageReceived   // 前台新消息  .impact(weight: .light)
        case sendSuccess       // 发送成功    .impact(weight: .medium)
        case toggleChanged     // 状态切换    .selection
        case warning           // 失败提示    .notification(.warning)
    }

    struct Event: Equatable {
        let scenario: Scenario
        let id: Int
    }

    /// 初值 id = 0 不会触发反馈；fire 自 1 起
    private(set) var event = Event(scenario: .warning, id: 0)
    private var nextID = 0

    func fire(_ scenario: Scenario) {
        nextID += 1
        event = Event(scenario: scenario, id: nextID)
    }
}
