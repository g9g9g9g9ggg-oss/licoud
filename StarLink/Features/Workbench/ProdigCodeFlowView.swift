import SwiftUI
import UIKit

/// 生产二维码三步向导（机主参考图 2/3/8/9）：
/// ① 备注信息 → ② 样式外观（四款 2×2 实时预览）→ ③ 领取确认（徽章/底字/Logo）→ 从码池领取
struct ProdigCodeFlowView: View {
    @Environment(HapticService.self) private var haptics
    private var store: WorkbenchStore { WorkbenchStore.shared }
    @Environment(\.dismiss) private var dismiss

    @State private var step = 1
    @State private var remark = ""
    @State private var style: QRCardStyle = .baiyuJinsha   // 白玉金沙·默认
    @State private var badgeMode: QRBadgeMode = .show
    @State private var bottomText = ""
    @State private var logoMode: QRLogoMode = .brand

    /// 领取用的 mock 分发链接（三步期间固定，预览与领取一致）
    private var previewURL: String {
        "https://pool.starlink.demo/c/preview"
    }

    private var accent: Color { Color(red: 0.0, green: 0.78, blue: 0.36) }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.09).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                header
                stepper
                Group {
                    switch step {
                    case 1: remarkStep
                    case 2: styleStep
                    default: confirmStep
                    }
                }
                Spacer()
                footerButtons
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 头部

    private var header: some View {
        HStack {
            Text("新建二维码")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 步进条：完成=绿勾，当前=高亮胶囊，未到=灰圈
    private var stepper: some View {
        HStack(spacing: 10) {
            ForEach(1...3, id: \.self) { index in
                if index < step {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accent)
                } else if index == step {
                    Text(stepTitle(index))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(index == 3 ? Color.yellow : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.yellow.opacity(index == 3 ? 0.15 : 0)))
                        .overlay(Capsule().stroke(index == 1 || index == 2 ? Color.yellow.opacity(0.8) : .clear, lineWidth: 1))
                } else {
                    Text("\(index)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
            }
            Spacer()
        }
    }

    private func stepTitle(_ index: Int) -> String {
        switch index {
        case 1: return "备注信息"
        case 2: return "样式外观"
        default: return "领取确认"
        }
    }

    // MARK: - 第 1 步：备注信息

    private var remarkStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("任意备注", text: $remark)
                .font(.body)
                .foregroundStyle(.white)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.red.opacity(0.85), lineWidth: 2)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
                )
            Text("任意备注，通过此二维码进入自动备注")
                .font(.caption)
                .foregroundStyle(.red.opacity(0.9))
        }
    }

    // MARK: - 第 2 步：样式外观（四款 2×2）

    private var styleStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("二维码样式")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                ForEach(QRCardStyle.allCases) { candidate in
                    Button {
                        style = candidate
                        haptics.fire(.toggleChanged)
                    } label: {
                        VStack(spacing: 6) {
                            QRCardView(
                                style: candidate,
                                url: previewURL,
                                badgeMode: badgeMode,
                                bottomText: bottomText,
                                logoMode: logoMode
                            )
                            .frame(width: 128)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(
                                        style == candidate ? accent : Color.white.opacity(0.25),
                                        lineWidth: style == candidate ? 2.5 : 1
                                    )
                            )
                            Text(candidate.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(candidate.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 第 3 步：领取确认

    private var confirmStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                QRCardView(
                    style: style,
                    url: previewURL,
                    badgeMode: badgeMode,
                    bottomText: bottomText,
                    logoMode: logoMode,
                    watermark: true
                )
                .frame(width: 260)
                .frame(maxWidth: .infinity)

                badgePicker
                bottomTextEditor
                logoPicker
            }
        }
    }

    private var badgePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("徽章").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(QRBadgeMode.allCases) { mode in
                    optionPill(mode.title, selected: badgeMode == mode) {
                        badgeMode = mode
                        haptics.fire(.toggleChanged)
                    }
                }
            }
            Text("亮徽章在以下样式，显示在二维码上方")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var bottomTextEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("底部文字").font(.caption).foregroundStyle(.secondary)
            TextField("扫码咨询", text: $bottomText)
                .font(.body)
                .foregroundStyle(.white)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                )
            Text("显示在二维码下方，最长 24 字；留空使用「扫码咨询」")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var logoPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Logo 来源").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(QRLogoMode.allCases) { mode in
                    optionPill(mode.title, selected: logoMode == mode) {
                        logoMode = mode
                        haptics.fire(.toggleChanged)
                    }
                }
            }
            Text("仅 PNG 图会合成到二维码中心，其他格式仅作保存展示；合成时已自动提高容错等级，正常尺寸下不影响识别。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func optionPill(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(selected ? accent : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selected ? accent.opacity(0.18) : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(selected ? accent : Color.white.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 底部按钮

    private var footerButtons: some View {
        HStack(spacing: 10) {
            if step == 1 {
                wizardButton("取消", role: .secondary) { dismiss() }
            } else {
                wizardButton("取消", role: .secondary) { dismiss() }
                wizardButton("上一步", role: .secondary) { step -= 1 }
            }
            nextButton
        }
    }

    @ViewBuilder
    private var nextButton: some View {
        switch step {
        case 1:
            wizardButton("下一步", role: .primary, enabled: !remark.trimmingCharacters(in: .whitespaces).isEmpty) { step = 2 }
        case 2:
            wizardButton("下一步", role: .primary) { step = 3 }
        default:
            wizardButton("从码池领取", role: .primary) { claim() }
        }
    }

    private func wizardButton(_ title: String, role: SecondaryRole, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(role == .primary ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(role == .primary ? (enabled ? accent : Color.gray.opacity(0.4)) : Color.white.opacity(0.08))
                )
        }
        .disabled(!enabled)
    }

    enum SecondaryRole { case primary, secondary }

    private func claim() {
        guard let code = store.claimCode(
            remark: remark,
            style: style,
            badgeMode: badgeMode,
            bottomText: bottomText,
            logoMode: logoMode
        ) else { return }
        haptics.fire(.sendSuccess)
        dismiss()
        _ = code
    }
}
