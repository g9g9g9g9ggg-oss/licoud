import Foundation

/// 全局配置（设计书 1.4）
enum AppConfig {
    /// 本地 mock 开关：后台测试环境确认并经负责人同意后改 false（任务书 0.4）
    static let useMockServices = true

    /// 后台测试环境地址（占位，待负责人提供后替换）
    static let apiBaseURL = URL(string: "https://TEST-ENV-PLACEHOLDER.invalid")!
}
