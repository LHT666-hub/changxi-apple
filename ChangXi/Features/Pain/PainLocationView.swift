import SwiftUI

enum PainVisual {
    static let accent = Color(red: 0.66, green: 0.36, blue: 0.34)
    static let accentSoft = Color(red: 0.66, green: 0.36, blue: 0.34).opacity(0.10)
    static let accentLine = Color(red: 0.66, green: 0.36, blue: 0.34).opacity(0.72)
    static let bodyTop = Color(red: 0.91, green: 0.94, blue: 0.95)
    static let bodyBottom = Color(red: 0.76, green: 0.82, blue: 0.85)
    static let guide = CX.actionPrimary.opacity(0.16)
}

/// Native body-sensation entry used by the health portrait and Health tab.
struct PainLocationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AssistantCoordinator.self) private var assistant
    @State private var journal = PainJournal()
    @State private var draft = PainRecord()
    @State private var step = 0
    @State private var angle = PainAngle.front
    @State private var kind = PainMarkKind.point
    @State private var saved = false
    @State private var error: String?
    @State private var history = false
    @State private var enlarged = false
    @State private var voiceLocation = false
    @State private var voiceHint: String?
    @State private var assistantContextID = UUID()

    private var title: String {
        switch step {
        case 0: "选择不适部位"
        case 1: "\(draft.region.rawValue) · 标注位置"
        case 2: "疼痛感觉和强度"
        default: "确认本次记录"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if step == 1 { markingHeader } else { header }
                if saved { success }
                else {
                    switch step {
                    case 0: regionGrid
                    case 1: location
                    case 2: descriptionForm
                    default: review
                    }
                    if step > 1 || (step == 1 && dynamicTypeSize.isAccessibilitySize) {
                        footer.padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: 680)
            .padding(20)
            .padding(.bottom, step == 1 && !saved && !dynamicTypeSize.isAccessibilitySize ? 172 : 24)
            .frame(maxWidth: .infinity)
            .id(step)
        }
        .cxMoonScreenBackground(illustrated: true)
        .navigationTitle("疼痛位置记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { history = true } label: { Image(systemName: "clock.arrow.circlepath") }
                    .accessibilityLabel("查看疼痛记录")
            }
        }
        .overlay(alignment: .bottom) {
            if step == 1 && !saved && !dynamicTypeSize.isAccessibilitySize {
                footer
                    .padding(.horizontal, 14)
                    .padding(.bottom, 82)
            }
        }
        .sheet(isPresented: $history) { NavigationStack { PainHistoryView(journal: journal) } }
        .sheet(isPresented: $voiceLocation) {
            NavigationStack {
                PainVoiceLocationView { region, selectedAngle, marks in
                    if draft.region != region && !draft.marks.isEmpty {
                        // Keep an existing region intact; voice suggestions cannot erase drawn marks.
                        error = "这次正在记录\(draft.region.rawValue)。请先保存已有标记，再新建\(region.rawValue)记录。"
                    } else {
                        draft.region = region
                        draft.marks.append(contentsOf: marks)
                        angle = selectedAngle
                        voiceHint = marks.last?.name
                        advance(1)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $enlarged) {
            NavigationStack {
                Page(illustrated: true) {
                    VStack(alignment: .leading, spacing: CXSpacing.xs) {
                        Text(draft.region.rawValue)
                            .font(CXTypography.micro.weight(.semibold))
                            .foregroundStyle(CX.actionPrimary)
                            .tracking(0.6)

                        Text("放大标记")
                            .font(CXTypography.display)

                        Text("在更大的轮廓上补充位置；返回后会保留这里的标记。")
                            .font(CXTypography.body)
                            .foregroundStyle(CX.muted)
                            .lineSpacing(5)
                    }

                    SectionEyebrow(title: "视角")
                    anglePicker

                    SectionEyebrow(title: "标记方式")
                    markToolPicker

                    PainMarkingSurface(
                        region: draft.region,
                        angle: angle,
                        kind: kind,
                        marks: $draft.marks
                    )

                    markHistoryActions
                }
                .navigationTitle("细标位置")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { enlarged = false }
                    }
                }
            }
        }
        .alert("暂时没有保存", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("返回核对", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
        .onAppear {
            assistant.register(id: assistantContextID, title: "身体感受记录", draft: draft.summary) { _ in false }
        }
        .onDisappear { assistant.unregister(id: assistantContextID) }
    }

    private var markingHeader: some View {
        VStack(alignment: .leading, spacing: CXSpacing.md) {
            HStack {
                Button {
                    advance(0)
                } label: {
                    Label(draft.region.rawValue, systemImage: "chevron.left")
                        .font(CXTypography.supporting.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(CX.actionPrimary)

                Spacer()

                Text("2 / 4")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.muted)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                ForEach(0..<4) { index in
                    Capsule()
                        .fill(index <= 1 ? CX.actionPrimary : CX.actionPrimary.opacity(0.10))
                        .frame(height: 5)
                }
            }
            .accessibilityLabel("第2步，共4步")

            Text("把疼的位置标出来")
                .font(CXTypography.display)

            Text("先选视角，再选标记方式。只需要画出你感觉到的位置，不需要懂解剖。")
                .font(CXTypography.body)
                .foregroundStyle(CX.muted)
                .lineSpacing(5)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CXSpacing.md) {
            HStack {
                Text("身体感受")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)

                Spacer()

                Text("\(step + 1) / 4")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.muted)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                ForEach(0..<4) { index in
                    Capsule()
                        .fill(index <= step ? CX.actionPrimary : CX.actionPrimary.opacity(0.10))
                        .frame(height: 5)
                }
            }
            .accessibilityLabel("第\(step + 1)步，共4步")

            Text(saved ? "这次感受，已经记下来了" : title)
                .font(CXTypography.display)
                .fixedSize(horizontal: false, vertical: true)

            Text(stepGuidance)
                .font(CXTypography.body)
                .foregroundStyle(CX.muted)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stepGuidance: String {
        switch step {
        case 0:
            "先选一个大致区域。下一步再在人体轮廓上标出更具体的位置，不需要一次选得很精确。"
        case 2:
            "位置记好以后，再描述疼痛的强度和感觉。位置与强度是两件不同的事。"
        case 3:
            "最后核对一次位置、感觉和时间；只有你点保存后，这次记录才会留在本机。"
        default:
            "按你的实际感受标记即可；画面只是帮助描述位置，不代表诊断。"
        }
    }

    private var regionGrid: some View {
        VStack(alignment: .leading, spacing: CXSpacing.lg) {
            VStack(spacing: CXSpacing.sm) {
                HStack(spacing: CXSpacing.xl) {
                    GentlePainFigure(region: nil, angle: .front)
                        .frame(width: 104, height: 188)
                    GentlePainFigure(region: nil, angle: .back)
                        .frame(width: 104, height: 188)
                }

                HStack(spacing: 34) {
                    Text("正面")
                    Text("背面")
                }
                .font(CXTypography.micro.weight(.semibold))
                .foregroundStyle(CX.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CXSpacing.md)
            .background(
                LinearGradient(
                    colors: [CX.surface.opacity(0.96), CX.moonlight.opacity(0.035)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: .rect(cornerRadius: CXRadius.lg, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CXRadius.lg, style: .continuous)
                    .strokeBorder(CX.separator.opacity(0.10), lineWidth: 0.5)
            }
            .accessibilityHidden(true)

            SectionEyebrow(title: "哪里不舒服", action: "先选大致区域")

            LazyVGrid(
                columns: CXLayout.adaptiveColumns(
                    minimum: 152,
                    spacing: CXSpacing.sm,
                    dynamicTypeSize: dynamicTypeSize
                ),
                spacing: CXSpacing.sm
            ) {
                ForEach(PainRegion.allCases) { region in
                    Button {
                        draft = PainRecord(region: region)
                        angle = region == .back ? .back : .front
                        advance(1)
                    } label: {
                        VStack(alignment: .leading, spacing: CXSpacing.sm) {
                            GentlePainFigure(
                                region: region,
                                angle: region == .back ? .back : .front
                            )
                            .frame(height: 104)
                            .frame(maxWidth: .infinity)
                            .background(CX.moonlight.opacity(0.035), in: .rect(cornerRadius: 16, style: .continuous))
                            .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(region.rawValue)
                                    .font(CXTypography.section)
                                    .foregroundStyle(CX.ink)

                                Text(regionHint(region))
                                    .font(CXTypography.meta)
                                    .foregroundStyle(CX.muted)
                            }

                            HStack {
                                Text("选择")
                                    .font(CXTypography.micro.weight(.semibold))
                                    .foregroundStyle(CX.actionPrimary)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(CX.faint)
                            }
                        }
                        .padding(CXSpacing.md)
                        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
                        .cxContentSurface(cornerRadius: CXRadius.md)
                        .contentShape(.rect(cornerRadius: CXRadius.md, style: .continuous))
                    }
                    .buttonStyle(QuietPressButton())
                    .accessibilityIdentifier("pain-region-\(region.anatomyAssetName)")
                }
            }

            Button { voiceLocation = true } label: {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: "waveform")
                        .foregroundStyle(CX.actionPrimary)
                        .frame(width: 42, height: 42)
                        .background(CX.actionPrimary.opacity(0.08), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("不确定区域？直接说给常曦听")
                            .font(CXTypography.section)
                        Text("例如“左边太阳穴一跳一跳地疼”")
                            .font(CXTypography.meta)
                            .foregroundStyle(CX.muted)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CX.faint)
                }
                .padding(CXSpacing.md)
                .cxContentSurface(cornerRadius: CXRadius.md)
            }
            .buttonStyle(QuietPressButton())
        }
    }

    private func regionSymbol(_ region: PainRegion) -> String {
        switch region {
        case .head: "person.crop.circle"
        case .neck: "figure.mind.and.body"
        case .torso: "figure.arms.open"
        case .back: "figure.walk"
        case .arms: "figure.strengthtraining.traditional"
        case .legs: "figure.run"
        }
    }

    private func regionHint(_ region: PainRegion) -> String {
        switch region {
        case .head: "头面、耳周"
        case .neck: "后颈、肩膀"
        case .torso: "胸口、腹部"
        case .back: "肩胛、腰背"
        case .arms: "手臂、手掌"
        case .legs: "髋腿、足部"
        }
    }

    private var anglePicker: some View {
        Picker("身体视角", selection: $angle) {
            ForEach(PainAngle.allCases) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented)
    }

    private var location: some View {
        VStack(alignment: .leading, spacing: CXSpacing.lg) {
            if let voiceHint {
                HStack(alignment: .top, spacing: CXSpacing.sm) {
                    Image(systemName: "waveform")
                        .foregroundStyle(CX.actionPrimary)
                        .frame(width: 34, height: 34)
                        .background(CX.actionPrimary.opacity(0.08), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("常曦先帮你标了“\(voiceHint)”")
                            .font(CXTypography.supporting.weight(.semibold))
                        Text("这只是建议位置，请在图上核对或调整。")
                            .font(CXTypography.meta)
                            .foregroundStyle(CX.muted)
                    }

                    Spacer(minLength: 0)
                }
                .padding(CXSpacing.md)
                .background(CX.actionPrimary.opacity(0.045), in: .rect(cornerRadius: CXRadius.md, style: .continuous))
            }

            VStack(alignment: .leading, spacing: CXSpacing.sm) {
                HStack {
                    SectionEyebrow(title: "从哪个方向看")

                    Spacer()

                    Button {
                        voiceLocation = true
                    } label: {
                        Label("说位置", systemImage: "waveform")
                            .font(CXTypography.meta.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CX.actionPrimary)
                }

                anglePicker
            }

            VStack(alignment: .leading, spacing: CXSpacing.sm) {
                SectionEyebrow(title: "怎么标")

                markToolPicker

                Text(kind.instruction)
                    .font(CXTypography.meta)
                    .foregroundStyle(CX.muted)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: kind)
            }

            VStack(alignment: .leading, spacing: CXSpacing.sm) {
                HStack {
                    SectionEyebrow(title: "标记位置", action: angle.rawValue)

                    Spacer()

                    Button {
                        enlarged = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .frame(width: 38, height: 38)
                            .background(CX.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CX.actionPrimary)
                    .accessibilityLabel("放大标记")
                }

                PainMarkingSurface(
                    region: draft.region,
                    angle: angle,
                    kind: kind,
                    marks: $draft.marks
                )
                .id(angle)
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: angle)
            }

            HStack(spacing: CXSpacing.sm) {
                let count = draft.marks.filter { $0.angle == angle && !$0.hasSurfaceLocation }.count

                Label(
                    count == 0 ? "这个视角还没标记" : "已标记 \(count) 处",
                    systemImage: count == 0 ? "hand.draw" : "checkmark.circle.fill"
                )
                .font(CXTypography.supporting.weight(.semibold))
                .foregroundStyle(count == 0 ? CX.muted : CX.statusPositive)

                Spacer()

                if !draft.marks.isEmpty {
                    Text("共 \(draft.marks.filter { !$0.hasSurfaceLocation }.count) 处")
                        .font(CXTypography.micro)
                        .foregroundStyle(CX.muted)
                }
            }

            markHistoryActions

            if draft.region == .head {
                landmarks
            }

            HStack(alignment: .top, spacing: CXSpacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundStyle(CX.actionPrimary)

                Text("左右以你自己的身体为准。这里记录的是你感觉到的位置，不代表疼痛来源或诊断。")
                    .font(CXTypography.meta)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(4)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, CXSpacing.xs)
        }
    }

    private var markToolPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CXSpacing.sm) {
                ForEach(PainMarkKind.allCases) { tool in
                    Button {
                        kind = tool
                    } label: {
                        HStack(spacing: 8) {
                            PainToolPreview(kind: tool)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tool.label)
                                    .font(CXTypography.supporting.weight(.semibold))
                                Text(toolShortHint(tool))
                                    .font(CXTypography.micro)
                                    .foregroundStyle(CX.muted)
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(minWidth: 124, minHeight: 58, alignment: .leading)
                        .background(
                            kind == tool ? PainVisual.accentSoft : CX.surface.opacity(0.88),
                            in: .rect(cornerRadius: 16, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    kind == tool ? PainVisual.accent.opacity(0.36) : CX.separator.opacity(0.10),
                                    lineWidth: kind == tool ? 1 : 0.5
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(kind == tool ? .isSelected : [])
                    .accessibilityHint(tool.instruction)
                    .accessibilityIdentifier("pain-tool-\(tool.label)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var markHistoryActions: some View {
        HStack(spacing: CXSpacing.sm) {
            Button {
                if let index = draft.marks.lastIndex(where: { $0.angle == angle && !$0.hasSurfaceLocation }) {
                    draft.marks.remove(at: index)
                }
            } label: {
                Label("撤销上一笔", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .disabled(!draft.marks.contains(where: { $0.angle == angle && !$0.hasSurfaceLocation }))

            Button(role: .destructive) {
                draft.marks.removeAll { $0.angle == angle && !$0.hasSurfaceLocation }
            } label: {
                Label("清空此面", systemImage: "eraser")
                    .font(CXTypography.supporting)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .tint(CX.muted)
            .disabled(!draft.marks.contains(where: { $0.angle == angle && !$0.hasSurfaceLocation }))
        }
    }

    private func toolShortHint(_ tool: PainMarkKind) -> String {
        switch tool {
        case .point: "轻点最疼处"
        case .area: "像涂色一样"
        case .line: "顺着方向画"
        case .radiating: "从起点拖出去"
        }
    }

    private var landmarks: some View {
        VStack(alignment: .leading, spacing: CXSpacing.sm) {
            SectionEyebrow(title: "头部常见位置", action: "也可以直接选")

            ScrollView(.horizontal) {
                HStack(spacing: CXSpacing.sm) {
                    ForEach(headLandmarks, id: \.name) { item in
                        Button {
                            draft.marks.append(
                                PainMark(
                                    angle: angle,
                                    kind: .point,
                                    points: [PainCoordinate(x: item.x, y: item.y)],
                                    name: item.name
                                )
                            )
                        } label: {
                            Text(item.name)
                                .font(CXTypography.supporting.weight(.semibold))
                                .foregroundStyle(CX.ink)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 42)
                                .background(
                                    CX.actionPrimary.opacity(0.055),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(QuietPressButton())
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var headLandmarks: [(name: String, x: Double, y: Double)] {
        switch angle {
        case .front: [("额头", 0.5, 0.25), ("右太阳穴", 0.31, 0.36), ("左太阳穴", 0.69, 0.36), ("下颌", 0.5, 0.64)]
        case .back: [("后脑勺", 0.5, 0.43), ("头顶", 0.5, 0.16), ("后颈", 0.5, 0.75)]
        case .left: [("左太阳穴", 0.35, 0.31), ("左耳周", 0.56, 0.43), ("头顶", 0.5, 0.16)]
        case .right: [("右太阳穴", 0.65, 0.31), ("右耳周", 0.44, 0.43), ("头顶", 0.5, 0.16)]
        }
    }

    private var descriptionForm: some View {
        VStack(alignment: .leading, spacing: CXSpacing.xl) {
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("现在有多疼？")
                            .font(CXTypography.title)
                        Text("先选最接近的一句，不必纠结数字。")
                            .font(CXTypography.supporting)
                            .foregroundStyle(CX.muted)
                    }

                    Spacer()

                    if draft.intensityConfirmed == true {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(draft.intensity)")
                                .font(CXTypography.display)
                                .fontDesign(.rounded)
                                .monospacedDigit()
                                .foregroundStyle(PainVisual.accent)
                            Text("/10")
                                .font(CXTypography.meta)
                                .foregroundStyle(CX.muted)
                        }
                    }
                }

                VStack(spacing: CXSpacing.sm) {
                    ForEach(intensityChoices, id: \.score) { choice in
                        let selected = draft.intensity == choice.score && draft.intensityConfirmed == true

                        Button {
                            draft.intensity = choice.score
                            draft.intensityConfirmed = true
                        } label: {
                            HStack(spacing: CXSpacing.md) {
                                Text("\(choice.score)")
                                    .font(CXTypography.section)
                                    .monospacedDigit()
                                    .foregroundStyle(selected ? .white : PainVisual.accent)
                                    .frame(width: 38, height: 38)
                                    .background(
                                        selected ? PainVisual.accent : PainVisual.accentSoft,
                                        in: Circle()
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(choice.title)
                                        .font(CXTypography.section)
                                        .foregroundStyle(CX.ink)
                                    Text(choice.detail)
                                        .font(CXTypography.meta)
                                        .foregroundStyle(CX.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: CXSpacing.sm)

                                if selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(PainVisual.accent)
                                }
                            }
                            .padding(.horizontal, CXSpacing.md)
                            .frame(maxWidth: .infinity, minHeight: 62)
                            .background(
                                selected ? PainVisual.accentSoft : CX.surface,
                                in: .rect(cornerRadius: CXRadius.md, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous)
                                    .strokeBorder(
                                        selected ? PainVisual.accent.opacity(0.28) : CX.separator.opacity(0.09),
                                        lineWidth: selected ? 1 : 0.5
                                    )
                            }
                        }
                        .buttonStyle(QuietPressButton())
                        .accessibilityLabel("\(choice.score)分，\(choice.title)，\(choice.detail)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("pain-intensity-\(choice.score)")
                    }
                }

                if draft.intensityConfirmed == true {
                    HStack(alignment: .top, spacing: CXSpacing.sm) {
                        Text(PainIntensityScale.band(for: draft.intensity).rawValue)
                            .font(CXTypography.micro.weight(.semibold))
                            .foregroundStyle(PainVisual.accent)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 30)
                            .background(PainVisual.accentSoft, in: Capsule())

                        Text(PainIntensityScale.explanation(for: draft.intensity))
                            .font(CXTypography.supporting)
                            .foregroundStyle(CX.ink)

                        Spacer(minLength: 0)
                    }
                }

                DisclosureGroup("需要更精确？微调 0–10") {
                    VStack(spacing: CXSpacing.sm) {
                        Slider(
                            value: Binding(
                                get: { Double(draft.intensity) },
                                set: {
                                    draft.intensity = Int($0)
                                    draft.intensityConfirmed = true
                                }
                            ),
                            in: 0...10,
                            step: 1
                        )
                        .tint(PainVisual.accent)
                        .accessibilityLabel("疼痛程度")
                        .accessibilityValue("\(draft.intensity)分")

                        HStack {
                            Text("0 · 不疼")
                            Spacer()
                            Text("10 · 最强烈")
                        }
                        .font(CXTypography.micro)
                        .foregroundStyle(CX.muted)
                    }
                    .padding(.top, CXSpacing.sm)
                }
                .font(CXTypography.supporting.weight(.semibold))

                Text("强度只用于记录和沟通，不用于自己判断病情严重程度。")
                    .font(CXTypography.meta)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(4)
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            VStack(alignment: .leading, spacing: CXSpacing.md) {
                SectionEyebrow(title: "疼起来像什么", action: "选择最接近的一项")

                LazyVGrid(
                    columns: CXLayout.adaptiveColumns(
                        minimum: 126,
                        spacing: CXSpacing.sm,
                        dynamicTypeSize: dynamicTypeSize
                    ),
                    spacing: CXSpacing.sm
                ) {
                    ForEach(painQualities, id: \.title) { item in
                        let selected = draft.sensation == item.title

                        Button {
                            draft.sensation = item.title
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.title)
                                        .font(CXTypography.supporting.weight(.semibold))
                                        .foregroundStyle(CX.ink)

                                    Spacer()

                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(PainVisual.accent)
                                    }
                                }

                                Text(item.detail)
                                    .font(CXTypography.micro)
                                    .foregroundStyle(CX.muted)
                                    .lineLimit(2)
                            }
                            .padding(CXSpacing.md)
                            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                            .background(
                                selected ? PainVisual.accentSoft : CX.surface,
                                in: .rect(cornerRadius: 16, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        selected ? PainVisual.accent.opacity(0.24) : CX.separator.opacity(0.08),
                                        lineWidth: 0.7
                                    )
                            }
                        }
                        .buttonStyle(QuietPressButton())
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }

            VStack(alignment: .leading, spacing: CXSpacing.md) {
                SectionEyebrow(title: "什么时候开始")

                Picker("开始时间", selection: $draft.onset) {
                    ForEach(
                        ["开始时间未填写", "刚刚开始", "今天开始", "已经几天", "更久了", "记不清"],
                        id: \.self
                    ) {
                        Text($0)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, CXSpacing.md)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(CX.raisedSurface, in: .rect(cornerRadius: CXRadius.sm, style: .continuous))

                TextField("还有什么想补充的？（选填）", text: $draft.note, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(CXSpacing.md)
                    .background(CX.raisedSurface, in: .rect(cornerRadius: CXRadius.sm, style: .continuous))
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            PainAssessmentForm(
                assessment: Binding(
                    get: { draft.assessment ?? PainAssessment() },
                    set: { draft.assessment = $0 }
                )
            )
        }
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: CXSpacing.xl) {
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(CX.statusPositive)
                        .frame(width: 48, height: 48)
                        .background(CX.statusPositive.opacity(0.08), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("最后核对一次")
                            .font(CXTypography.title)
                        Text("位置、感觉和时间都可以返回修改。")
                            .font(CXTypography.supporting)
                            .foregroundStyle(CX.muted)
                    }

                    Spacer()
                }

                HStack(spacing: CXSpacing.sm) {
                    PainReviewFact(
                        title: "部位",
                        value: draft.region.rawValue,
                        tint: CX.actionPrimary
                    )
                    PainReviewFact(
                        title: "强度",
                        value: draft.intensityConfirmed == true ? "\(draft.intensity)/10" : "未确认",
                        tint: PainVisual.accent
                    )
                    PainReviewFact(
                        title: "感觉",
                        value: draft.sensation,
                        tint: CX.statusPositive
                    )
                }
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            if draft.marks.contains(where: { !$0.hasSurfaceLocation }) {
                SectionEyebrow(title: "标记的位置")

                LazyVGrid(
                    columns: CXLayout.adaptiveColumns(
                        minimum: 146,
                        spacing: CXSpacing.sm,
                        dynamicTypeSize: dynamicTypeSize
                    ),
                    spacing: CXSpacing.sm
                ) {
                    ForEach(
                        PainAngle.allCases.filter { a in
                            draft.marks.contains { $0.angle == a && !$0.hasSurfaceLocation }
                        }
                    ) { a in
                        VStack(alignment: .leading, spacing: CXSpacing.sm) {
                            HStack {
                                Text(a.rawValue)
                                    .font(CXTypography.supporting.weight(.semibold))
                                Spacer()
                                Text("\(draft.marks.filter { $0.angle == a && !$0.hasSurfaceLocation }.count)处")
                                    .font(CXTypography.micro)
                                    .foregroundStyle(CX.muted)
                            }

                            PainMarkingSurface(
                                region: draft.region,
                                angle: a,
                                kind: .point,
                                marks: .constant(draft.marks),
                                editable: false
                            )
                        }
                        .padding(CXSpacing.md)
                        .cxContentSurface(cornerRadius: CXRadius.md)
                    }
                }
            }

            if draft.marks.contains(where: \.hasSurfaceLocation) {
                LegacySurfaceMarkSummary(
                    count: draft.marks.filter(\.hasSurfaceLocation).count
                )
            }

            VStack(alignment: .leading, spacing: CXSpacing.md) {
                SectionEyebrow(title: "这次记录")

                PainReviewRow(title: "开始时间", value: draft.onset)
                Divider().overlay(CX.separator.opacity(0.12))
                PainReviewRow(
                    title: "疼痛感觉",
                    value: draft.sensation
                )

                if !draft.note.isEmpty {
                    Divider().overlay(CX.separator.opacity(0.12))
                    PainReviewRow(title: "补充说明", value: draft.note)
                }

                if let assessment = draft.assessment {
                    Divider().overlay(CX.separator.opacity(0.12))
                    PainAssessmentSummary(assessment: assessment)
                }
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            Button {
                advance(1)
            } label: {
                Label("重新标注位置", systemImage: "pencil.tip")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
        }
    }

    private var footer: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: CXSpacing.sm) {
                    primaryStepButton
                    backStepButton
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: CXSpacing.sm) {
                    backStepButton
                    primaryStepButton
                }
            }
        }
        .padding(CXSpacing.sm)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(CX.separator.opacity(0.10), lineWidth: 0.6)
        }
        .shadow(color: .black.opacity(0.055), radius: 16, y: 7)
    }

    private var backStepButton: some View {
        Button {
            advance(max(0, step - 1))
        } label: {
            Label("上一步", systemImage: "chevron.left")
                .font(CXTypography.supporting.weight(.semibold))
                .frame(minWidth: 92, minHeight: 50)
        }
        .buttonStyle(.plain)
        .foregroundStyle(CX.muted)
    }

    private var primaryStepButton: some View {
        Button(step == 3 ? "保存这次记录" : step == 1 ? "继续描述感受" : "核对这次记录") {
            if step < 3 { advance(step + 1) }
            else {
                do { draft.date = .now; try journal.save(draft); saved = true }
                catch { self.error = journal.readError ?? "记录没有保存成功，请保留当前内容后重试。" }
            }
        }
        .buttonStyle(PrimaryButton())
        .disabled(step == 1 && draft.marks.isEmpty)
        .accessibilityHint(step == 1 ? "进入疼痛感觉和强度选择" : "")
        .accessibilityIdentifier("pain-primary-step")
    }

    private var success: some View {
        VStack(spacing: CXSpacing.xl) {
            ZStack {
                Circle()
                    .fill(CX.statusPositive.opacity(0.08))
                    .frame(width: 88, height: 88)

                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(CX.statusPositive)
            }

            VStack(spacing: CXSpacing.sm) {
                Text("这次感受，已经记下来了")
                    .font(CXTypography.title)
                    .multilineTextAlignment(.center)

                Text(draft.summary)
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }

            VStack(spacing: CXSpacing.sm) {
                Button("再记一个部位") {
                    draft = PainRecord()
                    saved = false
                    advance(0)
                }
                .buttonStyle(PrimaryButton())

                Button("查看记录本") {
                    history = true
                }
                .font(CXTypography.supporting.weight(.semibold))
                .frame(minHeight: 44)
            }
            .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CXSpacing.xl)
    }

    private var painQualities: [(title: String, detail: String)] {
        [("酸痛", "酸胀、持续"), ("刺痛", "针扎一样"), ("跳痛", "一跳一跳"),
         ("灼痛", "烧灼、发热"), ("胀痛", "发紧、撑胀"), ("电击样", "突然窜过"),
         ("钝痛", "闷闷地痛"), ("绞痛", "阵发收紧"), ("触痛", "轻碰或按压会痛"),
         ("麻痛", "麻木伴痛"), ("说不清", "之后可补充")]
    }

    private var intensityChoices: [(score: Int, title: String, detail: String)] {
        [
            (1, "微微疼", "不留意时几乎感觉不到"),
            (3, "有点疼", "能感觉到，但基本不影响做事"),
            (5, "明显疼", "会分心，需要停下来缓一缓"),
            (7, "很疼", "明显影响走动、做事或睡觉"),
            (9, "难以忍受", "几乎无法正常活动或休息")
        ]
    }

    private func advance(_ value: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { step = value }
    }
}

private struct PainReviewFact: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(CXTypography.micro)
                .foregroundStyle(CX.muted)

            Text(value)
                .font(CXTypography.supporting.weight(.semibold))
                .foregroundStyle(CX.ink)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(CXSpacing.sm)
        .background(tint.opacity(0.055), in: .rect(cornerRadius: 14, style: .continuous))
    }
}

private struct PainReviewRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: CXSpacing.md) {
            Text(title)
                .font(CXTypography.supporting)
                .foregroundStyle(CX.muted)
                .frame(width: 74, alignment: .leading)

            Text(value)
                .font(CXTypography.supporting.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct LegacySurfaceMarkSummary: View {
    let count: Int

    var body: some View {
        Card {
            Label("旧版立体位置已保留", systemImage: "archivebox.fill")
                .font(.headline)
                .foregroundStyle(CX.blue)
            Text("这条记录包含 \(count) 处旧版三维坐标。为避免再次展示骨骼或切面模型，这里只保留位置说明；原始数据不会被删除。")
                .font(.subheadline)
                .foregroundStyle(CX.muted)
                .lineSpacing(4)
        }
    }
}

/// Compact, neutral body reference used before region selection.
private struct GentleBodyOverview: View {
    var body: some View {
        HStack(spacing: 22) {
            ForEach([PainAngle.front, .back]) { angle in
                VStack(spacing: 6) {
                    PainAtlasCell(angle: angle, crop: PainAtlasCell.fullBody)
                        .frame(width: 104, height: 128)
                        .clipShape(.rect(cornerRadius: 14, style: .continuous))
                    Text(angle.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(CX.muted)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Static surface-only clinical illustration. The interactive anatomy layers are
/// intentionally not used in this flow.
struct PainArtwork: View {
    let region: PainRegion
    let angle: PainAngle

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    CX.surface.opacity(0.98),
                    CX.moonlight.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            GentlePainFigure(region: region, angle: angle)
                .padding(14)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct PainAtlasCell: View {
    let angle: PainAngle
    let crop: CGRect

    static let fullBody = CGRect(x: 0, y: 0, width: 1, height: 1)

    var body: some View {
        GeometryReader { geometry in
            let side = max(geometry.size.width, geometry.size.height)
            let cell = side / max(crop.width, crop.height)
            Image("PainBodyAtlas")
                .resizable()
                .frame(width: cell * 2, height: cell * 2)
                .offset(
                    x: -(angle.column + crop.minX) * cell,
                    y: -(angle.row + crop.minY) * cell
                )
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .clipped()
        }
    }
}

private struct GentlePainFigure: View {
    let region: PainRegion?
    let angle: PainAngle

    var body: some View {
        Canvas { context, size in
            let focus = focusConfiguration(in: size)
            var drawing = context
            drawing.translateBy(x: size.width / 2 - focus.center.x * focus.scale,
                                y: size.height / 2 - focus.center.y * focus.scale)
            drawing.scaleBy(x: focus.scale, y: focus.scale)

            let glow = Path(ellipseIn: highlightRect)
            drawing.fill(glow, with: .color(CX.moonlight.opacity(region == nil ? 0.07 : 0.15)))

            let parts = angle == .left || angle == .right ? sideParts : frontParts
            for part in parts {
                drawing.fill(
                    part,
                    with: .linearGradient(
                        Gradient(colors: [
                            PainVisual.bodyTop,
                            PainVisual.bodyBottom
                        ]),
                        startPoint: CGPoint(x: 95, y: 80),
                        endPoint: CGPoint(x: 230, y: 560)
                    )
                )
            }

            var guide = Path()
            if angle == .back {
                guide.move(to: CGPoint(x: 160, y: 154))
                guide.addCurve(to: CGPoint(x: 160, y: 320), control1: CGPoint(x: 154, y: 210), control2: CGPoint(x: 166, y: 268))
            } else if angle == .front {
                guide.move(to: CGPoint(x: 130, y: 170))
                guide.addQuadCurve(to: CGPoint(x: 190, y: 170), control: CGPoint(x: 160, y: 184))
            } else {
                guide.move(to: CGPoint(x: 168, y: 164))
                guide.addCurve(to: CGPoint(x: 173, y: 315), control1: CGPoint(x: 180, y: 210), control2: CGPoint(x: 164, y: 270))
            }
            drawing.stroke(guide, with: .color(PainVisual.guide), style: StrokeStyle(lineWidth: 2.2 / focus.scale, lineCap: .round))
        }
    }

    private func focusConfiguration(in size: CGSize) -> (center: CGPoint, scale: CGFloat) {
        let base = min(size.width / 320, size.height / 640)
        let center: CGPoint
        let zoom: CGFloat
        switch region {
        case nil: center = CGPoint(x: 160, y: 320); zoom = 0.92
        case .head?: center = CGPoint(x: 160, y: 102); zoom = 2.25
        case .neck?: center = CGPoint(x: 160, y: 158); zoom = 1.95
        case .torso?, .back?: center = CGPoint(x: 160, y: 250); zoom = 1.30
        case .arms?: center = CGPoint(x: 160, y: 260); zoom = 0.92
        case .legs?: center = CGPoint(x: 160, y: 454); zoom = 0.92
        }
        return (center, base * zoom)
    }

    private var highlightRect: CGRect {
        switch region {
        case nil: CGRect(x: 84, y: 48, width: 152, height: 520)
        case .head?: CGRect(x: 112, y: 20, width: 96, height: 112)
        case .neck?: CGRect(x: 93, y: 112, width: 134, height: 96)
        case .torso?: CGRect(x: 94, y: 170, width: 132, height: 174)
        case .back?: CGRect(x: 92, y: 164, width: 136, height: 190)
        case .arms?: CGRect(x: 48, y: 145, width: 224, height: 226)
        case .legs?: CGRect(x: 96, y: 322, width: 128, height: 292)
        }
    }

    private var frontParts: [Path] {
        var head = Path(ellipseIn: CGRect(x: 119, y: 24, width: 82, height: 94))
        head.addEllipse(in: CGRect(x: 112, y: 66, width: 13, height: 28))
        head.addEllipse(in: CGRect(x: 195, y: 66, width: 13, height: 28))

        var neck = Path()
        neck.addRect(CGRect(x: 143, y: 108, width: 34, height: 55))
        neck.addEllipse(in: CGRect(x: 143, y: 137, width: 34, height: 32))

        var torso = Path()
        torso.move(to: CGPoint(x: 105, y: 151))
        torso.addCurve(to: CGPoint(x: 128, y: 318), control1: CGPoint(x: 112, y: 205), control2: CGPoint(x: 116, y: 270))
        torso.addCurve(to: CGPoint(x: 160, y: 337), control1: CGPoint(x: 137, y: 330), control2: CGPoint(x: 148, y: 337))
        torso.addCurve(to: CGPoint(x: 192, y: 318), control1: CGPoint(x: 172, y: 337), control2: CGPoint(x: 183, y: 330))
        torso.addCurve(to: CGPoint(x: 215, y: 151), control1: CGPoint(x: 204, y: 270), control2: CGPoint(x: 208, y: 205))
        torso.addCurve(to: CGPoint(x: 177, y: 132), control1: CGPoint(x: 204, y: 137), control2: CGPoint(x: 188, y: 134))
        torso.addLine(to: CGPoint(x: 143, y: 132))
        torso.addCurve(to: CGPoint(x: 105, y: 151), control1: CGPoint(x: 132, y: 134), control2: CGPoint(x: 116, y: 137))
        torso.closeSubpath()

        var leftArm = Path()
        leftArm.move(to: CGPoint(x: 111, y: 148))
        leftArm.addCurve(to: CGPoint(x: 76, y: 315), control1: CGPoint(x: 94, y: 192), control2: CGPoint(x: 87, y: 262))
        leftArm.addCurve(to: CGPoint(x: 59, y: 363), control1: CGPoint(x: 74, y: 334), control2: CGPoint(x: 66, y: 349))
        leftArm.addCurve(to: CGPoint(x: 78, y: 370), control1: CGPoint(x: 64, y: 371), control2: CGPoint(x: 72, y: 373))
        leftArm.addCurve(to: CGPoint(x: 105, y: 250), control1: CGPoint(x: 88, y: 327), control2: CGPoint(x: 98, y: 286))
        leftArm.addCurve(to: CGPoint(x: 124, y: 162), control1: CGPoint(x: 112, y: 217), control2: CGPoint(x: 121, y: 183))
        leftArm.closeSubpath()

        var rightArm = leftArm
        rightArm = leftArm.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 320, ty: 0))

        var leftLeg = Path()
        leftLeg.move(to: CGPoint(x: 128, y: 312))
        leftLeg.addCurve(to: CGPoint(x: 112, y: 472), control1: CGPoint(x: 120, y: 366), control2: CGPoint(x: 112, y: 426))
        leftLeg.addCurve(to: CGPoint(x: 101, y: 602), control1: CGPoint(x: 111, y: 520), control2: CGPoint(x: 107, y: 566))
        leftLeg.addCurve(to: CGPoint(x: 127, y: 612), control1: CGPoint(x: 105, y: 614), control2: CGPoint(x: 118, y: 615))
        leftLeg.addCurve(to: CGPoint(x: 153, y: 337), control1: CGPoint(x: 139, y: 518), control2: CGPoint(x: 149, y: 411))
        leftLeg.closeSubpath()

        let rightLeg = leftLeg.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 320, ty: 0))
        return [leftArm, rightArm, leftLeg, rightLeg, torso, neck, head]
    }

    private var sideParts: [Path] {
        let head = Path(ellipseIn: CGRect(x: 126, y: 24, width: 72, height: 96))

        var neck = Path()
        neck.addRect(CGRect(x: 145, y: 107, width: 35, height: 58))
        var torso = Path()
        torso.move(to: CGPoint(x: 137, y: 142))
        torso.addCurve(to: CGPoint(x: 137, y: 331), control1: CGPoint(x: 126, y: 204), control2: CGPoint(x: 127, y: 275))
        torso.addCurve(to: CGPoint(x: 185, y: 331), control1: CGPoint(x: 150, y: 342), control2: CGPoint(x: 173, y: 341))
        torso.addCurve(to: CGPoint(x: 192, y: 165), control1: CGPoint(x: 199, y: 269), control2: CGPoint(x: 201, y: 202))
        torso.addCurve(to: CGPoint(x: 137, y: 142), control1: CGPoint(x: 180, y: 146), control2: CGPoint(x: 158, y: 140))
        torso.closeSubpath()

        var arm = Path()
        arm.move(to: CGPoint(x: 146, y: 153))
        arm.addCurve(to: CGPoint(x: 159, y: 360), control1: CGPoint(x: 151, y: 214), control2: CGPoint(x: 154, y: 294))
        arm.addCurve(to: CGPoint(x: 177, y: 360), control1: CGPoint(x: 163, y: 371), control2: CGPoint(x: 172, y: 369))
        arm.addCurve(to: CGPoint(x: 177, y: 170), control1: CGPoint(x: 178, y: 292), control2: CGPoint(x: 179, y: 219))
        arm.closeSubpath()

        var frontLeg = Path()
        frontLeg.move(to: CGPoint(x: 139, y: 315))
        frontLeg.addCurve(to: CGPoint(x: 122, y: 601), control1: CGPoint(x: 135, y: 404), control2: CGPoint(x: 128, y: 527))
        frontLeg.addCurve(to: CGPoint(x: 166, y: 611), control1: CGPoint(x: 128, y: 616), control2: CGPoint(x: 153, y: 615))
        frontLeg.addCurve(to: CGPoint(x: 174, y: 336), control1: CGPoint(x: 169, y: 505), control2: CGPoint(x: 176, y: 410))
        frontLeg.closeSubpath()

        let backLeg = frontLeg.applying(CGAffineTransform(translationX: 24, y: -2))
        let parts = [backLeg, frontLeg, torso, arm, neck, head]
        if angle == .right {
            return parts.map { $0.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 320, ty: 0)) }
        }
        return parts
    }
}

private struct PainToolPreview: View {
    let kind: PainMarkKind

    var body: some View {
        Canvas { context, size in
            let coral = PainVisual.accent
            switch kind {
            case .point:
                context.fill(Path(ellipseIn: CGRect(x: 4, y: 4, width: size.width - 8, height: size.height - 8)), with: .color(coral.opacity(0.13)))
                context.fill(Path(ellipseIn: CGRect(x: size.width / 2 - 4, y: size.height / 2 - 4, width: 8, height: 8)), with: .color(coral))
            case .area:
                for point in [CGPoint(x: 12, y: 18), CGPoint(x: 20, y: 13), CGPoint(x: 26, y: 20), CGPoint(x: 18, y: 25)] {
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)), with: .color(coral.opacity(0.18)))
                }
            case .line:
                var path = Path(); path.move(to: CGPoint(x: 5, y: 25)); path.addCurve(to: CGPoint(x: size.width - 5, y: 11), control1: CGPoint(x: 13, y: 7), control2: CGPoint(x: 24, y: 29))
                context.stroke(path, with: .color(coral), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            case .radiating:
                let center = CGPoint(x: 11, y: size.height / 2)
                context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(coral))
                for offset: CGFloat in [-8, 0, 8] {
                    var ray = Path(); ray.move(to: CGPoint(x: 16, y: center.y)); ray.addLine(to: CGPoint(x: size.width - 5, y: center.y + offset))
                    context.stroke(ray, with: .color(coral.opacity(0.78)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
            }
        }
        .frame(width: 36, height: 36)
        .background(PainVisual.accent.opacity(0.055), in: Circle())
    }
}

struct PainMarkingSurface: View {
    let region: PainRegion
    let angle: PainAngle
    let kind: PainMarkKind
    @Binding var marks: [PainMark]
    var editable = true
    @State private var stroke: [PainCoordinate] = []

    var body: some View {
        VStack(alignment: .leading, spacing: CXSpacing.sm) {
            ZStack {
                GeometryReader { geo in
                    ZStack {
                        PainArtwork(region: region, angle: angle)

                        Canvas { context, size in
                            let visible = marks.filter { $0.angle == angle && !$0.hasSurfaceLocation }
                            for mark in visible {
                                paint(mark.points, kind: mark.kind, context: &context, size: size)
                            }
                            paint(stroke, kind: kind, context: &context, size: size)
                        }
                        .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard editable else { return }
                                let point = PainCoordinate(
                                    x: min(1, max(0, value.location.x / geo.size.width)),
                                    y: min(1, max(0, value.location.y / geo.size.height))
                                )
                                if kind == .point {
                                    stroke = [point]
                                } else if stroke.count < 500, shouldAppend(point) {
                                    stroke.append(point)
                                }
                            }
                            .onEnded { _ in
                                guard editable, !stroke.isEmpty else { return }
                                let finalKind: PainMarkKind =
                                    (kind == .line || kind == .radiating) && stroke.count < 2
                                        ? .point
                                        : kind
                                marks.append(
                                    PainMark(
                                        angle: angle,
                                        kind: finalKind,
                                        points: stroke
                                    )
                                )
                                stroke = []
                            },
                        including: editable ? .all : .none
                    )
                }
                .aspectRatio(1, contentMode: .fit)

                VStack {
                    HStack {
                        Text(angle.rawValue)
                            .font(CXTypography.micro.weight(.semibold))
                            .foregroundStyle(CX.ink.opacity(0.72))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 30)
                            .background(.ultraThinMaterial, in: Capsule())

                        Spacer()
                    }

                    Spacer()

                    if editable && marks.allSatisfy({ $0.angle != angle || $0.hasSurfaceLocation }) {
                        Label("在轮廓上\(kind.label == "点状" ? "轻点" : "拖动")", systemImage: "hand.draw")
                            .font(CXTypography.micro.weight(.semibold))
                            .foregroundStyle(CX.muted)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 30)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(12)
                .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(CX.separator.opacity(0.12), lineWidth: 0.6)
            }
            .shadow(color: .black.opacity(0.035), radius: 14, y: 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(region.rawValue)\(angle.rawValue)位置图")
            .accessibilityHint(kind.instruction)
            .accessibilityIdentifier("pain-marking-surface")

            Text(angle.orientation)
                .font(CXTypography.micro)
                .foregroundStyle(CX.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: marks.count)
    }

    private func shouldAppend(_ point: PainCoordinate) -> Bool {
        guard let last = stroke.last else { return true }
        let dx = point.x - last.x
        let dy = point.y - last.y
        return dx * dx + dy * dy > 0.000025
    }

    private func paint(_ points: [PainCoordinate], kind: PainMarkKind, context: inout GraphicsContext, size: CGSize) {
        guard let first = points.first else { return }
        let start = CGPoint(x: first.x * size.width, y: first.y * size.height)
        if kind == .point {
            context.fill(Path(ellipseIn: CGRect(x: start.x - 19, y: start.y - 19, width: 38, height: 38)), with: .color(CX.coral.opacity(0.12)))
            context.stroke(Path(ellipseIn: CGRect(x: start.x - 10, y: start.y - 10, width: 20, height: 20)), with: .color(Color.white.opacity(0.92)), lineWidth: 3)
            context.fill(Path(ellipseIn: CGRect(x: start.x - 7, y: start.y - 7, width: 14, height: 14)), with: .color(CX.coral))
        } else if kind == .area {
            let diameter = max(34, min(size.width, size.height) * 0.115)
            let step = max(1, points.count / 90)
            for index in stride(from: 0, to: points.count, by: step) {
                let point = points[index]
                let center = CGPoint(x: point.x * size.width, y: point.y * size.height)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)),
                    with: .color(CX.coral.opacity(0.10))
                )
            }
            if points.count > 1 {
                var brushPath = Path(); brushPath.move(to: start)
                for point in points.dropFirst() { brushPath.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height)) }
                context.stroke(brushPath, with: .color(CX.coral.opacity(0.14)), style: StrokeStyle(lineWidth: diameter * 0.60, lineCap: .round, lineJoin: .round))
                context.stroke(brushPath, with: .color(CX.coral.opacity(0.72)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        } else {
            var path = Path(); path.move(to: start)
            for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height)) }
            let strokeColor = PainVisual.accent
            context.stroke(path, with: .color(strokeColor.opacity(0.13)), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
            if kind == .radiating, let last = points.last {
                let end = CGPoint(x: last.x * size.width, y: last.y * size.height)
                context.fill(Path(ellipseIn: CGRect(x: start.x - 11, y: start.y - 11, width: 22, height: 22)), with: .color(strokeColor.opacity(0.16)))
                context.fill(Path(ellipseIn: CGRect(x: start.x - 4, y: start.y - 4, width: 8, height: 8)), with: .color(strokeColor))
                for radius: CGFloat in [10, 17] {
                    context.stroke(
                        Path(
                            ellipseIn: CGRect(
                                x: end.x - radius,
                                y: end.y - radius,
                                width: radius * 2,
                                height: radius * 2
                            )
                        ),
                        with: .color(strokeColor.opacity(radius == 10 ? 0.22 : 0.10)),
                        lineWidth: 1.6
                    )
                }
            }
        }
    }
}

private struct PainHistoryView: View {
    let journal: PainJournal
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("身体感受记录")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)

                Text("回看之前标过的位置")
                    .font(CXTypography.display)

                Text("这些记录只描述当时的感受和位置，不代表诊断结果。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            if let error = journal.readError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.statusCritical)
                    .padding(CXSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        CX.statusCritical.opacity(0.05),
                        in: .rect(cornerRadius: CXRadius.md, style: .continuous)
                    )
            }

            if journal.records.isEmpty {
                CXEmptyState(
                    title: "还没有身体感受记录",
                    message: "以后每次标记的位置、强度和感觉，都会留在这里方便回看。",
                    icon: "figure.stand"
                )
            } else {
                SectionEyebrow(title: "本机记录", action: "\(journal.records.count) 条")

                ForEach(journal.records) { record in
                    NavigationLink {
                        PainHistoryDetailView(record: record)
                    } label: {
                        HStack(spacing: CXSpacing.md) {
                            GentlePainFigure(
                                region: record.region,
                                angle: record.region == .back ? .back : .front
                            )
                            .frame(width: 54, height: 76)
                            .background(CX.moonlight.opacity(0.035), in: .rect(cornerRadius: 12, style: .continuous))
                            .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(record.region.rawValue)
                                        .font(CXTypography.section)
                                        .foregroundStyle(CX.ink)

                                    if record.intensityConfirmed == true {
                                        Text("\(record.intensity)/10")
                                            .font(CXTypography.micro.weight(.semibold))
                                            .foregroundStyle(PainVisual.accent)
                                            .padding(.horizontal, 8)
                                            .frame(minHeight: 26)
                                            .background(PainVisual.accentSoft, in: Capsule())
                                    }
                                }

                                Text(record.sensation)
                                    .font(CXTypography.supporting)
                                    .foregroundStyle(CX.muted)

                                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(CXTypography.micro)
                                    .foregroundStyle(CX.faint)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CX.faint)
                        }
                        .padding(CXSpacing.md)
                        .cxContentSurface(cornerRadius: CXRadius.md)
                    }
                    .buttonStyle(QuietPressButton())
                }
            }
        }
        .navigationTitle("疼痛记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
    }
}

private struct PainHistoryDetailView: View {
    let record: PainRecord

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text(record.date.formatted(date: .long, time: .shortened))
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.muted)

                Text(record.region.rawValue)
                    .font(CXTypography.display)

                Text(record.summary)
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            if record.marks.contains(where: { !$0.hasSurfaceLocation }) {
                SectionEyebrow(title: "当时标记的位置")

                ForEach(
                    PainAngle.allCases.filter { angle in
                        record.marks.contains { $0.angle == angle && !$0.hasSurfaceLocation }
                    }
                ) { angle in
                    VStack(alignment: .leading, spacing: CXSpacing.sm) {
                        Text(angle.rawValue)
                            .font(CXTypography.section)

                        PainMarkingSurface(
                            region: record.region,
                            angle: angle,
                            kind: .point,
                            marks: .constant(record.marks),
                            editable: false
                        )
                    }
                    .padding(CXSpacing.md)
                    .cxContentSurface(cornerRadius: CXRadius.lg)
                }
            }

            if record.marks.contains(where: \.hasSurfaceLocation) {
                LegacySurfaceMarkSummary(
                    count: record.marks.filter(\.hasSurfaceLocation).count
                )
            }

            if !record.note.isEmpty {
                SectionEyebrow(title: "补充说明")
                Text(record.note)
                    .font(CXTypography.body)
                    .lineSpacing(5)
                    .padding(CXSpacing.lg)
                    .cxContentSurface(cornerRadius: CXRadius.lg)
            }

            if let assessment = record.assessment {
                PainAssessmentSummary(assessment: assessment)
            }
        }
        .navigationTitle("记录详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("身体感受 · 原生独立页面") {
    NavigationStack { PainLocationView() }
}
