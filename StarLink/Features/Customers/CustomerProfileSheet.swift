import SwiftUI
import UIKit

/// 客户资料卡 v2（机主 2026-11-17 指示）：
/// · 逐项改动（每次确定只写一项，其余不动）
/// · 改动记录（谁改的 / 前后值 / 时间）
/// · 一键复制商务文本（完整·简洁·高档）
/// · 界面商务原生风（系统深色 + 蓝·金语义色，去花哨）
struct CustomerProfileSheet: View {
    let customerID: String

    @Environment(HapticService.self) private var haptics
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    private var store = CustomerStore.shared
    private var engine = ChatDemoEngine.shared

    @State private var name = ""
    @State private var quota = ""
    @State private var regionManual = ""
    @State private var remark0 = ""
    @State private var remark1 = ""
    @State private var remark2 = ""
    @State private var loaded = false
    @State private var showsCopyToast = false

    private var customer: Customer? { store.customer(forPeerID: customerID) }
    private var conversationID: String { "cust-\(customerID)" }
    private var editorName: String { session.currentUser?.name ?? "客服" }

    init(customerID: String) {
        self.customerID = customerID
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if let customer {
                        headerSummary(customer)
                        fieldRow(title: "码名", placeholder: "客户名", text: $name, original: customer.name, field: "码名", onCommit: {
                            engine.renameConversationPeer(peerID: customer.id, to: name)
                        })
                        fieldRow(title: "额度", placeholder: "如：2.5万 / 500U / 待定", text: $quota, original: customer.quota ?? "", field: "额度")
                        fieldRow(title: "地区（手动）", placeholder: "如：广东·深圳", text: $regionManual, original: customer.regionManual ?? "", field: "地区")
                        fieldRow(title: "备注", placeholder: "备注", text: $remark0, original: remarkOriginal(0), field: "备注")
                        fieldRow(title: "备注+1", placeholder: "备注+1", text: $remark1, original: remarkOriginal(1), field: "备注+1")
                        fieldRow(title: "备注+2", placeholder: "备注+2", text: $remark2, original: remarkOriginal(2), field: "备注+2")
                        coreInfoCard(customer)
                        changeLogCard(customer)
                    } else {
                        ContentUnavailableView("客户不存在", systemImage: "person.crop.circle.badge.xmark")
                    }
                }
                .padding(14)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("客户资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear(perform: load)
            .overlay(alignment: .bottom) {
                if showsCopyToast {
                    toast
                }
            }
        }
    }

    // MARK: - 顶部摘要 + 一键复制

    private func headerSummary(_ customer: Customer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(String(customer.name.suffix(2).prefix(1)))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color(uiColor: .systemBlue)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(customer.name).font(.headline)
                    HStack(spacing: 4) {
                        if customer.isOnline {
                            Circle().fill(Color.green).frame(width: 7, height: 7)
                            Text("在线").font(.caption2).foregroundStyle(.secondary)
                        } else {
                            Text("离线").font(.caption2).foregroundStyle(.tertiary)
                        }
                        Text("· 消息 \(engine.messages(for: conversationID).count)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = store.profileCardText(customer, messageCount: engine.messages(for: conversationID).count)
                    haptics.fire(.sendSuccess)
                    withAnimation { showsCopyToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation { showsCopyToast = false }
                    }
                } label: {
                    Label("复制资料卡", systemImage: "doc.on.doc.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color(uiColor: .systemBlue)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(cardShape)
    }

    // MARK: - 逐项改动行（有改动才亮「确定」）

    private func fieldRow(title: String, placeholder: String, text: Binding<String>, original: String, field: String, onCommit: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                let changed = text.wrappedValue != original && !(text.wrappedValue.isEmpty && original.isEmpty)
                Button(changed ? "确定改动" : "确定") {
                    store.updateProfile(
                        customerID: customerID,
                        editor: editorName,
                        field: field,
                        oldValue: original,
                        newValue: text.wrappedValue
                    )
                    onCommit?()
                    haptics.fire(.sendSuccess)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(changed ? Color(uiColor: .systemBlue) : Color(uiColor: .systemGray3)))
                .disabled(!changed)
            }
            TextField(placeholder, text: text)
                .padding(11)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
        }
        .padding(14)
        .background(cardShape)
    }

    // MARK: - 核心信息（只读：来源码 / 设备 / IP / 地区·运营商）

    private func coreInfoCard(_ customer: Customer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("核心信息").font(.subheadline.weight(.semibold))
            LabeledContent {
                HStack(spacing: 4) {
                    if let no = customer.sourceCodeNo {
                        Text(no).font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.red.opacity(0.85)))
                            .foregroundStyle(.white)
                    }
                    if let remark = customer.sourceCodeRemark {
                        Text(remark).font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color(uiColor: .systemBlue)))
                            .foregroundStyle(.white)
                    }
                }
            } label: { Text("来源二维码").foregroundStyle(.secondary) }
            LabeledContent("设备", value: customer.device)
            LabeledContent("IP", value: customer.ip)
            if let carrier = customer.regionCarrier {
                LabeledContent("地区·运营商", value: carrier)
            }
            Divider()
            LabeledContent("进入时间", value: Self.shortTime(customer.enteredAt))
            LabeledContent("最近消息", value: Self.shortTime(customer.lastActiveAt))
        }
        .font(.subheadline)
        .padding(14)
        .background(cardShape)
    }

    // MARK: - 改动记录（谁改的）

    private func changeLogCard(_ customer: Customer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("改动记录").font(.subheadline.weight(.semibold))
            if customer.changeLog.isEmpty {
                Text("暂无改动").font(.caption).foregroundStyle(.tertiary)
            } else {
                ForEach(customer.changeLog) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(entry.field).font(.caption.weight(.semibold))
                            Text("· \(entry.editor)").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(Self.shortTime(entry.date)).font(.caption2).foregroundStyle(.tertiary)
                        }
                        Text("\(entry.oldValue.isEmpty ? "空" : entry.oldValue) → \(entry.newValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
        .padding(14)
        .background(cardShape)
    }

    // MARK: - 工具

    private var cardShape: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private var toast: some View {
        Label("已复制完整资料卡", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.75)))
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func remarkOriginal(_ index: Int) -> String {
        guard let customer, customer.remarks.indices.contains(index) else { return "" }
        return customer.remarks[index]
    }

    private static func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func load() {
        guard !loaded, let customer else { return }
        name = customer.name
        quota = customer.quota ?? ""
        regionManual = customer.regionManual ?? ""
        remark0 = remarkOriginal(0)
        remark1 = remarkOriginal(1)
        remark2 = remarkOriginal(2)
        loaded = true
    }
}
