import PhotosUI
import SwiftUI
import UIKit

/// 输入栏（设计书 6.1）：safeAreaInset 挂底部随键盘升降，跟手不跳变
struct ChatInputBar: View {
    @Binding var draft: String
    var onSend: () -> Void
    var onPickImage: (Data) -> Void = { _ in }
    var onPlus: () -> Void = {}

    @State private var photoSelection: PhotosPickerItem?

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Metrics.spacing8) {
            PhotosPicker(selection: $photoSelection, matching: .images) {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(Metrics.spacing4)
            }
            .accessibilityLabel("选择图片")
            .onChange(of: photoSelection) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        onPickImage(data)  // 直接发送；TODO(第二期): 发送前预览确认页
                    }
                    photoSelection = nil
                }
            }

            TextField("消息", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(Metrics.spacing8)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.cornerRadiusCard, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )

            // ➕（像微信一样）：快捷文字 / 快捷图片 / 关键词回复 / 欢迎语
            Button(action: onPlus) {
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("更多功能")

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? Color.starlinkAccent : Color.secondary)
            }
            .disabled(!canSend)
            .accessibilityLabel("发送")
        }
        .padding(.horizontal, Metrics.spacing12)
        .padding(.vertical, Metrics.spacing8)
        .background(.regularMaterial)
    }
}
