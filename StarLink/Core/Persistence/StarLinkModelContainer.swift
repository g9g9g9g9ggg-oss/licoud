import SwiftData

/// SwiftData 容器（第二期预写；测试用 inMemory）
enum StarLinkModelContainer {
    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(
                for: Conversation.self, Message.self,
                configurations: configuration
            )
        } catch {
            // 容器配置错误属于开发期问题，直接崩溃暴露
            fatalError("ModelContainer 创建失败: \(error)")
        }
    }
}
