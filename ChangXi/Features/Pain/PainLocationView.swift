import SwiftUI

/// Native body-sensation entry used by the health portrait and Health tab.
struct PainLocationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var use3D = true
    @State private var voiceHint: String?
    @State private var voiceSurfaceBaseline: Set<UUID> = []
    @State private var assistantContextID = UUID()

    private var title: String {
        switch step {
        case 0: "哪里不舒服？"
        case 1: "\(draft.region.rawValue)，指给我看"
        case 2: "疼痛感觉和强度"
        default: "这样记，对吗？"
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
                    if step > 1 {
                        footer.padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: 680)
            .padding(20)
            .padding(.bottom, step == 1 && !saved ? 172 : 24)
            .frame(maxWidth: .infinity)
            .id(step)
        }
        .cxMoonScreenBackground(illustrated: true)
        .navigationTitle("身体感受")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { history = true } label: { Image(systemName: "clock.arrow.circlepath") }
                    .accessibilityLabel("查看疼痛记录")
            }
        }
        .overlay(alignment: .bottom) {
            if step == 1 && !saved {
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
                        voiceSurfaceBaseline = Set(draft.marks.filter(\.hasSurfaceLocation).map(\.id))
                        draft.marks.append(contentsOf: marks)
                        angle = selectedAngle
                        voiceHint = marks.last?.name
                        use3D = true
                        advance(1)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $enlarged) {
            NavigationStack {
                VStack(spacing: 20) {
                    anglePicker
                    PainMarkingSurface(region: draft.region, angle: angle, kind: kind, marks: $draft.marks)
                    markTools
                }
                .padding(20)
                .cxMoonScreenBackground()
                .navigationTitle("放大标记")
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
                Image("ChangXiCharacter").resizable().scaledToFit().frame(width: 56, height: 56)
                Text("不用急着说清楚，\n我陪你一点点记下来。")
                    .font(.subheadline).foregroundStyle(CX.muted)
            }
            Text(saved ? "这次感受，记下来了" : title)
                .font(.largeTitle.weight(.semibold)).fontDesign(.serif)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var regionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 14) {
            ForEach(PainRegion.allCases) { region in
                Button {
                    draft = PainRecord(region: region)
                    angle = region == .back ? .back : .front
                    advance(1)
                } label: {
                    VStack(spacing: 12) {
                        PainRegionThumbnail(region: region)
                            .frame(height: 135).clipShape(.rect(cornerRadius: 24))
                        HStack {
                            Text(region.rawValue).font(.headline)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(CX.muted)
                        }
                    }
                    .padding(14)
                    .cxInteractiveGlass(cornerRadius: 28)
                    .contentShape(.rect(cornerRadius: 28))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("pain-region-\(region.anatomyAssetName)")
            }
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
                Image("ChangXiCharacter").resizable().scaledToFit().frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title2.weight(.semibold)).fontDesign(.serif)
                    Text("先转到看得清的位置，再切到“标记疼处”。")
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
                .accessibilityLabel("说给常曦听，再在模型上确认")
            }
            Picker("位置展示", selection: $use3D) {
                Text("局部三维").tag(true)
                Text("插画标记").tag(false)
            }.pickerStyle(.segmented)
            if use3D {
                Label("\(draft.region.rawValue)局部模型", systemImage: "view.3d")
                    .font(.subheadline.weight(.semibold))
                PainBody3DView(region: draft.region, marks: $draft.marks)
                if draft.marks.isEmpty {
                    Button { voiceLocation = true } label: {
                        Label("不方便点？说给常曦听", systemImage: "waveform.badge.mic")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Label("位置已在模型上确认", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CX.teal)
                }
                if let voiceHint {
                    Card {
                        Label("常曦听到：\(voiceHint)", systemImage: "waveform.badge.mic")
                            .font(.headline).foregroundStyle(CX.blue)
                        Text("语音先确定大致位置。请转动模型，再点、圈或沿着疼痛方向划一下，位置会更准确。")
                            .font(.subheadline).foregroundStyle(CX.muted)
                        Button("我已在三维人体上核对") { finishVoice3DCheck() }
                            .frame(minHeight: 44)
                            .disabled(surfaceIndexForDetail == nil)
                    }
                }
                if surfaceIndexForDetail != nil { preciseAreaPicker }
            } else {
                Text("选择视角后，点一下、圈一片，或沿疼痛方向划线。")
                    .font(.body).foregroundStyle(CX.muted)
                anglePicker
                PainMarkingSurface(region: draft.region, angle: angle, kind: kind, marks: $draft.marks)
                    .id(angle)
                    .transition(.opacity)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: angle)
                HStack {
                    Label("已标记 \(draft.marks.count) 处", systemImage: "smallcircle.filled.circle")
                        .foregroundStyle(CX.coral)
                    Spacer()
                    Button { enlarged = true } label: { Label("放大", systemImage: "arrow.up.left.and.arrow.down.right") }
                }.font(.subheadline)
                markTools
                if draft.region == .head { landmarks }
            }
            Text("以你自己的身体左右为准。标记只表达你感到疼的位置。")
                .font(.footnote).foregroundStyle(CX.muted)
        }
    }

    private var markTools: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], spacing: 8) {
                ForEach(PainMarkKind.allCases) { tool in
                    Button { kind = tool } label: {
                        Label(tool.label, systemImage: tool.symbol)
                            .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 48)
                            .background(kind == tool ? CX.blue.opacity(0.14) : CX.surface, in: .rect(cornerRadius: 16))
                    }.buttonStyle(.plain).accessibilityAddTraits(kind == tool ? .isSelected : [])
                }
            }
            Button {
                if let index = draft.marks.lastIndex(where: { $0.angle == angle }) { draft.marks.remove(at: index) }
            } label: { Label("撤销这个视角的上一笔", systemImage: "arrow.uturn.backward").frame(minHeight: 44) }
                .disabled(!draft.marks.contains(where: { $0.angle == angle }))
        }
    }

    private var landmarks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("也可以直接选位置").font(.subheadline).foregroundStyle(CX.muted)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128))]) {
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
                PainBody3DView(region: draft.region, marks: .constant(draft.marks), editable: false)
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
                Button("重新指位置") { advance(1) }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("上一步") { advance(step - 1) }.frame(minWidth: 80, minHeight: 48)
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
        .padding(10)
        .background(.regularMaterial, in: .rect(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.66), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
    }

    private var success: some View {
        Card {
            Label("已保存在这台设备", systemImage: "checkmark.circle.fill").foregroundStyle(CX.teal)
            Text(draft.summary).font(.title3)
            Button("再记一个部位") { draft = PainRecord(); saved = false; advance(0) }.buttonStyle(PrimaryButton())
            Button("查看记录本") { history = true }
        }
    }

    private var preciseAreaPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("再注明具体部位").font(.subheadline.weight(.semibold))
            Text("先在模型上标记，再选最接近的名称；不确定可以不选。")
                .font(.caption).foregroundStyle(CX.muted)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 8)], spacing: 8) {
                ForEach(detailedAreas, id: \.self) { area in
                    Button(area) {
                        guard let index = surfaceIndexForDetail else { return }
                        draft.marks[index].name = area
                        finishVoice3DCheck()
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .disabled(surfaceIndexForDetail == nil)
                }
            }
        }
    }

    private var detailedAreas: [String] {
        switch draft.region {
        case .head: ["头顶", "额头", "左太阳穴", "右太阳穴", "眼眶周围", "耳周", "面颊", "下颌", "后脑勺"]
        case .neck: ["颈前", "颈侧", "后颈", "左肩", "右肩", "锁骨周围"]
        case .torso: ["胸口正中", "左胸", "右胸", "上腹", "肚脐周围", "下腹", "左侧腹", "右侧腹"]
        case .back: ["左肩胛", "右肩胛", "上背", "脊柱周围", "左腰", "右腰", "骶尾部"]
        case .arms: ["肩关节", "上臂", "肘部", "前臂", "手腕", "手掌", "手背", "手指"]
        case .legs: ["髋部", "大腿", "膝前", "膝后", "小腿", "脚踝", "脚背", "脚底", "脚趾"]
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

    private func finishVoice3DCheck() {
        guard let hint = voiceHint,
              let surfaceIndex = surfaceIndexForDetail else { return }
        if draft.marks[surfaceIndex].name == "三维表面自选位置" ||
            draft.marks[surfaceIndex].name == "三维表面圈选范围" ||
            draft.marks[surfaceIndex].name == "三维表面疼痛走向" ||
            draft.marks[surfaceIndex].name == "三维表面放射路径" {
            draft.marks[surfaceIndex].name = hint
        }
        draft.marks.removeAll { !$0.hasSurfaceLocation && $0.name == hint }
        voiceHint = nil
        voiceSurfaceBaseline = []
    }

    private var surfaceIndexForDetail: Int? {
        if voiceHint != nil {
            return draft.marks.lastIndex { $0.hasSurfaceLocation && !voiceSurfaceBaseline.contains($0.id) }
        }
        return draft.marks.lastIndex(where: \.hasSurfaceLocation)
    }

    private func advance(_ value: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { step = value }
    }
}

/// Warm clay-style editorial art for the six region entry cards. Each region
/// is a separate asset so its scale remains consistent and cannot reveal an
/// adjacent atlas cell while the card animates.
private struct PainRegionThumbnail: View {
    let region: PainRegion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false

    private var assetName: String {
        switch region {
        case .head: "PainRegionHead"
        case .neck: "PainRegionNeck"
        case .torso: "PainRegionTorso"
        case .back: "PainRegionBack"
        case .arms: "PainRegionArms"
        case .legs: "PainRegionLegs"
        }
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .scaleEffect(isFloating ? 1.012 : 0.995)
            .offset(y: isFloating ? -1.5 : 1.5)
            .clipped()
            .overlay {
                LinearGradient(
                    colors: [.white.opacity(0.16), .clear, CX.moonlight.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .allowsHitTesting(false)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                    isFloating = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// Neutral medical diagram used for both region cards and 2D marking.
/// It deliberately avoids generated faces, nudity, and diagnostic anatomy claims.
struct PainArtwork: View {
    let region: PainRegion
    let angle: PainAngle
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.white.opacity(0.92), CX.moonlight.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            PainAnatomyIllustrationView(region: region, angle: angle)
                .padding(8)
        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
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
                        else if stroke.count < 1500 { stroke.append(point) }
                    }
                    .onEnded { _ in
                        guard editable, !stroke.isEmpty else { return }
                        marks.append(PainMark(angle: angle, kind: stroke.count < 3 ? .point : kind, points: stroke))
                        stroke = []
                    }, including: editable ? .all : .none)
            }.aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 30))
                .overlay { RoundedRectangle(cornerRadius: 30).strokeBorder(CX.moonlight.opacity(0.22), lineWidth: 1) }
                .accessibilityLabel("\(region.rawValue)\(angle.rawValue)位置图")
            Text(angle.orientation).font(.caption).foregroundStyle(CX.muted)
        }
    }

    private func paint(_ points: [PainCoordinate], kind: PainMarkKind, context: inout GraphicsContext, size: CGSize) {
        guard let first = points.first else { return }
        let start = CGPoint(x: first.x * size.width, y: first.y * size.height)
        if kind == .point || points.count < 3 {
            context.fill(Path(ellipseIn: CGRect(x: start.x - 17, y: start.y - 17, width: 34, height: 34)), with: .color(CX.coral.opacity(0.18)))
            context.fill(Path(ellipseIn: CGRect(x: start.x - 6, y: start.y - 6, width: 12, height: 12)), with: .color(CX.coral))
        } else {
            var path = Path(); path.move(to: start)
            for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height)) }
            if kind == .area { path.closeSubpath(); context.fill(path, with: .color(CX.coral.opacity(0.16))) }
            let strokeColor = kind == .radiating ? Color.orange : CX.coral
            context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            if kind == .radiating, let last = points.last {
                let end = CGPoint(x: last.x * size.width, y: last.y * size.height)
                context.fill(Path(ellipseIn: CGRect(x: end.x - 10, y: end.y - 10, width: 20, height: 20)), with: .color(strokeColor.opacity(0.20)))
                context.fill(Path(ellipseIn: CGRect(x: end.x - 4, y: end.y - 4, width: 8, height: 8)), with: .color(strokeColor))
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
                                PainBody3DView(region: record.region, marks: .constant(record.marks), editable: false)
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
