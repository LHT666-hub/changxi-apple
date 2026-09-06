import SwiftUI

struct ReportListContent: View {
    @Environment(AppStore.self) private var store
    @State private var upload = false
    var body: some View {
        ForEach(store.data.importedReports.reversed()) { report in
            NavigationLink { ImportedReportView(report: report) } label: { Card { RowLabel(title: report.title, subtitle: "本机报告 · 待整理", icon: "doc.richtext") } }.buttonStyle(.plain)
        }
        NavigationLink { ReportDetailView() } label: { Card { RowLabel(title: "9月5日体检报告", subtitle: "示例报告 · 3组指标已整理", icon: "doc.text.fill") } }.buttonStyle(.plain)
        Button { upload = true } label: { Label("添加报告照片", systemImage: "plus") }.buttonStyle(PrimaryButton())
            .sheet(isPresented: $upload) { NavigationStack { ReportImportView() } }
    }
}

struct ImportedReportView: View {
    var report: ImportedReport
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var deleting = false
    @State private var error: String?
    var body: some View {
        Page {
            Card {
                Text(report.title).font(.title2.bold())
                Text(report.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(CX.muted)
                if let image = UIImage(contentsOfFile: store.reportURL(report).path) { Image(uiImage: image).resizable().scaledToFit().accessibilityLabel("原始报告照片") }
                else { ContentUnavailableView("照片暂时无法读取", systemImage: "photo", description: Text("可在设备解锁后重试。")) }
                if !report.note.isEmpty { Text(report.note) }
                Label("已保存在本机 · 尚未识别", systemImage: "lock.shield").foregroundStyle(CX.muted)
                Text("本版本没有分析这张报告。请依据原始报告核对指标，或整理问题向医生咨询。").font(.footnote)
                NavigationLink("整理咨询问题") { ConsultationView() }
                Button("删除本机报告", role: .destructive) { deleting = true }.frame(minHeight: 44)
                if let error { Text(error).foregroundStyle(CX.coral) }
            }
        }.navigationTitle("报告原件")
        .confirmationDialog("删除这份报告及本机照片？", isPresented: $deleting, titleVisibility: .visible) { Button("删除报告", role: .destructive) { do { try store.deleteReport(report); dismiss() } catch { self.error = "报告未能删除，请稍后重试。" } } }
    }
}

struct ReportDetailView: View {
    @State private var showChat = false
    var body: some View {
        Page {
            Card {
                RowLabel(title: "9月5日体检报告", subtitle: "示例报告 · 数值与参考区间用于界面演示", icon: "doc.text.magnifyingglass", chevron: false)
                Text("主要关注 1 项").font(.title2.bold())
            }
            ForEach(ReportGroup.examples) { group in
                NavigationLink { ReportGroupView(group: group) } label: {
                    Card { RowLabel(title: group.name, subtitle: "\(group.summary) · \(group.flag)", icon: group.icon, tint: group.flag == "需关注" ? CX.coral : CX.teal) }
                }.buttonStyle(.plain)
            }
            Card {
                Label("常曦整理", systemImage: "sparkles").font(.title2.bold())
                Text("这份示例报告中，LDL-C 高于报告所列参考上限。可以把完整报告和近期记录一起交给医生查看。").lineSpacing(5)
                Text("参考区间来自本示例报告，并非个人治疗目标。不能据此自行调整用药。").font(.footnote).foregroundStyle(CX.muted)
            }
            Button("继续问常曦") { showChat = true }.buttonStyle(PrimaryButton())
            NavigationLink { DoctorDetailView() } label: { Card { RowLabel(title: "联系家庭医生", subtitle: "查看医生与咨询入口", icon: "stethoscope") } }.buttonStyle(.plain)
        }.navigationTitle("报告")
        .fullScreenCover(isPresented: $showChat) { NavigationStack { ChatView(initialPrompt: "我想了解这份体检报告") } }
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
        Page {
            ForEach(group.items) { item in
                Card {
                    Text(item.name).font(.title2.bold())
                    HStack(alignment: .firstTextBaseline) { Text(item.value).font(.largeTitle.bold()); Text(item.unit) }
                    Text("报告参考范围：\(item.range)").foregroundStyle(CX.muted)
                    Label(item.flag, systemImage: item.flag == "参考范围内" ? "checkmark.circle" : "exclamationmark.circle").foregroundStyle(item.flag == "参考范围内" ? CX.teal : CX.coral)
                }
            }
            Text("示例检验结果。医学结论需结合个人病史、测量条件和专业评估。").font(.footnote).foregroundStyle(CX.muted)
        }.navigationTitle(group.name)
    }
}
