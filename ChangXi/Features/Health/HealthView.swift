import SwiftUI
import Charts

struct HealthView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var section = "概览"
    var body: some View {
        Page {
            Picker("健康页面", selection: $section) { ForEach(["概览", "趋势", "报告", "计划"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
            switch section {
            case "趋势": TrendContent()
            case "报告": ReportListContent()
            case "计划":
                Card { RhythmView(completed: store.completed, total: store.data.plans.count) }
                NavigationLink { PlanView() } label: { Card { RowLabel(title: "查看今日计划", subtitle: "用药、运动和日常记录", icon: "calendar") } }.buttonStyle(.plain)
                NavigationLink { MedicationView() } label: { Card { RowLabel(title: "用药管理", icon: "pills") } }.buttonStyle(.plain)
            default: overview
            }
            DemoLabel()
        }.navigationTitle("健康")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink { MessagesView() } label: { Image(systemName: "envelope").frame(width: 44, height: 44) }.accessibilityLabel("消息中心") } }
        .task { await syncOnAppear() }
    }
    /// Task #25：进入健康页时，一次性 best-effort 绑定患者档案并拉取云端测量历史（本地优先合并去重）。
    /// 离线（`useRemoteAPI == false`）时不发任何请求。
    @MainActor private func syncOnAppear() async {
        guard AppConfiguration.useRemoteAPI, AppConfiguration.supportsExtendedAPI else { return }
        let pid = PatientContext.effectiveID(auth)
        await PatientContext.bindProfileIfNeeded(auth: auth, name: store.data.name, person: store.data.person)
        await HealthSyncService.shared.pullRemote(store: store, patientID: pid)
    }
    private var overview: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                Text("健康摘要")
                    .font(.largeTitle.weight(.semibold))
                    .fontDesign(.serif)
                Text("每一次记录，都让变化更容易被看见。")
                    .font(.body)
                    .foregroundStyle(CX.muted)
            }

            NavigationLink { HealthPortraitView() } label: {
                Card {
                    RowLabel(
                        title: "我的健康画像",
                        subtitle: "整体较稳定 · 有 2 项值得关注",
                        icon: "circle.hexagongrid.fill",
                        tint: CX.blue
                    )
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("open-health-portrait")

            CXGlassGroup(spacing: 12) {
                LazyVGrid(
                    columns: typeSize.isAccessibilitySize
                        ? [GridItem(.flexible())]
                        : [GridItem(.adaptive(minimum: 150), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(MetricKind.allCases) { kind in
                        NavigationLink { MetricDetailView(kind: kind) } label: {
                            MetricSummaryTile(
                                kind: kind,
                                value: store.latest(kind)?.display ?? "—"
                            )
                        }.buttonStyle(.plain).accessibilityIdentifier("metric-\(kind.rawValue)")
                    }
                }
            }
            SectionEyebrow(title: "身体感受", action: "本机记录")
            NavigationLink { PainLocationView() } label: {
                Card {
                    RowLabel(
                        title: "疼痛位置记录",
                        subtitle: "选择身体区域，并在体表图上标注具体位置",
                        icon: "figure.stand",
                        tint: CX.coral
                    )
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("open-pain-location")
            SectionEyebrow(title: "最近趋势", action: "7 天")
            Card {
                NavigationLink { MetricDetailView(kind: .pressure) } label: { RowLabel(title: "血压趋势", subtitle: "最近 7 天 · mmHg", icon: "chart.xyaxis.line") }.buttonStyle(.plain)
                HealthChart(readings: store.readings(.pressure, days: 7), kind: .pressure)
            }
            NavigationLink { PlanView() } label: { Card { RhythmView(completed: store.completed, total: store.data.plans.count) } }.buttonStyle(.plain)
            NavigationLink { ReportDetailView() } label: { Card { RowLabel(title: "体检报告已整理", subtitle: "查看数值、参考范围和关注事项", icon: "doc.text.magnifyingglass") } }.buttonStyle(.plain)
        }
    }
}

private struct MetricSummaryTile: View {
    let kind: MetricKind
    let value: String

    private var tint: Color {
        switch kind {
        case .pressure: CX.coral
        case .glucose: CX.gold
        case .weight: CX.blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: kind.icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                Text(kind.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CX.faint)
            }

            Text(value)
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(.numericText())

            Text(kind.unit)
                .font(.caption)
                .foregroundStyle(CX.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .cxInteractiveGlass(cornerRadius: 18)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct TrendContent: View {
    @Environment(AppStore.self) private var store
    @State private var kind = MetricKind.pressure
    @State private var days = 7
    var body: some View {
        Picker("指标", selection: $kind) { ForEach(MetricKind.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
        Picker("时间范围", selection: $days) { Text("7天").tag(7); Text("30天").tag(30); Text("90天").tag(90) }.pickerStyle(.segmented)
        Card {
            Text("\(kind.rawValue) · \(kind.unit)").font(.title2.bold())
            HealthChart(readings: store.readings(kind, days: days), kind: kind)
            Text("共 \(store.readings(kind, days: days).count) 次记录").foregroundStyle(CX.muted)
        }
        NavigationLink { MetricDetailView(kind: kind) } label: { Card { RowLabel(title: "查看记录明细", icon: "list.bullet") } }.buttonStyle(.plain)
    }
}

struct HealthChart: View {
    var readings: [HealthReading]
    var kind: MetricKind
    var body: some View {
        if readings.isEmpty {
            ContentUnavailableView("还没有记录", systemImage: "chart.xyaxis.line", description: Text("添加一次测量，开始记录你的月影。"))
        } else {
            Chart {
                ForEach(readings) { reading in
                    LineMark(x: .value("日期", reading.date), y: .value(kind == .pressure ? "收缩压" : kind.rawValue, reading.value), series: .value("指标", kind == .pressure ? "收缩压" : kind.rawValue)).foregroundStyle(by: .value("指标", kind == .pressure ? "收缩压" : kind.rawValue)).symbol(.circle)
                    if let value = reading.secondary {
                        LineMark(x: .value("日期", reading.date), y: .value("舒张压", value), series: .value("指标", "舒张压")).foregroundStyle(by: .value("指标", "舒张压")).symbol(.circle)
                    }
                }
            }
            .chartForegroundStyleScale(range: [CX.coral, CX.blue])
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.month().day()) } }
            .frame(height: 215)
            .accessibilityLabel("\(kind.rawValue)趋势，\(readings.count)次记录。可在记录明细查看所有数值。")
        }
    }
}

struct MetricDetailView: View {
    var kind: MetricKind
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @State private var days = 7
    @State private var showRecord = false
    @State private var deleteID: UUID?
    var body: some View {
        Page {
            Card {
                Text("最近记录").foregroundStyle(CX.muted)
                HStack(alignment: .firstTextBaseline) { Text(store.latest(kind)?.display ?? "—").font(.largeTitle.bold()); Text(kind.unit).foregroundStyle(CX.muted) }
                if let date = store.latest(kind)?.date { Text(date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(CX.muted) }
                Button("添加\(kind.rawValue)记录") { showRecord = true }.buttonStyle(PrimaryButton())
            }
            Picker("时间范围", selection: $days) { Text("7天").tag(7); Text("30天").tag(30); Text("90天").tag(90) }.pickerStyle(.segmented)
            Card { HealthChart(readings: store.readings(kind, days: days), kind: kind) }
            Text("记录明细").font(.title2.bold())
            Card {
                ForEach(store.readings(kind, days: days).reversed()) { reading in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(reading.display) \(kind.unit)").font(.headline)
                            Text(reading.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(CX.muted)
                            if !reading.note.isEmpty { Text(reading.note).font(.subheadline) }
                            if let sync = reading.syncState {
                                HStack(spacing: 6) {
                                    Image(systemName: sync.systemImage).font(.caption2)
                                    Text(sync.label).font(.caption2)
                                    if sync == .failed || sync == .pending {
                                        Button("重试") { HealthSyncService.shared.enqueueUpload(reading, store: store, patientID: PatientContext.effectiveID(auth)) }
                                            .font(.caption2).buttonStyle(.bordered).controlSize(.mini)
                                    }
                                }
                                .foregroundStyle(sync == .failed ? CX.coral : sync == .synced ? CX.teal : CX.muted)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) { deleteID = reading.id } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("删除\(reading.display)的记录")
                    }
                    Divider()
                }
            }
            Text("单次测量不能代替诊断。目标范围会因个人情况而不同，请以医生为你制定的计划为准。").font(.footnote).foregroundStyle(CX.muted)
        }.navigationTitle(kind.rawValue)
        .sheet(isPresented: $showRecord) { NavigationStack { RecordReadingView(kind: kind) } }
        .confirmationDialog("删除这条测量记录？", isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } }), titleVisibility: .visible) {
            Button("删除记录", role: .destructive) { if let id = deleteID { store.data.readings.removeAll { $0.id == id } }; deleteID = nil }
        }
    }
}

struct RecordReadingView: View {
    var kind: MetricKind
    var onSave: (() -> Void)? = nil
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var secondary = ""
    @State private var note = ""
    @State private var date = Date.now
    @State private var error: String?
    @State private var submitting = false
    @State private var pendingWorkflow: EventWorkflowResult?
    var body: some View {
        Form {
            Section("\(kind.rawValue) · \(kind.unit)") {
                TextField(kind == .pressure ? "收缩压" : "测量值", text: $value).keyboardType(.decimalPad).accessibilityIdentifier("reading-primary")
                if kind == .pressure { TextField("舒张压", text: $secondary).keyboardType(.decimalPad).accessibilityIdentifier("reading-secondary") }
                DatePicker("测量时间", selection: $date, in: ...Date.now)
                TextField("备注，如晨起、餐前或餐后", text: $note, axis: .vertical)
            }
            if let error { Section { Text(error).foregroundStyle(CX.coral) } }
            if submitting {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在发起玄同会诊…").foregroundStyle(CX.muted)
                    }
                }
            }
            Section { Button("保存记录", action: save).accessibilityIdentifier("save-reading").disabled(submitting) }
            Section { Text("输入校验只用于避免录入错误，不代表医学正常范围。").font(.footnote) }
        }.navigationTitle("记录\(kind.rawValue)")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        .fullScreenCover(item: $pendingWorkflow) { result in
            NavigationStack {
                WorkflowProgressView(result: result, onClose: { pendingWorkflow = nil; dismiss() })
            }
        }
        .assistantFormContext(
            title: "\(kind.rawValue)记录",
            draft: [value, secondary, note].filter { !$0.isEmpty }.joined(separator: " / ")
        ) { input in
            if kind == .pressure {
                guard let reading = AssistantFillParser.bloodPressure(from: input) else { return false }
                value = reading.systolic
                secondary = reading.diastolic
                return true
            }
            guard let number = AssistantFillParser.singleNumber(from: input, range: kind.inputRange) else { return false }
            value = number
            return true
        }
    }
    private func save() {
        guard let number = Double(value.replacingOccurrences(of: ",", with: ".")), number.isFinite, kind.inputRange.contains(number) else { error = "请检查测量值，输入\(kind.inputRange.lowerBound.formatted())至\(kind.inputRange.upperBound.formatted())之间的数字。"; return }
        let second = Double(secondary)
        if kind == .pressure {
            guard let second, second >= 20, second <= 200, second < number else { error = "请核对舒张压，应低于收缩压。"; return }
        }
        let reading = HealthReading(kind: kind, value: number, secondary: kind == .pressure ? second : nil, date: date, note: note)
        store.data.readings.append(reading)
        onSave?()
        MoonHaptics.shared.play(success: true, enabled: store.data.haptics)
        // Task #25：本地记录已成功写入（离线也到此为止，保证纯本地可用）。以下为 best-effort 云端上行。
        guard AppConfiguration.useRemoteAPI else { dismiss(); return }
        let pid = PatientContext.effectiveID(auth)
        if HealthSyncService.triggersWorkflow(reading) {
            // 异常读数：上行并触发玄同会诊工作流，成功后弹出实时进度页。
            submitting = true
            Task { @MainActor in
                let result = await HealthSyncService.shared.uploadReading(reading, store: store, patientID: pid)
                submitting = false
                if let result, result.eventID != nil {
                    pendingWorkflow = result
                } else {
                    dismiss()
                }
            }
        } else {
            // 常规读数：后台静默上行（不弹窗、不阻断），失败仅标记「待同步」。
            HealthSyncService.shared.enqueueUpload(reading, store: store, patientID: pid)
            dismiss()
        }
    }
}
