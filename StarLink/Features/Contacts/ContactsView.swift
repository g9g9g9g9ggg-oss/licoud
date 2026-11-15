import SwiftUI
import UIKit

/// 联系人（第二期预写）：员工列表 + 在线状态 + 系统 Section 分组
/// 打磨包：搜索、头像按姓名着色、在线摘要、快捷发消息
/// TODO(第二期): 员工列表接后台接口；在线状态来源随「三问」实时通道确认后接入
struct Contact: Identifiable, Hashable {
    let id: String        // 员工 ID，与聊天 peerID 同一体系
    let name: String
    let role: String
    let department: String
    let isOnline: Bool
}

/// 本地 mock 员工（TEST_ 前缀）；张三/李四与聊天种子会话对应
enum MockContacts {
    static let all: [Contact] = [
        Contact(id: "1002", name: "TEST_张三", role: "客服", department: "客服一组", isOnline: true),
        Contact(id: "1003", name: "TEST_李四", role: "客服", department: "客服一组", isOnline: false),
        Contact(id: "1004", name: "TEST_王五", role: "客服", department: "客服二组", isOnline: true),
        Contact(id: "1005", name: "TEST_赵六", role: "主管", department: "管理组", isOnline: true),
    ]
}

struct ContactsView: View {
    @State private var searchText = ""

    private var filtered: [Contact] {
        guard !searchText.isEmpty else { return MockContacts.all }
        return MockContacts.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.role.localizedCaseInsensitiveContains(searchText)
                || $0.department.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var grouped: [(department: String, contacts: [Contact])] {
        let dictionary = Dictionary(grouping: filtered, by: \.department)
        return dictionary.keys.sorted().map { (department: $0, contacts: dictionary[$0] ?? []) }
    }

    private var onlineCount: Int { filtered.filter(\.isOnline).count }

    var body: some View {
        List {
            Section {
                LabeledContent("在线") {
                    Text("\(onlineCount) / \(filtered.count)")
                        .foregroundStyle(onlineCount > 0 ? Color.green : .secondary)
                        .monospacedDigit()
                }
            }
            ForEach(grouped, id: \.department) { group in
                Section(group.department) {
                    ForEach(group.contacts) { contact in
                        NavigationLink(value: ChatRoute.chat(contact)) {
                            ContactRow(contact: contact)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("联系人")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索姓名 / 角色 / 部门")
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView("无匹配联系人", systemImage: "person.crop.circle.badge.magnifyingglass")
            }
        }
    }
}

/// 头像底色：按姓名哈希取档位色（打磨包，纯系统色不引新依赖）
private enum AvatarPalette {
    static let palette: [Color] = [
        Color(red: 0.36, green: 0.55, blue: 0.92),
        Color(red: 0.35, green: 0.72, blue: 0.58),
        Color(red: 0.90, green: 0.55, blue: 0.35),
        Color(red: 0.62, green: 0.48, blue: 0.85),
        Color(red: 0.85, green: 0.42, blue: 0.50),
        Color(red: 0.42, green: 0.68, blue: 0.78),
    ]

    static func color(for name: String) -> Color {
        let index = abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % palette.count
        return palette[index]
    }
}

private struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: Metrics.spacing12) {
            ZStack(alignment: .bottomTrailing) {
                Text(String(contact.name.suffix(2).prefix(1)))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(AvatarPalette.color(for: contact.name)))

                Circle()
                    .fill(contact.isOnline ? Color.green : Color(uiColor: .systemGray3))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name).font(.body)
                HStack(spacing: Metrics.spacing4) {
                    Text(contact.role)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
                    Text(contact.department)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, Metrics.spacing4)
    }
}
