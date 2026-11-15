#if DEBUG
import SwiftData
import SwiftUI
import UIKit

/// 消息 Tab 内路由
enum ChatRoute: Hashable {
    case conversation(String)
    case chat(Contact)   // 联系人一步开聊：push 时确保会话存在
    case contacts
}

/// 消息列表（设计书 6.1 / 任务书第二期）：头像、昵称、预览、时间、未读红点、滑动操作
struct ConversationListView: View {
    @Query(sort: [SortDescriptor(\Conversation.lastMessageAt, order: .reverse)])
    private var conversations: [Conversation]

    private let engine = ChatDemoEngine.shared

    var body: some View {
        List {
            ForEach(conversations) { conversation in
                NavigationLink(value: ChatRoute.conversation(conversation.id)) {
                    ConversationRow(conversation: conversation)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if conversation.unreadCount > 0 {
                        Button {
                            engine.markConversationRead(withID: conversation.id)
                        } label: {
                            Label("标记已读", systemImage: "checkmark.circle")
                        }
                        .tint(.blue)
                    }
                    Button(role: .destructive) {
                        engine.deleteConversation(conversation)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("消息")
        .toolbar {
            NavigationLink(value: ChatRoute.contacts) {
                Image(systemName: "person.crop.circle.badge.plus")
            }
            .accessibilityLabel("联系人")
        }
        // TODO(第二期): 接会话历史接口，替换本地种子/缓存刷新
        .refreshable { try? await Task.sleep(for: .seconds(1)) }
        .navigationDestination(for: ChatRoute.self) { route in
            switch route {
            case .contacts:
                ContactsView()
            case .conversation(let id):
                ChatView(conversationID: id)
            case .chat(let contact):
                ChatView(
                    conversationID: engine.findOrCreateConversation(
                        peerID: contact.id,
                        peerName: contact.name
                    ).id
                )
            }
        }
        .overlay {
            if conversations.isEmpty {
                ContentUnavailableView("暂无消息", systemImage: "message")
            }
        }
    }
}

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: Metrics.spacing12) {
            Text(String(conversation.peerName.suffix(2).prefix(1)))
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(uiColor: .quaternarySystemFill)))

            VStack(alignment: .leading, spacing: Metrics.spacing4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(conversation.peerName).font(.headline)
                    Spacer()
                    Text(ChatTimeFormatter.string(for: conversation.lastMessageAt))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(conversation.lastMessageText.isEmpty ? "暂无消息" : conversation.lastMessageText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if conversation.unreadCount > 0 {
                Text(conversation.unreadCount > 99 ? "99+" : "\(conversation.unreadCount)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Metrics.spacing4)
                    .padding(.vertical, 2)
                    .frame(minWidth: 18)
                    .background(Capsule().fill(Color.red))
            }
        }
        .padding(.vertical, Metrics.spacing4)
    }
}
#endif
