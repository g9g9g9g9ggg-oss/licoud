import Foundation
import Observation
import UIKit

/// 码池存储（@Observable）：演示期数据本地持久化（UserDefaults JSON v2）
/// 「以后对接码池（后端分发链接）」时仅替换本类实现，视图层不动
@Observable
final class WorkbenchStore {
    static let shared = WorkbenchStore()

    // MARK: - 码池

    /// 码池全部二维码（含有效中 / 锁定期 / 已失效）
    var codes: [PoolCode] = []
    /// 码池余量（对接后端后由码池下发；mock 660 起，领取即扣）
    private(set) var poolRemaining: Int = 660
    /// 累计客户（mock）
    private(set) var totalCustomers: Int = 15

    // MARK: - 快捷素材 / 触发 / 欢迎语

    var welcomeText: String = ""
    var welcomeEnabled: Bool = true
    var quickTexts: [QuickText] = []
    var libraryImages: [LibraryImage] = []
    /// 快捷图片栏（图库的引用子集；点 = 直接发送）
    var quickImages: [LibraryImage] = []
    var intents: [WorkbenchIntent] = []

    /// 编辑中的快捷文字（列表「编辑」入口传递）
    var editingQuickTextID: String?

    private(set) var lastQuickSendNote: String?

    private let defaultsKey = "workbench.pool.v2"
    private let legacyKey = "workbench.mock.v1"
    private let defaults: UserDefaults

    // MARK: - Init / 持久化

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: defaultsKey),
           let state = try? JSONDecoder().decode(PersistedState.self, from: data) {
            codes = state.codes
            poolRemaining = state.poolRemaining
            totalCustomers = state.totalCustomers
            welcomeText = state.welcomeText
            welcomeEnabled = state.welcomeEnabled
            quickTexts = state.quickTexts
            libraryImages = state.libraryImages
            quickImages = state.quickImages
            intents = state.intents
        } else if let data = defaults.data(forKey: legacyKey),
                  let legacy = try? JSONDecoder().decode(LegacyState.self, from: data) {
            // v1（旧工作台双码槽）→ v2（码池）：迁移快捷素材与意图，码槽废弃
            welcomeText = legacy.welcomeText
            welcomeEnabled = legacy.welcomeEnabled
            quickTexts = legacy.quickTexts
            libraryImages = legacy.libraryImages
            quickImages = legacy.quickImages
            intents = legacy.intents
            seedIfNeeded()
            persist()
        } else {
            seedIfNeeded()
            persist()
        }
        purgeExpiredLocks()
    }

    /// v1 遗留结构（qrSlots 不迁移；JSONDecoder 忽略 JSON 中的多余键）
    private struct LegacyState: Codable {
        var welcomeText: String
        var welcomeEnabled: Bool
        var quickTexts: [QuickText]
        var libraryImages: [LibraryImage]
        var quickImages: [LibraryImage]
        var intents: [WorkbenchIntent]
    }

    private struct PersistedState: Codable {
        var codes: [PoolCode]
        var poolRemaining: Int
        var totalCustomers: Int
        var welcomeText: String
        var welcomeEnabled: Bool
        var quickTexts: [QuickText]
        var libraryImages: [LibraryImage]
        var quickImages: [LibraryImage]
        var intents: [WorkbenchIntent]
    }

    func persist() {
        let state = PersistedState(
            codes: codes,
            poolRemaining: poolRemaining,
            totalCustomers: totalCustomers,
            welcomeText: welcomeText,
            welcomeEnabled: welcomeEnabled,
            quickTexts: quickTexts,
            libraryImages: libraryImages,
            quickImages: quickImages,
            intents: intents
        )
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: defaultsKey)
        }
    }

    /// Mock 种子（首次启动）：零码空池，与机主参考图 1 的空态一致
    private func seedIfNeeded() {
        if welcomeText.isEmpty {
            welcomeText = "您好，欢迎咨询星链！很高兴为您服务，请问有什么可以帮您？"
        }
        if quickTexts.isEmpty {
            let seeds = [
                ("您好，请问有什么可以帮您？", "您好，请问有什么可以帮您？"),
                ("稍等，我查一下", "稍等，我马上帮您查一下相关记录。"),
                ("这个问题我来跟进", "这个问题我来跟进，处理好了第一时间同步您。"),
                ("感谢耐心等待", "感谢您的耐心等待～"),
            ]
            quickTexts = seeds.map { QuickText(id: UUID().uuidString, title: $0.0, content: $0.1) }
        }
        if libraryImages.isEmpty {
            libraryImages = MockImageLibrary.defaultLibrary()
        }
        if quickImages.isEmpty {
            quickImages = Array(libraryImages.prefix(2))
        }
        if intents.isEmpty {
            intents = [
                WorkbenchIntent(
                    id: UUID().uuidString,
                    name: "询价",
                    matchMode: .keyword,
                    isEnabled: true,
                    phrases: ["多少钱", "价格", "怎么收费"],
                    textReply: TextReply(isEnabled: true, content: "我们的报价会根据方案细节给您一份明细，稍后发您～"),
                    imageReply: ImageReply(isEnabled: false, imageNames: [])
                ),
                WorkbenchIntent(
                    id: UUID().uuidString,
                    name: "售后",
                    matchMode: .keyword,
                    isEnabled: true,
                    phrases: ["坏了", "出问题", "售后"],
                    textReply: TextReply(isEnabled: false, content: ""),
                    imageReply: ImageReply(isEnabled: true, imageNames: ["图库-流程图"])
                ),
            ]
        }
    }

    // MARK: - 码池统计

    var activeCodes: [PoolCode] { codes.filter { $0.displayState == .active } }
    var lockedCodes: [PoolCode] { codes.filter { $0.displayState == .locked } }
    var expiredCodes: [PoolCode] { codes.filter { $0.displayState == .expired } }

    // MARK: - 码池 CRUD

    /// 从码池领取一张新码（三步向导完成；扣余量）
    @discardableResult
    func claimCode(remark: String, style: QRCardStyle, badgeMode: QRBadgeMode, bottomText: String, logoMode: QRLogoMode) -> PoolCode? {
        guard poolRemaining > 0 else { return nil }
        let token = UUID().uuidString.prefix(8).lowercased()
        let code = PoolCode(
            id: UUID().uuidString,
            remark: remark,
            url: "https://pool.starlink.demo/c/\(token)",
            style: style,
            badgeMode: badgeMode,
            bottomText: bottomText,
            logoMode: logoMode,
            customers: 0,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(12 * 3600),  // 参考：有效期剩余 11时39分 ≈ 12h
            state: .active,
            lockedUntil: nil
        )
        codes.append(code)
        poolRemaining -= 1
        persist()
        return code
    }

    /// 有效期延长 +1 天
    func extendCode(id: String) {
        guard let index = codes.firstIndex(where: { $0.id == id }) else { return }
        let base = max(codes[index].expiresAt, Date())
        codes[index].expiresAt = base.addingTimeInterval(24 * 3600)
        if codes[index].state == .expired { codes[index].state = .active }
        persist()
    }

    /// 码名（备注）编辑
    func updateCodeRemark(id: String, remark: String) {
        guard let index = codes.firstIndex(where: { $0.id == id }) else { return }
        codes[index].remark = remark
        persist()
    }

    /// 更换新码：新分发链接 + 续期 12h + 清停用（旧链接立即失效）
    func regenerateCode(id: String) {
        guard let index = codes.firstIndex(where: { $0.id == id }) else { return }
        let token = UUID().uuidString.prefix(8).lowercased()
        codes[index].url = "https://pool.starlink.demo/c/\(token)"
        codes[index].expiresAt = Date().addingTimeInterval(12 * 3600)
        codes[index].isDisabled = false
        persist()
    }

    /// 停用 / 启用入口
    func setCodeDisabled(id: String, disabled: Bool) {
        guard let index = codes.firstIndex(where: { $0.id == id }) else { return }
        codes[index].isDisabled = disabled
        persist()
    }

    /// 删除 → 锁定期 7 天（不放回余量；锁定期结束自动消失）
    func lockCode(id: String) {
        guard let index = codes.firstIndex(where: { $0.id == id }) else { return }
        codes[index].state = .locked
        codes[index].lockedUntil = Date().addingTimeInterval(7 * 24 * 3600)
        persist()
    }

    /// 锁定期到期清理（读取时顺带执行）
    private func purgeExpiredLocks() {
        let now = Date()
        codes.removeAll { code in
            code.state == .locked && (code.lockedUntil ?? now) < now
        }
    }

    // MARK: - 欢迎语

    func updateWelcome(text: String, enabled: Bool) {
        welcomeText = text
        welcomeEnabled = enabled
        persist()
    }

    // MARK: - 快捷文字

    func saveQuickText(_ text: QuickText) {
        if let index = quickTexts.firstIndex(where: { $0.id == text.id }) {
            quickTexts[index] = text
        } else {
            quickTexts.append(text)
        }
        persist()
    }

    func deleteQuickText(id: String) {
        quickTexts.removeAll { $0.id == id }
        persist()
    }

    func moveQuickText(id: String, offset: Int) {
        guard let index = quickTexts.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard quickTexts.indices.contains(target) else { return }
        quickTexts.swapAt(index, target)
        persist()
    }

    // MARK: - 本地图库 / 快捷图片栏

    func libraryImage(named name: String) -> LibraryImage? {
        libraryImages.first { $0.name == name }
    }

    func addQuickImage(_ image: LibraryImage) {
        if !quickImages.contains(where: { $0.id == image.id }) {
            quickImages.append(image)
            persist()
        }
    }

    func removeQuickImage(id: String) {
        quickImages.removeAll { $0.id == id }
        persist()
    }

    // MARK: - 快捷发送（跨 Tab）

    /// 目标会话：当前打开的会话优先，否则取最近会话
    @MainActor
    private func resolveTargetConversationID() -> String? {
        let engine = ChatDemoEngine.shared
        return engine.activeConversationID ?? engine.conversations().first?.id
    }

    /// 快捷文字「点 = 填入防误触」：投递草稿箱并跳回消息 Tab
    @MainActor
    func fillQuickText(_ text: QuickText) -> Bool {
        guard resolveTargetConversationID() != nil else { return false }
        ChatDraftBox.shared.pendingText = text.content
        TabRouter.shared.selection = 0
        return true
    }

    /// 快捷图片「点 = 直接发送」：走现有发图通道
    @MainActor
    func sendQuickImage(_ image: LibraryImage) -> Bool {
        guard let target = resolveTargetConversationID() else { return false }
        let engine = ChatDemoEngine.shared
        let imageData = image.imageData
        Task { await engine.sendImage(rawData: imageData, in: target) }
        TabRouter.shared.selection = 0
        lastQuickSendNote = "已发送：\(image.name)"
        return true
    }

    // MARK: - 意图

    func addIntent(name: String) -> WorkbenchIntent {
        let intent = WorkbenchIntent(
            id: UUID().uuidString,
            name: name,
            matchMode: .keyword,
            isEnabled: true,
            phrases: [],
            textReply: TextReply(isEnabled: false, content: ""),
            imageReply: ImageReply(isEnabled: false, imageNames: [])
        )
        intents.append(intent)
        persist()
        return intent
    }

    func saveIntent(_ intent: WorkbenchIntent) {
        if let index = intents.firstIndex(where: { $0.id == intent.id }) {
            intents[index] = intent
        } else {
            intents.append(intent)
        }
        persist()
    }

    func toggleIntent(id: String, isEnabled: Bool) {
        guard let index = intents.firstIndex(where: { $0.id == id }) else { return }
        intents[index].isEnabled = isEnabled
        persist()
    }

    func deleteIntent(id: String) {
        intents.removeAll { $0.id == id }
        persist()
    }
}

/// 本地图库 mock 内容：程序化生成（零外部资源、零第三方依赖）
enum MockImageLibrary {
    static func defaultLibrary() -> [LibraryImage] {
        let seeds: [(name: String, colors: (UIColor, UIColor), symbol: String)] = [
            ("图库-欢迎", (UIColor(red: 0.36, green: 0.55, blue: 0.92, alpha: 1), UIColor(red: 0.20, green: 0.34, blue: 0.72, alpha: 1)), "hand.wave"),
            ("图库-报价单", (UIColor(red: 0.35, green: 0.72, blue: 0.58, alpha: 1), UIColor(red: 0.18, green: 0.48, blue: 0.36, alpha: 1)), "doc.text"),
            ("图库-流程图", (UIColor(red: 0.90, green: 0.55, blue: 0.35, alpha: 1), UIColor(red: 0.72, green: 0.38, blue: 0.20, alpha: 1)), "flowchart"),
            ("图库-售后通道", (UIColor(red: 0.62, green: 0.48, blue: 0.85, alpha: 1), UIColor(red: 0.42, green: 0.30, blue: 0.64, alpha: 1)), "headphones"),
        ]
        return seeds.map { seed in
            LibraryImage(id: UUID().uuidString, name: seed.name, imageData: render(colors: seed.colors, symbol: seed.symbol, label: seed.name))
        }
    }

    /// 程序化占位图：渐变底 + 符号 + 名称（256pt）
    private static func render(colors: (UIColor, UIColor), symbol: String, label: String) -> Data {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [colors.0.cgColor, colors.1.cgColor] as CFArray,
                locations: [0, 1]
            )!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 64, weight: .medium)
            if let symbol = UIImage(systemName: symbol, withConfiguration: symbolConfig) {
                let symbolRect = CGRect(x: (size.width - 72) / 2, y: 72, width: 72, height: 72)
                symbol.withTintColor(.white, renderingMode: .alwaysOriginal)
                    .draw(in: symbolRect)
            }
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            (label as NSString).draw(
                in: CGRect(x: 8, y: size.height - 64, width: size.width - 16, height: 48),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraph,
                ]
            )
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
}
