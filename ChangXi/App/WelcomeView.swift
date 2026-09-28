import SwiftUI

struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var step = 0
    @State private var name = ""
    @State private var focuses = Set<String>()
    @State private var conditions = Set<String>()
    @State private var medication: Bool?
    @State private var support = ""
    @State private var priority = ""
    @State private var accepted = false

    private let questionCount = 6
    private let focusOptions = ["日常记录", "用药提醒", "报告管理", "饮食运动", "家人照护"]
    private let conditionOptions = ["暂无", "高血压", "糖尿病", "高血脂", "冠心病", "其他"]
    private let supportOptions = ["自己使用", "家人协助", "与医生共同管理"]
    private let priorityOptions = ["健康首页", "记录数据", "今日计划", "服务预约"]

    var body: some View {
        ZStack {
            MoonBackground(illustrated: true)

            if step == 0 {
                accessView
                    .transition(pageTransition)
            } else {
                questionnaire
                    .transition(pageTransition)
            }
        }
        .foregroundStyle(CX.ink)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .onAppear {
            name = store.data.name
            if auth.isAuthenticated { advanceToQuestions() }
        }
        .onChange(of: auth.isAuthenticated) { _, signedIn in
            guard signedIn else { return }
            store.data.isGuestMode = false
            advanceToQuestions()
        }
    }

    private var accessView: some View {
        ScrollView {
            VStack(spacing: CXSpacing.xl) {
                Spacer(minLength: 24)

                MoonPoolView(state: .idle, character: true, compact: true)
                    .frame(maxWidth: 500)
                    .frame(height: 260)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("常曦")
                        .font(CXTypography.display)
                    Text("记录健康，连接照护")
                        .font(CXTypography.body)
                        .foregroundStyle(CX.muted)
                }

                VStack(spacing: 12) {
                    NavigationLink {
                        DemoAuthView(initialMode: "登录")
                    } label: {
                        Text("登录")
                    }
                    .buttonStyle(PrimaryButton())
                    .accessibilityIdentifier("onboarding-login")

                    NavigationLink {
                        DemoAuthView(initialMode: "注册")
                    } label: {
                        Text("创建账户")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("onboarding-register")

                    Button("游客使用") {
                        store.data.isGuestMode = true
                        store.data.demoSignedIn = false
                        advanceToQuestions()
                    }
                    .font(CXTypography.supporting.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("onboarding-guest")
                }
                .frame(maxWidth: 520)

                HStack(spacing: 18) {
                    NavigationLink("使用说明") {
                        InfoView(
                            title: "使用说明",
                            text: "常曦用于健康记录和日常照护协助，不能代替医生诊断或治疗。"
                        )
                    }
                    NavigationLink("隐私说明") { PrivacyView() }
                }
                .font(CXTypography.meta.weight(.semibold))
                .foregroundStyle(CX.muted)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, CXSpacing.xl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var questionnaire: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    if step == 1 {
                        step = 0
                    } else {
                        move(to: step - 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")

                Spacer()

                Text("第 \(step) 题，共 \(questionCount) 题")
                    .font(CXTypography.meta.weight(.semibold))
                    .foregroundStyle(CX.muted)
                    .monospacedDigit()

                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, CXSpacing.md)

            ProgressView(value: Double(step), total: Double(questionCount))
                .tint(CX.actionPrimary)
                .padding(.horizontal, CXSpacing.xl)

            ScrollView {
                VStack(alignment: .leading, spacing: CXSpacing.xl) {
                    questionContent
                        .id(step)
                        .transition(pageTransition)
                }
                .frame(maxWidth: 600, alignment: .leading)
                .padding(CXSpacing.xl)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)

            Button(step == questionCount ? "完成" : "继续") {
                if step == questionCount { finish() } else { move(to: step + 1) }
            }
            .buttonStyle(PrimaryButton())
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.45)
            .padding(.horizontal, CXSpacing.xl)
            .padding(.bottom, CXSpacing.md)
            .accessibilityIdentifier(step == questionCount ? "finish-onboarding" : "onboarding-continue")
        }
    }

    @ViewBuilder
    private var questionContent: some View {
        switch step {
        case 1:
            questionHeader("怎么称呼你？", subtitle: "这个称呼会显示在首页。")
            TextField("输入你的称呼", text: $name)
                .textContentType(.nickname)
                .submitLabel(.continue)
                .font(CXTypography.title)
                .padding(.horizontal, CXSpacing.lg)
                .frame(minHeight: 64)
                .background(CX.raisedSurface, in: .rect(cornerRadius: CXRadius.md, style: .continuous))

        case 2:
            questionHeader("你最想先用哪些功能？", subtitle: "可多选。")
            choiceGrid(focusOptions, selections: focuses) { option in
                toggle(option, in: &focuses)
            }

        case 3:
            questionHeader("目前有哪些慢性病？", subtitle: "可多选，也可以选择暂无。")
            choiceGrid(conditionOptions, selections: conditions) { option in
                if option == "暂无" {
                    conditions = conditions.contains("暂无") ? [] : ["暂无"]
                } else {
                    conditions.remove("暂无")
                    toggle(option, in: &conditions)
                }
            }

        case 4:
            questionHeader("是否长期用药？", subtitle: "以后可在用药管理中补充药名。")
            choiceGrid(["是", "否"], selections: medication.map { [$0 ? "是" : "否"] } ?? []) { option in
                medication = option == "是"
            }

        case 5:
            questionHeader("平时由谁一起管理健康？", subtitle: nil)
            choiceGrid(supportOptions, selections: support.isEmpty ? [] : [support]) { support = $0 }

        default:
            questionHeader("首页先放什么？", subtitle: "之后可在设置中调整。")
            choiceGrid(priorityOptions, selections: priority.isEmpty ? [] : [priority]) { priority = $0 }

            Toggle("我已阅读使用说明与隐私说明", isOn: $accepted)
                .font(CXTypography.supporting)
                .padding(CXSpacing.lg)
                .cxContentSurface(cornerRadius: CXRadius.md)
        }
    }

    private func questionHeader(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CXTypography.display)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.muted)
            }
        }
    }

    private func choiceGrid(
        _ options: [String],
        selections: Set<String>,
        action: @escaping (String) -> Void
    ) -> some View {
        LazyVGrid(
            columns: CXLayout.adaptiveColumns(minimum: 145, dynamicTypeSize: dynamicTypeSize),
            spacing: 12
        ) {
            ForEach(options, id: \.self) { option in
                Button {
                    action(option)
                } label: {
                    HStack(spacing: 10) {
                        Text(option)
                            .font(CXTypography.section)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: selections.contains(option) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selections.contains(option) ? CX.actionPrimary : CX.faint)
                    }
                    .padding(.horizontal, CXSpacing.md)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .background(
                        selections.contains(option) ? CX.actionPrimary.opacity(0.09) : CX.surface,
                        in: .rect(cornerRadius: CXRadius.md, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous)
                            .stroke(selections.contains(option) ? CX.actionPrimary.opacity(0.45) : CX.separator.opacity(0.18))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case 1: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2: !focuses.isEmpty
        case 3: !conditions.isEmpty
        case 4: medication != nil
        case 5: !support.isEmpty
        case 6: !priority.isEmpty && accepted
        default: false
        }
    }

    private var pageTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity)
    }

    private func advanceToQuestions() {
        guard step == 0 else { return }
        move(to: 1)
    }

    private func move(to next: Int) {
        guard (0...questionCount).contains(next) else { return }
        MoonHaptics.shared.play(success: false, enabled: store.data.haptics)
        if reduceMotion {
            step = next
        } else {
            withAnimation(.smooth(duration: 0.32)) { step = next }
        }
    }

    private func toggle(_ option: String, in values: inout Set<String>) {
        if values.contains(option) { values.remove(option) } else { values.insert(option) }
    }

    private func finish() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        store.data.name = trimmedName
        store.data.person = "\(trimmedName)（本人）"
        store.data.healthFocuses = focuses.sorted()
        store.data.chronicConditions = conditions.sorted()
        store.data.usesLongTermMedication = medication
        store.data.supportPreference = support
        store.data.homePriority = priority
        store.data.onboarded = true
        MoonHaptics.shared.play(success: true, enabled: store.data.haptics)
    }
}
