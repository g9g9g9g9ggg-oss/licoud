import SwiftUI
import UIKit

/// 我的页（设计书 4.4）：Form 分组 + 登出确认
struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @State private var showsLogoutDialog = false

    var body: some View {
        List {
            Section {
                HStack(spacing: Metrics.spacing12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.starlinkAccent)
                    VStack(alignment: .leading, spacing: Metrics.spacing4) {
                        Text(session.currentUser?.name ?? "未登录")
                            .font(.headline)
                        Text(session.currentUser?.role ?? "-")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, Metrics.spacing4)
            }

            Section("通用") {
                LabeledContent("提示音") {
                    Text("第三期开放").foregroundStyle(.tertiary)
                }
                LabeledContent("免打扰") {
                    Text("第三期开放").foregroundStyle(.tertiary)
                }
            }

            Section("关于") {
                LabeledContent("版本", value: Self.versionText)
                LabeledContent("设备", value: Self.deviceText)
            }

            Section {
                Button(role: .destructive) {
                    showsLogoutDialog = true
                } label: {
                    Text("退出登录")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.red)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("logout-button")
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.large)
        .alert("确认退出登录？", isPresented: $showsLogoutDialog) {
            Button("退出登录", role: .destructive) {
                session.logout()
            }
            .accessibilityIdentifier("logout-confirm")
            Button("取消", role: .cancel) {}
        }
    }

    private static var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private static var deviceText: String {
        "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)"
    }
}
