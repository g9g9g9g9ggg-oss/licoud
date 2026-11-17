import SwiftUI

/// 工作台页内路由
enum IntentFocus: Hashable {
    case text
    case image
}

enum WorkbenchRoute: Hashable {
    case intentList(IntentFocus)
}

/// ⑤⑥ 共用意图管理页入口：进入后对应回复类型排前
struct IntentListView: View {
    let focus: IntentFocus
    private var store: WorkbenchStore { WorkbenchStore.shared }

    @Environment(HapticService.self) private var haptics
    @State private var showsNewIntentAlert = false
    @State private var newIntentName = ""
    /// 确定性导航：选中意图 → push 详情（不依赖 List NavigationLink 命中）
    @State private var selectedIntent: SelectedIntent?

    /// 焦点回复类型排前；同组内启用中的排前
    private var ordered: [WorkbenchIntent] {
        let intents = store.intents
        return intents.sorted { a, b in
            let aFocus = focusWeight(a)
            let bFocus = focusWeight(b)
            if aFocus != bFocus { return aFocus < bFocus }
            if a.isEnabled != b.isEnabled { return a.isEnabled }
            return a.name < b.name
        }
    }

    private func focusWeight(_ intent: WorkbenchIntent) -> Int {
        let active: Bool
        switch focus {
        case .text: active = intent.textReply.isEnabled
        case .image: active = intent.imageReply.isEnabled
        }
        return active ? 0 : 1
    }

    var body: some View {
        List {
            if store.intents.isEmpty {
                ContentUnavailableView("暂无意图", systemImage: "text.badge.plus", description: Text("点右上「＋」新建第一个意图"))
                    .listRowBackground(Color.clear)
            }
            ForEach(ordered) { intent in
                HStack(spacing: Metrics.spacing8) {
                    Button {
                        selectedIntent = SelectedIntent(intentID: intent.id)
                    } label: {
                        HStack(spacing: Metrics.spacing8) {
                            Text(intent.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(intent.matchMode.title)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { intent.isEnabled },
                        set: { newValue in
                            store.toggleIntent(id: intent.id, isEnabled: newValue)
                            haptics.fire(.toggleChanged)
                        }
                    ))
                    .labelsHidden()
                    .fixedSize()
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    store.deleteIntent(id: ordered[index].id)
                }
            }
        }
        .navigationTitle("提示词触发")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showsNewIntentAlert = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("新建意图")
        }
        .alert("新建意图", isPresented: $showsNewIntentAlert) {
            TextField("意图名称", text: $newIntentName)
            Button("创建") {
                let name = newIntentName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                _ = store.addIntent(name: name)
                newIntentName = ""
                haptics.fire(.toggleChanged)
            }
            Button("取消", role: .cancel) { newIntentName = "" }
        } message: {
            Text("新建后进入意图详情配置说法与回复。")
        }
        .navigationDestination(item: Binding(
            get: { selectedIntent },
            set: { selectedIntent = $0 }
        )) { target in
            IntentDetailView(intentID: target.intentID, focus: focus)
        }
    }
}

/// navigationDestination(item:) 载体
struct SelectedIntent: Identifiable, Hashable {
    let id = UUID()
    let intentID: String
}

/// 意图详情：说法区（本地攒着、一次保存）+ 文字/图片回复区 + match_mode
struct IntentDetailView: View {
    let intentID: String
    let focus: IntentFocus

    @Environment(HapticService.self) private var haptics
    private var store: WorkbenchStore { WorkbenchStore.shared }

    // 本地草稿（说法攒着一次保存）
    @State private var phrases: [String] = []
    @State private var name: String = ""
    @State private var matchMode: MatchMode = .keyword
    @State private var textEnabled = false
    @State private var textContent = ""
    @State private var imageEnabled = false
    @State private var imageNames: [String] = []
    @State private var showsDiscardAlert = false
    @State private var loaded = false

    private var isDirty: Bool {
        guard let intent = store.intents.first(where: { $0.id == intentID }) else { return false }
        return intent.phrases != phrases
            || intent.name != name
            || intent.matchMode != matchMode
            || intent.textReply != TextReply(isEnabled: textEnabled, content: textContent)
            || intent.imageReply != ImageReply(isEnabled: imageEnabled, imageNames: imageNames)
    }

    var body: some View {
        Form {
            Section("意图") {
                TextField("意图名称", text: $name)
                Picker("匹配方式", selection: $matchMode) {
                    ForEach(MatchMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .disabled(true) // semantic/ai 即将上线；keyword 为当前唯一可用项
            }

            Section {
                ForEach(phrases.indices, id: \.self) { index in
                    HStack(spacing: Metrics.spacing8) {
                        TextField("说法 \(index + 1)", text: Binding(
                            get: { phrases[index] },
                            set: { phrases[index] = $0 }
                        ))
                        Button(role: .destructive) {
                            phrases.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button {
                    phrases.append("")
                } label: {
                    Label("新增说法", systemImage: "plus.circle")
                }
            } header: {
                Text("说法")
            } footer: {
                Text("说法增删只改本地，点「保存说法」一次性生效。")
            }

            Section("文字回复") {
                Toggle("启用文字回复", isOn: $textEnabled)
                if textEnabled {
                    TextEditor(text: $textContent)
                        .frame(minHeight: 72)
                    Text("\(textContent.count) / 1000")
                        .font(.caption2)
                        .foregroundStyle(textContent.count > 1000 ? Color.red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            Section {
                Toggle("启用图片回复", isOn: $imageEnabled)
                if imageEnabled {
                    ForEach(store.libraryImages) { image in
                        let isSelected = imageNames.contains(image.name)
                        let selectable = isSelected || imageNames.count < ImageReply.maxImages
                        HStack(spacing: Metrics.spacing8) {
                            if let uiImage = UIImage(data: image.imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            Text(image.name).font(.subheadline)
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? Color.starlinkAccent : Color(uiColor: .systemGray4))
                                .onTapGesture {
                                    guard selectable else { return }
                                    if isSelected {
                                        imageNames.removeAll { $0 == image.name }
                                    } else {
                                        imageNames.append(image.name)
                                    }
                                }
                        }
                        .opacity(selectable ? 1 : 0.4)
                    }
                    if imageNames.count >= ImageReply.maxImages {
                        Text("最多 \(ImageReply.maxImages) 张")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("图片回复")
            } footer: {
                Text("同一意图可同时启用文字与图片回复；命中时先文字后图片。")
            }
        }
        .navigationTitle(name.isEmpty ? "意图详情" : name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                } label: {
                    Text("保存").fontWeight(isDirty ? .semibold : .regular)
                }
                .disabled(!isDirty || textContent.count > 1000)
            }
        }
        .alert("放弃未保存的修改？", isPresented: $showsDiscardAlert) {}
    }

    private func load() {
        guard !loaded, let intent = store.intents.first(where: { $0.id == intentID }) else { return }
        name = intent.name
        matchMode = intent.matchMode
        phrases = intent.phrases
        textEnabled = intent.textReply.isEnabled
        textContent = intent.textReply.content
        imageEnabled = intent.imageReply.isEnabled
        imageNames = intent.imageReply.imageNames
        loaded = true
    }

    private func save() {
        guard let index = store.intents.firstIndex(where: { $0.id == intentID }) else { return }
        var intent = store.intents[index]
        intent.name = name
        intent.matchMode = matchMode
        intent.phrases = phrases.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        intent.textReply = TextReply(isEnabled: textEnabled, content: textContent)
        intent.imageReply = ImageReply(isEnabled: imageEnabled, imageNames: imageNames)
        store.saveIntent(intent)
        haptics.fire(.sendSuccess)
    }
}
