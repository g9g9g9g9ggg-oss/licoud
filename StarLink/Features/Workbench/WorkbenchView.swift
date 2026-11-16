import SwiftUI
import UIKit

/// Tab 3 码池（机主 2026-11-16 指示：码池里就是码池，其余内容撤到聊天 ➕ 面板）
/// 版型：说明行 + 新建按钮 → 统计 4 chip → 码卡双列网格（空态）→ 「更多」菜单（参考图 1）
struct WorkbenchView: View {
    @Environment(HapticService.self) private var haptics
    private var store: WorkbenchStore { WorkbenchStore.shared }

    @State private var showsProdigFlow = false
    @State private var editingCode: PoolCode?
    @State private var sourceDataCode: PoolCode?
    @State private var confirmAction: ConfirmAction?

    struct ConfirmAction: Identifiable {
        let id = UUID()
        var title: String
        var message: String
        var isDestructive: Bool
        var run: () -> Void
    }

    // 暗色码池配色
    private let pageBackground = Color(red: 0.05, green: 0.07, blue: 0.09)
    private let accent = Color(red: 0.0, green: 0.78, blue: 0.36)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                headerDescription
                statChips
                codesGrid
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(pageBackground.ignoresSafeArea())
        .navigationTitle("码池")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(isPresented: $showsProdigFlow) {
            ProdigCodeFlowView()
        }
        .sheet(item: $editingCode) { code in
            CodeRemarkEditView(code: code)
        }
        .sheet(item: Binding(
            get: { sourceDataCode },
            set: { sourceDataCode = $0 }
        )) { code in
            SourceDataView(code: code)
        }
        .alert(
            confirmAction?.title ?? "",
            isPresented: Binding(
                get: { confirmAction != nil },
                set: { if !$0 { confirmAction = nil } }
            )
        ) {
            Button(confirmAction?.isDestructive == true ? "确认" : "好", role: confirmAction?.isDestructive == true ? .destructive : nil) {
                confirmAction?.run()
                confirmAction = nil
            }
            Button("取消", role: .cancel) { confirmAction = nil }
        } message: {
            Text(confirmAction?.message ?? "")
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 说明行 + 新建按钮

    private var headerDescription: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("生成与维护客户入口二维码")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("累计客户 \(store.totalCustomers) · 有效期内可扫码进入；客户扫码后自动进入消息。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showsProdigFlow = true
            } label: {
                Text("新建二维码")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(accent))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 统计 4 chip

    private var statChips: some View {
        HStack(spacing: 10) {
            statChip(value: store.activeCodes.count, label: "有效中", color: .green)
            statChip(value: store.lockedCodes.count, label: "锁定期", color: .yellow)
            statChip(value: store.expiredCodes.count, label: "已失效", color: .gray)
            statChip(value: store.poolRemaining, label: "码池余量", color: .white)
        }
    }

    private func statChip(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - 码卡网格 / 空态

    private var codesGrid: some View {
        Group {
            if store.codes.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(store.codes) { code in
                        PoolCodeCell(
                            code: code,
                            onDownload: { downloadCode(code) },
                            onCopyLink: {
                                UIPasteboard.general.string = code.url
                                haptics.fire(.sendSuccess)
                            },
                            onEdit: { editingCode = code },
                            onExtend: {
                                store.extendCode(id: code.id)
                                haptics.fire(.toggleChanged)
                            },
                            onLock: {
                                store.lockCode(id: code.id)
                                haptics.fire(.warning)
                            }
                        )
                        .contextMenu { moreMenu(for: code) }
                    }
                }
            }
        }
    }

    /// 「更多」菜单（机主参考图 1）：下载/复制链接/编辑/查看源数据/更换新码/停用·启用/删除
    @ViewBuilder
    private func moreMenu(for code: PoolCode) -> some View {
        Button { downloadCode(code) } label: { Label("下载二维码图片", systemImage: "arrow.down.circle") }
        Button {
            UIPasteboard.general.string = code.url
            haptics.fire(.sendSuccess)
        } label: { Label("复制入口链接", systemImage: "doc.on.doc") }
        Button { editingCode = code } label: { Label("编辑信息", systemImage: "pencil") }
        Button { sourceDataCode = code } label: { Label("查看源数据", systemImage: "info.circle") }
        Button {
            if let customer = store.simulateScan(code: code) {
                haptics.fire(.messageReceived)
                TabRouter.shared.selection = 0
                _ = customer
            }
        } label: { Label("模拟客户扫码（演示）", systemImage: "person.badge.plus") }
        Button { confirmRegenerate(code) } label: { Label("更换新码", systemImage: "arrow.triangle.2.circlepath") }
        Button { confirmToggleDisable(code) } label: {
            Label(
                code.isDisabled ? "启用入口" : "停用入口",
                systemImage: code.isDisabled ? "play.circle" : "pause.circle"
            )
        }
        Divider()
        Button(role: .destructive) { confirmLock(code) } label: { Label("删除二维码（进锁定期）", systemImage: "trash") }
    }

    private func confirmRegenerate(_ code: PoolCode) {
        confirmAction = ConfirmAction(
            title: "更换新码",
            message: "将生成新的入口链接，旧链接立即失效（已扫码客户不受影响）。确定更换？",
            isDestructive: false
        ) {
            store.regenerateCode(id: code.id)
            haptics.fire(.sendSuccess)
        }
    }

    private func confirmToggleDisable(_ code: PoolCode) {
        let disabling = !code.isDisabled
        confirmAction = ConfirmAction(
            title: disabling ? "停用入口" : "启用入口",
            message: disabling ? "停用后扫码将提示客服不在线，可随时启用。" : "启用后扫码将重新接入客服。",
            isDestructive: false
        ) {
            store.setCodeDisabled(id: code.id, disabled: disabling)
            haptics.fire(.toggleChanged)
        }
    }

    private func confirmLock(_ code: PoolCode) {
        confirmAction = ConfirmAction(
            title: "删除二维码",
            message: "删除后进入 7 天锁定期，期间不可恢复；确定删除？",
            isDestructive: true
        ) {
            store.lockCode(id: code.id)
            haptics.fire(.warning)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "diamond")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("还没有二维码")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            Text("创建第一张获客码，让客户扫码迈出入你的接待台")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showsProdigFlow = true
            } label: {
                Text("新建二维码")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(accent))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - 下载（ImageRenderer 渲染样式卡出图）

    private func downloadCode(_ code: PoolCode) {
        let card = QRCardView(
            style: code.style,
            url: code.url,
            badgeMode: code.badgeMode,
            bottomText: code.bottomText,
            logoMode: code.logoMode
        )
        .frame(width: 600)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        haptics.fire(.sendSuccess)
    }
}

/// 查看源数据（机主参考「更多」菜单项）：入口链接 / 状态 / 客户数 / 时间，只读
struct SourceDataView: View {
    let code: PoolCode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("入口") {
                    LabeledContent("链接", value: code.url)
                        .font(.caption)
                    LabeledContent("备注", value: code.remark)
                    LabeledContent("样式", value: code.style.title)
                }
                Section("状态") {
                    LabeledContent("状态", value: stateTitle)
                    LabeledContent("有效期至", value: DateFormatter.localizedString(from: code.expiresAt, dateStyle: .short, timeStyle: .short))
                    if let locked = code.lockedUntil {
                        LabeledContent("锁定期至", value: DateFormatter.localizedString(from: locked, dateStyle: .short, timeStyle: .short))
                    }
                    LabeledContent("客户数", value: "\(code.customers)")
                    LabeledContent("创建于", value: DateFormatter.localizedString(from: code.createdAt, dateStyle: .short, timeStyle: .short))
                }
            }
            .navigationTitle("源数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var stateTitle: String {
        switch code.displayState {
        case .active: return "有效中"
        case .locked: return "锁定期"
        case .expired: return "已失效"
        }
    }
}

/// 码名编辑 sheet（「编辑信息」）
struct CodeRemarkEditView: View {
    let code: PoolCode
    @Environment(HapticService.self) private var haptics
    private var store: WorkbenchStore { WorkbenchStore.shared }
    @Environment(\.dismiss) private var dismiss

    @State private var remark = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("码名（备注）") {
                    TextField("例如：阿萨", text: $remark)
                }
            }
            .navigationTitle("编辑信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        store.updateCodeRemark(id: code.id, remark: remark)
                        haptics.fire(.sendSuccess)
                        dismiss()
                    }
                    .disabled(remark.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { remark = code.remark }
        }
        .preferredColorScheme(.dark)
    }
}
