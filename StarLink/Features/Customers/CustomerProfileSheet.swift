import SwiftUI

/// 客户资料 sheet（机主参考「做主3」）：核心信息 + 额度/地区/备注逐项确定 + 时间线
struct CustomerProfileSheet: View {
    let customerID: String

    @Environment(HapticService.self) private var haptics
    @Environment(\.dismiss) private var dismiss
    private var customerStore = CustomerStore.shared
    private var engine = ChatDemoEngine.shared

    init(customerID: String) {
        self.customerID = customerID
    }

    @State private var name = ""
    @State private var quota = ""
    @State private var regionManual = ""
    @State private var remark0 = ""
    @State private var remark1 = ""
    @State private var remark2 = ""
    @State private var loaded = false

    private var customer: Customer? { customerStore.customer(forPeerID: customerID) }
    private var conversationID: String { "cust-\(customerID)" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: Metrics.spacing12) {
                        TextField("客户名", text: $name)
                            .font(.body.weight(.semibold))
                        Button("确定") {
                            customerStore.updateProfile(customerID: customerID) { $0.name = name }
                            haptics.fire(.sendSuccess)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("核心信息") {
                    if let customer {
                        LabeledContent("来源二维码") {
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
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color(red: 0.0, green: 0.55, blue: 0.35)))
                                }
                            }
                        }
                        LabeledContent("设备", value: customer.device)
                        LabeledContent("IP", value: customer.ip)
                    }
                }

                Section("额度（如：2.5万 / 500U / 待定）") {
                    HStack {
                        TextField("待填写", text: $quota)
                        Button("确定") {
                            customerStore.updateProfile(customerID: customerID) { $0.quota = quota }
                            haptics.fire(.sendSuccess)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Section("地区（手动填写）") {
                    HStack {
                        TextField("如：广东·深圳", text: $regionManual)
                        Button("确定") {
                            customerStore.updateProfile(customerID: customerID) { $0.regionManual = regionManual }
                            haptics.fire(.sendSuccess)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Section("备注") {
                    remarkRow(index: 0, placeholder: "备注", text: $remark0) {
                        customerStore.updateProfile(customerID: customerID) { c in
                            c.remarks = [remark0, remark1, remark2]
                        }
                        haptics.fire(.sendSuccess)
                    }
                    remarkRow(index: 1, placeholder: "备注+1", text: $remark1) {
                        customerStore.updateProfile(customerID: customerID) { c in
                            c.remarks = [remark0, remark1, remark2]
                        }
                        haptics.fire(.sendSuccess)
                    }
                    remarkRow(index: 2, placeholder: "备注+2", text: $remark2) {
                        customerStore.updateProfile(customerID: customerID) { c in
                            c.remarks = [remark0, remark1, remark2]
                        }
                        haptics.fire(.sendSuccess)
                    }
                }

                Section("时间线") {
                    if let customer {
                        LabeledContent("消息数", value: "\(engine.messages(for: conversationID).count)")
                        LabeledContent("进入时间", value: DateFormatter.localizedString(from: customer.enteredAt, dateStyle: .short, timeStyle: .short))
                        LabeledContent("最近消息", value: DateFormatter.localizedString(from: customer.lastActiveAt, dateStyle: .short, timeStyle: .short))
                    }
                }
            }
            .navigationTitle("客户资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
            .onAppear(perform: load)
        }
        .preferredColorScheme(.dark)
    }

    private func remarkRow(index: Int, placeholder: String, text: Binding<String>, onConfirm: @escaping () -> Void) -> some View {
        HStack {
            TextField(placeholder, text: text)
            Button("确定", action: onConfirm)
                .buttonStyle(.borderedProminent)
        }
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
