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
        case 2: "是什么样的疼？"
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
                }
            }
            .frame(maxWidth: 680)
            .padding(20)
            .padding(.bottom, step > 0 && !saved ? 156 : 0)
            .frame(maxWidth: .infinity)
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
        // This screen lives inside the app's persistent custom tab bar. A
        // local overlay keeps the step controls visibly above that bar;
        // nested safe-area insets can otherwise place them off-screen.
        .overlay(alignment: .bottom) {
            if step > 0 && !saved {
                footer.padding(.bottom, 84)
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
                        PainArtwork(region: region, angle: region == .back ? .back : .front)
                            .frame(height: 135).clipShape(.rect(cornerRadius: 24))
                        HStack {
                            Text(region.rawValue).font(.headline)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(CX.muted)
                        }
                    }
                    .padding(14)
                    .cxInteractiveGlass(cornerRadius: 28)
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
                    Text("先选解剖层，再转动局部模型标记。")
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
                HStack {
                    Label("局部模型 · \(draft.region.rawValue)", systemImage: "view.3d")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("可切换解剖层").font(.caption.weight(.medium)).foregroundStyle(CX.blue)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(CX.blue.opacity(0.10), in: Capsule())
                }
                PainBody3DView(region: draft.region, marks: $draft.marks)
                Button { voiceLocation = true } label: {
                    Label("说给常曦听，再在模型上确认", systemImage: "waveform.badge.mic")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
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
                preciseAreaPicker
            } else {
            Text("点一下、圈一片，或沿着疼的位置划一条。")
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
                HStack(alignment: .firstTextBaseline) {
                    Text("有多疼").font(.title3.weight(.semibold))
                    Spacer()
                    if draft.intensityConfirmed == true {
                        Text("\(draft.intensity)").font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundStyle(CX.blue)
                        Text("/ 10").font(.subheadline).foregroundStyle(CX.muted)
                    } else { Text("尚未确认").foregroundStyle(CX.muted) }
                }
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
            Button(step == 3 ? "保存这次记录" : step == 1 ? "位置选好了" : "看看记录") {
                if step < 3 { advance(step + 1) }
                else {
                    do { draft.date = .now; try journal.save(draft); saved = true }
                    catch { self.error = journal.readError ?? "记录没有保存成功，请保留当前内容后重试。" }
                }
            }.buttonStyle(PrimaryButton()).disabled(step == 1 && draft.marks.isEmpty)
        }.padding(.horizontal, 20).padding(.vertical, 12).background(.regularMaterial)
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

/// Neutral medical diagram used for both region cards and 2D marking.
/// It deliberately avoids generated faces, nudity, and diagnostic anatomy claims.
struct PainArtwork: View {
    let region: PainRegion
    let angle: PainAngle
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.white.opacity(0.92), CX.moonlight.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            PainRegionDiagram(region: region, angle: angle)
                .padding(18)
        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
    }
}

private struct PainRegionDiagram: View {
    let region: PainRegion
    let angle: PainAngle
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let w = size.width, h = size.height
                let line = StrokeStyle(lineWidth: max(2, w * 0.018), lineCap: .round, lineJoin: .round)
                let ink = Color(red: 0.20, green: 0.31, blue: 0.43)
                let wash = CX.blue.opacity(0.13)
                var path = Path()
                switch region {
                case .head:
                    path.addEllipse(in: CGRect(x: w * 0.27, y: h * 0.10, width: w * 0.46, height: h * 0.58))
                    path.move(to: CGPoint(x: w * 0.39, y: h * 0.68)); path.addLine(to: CGPoint(x: w * 0.39, y: h * 0.84))
                    path.move(to: CGPoint(x: w * 0.61, y: h * 0.68)); path.addLine(to: CGPoint(x: w * 0.61, y: h * 0.84))
                    path.move(to: CGPoint(x: w * 0.20, y: h * 0.91)); path.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.91), control: CGPoint(x: w * 0.50, y: h * 0.76))
                case .neck:
                    path.addEllipse(in: CGRect(x: w * 0.36, y: h * 0.05, width: w * 0.28, height: h * 0.32))
                    path.move(to: CGPoint(x: w * 0.42, y: h * 0.36)); path.addLine(to: CGPoint(x: w * 0.40, y: h * 0.58))
                    path.move(to: CGPoint(x: w * 0.58, y: h * 0.36)); path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.58))
                    path.move(to: CGPoint(x: w * 0.08, y: h * 0.73)); path.addQuadCurve(to: CGPoint(x: w * 0.92, y: h * 0.73), control: CGPoint(x: w * 0.50, y: h * 0.48))
                    context.fill(Path(roundedRect: CGRect(x: w * 0.35, y: h * 0.34, width: w * 0.30, height: h * 0.34), cornerRadius: w * 0.10), with: .color(wash))
                case .torso, .back:
                    path.move(to: CGPoint(x: w * 0.17, y: h * 0.16)); path.addQuadCurve(to: CGPoint(x: w * 0.83, y: h * 0.16), control: CGPoint(x: w * 0.50, y: h * 0.04))
                    path.addLine(to: CGPoint(x: w * 0.70, y: h * 0.86)); path.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.86), control: CGPoint(x: w * 0.50, y: h * 0.94)); path.closeSubpath()
                    context.fill(path, with: .color(wash))
                    if region == .back { var spine = Path(); spine.move(to: CGPoint(x: w * 0.5, y: h * 0.2)); spine.addLine(to: CGPoint(x: w * 0.5, y: h * 0.82)); context.stroke(spine, with: .color(CX.blue.opacity(0.35)), style: StrokeStyle(lineWidth: 2, dash: [5, 5])) }
                case .arms:
                    path.move(to: CGPoint(x: w * 0.44, y: h * 0.12)); path.addCurve(to: CGPoint(x: w * 0.12, y: h * 0.86), control1: CGPoint(x: w * 0.30, y: h * 0.22), control2: CGPoint(x: w * 0.22, y: h * 0.62))
                    path.move(to: CGPoint(x: w * 0.56, y: h * 0.12)); path.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.86), control1: CGPoint(x: w * 0.70, y: h * 0.22), control2: CGPoint(x: w * 0.78, y: h * 0.62))
                    for p in [CGPoint(x:w*0.28,y:h*0.50), CGPoint(x:w*0.72,y:h*0.50)] { context.fill(Path(ellipseIn: CGRect(x:p.x-w*0.07,y:p.y-w*0.07,width:w*0.14,height:w*0.14)), with:.color(wash)) }
                case .legs:
                    path.move(to: CGPoint(x: w * 0.28, y: h * 0.08)); path.addCurve(to: CGPoint(x: w * 0.22, y: h * 0.91), control1: CGPoint(x: w * 0.31, y: h * 0.42), control2: CGPoint(x: w * 0.18, y: h * 0.65))
                    path.move(to: CGPoint(x: w * 0.72, y: h * 0.08)); path.addCurve(to: CGPoint(x: w * 0.78, y: h * 0.91), control1: CGPoint(x: w * 0.69, y: h * 0.42), control2: CGPoint(x: w * 0.82, y: h * 0.65))
                    for p in [CGPoint(x:w*0.27,y:h*0.53), CGPoint(x:w*0.73,y:h*0.53)] { context.fill(Path(ellipseIn: CGRect(x:p.x-w*0.07,y:p.y-w*0.07,width:w*0.14,height:w*0.14)), with:.color(wash)) }
                }
                context.stroke(path, with: .color(ink), style: line)
            }
        }
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
