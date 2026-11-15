import SwiftUI
import UIKit

/// 消息 Tab 内路由
enum ChatRoute: Hashable {
    case conversation(String)
    case chat(Contact)   // 联系人一步开聊：push 时确保会话存在
    case contacts
}

/// 消息列表（设计书 6.1 / 任务书第二期）：头像、昵称、预览、时间、未读红点、滑动操作
/// 打磨包：会话搜索、置顶（contextMenu）、下拉刷新真实化（重读本地库）
/// 数据源：引擎 @Observable 状态（uiConversations）
struct ConversationListView: View {
    private let engine = ChatDemoEngine.shared
    @State private var searchText = ""

    private var filtered: [ChatConversation] {
        let all = engine.conversations()
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.peerName.localizedCaseInsensitiveContains(searchText)
                || $0.lastMessageText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        let conversations = filtered
        return List {
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
                        engine.deleteConversation(conversation.id)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        engine.setPinned(!conversation.isPinned, forConversationID: conversation.id)
                    } label: {
                        Label(
                            conversation.isPinned ? "取消置顶" : "置顶",
                            systemImage: conversation.isPinned ? "pin.slash" : "pin"
                        )
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
        .searchable(text: $searchText, prompt: "搜索会话")
        // 下拉刷新：演示期重读本地库（第二期接会话历史接口）
        .refreshable { engine.reloadFromStore() }
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
                ContentUnavailableView(
                    searchText.isEmpty ? "暂无消息" : "无匹配会话",
                    systemImage: searchText.isEmpty ? "message" : "magnifyingglass"
                )
            }
        }
    }
}

private struct ConversationRow: View {
    let conversation: ChatConversation

    var body: some View {
        HStack(spacing: Metrics.spacing12) {
            Text(String(conversation.peerName.suffix(2).prefix(1)))
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(uiColor: .quaternarySystemFill)))
                .overlay(alignment: .topTrailing) {
                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.starlinkAccent)
                            .padding(3)
                    }
                }

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
