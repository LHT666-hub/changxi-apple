import AVFoundation
import PhotosUI
import SwiftUI

private enum SY {
    static let ink = Color(.displayP3, red: 0.24, green: 0.13, blue: 0.09)
    static let muted = Color(.displayP3, red: 0.43, green: 0.34, blue: 0.29)
    static let apricot = Color(.displayP3, red: 0.94, green: 0.48, blue: 0.28)
    static let amber = Color(.displayP3, red: 0.93, green: 0.66, blue: 0.27)
    static let tea = Color(.displayP3, red: 0.34, green: 0.49, blue: 0.31)
    static let cream = Color(.displayP3, red: 1.0, green: 0.96, blue: 0.89)
}

struct ShiyangEntryCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationLink {
            ShiyangRootView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(SY.apricot.opacity(0.15))
                    Image(systemName: "fork.knife")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(SY.apricot)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(store.data.shiyangOnboarded ? "今晚吃什么" : "常曦食养")
                            .font(.headline)
                        if !store.data.shiyangOnboarded {
                            Text("上新")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(SY.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(SY.amber.opacity(0.24), in: Capsule())
                        }
                    }
                    Text(store.data.shiyangOnboarded ? ShiyangCatalog.recipe(store.data.shiyangSelectedRecipeID).title : "今天吃什么，按你的生活来安排")
                        .font(.subheadline)
                        .foregroundStyle(CX.muted)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(CX.faint)
            }
            .foregroundStyle(CX.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 78)
            .shiyangGlass(cornerRadius: 24)
            .shadow(color: SY.apricot.opacity(0.10), radius: 18, y: 8)
        }
        .buttonStyle(QuietPressButton())
        .accessibilityIdentifier("open-shiyang")
    }
}

struct ShiyangRootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if store.data.shiyangOnboarded {
                ShiyangHomeView()
            } else {
                ShiyangOnboardingFlow()
            }
        }
        .tint(SY.apricot)
    }
}

private enum ShiyangOnboardingStage {
    case intro
    case consent
    case profile
    case summary
}

private struct ShiyangProfileDraft {
    var city = "上海"
    var mealContext = "经常外卖"
    var staplePreference = "都可以"
    var avoidanceNote = ""
    var goal = "吃得均衡"
    var cookingMinutes = 30
    var healthNote = ""
    var medicationNote = ""

    var summary: String {
        "\(city)生活 · 午餐\(mealContext) · 喜欢\(staplePreference) · 晚餐约\(cookingMinutes)分钟 · 近期希望\(goal)"
    }

    var safetySummary: String {
        var items: [String] = []
        if !avoidanceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(avoidanceNote)
        }
        if !healthNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(healthNote)
        }
        if !medicationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("正在使用：\(medicationNote)")
        }
        return items.joined(separator: "；")
    }
}

private struct ShiyangOnboardingFlow: View {
    @Environment(AppStore.self) private var store
    @State private var stage = ShiyangOnboardingStage.intro
    @State private var draft = ShiyangProfileDraft()
    @State private var useLifestyleMemory = false
    @State private var useHealthData = false
    @State private var useMedicationData = false
    @State private var loaded = false

    var body: some View {
        Group {
            switch stage {
            case .intro:
                ShiyangWelcomeView { move(to: .consent) }
            case .consent:
                ShiyangConsentView(
                    useLifestyleMemory: $useLifestyleMemory,
                    useHealthData: $useHealthData,
                    useMedicationData: $useMedicationData,
                    onBack: { move(to: .intro) },
                    onContinue: { move(to: .profile) }
                )
            case .profile:
                ShiyangProfileQuestionsView(
                    draft: $draft,
                    onBack: { move(to: .consent) },
                    onComplete: { move(to: .summary) }
                )
            case .summary:
                ShiyangProfileSummaryView(
                    draft: draft,
                    useLifestyleMemory: useLifestyleMemory,
                    useHealthData: useHealthData,
                    useMedicationData: useMedicationData,
                    onEdit: { move(to: .profile) },
                    onConfirm: confirmProfile
                )
            }
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .onAppear {
            guard !loaded else { return }
            draft = ShiyangProfileDraft(
                city: store.data.shiyangCity,
                mealContext: store.data.shiyangMealContext,
                staplePreference: store.data.shiyangStaplePreference,
                avoidanceNote: store.data.shiyangAvoidanceNote,
                goal: store.data.shiyangGoal,
                cookingMinutes: store.data.shiyangAvailableMinutes,
                healthNote: store.data.shiyangHealthNote,
                medicationNote: store.data.shiyangMedicationNote
            )
            useLifestyleMemory = store.data.shiyangUseLifestyleMemory
            useHealthData = store.data.shiyangUseHealthData
            useMedicationData = store.data.shiyangUseMedicationData
            loaded = true
        }
    }

    private func move(to next: ShiyangOnboardingStage) {
        withAnimation(.spring(duration: 0.42, bounce: 0.06)) { stage = next }
    }

    private func confirmProfile() {
        store.data.shiyangCity = draft.city.trimmingCharacters(in: .whitespacesAndNewlines)
        store.data.shiyangMealContext = draft.mealContext
        store.data.shiyangStaplePreference = draft.staplePreference
        store.data.shiyangAvoidanceNote = draft.avoidanceNote.trimmingCharacters(in: .whitespacesAndNewlines)
        store.data.shiyangGoal = draft.goal
        store.data.shiyangAvailableMinutes = draft.cookingMinutes
        store.data.shiyangHealthNote = draft.healthNote.trimmingCharacters(in: .whitespacesAndNewlines)
        store.data.shiyangMedicationNote = draft.medicationNote.trimmingCharacters(in: .whitespacesAndNewlines)
        store.data.shiyangUseLifestyleMemory = useLifestyleMemory
        store.data.shiyangUseHealthData = useHealthData
        store.data.shiyangUseMedicationData = useMedicationData

        let excluded = Set(store.data.shiyangExcludedIngredientIDs)
            .union(ShiyangCatalog.ingredientIDs(in: draft.avoidanceNote))
        store.data.shiyangExcludedIngredientIDs = excluded.sorted()
        let recommendations = ShiyangRecommendationEngine.recommendations(
            pantry: Set(store.data.shiyangPantryIngredientIDs),
            excluded: excluded,
            maxMinutes: draft.cookingMinutes,
            lowSalt: store.data.shiyangLowSalt,
            likesSpicy: store.data.shiyangLikesSpicy,
            staplePreference: draft.staplePreference,
            mealContext: draft.mealContext,
            goal: draft.goal
        )
        if let first = recommendations.first { store.data.shiyangSelectedRecipeID = first.recipe.id }
        store.data.shiyangOnboarded = true
        MoonHaptics.shared.play(success: true, enabled: store.data.haptics)
    }
}

private struct ShiyangConsentView: View {
    @Binding var useLifestyleMemory: Bool
    @Binding var useHealthData: Bool
    @Binding var useMedicationData: Bool
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ShiyangOnboardingPage(step: 1, total: 3, onBack: onBack) {
            VStack(alignment: .leading, spacing: 8) {
                Text("让食养认识多少个你？")
                    .font(.largeTitle.weight(.semibold))
                    .fontDesign(.serif)
                Text("常曦不会默认读取全部信息。你可以分开授权，也可以暂时都不打开。")
                    .foregroundStyle(SY.muted)
                    .lineSpacing(5)
            }

            VStack(spacing: 12) {
                ShiyangConsentCard(
                    symbol: "house.and.flag.fill",
                    title: "生活信息",
                    detail: "所在地区、生活节奏、家庭情况和已确认偏好",
                    isOn: $useLifestyleMemory,
                    tint: SY.tea
                )
                ShiyangConsentCard(
                    symbol: "heart.text.square.fill",
                    title: "健康信息",
                    detail: "体重、已确认的健康情况和过敏信息",
                    isOn: $useHealthData,
                    tint: CX.blue
                )
                ShiyangConsentCard(
                    symbol: "pills.fill",
                    title: "用药信息",
                    detail: "只用于先排除需要避开的食物组合",
                    isOn: $useMedicationData,
                    tint: SY.apricot
                )
            }

            Text("这些权限之后都能在「食养档案与授权」中查看、修改或关闭。关闭后，新的推荐将不再读取对应信息。")
                .font(.footnote)
                .foregroundStyle(SY.muted)
                .lineSpacing(4)

            Button("继续", action: onContinue)
                .buttonStyle(ShiyangPrimaryButton())
                .accessibilityIdentifier("continue-shiyang-consent")
        }
    }
}

private struct ShiyangConsentCard: View {
    let symbol: String
    let title: String
    let detail: String
    @Binding var isOn: Bool
    let tint: Color

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.10), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(SY.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(SY.apricot)
        .padding(17)
        .shiyangGlass(cornerRadius: 22)
    }
}

private struct ShiyangProfileQuestionsView: View {
    @Binding var draft: ShiyangProfileDraft
    let onBack: () -> Void
    let onComplete: () -> Void
    @State private var question = 0

    private let total = 7

    var body: some View {
        ShiyangOnboardingPage(step: 2, total: 3, onBack: goBack) {
            HStack {
                Text("认识你的饭桌")
                    .font(.headline)
                    .foregroundStyle(SY.apricot)
                Spacer()
                Text("\(question + 1) / \(total)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(SY.muted)
            }

            ProgressView(value: Double(question + 1), total: Double(total))
                .tint(SY.apricot)

            questionContent
                .id(question)
                .transition(.opacity.combined(with: .move(edge: .trailing)))

            Spacer(minLength: 12)

            Button(question == total - 1 ? "看看常曦记住了什么" : "下一题") {
                if question == total - 1 {
                    onComplete()
                } else {
                    withAnimation(.spring(duration: 0.38, bounce: 0.04)) { question += 1 }
                }
            }
            .buttonStyle(ShiyangPrimaryButton())
            .disabled(question == 0 && draft.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("next-shiyang-question")
        }
    }

    @ViewBuilder private var questionContent: some View {
        switch question {
        case 0:
            ShiyangQuestionBlock(title: "你平时主要在哪座城市生活？", detail: "用于判断常见饮食、气候和时令，不需要填写详细地址。") {
                TextField("城市，例如上海", text: $draft.city)
                    .textContentType(.addressCity)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 54)
                    .shiyangGlass(cornerRadius: 18)
            }
        case 1:
            ShiyangQuestionBlock(title: "午饭一般在哪里吃？", detail: "这会影响我们推荐在家做、食堂搭配还是外卖点法。") {
                ShiyangChoiceGrid(options: ["在家吃", "经常食堂", "经常外卖", "不太固定"], selection: $draft.mealContext)
            }
        case 2:
            ShiyangQuestionBlock(title: "平时更喜欢米还是面？", detail: "不用为了健康突然换掉自己熟悉的主食。") {
                ShiyangChoiceGrid(options: ["米饭", "面食", "都可以"], selection: $draft.staplePreference)
            }
        case 3:
            ShiyangQuestionBlock(title: "有什么一定不吃或不能吃的？", detail: "过敏和明确忌口会优先排除；不确定的可以先不填。") {
                TextField("例如：花生过敏、不吃香菜", text: $draft.avoidanceNote, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(16)
                    .shiyangGlass(cornerRadius: 18)
            }
        case 4:
            ShiyangQuestionBlock(title: "最近更想解决什么？", detail: "先选此刻最重要的一件事，之后随时可以改。") {
                ShiyangChoiceGrid(options: ["规律吃饭", "管理体重", "吃得均衡", "照顾健康情况"], selection: $draft.goal)
            }
        case 5:
            ShiyangQuestionBlock(title: "做饭通常有多少时间？", detail: "我们会优先把能按时完成的做法排在前面。") {
                ShiyangChoiceGrid(options: [15, 20, 30, 45, 60], selection: $draft.cookingMinutes) { "\($0)分钟" }
            }
        default:
            ShiyangQuestionBlock(title: "最后，有没有需要特别注意的情况？", detail: "这些信息只用于避开风险，不用于诊断或调整用药。没有可以留空。") {
                VStack(spacing: 12) {
                    TextField("健康情况或已知过敏", text: $draft.healthNote, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(16)
                        .shiyangGlass(cornerRadius: 18)
                    TextField("正在使用的药物", text: $draft.medicationNote, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(16)
                        .shiyangGlass(cornerRadius: 18)
                }
            }
        }
    }

    private func goBack() {
        if question == 0 { onBack() }
        else { withAnimation(.spring(duration: 0.38, bounce: 0.04)) { question -= 1 } }
    }
}

private struct ShiyangProfileSummaryView: View {
    let draft: ShiyangProfileDraft
    let useLifestyleMemory: Bool
    let useHealthData: Bool
    let useMedicationData: Bool
    let onEdit: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ShiyangOnboardingPage(step: 3, total: 3, onBack: onEdit) {
            VStack(alignment: .leading, spacing: 7) {
                Text("常曦这样理解你的饭桌")
                    .font(.largeTitle.weight(.semibold))
                    .fontDesign(.serif)
                Text("确认以后再生成第一顿，避免把写错的信息带进推荐。")
                    .foregroundStyle(SY.muted)
            }

            VStack(alignment: .leading, spacing: 16) {
                Label("你的日常", systemImage: "house.fill")
                    .font(.headline)
                    .foregroundStyle(SY.tea)
                Text(draft.summary)
                    .font(.title3.weight(.medium))
                    .lineSpacing(6)
                Button("返回修改", systemImage: "pencil", action: onEdit)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .padding(20)
            .shiyangGlass(cornerRadius: 26)

            VStack(alignment: .leading, spacing: 12) {
                Label("需要特别注意", systemImage: "exclamationmark.shield.fill")
                    .font(.headline)
                    .foregroundStyle(SY.apricot)
                Text(draft.safetySummary.isEmpty ? "目前没有填写；以后可以随时补充。" : draft.safetySummary)
                    .foregroundStyle(draft.safetySummary.isEmpty ? SY.muted : SY.ink)
                    .lineSpacing(5)
            }
            .padding(20)
            .background(SY.apricot.opacity(0.09), in: .rect(cornerRadius: 24, style: .continuous))

            HStack(spacing: 8) {
                ShiyangPermissionPill(title: "生活", enabled: useLifestyleMemory)
                ShiyangPermissionPill(title: "健康", enabled: useHealthData)
                ShiyangPermissionPill(title: "用药", enabled: useMedicationData)
            }

            Button("确认，生成我的第一顿", action: onConfirm)
                .buttonStyle(ShiyangPrimaryButton())
                .accessibilityIdentifier("confirm-shiyang-profile")
        }
    }
}

private struct ShiyangPermissionPill: View {
    let title: String
    let enabled: Bool

    var body: some View {
        Label("\(title)\(enabled ? "已允许" : "未读取")", systemImage: enabled ? "checkmark.circle.fill" : "minus.circle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(enabled ? SY.tea : SY.muted)
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct ShiyangQuestionBlock<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))
                    .fontDesign(.serif)
                Text(detail)
                    .foregroundStyle(SY.muted)
                    .lineSpacing(5)
            }
            content
        }
    }
}

private struct ShiyangChoiceGrid<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String

    init(options: [Value], selection: Binding<Value>, label: @escaping (Value) -> String) {
        self.options = options
        self._selection = selection
        self.label = label
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 10)], spacing: 10) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    HStack {
                        Text(label(option)).font(.subheadline.weight(.semibold))
                        Spacer()
                        if selection == option { Image(systemName: "checkmark.circle.fill") }
                    }
                    .foregroundStyle(selection == option ? .white : SY.ink)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(selection == option ? SY.apricot : SY.cream.opacity(0.72), in: .rect(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(QuietPressButton())
            }
        }
    }
}

private extension ShiyangChoiceGrid where Value == String {
    init(options: [String], selection: Binding<String>) {
        self.init(options: options, selection: selection) { $0 }
    }
}

private struct ShiyangOnboardingPage<Content: View>: View {
    let step: Int
    let total: Int
    let onBack: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .shiyangGlass(cornerRadius: 22)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("\(step) / \(total)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(SY.muted)
                }
                content
            }
            .frame(maxWidth: 640, minHeight: 620, alignment: .top)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
        .background { ShiyangBackground() }
        .foregroundStyle(SY.ink)
        .navigationBarBackButtonHidden(true)
    }
}

private struct ShiyangBrowseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("先随便看看")
                        .font(.largeTitle.weight(.semibold))
                        .fontDesign(.serif)
                    Text("不建立档案也可以读。这里的内容不会自动变成你的个人建议。")
                        .foregroundStyle(SY.muted)
                }

                ShiyangBrowseLink(title: "地域食养", detail: "从熟悉的地方风味开始，看看日常菜怎样搭得更均衡。", symbol: "map.fill")
                ShiyangBrowseLink(title: "\(ShiyangSeason.currentSolarTerm)食养", detail: "跟着当下时节认识本地常见食材，不夸大功效。", symbol: "sun.max.fill")
                ShiyangBrowseLink(title: "一日三餐", detail: "早餐、午餐、晚餐与外卖、食堂、家庭饭桌的实际搭配。", symbol: "fork.knife")

                SectionEyebrow(title: "家常菜谱", action: "\(ShiyangCatalog.recipes.count)道 · 离线可看")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(ShiyangCatalog.recipes) { recipe in
                        NavigationLink {
                            ShiyangRecipeDetailView(recipe: recipe)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(recipe.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 118)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .clipShape(.rect(cornerRadius: 18, style: .continuous))
                                Text(recipe.title).font(.headline).lineLimit(1)
                                Text("约\(recipe.minutes)分钟")
                                    .font(.caption)
                                    .foregroundStyle(SY.muted)
                            }
                            .foregroundStyle(SY.ink)
                        }
                        .buttonStyle(QuietPressButton())
                    }
                }
            }
            .frame(maxWidth: 680)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background { ShiyangBackground() }
        .navigationTitle("食养图鉴")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ShiyangBrowseLink: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(SY.apricot)
                .frame(width: 48, height: 48)
                .background(SY.apricot.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(SY.muted)
            }
        }
        .padding(18)
        .shiyangGlass(cornerRadius: 22)
    }
}

private struct ShiyangProfileSettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("食养档案与授权")
                        .font(.largeTitle.weight(.semibold))
                        .fontDesign(.serif)
                    Text("你可以随时修改。关闭某一类授权后，之后的推荐不会再读取那部分信息。")
                        .foregroundStyle(SY.muted)
                        .lineSpacing(4)
                }

                SectionEyebrow(title: "常曦可以读取")
                VStack(spacing: 12) {
                    ShiyangConsentCard(
                        symbol: "house.and.flag.fill",
                        title: "生活信息",
                        detail: "所在地区、生活节奏和已确认的饮食偏好",
                        isOn: $store.data.shiyangUseLifestyleMemory,
                        tint: SY.tea
                    )
                    ShiyangConsentCard(
                        symbol: "heart.text.square.fill",
                        title: "健康信息",
                        detail: "体重、过敏和你主动填写的健康情况",
                        isOn: $store.data.shiyangUseHealthData,
                        tint: CX.blue
                    )
                    ShiyangConsentCard(
                        symbol: "pills.fill",
                        title: "用药信息",
                        detail: "仅用于饮食安全提醒，单独授权",
                        isOn: $store.data.shiyangUseMedicationData,
                        tint: SY.apricot
                    )
                }

                SectionEyebrow(title: "我的饭桌")
                VStack(spacing: 16) {
                    profileField("常住城市", text: $store.data.shiyangCity, prompt: "例如：上海")
                    profileField("不吃或不能吃", text: $store.data.shiyangAvoidanceNote, prompt: "例如：花生过敏、不吃香菜")
                    profileField("需要注意的健康情况", text: $store.data.shiyangHealthNote, prompt: "选填")
                    profileField("正在使用的药物", text: $store.data.shiyangMedicationNote, prompt: "选填，具体相互作用请咨询医生或药师")
                }
                .padding(18)
                .shiyangGlass(cornerRadius: 24)

                Text("食养建议用于日常饮食参考，不替代诊断、处方或医生建议。过敏与明确的安全限制始终优先。")
                    .font(.footnote)
                    .foregroundStyle(SY.muted)
                    .lineSpacing(4)
            }
            .frame(maxWidth: 680)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background { ShiyangBackground() }
        .foregroundStyle(SY.ink)
        .navigationTitle("食养档案")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func profileField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold))
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(SY.cream.opacity(0.76), in: .rect(cornerRadius: 15, style: .continuous))
        }
    }
}

private struct ShiyangWelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("常曦食养", systemImage: "fork.knife")
                            .font(.headline)
                            .foregroundStyle(SY.apricot)
                        Text("常曦有了一个新能力：食养")
                            .font(.largeTitle.weight(.semibold))
                            .fontDesign(.serif)
                        Text("结合你生活的地方、当下时节、饮食习惯和需要注意的健康情况，陪你把每天的饭吃得更适合自己。")
                            .font(.body)
                            .foregroundStyle(SY.muted)
                            .lineSpacing(5)
                    }
                    Spacer(minLength: 8)
                    Image("ChangXiCharacter")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 98, height: 98)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 18) {
                    ShiyangWelcomeRow(symbol: "refrigerator.fill", title: "看看家里有什么", detail: "文字、语音或照片都能作为开始")
                    ShiyangWelcomeRow(symbol: "wand.and.stars", title: "每次都能重新调整", detail: "不是固定菜单，缺食材也可以替换")
                    ShiyangWelcomeRow(symbol: "play.rectangle.on.rectangle.fill", title: "跟着动画慢慢做", detail: "先备食材，再一步一步完成")
                }
                .padding(20)
                .shiyangGlass(cornerRadius: 28)

                Button("开始认识我的饭桌", action: onStart)
                .buttonStyle(ShiyangPrimaryButton())
                .accessibilityIdentifier("start-shiyang")

                NavigationLink {
                    ShiyangBrowseView()
                } label: {
                    Text("先随便看看")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.plain)
                .shiyangGlass(cornerRadius: 18)
                .accessibilityIdentifier("browse-shiyang")

                Text("食养建议用于日常饮食参考，不替代诊断、处方或医生建议。涉及过敏和用药时，安全限制会优先于口味推荐。")
                    .font(.footnote)
                    .foregroundStyle(SY.muted)
                    .lineSpacing(4)
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)
        }
        .background { ShiyangBackground() }
        .foregroundStyle(SY.ink)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appeared = true }
    }
}

private struct ShiyangWelcomeRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(SY.apricot)
                .frame(width: 42, height: 42)
                .background(SY.apricot.opacity(0.11), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(SY.muted)
            }
        }
    }
}

private struct ShiyangHomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(AssistantCoordinator.self) private var assistant
    @State private var showChat = false

    private var recommendations: [ShiyangRecommendation] {
        ShiyangRecommendationEngine.recommendations(
            pantry: Set(store.data.shiyangPantryIngredientIDs),
            excluded: Set(store.data.shiyangExcludedIngredientIDs),
            maxMinutes: store.data.shiyangAvailableMinutes,
            lowSalt: store.data.shiyangLowSalt,
            likesSpicy: store.data.shiyangLikesSpicy,
            staplePreference: store.data.shiyangStaplePreference,
            mealContext: store.data.shiyangMealContext,
            goal: store.data.shiyangGoal
        )
    }

    private var current: ShiyangRecommendation {
        recommendations.first { $0.recipe.id == store.data.shiyangSelectedRecipeID }
            ?? recommendations.first
            ?? ShiyangRecommendation(recipe: ShiyangCatalog.recipes[0], matchedIDs: [], missingIDs: [], score: 0)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                header
                recommendationHero

                HStack(spacing: 12) {
                    NavigationLink {
                        ShiyangRecipeDetailView(recipe: current.recipe)
                    } label: {
                        Label("为什么这样推荐", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .shiyangGlass(cornerRadius: 18)
                    }
                    .buttonStyle(QuietPressButton())

                    NavigationLink {
                        ShiyangCookingGuideView(recipe: current.recipe)
                    } label: {
                        Label("开始做饭", systemImage: "frying.pan.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                LinearGradient(colors: [SY.amber, SY.apricot], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: .rect(cornerRadius: 18, style: .continuous)
                            )
                    }
                    .buttonStyle(QuietPressButton())
                }

                NavigationLink {
                    ShiyangPantryView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "refrigerator.fill")
                            .foregroundStyle(SY.apricot)
                            .frame(width: 42, height: 42)
                            .background(SY.apricot.opacity(0.10), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("看看家里有什么").font(.headline)
                            Text("勾选现有食材，再为这一顿重新定制")
                                .font(.subheadline)
                                .foregroundStyle(SY.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CX.faint)
                    }
                    .foregroundStyle(SY.ink)
                    .padding(18)
                    .shiyangGlass(cornerRadius: 22)
                }
                .buttonStyle(QuietPressButton())

                Button {
                    assistant.activateGeneral()
                    showChat = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            .foregroundStyle(CX.blue)
                            .frame(width: 42, height: 42)
                            .background(CX.blue.opacity(0.09), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("我想吃……").font(.headline)
                            Text("火锅、小面、外卖，也可以直接告诉常曦")
                                .font(.subheadline)
                                .foregroundStyle(SY.muted)
                        }
                        Spacer()
                        Image(systemName: "waveform")
                            .foregroundStyle(CX.faint)
                    }
                    .foregroundStyle(SY.ink)
                    .padding(18)
                    .shiyangGlass(cornerRadius: 22)
                }
                .buttonStyle(QuietPressButton())

                SectionEyebrow(title: "更多适合你的做法", action: "本地菜谱库")
                VStack(spacing: 0) {
                    ForEach(recommendations.dropFirst().prefix(3)) { item in
                        NavigationLink {
                            ShiyangRecipeDetailView(recipe: item.recipe)
                        } label: {
                            ShiyangRecipeRow(recommendation: item)
                        }
                        .buttonStyle(.plain)
                        if item.id != recommendations.dropFirst().prefix(3).last?.id {
                            Divider().overlay(SY.apricot.opacity(0.12))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .shiyangGlass(cornerRadius: 24)

                NavigationLink {
                    ShiyangProfileSettingsView()
                } label: {
                    Label("食养档案与授权", systemImage: "person.text.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SY.muted)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 34)
            .frame(maxWidth: .infinity)
        }
        .background { ShiyangBackground() }
        .foregroundStyle(SY.ink)
        .navigationTitle("食养")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showChat) {
            NavigationStack { ChatView(initialPrompt: foodChatPrompt) }
        }
        .onAppear { selectFirstAvailableIfNeeded() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("常曦食养", systemImage: "moonphase.waxing.crescent")
                    .font(.headline)
                    .foregroundStyle(SY.apricot)
                Text("今天，也好好吃饭。")
                    .font(.largeTitle.weight(.semibold))
                    .fontDesign(.serif)
                Text("\(store.data.shiyangCity) · \(ShiyangSeason.currentSolarTerm)  ·  按你的饭桌现配")
                    .font(.subheadline)
                    .foregroundStyle(SY.muted)
            }
            Spacer(minLength: 4)
            Image("ChangXiCharacter")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
        }
    }

    private var recommendationHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image(current.recipe.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 242)
                    .frame(maxWidth: .infinity)
                    .clipped()

                Text("为你现配")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SY.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(14)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今晚吃什么")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SY.apricot)
                        Text(current.recipe.title)
                            .font(.title2.weight(.semibold))
                            .fontDesign(.serif)
                    }
                    Spacer(minLength: 8)
                    Button("换一道", systemImage: "arrow.triangle.2.circlepath") { cycleRecipe() }
                        .font(.subheadline.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(SY.ink)
                        .frame(minHeight: 44)
                }

                Text(personalizedRecommendationNote)
                    .font(.subheadline)
                    .foregroundStyle(SY.muted)
                    .lineSpacing(4)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ShiyangTag(text: "\(store.data.shiyangServings)人", symbol: "person.2.fill")
                        ShiyangTag(text: "\(current.recipe.minutes)分钟", symbol: "clock.fill")
                        ShiyangTag(text: store.data.shiyangLowSalt ? "少盐" : "家常味", symbol: "leaf.fill")
                        ShiyangTag(text: current.reason, symbol: "checkmark.seal.fill")
                    }
                }
                .scrollIndicators(.hidden)
            }
            .padding(18)
        }
        .background(SY.cream.opacity(0.72), in: .rect(cornerRadius: 30, style: .continuous))
        .clipShape(.rect(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.42), lineWidth: 0.8)
        }
        .shadow(color: SY.apricot.opacity(0.12), radius: 20, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shiyang-recommendation")
    }

    private func selectFirstAvailableIfNeeded() {
        guard !recommendations.contains(where: { $0.recipe.id == store.data.shiyangSelectedRecipeID }),
              let first = recommendations.first else { return }
        store.data.shiyangSelectedRecipeID = first.recipe.id
    }

    private var personalizedRecommendationNote: String {
        let base = current.recipe.personalizationNote
        if store.data.shiyangStaplePreference == "都可以" {
            return "按你\(store.data.shiyangAvailableMinutes)分钟的做饭时间和“\(store.data.shiyangGoal)”目标现配。\(base)"
        }
        return "保留你喜欢的\(store.data.shiyangStaplePreference)，按\(store.data.shiyangAvailableMinutes)分钟和“\(store.data.shiyangGoal)”目标现配。\(base)"
    }

    private func cycleRecipe() {
        guard !recommendations.isEmpty else { return }
        let currentIndex = recommendations.firstIndex { $0.recipe.id == current.recipe.id } ?? 0
        let next = recommendations[(currentIndex + 1) % recommendations.count]
        withAnimation(.spring(duration: 0.45, bounce: 0.08)) {
            store.data.shiyangSelectedRecipeID = next.recipe.id
        }
        MoonHaptics.shared.play(enabled: store.data.haptics)
    }

    private var foodChatPrompt: String {
        let pantry = store.data.shiyangPantryIngredientIDs.compactMap { ShiyangCatalog.ingredient($0)?.name }.joined(separator: "、")
        var details = [
            "我住在\(store.data.shiyangCity)",
            "午餐\(store.data.shiyangMealContext)",
            "偏好\(store.data.shiyangStaplePreference)",
            "最近希望\(store.data.shiyangGoal)",
            "家里现在有\(pantry)",
            "做饭大约有\(store.data.shiyangAvailableMinutes)分钟"
        ]
        if !store.data.shiyangAvoidanceNote.isEmpty { details.append("不能吃或不吃：\(store.data.shiyangAvoidanceNote)") }
        if store.data.shiyangUseHealthData && !store.data.shiyangHealthNote.isEmpty { details.append("需要注意：\(store.data.shiyangHealthNote)") }
        if store.data.shiyangUseMedicationData && !store.data.shiyangMedicationNote.isEmpty { details.append("正在使用：\(store.data.shiyangMedicationNote)") }
        return "今晚我想吃点别的。请先遵守食养安全限制，再根据这些已确认信息给我可调整的一餐建议：\(details.joined(separator: "；"))。"
    }
}

private struct ShiyangRecipeRow: View {
    let recommendation: ShiyangRecommendation

    var body: some View {
        HStack(spacing: 14) {
            Image(recommendation.recipe.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 68, height: 68)
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(recommendation.recipe.title).font(.headline)
                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundStyle(SY.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CX.faint)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct ShiyangPantryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    @State private var category = ShiyangIngredientCategory.vegetable
    @State private var input = ""
    @State private var speech = SpeechController()
    @State private var photoItem: PhotosPickerItem?
    @State private var photoPreview: UIImage?
    @State private var cameraPresented = false
    @State private var cameraError: String?
    @State private var loaded = false
    @State private var showAvoidances = false

    private var categoryIngredients: [ShiyangIngredient] {
        ShiyangCatalog.ingredients.filter { $0.category == category }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("家里现在有什么？")
                        .font(.largeTitle.weight(.semibold))
                        .fontDesign(.serif)
                    Text("选你确定有的就好，缺少的食材稍后都能替换。")
                        .foregroundStyle(SY.muted)
                }

                HStack(spacing: 10) {
                    TextField("例如：番茄、鸡蛋、菌菇", text: $input)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit(addInput)
                    Button("加入", action: addInput)
                        .font(.subheadline.weight(.semibold))
                        .disabled(ShiyangCatalog.ingredientIDs(in: input).isEmpty)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .shiyangGlass(cornerRadius: 18)

                HStack(spacing: 12) {
                    Button {
                        Task {
                            if speech.isRecording { speech.stop() } else { await speech.start() }
                        }
                    } label: {
                        Label(speech.isRecording ? "说完了" : "说一说", systemImage: speech.isRecording ? "stop.fill" : "mic.fill")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await openCamera() }
                    } label: {
                        Label("拍一拍", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("相册", systemImage: "photo.fill")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                }
                .tint(SY.apricot)

                if speech.isRecording || !speech.transcript.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform")
                            .symbolEffect(.variableColor.iterative, isActive: speech.isRecording)
                            .foregroundStyle(SY.apricot)
                        Text(speech.transcript.isEmpty ? "正在听你说家里有哪些食材……" : speech.transcript)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(14)
                    .background(SY.apricot.opacity(0.09), in: .rect(cornerRadius: 16, style: .continuous))
                }

                if let photoPreview {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(uiImage: photoPreview)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(.rect(cornerRadius: 18, style: .continuous))
                        Text("照片只作为盘点参考，请在下面确认实际食材。")
                            .font(.footnote)
                            .foregroundStyle(SY.muted)
                    }
                }

                HStack {
                    Text("已选 \(selected.count) 样")
                        .font(.headline)
                    Spacer()
                    Button("清空") { selected.removeAll() }
                        .font(.subheadline)
                        .disabled(selected.isEmpty)
                }

                Picker("食材分类", selection: $category) {
                    ForEach(ShiyangIngredientCategory.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                    ForEach(categoryIngredients) { ingredient in
                        Button {
                            toggle(ingredient.id)
                        } label: {
                            VStack(spacing: 9) {
                                Image(systemName: ingredient.symbol)
                                    .font(.title2.weight(.medium))
                                    .foregroundStyle(selected.contains(ingredient.id) ? .white : color(for: ingredient.category))
                                Text(ingredient.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(selected.contains(ingredient.id) ? .white : SY.ink)
                            }
                            .frame(maxWidth: .infinity, minHeight: 86)
                            .background {
                                if selected.contains(ingredient.id) {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(LinearGradient(colors: [SY.amber, SY.apricot], startPoint: .topLeading, endPoint: .bottomTrailing))
                                } else {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                }
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(selected.contains(ingredient.id) ? .clear : color(for: ingredient.category).opacity(0.16), lineWidth: 0.8)
                            }
                        }
                        .buttonStyle(QuietPressButton())
                        .accessibilityLabel("\(ingredient.name)，\(selected.contains(ingredient.id) ? "已选择" : "未选择")")
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    TextField("常住城市", text: Binding(
                        get: { store.data.shiyangCity },
                        set: { store.data.shiyangCity = $0 }
                    ))
                    .textContentType(.addressCity)

                    Stepper("\(store.data.shiyangServings)人吃", value: Binding(
                        get: { store.data.shiyangServings },
                        set: { store.data.shiyangServings = $0 }
                    ), in: 1...6)

                    HStack {
                        Text("能做多久")
                        Spacer()
                        Picker("能做多久", selection: Binding(
                            get: { store.data.shiyangAvailableMinutes },
                            set: { store.data.shiyangAvailableMinutes = $0 }
                        )) {
                            ForEach([15, 20, 30, 45, 60], id: \.self) { Text("\($0)分钟").tag($0) }
                        }
                        .labelsHidden()
                    }

                    Toggle("少盐一点", isOn: Binding(
                        get: { store.data.shiyangLowSalt },
                        set: { store.data.shiyangLowSalt = $0 }
                    ))
                    Toggle("可以有一点辣", isOn: Binding(
                        get: { store.data.shiyangLikesSpicy },
                        set: { store.data.shiyangLikesSpicy = $0 }
                    ))

                    DisclosureGroup("有些食材不能吃", isExpanded: $showAvoidances) {
                        VStack(spacing: 0) {
                            ForEach(["egg", "shrimp", "fish", "tofu", "beef", "pork"], id: \.self) { id in
                                if let ingredient = ShiyangCatalog.ingredient(id) {
                                    Toggle(ingredient.name, isOn: Binding(
                                        get: { store.data.shiyangExcludedIngredientIDs.contains(id) },
                                        set: { excluded in
                                            if excluded {
                                                if !store.data.shiyangExcludedIngredientIDs.contains(id) {
                                                    store.data.shiyangExcludedIngredientIDs.append(id)
                                                }
                                                selected.remove(id)
                                            } else {
                                                store.data.shiyangExcludedIngredientIDs.removeAll { $0 == id }
                                            }
                                        }
                                    ))
                                    .padding(.top, 10)
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .shiyangGlass(cornerRadius: 22)

                Button("用这些食材现配菜谱") {
                    let result = ShiyangRecommendationEngine.recommendations(
                        pantry: selected,
                        excluded: Set(store.data.shiyangExcludedIngredientIDs),
                        maxMinutes: store.data.shiyangAvailableMinutes,
                        lowSalt: store.data.shiyangLowSalt,
                        likesSpicy: store.data.shiyangLikesSpicy,
                        staplePreference: store.data.shiyangStaplePreference,
                        mealContext: store.data.shiyangMealContext,
                        goal: store.data.shiyangGoal
                    )
                    store.data.shiyangPantryIngredientIDs = selected.sorted()
                    if let first = result.first { store.data.shiyangSelectedRecipeID = first.recipe.id }
                    MoonHaptics.shared.play(success: true, enabled: store.data.haptics)
                    dismiss()
                }
                .buttonStyle(ShiyangPrimaryButton())
                .disabled(selected.isEmpty)
                .accessibilityIdentifier("generate-shiyang-recipe")
            }
            .frame(maxWidth: 680)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background { ShiyangBackground() }
        .foregroundStyle(SY.ink)
        .navigationTitle("我的食材")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            selected = Set(store.data.shiyangPantryIngredientIDs)
            loaded = true
        }
        .onDisappear { speech.stop() }
        .onChange(of: speech.transcript) { _, value in input = value }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                await MainActor.run { photoPreview = image }
            }
        }
        .sheet(isPresented: $cameraPresented) {
            CameraCapture { image in
                if let image { photoPreview = image }
                cameraPresented = false
            }
        }
        .alert("无法使用相机", isPresented: Binding(
            get: { cameraError != nil },
            set: { if !$0 { cameraError = nil } }
        )) {
            Button("知道了", role: .cancel) { cameraError = nil }
        } message: {
            Text(cameraError ?? "请从相册选择照片。")
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        MoonHaptics.shared.play(enabled: store.data.haptics)
    }

    private func addInput() {
        let ids = ShiyangCatalog.ingredientIDs(in: input)
        selected.formUnion(ids)
        input = ""
    }

    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraError = "当前设备没有可用相机，可以从相册选择食材照片。"
            return
        }
        let authorized = await AVCaptureDevice.requestAccess(for: .video)
        if authorized {
            cameraPresented = true
        } else {
            cameraError = "相机权限未开启，可以改用相册或文字输入。"
        }
    }

    private func color(for category: ShiyangIngredientCategory) -> Color {
        switch category {
        case .vegetable: SY.tea
        case .protein: SY.apricot
        case .staple: SY.amber
        case .pantry: CX.blue
        }
    }
}

private struct ShiyangRecipeDetailView: View {
    @Environment(AppStore.self) private var store
    let recipe: ShiyangRecipe

    private var pantry: Set<String> { Set(store.data.shiyangPantryIngredientIDs) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Image(recipe.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(.rect(cornerRadius: 30, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        LinearGradient(colors: [.clear, .black.opacity(0.58)], startPoint: .center, endPoint: .bottom)
                            .clipShape(.rect(cornerRadius: 30, style: .continuous))
                            .overlay(alignment: .bottomLeading) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(recipe.title)
                                        .font(.title.weight(.semibold))
                                        .fontDesign(.serif)
                                    Text(recipe.subtitle).font(.subheadline)
                                }
                                .foregroundStyle(.white)
                                .padding(20)
                            }
                    }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ShiyangTag(text: "\(store.data.shiyangServings)人", symbol: "person.2.fill")
                        ShiyangTag(text: "\(recipe.minutes)分钟", symbol: "clock.fill")
                        ForEach(recipe.tags, id: \.self) { ShiyangTag(text: $0, symbol: "sparkles") }
                    }
                }
                .scrollIndicators(.hidden)

                VStack(alignment: .leading, spacing: 8) {
                    Text("为什么是这道")
                        .font(.title3.weight(.semibold))
                    Text(recipe.personalizationNote)
                        .foregroundStyle(SY.muted)
                    Text(recipe.seasonalNote)
                        .font(.subheadline)
                        .foregroundStyle(SY.tea)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("食材")
                            .font(.title2.weight(.semibold))
                            .fontDesign(.serif)
                        Spacer()
                        Text("按\(store.data.shiyangServings)人份")
                            .font(.subheadline)
                            .foregroundStyle(SY.muted)
                    }
                    ForEach(recipe.ingredients, id: \.ingredientID) { item in
                        let ingredient = ShiyangCatalog.ingredient(item.ingredientID)
                        HStack(spacing: 12) {
                            Image(systemName: pantry.contains(item.ingredientID) ? "checkmark.circle.fill" : "cart.badge.plus")
                                .foregroundStyle(pantry.contains(item.ingredientID) ? SY.tea : SY.apricot)
                            Text(ingredient?.name ?? item.ingredientID)
                            Spacer()
                            Text(scaledAmount(item.amountForTwo))
                                .foregroundStyle(SY.muted)
                            if !item.required {
                                Text("可选").font(.caption2).foregroundStyle(SY.muted)
                            }
                        }
                        .frame(minHeight: 40)
                    }
                }
                .padding(18)
                .shiyangGlass(cornerRadius: 24)

                NavigationLink {
                    ShiyangCookingGuideView(recipe: recipe)
                } label: {
                    Label("开始做饭", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ShiyangPrimaryButton())
                .accessibilityIdentifier("start-cooking")

                Text("烹饪过程中可以暂停、重复步骤，也可以临时替换食材。")
                    .font(.footnote)
                    .foregroundStyle(SY.muted)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 680)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background { ShiyangBackground() }
        .foregroundStyle(SY.ink)
        .navigationTitle("菜谱")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scaledAmount(_ amount: String) -> String {
        guard store.data.shiyangServings != 2 else { return amount }
        return "约\(store.data.shiyangServings)人份"
    }
}

private struct ShiyangCookingGuideView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingIngredients = true
    @State private var ingredientsArrived = false
    @State private var stepIndex = 0
    @State private var remaining = 0
    @State private var timerRunning = false
    @State private var substitutions: [String: String] = [:]
    @State private var showSubstitutions = false

    let recipe: ShiyangRecipe

    private var step: ShiyangCookingStep { recipe.steps[stepIndex] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title)
                            .font(.title2.weight(.semibold))
                            .fontDesign(.serif)
                        Text(showingIngredients ? "先把食材请上桌" : "第 \(stepIndex + 1) 步 · 共 \(recipe.steps.count) 步")
                            .font(.subheadline)
                            .foregroundStyle(SY.muted)
                    }
                    Spacer()
                    Button("临时换食材", systemImage: "arrow.left.arrow.right") { showSubstitutions = true }
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                }

                if showingIngredients {
                    ingredientStage
                } else {
                    stepStage
                }
            }
            .frame(maxWidth: 680)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background { ShiyangBackground() }
        .foregroundStyle(SY.ink)
        .navigationTitle("跟着做")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSubstitutions) {
            ShiyangSubstitutionSheet(recipe: recipe, substitutions: $substitutions)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onDisappear { timerRunning = false }
    }

    private var ingredientStage: some View {
        VStack(spacing: 22) {
            ZStack(alignment: .bottom) {
                Image(recipe.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 330)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(.rect(cornerRadius: 30, style: .continuous))
                    .opacity(0.28)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 12) {
                    ForEach(Array(recipe.ingredients.prefix(6).enumerated()), id: \.element.ingredientID) { index, item in
                        let shownID = substitutions[item.ingredientID] ?? item.ingredientID
                        let ingredient = ShiyangCatalog.ingredient(shownID)
                        VStack(spacing: 8) {
                            Image(systemName: ingredient?.symbol ?? "leaf.fill")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(SY.apricot)
                            Text(ingredient?.name ?? shownID)
                                .font(.subheadline.weight(.semibold))
                            Text(item.amountForTwo)
                                .font(.caption)
                                .foregroundStyle(SY.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 92)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20, style: .continuous))
                        .scaleEffect(ingredientsArrived || reduceMotion ? 1 : 0.72)
                        .offset(y: ingredientsArrived || reduceMotion ? 0 : -34)
                        .opacity(ingredientsArrived ? 1 : 0)
                        .animation(
                            reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.55, bounce: 0.18).delay(Double(index) * 0.09),
                            value: ingredientsArrived
                        )
                    }
                }
                .padding(16)
            }

            Text("先认一遍食材，做饭时就不会手忙脚乱。")
                .font(.subheadline)
                .foregroundStyle(SY.muted)

            Button("食材备好了") {
                withAnimation(.spring(duration: 0.45, bounce: 0.08)) {
                    showingIngredients = false
                    stepIndex = 0
                    resetTimer()
                }
            }
            .buttonStyle(ShiyangPrimaryButton())
        }
        .onAppear {
            ingredientsArrived = false
            DispatchQueue.main.async { ingredientsArrived = true }
        }
    }

    private var stepStage: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                ForEach(recipe.steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= stepIndex ? SY.apricot : SY.apricot.opacity(0.16))
                        .frame(height: 6)
                        .animation(.spring(duration: 0.35), value: stepIndex)
                }
            }
            .accessibilityLabel("已进行到第\(stepIndex + 1)步，共\(recipe.steps.count)步")

            ZStack {
                Image(recipe.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 330)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(.rect(cornerRadius: 30, style: .continuous))

                LinearGradient(colors: [.clear, .black.opacity(0.52)], startPoint: .center, endPoint: .bottom)
                    .clipShape(.rect(cornerRadius: 30, style: .continuous))

                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        Image(systemName: step.symbol)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 66, height: 66)
                            .background(.ultraThinMaterial, in: Circle())
                            .symbolEffect(.bounce, value: stepIndex)
                        Spacer()
                        if step.seconds > 0 {
                            timerView
                        }
                    }
                }
                .padding(18)
            }
            .id(step.id)
            .transition(.blurReplace)

            VStack(alignment: .leading, spacing: 9) {
                Text(personalized(step.title))
                    .font(.title.weight(.semibold))
                    .fontDesign(.serif)
                Text(personalized(step.detail))
                    .font(.body)
                    .foregroundStyle(SY.muted)
                    .lineSpacing(6)
            }

            if !step.ingredientIDs.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(step.ingredientIDs, id: \.self) { id in
                            let shownID = substitutions[id] ?? id
                            if let ingredient = ShiyangCatalog.ingredient(shownID) {
                                ShiyangTag(text: ingredient.name, symbol: ingredient.symbol)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            HStack(spacing: 10) {
                Button("上一步", systemImage: "chevron.left") { previousStep() }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .buttonStyle(.bordered)
                    .disabled(stepIndex == 0)

                Button("再看一遍", systemImage: "arrow.counterclockwise") {
                    withAnimation(.spring(duration: 0.35)) { resetTimer() }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .buttonStyle(.bordered)
            }
            .tint(SY.apricot)

            Button(stepIndex == recipe.steps.count - 1 ? "完成这道菜" : "下一步") {
                nextStep()
            }
            .buttonStyle(ShiyangPrimaryButton())
            .accessibilityIdentifier("next-cooking-step")
        }
        .task(id: timerRunning) {
            guard timerRunning else { return }
            while timerRunning && remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, timerRunning else { return }
                remaining -= 1
            }
            if remaining == 0 { timerRunning = false }
        }
    }

    private var timerView: some View {
        Button {
            timerRunning.toggle()
        } label: {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                Circle()
                    .trim(from: 0, to: timerProgress)
                    .stroke(SY.amber, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(timeLabel)
                        .font(.headline.monospacedDigit())
                    Image(systemName: timerRunning ? "pause.fill" : "play.fill")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
            }
            .frame(width: 78, height: 78)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(timerRunning ? "暂停计时" : "开始计时")
    }

    private var timerProgress: Double {
        guard step.seconds > 0 else { return 0 }
        return 1 - Double(remaining) / Double(step.seconds)
    }

    private var timeLabel: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private func personalized(_ text: String) -> String {
        substitutions.reduce(text) { result, substitution in
            guard let original = ShiyangCatalog.ingredient(substitution.key)?.name,
                  let replacement = ShiyangCatalog.ingredient(substitution.value)?.name else { return result }
            return result.replacingOccurrences(of: original, with: replacement)
        }
    }

    private func resetTimer() {
        timerRunning = false
        remaining = step.seconds
    }

    private func previousStep() {
        guard stepIndex > 0 else { return }
        withAnimation(.spring(duration: 0.4, bounce: 0.08)) { stepIndex -= 1 }
        resetTimer()
    }

    private func nextStep() {
        timerRunning = false
        if stepIndex < recipe.steps.count - 1 {
            withAnimation(.spring(duration: 0.4, bounce: 0.08)) { stepIndex += 1 }
            resetTimer()
        } else {
            MoonHaptics.shared.play(success: true, enabled: store.data.haptics)
            withAnimation(.spring(duration: 0.45, bounce: 0.10)) {
                showingIngredients = true
                stepIndex = 0
                ingredientsArrived = false
            }
        }
    }
}

private struct ShiyangSubstitutionSheet: View {
    let recipe: ShiyangRecipe
    @Binding var substitutions: [String: String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(recipe.ingredients, id: \.ingredientID) { item in
                    Section(ShiyangCatalog.ingredient(item.ingredientID)?.name ?? item.ingredientID) {
                        Button("使用原食材") { substitutions.removeValue(forKey: item.ingredientID) }
                        ForEach(item.alternatives, id: \.self) { alternativeID in
                            if let ingredient = ShiyangCatalog.ingredient(alternativeID) {
                                Button {
                                    substitutions[item.ingredientID] = alternativeID
                                } label: {
                                    HStack {
                                        Label(ingredient.name, systemImage: ingredient.symbol)
                                        Spacer()
                                        if substitutions[item.ingredientID] == alternativeID {
                                            Image(systemName: "checkmark").foregroundStyle(SY.apricot)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("临时换食材")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

private struct ShiyangTag: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SY.ink)
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .background(.ultraThinMaterial, in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct ShiyangPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 18)
            .background(
                LinearGradient(colors: [SY.amber, SY.apricot, Color(.displayP3, red: 0.78, green: 0.28, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: 19, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .strokeBorder(.white.opacity(0.38), lineWidth: 0.8)
            }
            .shadow(color: SY.apricot.opacity(isEnabled ? 0.24 : 0), radius: 12, y: 6)
            .opacity(isEnabled ? (configuration.isPressed ? 0.86 : 1) : 0.40)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.spring(duration: 0.20, bounce: 0), value: configuration.isPressed)
    }
}

private struct ShiyangGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(SY.cream, in: .rect(cornerRadius: cornerRadius, style: .continuous))
                .overlay { border }
        } else if #available(iOS 26, *) {
            content.glassEffect(.regular.tint(SY.cream.opacity(0.22)).interactive(), in: .rect(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(.regularMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
                .overlay { border }
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(SY.apricot.opacity(0.16), lineWidth: 0.8)
    }
}

private struct ShiyangBackground: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.48, 0.45], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    SY.cream, Color.white, CX.moonlight.opacity(0.20),
                    Color.white, SY.apricot.opacity(0.12), SY.cream,
                    SY.amber.opacity(0.10), Color.white, CX.moonlight.opacity(0.10)
                ]
            )
            .opacity(0.74)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private extension View {
    func shiyangGlass(cornerRadius: CGFloat) -> some View {
        modifier(ShiyangGlassModifier(cornerRadius: cornerRadius))
    }
}
