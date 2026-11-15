import SwiftUI
import UIKit

/// 气泡（设计书 6.1）：圆角 18、留白走档位、无渐变
/// 尾巴以差异化圆角近似系统 Messages 比例，第二期验收时对照录屏微调
struct ChatBubbleView: View {
    let message: Message
    let isOutgoing: Bool
    var onRetry: () -> Void = {}
    var onOpenImage: () -> Void = {}

    var body: some View {
        HStack(alignment: .bottom, spacing: Metrics.spacing4) {
            if isOutgoing {
                Spacer(minLength: 64)
                stateIcon
                bubble
            } else {
                bubble
                Spacer(minLength: 64)
            }
        }
    }

    @ViewBuilder
    private var bubble: some View {
        switch message.kind {
        case .text:
            Text(message.text)
                .padding(.horizontal, Metrics.spacing12)
                .padding(.vertical, Metrics.spacing8)
                .background { bubbleShape.fill(bubbleFill) }
                .foregroundStyle(isOutgoing ? Color.white : Color.primary)
        case .image:
            imageContent
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let data = message.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220, maxHeight: 280)
                .clipShape(bubbleShape)
                .onTapGesture { onOpenImage() }
                .accessibilityLabel("图片")
        } else {
            // 图片上传未接通前的占位（第二期联调时替换）
            Text("图片（第二期联调接入）")
                .font(.subheadline)
                .italic()
                .foregroundStyle(isOutgoing ? Color.white.opacity(0.8) : Color.secondary)
        }
    }

    private var bubbleShape: RoundedCorner {
        RoundedCorner(
            radius: Metrics.cornerRadiusBubble,
            // 出去的一侧底角留直角近似尾巴：outgoing 右下 / incoming 左下
            corners: isOutgoing ? [.topLeft, .topRight, .bottomLeft]
                                : [.topLeft, .topRight, .bottomRight]
        )
    }

    private var bubbleFill: AnyShapeStyle {
        isOutgoing
            ? AnyShapeStyle(Color.starlinkAccent)
            : AnyShapeStyle(Color(uiColor: .secondarySystemBackground))
    }

    /// 发送状态小图标：不抢视线（任务书第二期）
    @ViewBuilder
    private var stateIcon: some View {
        switch message.state {
        case .sending:
            ProgressView()
                .controlSize(.mini)
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        case .read:
            Image(systemName: "checkmark.circle")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        case .failed:
            Button(action: onRetry) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重发")
        }
    }
}

/// 指定角圆角（iOS 17 目标下的尾巴近似方案）
struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath)
    }
}
