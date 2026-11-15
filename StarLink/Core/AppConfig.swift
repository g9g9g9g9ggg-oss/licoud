import Foundation

/// 全局配置（设计书 1.4）
enum AppConfig {
    /// 本地 mock 开关：后台测试环境确认并经负责人同意后改 false（任务书 0.4）
    static let useMockServices = true

    /// 工作台 API 地址（2026-11-15 由占位符替换为生产主域；备域 9888.258766.lol / 988888.258766.lol）
    static let apiBaseURL = URL(string: "https://258766.lol")!
}
