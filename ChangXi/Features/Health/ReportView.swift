import SwiftUI

struct ReportListContent: View {
    @Environment(AppStore.self) private var store
    @State private var upload = false

    var body: some View {
        VStack(alignment: .leading, spacing: CXSpacing.xs) {
            Text("报告与资料")
                .font(CXTypography.display)
            Text("保留原始报告，再把值得关注的内容慢慢整理出来。")
                .font(CXTypography.body)
                .foregroundStyle(CX.muted)
                .lineSpacing(5)
        }

        if !store.data.importedReports.isEmpty {
            SectionEyebrow(title: "我的报告", action: "\(store.data.importedReports.count) 份")

            ForEach(store.data.importedReports.reversed()) { report in
                NavigationLink {
                    ImportedReportView(report: report)
                } label: {
                    ReportListRow(
                        title: report.title,
                        subtitle: report.date.formatted(date: .abbreviated, time: .omitted),
                        status: reportStatus(report),
                        icon: "doc.richtext",
                        tint: report.analysisText != nil || report.bpReading != nil ? CX.statusPositive : CX.actionPrimary
                    )
                }
                .buttonStyle(QuietPressButton())
            }
        }

        SectionEyebrow(title: "体验示例", action: "示例数据")
        NavigationLink { ReportDetailView() } label: {
            ReportListRow(
                title: "9月5日体检报告",
                subtitle: "3 组指标已整理",
                status: "1 项值得关注",
                icon: "doc.text.magnifyingglass",
                tint: CX.statusWarning
            )
        }
        .buttonStyle(QuietPressButton())

        Button {
            upload = true
        } label: {
            HStack {
                Label("添加体检报告", systemImage: "plus")
                Spacer()
                Text("拍照或从相册选择")
                    .font(CXTypography.meta)
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .buttonStyle(PrimaryButton())
        .sheet(isPresented: $upload) {
            NavigationStack { ReportImportView() }
        }

        if AppConfiguration.useRemoteAPI && AppConfiguration.supportsExtendedAPI {
            SectionEyebrow(title: "更多资料")
            NavigationLink { CloudDocumentsView() } label: {
                ReportListRow(
                    title: "云端文档",
                    subtitle: "只显示你主动归档的资料",
                    status: "可管理",
                    icon: "externaldrive.fill",
                    tint: CX.actionPrimary
                )
            }
            .buttonStyle(QuietPressButton())
        }
    }

    private func reportStatus(_ report: ImportedReport) -> String {
        if report.bpReading != nil { return "已识别血压" }
        if report.analysisText != nil { return "已整理" }
        return "原件已保存"
    }
}

private struct ReportListRow: View {
    let title: String
    let subtitle: String
    let status: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: CXSpacing.md) {
            Image(systemName: icon)
                .font(.title3.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.09), in: .rect(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(CXTypography.section)
                    .foregroundStyle(CX.ink)
                    .lineLimit(2)

                Text(subtitle)
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.muted)
            }

            Spacer(minLength: CXSpacing.sm)

            VStack(alignment: .trailing, spacing: 8) {
                Text(status)
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 28)
                    .background(tint.opacity(0.08), in: Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CX.faint)
            }
        }
        .padding(CXSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cxContentSurface(cornerRadius: CXRadius.md)
        .contentShape(Rectangle())
    }
}

struct ImportedReportView: View {
    var report: ImportedReport
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var deleting = false
    @State private var error: String?

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text(report.documentID == nil ? "本机报告" : "已归档报告")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)

                Text(report.title)
                    .font(CXTypography.display)

                Text(report.date.formatted(date: .long, time: .shortened))
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.muted)
            }

            SectionEyebrow(title: "报告原件", action: report.documentID == nil ? "保存在本机" : "本机 + 云端")
            originalReport

            if report.analysisText != nil || report.bpReading != nil || !(report.findings ?? []).isEmpty {
                SectionEyebrow(title: "整理结果", action: "请与原图核对")
                analysisContent
            } else {
                HStack(alignment: .top, spacing: CXSpacing.sm) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(CX.actionPrimary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("原件已保存")
                            .font(CXTypography.section)
                        Text("这份报告还没有自动整理。你仍可以保留原图，或把想问的问题带给家庭医生。")
                            .font(CXTypography.supporting)
                            .foregroundStyle(CX.muted)
                            .lineSpacing(4)
                    }
                    Spacer(minLength: 0)
                }
                .padding(CXSpacing.lg)
                .cxContentSurface(cornerRadius: CXRadius.lg)
            }

            SectionEyebrow(title: "下一步")
            NavigationLink { ConsultationView() } label: {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .foregroundStyle(CX.actionPrimary)
                        .frame(width: 40, height: 40)
                        .background(CX.actionPrimary.opacity(0.08), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("整理咨询问题")
                            .font(CXTypography.section)
                        Text("把报告里最想确认的内容先写下来")
                            .font(CXTypography.supporting)
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

            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.statusCritical)
            }

            Button(role: .destructive) {
                deleting = true
            } label: {
                Label("删除这份本机报告", systemImage: "trash")
                    .font(CXTypography.supporting.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .foregroundStyle(CX.statusCritical)
        }
        .navigationTitle("报告")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "删除这份报告及本机照片？",
            isPresented: $deleting,
            titleVisibility: .visible
        ) {
            Button("删除报告", role: .destructive) {
                do {
                    try store.deleteReport(report)
                    dismiss()
                } catch {
                    self.error = "报告未能删除，请稍后重试。"
                }
            }
        }
    }

    private var originalReport: some View {
        VStack(alignment: .leading, spacing: CXSpacing.md) {
            if let image = UIImage(contentsOfFile: store.reportURL(report).path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 420)
                    .clipShape(.rect(cornerRadius: CXRadius.md, style: .continuous))
                    .accessibilityLabel("原始报告照片")
            } else {
                ContentUnavailableView(
                    "照片暂时无法读取",
                    systemImage: "photo",
                    description: Text("可在设备解锁后重试。")
                )
                .frame(minHeight: 220)
            }

            if !report.note.isEmpty {
                Text(report.note)
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(4)
            }

            if report.documentID != nil {
                Label("已归档到云端文档", systemImage: "checkmark.icloud")
                    .font(CXTypography.meta.weight(.semibold))
                    .foregroundStyle(CX.statusPositive)
            }
        }
        .padding(CXSpacing.md)
        .cxContentSurface(cornerRadius: CXRadius.lg)
    }

    @ViewBuilder
    private var analysisContent: some View {
        VStack(alignment: .leading, spacing: CXSpacing.lg) {
            if let bp = report.bpReading {
                VStack(alignment: .leading, spacing: 8) {
                    Text("识别到的血压")
                        .font(CXTypography.micro.weight(.semibold))
                        .foregroundStyle(CX.muted)
                    Text(bp.display)
                        .font(CXTypography.display)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                    if bp.isLowConfidence {
                        Label("识别置信度较低，请对照原图核对。", systemImage: "exclamationmark.circle")
                            .font(CXTypography.meta)
                            .foregroundStyle(CX.statusWarning)
                    }
                }
            }

            if let analysis = report.analysisText, !analysis.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("常曦整理", systemImage: "sparkles")
                        .font(CXTypography.section)
                    Text(analysis)
                        .font(CXTypography.body)
                        .lineSpacing(5)
                }
            }

            if let findings = report.findings, !findings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("关注要点")
                        .font(CXTypography.section)
                    ForEach(findings, id: \.self) { finding in
                        HStack(alignment: .top, spacing: 9) {
                            Circle()
                                .fill(CX.statusWarning)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                            Text(finding)
                                .font(CXTypography.supporting)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(CXSpacing.lg)
        .cxContentSurface(cornerRadius: CXRadius.lg)
    }
}

struct ReportDetailView: View {
    @State private var showChat = false

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.sm) {
                Text("示例报告")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)

                Text("9月5日体检报告")
                    .font(CXTypography.display)

                HStack(spacing: CXSpacing.sm) {
                    Label("3 组指标", systemImage: "list.bullet.rectangle")
                    Label("1 项值得关注", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(CX.statusWarning)
                }
                .font(CXTypography.supporting)
                .foregroundStyle(CX.muted)
            }

            SectionEyebrow(title: "指标分组", action: "按原报告整理")
            ForEach(ReportGroup.examples) { group in
                NavigationLink { ReportGroupView(group: group) } label: {
                    ReportListRow(
                        title: group.name,
                        subtitle: group.summary,
                        status: group.flag,
                        icon: group.icon,
                        tint: group.flag == "需关注" ? CX.statusWarning : CX.statusPositive
                    )
                }
                .buttonStyle(QuietPressButton())
            }

            SectionEyebrow(title: "常曦整理")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                HStack(alignment: .top, spacing: CXSpacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(CX.actionPrimary)
                        .frame(width: 30, height: 30)
                    Text("这份示例报告中，LDL-C 高于报告所列参考上限。可以把完整报告和近期记录一起交给医生查看。")
                        .font(CXTypography.body)
                        .lineSpacing(5)
                }

                Text("参考区间来自本示例报告，并非个人治疗目标；不要仅凭这一页自行调整用药。")
                    .font(CXTypography.meta)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(4)
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            Button {
                showChat = true
            } label: {
                Label("继续问常曦", systemImage: "bubble.left.and.text.bubble.right")
            }
            .buttonStyle(PrimaryButton())

            NavigationLink { DoctorDetailView() } label: {
                ReportListRow(
                    title: "联系家庭医生",
                    subtitle: "带着原始报告和问题继续沟通",
                    status: "下一步",
                    icon: "stethoscope",
                    tint: CX.statusPositive
                )
            }
            .buttonStyle(QuietPressButton())
        }
        .navigationTitle("报告")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showChat) {
            NavigationStack { ChatView(initialPrompt: "我想了解这份体检报告") }
        }
    }
}

struct ReportGroup: Identifiable {
    var id: String { name }
    var name: String
    var summary: String
    var icon: String
    var flag: String
    var items: [ReportValue]
    static let examples = [
        ReportGroup(name: "血脂", summary: "总胆固醇 · LDL-C · 甘油三酯", icon: "drop.fill", flag: "需关注", items: [ReportValue(name: "LDL-C", value: "3.7", unit: "mmol/L", range: "< 3.4", flag: "高于参考上限"), ReportValue(name: "总胆固醇", value: "5.0", unit: "mmol/L", range: "< 5.2", flag: "参考范围内"), ReportValue(name: "甘油三酯", value: "1.4", unit: "mmol/L", range: "< 1.7", flag: "参考范围内")]),
        ReportGroup(name: "肾功能", summary: "肌酐", icon: "cross.case.fill", flag: "参考范围内", items: [ReportValue(name: "肌酐", value: "68", unit: "μmol/L", range: "44–97", flag: "参考范围内")]),
        ReportGroup(name: "血糖", summary: "空腹血糖", icon: "drop", flag: "参考范围内", items: [ReportValue(name: "空腹血糖", value: "5.6", unit: "mmol/L", range: "3.9–6.1", flag: "参考范围内")])
    ]
}
struct ReportValue: Identifiable { var id: String { name }; var name: String; var value: String; var unit: String; var range: String; var flag: String }
struct ReportGroupView: View {
    var group: ReportGroup

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("报告指标")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                Text(group.name)
                    .font(CXTypography.display)
                Text(group.summary)
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.muted)
            }

            ForEach(group.items) { item in
                VStack(alignment: .leading, spacing: CXSpacing.md) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name)
                            .font(CXTypography.section)
                        Spacer()
                        Text(item.flag)
                            .font(CXTypography.micro.weight(.semibold))
                            .foregroundStyle(item.flag == "参考范围内" ? CX.statusPositive : CX.statusWarning)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.value)
                            .font(CXTypography.display)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                        Text(item.unit)
                            .font(CXTypography.supporting)
                            .foregroundStyle(CX.muted)
                    }

                    Divider().overlay(CX.separator.opacity(0.14))

                    HStack {
                        Text("报告参考范围")
                            .font(CXTypography.meta)
                            .foregroundStyle(CX.muted)
                        Spacer()
                        Text(item.range)
                            .font(CXTypography.supporting.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                .padding(CXSpacing.lg)
                .cxContentSurface(cornerRadius: CXRadius.lg)
            }

            Text("示例检验结果仅用于展示信息层级。医学结论仍需结合个人病史、测量条件和专业评估。")
                .font(CXTypography.meta)
                .foregroundStyle(CX.muted)
                .lineSpacing(4)
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
