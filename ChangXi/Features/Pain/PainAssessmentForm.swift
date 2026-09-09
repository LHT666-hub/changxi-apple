import SwiftUI

/// Patient descriptions, not a validated diagnostic score or an automated triage assessment.
struct PainAssessmentForm: View {
    @Binding var assessment: PainAssessment
    var body: some View {
        Card {
            Text("再记一点，方便以后对照").font(.title3.weight(.semibold))
            Text("这些都可以跳过，不确定就留空或选说不清。")
                .font(.footnote).foregroundStyle(CX.muted)
            Picker("谁在描述", selection: $assessment.reporter) {
                Text("本人描述").tag("本人描述")
                Text("家人协助转述").tag("家人协助转述")
            }
            Picker("用自己的话说程度", selection: $assessment.intensityWords) {
                ForEach(["还没选", "不疼", "轻微", "中等", "很疼", "非常疼", "说不清"], id: \.self) { Text($0) }
            }
            Picker("一直疼，还是一阵一阵", selection: $assessment.pattern) {
                ForEach(["还没选", "一直疼", "一阵一阵", "偶尔一下", "说不清"], id: \.self) { Text($0) }
            }
            TextField("每次大约疼多久？", text: $assessment.duration, axis: .vertical)
            TextField("会牵扯到别处吗？例如从腰到腿", text: $assessment.radiation, axis: .vertical)
            TextField("什么情况下更疼？例如走路、转头", text: $assessment.aggravating, axis: .vertical)
            TextField("怎样会好一些？例如休息", text: $assessment.relieving, axis: .vertical)
            Picker("对日常活动的影响", selection: $assessment.dailyImpact) {
                ForEach(["还没选", "没有影响", "有些影响", "很受影响", "说不清"], id: \.self) { Text($0) }
            }
            Picker("对睡眠的影响", selection: $assessment.sleepImpact) {
                ForEach(["还没选", "没有影响", "难以入睡", "疼醒", "说不清"], id: \.self) { Text($0) }
            }
        }
        DisclosureGroup("哪些情况应先求助？") {
            VStack(alignment: .leading, spacing: 10) {
                Text("如果头痛突然发生且极其剧烈，或伴说话困难、肢体无力、意识异常；或者突发胸痛伴呼吸困难、冷汗，应先呼叫急救，不要等填完记录。中国大陆可拨打120，其他地区请使用当地急救号码。")
                Text("这不是完整的急症筛查，也不能用来排除危险。")
                Link("查看国家卫健委急救说明", destination: URL(string: "https://www.nhc.gov.cn/xcs/c100122/202411/81a60171b43d43ff98cc6110d65a4136.shtml")!)
                Link("查看 NHS 头痛求助说明", destination: URL(string: "https://www.nhs.uk/symptoms/headaches/")!)
            }.font(.footnote).foregroundStyle(CX.muted).padding(.top, 10)
        }.padding(18).background(CX.surface, in: .rect(cornerRadius: 20))
    }
}

struct PainAssessmentSummary: View {
    let assessment: PainAssessment
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(assessment.reporter)
            ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                if !field.1.isEmpty && field.1 != "还没选" { Text("\(field.0)：\(field.1)") }
            }
        }.font(.subheadline).foregroundStyle(CX.muted)
    }
    private var fields: [(String, String)] {
        [("程度描述", assessment.intensityWords), ("疼痛规律", assessment.pattern),
         ("每次持续", assessment.duration), ("牵扯位置", assessment.radiation),
         ("加重情况", assessment.aggravating), ("缓解情况", assessment.relieving),
         ("日常活动", assessment.dailyImpact), ("睡眠", assessment.sleepImpact)]
    }
}
