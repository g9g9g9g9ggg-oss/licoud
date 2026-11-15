import SwiftUI
import UIKit

/// 联系人（第二期预写）：员工列表 + 在线状态 + 系统 Section 分组
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
    private var grouped: [(department: String, contacts: [Contact])] {
        let dictionary = Dictionary(grouping: MockContacts.all, by: \.department)
        return dictionary.keys.sorted().map { (department: $0, contacts: dictionary[$0] ?? []) }
    }

    var body: some View {
        List {
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
    }
}

private struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: Metrics.spacing12) {
            ZStack(alignment: .bottomTrailing) {
                Text(String(contact.name.suffix(2).prefix(1)))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(uiColor: .quaternarySystemFill)))

                Circle()
                    .fill(contact.isOnline ? Color.green : Color(uiColor: .systemGray3))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name).font(.body)
                Text(contact.role).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, Metrics.spacing4)
    }
}
