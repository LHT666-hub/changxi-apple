import SwiftUI
import Charts

struct HealthView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var section = "概览"

    var body: some View {
        Page(illustrated: section == "概览") {
            Picker("健康页面", selection: $section) {
                ForEach(["概览", "趋势", "报告", "计划"], id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)

            switch section {
            case "趋势":
                TrendContent()
            case "报告":
                ReportListContent()
            case "计划":
                planContent
            default:
                overview
            }
        }
        .navigationTitle("健康")
        .toolbar {
            if auth.isAuthenticated {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { MessagesView() } label: {
                        Image(systemName: "envelope")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("消息中心")
                }
            }
        }
        .task { await syncOnAppear() }
    }

    @MainActor
    private func syncOnAppear() async {
        guard AppConfiguration.useRemoteAPI, AppConfiguration.supportsExtendedAPI else { return }
        let pid = PatientContext.effectiveID(auth)
        await PatientContext.bindProfileIfNeeded(auth: auth, name: store.data.name, person: store.data.person)
        await HealthSyncService.shared.pullRemote(store: store, patientID: pid)
    }

    private var overview: some View {
        Group {
            Text("健康概览")
                .font(CXTypography.display)

            NavigationLink { HealthPortraitView() } label: {
                HStack(alignment: .center, spacing: CXSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(CX.actionPrimary.opacity(0.08))
                            .frame(width: 62, height: 62)
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.title2.weight(.medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(CX.actionPrimary)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("我的健康画像")
                            .font(CXTypography.title)
                            .foregroundStyle(CX.ink)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(store.data.readings.isEmpty ? "待记录" : "\(recordedMetricCount) 项")
                            .font(CXTypography.section)
                            .foregroundStyle(CX.actionPrimary)
                        Text(store.data.readings.isEmpty ? "暂无数据" : "已记录")
                            .font(CXTypography.micro)
                            .foregroundStyle(CX.muted)
                    }
                }
                .padding(CXSpacing.lg)
                .cxContentSurface(cornerRadius: CXRadius.lg)
            }
            .buttonStyle(QuietPressButton())
            .accessibilityIdentifier("open-health-portrait")

            SectionEyebrow(title: "关键指标")
            CXGlassGroup(spacing: CXSpacing.sm) {
                LazyVGrid(
                    columns: typeSize.isAccessibilitySize
                        ? [GridItem(.flexible())]
                        : [GridItem(.adaptive(minimum: 150), spacing: CXSpacing.sm)],
                    spacing: CXSpacing.sm
                ) {
                    ForEach(MetricKind.allCases) { kind in
                        NavigationLink { MetricDetailView(kind: kind) } label: {
                            MetricSummaryTile(
                                kind: kind,
                                value: store.latest(kind)?.display ?? "—"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("metric-\(kind.rawValue)")
                    }

                    NavigationLink { BMIDetailView() } label: {
                        BMISummaryTile(result: store.currentBMI)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("metric-BMI")
                }
            }

            SectionEyebrow(title: "身体感受")
            NavigationLink { PainLocationView() } label: {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: "figure.stand")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(CX.statusCritical)
                        .frame(width: 46, height: 46)
                        .background(CX.statusCritical.opacity(0.08), in: Circle())

                    Text("标注不舒服的位置")
                        .font(CXTypography.section)
                        .foregroundStyle(CX.ink)

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CX.faint)
                }
                .padding(CXSpacing.md)
                .background(
                    LinearGradient(
                        colors: [CX.surface, CX.statusCritical.opacity(0.025)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: .rect(cornerRadius: CXRadius.md, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous)
                        .strokeBorder(CX.statusCritical.opacity(0.10), lineWidth: 0.5)
                }
            }
            .buttonStyle(QuietPressButton())
            .accessibilityIdentifier("open-pain-location")

            SectionEyebrow(title: "最近变化", action: "血压 · 7 天")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                HStack {
                    Text("血压趋势")
                        .font(CXTypography.section)
                    Spacer()
                    NavigationLink { MetricDetailView(kind: .pressure) } label: {
                        Text("查看明细")
                            .font(CXTypography.meta.weight(.semibold))
                            .foregroundStyle(CX.actionPrimary)
                    }
                }

                HealthChart(
                    readings: store.readings(.pressure, days: 7),
                    kind: .pressure
                )
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)
        }
    }

    private var recordedMetricCount: Int {
        Set(store.data.readings.map(\.kind)).count
    }

    private var planContent: some View {
        Group {
            Text("今日计划")
                .font(CXTypography.display)

            VStack(alignment: .leading, spacing: CXSpacing.md) {
                RhythmView(completed: store.completed, total: store.data.plans.count)
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "管理")
            HStack(spacing: CXSpacing.sm) {
                NavigationLink { PlanView() } label: {
                    HealthActionTile(
                        title: "今日计划",
                        subtitle: "查看与完成",
                        icon: "calendar",
                        tint: CX.actionPrimary
                    )
                }
                .buttonStyle(QuietPressButton())

                NavigationLink { MedicationView() } label: {
                    HealthActionTile(
                        title: "用药记录",
                        subtitle: "计划与历史",
                        icon: "pills",
                        tint: CX.statusPositive
                    )
                }
                .buttonStyle(QuietPressButton())
            }
        }
    }
}

private struct HealthActionTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: CXSpacing.sm) {
            Image(systemName: icon)
                .font(.title3.weight(.medium))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.08), in: .rect(cornerRadius: 13, style: .continuous))

            Text(title)
                .font(CXTypography.section)
                .foregroundStyle(CX.ink)

            Text(subtitle)
                .font(CXTypography.meta)
                .foregroundStyle(CX.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(CXSpacing.md)
        .cxContentSurface(cornerRadius: CXRadius.md)
    }
}

private struct BMISummaryTile: View {
    let result: BMIResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.arms.open")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CX.statusPositive)
                Text("BMI")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CX.faint)
            }

            Text(result?.display ?? "—")
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(.numericText())

            Text(result.map { "kg/m² · \($0.classification.rawValue)" } ?? "等待体重记录")
                .font(.caption)
                .foregroundStyle(CX.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .cxContentSurface(cornerRadius: CXRadius.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let result else { return "BMI，等待体重记录" }
        return "BMI \(result.display)，\(result.classification.rawValue)"
    }
}

struct BMIDetailView: View {
    @Environment(AppStore.self) private var store

    private var result: BMIResult? { store.currentBMI }
    private var latestWeight: HealthReading? { store.latest(.weight) }

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("体质指数")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)

                Text("看懂当前 BMI，也看懂它从哪里来")
                    .font(CXTypography.display)

                Text("BMI 由最新体重和档案身高自动计算，只用于体重状况筛查。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            VStack(alignment: .leading, spacing: CXSpacing.md) {
                Text("当前 BMI")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.muted)

                if let result {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(result.display)
                            .font(CXTypography.display)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("kg/m²")
                            .font(CXTypography.supporting)
                            .foregroundStyle(CX.muted)
                    }

                    Label(result.classification.rawValue, systemImage: result.classification.systemImage)
                        .font(CXTypography.supporting.weight(.semibold))
                        .foregroundStyle(result.classification.tint)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 34)
                        .background(result.classification.tint.opacity(0.09), in: Capsule())

                    if let latestWeight {
                        Text("按最新体重 \(latestWeight.display) kg 与身高 \(heightDisplay) cm 计算")
                            .font(CXTypography.meta)
                            .foregroundStyle(CX.muted)
                    }
                } else {
                    CXEmptyState(
                        title: "还不能计算 BMI",
                        message: "先添加一条体重记录，BMI 会自动出现。",
                        icon: "scalemass"
                    )
                }
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)
            .accessibilityElement(children: .combine)

            SectionEyebrow(title: "中国成人 BMI 分级")
            VStack(spacing: 0) {
                ForEach(Array(BMIClassification.allCases.enumerated()), id: \.element) { index, classification in
                    BMIRangeRow(
                        classification: classification,
                        isCurrent: result?.classification == classification
                    )
                    if index < BMIClassification.allCases.count - 1 {
                        Divider().overlay(CX.separator.opacity(0.14))
                    }
                }
            }
            .padding(.horizontal, CXSpacing.md)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "计算依据")
            VStack(spacing: CXSpacing.sm) {
                NavigationLink { MetricDetailView(kind: .weight) } label: {
                    HStack(spacing: CXSpacing.md) {
                        Image(systemName: "scalemass")
                            .foregroundStyle(CX.actionPrimary)
                            .frame(width: 42, height: 42)
                            .background(CX.actionPrimary.opacity(0.08), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(latestWeight.map { "体重 \($0.display) kg" } ?? "添加体重记录")
                                .font(CXTypography.section)
                            Text(latestWeight.map { "更新于 \($0.date.formatted(date: .abbreviated, time: .shortened))" } ?? "BMI 需要最新体重")
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

                NavigationLink { AccountView() } label: {
                    HStack(spacing: CXSpacing.md) {
                        Image(systemName: "ruler")
                            .foregroundStyle(CX.statusPositive)
                            .frame(width: 42, height: 42)
                            .background(CX.statusPositive.opacity(0.08), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("身高 \(heightDisplay) cm")
                                .font(CXTypography.section)
                            Text("资料有变化时可在个人资料中修改")
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

            Text("BMI = 体重（kg）÷ 身高（m）²。依据现行《成人体重判定》WS/T 428—2013，适用于 18 岁及以上一般成人；特殊人群需结合专业评估。")
                .font(CXTypography.meta)
                .foregroundStyle(CX.muted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .navigationTitle("BMI")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heightDisplay: String {
        store.data.heightCentimeters.formatted(.number.precision(.fractionLength(0...1)))
    }
}

private struct BMIRangeRow: View {
    let classification: BMIClassification
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCurrent ? "checkmark.circle.fill" : "circle.fill")
                .font(isCurrent ? .title3 : .caption2)
                .foregroundStyle(classification.tint)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(classification.rawValue)
                    .font(CXTypography.section)
                Text(classification.rangeDescription)
                    .font(CXTypography.supporting)
                    .monospacedDigit()
                    .foregroundStyle(CX.muted)
            }

            Spacer(minLength: 8)

            if isCurrent {
                Text("当前")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(classification.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(classification.tint.opacity(0.10), in: Capsule())
            }
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(classification.rawValue)，\(classification.rangeDescription)\(isCurrent ? "，当前所在区间" : "")")
    }
}

private extension BMIClassification {
    var tint: Color {
        switch self {
        case .underweight: CX.actionPrimary
        case .normal: CX.statusPositive
        case .overweight: CX.statusWarning
        case .obesity: CX.statusCritical
        }
    }

    var systemImage: String {
        switch self {
        case .underweight: "arrow.down.circle.fill"
        case .normal: "checkmark.seal.fill"
        case .overweight: "exclamationmark.circle.fill"
        case .obesity: "exclamationmark.triangle.fill"
        }
    }
}

private struct MetricSummaryTile: View {
    let kind: MetricKind
    let value: String

    private var tint: Color {
        switch kind {
        case .pressure: CX.statusCritical
        case .glucose: CX.statusWarning
        case .weight: CX.actionPrimary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: kind.icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                Text(kind.rawValue)
                    .font(CXTypography.supporting.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CX.faint)
            }

            Text(value)
                .font(CXTypography.title)
                .fontDesign(.rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(.numericText())

            Text(kind.unit)
                .font(CXTypography.micro)
                .foregroundStyle(CX.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(16)
        .cxContentSurface(cornerRadius: CXRadius.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct TrendContent: View {
    @Environment(AppStore.self) private var store
    @State private var kind = MetricKind.pressure
    @State private var days = 7

    var body: some View {
        VStack(alignment: .leading, spacing: CXSpacing.xs) {
            Text("趋势")
                .font(CXTypography.micro.weight(.semibold))
                .foregroundStyle(CX.actionPrimary)
                .tracking(0.6)
            Text("看变化，不只看一次数字")
                .font(CXTypography.display)
            Text("切换指标和时间范围，观察记录是否在发生持续变化。")
                .font(CXTypography.body)
                .foregroundStyle(CX.muted)
                .lineSpacing(5)
        }

        VStack(alignment: .leading, spacing: CXSpacing.md) {
            Picker("指标", selection: $kind) {
                ForEach(MetricKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("时间范围", selection: $days) {
                Text("7天").tag(7)
                Text("30天").tag(30)
                Text("90天").tag(90)
            }
            .pickerStyle(.segmented)
        }
        .padding(CXSpacing.lg)
        .cxContentSurface(cornerRadius: CXRadius.lg)

        VStack(alignment: .leading, spacing: CXSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.rawValue)
                        .font(CXTypography.title)
                    Text(kind.unit)
                        .font(CXTypography.meta)
                        .foregroundStyle(CX.muted)
                }

                Spacer()

                Text("\(store.readings(kind, days: days).count) 次记录")
                    .font(CXTypography.meta.weight(.semibold))
                    .foregroundStyle(CX.muted)
            }

            HealthChart(readings: store.readings(kind, days: days), kind: kind)
        }
        .padding(CXSpacing.lg)
        .cxContentSurface(cornerRadius: CXRadius.lg)

        NavigationLink { MetricDetailView(kind: kind) } label: {
            HStack {
                Text("查看全部记录")
                    .font(CXTypography.section)
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

struct HealthChart: View {
    var readings: [HealthReading]
    var kind: MetricKind
    var body: some View {
        if readings.isEmpty {
            CXEmptyState(title: "还没有记录", message: "添加一次测量后，最近的变化会从这里慢慢出现。", icon: "chart.xyaxis.line")
        } else {
            Chart {
                ForEach(readings) { reading in
                    LineMark(x: .value("日期", reading.date), y: .value(kind == .pressure ? "收缩压" : kind.rawValue, reading.value), series: .value("指标", kind == .pressure ? "收缩压" : kind.rawValue)).foregroundStyle(by: .value("指标", kind == .pressure ? "收缩压" : kind.rawValue)).symbol(.circle)
                    if let value = reading.secondary {
                        LineMark(x: .value("日期", reading.date), y: .value("舒张压", value), series: .value("指标", "舒张压")).foregroundStyle(by: .value("指标", "舒张压")).symbol(.circle)
                    }
                }
            }
            .chartForegroundStyleScale(range: [CX.statusCritical, CX.actionPrimary])
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
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("健康指标")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)
                Text(kind.rawValue)
                    .font(CXTypography.display)
                Text("先看最近一次，再看一段时间里的变化。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            VStack(alignment: .leading, spacing: CXSpacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(store.latest(kind)?.display ?? "—")
                        .font(CXTypography.display)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                    Text(kind.unit)
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.muted)
                }

                if let date = store.latest(kind)?.date {
                    Text("最近记录 · \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(CXTypography.meta)
                        .foregroundStyle(CX.muted)
                } else {
                    Text("还没有记录")
                        .font(CXTypography.meta)
                        .foregroundStyle(CX.muted)
                }

                Button("添加\(kind.rawValue)记录") {
                    showRecord = true
                }
                .buttonStyle(PrimaryButton())
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "变化趋势")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                Picker("时间范围", selection: $days) {
                    Text("7天").tag(7)
                    Text("30天").tag(30)
                    Text("90天").tag(90)
                }
                .pickerStyle(.segmented)

                HealthChart(
                    readings: store.readings(kind, days: days),
                    kind: kind
                )
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(
                title: "记录明细",
                action: "\(store.readings(kind, days: days).count) 条"
            )

            if store.readings(kind, days: days).isEmpty {
                CXEmptyState(
                    title: "这段时间还没有记录",
                    message: "添加一次测量后，记录会按时间出现在这里。",
                    icon: "list.bullet.clipboard"
                )
            } else {
                VStack(spacing: CXSpacing.sm) {
                    ForEach(store.readings(kind, days: days).reversed()) { reading in
                        HStack(alignment: .top, spacing: CXSpacing.md) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(reading.display) \(kind.unit)")
                                    .font(CXTypography.section)
                                    .monospacedDigit()

                                Text(reading.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(CXTypography.micro)
                                    .foregroundStyle(CX.muted)

                                if !reading.note.isEmpty {
                                    Text(reading.note)
                                        .font(CXTypography.supporting)
                                        .foregroundStyle(CX.muted)
                                }

                                if let sync = reading.syncState {
                                    HStack(spacing: 6) {
                                        Image(systemName: sync.systemImage)
                                        Text(sync.label)
                                        if sync == .failed || sync == .pending {
                                            Button("重试") {
                                                HealthSyncService.shared.enqueueUpload(
                                                    reading,
                                                    store: store,
                                                    patientID: PatientContext.effectiveID(auth)
                                                )
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                        }
                                    }
                                    .font(CXTypography.micro)
                                    .foregroundStyle(
                                        sync == .failed
                                            ? CX.statusCritical
                                            : sync == .synced
                                                ? CX.statusPositive
                                                : CX.muted
                                    )
                                }
                            }

                            Spacer()

                            Button(role: .destructive) {
                                deleteID = reading.id
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 40, height: 40)
                            }
                            .accessibilityLabel("删除\(reading.display)的记录")
                        }
                        .padding(CXSpacing.md)
                        .cxContentSurface(cornerRadius: CXRadius.md)
                    }
                }
            }

            Text("单次测量不能代替诊断。目标范围会因个人情况而不同，请以医生为你制定的计划为准。")
                .font(CXTypography.meta)
                .foregroundStyle(CX.muted)
                .lineSpacing(4)
        }
        .navigationTitle(kind.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRecord) {
            NavigationStack { RecordReadingView(kind: kind) }
        }
        .confirmationDialog(
            "删除这条测量记录？",
            isPresented: Binding(
                get: { deleteID != nil },
                set: { if !$0 { deleteID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除记录", role: .destructive) {
                if let id = deleteID {
                    store.data.readings.removeAll { $0.id == id }
                }
                deleteID = nil
            }
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
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("健康记录")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)

                Text("记录\(kind.rawValue)")
                    .font(CXTypography.display)

                Text("只记录事实，不在录入时替你判断结果。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            SectionEyebrow(title: "测量数值", action: kind.unit)
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                MeasurementField(
                    title: kind == .pressure ? "收缩压" : kind.rawValue,
                    unit: kind.unit
                ) {
                    TextField(kind == .pressure ? "例如 120" : "输入测量值", text: $value)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("reading-primary")
                }

                if kind == .pressure {
                    MeasurementField(title: "舒张压", unit: kind.unit) {
                        TextField("例如 80", text: $secondary)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("reading-secondary")
                    }
                }

                Divider().overlay(CX.separator.opacity(0.14))

                DatePicker("测量时间", selection: $date, in: ...Date.now)
                    .font(CXTypography.supporting)
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "补充说明", action: "可选")
            VStack(alignment: .leading, spacing: CXSpacing.sm) {
                TextField("例如：晨起、餐前、餐后或当时的感受", text: $note, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(CXSpacing.md)
                    .background(CX.raisedSurface, in: .rect(cornerRadius: CXRadius.sm, style: .continuous))

                Text("备注是为了帮助以后回看测量情境，不影响保存。")
                    .font(CXTypography.meta)
                    .foregroundStyle(CX.muted)
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.statusCritical)
                    .padding(CXSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CX.statusCritical.opacity(0.06), in: .rect(cornerRadius: CXRadius.md, style: .continuous))
            }

            if submitting {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("正在整理记录…")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.muted)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            Button("保存记录", action: save)
                .buttonStyle(PrimaryButton())
                .disabled(submitting)
                .accessibilityIdentifier("save-reading")

            HStack(alignment: .top, spacing: CXSpacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundStyle(CX.actionPrimary)
                Text("输入校验只用于避免明显录入错误，不代表医学正常范围。")
                    .font(CXTypography.meta)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(4)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CXSpacing.xs)
        }
        .navigationTitle("记录\(kind.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
        .fullScreenCover(item: $pendingWorkflow) { result in
            NavigationStack {
                WorkflowProgressView(result: result, onClose: {
                    pendingWorkflow = nil
                    dismiss()
                })
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

    private struct MeasurementField<Content: View>: View {
        let title: String
        let unit: String
        @ViewBuilder let content: Content

        init(title: String, unit: String, @ViewBuilder content: () -> Content) {
            self.title = title
            self.unit = unit
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(title)
                        .font(CXTypography.micro.weight(.semibold))
                        .foregroundStyle(CX.muted)
                    Spacer()
                    Text(unit)
                        .font(CXTypography.micro)
                        .foregroundStyle(CX.faint)
                }

                content
                    .font(CXTypography.numeric)
                    .padding(.horizontal, CXSpacing.md)
                    .frame(minHeight: 58)
                    .background(CX.raisedSurface, in: .rect(cornerRadius: CXRadius.sm, style: .continuous))
            }
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
