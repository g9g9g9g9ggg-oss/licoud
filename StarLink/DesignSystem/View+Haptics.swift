import SwiftUI

/// 触感挂载扩展（设计书 3.4）：仅 RootView 调一次 .haptics(...)
/// 业务代码不得直接使用 sensoryFeedback
extension View {
    func haptics(_ service: HapticService) -> some View {
        sensoryFeedback(trigger: service.event) { _, new in
            switch new.scenario {
            case .messageReceived: .impact(weight: .light)
            case .sendSuccess:     .impact(weight: .medium)
            case .toggleChanged:   .selection
            case .warning:         SensoryFeedback.warning
            }
        }
    }
}
