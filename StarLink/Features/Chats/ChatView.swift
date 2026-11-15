import SwiftData
import SwiftUI
import UIKit

/// 聊天窗口（设计书 6.1）：气泡流 + 时间分隔 + 底部输入栏（safeAreaInset）
/// 历史加载留桩：TODO(第二期) 顶部滚动翻页接历史接口
struct ChatView: View {
    let conversationID: String
    private let engine = ChatDemoEngine.shared

    @Query private var messages: [Message]
    @State private var draft = ""
    @State private var viewerMessage: Message?

    init(conversationID: String) {
        self.conversationID = conversationID
        let id = conversationID
        _messages = Query(
            filter: #Predicate<Message> { $0.conversationID == id },
            sort: [SortDescriptor(\Message.sentAt)]
        )
    }

    var body: some View {
        Group {
            if let conversation = engine.conversation(withID: conversationID) {
                chatBody(conversation)
            } else {
                ContentUnavailableView("会话不存在", systemImage: "message.badge.exclamationmark")
            }
        }
        .navigationTitle(engine.conversation(withID: conversationID)?.peerName ?? "TEST")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            engine.activeConversationID = conversationID
            engine.markConversationRead(withID: conversationID)
        }
        .onDisappear {
            engine.activeConversationID = nil
        }
    }

    private func chatBody(_ conversation: Conversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Metrics.spacing4) {
                    ForEach(rows) { row in
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
                ChatInputBar(
                    draft: $draft,
                    onSend: {
                        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        draft = ""
                        Task { await engine.sendMessage(text, in: conversation) }
                    },
                    onPickImage: { data in
                        Task { await engine.sendImage(rawData: data, in: conversation) }
                    }
                )
            }
            .fullScreenCover(item: $viewerMessage) { message in
                ImageViewerView(data: message.imageData) {
                    viewerMessage = nil
                }
            }
            .onChange(of: messages.count) { _, _ in
                guard let last = messages.last else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - 行组装（含 >10 分钟时间分隔）

    private enum ChatRow: Identifiable {
        case time(Date)
        case message(Message)

        var id: String {
            switch self {
            case .time(let date): return "time-\(date.timeIntervalSince1970)"
            case .message(let message): return message.id
            }
        }
    }

    private var rows: [ChatRow] {
        var result: [ChatRow] = []
        var previous: Message?
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
                onOpenImage: { viewerMessage = message }
            )
        }
    }
}

/// 大图查看（设计书 6.1）：fullScreenCover + 弹簧缩放拟系统照片转场
/// 拖拽下滑关闭、双击 1x/2x、捏合缩放 1–4x；最低 iOS 17 下无原生 zoom 转场，升 iOS 18 可换 .navigationTransition(.zoom)
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
