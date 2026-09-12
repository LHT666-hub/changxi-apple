import SwiftUI

struct HealthPortraitView: View {
    private let dimensions = HealthPortraitDimension.samples
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("我的健康画像")
                        .font(.largeTitle.weight(.semibold)).fontDesign(.serif)
                    Text("整体较稳定，有 2 项值得继续关注。")
                        .font(.title3).foregroundStyle(CX.muted)
                }

                Card {
                    portraitSummary
                }

                SectionEyebrow(title: "六维画像", action: "事实 · 状态 · 需要 · 行动")
                LazyVGrid(columns: CXLayout.adaptiveColumns(minimum: 155, dynamicTypeSize: dynamicTypeSize), spacing: 12) {
                    ForEach(dimensions) { dimension in
                        NavigationLink { destination(for: dimension) } label: {
                            HealthPortraitCard(dimension: dimension)
                        }.buttonStyle(.plain)
                    }
                }

                Card {
                    Text("常曦正在留意").font(.title3.weight(.semibold))
                    Text("近期最大的变化是活动量下降。我想继续了解，是天气原因，还是腿脚最近不舒服？")
                        .foregroundStyle(CX.muted).lineSpacing(5)
                    NavigationLink("记录身体感受") { PainLocationView() }
                        .buttonStyle(PrimaryButton())
                }
                Text("健康画像用于整理变化与管理需求，不生成疾病诊断。需要专业判断的内容由家庭医生确认。")
                    .font(.footnote).foregroundStyle(CX.muted)
            }
            .frame(maxWidth: 680).padding(20).frame(maxWidth: .infinity)
        }
        .cxMoonScreenBackground(illustrated: true)
        .navigationTitle("健康画像").navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var portraitSummary: some View {
        let ring = SixDimensionRing(dimensions: dimensions)
            .frame(width: 142, height: 142)
        let copy = VStack(alignment: .leading, spacing: 8) {
            Label("重点关注", systemImage: "circle.lefthalf.filled")
                .font(.headline)
                .foregroundStyle(CX.gold)
            Text("最近活动量有所下降，下肢力量也需要继续观察。")
                .font(.subheadline)
                .foregroundStyle(CX.muted)
            Text("画像会随着记录逐步更新")
                .font(.caption)
                .foregroundStyle(CX.faint)
        }

        if dynamicTypeSize >= .xxxLarge {
            VStack(alignment: .leading, spacing: 16) { ring; copy }
        } else {
            HStack(spacing: 20) { ring; copy }
        }
    }

    @ViewBuilder private func destination(for dimension: HealthPortraitDimension) -> some View {
        switch dimension.kind {
        case .characteristics: ConstitutionRootView()
        case .function: HealthDimensionDetailView(dimension: dimension, painEntry: true)
        default: HealthDimensionDetailView(dimension: dimension, painEntry: false)
        }
    }
}

private enum HealthDimensionKind: String {
    case body, treatment, lifestyle, mind, function, characteristics
}

private struct HealthPortraitDimension: Identifiable {
    let kind: HealthDimensionKind
    let title: String
    let state: String
    let detail: String
    let symbol: String
    let tint: Color
    var id: String { kind.rawValue }

    static let samples: [Self] = [
        .init(kind: .body, title: "身体状态", state: "总体稳定", detail: "血糖近期略有波动", symbol: "heart.text.square", tint: CX.teal),
        .init(kind: .treatment, title: "治疗用药", state: "按计划进行", detail: "12 天后需要复查", symbol: "pills", tint: CX.teal),
        .init(kind: .lifestyle, title: "生活管理", state: "活动量下降", detail: "平均 4,860 步／日", symbol: "figure.walk", tint: CX.gold),
        .init(kind: .mind, title: "身心状态", state: "整体平稳", detail: "最近睡眠稍浅", symbol: "moon.stars", tint: CX.teal),
        .init(kind: .function, title: "身体功能", state: "下肢力量需关注", detail: "本周康复 4／6 次", symbol: "figure.strengthtraining.traditional", tint: CX.gold),
        .init(kind: .characteristics, title: "健康特点", state: "体质等待了解", detail: "家庭支持良好", symbol: "person.crop.circle.badge.questionmark", tint: CX.blue)
    ]
}

private struct HealthPortraitCard: View {
    let dimension: HealthPortraitDimension
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: dimension.symbol).foregroundStyle(dimension.tint)
                Spacer()
                Circle().fill(dimension.tint).frame(width: 9, height: 9)
            }
            Text(dimension.title).font(.headline)
            Text(dimension.state).font(.subheadline.weight(.semibold)).foregroundStyle(dimension.tint)
            Text(dimension.detail)
                .font(.caption)
                .foregroundStyle(CX.muted)
                .lineLimit(dynamicTypeSize >= .xxxLarge ? nil : 2)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(CX.faint).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, minHeight: 145, alignment: .leading)
        .padding(16).cxInteractiveGlass(cornerRadius: 22)
    }
}

private struct SixDimensionRing: View {
    let dimensions: [HealthPortraitDimension]
    var body: some View {
        ZStack {
            ForEach(Array(dimensions.enumerated()), id: \.element.id) { index, item in
                Circle()
                    .trim(from: CGFloat(index) / 6 + 0.012, to: CGFloat(index + 1) / 6 - 0.012)
                    .stroke(item.tint.opacity(0.88), style: StrokeStyle(lineWidth: 15, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 2) {
                Text("6").font(.title.bold()).monospacedDigit()
                Text("个维度").font(.caption).foregroundStyle(CX.muted)
            }
        }.accessibilityLabel("六维健康画像，其中两项需要关注")
    }
}

private struct HealthDimensionDetailView: View {
    let dimension: HealthPortraitDimension
    let painEntry: Bool
    var body: some View {
        Page {
            Label(dimension.title, systemImage: dimension.symbol)
                .font(.largeTitle.weight(.semibold)).fontDesign(.serif).foregroundStyle(dimension.tint)
            Card {
                Text("现在的状态").font(.headline)
                Text(dimension.state).font(.title2.weight(.semibold))
                Text(dimension.detail).foregroundStyle(CX.muted)
            }
            Card {
                Text("接下来可以做什么").font(.headline)
                Text(painEntry ? "记录疼痛和活动后的感受，帮助以后比较变化。" : "继续完成日常记录，常曦会把新的变化整理到这里。")
                    .foregroundStyle(CX.muted)
                if painEntry { NavigationLink("记录身体感受") { PainLocationView() }.buttonStyle(PrimaryButton()) }
            }
            DemoLabel()
        }.navigationTitle(dimension.title)
    }
}
