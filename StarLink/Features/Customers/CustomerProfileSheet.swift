import SwiftUI
import UIKit

/// 客户资料卡（机主参考图：暗色卡 + 核心信息 + 额度/地区/备注逐项确定 + 时间线）
/// 入口：客户会话右上角「资料」（会话由「模拟客户扫码」生成）
struct CustomerProfileSheet: View {
    let customerID: String

    @Environment(HapticService.self) private var haptics
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

    private var customer: Customer? { store.customer(forPeerID: customerID) }
    private var conversationID: String { "cust-\(customerID)" }

    // 参考图配色：暗底 + 绿强调
    private let bg = Color(red: 0.06, green: 0.08, blue: 0.11)
    private let card = Color(red: 0.10, green: 0.13, blue: 0.17)
    private let accent = Color(red: 0.0, green: 0.78, blue: 0.36)

    init(customerID: String) {
        self.customerID = customerID
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if let customer {
                        nameCard
                        coreInfoCard(customer)
                        quotaCard
                        regionCard
                        remarksCard
                        timelineCard(customer)
                    } else {
                        ContentUnavailableView("客户不存在", systemImage: "person.crop.circle.badge.xmark")
                    }
                }
                .padding(14)
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("客户资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
            .onAppear(perform: load)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 码名（逐项确定式：输入 + 绿色确定）

    private var nameCard: some View {
        HStack(spacing: 8) {
            TextField("客户名", text: $name)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(card)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(accent.opacity(0.7), lineWidth: 1))
                )
            confirmButton("确定") {
                store.updateProfile(customerID: customerID) { $0.name = name }
            }
        }
    }

    // MARK: - 核心信息（来源二维码 / 设备 / IP + 地区运营商）

    private func coreInfoCard(_ customer: Customer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("核心信息")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
            HStack {
                Text("来源二维码").foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    if let no = customer.sourceCodeNo {
                        Text(no)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.red.opacity(0.85)))
                            .foregroundStyle(.white)
                    }
                    if let remark = customer.sourceCodeRemark {
                        Text(remark)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(red: 0.0, green: 0.55, blue: 0.35)))
                            .foregroundStyle(.white)
                    }
                }
            }
            LabeledContent("设备", value: customer.device)
            LabeledContent("IP", value: customer.ip)
            if let rc = customer.regionCarrier {
                LabeledContent("地区·运营商", value: rc)
            }
        }
        .font(.subheadline)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(card)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(accent.opacity(0.35), lineWidth: 1))
        )
    }

    // MARK: - 额度

    private var quotaCard: some View {
        HStack(spacing: 8) {
            TextField("如：2.5万 / 500U / 待定", text: $quota)
                .foregroundStyle(.white)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(card)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(accent.opacity(0.7), lineWidth: 1))
                )
            confirmButton("确定") {
                store.updateProfile(customerID: customerID) { $0.quota = quota }
            }
        }
    }

    // MARK: - 地区（手动填写）

    private var regionCard: some View {
        HStack(spacing: 8) {
            TextField("如：广东·深圳（手动填写）", text: $regionManual)
                .foregroundStyle(.white)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(card)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(accent.opacity(0.7), lineWidth: 1))
                )
            confirmButton("确定") {
                store.updateProfile(customerID: customerID) { $0.regionManual = regionManual }
            }
        }
    }

    // MARK: - 备注 / 备注+1 / 备注+2（逐项确定）

    private var remarksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            remarkField(index: 0, placeholder: "备注")
            remarkField(index: 1, placeholder: "备注+1")
            remarkField(index: 2, placeholder: "备注+2")
        }
    }

    private func remarkField(index: Int, placeholder: String) -> some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: remarkBinding(index))
                .foregroundStyle(.white)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(card)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(accent.opacity(0.7), lineWidth: 1))
                )
            confirmButton("确定") {
                store.updateProfile(customerID: customerID) { c in
                    c.remarks = [remark0, remark1, remark2]
                }
            }
        }
    }

    private func remarkBinding(_ index: Int) -> Binding<String> {
        switch index {
        case 0: return $remark0
        case 1: return $remark1
        default: return $remark2
        }
    }

    // MARK: - 时间线

    private func timelineCard(_ customer: Customer) -> some View {
        VStack(spacing: 10) {
            LabeledContent("消息数", value: "\(engine.messages(for: conversationID).count)")
            Divider().overlay(Color.white.opacity(0.08))
            LabeledContent("进入时间", value: DateFormatter.localizedString(from: customer.enteredAt, dateStyle: .short, timeStyle: .short))
            Divider().overlay(Color.white.opacity(0.08))
            LabeledContent("最近消息", value: DateFormatter.localizedString(from: customer.lastActiveAt, dateStyle: .short, timeStyle: .short))
        }
        .font(.subheadline)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(card)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(accent.opacity(0.35), lineWidth: 1))
        )
    }

    // MARK: - 工具

    private func confirmButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title) {
            action()
            haptics.fire(.sendSuccess)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(accent))
        .buttonStyle(.plain)
    }

    private func load() {
        guard !loaded, let customer else { return }
        name = customer.name
        quota = customer.quota ?? ""
        regionManual = customer.regionManual ?? ""
        let remarks = customer.remarks
        remark0 = remarks.count > 0 ? remarks[0] : ""
        remark1 = remarks.count > 1 ? remarks[1] : ""
        remark2 = remarks.count > 2 ? remarks[2] : ""
        loaded = true
    }
}
