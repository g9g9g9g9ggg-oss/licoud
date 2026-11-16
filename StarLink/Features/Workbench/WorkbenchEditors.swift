import SwiftUI
import UIKit

// 工作台（码池）编辑器三件套：欢迎语 / 快捷文字 / 本地图库选择

/// 欢迎语编辑（设计①）：TextField axis vertical + 字数计数（x/1000）+ 保存
struct WelcomeEditView: View {
    @Environment(HapticService.self) private var haptics
    private var store: WorkbenchStore { WorkbenchStore.shared }

    @State private var text = ""
    @State private var enabled = true

    private var isValid: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= 1000 }

    var body: some View {
        Form {
            Section {
                TextField("欢迎语内容", text: $text, axis: .vertical)
                    .lineLimit(3...6)
            } footer: {
                HStack {
                    Spacer()
                    Text("\(text.count) / 1000")
                        .foregroundStyle(text.count > 1000 ? Color.red : .secondary)
                }
            }
            Section {
                Toggle("启用欢迎语", isOn: $enabled)
            }
        }
        .navigationTitle("欢迎语")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            text = store.welcomeText
            enabled = store.welcomeEnabled
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    store.updateWelcome(text: text, enabled: enabled)
                    haptics.fire(.sendSuccess)
                }
                .disabled(!isValid)
            }
        }
    }
}

/// 快捷文字编辑（新建 / 编辑复用；按 store.editingQuickTextID 载入）
struct QuickTextEditorView: View {
    @Environment(HapticService.self) private var haptics
    private var store: WorkbenchStore { WorkbenchStore.shared }

    @State private var editingID: String?
    @State private var title = ""
    @State private var content = ""
    @State private var loaded = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("标题（列表展示）") {
                TextField("例如：您好", text: $title)
            }
            Section("内容（点按后填入会话输入框）") {
                TextField("完整内容", text: $content, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
        .navigationTitle("快捷文字")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            if let id = store.editingQuickTextID,
               let existing = store.quickTexts.first(where: { $0.id == id }) {
                editingID = existing.id
                title = existing.title
                content = existing.content
            }
            loaded = true
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    store.saveQuickText(QuickText(
                        id: editingID ?? UUID().uuidString,
                        title: title,
                        content: content
                    ))
                    haptics.fire(.sendSuccess)
                }
                .disabled(!isValid)
            }
        }
    }
}

/// 本地图库选择（设计④＋）：网格 3 列单选，选中即加入快捷图片栏
struct ImageLibPickerView: View {
    @Environment(HapticService.self) private var haptics
    private var store: WorkbenchStore { WorkbenchStore.shared }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Metrics.spacing12)], spacing: Metrics.spacing12) {
                ForEach(store.libraryImages) { image in
                    Button {
                        store.addQuickImage(image)
                        haptics.fire(.toggleChanged)
                    } label: {
                        VStack(spacing: Metrics.spacing4) {
                            if let uiImage = UIImage(data: image.imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            Text(image.name).font(.caption2).foregroundStyle(.secondary)
                        }
                        .overlay(alignment: .topTrailing) {
                            if store.quickImages.contains(where: { $0.id == image.id }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.starlinkAccent)
                                    .padding(4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Metrics.spacing16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("本地图库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") {}
            }
        }
    }
}
