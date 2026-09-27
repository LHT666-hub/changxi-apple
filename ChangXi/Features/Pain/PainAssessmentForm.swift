import SwiftUI

/// Patient descriptions, not a validated diagnostic score or an automated triage assessment.
struct PainAssessmentForm: View {
    @Binding var assessment: PainAssessment
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: CXSpacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: "text.badge.plus")
                        .foregroundStyle(CX.actionPrimary)
                        .frame(width: 42, height: 42)
                        .background(CX.actionPrimary.opacity(0.08), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("补充疼痛经过与影响")
                            .font(CXTypography.section)
                            .foregroundStyle(CX.ink)
                        Text("选填 · 规律、持续时间、活动和睡眠")
                            .font(CXTypography.meta)
                            .foregroundStyle(CX.muted)
                    }

                    Spacer()

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CX.faint)
                }
                .padding(CXSpacing.md)
                .cxContentSurface(cornerRadius: CXRadius.md)
            }
            .buttonStyle(QuietPressButton())

            if expanded {
                VStack(alignment: .leading, spacing: CXSpacing.lg) {
                    VStack(alignment: .leading, spacing: CXSpacing.md) {
                        SectionEyebrow(title: "发生方式")

                        Picker("谁在描述", selection: $assessment.reporter) {
                            Text("本人描述").tag("本人描述")
                            Text("家人协助转述").tag("家人协助转述")
                        }
                        .pickerStyle(.segmented)

                        Picker("疼痛规律", selection: $assessment.pattern) {
                            ForEach(
                                ["还没选", "一直疼", "一阵一阵", "偶尔一下", "说不清"],
                                id: \.self
                            ) {
                                Text($0)
                            }
                        }
                        .pickerStyle(.menu)

                        PainTextArea(
                            title: "每次大约疼多久？",
                            text: $assessment.duration
                        )

                        PainTextArea(
                            title: "还会扩散到哪里？例如从腰窜到腿",
                            text: $assessment.radiation
                        )
                    }
                    .padding(CXSpacing.lg)
                    .cxContentSurface(cornerRadius: CXRadius.lg)

                    VStack(alignment: .leading, spacing: CXSpacing.md) {
                        SectionEyebrow(title: "什么会让它变化")

                        PainTextArea(
                            title: "什么情况下更疼？例如走路、转头",
                            text: $assessment.aggravating
                        )

                        PainTextArea(
                            title: "怎样会好一些？例如休息",
                            text: $assessment.relieving
                        )
                    }
                    .padding(CXSpacing.lg)
                    .cxContentSurface(cornerRadius: CXRadius.lg)

                    VStack(alignment: .leading, spacing: CXSpacing.md) {
                        SectionEyebrow(title: "对日常的影响")

                        Picker("日常活动", selection: $assessment.dailyImpact) {
                            ForEach(
                                ["还没选", "没有影响", "有些影响", "很受影响", "说不清"],
                                id: \.self
                            ) {
                                Text($0)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("睡眠", selection: $assessment.sleepImpact) {
                            ForEach(
                                ["还没选", "没有影响", "难以入睡", "疼醒", "说不清"],
                                id: \.self
                            ) {
                                Text($0)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(CXSpacing.lg)
                    .cxContentSurface(cornerRadius: CXRadius.lg)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            DisclosureGroup("哪些情况应先求助？") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("如果头痛突然发生且极其剧烈，或伴说话困难、肢体无力、意识异常；或者突发胸痛伴呼吸困难、冷汗，应先呼叫急救，不要等填完记录。中国大陆可拨打120，其他地区请使用当地急救号码。")
                    Text("这不是完整的急症筛查，也不能用来排除危险。")
                    Link(
                        "查看国家卫健委急救说明",
                        destination: URL(string: "https://www.nhc.gov.cn/xcs/c100122/202411/81a60171b43d43ff98cc6110d65a4136.shtml")!
                    )
                    Link(
                        "查看 NHS 头痛求助说明",
                        destination: URL(string: "https://www.nhs.uk/symptoms/headaches/")!
                    )
                }
                .font(CXTypography.meta)
                .foregroundStyle(CX.muted)
                .padding(.top, 10)
            }
            .font(CXTypography.supporting.weight(.semibold))
            .padding(CXSpacing.md)
            .background(
                CX.statusWarning.opacity(0.035),
                in: .rect(cornerRadius: CXRadius.md, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous)
                    .strokeBorder(CX.statusWarning.opacity(0.10), lineWidth: 0.5)
            }
        }
    }
}

private struct PainTextArea: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text, axis: .vertical)
            .font(CXTypography.supporting)
            .lineLimit(2...5)
            .padding(CXSpacing.md)
            .background(
                CX.raisedSurface,
                in: .rect(cornerRadius: CXRadius.sm, style: .continuous)
            )
    }
}

struct PainAssessmentSummary: View {
    let assessment: PainAssessment

    var body: some View {
        VStack(alignment: .leading, spacing: CXSpacing.md) {
            HStack {
                Text("经过与影响")
                    .font(CXTypography.section)
                Spacer()
                Text(assessment.reporter)
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.muted)
            }

            let visible = fields.filter { !$0.1.isEmpty && $0.1 != "还没选" }

            if visible.isEmpty {
                Text("这次没有补充更多经过与影响。")
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.muted)
            } else {
                ForEach(Array(visible.enumerated()), id: \.offset) { index, field in
                    HStack(alignment: .top, spacing: CXSpacing.md) {
                        Text(field.0)
                            .font(CXTypography.meta)
                            .foregroundStyle(CX.muted)
                            .frame(width: 72, alignment: .leading)

                        Text(field.1)
                            .font(CXTypography.supporting.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if index < visible.count - 1 {
                        Divider().overlay(CX.separator.opacity(0.10))
                    }
                }
            }
        }
    }

    private var fields: [(String, String)] {
        [
            ("疼痛规律", assessment.pattern),
            ("每次持续", assessment.duration),
            ("放射位置", assessment.radiation),
            ("加重情况", assessment.aggravating),
            ("缓解情况", assessment.relieving),
            ("日常活动", assessment.dailyImpact),
            ("睡眠", assessment.sleepImpact)
        ]
    }
}
