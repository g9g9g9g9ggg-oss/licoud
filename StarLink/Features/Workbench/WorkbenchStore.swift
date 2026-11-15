import Foundation
import Observation
import UIKit

/// 工作台 Mock 存储（@Observable）：演示期数据全部本地持久化（UserDefaults JSON）
/// 第二期接 workspace 接口族时，把各 CRUD 换成网络调用即可，视图层不动
@Observable
final class WorkbenchStore {
    static let shared = WorkbenchStore()

    // MARK: - 状态

    var welcomeText: String = ""
    var welcomeEnabled: Bool = true
    var qrSlots: [QRSlot] = []
    var quickTexts: [QuickText] = []
    var libraryImages: [LibraryImage] = []
    /// 快捷图片栏（图库的引用子集；点 = 直接发送）
    var quickImages: [LibraryImage] = []
    var intents: [WorkbenchIntent] = []

    /// 快捷图片选中的临时记录（最近一次发送去向，用于轻提示）
    private(set) var lastQuickSendNote: String?

    private let defaultsKey = "workbench.mock.v1"
    private let defaults: UserDefaults

    // MARK: - Init / 持久化

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: defaultsKey),
           let state = try? JSONDecoder().decode(PersistedState.self, from: data) {
            welcomeText = state.welcomeText
            welcomeEnabled = state.welcomeEnabled
            qrSlots = state.qrSlots
            quickTexts = state.quickTexts
            libraryImages = state.libraryImages
            quickImages = state.quickImages
            intents = state.intents
        } else {
            seedIfNeeded()
            persist()
        }
    }

    private struct PersistedState: Codable {
        var welcomeText: String
        var welcomeEnabled: Bool
        var qrSlots: [QRSlot]
        var quickTexts: [QuickText]
        var libraryImages: [LibraryImage]
        var quickImages: [LibraryImage]
        var intents: [WorkbenchIntent]
    }

    func persist() {
        let state = PersistedState(
            welcomeText: welcomeText,
            welcomeEnabled: welcomeEnabled,
            qrSlots: qrSlots,
            quickTexts: quickTexts,
            libraryImages: libraryImages,
            quickImages: quickImages,
            intents: intents
        )
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: defaultsKey)
        }
    }

    /// Mock 种子（首次启动）：与聊天种子 TEST_ 张三/李四同一世界观
    private func seedIfNeeded() {
        if welcomeText.isEmpty {
            welcomeText = "您好，欢迎咨询星链！很高兴为您服务，请问有什么可以帮您？"
        }
        if qrSlots.isEmpty {
            let now = Date()
            qrSlots = [
                QRSlot(
                    id: "online",
                    title: "在线客服码",
                    content: QRSlotContent(
                        url: "https://kf.starlink.demo/online/001",
                        note: "线上主推码",
                        expiresAt: now.addingTimeInterval(7 * 24 * 3600),
                        isDisabled: false,
                        boundPeerName: "TEST_张三"
                    )
                ),
                QRSlot(
                    id: "offline",
                    title: "不在线客服码",
                    content: QRSlotContent(
                        url: "https://kf.starlink.demo/offline/001",
                        note: "非工作时段",
                        expiresAt: now.addingTimeInterval(30 * 3600),
                        isDisabled: false,
                        boundPeerName: "TEST_李四"
                    )
                ),
            ]
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

    // MARK: - 欢迎语

    func updateWelcome(text: String, enabled: Bool) {
        welcomeText = text
        welcomeEnabled = enabled
        persist()
    }

    // MARK: - 客服码

    /// 「生产」：重新出码（新 URL + 7 天有效期）
    func produceCode(slotID: String) {
        guard let index = qrSlots.firstIndex(where: { $0.id == slotID }) else { return }
        let token = UUID().uuidString.prefix(8)
        let isOnline = qrSlots[index].id == "online"
        let bound = qrSlots[index].content?.boundPeerName ?? (isOnline ? "TEST_张三" : "TEST_李四")
        qrSlots[index].content = QRSlotContent(
            url: "https://kf.starlink.demo/\(qrSlots[index].id)/\(token)",
            note: qrSlots[index].content?.note ?? "",
            expiresAt: Date().addingTimeInterval(7 * 24 * 3600),
            isDisabled: false,
            boundPeerName: bound
        )
        persist()
    }

    func updateSlotContent(slotID: String, modify: (inout QRSlotContent) -> Void) {
        guard let index = qrSlots.firstIndex(where: { $0.id == slotID }),
              var content = qrSlots[index].content else { return }
        modify(&content)
        qrSlots[index].content = content
        persist()
    }

    func deleteCode(slotID: String) {
        if let index = qrSlots.firstIndex(where: { $0.id == slotID }) {
            qrSlots[index].content = nil
        }
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

    /// 上移 / 下移（长按菜单排序）
    func moveQuickText(id: String, offset: Int) {
        guard let index = quickTexts.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard quickTexts.indices.contains(target) else { return }
        quickTexts.swapAt(index, target)
        persist()
    }

    // MARK: - 本地图库

    func libraryImage(named name: String) -> LibraryImage? {
        libraryImages.first { $0.name == name }
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

    /// 程序化占位图：渐变底 + 符号 + 名称（128pt）
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
                UIColor.white.withAlphaComponent(0.9).setFill()
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
