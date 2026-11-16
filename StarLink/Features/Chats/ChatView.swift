import SwiftUI
import UIKit

/// 聊天窗口（设计书 6.1）：气泡流 + 时间分隔 + 底部输入栏（safeAreaInset）
/// 打磨包：➕ 面板（快捷文字/快捷图片/关键词回复/欢迎语，像微信一样）
///         引用（长按 → 引用条 → 气泡内引用块）、撤回灰条
/// 数据源：引擎 @Observable 状态（uiMessages）—— SwiftData 仅在引擎内部作持久化
/// 历史加载留桩：TODO(第二期) 顶部滚动翻页接历史接口
struct ChatView: View {
    let conversationID: String
    private let engine = ChatDemoEngine.shared
    @Environment(HapticService.self) private var haptics

    @State private var draft = ""
    @State private var viewerMessage: ChatMessage?
    /// 快捷文字「点 = 填入」的消费入口（码池跨 Tab 投递）
    @State private var draftBox = ChatDraftBox.shared
    /// 引用中的消息（nil = 无）
    @State private var quotedMessage: ChatMessage?
    /// ➕ 面板展开状态
    @State private var plusPanel: PlusPanel?
    @State private var showsWelcomeEditor = false
    @State private var showsIntentList = false
    @State private var profileCustomerID: String?

    private var peerID: String { engine.conversation(conversationID)?.peerID ?? "" }
    private var customer: Customer? { CustomerStore.shared.customer(forPeerID: peerID) }

    enum PlusPanel: String, Identifiable {
        case main, quickTexts, quickImages
        var id: String { rawValue }
    }

    /// sheet(item:) 载体
    struct ProfileTarget: Identifiable {
        let id: String
    }

    private func tagColor(_ index: Int) -> Color {
        switch index {
        case 0: return .red
        case 1: return .blue
        case 2: return .purple
        default: return .secondary
        }
    }

    var body: some View {
        content
            .toolbar { headerToolbar }
            .toolbar { profileToolbarButton }
            .sheet(item: Binding(
                get: { profileCustomerID.map { ProfileTarget(id: $0) } },
                set: { profileCustomerID = $0?.id }
            )) { target in
                CustomerProfileSheet(customerID: target.id)
            }
            .onAppear(perform: onEnter)
            .onChange(of: draftBox.pendingText) { _, _ in
                if let pending = draftBox.consumeText() {
                    draft = pending
                }
            }
        .navigationDestination(for: WorkbenchRoute.self) { route in
            switch route {
            case .intentList(let focus):
                IntentListView(focus: focus)
            }
        }
        .navigationDestination(isPresented: $showsWelcomeEditor) {
            WelcomeEditView()
        }
        .navigationDestination(isPresented: $showsIntentList) {
            IntentListView(focus: .text)
        }
    }

    // MARK: - 拆分成员（body 类型检查提速）

    @ViewBuilder
    private var content: some View {
        if engine.conversation(conversationID) != nil {
            chatBody
        } else {
            ContentUnavailableView("会话不存在", systemImage: "message.badge.exclamationmark")
        }
    }

    private func onEnter() {
        engine.activeConversationID = conversationID
        engine.markConversationRead(withID: conversationID)
        if let pending = draftBox.consumeText() {
            draft = pending
        }
    }

    @ToolbarContentBuilder
    private var headerToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 3) {
                Text(engine.conversation(conversationID)?.peerName ?? "")
                    .font(.headline)
                if let customer, !customer.headerTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(customer.headerTags.enumerated()), id: \.offset) { index, tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(tagColor(index).opacity(0.18)))
                                .foregroundStyle(tagColor(index))
                        }
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var profileToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if customer != nil {
                Button("资料") { profileCustomerID = customer!.id }
                    .font(.subheadline)
            }
        }
    }

    private var chatBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Metrics.spacing4) {
                    ForEach(rows(from: engine.messages(for: conversationID))) { row in
                        rowView(row)
                    }
                }
                .padding(.horizontal, Metrics.spacing12)
                .padding(.vertical, Metrics.spacing8)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    if let quote = quotedMessage { quoteStrip(for: quote) }
                    ChatInputBar(
                        draft: $draft,
                        onSend: send,
                        onPickImage: { data in
                            Task { await engine.sendImage(rawData: data, in: conversationID) }
                        },
                        onPlus: { togglePanel() }
                    )
                    if let panel = plusPanel { panelContent(panel) }
                }
                .background(.regularMaterial)
            }
            .fullScreenCover(item: $viewerMessage) { message in
                ImageViewerView(data: message.imageData) {
                    viewerMessage = nil
                }
            }
            .onChange(of: engine.messages(for: conversationID).count) { _, _ in
                let messages = engine.messages(for: conversationID)
                guard let last = messages.last else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - 发送 / 引用 / 撤回 / 保存

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        let quote = quotedMessage
        quotedMessage = nil
        plusPanel = nil
        Task { await engine.sendMessage(text, in: conversationID, quote: quote) }
    }

    private func togglePanel() {
        if plusPanel == nil { hideKeyboard() }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            plusPanel = plusPanel == nil ? .main : nil
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func saveImage(_ message: ChatMessage) {
        guard let data = message.imageData, let image = UIImage(data: data) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    /// 引用条（输入栏上方）
    private func quoteStrip(for quote: ChatMessage) -> some View {
        HStack(spacing: Metrics.spacing8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.starlinkAccent.opacity(0.6))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text("引用 \(quote.senderID == engine.myUserID ? "我自己" : (engine.conversation(conversationID)?.peerName ?? "对方"))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(quote.quoteSummary)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                quotedMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("取消引用")
        }
        .padding(.horizontal, Metrics.spacing12)
        .padding(.vertical, Metrics.spacing8)
    }

    // MARK: - ➕ 面板（像微信一样）

    private func panelContent(_ panel: PlusPanel) -> some View {
        Group {
            switch panel {
            case .main: mainPanel
            case .quickTexts: quickTextPanel
            case .quickImages: quickImagePanel
            }
        }
        .padding(.horizontal, Metrics.spacing16)
        .padding(.vertical, Metrics.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var mainPanel: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Metrics.spacing16) {
            panelButton("快捷文字", "text.bubble", tint: .blue) { plusPanel = .quickTexts }
            panelButton("快捷图片", "photo.stack", tint: .green) { plusPanel = .quickImages }
            panelButton("关键词回复", "text.badge.plus", tint: .orange) {
                plusPanel = nil
                showsIntentList = true
            }
            Button {
                plusPanel = nil
                showsWelcomeEditor = true
            } label: {
                panelButtonLabel("欢迎语", "wave.bubble", tint: .purple)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Metrics.spacing8)
    }

    private func panelButton(_ title: String, _ icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { panelButtonLabel(title, icon, tint: tint) }
            .buttonStyle(.plain)
    }

    private func panelButtonLabel(_ title: String, _ icon: String, tint: Color) -> some View {
        VStack(spacing: Metrics.spacing8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Color(uiColor: .secondarySystemBackground)))
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    private var quickTextPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelBackHeader("快捷文字 · 点 = 填入")
            ForEach(store.quickTexts) { text in
                Button {
                    draft = text.content
                    plusPanel = nil
                    haptics.fire(.toggleChanged)
                } label: {
                    HStack {
                        Text(text.title).font(.subheadline).foregroundStyle(.primary)
                        Spacer()
                        Text(text.content).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
    }

    private var quickImagePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelBackHeader("快捷图片 · 点 = 直接发送")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Metrics.spacing8) {
                    ForEach(store.quickImages) { image in
                        Button {
                            Task { await engine.sendImage(rawData: image.imageData, in: conversationID) }
                            plusPanel = nil
                            haptics.fire(.sendSuccess)
                        } label: {
                            if let uiImage = UIImage(data: image.imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 84, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, Metrics.spacing8)
        }
    }

    private func panelBackHeader(_ title: String) -> some View {
        HStack {
            Button {
                plusPanel = .main
            } label: {
                Label(title, systemImage: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.bottom, Metrics.spacing8)
    }

    private var store: WorkbenchStore { WorkbenchStore.shared }

    // MARK: - 行组装（含 >10 分钟时间分隔）

    private enum ChatRow: Identifiable {
        case time(Date)
        case message(ChatMessage)

        var id: String {
            switch self {
            case .time(let date): return "time-\(date.timeIntervalSince1970)"
            case .message(let message): return message.id
            }
        }
    }

    private func rows(from messages: [ChatMessage]) -> [ChatRow] {
        var result: [ChatRow] = []
        var previous: ChatMessage?
        for message in messages {
            if let previous, message.sentAt.timeIntervalSince(previous.sentAt) > 600 {
                result.append(.time(message.sentAt))
            } else if previous == nil {
                result.append(.time(message.sentAt))
            }
            result.append(.message(message))
            previous = message
        }
        return result
    }

    @ViewBuilder
    private func rowView(_ row: ChatRow) -> some View {
        switch row {
        case .time(let date):
            Text(ChatTimeFormatter.string(for: date))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Metrics.spacing4)
        case .message(let message):
            ChatBubbleView(
                message: message,
                isOutgoing: message.senderID == engine.myUserID,
                onRetry: { engine.retryMessage(message) },
                onOpenImage: { viewerMessage = message },
                onDelete: { engine.deleteLocalMessage(message) },
                onQuote: {
                    quotedMessage = message
                    plusPanel = nil
                    hideKeyboard()
                },
                onRecall: {
                    engine.recallMessage(message)
                    haptics.fire(.warning)
                },
                onSaveImage: { saveImage(message) }
            )
        }
    }
}

/// 大图查看（设计书 6.1）：fullScreenCover + 弹簧缩放拟系统照片转场
/// 拖拽下滑关闭、双击 1x/2x、捏合缩放 1–4x
private struct ImageViewerView: View {
    let data: Data?
    var onClose: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .simultaneousGesture(magnificationGesture)
                    .gesture(dragGesture)
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            scale = scale > 1 ? 1 : 2
                            lastScale = scale
                            offset = .zero
                        }
                    }
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.6))
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .accessibilityLabel("关闭")
                    .padding(Metrics.spacing16)
                }
                Spacer()
            }
        }
    }

    /// 未放大时：下拉超过阈值关闭，否则弹回
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale <= 1.01 else { return }
                offset = value.translation
            }
            .onEnded { value in
                if abs(value.translation.height) > 120 {
                    onClose()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = .zero
                    }
                }
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = .zero
                    }
                }
            }
    }
}
