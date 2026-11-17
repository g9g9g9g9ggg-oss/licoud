import Foundation
import Observation

// 客户体系（机主参考 STARLINK MATRIX 客户2650/资料页）：客户扫码 → 生成客户 + 简短会话
// 不加好友；标签（来源码/地区·运营商）挂在客户上，会话列表与聊天头部引用
// 演示期 Mock 本地持久化；对接后端时换 Store 实现

/// 客户（扫码进入的访客；与会话 peerID 同一体系）
struct Customer: Codable, Identifiable, Equatable {
    let id: String                 // = 会话 peerID
    var name: String               // 客户2650
    var sourceCodeRemark: String?  // 来源二维码备注（tag chip：绿）
    var sourceCodeNo: String?      // 码编号（tag chip：红 45646）
    var regionCarrier: String?     // 地区·运营商（tag chip：蓝 云南玉溪·移动）
    var extraTag: String?          // 附加 tag（紫 4563）
    var quota: String?             // 额度（如：2.5万 / 500U / 待定）
    var regionManual: String?      // 地区（手动填写：广东·深圳）
    var remarks: [String]          // 备注 / 备注+1 / 备注+2
    var device: String             // 手机 · Safari (iOS)
    var ip: String
    var isOnline: Bool
    var onlineSince: Date?
    var enteredAt: Date
    var lastActiveAt: Date
    /// 改动记录（谁改的 / 改了什么 / 何时），最新在前，封顶 20 条
    var changeLog: [ChangeEntry] = []

    /// 聊天头部 tag chips（非空项；额度/手填地区来自资料卡 → 全局同步展示）
    var headerTags: [String] {
        var tags: [String] = []
        if let no = sourceCodeNo, let remark = sourceCodeRemark {
            tags.append("\(no) · \(remark)")
        } else if let remark = sourceCodeRemark {
            tags.append(remark)
        }
        if let rc = regionCarrier { tags.append(rc) }
        if let extra = extraTag { tags.append(extra) }
        if let manual = regionManual, !manual.isEmpty { tags.append(manual) }
        if let q = quota, !q.isEmpty { tags.append("额度 \(q)") }
        return tags
    }
}

/// 资料卡改动记录（谁改的）
struct ChangeEntry: Codable, Identifiable, Equatable {
    let id: String
    var field: String        // 码名 / 额度 / 地区 / 备注 / 备注+1 / 备注+2
    var oldValue: String
    var newValue: String
    var editor: String       // 改动人（客服名）
    var date: Date
}

/// 客户存储（@Observable）
@Observable
final class CustomerStore {
    static let shared = CustomerStore()

    var customers: [Customer] = []

    private let defaultsKey = "customers.v1"
    private let defaults: UserDefaults

    /// 地区·运营商 mock 池（参考图）
    private static let regionPool: [(String, String)] = [
        ("云南玉溪", "移动"), ("云南玉溪", "电信"), ("广东广州", "中国电信"),
        ("广东深圳", "移动"), ("浙江杭州", "联通"), ("上海", "移动"),
    ]
    private static let extraTagPool = ["4563", "8888", "4563"]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: defaultsKey),
           let state = try? JSONDecoder().decode([Customer].self, from: data) {
            customers = state
        }
    }

    func persist() {
        if let data = try? JSONEncoder().encode(customers) {
            defaults.set(data, forKey: defaultsKey)
        }
    }

    // MARK: - 扫码进入（模拟；对接后由码池后端 webhook 触发）

    /// 客户扫码：生成客户 + 返回（会话由引擎按 peerID 创建）
    @MainActor
    func customerScans(code: PoolCode) -> Customer {
        // 已有该码来源的客户 → 复用（同一客户重复扫码）
        if let existing = customers.first(where: { $0.sourceCodeRemark == code.remark && $0.sourceCodeNo == code.codeNo }) {
            updateOnline(customerID: existing.id, online: true)
            return existing
        }
        let serial = Int.random(in: 2600...8999)
        let region = Self.regionPool.randomElement()!
        let customer = Customer(
            id: String(Int.random(in: 10000...99999)),
            name: "客户\(serial)",
            sourceCodeRemark: code.remark,
            sourceCodeNo: code.codeNo,
            regionCarrier: "\(region.0)·\(region.1)",
            extraTag: Self.extraTagPool.randomElement(),
            quota: nil,
            regionManual: nil,
            remarks: [],
            device: "手机 · Safari (iOS)",
            ip: "\(Int.random(in: 100...223)).\(Int.random(in: 0...255)).\(Int.random(in: 0...255)).\(Int.random(in: 1...254))",
            isOnline: true,
            onlineSince: Date(),
            enteredAt: Date(),
            lastActiveAt: Date()
        )
        customers.append(customer)
        persist()
        return customer
    }

    func updateOnline(customerID: String, online: Bool) {
        guard let index = customers.firstIndex(where: { $0.id == customerID }) else { return }
        customers[index].isOnline = online
        if online { customers[index].onlineSince = customers[index].onlineSince ?? Date() }
        else { customers[index].onlineSince = nil }
        persist()
    }

    func customer(forPeerID peerID: String) -> Customer? {
        customers.first { $0.id == peerID }
    }

    /// 资料页逐项改动（记录改动人 / 前后值 / 时间）
    func updateProfile(customerID: String, editor: String, field: String, oldValue: String, newValue: String) {
        guard let index = customers.firstIndex(where: { $0.id == customerID }) else { return }
        let entry = ChangeEntry(
            id: UUID().uuidString,
            field: field,
            oldValue: oldValue,
            newValue: newValue,
            editor: editor,
            date: Date()
        )
        switch field {
        case "码名":
            customers[index].name = newValue
        case "额度":
            customers[index].quota = newValue
        case "地区":
            customers[index].regionManual = newValue
        case "备注":
            customers[index].remarks = [newValue, remarkAt(customerID, 1), remarkAt(customerID, 2)]
        case "备注+1":
            customers[index].remarks = [remarkAt(customerID, 0), newValue, remarkAt(customerID, 2)]
        case "备注+2":
            customers[index].remarks = [remarkAt(customerID, 0), remarkAt(customerID, 1), newValue]
        default:
            break
        }
        customers[index].changeLog.insert(entry, at: 0)
        if customers[index].changeLog.count > 20 {
            customers[index].changeLog.removeLast(customers[index].changeLog.count - 20)
        }
        customers[index].lastActiveAt = Date()
        persist()
    }

    private func remarkAt(_ customerID: String, _ index: Int) -> String {
        guard let customer = customers.first(where: { $0.id == customerID }),
              customer.remarks.indices.contains(index) else { return "" }
        return customer.remarks[index]
    }

    /// 资料卡商务文本（一键复制用：完整 · 简洁 · 高档）
    func profileCardText(_ customer: Customer, messageCount: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        var lines: [String] = []
        lines.append("━━━━━━━━━━━━━━━━━━")
        lines.append("　　星链 · 客户资料卡")
        lines.append("━━━━━━━━━━━━━━━━━━")
        lines.append("客户名称：\(customer.name)")
        if let no = customer.sourceCodeNo, let remark = customer.sourceCodeRemark {
            lines.append("来源二维码：\(no)（\(remark)）")
        }
        lines.append("设备：\(customer.device)")
        lines.append("IP：\(customer.ip)")
        if let carrier = customer.regionCarrier { lines.append("地区·运营商：\(carrier)") }
        if let manual = customer.regionManual, !manual.isEmpty { lines.append("地区（手填）：\(manual)") }
        if let quota = customer.quota, !quota.isEmpty { lines.append("额度：\(quota)") }
        let remarks = customer.remarks.enumerated().compactMap { index, text -> String? in
            guard !text.isEmpty else { return nil }
            return "备注\(index == 0 ? "" : "+\(index)")：\(text)"
        }
        lines.append(contentsOf: remarks)
        lines.append("消息数：\(messageCount)")
        lines.append("进入时间：\(formatter.string(from: customer.enteredAt))")
        lines.append("最近消息：\(formatter.string(from: customer.lastActiveAt))")
        lines.append("━━━━━━━━━━━━━━━━━━")
        lines.append("星链商务接待 · 资料卡")
        return lines.joined(separator: "\n")
    }

    /// 消息数计数（引擎在收到/发送时调用）
    func bumpMessageCount(customerID: String) {
        guard let index = customers.firstIndex(where: { $0.id == customerID }) else { return }
        customers[index].lastActiveAt = Date()
    }
}

extension WorkbenchStore {
    /// 领取序号（mock 码编号基准）：按领取时间在 codes 中的位置
    var claimOrdinal: Int { codes.count }
}
