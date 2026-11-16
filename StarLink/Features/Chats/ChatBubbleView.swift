import SwiftUI
import UIKit

/// 气泡（设计书 6.1）：圆角 18、留白走档位、无渐变
/// 尾巴以差异化圆角近似系统 Messages 比例，第二期验收时对照录屏微调
/// 数据源：引擎快照 ChatMessage（纯值类型）
struct ChatBubbleView: View {
    let message: ChatMessage
    let isOutgoing: Bool
    var onRetry: () -> Void = {}
    var onOpenImage: () -> Void = {}
    var onDelete: () -> Void = {}
    var onQuote: () -> Void = {}
    var onRecall: () -> Void = {}
    var onSaveImage: () -> Void = {}

    var body: some View {
        Group {
            if message.state == .recalled {
                // 撤回：灰色系统条（微信式）
                Text(isOutgoing ? "你撤回了一条消息" : "对方撤回了一条消息")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            } else {
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
                .contextMenu { contextMenuItems }
            }
        }
    }

    /// 长按操作（机主参考圈图）：文字=引用/复制/撤回/删除；图片=引用/保存/撤回/删除
    @ViewBuilder
    private var contextMenuItems: some View {
        Button { onQuote() } label: { Label("引用", systemImage: "quote.opening") }
        if message.kind == .text {
            Button { UIPasteboard.general.string = message.text } label: { Label("复制", systemImage: "doc.on.doc") }
        }
        if message.kind == .image, message.imageData != nil {
            Button { onSaveImage() } label: { Label("保存", systemImage: "square.and.arrow.down") }
        }
        if isOutgoing, message.state == .sent || message.state == .read {
            Button { onRecall() } label: { Label("撤回", systemImage: "arrow.uturn.backward") }
        }
        Divider()
        Button(role: .destructive) { onDelete() } label: { Label("删除", systemImage: "trash") }
    }

    @ViewBuilder
    private var bubble: some View {
        switch message.kind {
        case .text:
            VStack(alignment: .leading, spacing: 6) {
                if message.quotedText != nil || message.quotedImageData != nil {
                    quoteBlock
                }
                Text(message.text)
            }
            .padding(.horizontal, Metrics.spacing12)
            .padding(.vertical, Metrics.spacing8)
            .background { bubbleShape.fill(bubbleFill) }
            .foregroundStyle(isOutgoing ? Color.white : Color.primary)
        case .image:
            imageContent
        }
    }

    /// 引用块（机主参考：发送带引用的消息，气泡内先展示被引用内容）
    @ViewBuilder
    private var quoteBlock: some View {
        if message.quotedText != nil || message.quotedImageData != nil {
            HStack(alignment: .top, spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isOutgoing ? Color.white.opacity(0.6) : Color.starlinkAccent.opacity(0.6))
                    .frame(width: 3)
                Group {
                    if let data = message.quotedImageData, let img = UIImage(data: data) {
                        HStack(spacing: 6) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Text("[图片]")
                        }
                    } else {
                        Text(message.quoteSummary)
                    }
                }
                .font(.caption)
                .foregroundStyle(isOutgoing ? Color.white.opacity(0.85) : .secondary)
                .lineLimit(2)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isOutgoing ? Color.black.opacity(0.15) : Color.black.opacity(0.05))
            )
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
        case .recalled:
            EmptyView()
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
