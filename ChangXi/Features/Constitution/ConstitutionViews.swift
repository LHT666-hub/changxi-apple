import SwiftUI
import UIKit

struct ConstitutionHomeView: View {
    @State private var store = ConstitutionStore()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("认识自己的体质")
                        .font(.largeTitle.weight(.semibold)).fontDesign(.serif)
                    Text("从日常感受出发，了解身体相对稳定的特点，再与家庭医生一起核对。")
                        .foregroundStyle(CX.muted).lineSpacing(5)
                }

                if let result = store.result {
                    NavigationLink { ConstitutionResultView(store: store) } label: {
                        ConstitutionResultSummary(result: result)
                    }.buttonStyle(.plain)
                }

                LazyVGrid(columns: CXLayout.adaptiveColumns(minimum: 145, dynamicTypeSize: dynamicTypeSize), spacing: 12) {
                    ForEach(TCMConstitution.allCases) { constitution in
                        NavigationLink { ConstitutionGuideView(constitution: constitution, store: store) } label: {
                            ConstitutionCard(constitution: constitution)
                        }.buttonStyle(.plain)
                    }
                }

                NavigationLink { ConstitutionQuestionnaireView(store: store) } label: {
                    Label(store.result == nil ? "开始体质初测" : "重新进行初测", systemImage: "arrow.right")
                        .font(.title3.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 58)
                }.buttonStyle(PrimaryButton())

                Text("本初测用于帮助表达体质特征，不等同于医疗机构按国家标准完成的正式体质辨识。")
                    .font(.footnote).foregroundStyle(CX.muted)
            }
            .frame(maxWidth: 680).padding(20).frame(maxWidth: .infinity)
        }
        .cxMoonScreenBackground(illustrated: true)
        .navigationTitle("中医体质").navigationBarTitleDisplayMode(.inline)
    }
}

private struct ConstitutionCard: View {
    let constitution: TCMConstitution
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        VStack(spacing: 0) {
            ConstitutionArtwork(constitution: constitution)
                .frame(height: 132).clipped()
            VStack(alignment: .leading, spacing: 7) {
                Text(constitution.rawValue).font(.title3.weight(.semibold)).fontDesign(.serif)
                Text(constitution.shortDescription)
                    .font(.caption)
                    .foregroundStyle(CX.muted)
                    .lineLimit(dynamicTypeSize >= .xxxLarge ? nil : 2)
                HStack {
                    Text(constitution.gentlePhrase).font(.caption2).foregroundStyle(constitution.tint)
                    Spacer(); Image(systemName: "chevron.right").font(.caption2).foregroundStyle(CX.faint)
                }
            }.padding(14)
        }
        .background(CX.surface.opacity(0.92), in: .rect(cornerRadius: 24))
        .clipShape(.rect(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.66), lineWidth: 1) }
        .shadow(color: constitution.tint.opacity(0.10), radius: 18, y: 8)
    }
}

struct ConstitutionArtwork: View {
    let constitution: TCMConstitution
    @ViewBuilder
    var body: some View {
        if let atlas = UIImage(named: "ConstitutionAtlas") {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let side = max(width, height)
                let index = constitution.atlasIndex
                Image(uiImage: atlas)
                    .resizable()
                    .frame(width: side * 3, height: side * 3)
                    .offset(
                        x: -CGFloat(index % 3) * side + (width - side) / 2,
                        y: -CGFloat(index / 3) * side + (height - side) / 2
                    )
            }
            .clipped()
            .accessibilityHidden(true)
        } else {
            nativeArtwork
        }
    }

    private var nativeArtwork: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let index = constitution.atlasIndex
            ZStack {
                LinearGradient(
                    colors: [Color.white.opacity(0.92), constitution.tint.opacity(0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(constitution.tint.opacity(0.13))
                    .frame(width: width * 0.74, height: width * 0.74)
                    .offset(x: width * (index.isMultiple(of: 2) ? 0.12 : -0.10), y: -height * 0.03)
                Circle()
                    .trim(from: 0.14, to: 0.84)
                    .stroke(Color.white.opacity(0.82), style: StrokeStyle(lineWidth: max(3, width * 0.026), lineCap: .round))
                    .frame(width: width * 0.38, height: width * 0.38)
                    .rotationEffect(.degrees(Double(index * 19 - 30)))
                    .offset(x: width * 0.25, y: -height * 0.28)
                ConstitutionBotanical(tint: constitution.tint, mirrored: index.isMultiple(of: 2))
                    .frame(width: width * 0.38, height: height * 0.66)
                    .offset(x: width * (index.isMultiple(of: 2) ? -0.32 : 0.32), y: height * 0.16)
                ConstitutionPortrait(constitution: constitution)
                    .frame(width: width * 0.78, height: height * 0.92)
                    .offset(y: height * 0.12)
                Image(systemName: motif(for: constitution))
                    .font(.system(size: min(width, height) * 0.12, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(constitution.tint.opacity(0.72))
                    .offset(x: -width * 0.31, y: -height * 0.32)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private func motif(for value: TCMConstitution) -> String {
        switch value {
        case .balanced: "leaf"
        case .qiDeficiency: "cup.and.saucer"
        case .yangDeficiency: "sun.min"
        case .yinDeficiency: "moon"
        case .phlegmDamp: "figure.walk"
        case .dampHeat: "fan"
        case .bloodStasis: "waveform.path.ecg"
        case .qiStagnation: "wind"
        case .special: "camera.macro"
        }
    }
}

private struct ConstitutionPortrait: View {
    let constitution: TCMConstitution
    private var index: Int { constitution.atlasIndex }
    private var clothing: Color { constitution.tint.opacity(0.76) }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                RoundedRectangle(cornerRadius: width * 0.18)
                    .fill(clothing)
                    .frame(width: width * 0.58, height: height * 0.43)
                    .offset(y: height * 0.31)
                Capsule().fill(clothing.opacity(0.92))
                    .frame(width: width * 0.17, height: height * 0.40)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -25 : 25))
                    .offset(x: width * (index.isMultiple(of: 2) ? -0.25 : 0.25), y: height * 0.27)
                Capsule().fill(clothing.opacity(0.86))
                    .frame(width: width * 0.15, height: height * 0.34)
                    .rotationEffect(.degrees(index.isMultiple(of: 3) ? 32 : -32))
                    .offset(x: width * (index.isMultiple(of: 3) ? 0.22 : -0.22), y: height * 0.31)
                Circle().fill(Color(red: 0.66, green: 0.67, blue: 0.68))
                    .frame(width: width * 0.38, height: width * 0.38)
                    .offset(x: width * (index.isMultiple(of: 2) ? 0.025 : -0.025), y: -height * 0.13)
                Circle().fill(Color(red: 0.93, green: 0.79, blue: 0.68))
                    .frame(width: width * 0.33, height: width * 0.35)
                    .offset(x: width * (index.isMultiple(of: 2) ? -0.015 : 0.015), y: -height * 0.105)
                HStack(spacing: width * 0.075) {
                    Capsule().fill(CX.ink.opacity(0.65)).frame(width: width * 0.035, height: 2)
                    Capsule().fill(CX.ink.opacity(0.65)).frame(width: width * 0.035, height: 2)
                }.offset(y: -height * 0.12)
                Capsule().stroke(CX.ink.opacity(0.48), lineWidth: 1.4)
                    .frame(width: width * 0.10, height: height * 0.035)
                    .mask(Rectangle().frame(height: height * 0.025).offset(y: height * 0.012))
                    .offset(y: -height * 0.045)
                if [.qiDeficiency, .yangDeficiency].contains(constitution) {
                    Capsule().stroke(Color.white.opacity(0.72), lineWidth: width * 0.035)
                        .frame(width: width * 0.43, height: height * 0.17)
                        .offset(y: height * 0.10)
                }
                if constitution == .qiDeficiency || constitution == .yangDeficiency {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: width * 0.17)).foregroundStyle(Color.white.opacity(0.88))
                        .offset(x: width * 0.12, y: height * 0.25)
                } else if constitution == .dampHeat {
                    Image(systemName: "fan.fill").font(.system(size: width * 0.20)).foregroundStyle(Color.white.opacity(0.78))
                        .offset(x: width * 0.18, y: height * 0.24)
                } else if constitution == .phlegmDamp {
                    Image(systemName: "waterbottle.fill").font(.system(size: width * 0.15)).foregroundStyle(Color.white.opacity(0.82))
                        .offset(x: width * 0.19, y: height * 0.27)
                }
            }
        }
    }
}

private struct ConstitutionBotanical: View {
    let tint: Color
    let mirrored: Bool
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Capsule().fill(tint.opacity(0.38)).frame(width: 3, height: geometry.size.height * 0.86)
                    .rotationEffect(.degrees(mirrored ? 18 : -18))
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(tint.opacity(0.22 + Double(index) * 0.07))
                        .frame(width: geometry.size.width * 0.34, height: geometry.size.height * 0.12)
                        .rotationEffect(.degrees(Double((mirrored ? -1 : 1) * (28 + index * 7))))
                        .offset(
                            x: geometry.size.width * (index.isMultiple(of: 2) ? -0.20 : 0.20),
                            y: geometry.size.height * (0.30 - CGFloat(index) * 0.18)
                        )
                }
            }
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
        }
    }
}

private struct ConstitutionResultSummary: View {
    let result: ConstitutionResult
    var body: some View {
        HStack(spacing: 16) {
            ConstitutionArtwork(constitution: result.primary)
                .frame(width: 116, height: 116).clipShape(.rect(cornerRadius: 22))
            VStack(alignment: .leading, spacing: 7) {
                Text("当前体质画像").font(.caption).foregroundStyle(CX.muted)
                Text("\(result.primary.rawValue)倾向")
                    .font(.title2.weight(.semibold)).fontDesign(.serif)
                Label(result.status.rawValue, systemImage: result.status == .pending ? "clock" : "sparkles")
                    .font(.caption).foregroundStyle(result.primary.tint)
                Text("查看结果与下一步").font(.caption).foregroundStyle(CX.muted)
            }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(CX.faint)
        }
        .padding(16).cxInteractiveGlass(cornerRadius: 26)
    }
}

struct ConstitutionQuestionnaireView: View {
    let store: ConstitutionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var answers: [Int: Int] = [:]
    @State private var showResult = false

    private let choices = [(0, "没有"), (1, "很少"), (2, "有时"), (3, "经常"), (4, "总是")]
    private var question: ConstitutionQuestion { ConstitutionQuestion.brief[index] }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ProgressView(value: Double(index + 1), total: Double(ConstitutionQuestion.brief.count))
                        .tint(CX.blue)
                    Text("第 \(index + 1) 题，共 \(ConstitutionQuestion.brief.count) 题")
                        .font(.subheadline).foregroundStyle(CX.muted)
                    HStack(alignment: .top, spacing: 12) {
                        Image("ChangXiCharacter").resizable().scaledToFit().frame(width: 62, height: 62)
                        Text(question.text)
                            .font(.title2.weight(.semibold)).fontDesign(.serif).lineSpacing(5)
                    }
                    VStack(spacing: 10) {
                        ForEach(choices, id: \.0) { score, label in
                            Button {
                                answers[question.id] = score
                                if index < ConstitutionQuestion.brief.count - 1 {
                                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { index += 1 }
                                }
                            } label: {
                                HStack {
                                    Text(label).font(.headline)
                                    Spacer()
                                    if answers[question.id] == score { Image(systemName: "checkmark.circle.fill").foregroundStyle(CX.blue) }
                                }
                                .padding(.horizontal, 18).frame(minHeight: 56)
                                .background(answers[question.id] == score ? CX.blue.opacity(0.12) : CX.surface, in: .rect(cornerRadius: 18))
                            }.buttonStyle(.plain)
                        }
                    }
                    Text("请按最近三个月多数时候的感受选择。想不起来时，可以选最接近的一项。")
                        .font(.footnote).foregroundStyle(CX.muted)
                }
                .frame(maxWidth: 620).padding(20).frame(maxWidth: .infinity)
            }
            HStack(spacing: 12) {
                Button("上一题") { if index > 0 { index -= 1 } }.frame(minWidth: 90, minHeight: 50).disabled(index == 0)
                if index == ConstitutionQuestion.brief.count - 1 {
                    Button("查看初步结果") { finish() }
                        .buttonStyle(PrimaryButton()).disabled(answers.count < ConstitutionQuestion.brief.count)
                } else {
                    Button("退出初测") { dismiss() }.buttonStyle(.bordered).frame(minHeight: 50)
                }
            }.padding(16).background(.regularMaterial)
        }
        .cxMoonScreenBackground(illustrated: true)
        .navigationTitle("体质初测").navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showResult) { ConstitutionResultView(store: store) }
    }

    private func finish() {
        var scores = Dictionary(uniqueKeysWithValues: TCMConstitution.allCases.map { ($0, 0) })
        for question in ConstitutionQuestion.brief { scores[question.constitution, default: 0] += answers[question.id] ?? 0 }
        let biasedMaximum = TCMConstitution.allCases.filter { $0 != .balanced }.map { scores[$0] ?? 0 }.max() ?? 0
        if (scores[.balanced] ?? 0) >= 6 && biasedMaximum <= 3 { scores[.balanced] = 9 }
        else { scores[.balanced] = 0 }
        store.save(scores: scores)
        showResult = true
    }
}

struct ConstitutionResultView: View {
    let store: ConstitutionStore
    var body: some View {
        ScrollView {
            if let result = store.result {
                VStack(alignment: .leading, spacing: 20) {
                    ConstitutionHero(constitution: result.primary, eyebrow: "您的主要体质倾向")
                    if let secondary = result.secondary, secondary != .balanced {
                        Card {
                            Text("同时呈现一些 \(secondary.rawValue) 特征")
                                .font(.headline).fontDesign(.serif)
                            Text(secondary.shortDescription).foregroundStyle(CX.muted)
                        }
                    }
                    Card {
                        HStack { Text("各体质初测得分").font(.title3.weight(.semibold)); Spacer(); Text("相对表现").font(.caption).foregroundStyle(CX.muted) }
                        ForEach(result.ranked, id: \.0) { item in
                            let constitution = item.0
                            let score = item.1
                            HStack {
                                Text(constitution.rawValue).frame(width: 64, alignment: .leading)
                                ProgressView(value: Double(score), total: 9).tint(constitution.tint)
                                Text("\(Int((Double(score) / 9 * 100).rounded()))%").font(.caption).monospacedDigit().frame(width: 38)
                            }.font(.subheadline)
                        }
                    }
                    ReviewPipeline(status: result.status)
                    NavigationLink { ConstitutionGuideView(constitution: result.primary, store: store) } label: {
                        Label("查看 \(result.primary.rawValue) 科普", systemImage: "book.closed")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }.buttonStyle(.bordered)
                    NavigationLink { ConstitutionDoctorReviewView(store: store) } label: {
                        Label(result.status == .pending ? "查看家庭医生确认进度" : "请家庭医生协助确认", systemImage: "paperplane")
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }.buttonStyle(PrimaryButton())
                    Text("得分用于这次简短体验型初测，各类型可以同时呈现；正式判定应由专业人员按现行标准完成。")
                        .font(.footnote).foregroundStyle(CX.muted)
                }.frame(maxWidth: 680).padding(20).frame(maxWidth: .infinity)
            }
        }
        .cxMoonScreenBackground(illustrated: true)
        .navigationTitle("体质结果").navigationBarTitleDisplayMode(.inline)
    }
}

private struct ConstitutionHero: View {
    let constitution: TCMConstitution
    let eyebrow: String
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ConstitutionArtwork(constitution: constitution).frame(height: 285)
            LinearGradient(colors: [.clear, CX.ink.opacity(0.72)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow).font(.caption).foregroundStyle(.white.opacity(0.86))
                Text(constitution.rawValue).font(.largeTitle.weight(.semibold)).fontDesign(.serif).foregroundStyle(.white)
                Text(constitution.shortDescription).foregroundStyle(.white.opacity(0.9))
            }.padding(20)
        }.clipShape(.rect(cornerRadius: 28)).shadow(color: constitution.tint.opacity(0.18), radius: 22, y: 10)
    }
}

private struct ReviewPipeline: View {
    let status: ConstitutionReviewStatus
    var body: some View {
        Card {
            Text("这份结果走到哪一步了").font(.title3.weight(.semibold))
            ForEach(Array([ConstitutionReviewStatus.draft, .pending, .confirmed].enumerated()), id: \.element.rawValue) { index, item in
                HStack(spacing: 12) {
                    Image(systemName: reached(item) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(reached(item) ? CX.teal : CX.faint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.rawValue).font(.headline)
                        if item == status { Text("当前步骤").font(.caption).foregroundStyle(CX.muted) }
                    }
                }
                if index < 2 { Rectangle().fill(CX.separator.opacity(0.3)).frame(width: 2, height: 16).padding(.leading, 10) }
            }
        }
    }
    private func reached(_ item: ConstitutionReviewStatus) -> Bool {
        let order: [ConstitutionReviewStatus] = [.draft, .pending, .confirmed]
        return (order.firstIndex(of: item) ?? 0) <= (order.firstIndex(of: status) ?? 0)
    }
}

struct ConstitutionGuideView: View {
    let constitution: TCMConstitution
    let store: ConstitutionStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ConstitutionHero(constitution: constitution, eyebrow: "体质小指南")
                if store.result?.primary == constitution {
                    Label("已加入我的健康画像 · \(store.result?.status.rawValue ?? "常曦初测")", systemImage: "checkmark.shield")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(CX.teal)
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(CX.teal.opacity(0.10), in: Capsule())
                }
                Card {
                    Text("常见表现").font(.title3.weight(.semibold))
                    Text("这些表现只帮助理解体质特点，并不是疾病症状清单。")
                        .font(.footnote).foregroundStyle(CX.muted)
                    TagFlow(items: constitution.commonSigns, tint: constitution.tint)
                }
                Card {
                    Text("日常可以这样照顾自己").font(.title3.weight(.semibold))
                    LazyVGrid(columns: CXLayout.adaptiveColumns(minimum: 125, spacing: 10, dynamicTypeSize: dynamicTypeSize), spacing: 10) {
                        ForEach(constitution.suggestions, id: \.self) { suggestion in
                            Label(suggestion, systemImage: "leaf")
                                .font(.subheadline).frame(maxWidth: .infinity, minHeight: 54)
                                .background(constitution.tint.opacity(0.10), in: .rect(cornerRadius: 16))
                        }
                    }
                }
                NavigationLink { ConstitutionCarePlanView(constitution: constitution) } label: {
                    Label("看看温和调养计划", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 56)
                }.buttonStyle(PrimaryButton())
                Text("体质调养不能替代疾病治疗；已有疾病、正在用药或出现持续不适时，请先与医生核对。")
                    .font(.footnote).foregroundStyle(CX.muted)
            }.frame(maxWidth: 680).padding(20).frame(maxWidth: .infinity)
        }.cxMoonScreenBackground(illustrated: true)
            .navigationTitle("\(constitution.rawValue)指南").navigationBarTitleDisplayMode(.inline)
    }
}

private struct TagFlow: View {
    let items: [String]
    let tint: Color
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        LazyVGrid(columns: CXLayout.adaptiveColumns(minimum: 116, spacing: 8, dynamicTypeSize: dynamicTypeSize), alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) {
                Text($0)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .background(tint.opacity(0.10), in: .rect(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

struct ConstitutionDoctorReviewView: View {
    let store: ConstitutionStore
    @State private var showRequest = false
    var body: some View {
        Page {
            Text("请家庭医生一起确认").font(.largeTitle.weight(.semibold)).fontDesign(.serif)
            Text("常曦会整理初测结果和作答时间。发送前，您可以先核对将共享的内容。")
                .foregroundStyle(CX.muted)
            if let result = store.result {
                Card {
                    RowLabel(title: "\(result.primary.rawValue)倾向", subtitle: "初测于 \(result.date.formatted(date: .abbreviated, time: .shortened))", icon: "leaf.fill", tint: result.primary.tint)
                    Divider()
                    Label(result.status.rawValue, systemImage: result.status == .pending ? "clock" : "doc.text")
                        .foregroundStyle(result.status == .pending ? CX.gold : CX.blue)
                }
                Card {
                    RowLabel(title: "王医生", subtitle: "家庭医生 · 中医体质结果确认", icon: "stethoscope", tint: CX.teal)
                    Text(result.status == .pending ? "确认申请已保存在本机等待同步。医生确认后，正式结果和建议会回到健康画像。" : "医生会结合健康状况、用药与当面了解进行判断。")
                        .font(.subheadline).foregroundStyle(CX.muted)
                }
                if result.status != .pending {
                    Button("提交确认申请") { showRequest = true }.buttonStyle(PrimaryButton())
                }
            }
            Text("体验版本不会真的向医疗机构发送信息；接入服务端后需要在这里再次展示接收机构和共享范围。")
                .font(.footnote).foregroundStyle(CX.muted)
        }
        .navigationTitle("家庭医生确认")
        .confirmationDialog("确认提交这份体质初测？", isPresented: $showRequest, titleVisibility: .visible) {
            Button("确认提交") { store.requestDoctorReview() }
            Button("再看看", role: .cancel) { }
        } message: { Text("体验版会把状态保存在本机，不会实际发送。") }
    }
}

struct ConstitutionCarePlanView: View {
    let constitution: TCMConstitution
    @State private var completed: Set<Int> = []
    private var tasks: [String] { [constitution.suggestions[0], constitution.suggestions[1], "记下今天的感受"] }
    var body: some View {
        Page {
            Text("从今天的一小步开始").font(.largeTitle.weight(.semibold)).fontDesign(.serif)
            Text("根据 \(constitution.rawValue) 的常见特点整理，您可以按自己的体力调整。")
                .foregroundStyle(CX.muted)
            Card {
                ForEach(Array(tasks.enumerated()), id: \.element) { index, task in
                    Button {
                        if completed.contains(index) { completed.remove(index) } else { completed.insert(index) }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: completed.contains(index) ? "checkmark.circle.fill" : "circle")
                                .font(.title2).foregroundStyle(completed.contains(index) ? CX.teal : CX.faint)
                            Text(task).font(.headline).foregroundStyle(CX.ink)
                            Spacer()
                        }.frame(minHeight: 56)
                    }.buttonStyle(.plain)
                    if index < tasks.count - 1 { Divider() }
                }
            }
            Text("计划只提供一般生活方式提示，不包含中药、穴位或治疗处方。")
                .font(.footnote).foregroundStyle(CX.muted)
        }.navigationTitle("调养计划")
    }
}

#Preview("中医体质总览") {
    NavigationStack { ConstitutionHomeView() }
}

#Preview("六维健康画像") {
    NavigationStack { HealthPortraitView() }
}
