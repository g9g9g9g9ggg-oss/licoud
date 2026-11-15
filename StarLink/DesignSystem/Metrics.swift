import CoreGraphics

/// 间距与圆角档位（设计书 3.5）：禁止使用档位之外的值
enum Metrics {
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24

    /// 气泡圆角（对照系统 Messages 比例）
    static let cornerRadiusBubble: CGFloat = 18
    static let cornerRadiusButton: CGFloat = 12
    static let cornerRadiusCard: CGFloat = 10

    static let buttonHeight: CGFloat = 50
}
