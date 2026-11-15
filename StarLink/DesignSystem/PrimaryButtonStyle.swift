import SwiftUI

/// 主按钮样式（设计书 4.2）：高 50、圆角 12、品牌色、按下变暗、禁用置灰
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cornerRadiusButton, style: .continuous)
                    .fill(isEnabled ? Color.starlinkAccent : Color.secondary)
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
            )
    }
}
