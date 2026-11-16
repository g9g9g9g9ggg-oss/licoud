import SwiftUI
import UIKit

/// 码池样式卡（机主参考图 4-7）：金边外框 + 徽章胶囊 + 米白码盒 + 底部文字
/// 尺寸自适应：列表缩略（72pt）/ 向导预览 / 全尺寸（下载出图用 ImageRenderer）
struct QRCardView: View {
    let style: QRCardStyle
    let url: String
    var badgeMode: QRBadgeMode = .show
    var bottomText: String = "扫码咨询"
    var logoMode: QRLogoMode = .none
    var watermark: Bool = false          // 「预览·未启用」斜带（向导第 3 步）

    var body: some View {
        ZStack {
            // 外底（渐变）
            LinearGradient(
                colors: [
                    Color(style.cardBackground.0),
                    Color(style.cardBackground.1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            // 金边
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(style.borderColor), lineWidth: 5)
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            innerContent
                .padding(14)
        }
        .overlay {
            if watermark { watermarkBand }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var innerContent: some View {
        VStack(spacing: 8) {
            if badgeMode == .show { badgePill }
            qrBox
            Text(bottomText.isEmpty ? "扫码咨询" : bottomText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(style.labelColor))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 10)
    }

    /// 徽章胶囊：🎧 在线客服 ●
    private var badgePill: some View {
        HStack(spacing: 5) {
            Image(systemName: "headphones")
                .font(.system(size: 11, weight: .semibold))
            Text("在线客服")
                .font(.system(size: 13, weight: .semibold))
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
        }
        .foregroundStyle(Color(red: 0.0, green: 0.72, blue: 0.42))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Capsule().stroke(Color(red: 0.0, green: 0.72, blue: 0.42), lineWidth: 1.5))
        .background(Capsule().fill(Color(white: 1, opacity: style.isDark ? 0.06 : 0.5)))
    }

    /// 米白码盒 + 样式着色二维码 + Logo
    private var qrBox: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(style.qrBoxColor))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let qr = QRCodeImage.tinted(
                    string: url,
                    background: style.qrBoxColor,
                    foreground: style.qrTint,
                    size: 400
                ) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                }
                if logoMode == .brand {
                    // 品牌 Logo：星标金圆（合成到码心）
                    ZStack {
                        Circle().fill(Color(style.borderColor)).frame(width: 34, height: 34)
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                }
            }
            .shadow(color: .black.opacity(style.isDark ? 0.4 : 0.12), radius: 6, y: 3)
    }

    /// 「预览·未启用」斜带（机主参考图 9）
    private var watermarkBand: some View {
        GeometryReader { geo in
            Text("预览 · 未启用")
                .font(.system(size: geo.size.width * 0.11, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .background(Rectangle().fill(Color.gray.opacity(0.55)))
                .rotationEffect(.degrees(-22))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }
}

/// 码池列表卡（机主参考图 10/11）：迷你样式码 + 名称 + 有效中条 + 倒计时 + 客户/创建 + 按钮行
struct PoolCodeCell: View {
    let code: PoolCode
    var onDownload: () -> Void = {}
    var onCopyLink: () -> Void = {}
    var onEdit: () -> Void = {}
    var onExtend: () -> Void = {}
    var onLock: () -> Void = {}

    private var isDarkStyle: Bool { code.style.isDark }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                QRCardView(
                    style: code.style,
                    url: code.url,
                    badgeMode: code.badgeMode,
                    bottomText: code.bottomText,
                    logoMode: code.logoMode
                )
                .frame(width: 76)

                VStack(alignment: .leading, spacing: 6) {
                    Text(code.remark)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    stateBar
                    Text(countdownText)
                        .font(.caption2)
                        .foregroundStyle(code.displayState == .active ? .white.opacity(0.85) : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(code.remark)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: "person.2")
                    .font(.caption2)
                Text("\(code.customers) 位客户")
                    .font(.caption2)
                Text("创建于 \(RelativeDateTimeFormatter.localized(created: code.createdAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                cellButton("下载") { onDownload() }
                cellButton("复制链接") { onCopyLink() }
                cellButton("编辑") { onEdit() }
                Menu {
                    Button { onExtend() } label: { Label("延长有效期 1 天", systemImage: "clock.arrow.circlepath") }
                    Button(role: .destructive) { onLock() } label: { Label("删除（进锁定期）", systemImage: "trash") }
                } label: {
                    cellButtonLabel("更多")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: UIColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 1)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    /// 状态条：● 有效中（绿）/ ● 锁定期（黄）/ ● 已失效（灰）
    private var stateBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(stateColor)
                .frame(width: 7, height: 7)
            Text(stateTitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(stateColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(stateColor.opacity(0.16))
        )
    }

    private var stateColor: Color {
        switch code.displayState {
        case .active: return .green
        case .locked: return .yellow
        case .expired: return .gray
        }
    }

    private var stateTitle: String {
        switch code.displayState {
        case .active: return "有效中"
        case .locked: return "锁定期"
        case .expired: return "已失效"
        }
    }

    private var countdownText: String {
        switch code.displayState {
        case .locked:
            let hours = Int((code.lockedUntil.map { $0.timeIntervalSinceNow } ?? 0) / 3600)
            return "锁定期剩余 \(hours) 小时"
        default:
            let interval = code.expiresAt.timeIntervalSinceNow
            guard interval > 0 else { return "已过期" }
            let totalHours = Int(interval / 3600)
            let days = totalHours / 24
            let hours = totalHours % 24
            let minutes = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
            return days > 0
                ? "有效期剩余 \(days)天\(hours)小时"
                : "有效期剩余 \(totalHours)时\(minutes)分"
        }
    }

    private func cellButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { cellButtonLabel(title) }
    }

    private func cellButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
    }
}

extension RelativeDateTimeFormatter {
    /// 「创建于 x分钟前」
    static func localized(created: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: created, relativeTo: Date())
    }
}
