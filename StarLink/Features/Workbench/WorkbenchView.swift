import SwiftUI
import UIKit

/// Tab 3 工作台（设计：《工作台Tab3-iOS界面设计.md》）
/// 演示期：Mock 数据走 WorkbenchStore（本地持久化）；第二期接 workspace 接口族
struct WorkbenchView: View {
    @Environment(HapticService.self) private var haptics
    private var store: WorkbenchStore { WorkbenchStore.shared }

    @State private var showsWelcomeEdit = false
    @State private var showsQuickTextEditor = false
    @State private var showsImageLibPicker = false
    @State private var showsBindPicker = false
    @State private var showsProduceChooser = false
    @State private var showNoteEditSlotID: String?
    @State private var confirmAction: ConfirmAction?

    struct ConfirmAction: Identifiable {
        let id = UUID()
        var title: String
        var message: String
        var isDestructive: Bool
        var run: () -> Void
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacing16) {
                welcomeCard
                qrSection
                quickTextSection
                quickImageSection
                intentSection
            }
            .padding(.horizontal, Metrics.spacing16)
            .padding(.vertical, Metrics.spacing16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("工作台")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $showsWelcomeEdit) {
            WelcomeEditView()
        }
        .navigationDestination(isPresented: $showsQuickTextEditor) {
            QuickTextEditorView()
        }
        .navigationDestination(isPresented: $showsImageLibPicker) {
            ImageLibPickerView()
        }
        .navigationDestination(isPresented: $showsBindPicker) {
            BindCustomerServiceView()
        }
        .navigationDestination(item: $showNoteEditSlotID) { slotID in
            QRNoteEditView(slotID: slotID)
        }
        .navigationDestination(for: WorkbenchRoute.self) { route in
            switch route {
            case .intentList(let focus):
                IntentListView(focus: focus)
            }
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
    }

    // MARK: - ① 欢迎语卡片

    private var welcomeCard: some View {
        Button {
            showsWelcomeEdit = true
        } label: {
            HStack(spacing: Metrics.spacing12) {
                Label("欢迎语", systemImage: "text.bubble")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text(store.welcomeText.isEmpty ? "未设置" : store.welcomeText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Toggle("", isOn: Binding(
                    get: { store.welcomeEnabled },
                    set: { newValue in
                        store.updateWelcome(text: store.welcomeText, enabled: newValue)
                        haptics.fire(.toggleChanged)
                    }
                ))
                .labelsHidden()
                .fixedSize()
            }
            .padding(Metrics.spacing12)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cornerRadiusCard, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - ② 客服码区

    private var qrSection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing8) {
            HStack {
                Text("客服码").font(.subheadline.weight(.medium))
                Spacer()
                Button {
                    showsProduceChooser = true
                } label: {
                    Label("生产", systemImage: "plus.circle")
                        .font(.footnote)
                }
                .buttonStyle(.borderless)
            }
            HStack(alignment: .top, spacing: Metrics.spacing16) {
                ForEach(store.qrSlots) { slot in
                    QRSlotCard(slot: slot) { action in
                        handleSlotAction(action, slotID: slot.id)
                    }
                }
            }
        }
        .alert("生产新码", isPresented: $showsProduceChooser) {
            ForEach(store.qrSlots) { slot in
                Button(slot.title) {
                    store.produceCode(slotID: slot.id)
                    showNoteEditSlotID = slot.id
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("为哪一个客服码重新出码？出码后可编辑备注。")
        }
    }

    private func handleSlotAction(_ action: QRSlotCard.Action, slotID: String) {
        switch action {
        case .download:
            guard let content = store.qrSlots.first(where: { $0.id == slotID })?.content,
                  let image = QRCodeImage.make(string: content.url) else { return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            haptics.fire(.sendSuccess)
        case .copyURL:
            if let url = store.qrSlots.first(where: { $0.id == slotID })?.content?.url {
                UIPasteboard.general.string = url
                haptics.fire(.sendSuccess)
            }
        case .edit:
            showsBindPicker = true
        case .toggleDisable:
            guard let content = store.qrSlots.first(where: { $0.id == slotID })?.content else { return }
            confirmAction = ConfirmAction(
                title: content.isDisabled ? "启用客服码" : "停用客服码",
                message: content.isDisabled ? "启用后扫码将重新接入客服。" : "停用后扫码将提示客服不在线，可随时启用。",
                isDestructive: false
            ) {
                store.updateSlotContent(slotID: slotID) { $0.isDisabled.toggle() }
                haptics.fire(.toggleChanged)
            }
        case .delete:
            confirmAction = ConfirmAction(
                title: "删除客服码",
                message: "删除后需重新生产出码，确定删除？",
                isDestructive: true
            ) {
                store.deleteCode(slotID: slotID)
            }
        }
    }

    // MARK: - ③ 快捷文字栏

    private var quickTextSection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing8) {
            HStack {
                Text("快捷文字").font(.subheadline.weight(.medium))
                Text("点 = 填入防误触").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Button {
                    showsQuickTextEditor = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.starlinkAccent)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("新增快捷文字")
            }
            if store.quickTexts.isEmpty {
                Text("暂无快捷文字")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Metrics.spacing8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Metrics.spacing8) {
                        ForEach(store.quickTexts) { text in
                            Button {
                                if store.fillQuickText(text) {
                                    haptics.fire(.toggleChanged)
                                } else {
                                    confirmAction = ConfirmAction(
                                        title: "先打开一个会话",
                                        message: "点按快捷文字会填入会话输入框；请先在「消息」Tab 打开任一会话。",
                                        isDestructive: false
                                    ) {}
                                }
                            } label: {
                                Text(text.title)
                                    .font(.subheadline)
                                    .padding(.horizontal, Metrics.spacing12)
                                    .padding(.vertical, Metrics.spacing8)
                                    .background(Capsule().fill(Color(uiColor: .secondarySystemGroupedBackground)))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { showsQuickTextEditor = true } label: { Label("编辑", systemImage: "pencil") }
                                Button(role: .destructive) {
                                    store.deleteQuickText(id: text.id)
                                } label: { Label("删除", systemImage: "trash") }
                                Button { store.moveQuickText(id: text.id, offset: -1) } label: { Label("上移", systemImage: "arrow.up") }
                                Button { store.moveQuickText(id: text.id, offset: 1) } label: { Label("下移", systemImage: "arrow.down") }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - ④ 快捷图片栏

    private var quickImageSection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing8) {
            HStack {
                Text("快捷图片").font(.subheadline.weight(.medium))
                Text("点 = 直接发送").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Button {
                    showsImageLibPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.starlinkAccent)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("从图库添加快捷图片")
            }
            if store.quickImages.isEmpty {
                Text("暂无快捷图片，从图库添加")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Metrics.spacing8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Metrics.spacing8) {
                        ForEach(store.quickImages) { image in
                            Button {
                                if store.sendQuickImage(image) {
                                    haptics.fire(.sendSuccess)
                                } else {
                                    confirmAction = ConfirmAction(
                                        title: "先打开一个会话",
                                        message: "点按快捷图片会直接发送到会话；请先在「消息」Tab 打开任一会话。",
                                        isDestructive: false
                                    ) {}
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
                                    store.quickImages.removeAll { $0.id == image.id }
                                    store.persist()
                                } label: { Label("从快捷栏移除", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - ⑤⑥ 提示词触发板块

    private var intentSection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing8) {
            Text("提示词触发").font(.subheadline.weight(.medium))
            HStack(spacing: Metrics.spacing16) {
                intentEntryCard(.text, title: "提示词触发 · 文字", icon: "text.bubble")
                intentEntryCard(.image, title: "提示词触发 · 图片", icon: "photo.stack")
            }
        }
    }

    private func intentEntryCard(_ focus: IntentFocus, title: String, icon: String) -> some View {
        NavigationLink(value: WorkbenchRoute.intentList(focus)) {
            VStack(alignment: .leading, spacing: Metrics.spacing8) {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(enabledCount(for: focus) == 0 ? "未启用意图" : "启用中 \(enabledCount(for: focus)) 个")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
            .padding(Metrics.spacing12)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cornerRadiusCard, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
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
}

/// 客服码卡（含过期灰显 / 倒计时 / 按钮排）
struct QRSlotCard: View {
    enum Action { case download, copyURL, edit, toggleDisable, delete }

    let slot: QRSlot
    var onAction: (Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing8) {
            Text(slot.title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            slotBody
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(Color(uiColor: .systemBackground))

            buttonGrid
        }
        .padding(Metrics.spacing8)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusCard, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private var slotBody: some View {
        if let content = slot.content {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let countdown = CountdownText.forExpiry(content.expiresAt, now: context.date)
                ZStack {
                    if let qr = QRCodeImage.make(string: content.url) {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .opacity(content.isDisabled || countdown.isExpired ? 0.4 : 1)
                    }
                    VStack {
                        Spacer()
                        HStack(spacing: Metrics.spacing4) {
                            Circle().fill(Color.starlinkAccent).frame(width: 18, height: 18)
                                .overlay(Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.white))
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let countdown = CountdownText.forExpiry(content.expiresAt, now: context.date)
                    Text(countdown.isExpired ? "已过期" : "剩余 \(countdown.text)")
                        .font(.caption2)
                        .foregroundStyle(
                            countdown.isExpired || content.isDisabled
                                ? Color.secondary
                                : (countdown.within24h ? Color.orange : Color.secondary)
                        )
                }
                .padding(.bottom, 2)
            }
        } else {
            ContentUnavailableView("待生产", systemImage: "qrcode", description: Text("点上方「生产」出码"))
                .font(.caption2)
        }
    }

    private var buttonGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: Metrics.spacing4)], spacing: Metrics.spacing4) {
            slotButton("下载图片", "arrow.down.circle") { onAction(.download) }
                .disabled(slot.content == nil)
            slotButton("复制网址", "doc.on.doc") { onAction(.copyURL) }
                .disabled(slot.content == nil)
            slotButton("编辑", "person.crop.circle.badge.gearshape") { onAction(.edit) }
                .disabled(slot.content == nil)
            slotButton(slot.content?.isDisabled == true ? "启用" : "停用",
                       slot.content?.isDisabled == true ? "play.circle" : "pause.circle") { onAction(.toggleDisable) }
                .disabled(slot.content == nil)
            slotButton("删除", "trash", role: .destructive) { onAction(.delete) }
                .disabled(slot.content == nil)
        }
    }

    private func slotButton(_ title: String, _ icon: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.body)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(role == .destructive ? Color.red : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

/// 倒计时文案：>24h「x天x小时」；≤24h 橙色；过期灰显
enum CountdownText {
    struct Result {
        var text: String
        var within24h: Bool
        var isExpired: Bool
    }

    static func forExpiry(_ date: Date, now: Date = Date()) -> Result {
        let interval = date.timeIntervalSince(now)
        guard interval > 0 else { return Result(text: "0", within24h: false, isExpired: true) }
        let totalHours = Int(interval / 3600)
        let days = totalHours / 24
        let hours = totalHours % 24
        if days > 0 {
            return Result(text: "\(days)天\(hours)小时", within24h: false, isExpired: false)
        }
        return Result(text: "\(hours)小时\(Int(interval.truncatingRemainder(dividingBy: 3600) / 60))分", within24h: true, isExpired: false)
    }
}
