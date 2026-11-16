import SwiftUI
import UIKit

/// Tab 3 码池（机主 2026-11-16 指示：原工作台更名重构，版型借鉴 STARLINK MATRIX 码池）
/// 结构：说明行 + 新建按钮 → 统计 4 chip → 码卡双列网格（空态）→ 快捷素材与触发
/// 演示期 Mock 本地持久化；「以后对接码池后端」仅换 WorkbenchStore 实现
struct WorkbenchView: View {
    @Environment(HapticService.self) private var haptics
    private var store: WorkbenchStore { WorkbenchStore.shared }

    @State private var showsProdigFlow = false
    @State private var showsQuickTextEditor = false
    @State private var showsImageLibPicker = false
    @State private var editingCode: PoolCode?
    @State private var showSendHint = false

    // 暗色码池配色（机主参考图 1/10）
    private let pageBackground = Color(red: 0.05, green: 0.07, blue: 0.09)
    private let accent = Color(red: 0.0, green: 0.78, blue: 0.36)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                headerDescription
                statChips
                codesGrid
                Divider().overlay(Color.white.opacity(0.1))
                quickTextSection
                quickImageSection
                intentSection
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
        .navigationDestination(isPresented: $showsQuickTextEditor) {
            QuickTextEditorView()
        }
        .navigationDestination(isPresented: $showsImageLibPicker) {
            ImageLibPickerView()
        }
        .sheet(item: $editingCode) { code in
            CodeRemarkEditView(code: code)
        }
        .alert("先打开一个会话", isPresented: $showSendHint) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("快捷发送会进入「消息」Tab 最近会话；请先打开任一会话。")
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 说明行 + 新建按钮（参考图 10 头部）

    private var headerDescription: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("生成与维护客户入口二维码")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("有效期内可扫码进入；过期前 1 小时可延长；客户数量实事求是。")
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

    // MARK: - 统计 4 chip（有效中 / 锁定期 / 已失效 / 码池余量）

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

    // MARK: - 码卡网格 / 空态（参考图 1 空态 + 图 10 网格）

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
                    }
                }
            }
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

    // MARK: - 快捷素材（保留既有能力，下沉到码池页下半部）

    private var quickTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("快捷文字").font(.subheadline.weight(.medium)).foregroundStyle(.white)
                Text("点 = 填入防误触").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Button {
                    store.editingQuickTextID = nil
                    showsQuickTextEditor = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(accent)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("新增快捷文字")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(store.quickTexts) { text in
                        Button {
                            if store.fillQuickText(text) {
                                haptics.fire(.toggleChanged)
                            } else {
                                showSendHint = true
                            }
                        } label: {
                            Text(text.title)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                store.editingQuickTextID = text.id
                                showsQuickTextEditor = true
                            } label: { Label("编辑", systemImage: "pencil") }
                            Button(role: .destructive) {
                                store.deleteQuickText(id: text.id)
                            } label: { Label("删除", systemImage: "trash") }
                            Button { store.moveQuickText(id: text.id, offset: -1) } label: { Label("上移", systemImage: "arrow.up") }
                            Button { store.moveQuickText(id: text.id, offset: 1) } label: { Label("下移", systemImage: "arrow.down") }
                        }
                    }
                }
            }
        }
    }

    private var quickImageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("快捷图片").font(.subheadline.weight(.medium)).foregroundStyle(.white)
                Text("点 = 直接发送").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Button {
                    showsImageLibPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(accent)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("从图库添加快捷图片")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(store.quickImages) { image in
                        Button {
                            if store.sendQuickImage(image) {
                                haptics.fire(.sendSuccess)
                            } else {
                                showSendHint = true
                            }
                        } label: {
                            if let uiImage = UIImage(data: image.imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.removeQuickImage(id: image.id)
                            } label: { Label("从快捷栏移除", systemImage: "trash") }
                        }
                    }
                }
            }
        }
    }

    private var intentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提示词触发").font(.subheadline.weight(.medium)).foregroundStyle(.white)
            HStack(spacing: 12) {
                intentEntryCard(.text, title: "提示词触发 · 文字", icon: "text.bubble")
                intentEntryCard(.image, title: "提示词触发 · 图片", icon: "photo.stack")
            }
        }
    }

    private func intentEntryCard(_ focus: IntentFocus, title: String, icon: String) -> some View {
        NavigationLink(value: WorkbenchRoute.intentList(focus)) {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(enabledCount(for: focus) == 0 ? "未启用意图" : "启用中 \(enabledCount(for: focus)) 个")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func enabledCount(for focus: IntentFocus) -> Int {
        store.intents.filter { intent in
            guard intent.isEnabled else { return false }
            switch focus {
            case .text: return intent.textReply.isEnabled
            case .image: return intent.imageReply.isEnabled
            }
        }.count
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

/// 码名编辑 sheet（列表「编辑」）
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
            .navigationTitle("编辑")
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
