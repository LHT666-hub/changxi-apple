import SwiftUI

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
                if step != 1 { header }
                if saved { success }
                else {
                    if step == 0 {
                        Button { voiceLocation = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "waveform.badge.mic").font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("也可以说给常曦听").font(.headline)
                                    Text("我来标，你来确认").font(.subheadline).foregroundStyle(CX.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                            }.padding(18).cxInteractiveGlass(cornerRadius: 22)
                        }.buttonStyle(.plain)
                    }
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
                ScrollView {
                    VStack(spacing: 20) {
                        anglePicker
                        PainMarkingSurface(region: draft.region, angle: angle, kind: kind, marks: $draft.marks)
                        markTools
                    }
                    .padding(20)
                }
                .cxMoonScreenBackground()
                .navigationTitle("细标疼痛位置")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { enlarged = false } } }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                ForEach(0..<4) { index in
                    Capsule().fill(index <= step ? CX.moonlight : CX.moonlight.opacity(0.18)).frame(height: 3)
                }
            }.accessibilityLabel("第\(step + 1)步，共4步")
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "cross.case.fill")
                    .font(.title3)
                    .foregroundStyle(CX.blue)
                    .frame(width: 42, height: 42)
                    .background(CX.moonlight.opacity(0.14), in: Circle())
                Text("按实际感受记录即可；无法确定时，可先选择最接近的区域。")
                    .font(.subheadline)
                    .foregroundStyle(CX.muted)
            }
            Text(saved ? "这次感受，记下来了" : title)
                .font(.largeTitle.weight(.semibold)).fontDesign(.serif)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var regionGrid: some View {
        VStack(spacing: 16) {
            Text("选择最接近的身体区域；下一步可切换正面、侧面和背面，进一步标注具体位置。")
                .font(.subheadline)
                .foregroundStyle(CX.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: CXLayout.adaptiveColumns(minimum: 156, spacing: 12, dynamicTypeSize: dynamicTypeSize), spacing: 12) {
                ForEach(PainRegion.allCases) { region in
                    Button {
                        draft = PainRecord(region: region)
                        angle = region == .back ? .back : .front
                        advance(1)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: regionSymbol(region))
                                .font(.title3.weight(.medium))
                                .foregroundStyle(CX.blue)
                                .frame(width: 42, height: 42)
                                .background(CX.moonlight.opacity(0.14), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(region.rawValue).font(.headline)
                                Text(regionHint(region)).font(.caption).foregroundStyle(CX.muted)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold)).foregroundStyle(CX.faint)
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .cxInteractiveGlass(cornerRadius: 22)
                        .contentShape(.rect(cornerRadius: 22))
                    }
                    .buttonStyle(QuietPressButton())
                    .accessibilityIdentifier("pain-region-\(region.anatomyAssetName)")
                }
            }
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title2.weight(.semibold))
                    Text(kind.instruction)
                        .font(.caption).foregroundStyle(CX.muted)
                }
                Spacer()
                Button { voiceLocation = true } label: {
                    Image(systemName: "waveform.badge.mic")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .cxInteractiveGlassCircle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("说给常曦听，再在图上确认")
            }
            if let voiceHint {
                Label("已按语音标出“\(voiceHint)”，还可以在图上调整", systemImage: "waveform.badge.mic")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CX.blue)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .background(CX.moonlight.opacity(0.12), in: .rect(cornerRadius: 14))
            }
            anglePicker
            PainMarkingSurface(region: draft.region, angle: angle, kind: kind, marks: $draft.marks)
                .id(angle)
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: angle)
            HStack {
                let count = draft.marks.filter { $0.angle == angle && !$0.hasSurfaceLocation }.count
                Label(count == 0 ? "还没有标记" : "这个视角已标记 \(count) 处", systemImage: count == 0 ? "hand.draw" : "checkmark.circle.fill")
                    .foregroundStyle(count == 0 ? CX.muted : CX.teal)
                Spacer()
                Button { enlarged = true } label: { Label("放大细标", systemImage: "arrow.up.left.and.arrow.down.right") }
            }.font(.subheadline)
            markTools
            if draft.region == .head { landmarks }
            Text("以你自己的身体左右为准。标记只表达你感到疼的位置。")
                .font(.footnote).foregroundStyle(CX.muted)
        }
    }

    private var markTools: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: CXLayout.adaptiveColumns(minimum: 146, spacing: 10, dynamicTypeSize: dynamicTypeSize), spacing: 10) {
                ForEach(PainMarkKind.allCases) { tool in
                    Button { kind = tool } label: {
                        HStack(spacing: 10) {
                            PainToolPreview(kind: tool)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tool.label).font(.subheadline.weight(.semibold))
                                Text(toolShortHint(tool)).font(.caption2).foregroundStyle(CX.muted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                        .background(kind == tool ? CX.moonlight.opacity(0.16) : CX.surface.opacity(0.82), in: .rect(cornerRadius: 18))
                        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(kind == tool ? CX.blue.opacity(0.45) : CX.separator.opacity(0.12), lineWidth: kind == tool ? 1.2 : 0.5) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(kind == tool ? .isSelected : [])
                    .accessibilityHint(tool.instruction)
                    .accessibilityIdentifier("pain-tool-\(tool.label)")
                }
            }
            HStack(spacing: 12) {
                Button {
                    if let index = draft.marks.lastIndex(where: { $0.angle == angle && !$0.hasSurfaceLocation }) { draft.marks.remove(at: index) }
                } label: { Label("撤销上一笔", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity, minHeight: 44) }
                    .disabled(!draft.marks.contains(where: { $0.angle == angle && !$0.hasSurfaceLocation }))
                Button(role: .destructive) {
                    draft.marks.removeAll { $0.angle == angle && !$0.hasSurfaceLocation }
                } label: { Label("清空此面", systemImage: "eraser").frame(maxWidth: .infinity, minHeight: 44) }
                    .disabled(!draft.marks.contains(where: { $0.angle == angle && !$0.hasSurfaceLocation }))
            }
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
        VStack(alignment: .leading, spacing: 12) {
            Text("也可以直接选位置").font(.subheadline).foregroundStyle(CX.muted)
            LazyVGrid(columns: CXLayout.adaptiveColumns(minimum: 100, dynamicTypeSize: dynamicTypeSize)) {
                ForEach(headLandmarks, id: \.name) { item in
                    Button(item.name) {
                        draft.marks.append(PainMark(angle: angle, kind: .point, points: [PainCoordinate(x: item.x, y: item.y)], name: item.name))
                    }.buttonStyle(.bordered).frame(minHeight: 44)
                }
            }
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
        VStack(spacing: 20) {
            Card {
                HStack(alignment: .firstTextBaseline) {
                    Text("有多疼").font(.title3.weight(.semibold))
                    Spacer()
                    if draft.intensityConfirmed == true {
                        Text("\(draft.intensity)").font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundStyle(CX.blue)
                        Text("/ 10").font(.subheadline).foregroundStyle(CX.muted)
                    } else { Text("尚未确认").foregroundStyle(CX.muted) }
                }
                Text("先选一句最接近你现在的感受")
                    .font(.subheadline)
                    .foregroundStyle(CX.muted)
                VStack(spacing: 8) {
                    ForEach(intensityChoices, id: \.score) { choice in
                        Button {
                            draft.intensity = choice.score
                            draft.intensityConfirmed = true
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(choice.score)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(draft.intensity == choice.score && draft.intensityConfirmed == true ? .white : CX.blue)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        draft.intensity == choice.score && draft.intensityConfirmed == true ? CX.blue : CX.blue.opacity(0.10),
                                        in: Circle()
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(choice.title).font(.subheadline.weight(.semibold))
                                    Text(choice.detail).font(.caption).foregroundStyle(CX.muted)
                                }
                                Spacer()
                                if draft.intensity == choice.score && draft.intensityConfirmed == true {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(CX.blue)
                                }
                            }
                            .padding(12)
                            .background(
                                draft.intensity == choice.score && draft.intensityConfirmed == true ? CX.blue.opacity(0.10) : CX.mist.opacity(0.72),
                                in: .rect(cornerRadius: 16)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(choice.score)分，\(choice.title)，\(choice.detail)")
                        .accessibilityAddTraits(draft.intensity == choice.score && draft.intensityConfirmed == true ? .isSelected : [])
                        .accessibilityIdentifier("pain-intensity-\(choice.score)")
                    }
                }
                Text("想记得更精确，可以再微调")
                    .font(.caption)
                    .foregroundStyle(CX.muted)
                Slider(value: Binding(get: { Double(draft.intensity) }, set: { draft.intensity = Int($0); draft.intensityConfirmed = true }), in: 0...10, step: 1)
                    .accessibilityLabel("疼痛程度").accessibilityValue("\(draft.intensity)分")
                HStack { Text("0 · 不疼"); Spacer(); Text("10 · 能想象的最疼") }.font(.footnote).foregroundStyle(CX.muted)
                if draft.intensityConfirmed == true {
                    HStack(spacing: 10) {
                        Text(PainIntensityScale.band(for: draft.intensity).rawValue)
                            .font(.caption.weight(.semibold)).foregroundStyle(CX.blue)
                            .padding(.horizontal, 9).padding(.vertical, 5).background(CX.blue.opacity(0.10), in: Capsule())
                        Text(PainIntensityScale.explanation(for: draft.intensity))
                            .font(.subheadline).foregroundStyle(CX.ink)
                    }
                }
                Button(draft.intensityConfirmed == true ? "已确认这个分数" : "就记这个分数") { draft.intensityConfirmed = true }
                Text("分级用于记录和沟通，不用于自行判断病情轻重。")
                    .font(.footnote).foregroundStyle(CX.muted)
            }
            Card {
                Text("疼起来像什么").font(.title3.weight(.semibold))
                Text("选择最接近的一种感觉；它和疼痛强度是两回事。")
                    .font(.footnote).foregroundStyle(CX.muted)
                LazyVGrid(columns: CXLayout.adaptiveColumns(minimum: 128, dynamicTypeSize: dynamicTypeSize)) {
                    ForEach(painQualities, id: \.title) { item in
                        Button { draft.sensation = item.title } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.subheadline.weight(.semibold))
                                Text(item.detail).font(.caption).foregroundStyle(CX.muted)
                            }
                            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                            .padding(.horizontal, 12)
                            .background(draft.sensation == item.title ? CX.blue.opacity(0.15) : CX.mist, in: .rect(cornerRadius: 16))
                        }.buttonStyle(.plain).accessibilityAddTraits(draft.sensation == item.title ? .isSelected : [])
                    }
                }
            }
            Card {
                Text("什么时候开始").font(.title3.weight(.semibold))
                Picker("开始时间", selection: $draft.onset) {
                    ForEach(["开始时间未填写", "刚刚开始", "今天开始", "已经几天", "更久了", "记不清"], id: \.self) { Text($0) }
                }.pickerStyle(.menu)
                TextField("还有什么想补充的？（选填）", text: $draft.note, axis: .vertical)
                    .lineLimit(3...6).padding(14).background(CX.mist, in: .rect(cornerRadius: 16))
            }
            PainAssessmentForm(assessment: Binding(get: { draft.assessment ?? PainAssessment() }, set: { draft.assessment = $0 }))
        }
    }

    private var review: some View {
        VStack(spacing: 20) {
            if draft.marks.contains(where: \.hasSurfaceLocation) {
                LegacySurfaceMarkSummary(count: draft.marks.filter(\.hasSurfaceLocation).count)
            }
            ForEach(PainAngle.allCases.filter { a in draft.marks.contains { $0.angle == a && !$0.hasSurfaceLocation } }) { a in
                VStack(alignment: .leading) {
                    Text(a.rawValue).font(.headline)
                    PainMarkingSurface(region: draft.region, angle: a, kind: kind, marks: .constant(draft.marks), editable: false)
                }
            }
            Card {
                Text(draft.summary).font(.title3).lineSpacing(7)
                ForEach(draft.marks) { mark in
                    Text("\(!mark.hasSurfaceLocation ? mark.angle.rawValue : "三维表面") · \(mark.name ?? mark.kind.label)").font(.subheadline).foregroundStyle(CX.muted)
                }
                if !draft.note.isEmpty { Text(draft.note) }
                if let assessment = draft.assessment { PainAssessmentSummary(assessment: assessment) }
                Button("重新标注位置") { advance(1) }
            }
        }
    }

    private var footer: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    primaryStepButton
                    backStepButton.frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 12) {
                    backStepButton
                    primaryStepButton
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: .rect(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.66), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
    }

    private var backStepButton: some View {
        Button("上一步") { advance(step - 1) }
            .frame(minWidth: 80, minHeight: 48)
    }

    private var primaryStepButton: some View {
        Button(step == 3 ? "保存这次记录" : step == 1 ? "下一步：选感觉和强度" : "看看记录") {
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
        Card {
            Label("已保存在这台设备", systemImage: "checkmark.circle.fill").foregroundStyle(CX.teal)
            Text(draft.summary).font(.title3)
            Button("再记一个部位") { draft = PainRecord(); saved = false; advance(0) }.buttonStyle(PrimaryButton())
            Button("查看记录本") { history = true }
        }
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
                colors: [Color.white.opacity(0.98), CX.moonlight.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            PainAtlasCell(angle: angle, crop: crop)
                .padding(10)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var crop: CGRect {
        switch region {
        case .head: CGRect(x: 0.34, y: 0.015, width: 0.32, height: 0.32)
        default: region.crop
        }
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
                            Color(red: 0.88, green: 0.92, blue: 0.94),
                            Color(red: 0.71, green: 0.79, blue: 0.83)
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
            drawing.stroke(guide, with: .color(CX.blue.opacity(0.18)), style: StrokeStyle(lineWidth: 2.2 / focus.scale, lineCap: .round))
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
        var head = Path(ellipseIn: CGRect(x: 126, y: 24, width: 72, height: 96))
        var profile = Path()
        profile.move(to: CGPoint(x: 190, y: 62))
        profile.addLine(to: CGPoint(x: 207, y: 76))
        profile.addLine(to: CGPoint(x: 191, y: 83))
        profile.addLine(to: CGPoint(x: 195, y: 101))
        profile.addQuadCurve(to: CGPoint(x: 177, y: 116), control: CGPoint(x: 190, y: 114))
        profile.closeSubpath()
        head.addPath(profile)

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
            let coral = CX.coral
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
        .background(CX.coral.opacity(0.06), in: Circle())
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
        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack {
                    PainArtwork(region: region, angle: angle)
                    Canvas { context, size in
                        let visible = marks.filter { $0.angle == angle && !$0.hasSurfaceLocation }
                        for mark in visible { paint(mark.points, kind: mark.kind, context: &context, size: size) }
                        paint(stroke, kind: kind, context: &context, size: size)
                    }.allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard editable else { return }
                        let point = PainCoordinate(x: min(1, max(0, value.location.x / geo.size.width)), y: min(1, max(0, value.location.y / geo.size.height)))
                        if kind == .point { stroke = [point] }
                        else if stroke.count < 500, shouldAppend(point) { stroke.append(point) }
                    }
                    .onEnded { _ in
                        guard editable, !stroke.isEmpty else { return }
                        let finalKind: PainMarkKind = (kind == .line || kind == .radiating) && stroke.count < 2 ? .point : kind
                        marks.append(PainMark(angle: angle, kind: finalKind, points: stroke))
                        stroke = []
                    }, including: editable ? .all : .none)
            }.aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 30))
                .overlay { RoundedRectangle(cornerRadius: 30).strokeBorder(CX.moonlight.opacity(0.22), lineWidth: 1) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(region.rawValue)\(angle.rawValue)位置图")
                .accessibilityHint(kind.instruction)
                .accessibilityIdentifier("pain-marking-surface")
            Text(angle.orientation).font(.caption).foregroundStyle(CX.muted)
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
            let strokeColor = CX.coral
            context.stroke(path, with: .color(strokeColor.opacity(0.13)), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
            if kind == .radiating, let last = points.last {
                let end = CGPoint(x: last.x * size.width, y: last.y * size.height)
                context.fill(Path(ellipseIn: CGRect(x: start.x - 11, y: start.y - 11, width: 22, height: 22)), with: .color(strokeColor.opacity(0.16)))
                context.fill(Path(ellipseIn: CGRect(x: start.x - 4, y: start.y - 4, width: 8, height: 8)), with: .color(strokeColor))
                for radius: CGFloat in [12, 20] {
                    context.stroke(Path(ellipseIn: CGRect(x: end.x - radius, y: end.y - radius, width: radius * 2, height: radius * 2)), with: .color(strokeColor.opacity(radius == 12 ? 0.32 : 0.16)), lineWidth: 2)
                }
            }
        }
    }
}

private struct PainHistoryView: View {
    let journal: PainJournal
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            if let error = journal.readError { Text(error).foregroundStyle(CX.coral) }
            if journal.records.isEmpty { ContentUnavailableView("还没有疼痛记录", systemImage: "figure.stand", description: Text("用图记下感受，以后可以回来对照。")) }
            ForEach(journal.records) { record in
                NavigationLink {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(record.summary).font(.title3)
                            if record.marks.contains(where: \.hasSurfaceLocation) {
                                LegacySurfaceMarkSummary(count: record.marks.filter(\.hasSurfaceLocation).count)
                            }
                            ForEach(PainAngle.allCases.filter { angle in record.marks.contains { $0.angle == angle && !$0.hasSurfaceLocation } }) { angle in
                                Text(angle.rawValue).font(.headline)
                                PainMarkingSurface(region: record.region, angle: angle, kind: .point, marks: .constant(record.marks), editable: false)
                            }
                            Text(record.note)
                            if let assessment = record.assessment { PainAssessmentSummary(assessment: assessment) }
                        }.padding(20).frame(maxWidth: 680)
                    }.navigationTitle(record.region.rawValue)
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(record.summary)
                        Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(CX.muted)
                    }.padding(.vertical, 8)
                }
            }
        }.navigationTitle("疼痛记录")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
    }
}

#Preview("身体感受 · 原生独立页面") {
    NavigationStack { PainLocationView() }
}
