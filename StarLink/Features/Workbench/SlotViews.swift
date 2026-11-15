import SwiftUI
import UIKit

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

/// 快捷文字编辑（新建 / 编辑复用；无 id = 新建）
struct QuickTextEditorView: View {
    @Environment(HapticService.self) private var haptics
    private var store: WorkbenchStore { WorkbenchStore.shared }

    @State private var editingID: String?
    @State private var title = ""
    @State private var content = ""

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

/// 绑定客服（设计②编辑）：在线客服 / 不在线客服 两行 Picker
struct BindCustomerServiceView: View {
    @Environment(HapticService.self) private var haptics
    private var store: WorkbenchStore { WorkbenchStore.shared }

    @State private var onlineBound = ""
    @State private var offlineBound = ""

    var body: some View {
        Form {
            Section("在线客服码 · 绑定客服") {
                Picker("在线客服", selection: $onlineBound) {
                    ForEach(MockContacts.all, id: \.id) { contact in
                        Text(contact.name).tag(contact.name)
                    }
                }
            }
            Section("不在线客服码 · 绑定客服") {
                Picker("不在线客服", selection: $offlineBound) {
                    ForEach(MockContacts.all, id: \.id) { contact in
                        Text(contact.name).tag(contact.name)
                    }
                }
            }
        }
        .navigationTitle("编辑绑定客服")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            onlineBound = store.qrSlots.first(where: { $0.id == "online" })?.content?.boundPeerName ?? MockContacts.all[0].name
            offlineBound = store.qrSlots.first(where: { $0.id == "offline" })?.content?.boundPeerName ?? MockContacts.all[1].name
        }
        .onChange(of: onlineBound) { _, newValue in
            store.updateSlotContent(slotID: "online") { $0.boundPeerName = newValue }
        }
        .onChange(of: offlineBound) { _, newValue in
            store.updateSlotContent(slotID: "offline") { $0.boundPeerName = newValue }
            haptics.fire(.toggleChanged)
        }
    }
}

/// 出码后的备注编辑（单输入框 + 保存）
struct QRNoteEditView: View {
    let slotID: String

    @Environment(HapticService.self) private var haptics
    private var store: WorkbenchStore { WorkbenchStore.shared }

    @State private var note = ""

    private var slotTitle: String {
        store.qrSlots.first(where: { $0.id == slotID })?.title ?? "客服码"
    }

    var body: some View {
        Form {
            Section("备注（\(slotTitle)）") {
                TextField("例如：线上主推码", text: $note)
            }
        }
        .navigationTitle("备注")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            note = store.qrSlots.first(where: { $0.id == slotID })?.content?.note ?? ""
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    store.updateSlotContent(slotID: slotID) { $0.note = note }
                    haptics.fire(.sendSuccess)
                }
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
                        if !store.quickImages.contains(where: { $0.id == image.id }) {
                            store.quickImages.append(image)
                            store.persist()
                            haptics.fire(.toggleChanged)
                        }
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
