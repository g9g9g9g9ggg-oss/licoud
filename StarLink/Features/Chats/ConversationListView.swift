import SwiftUI
import UIKit

/// 消息 Tab 内路由
enum ChatRoute: Hashable {
    case conversation(String)
}

/// 消息列表（机主参考 STARLINK MATRIX 会话页）：搜索客户/备注/地区、全部/未读筛选、
/// 客户行带标签 chips（码编号/地区·运营商/来源）、置顶、滑动操作、下拉刷新
struct ConversationListView: View {
    private let engine = ChatDemoEngine.shared
    private let customerStore = CustomerStore.shared
    @State private var searchText = ""
    @State private var filter: ConversationFilter = .all

    enum ConversationFilter: String, CaseIterable, Identifiable {
        case all = "全部"
        case unread = "未读"
        var id: String { rawValue }
    }

    private var allConversations: [ChatConversation] { engine.conversations() }

    private var filtered: [ChatConversation] {
        var list = allConversations
        if filter == .unread { list = list.filter { $0.unreadCount > 0 } }
        if !searchText.isEmpty {
            list = list.filter { conversation in
                let inName = conversation.peerName.localizedCaseInsensitiveContains(searchText)
                let inText = conversation.lastMessageText.localizedCaseInsensitiveContains(searchText)
                let customer = customerStore.customer(forPeerID: conversation.peerID)
                let inTags = [customer?.sourceCodeRemark, customer?.sourceCodeNo, customer?.regionCarrier, customer?.regionManual]
                    .compactMap { $0 }
                    .contains { $0.localizedCaseInsensitiveContains(searchText) }
                return inName || inText || inTags
            }
        }
        return list
    }

    var body: some View {
        List {
            Section {
                Picker("", selection: $filter) {
                    ForEach(ConversationFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            ForEach(filtered) { conversation in
                NavigationLink(value: ChatRoute.conversation(conversation.id)) {
                    ConversationRow(conversation: conversation, customer: customerStore.customer(forPeerID: conversation.peerID))
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
        .searchable(text: $searchText, prompt: "搜索客户 / 备注 / 地区")
        .refreshable { engine.reloadFromStore() }
        .navigationDestination(for: ChatRoute.self) { route in
            switch route {
            case .conversation(let id):
                ChatView(conversationID: id)
            }
        }
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? (filter == .unread ? "没有未读会话" : "暂无会话") : "无匹配结果",
                    systemImage: searchText.isEmpty ? "message" : "magnifyingglass"
                )
            }
        }
    }
}

/// 会话行：客户行带在线状态与标签 chips；员工行保持简洁
struct ConversationRow: View {
    let conversation: ChatConversation
    let customer: Customer?

    var body: some View {
        HStack(spacing: Metrics.spacing12) {
            avatar
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(conversation.peerName)
                        .font(.body.weight(customer != nil ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    if let customer, customer.isOnline, let since = customer.onlineSince {
                        HStack(spacing: 3) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text("在线 \(ChatTimeFormatter.string(for: since))")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(ChatTimeFormatter.string(for: conversation.lastMessageAt))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(conversation.lastMessageText.isEmpty ? "暂无消息" : conversation.lastMessageText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let customer, !customer.headerTags.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(customer.headerTags.enumerated()), id: \.offset) { index, tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(tagColor(index).opacity(0.16)))
                                .foregroundStyle(tagColor(index))
                        }
                    }
                }
            }
            Spacer(minLength: 4)
            if conversation.unreadCount > 0 {
                Text("\(conversation.unreadCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.red))
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, Metrics.spacing4)
    }

    private func tagColor(_ index: Int) -> Color {
        switch index {
        case 0: return .red          // 码编号
        case 1: return .blue         // 地区·运营商
        case 2: return .purple       // 附加
        default: return .secondary
        }
    }

    @ViewBuilder
    private var avatar: some View {
        ZStack(alignment: .topTrailing) {
            Text(String(conversation.peerName.suffix(2).prefix(1)))
                .font(.headline)
                .foregroundStyle(customer != nil ? .white : .secondary)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(
                        customer != nil
                            ? Color(red: 0.0, green: 0.55, blue: 0.35)
                            : Color(uiColor: .quaternarySystemFill)
                    )
                )
            if conversation.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.starlinkAccent)
                    .padding(3)
            }
        }
    }
}
