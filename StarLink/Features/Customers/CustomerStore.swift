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

    /// 聊天头部 tag chips（非空项）
    var headerTags: [String] {
        var tags: [String] = []
        if let no = sourceCodeNo, let remark = sourceCodeRemark {
            tags.append("\(no) · \(remark)")
        } else if let remark = sourceCodeRemark {
            tags.append(remark)
        }
        if let rc = regionCarrier { tags.append(rc) }
        if let extra = extraTag { tags.append(extra) }
        return tags
    }
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

    /// 资料页编辑（额度/地区/备注）
    func updateProfile(customerID: String, modify: (inout Customer) -> Void) {
        guard let index = customers.firstIndex(where: { $0.id == customerID }) else { return }
        modify(&customers[index])
        customers[index].lastActiveAt = Date()
        persist()
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
