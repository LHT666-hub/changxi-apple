import SwiftUI
import UserNotifications

struct ProfileView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("我的")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)

                Text(store.data.name)
                    .font(CXTypography.display)

                Text("健康资料、照护关系和常曦记忆都从这里管理。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            NavigationLink { AccountView() } label: {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(CX.actionPrimary)
                        .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.data.name)
                            .font(CXTypography.title)
                        Text("家庭医生：蒋医生")
                            .font(CXTypography.supporting)
                            .foregroundStyle(CX.muted)
                    }

                    Spacer()
                    Text("个人资料")
                        .font(CXTypography.meta.weight(.semibold))
                        .foregroundStyle(CX.actionPrimary)
                }
                .padding(CXSpacing.lg)
                .cxContentSurface(cornerRadius: CXRadius.lg)
            }
            .buttonStyle(QuietPressButton())

            NavigationLink { MemoryView() } label: {
                MemorySummaryCard(
                    confirmed: store.data.memories.filter(\.confirmed).count,
                    pending: store.pendingMemories
                )
            }
            .buttonStyle(.plain)

            SectionEyebrow(title: "健康与照护")
            VStack(spacing: CXSpacing.sm) {
                ProfileEntryRow(
                    title: "我的健康档案",
                    subtitle: "健康数据 · 用药记录 · 检查报告",
                    icon: "heart.fill",
                    tint: CX.statusCritical
                ) { HealthArchiveView() }

                ProfileEntryRow(
                    title: "家人与照护",
                    subtitle: "服务对象 · 照护计划",
                    icon: "person.2.fill",
                    tint: CX.actionPrimary
                ) { FamilyView() }

                ProfileEntryRow(
                    title: "我的设备",
                    subtitle: "设备管理 · 数据同步",
                    icon: "applewatch",
                    tint: CX.statusPositive
                ) { DevicesView() }
            }

            SectionEyebrow(title: "设置")
            VStack(spacing: CXSpacing.sm) {
                ProfileEntryRow(title: "玄同连接", subtitle: "服务地址 · 连接检查", icon: "network", tint: CX.actionPrimary) { BackendConnectionView() }
                ProfileEntryRow(title: "隐私与授权", subtitle: "数据安全 · 权限管理", icon: "checkmark.shield.fill", tint: CX.statusPositive) { PrivacyView() }
                ProfileEntryRow(title: "通知设置", subtitle: "用药提醒 · 健康提醒", icon: "bell.fill", tint: CX.statusWarning) { NotificationSettingsView() }
                ProfileEntryRow(title: "显示与触感", subtitle: "大字模式 · 动态效果", icon: "textformat.size", tint: CX.actionPrimary) { AccessibilitySettingsView() }
                ProfileEntryRow(title: "语音输入", subtitle: "本机识别 · 云端方言识别", icon: "waveform", tint: CX.actionPrimary) { SpeechSettingsView() }
                ProfileEntryRow(title: "帮助与反馈", subtitle: "使用指南 · 常见问题", icon: "questionmark.circle.fill", tint: CX.brandIvory) { HelpView() }
            }

            DemoLabel()
        }
        .navigationTitle("我的")
    }
}

private struct ProfileEntryRow<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    @ViewBuilder let destination: Destination

    init(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.destination = destination()
    }

    var body: some View {
        NavigationLink { destination } label: {
            HStack(spacing: CXSpacing.md) {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.08), in: .rect(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(CXTypography.section)
                        .foregroundStyle(CX.ink)
                    Text(subtitle)
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.muted)
                        .lineLimit(2)
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
}

struct BackendConnectionView: View {
    @Environment(AuthSession.self) private var auth
    @State private var address = AppConfiguration.apiBaseURL.absoluteString
    @State private var checking = false
    @State private var status = "尚未检查连接"
    @State private var connected = false

    var body: some View {
        Page {
            Card {
                Label("常曦 × 玄同", systemImage: "network").font(.title2.weight(.medium))
                Text("连接正在运行的玄同服务，让常曦调用家庭医生团队。")
                    .font(.subheadline).foregroundStyle(CX.muted)
                TextField("https://你的服务器地址", text: $address)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(.URL).padding(14)
                    .background(CX.mist, in: .rect(cornerRadius: 14))
                    .accessibilityIdentifier("backend-address")
                Button {
                    Task { await connect() }
                } label: {
                    HStack { if checking { ProgressView().tint(.white) }; Text(checking ? "正在连接…" : "检查并使用这个地址") }
                }.buttonStyle(PrimaryButton()).disabled(checking)
                    .accessibilityIdentifier("check-backend")
                Label(status, systemImage: connected ? "checkmark.circle" : "info.circle")
                    .font(.footnote).foregroundStyle(connected ? CX.teal : CX.muted)
                    .accessibilityIdentifier("backend-status")
            }
            Card {
                Text("当前可用的后端能力").font(.headline)
                Text("对话事件、健康测量事件、照护任务与任务完成。")
                Text("此版本尚未启用远程账户登录、文档归档和健康记录跨设备恢复。最新玄同接口仍需联调，资料目前保存在本机。")
                    .font(.footnote).foregroundStyle(CX.muted)
            }
            Text("GitHub 是代码仓库地址，不是运行中的服务。真机请使用手机能访问的服务器地址；127.0.0.1 仅适用于在同一台 Mac 上运行的模拟器。")
                .font(.footnote).foregroundStyle(CX.muted)
        }.navigationTitle("玄同连接")
        .onChange(of: address) { connected = false; status = "地址已更改，请重新检查" }
    }

    @MainActor private func connect() async {
        guard let url = AppConfiguration.sanitizedURL(address),
              url.scheme == "https" || AppConfiguration.allowsInsecureHTTP(url) else {
            status = "请输入服务的根地址，例如 https://api.example.com，不要填 GitHub 仓库地址。"; return
        }
        #if !targetEnvironment(simulator)
        if AppConfiguration.isLocalDevelopment(url) {
            status = "这个地址指向手机自己，请改为后端服务器地址。"; return
        }
        #endif
        checking = true; connected = false
        defer { checking = false }
        do {
            let probe = try await BackendProbe.check(url)
            if url != AppConfiguration.apiBaseURL { auth.logout() }
            UserDefaults.standard.set(url.absoluteString, forKey: "cx.backend.url")
            connected = true
            if probe.provider == "mock" {
                status = "已连接玄同 · 当前为 Mock 测试模型，非真实 AI"
            } else if let provider = probe.provider {
                status = "已连接玄同 · \(provider)"
            } else {
                status = "已连接玄同"
            }
        } catch {
            status = "未能连接，地址没有更改。请确认玄同已经启动、网络可达。"
        }
    }
}

private struct MemorySummaryCard: View {
    let confirmed: Int
    let pending: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("常曦记忆", systemImage: "moon.stars.fill")
                    .font(.title2.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.74)
            }

            Text("记住了 \(confirmed) 条重要信息")
                .font(.headline)
                .monospacedDigit()

            Text(pending == 0 ? "没有待确认的记忆" : "还有 \(pending) 条等待你确认")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: [CX.blue, Color(.displayP3, red: 0.10, green: 0.20, blue: 0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 22, style: .continuous)
        )
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "moonphase.waxing.crescent")
                .font(.system(.largeTitle, design: .rounded, weight: .light))
                .foregroundStyle(.white.opacity(0.10))
                .scaleEffect(2.4)
                .offset(x: -20, y: -16)
                .accessibilityHidden(true)
        }
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .shadow(color: CX.blue.opacity(0.20), radius: 18, y: 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct MemoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @State private var filter = "待确认"
    @State private var editing: MemoryItem?
    @State private var deleting: MemoryItem?
    private var items: [MemoryItem] {
        store.data.memories.filter { item in
            switch filter { case "待确认": !item.confirmed; case "已记住": item.confirmed; default: item.category == filter && item.confirmed }
        }
    }
    var body: some View {
        Page {
            Text("我会记住你允许我记住的事").font(.title2)
            MoonPoolView(character: true, compact: true)
            if !store.data.rememberAllowed { Label("记忆已暂停。现有记忆仍可管理。", systemImage: "pause.circle").foregroundStyle(CX.muted) }
            Picker("记忆分类", selection: $filter) { ForEach(["待确认", "已记住", "偏好", "健康档案"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
            if items.isEmpty { CXEmptyState(title: "这里暂时没有记忆", message: "只有你确认过的内容，才会留在常曦记忆里。", icon: "moon.stars") }
            ForEach(items) { item in
                Card {
                    Label(item.title, systemImage: item.category == "偏好" ? "heart.text.clipboard" : "doc.text").font(.title2.bold())
                    Text(item.text).lineSpacing(5)
                    Text("来源：\(item.source)").font(.footnote).foregroundStyle(CX.muted)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 14) { actions(item) }
                        VStack(alignment: .leading, spacing: 8) { actions(item) }
                    }
                }
            }
            BrandFooter()
        }.navigationTitle("常曦记忆")
        .sheet(item: $editing) { item in NavigationStack { MemoryEditView(item: item) } }
        .confirmationDialog("不再记住这条信息？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("删除记忆", role: .destructive) { if let item = deleting { store.data.memories.removeAll { $0.id == item.id } }; deleting = nil }
        }
    }
    @ViewBuilder private func actions(_ item: MemoryItem) -> some View {
        if !item.confirmed {
            Button { if let i = store.data.memories.firstIndex(where: { $0.id == item.id }) { store.data.memories[i].confirmed = true }; MoonHaptics.shared.play(success: true, enabled: store.data.haptics); archiveMemory(item) } label: { Label("确认", systemImage: "checkmark") }.buttonStyle(.borderedProminent).disabled(!store.data.rememberAllowed).frame(minHeight: 44)
        }
        Button { editing = item } label: { Label("修改", systemImage: "pencil") }.frame(minHeight: 44)
        Button(role: .destructive) { deleting = item } label: { Label(item.confirmed ? "删除" : "不记住", systemImage: "xmark") }.frame(minHeight: 44)
    }

    /// Task #25：确认记忆后，尽力把它归档到云端 health-records（record_type = memory）。
    /// 离线不发请求；归档失败静默，绝不影响本地确认。
    private func archiveMemory(_ item: MemoryItem) {
        guard AppConfiguration.useRemoteAPI else { return }
        let pid = PatientContext.effectiveID(auth)
        Task { @MainActor in
            await HealthSyncService.shared.archive(
                recordType: "memory",
                title: item.title,
                content: [
                    "text": .string(item.text),
                    "category": .string(item.category),
                    "memory_id": .string(item.id.uuidString)
                ],
                patientID: pid
            )
        }
    }
}

struct MemoryEditView: View {
    var item: MemoryItem
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var category = "健康档案"
    var body: some View {
        Form {
            Section(item.title) { TextEditor(text: $text).frame(minHeight: 160); Picker("分类", selection: $category) { Text("健康档案").tag("健康档案"); Text("偏好").tag("偏好") } }
            Section { Button("保存修改") { if let i = store.data.memories.firstIndex(where: { $0.id == item.id }) { store.data.memories[i].text = text; store.data.memories[i].category = category }; dismiss() }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.navigationTitle("修改记忆").onAppear { text = item.text; category = item.category }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
    }
}

struct AccountView: View {
    @Environment(AppStore.self) private var store
    @State private var name = ""
    @State private var height = ""
    @State private var saved = false
    @State private var validationMessage: String?

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("个人资料")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)
                Text("让常曦更准确地认识你")
                    .font(CXTypography.display)
                Text("只保留真正会影响体验的信息，其余内容以后需要时再补。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            SectionEyebrow(title: "基本信息")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                LabeledField(title: "常用称呼", hint: "例如：张阿姨") {
                    TextField("称呼", text: $name)
                        .textContentType(.nickname)
                }

                LabeledField(title: "身高", hint: "用于计算 BMI") {
                    HStack(spacing: 8) {
                        TextField("身高", text: $height)
                            .keyboardType(.decimalPad)
                        Text("cm")
                            .font(CXTypography.supporting)
                            .foregroundStyle(CX.muted)
                    }
                }

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                        .font(CXTypography.meta)
                        .foregroundStyle(CX.statusCritical)
                }
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            Button(saved ? "已保存" : "保存资料", action: saveProfile)
                .buttonStyle(PrimaryButton())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if saved {
                Label("资料已更新", systemImage: "checkmark.circle.fill")
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.statusPositive)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            SectionEyebrow(title: "体验账户")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: store.data.demoSignedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                        .foregroundStyle(CX.actionPrimary)
                        .frame(width: 42, height: 42)
                        .background(CX.actionPrimary.opacity(0.08), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.data.demoSignedIn ? "演示账户已登录" : "访客体验")
                            .font(CXTypography.section)
                        Text("当前版本不依赖真实账户也可以完整体验。")
                            .font(CXTypography.supporting)
                            .foregroundStyle(CX.muted)
                    }

                    Spacer()
                }

                if store.data.demoSignedIn {
                    Button("退出演示账户") {
                        store.data.demoSignedIn = false
                    }
                    .font(CXTypography.supporting.weight(.semibold))
                } else {
                    NavigationLink("登录 / 注册体验") { DemoAuthView() }
                        .font(CXTypography.supporting.weight(.semibold))
                }
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)
        }
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = store.data.name
            height = store.data.heightCentimeters.formatted(.number.precision(.fractionLength(0...1)))
        }
        .onChange(of: name) { saved = false; validationMessage = nil }
        .onChange(of: height) { saved = false; validationMessage = nil }
    }

    private func saveProfile() {
        let normalizedHeight = height.replacingOccurrences(of: ",", with: ".")
        guard let heightValue = Double(normalizedHeight),
              heightValue.isFinite,
              (80...250).contains(heightValue) else {
            validationMessage = "请输入 80 至 250 cm 之间的身高。"
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.data.name = trimmedName
        store.data.person = "\(trimmedName)（本人）"
        store.data.heightCentimeters = heightValue
        height = heightValue.formatted(.number.precision(.fractionLength(0...1)))
        saved = true
        validationMessage = nil
    }
}

private struct LabeledField<Content: View>: View {
    let title: String
    let hint: String
    @ViewBuilder let content: Content

    init(title: String, hint: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.hint = hint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.muted)
                Spacer()
                Text(hint)
                    .font(CXTypography.micro)
                    .foregroundStyle(CX.faint)
            }

            content
                .padding(.horizontal, CXSpacing.md)
                .frame(minHeight: 52)
                .background(CX.raisedSurface, in: .rect(cornerRadius: CXRadius.sm, style: .continuous))
        }
    }
}

struct FamilyView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("家人与照护")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)
                Text("先确认这次是在照顾谁")
                    .font(CXTypography.display)
                Text("切换服务对象只影响新建的服务意向，不会混入本人的健康记录和常曦记忆。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            SectionEyebrow(title: "服务对象")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                Picker("为谁安排服务", selection: $store.data.person) {
                    Text("\(store.data.name)（本人）").tag("\(store.data.name)（本人）")
                    Text("家人（示例照护对象）").tag("家人（示例照护对象）")
                }
                .pickerStyle(.segmented)

                Label("家人档案需要本人授权后才能同步。", systemImage: "lock.shield")
                    .font(CXTypography.meta)
                    .foregroundStyle(CX.muted)
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "照护安排")
            VStack(spacing: CXSpacing.sm) {
                ProfileEntryRow(
                    title: "查看服务安排",
                    subtitle: "本机预约与咨询草稿",
                    icon: "calendar.badge.clock",
                    tint: CX.actionPrimary
                ) { BookingsView() }

                ProfileEntryRow(
                    title: "查看本人的今日计划",
                    subtitle: "用药、运动和日常记录",
                    icon: "checklist",
                    tint: CX.statusPositive
                ) { PlanView() }
            }

            SectionEyebrow(title: "紧急联系人", action: "仅存本机")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                LabeledField(title: "联系人姓名", hint: "可选") {
                    TextField("姓名", text: $store.data.emergencyName)
                }

                LabeledField(title: "联系电话", hint: "仅用于你主动查看或分享") {
                    TextField("联系电话", text: $store.data.emergencyPhone)
                        .keyboardType(.phonePad)
                }

                if !store.data.emergencyPhone.isEmpty {
                    ShareLink(
                        item: "\(store.data.emergencyName) \(store.data.emergencyPhone)"
                    ) {
                        Label("分享联系人", systemImage: "square.and.arrow.up")
                            .font(CXTypography.supporting.weight(.semibold))
                    }
                }
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)
        }
        .navigationTitle("家人与照护")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HealthArchiveView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("健康档案")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)

                Text("把长期记录放在一处")
                    .font(CXTypography.display)

                Text("这里看的是积累：测量、用药、报告和睡前记录，不重复展示首页的即时摘要。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            SectionEyebrow(title: "测量记录")
            VStack(spacing: CXSpacing.sm) {
                ForEach(MetricKind.allCases) { kind in
                    ProfileEntryRow(
                        title: kind.rawValue,
                        subtitle: "\(store.data.readings.filter { $0.kind == kind }.count) 条记录",
                        icon: kind.icon,
                        tint: kind == .pressure ? CX.statusCritical : kind == .glucose ? CX.statusWarning : CX.actionPrimary
                    ) {
                        MetricDetailView(kind: kind)
                    }
                }
            }

            SectionEyebrow(title: "用药与报告")
            VStack(spacing: CXSpacing.sm) {
                ProfileEntryRow(
                    title: "用药管理",
                    subtitle: "\(store.data.medications.count) 项计划 · \(store.data.doseHistory.count) 条历史",
                    icon: "pills.fill",
                    tint: CX.statusPositive
                ) {
                    MedicationView()
                }

                NavigationLink {
                    ReportListContent()
                } label: {
                    HStack(spacing: CXSpacing.md) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(CX.actionPrimary)
                            .frame(width: 42, height: 42)
                            .background(CX.actionPrimary.opacity(0.08), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("报告与资料")
                                .font(CXTypography.section)
                            Text("\(store.data.importedReports.count) 份本机报告")
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
            }

            SectionEyebrow(title: "睡前记录")
            VStack(alignment: .leading, spacing: CXSpacing.sm) {
                Text(store.data.journal.isEmpty ? "今晚还没有留下记录。" : store.data.journal)
                    .font(CXTypography.body)
                    .foregroundStyle(store.data.journal.isEmpty ? CX.muted : CX.ink)
                    .lineSpacing(5)

                NavigationLink("查看今日计划") { PlanView() }
                    .font(CXTypography.supporting.weight(.semibold))
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)
        }
        .navigationTitle("健康档案")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DevicesView: View {
    @State private var checking = false
    @State private var checked = false

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("设备")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)
                Text("先把记录方式说明白")
                    .font(CXTypography.display)
                Text("当前版本以手动记录为主；设备同步能力开放后，会在这里清楚说明授权范围和数据来源。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            CXEmptyState(
                title: "还没有连接设备",
                message: "现在可以继续手动记录血压、血糖和体重；设备同步与健康 App 授权尚未开放。",
                icon: "applewatch"
            )

            Button(checking ? "正在检查" : "检查设备支持") {
                checking = true
            }
            .buttonStyle(PrimaryButton())
            .disabled(checking)

            if checked {
                VStack(alignment: .leading, spacing: CXSpacing.md) {
                    Label("当前体验版暂无可配对设备", systemImage: "checkmark.circle")
                        .font(CXTypography.section)
                    NavigationLink("继续手动记录") { HealthArchiveView() }
                        .font(CXTypography.supporting.weight(.semibold))
                }
                .padding(CXSpacing.lg)
                .cxContentSurface(cornerRadius: CXRadius.lg)
            }
        }
        .navigationTitle("我的设备")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: checking) {
            guard checking else { return }
            do {
                try await Task.sleep(for: .milliseconds(700))
                checked = true
                checking = false
            } catch {
                checking = false
            }
        }
    }
}

struct PrivacyView: View {
    @Environment(AppStore.self) private var store
    @State private var reset = false

    var body: some View {
        @Bindable var store = store

        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("隐私与授权")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.statusPositive)
                    .tracking(0.6)
                Text("你的数据，由你决定怎么用")
                    .font(CXTypography.display)
                Text("权限只在真正需要时申请；健康记录、对话和草稿默认先留在本机。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            SectionEyebrow(title: "常曦记忆")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                Toggle(isOn: $store.data.rememberAllowed) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("允许确认常曦记忆")
                            .font(CXTypography.section)
                        Text("只有你确认过的内容，才会进入常曦记忆。")
                            .font(CXTypography.meta)
                            .foregroundStyle(CX.muted)
                    }
                }

                NavigationLink("管理常曦记忆") { MemoryView() }
                    .font(CXTypography.supporting.weight(.semibold))
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "系统权限")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                PrivacyPermissionRow(
                    icon: "camera",
                    title: "相机与照片",
                    subtitle: "只在你主动拍摄或选择资料时使用"
                )
                PrivacyPermissionRow(
                    icon: "mic",
                    title: "麦克风与语音",
                    subtitle: "只在你主动发起语音输入时使用"
                )

                Button("打开系统权限设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(CXTypography.supporting.weight(.semibold))
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "数据管理")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                ShareLink("导出本地数据", item: store.exportJSON)
                    .font(CXTypography.supporting.weight(.semibold))

                Divider().overlay(CX.separator.opacity(0.14))

                Button("清除本地数据并重新体验", role: .destructive) {
                    reset = true
                }
                .font(CXTypography.supporting.weight(.semibold))
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)
        }
        .navigationTitle("隐私与授权")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "清除本机保存的常曦体验数据？",
            isPresented: $reset,
            titleVisibility: .visible
        ) {
            Button("清除并重新体验", role: .destructive) {
                store.resetDemo()
            }
        }
    }
}

private struct PrivacyPermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: CXSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(CX.actionPrimary)
                .frame(width: 38, height: 38)
                .background(CX.actionPrimary.opacity(0.08), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(CXTypography.section)
                Text(subtitle)
                    .font(CXTypography.meta)
                    .foregroundStyle(CX.muted)
            }

            Spacer(minLength: 0)
        }
    }
}

struct NotificationSettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("通知")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.statusWarning)
                    .tracking(0.6)

                Text("只在真正有用的时候提醒你")
                    .font(CXTypography.display)

                Text("提醒由本机系统安排，不包含医生消息，也不会因为开启提醒而上传健康内容。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            SectionEyebrow(title: "每日提醒")
            VStack(spacing: CXSpacing.md) {
                ReminderSettingRow(
                    icon: "pills.fill",
                    tint: CX.statusPositive,
                    title: "晚间用药",
                    subtitle: "每天 20:00",
                    isOn: Binding(
                        get: { store.data.medicationReminders },
                        set: { update(medication: true, enabled: $0) }
                    )
                )
                .disabled(busy)

                Divider().overlay(CX.separator.opacity(0.14))

                ReminderSettingRow(
                    icon: "moon.stars.fill",
                    tint: CX.actionPrimary,
                    title: "睡前记录",
                    subtitle: "每天 22:00",
                    isOn: Binding(
                        get: { store.data.healthReminders },
                        set: { update(medication: false, enabled: $0) }
                    )
                )
                .disabled(busy)
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            HStack(alignment: .top, spacing: CXSpacing.sm) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(CX.actionPrimary)
                Text("只有在你开启某项提醒时，常曦才会向系统申请通知权限。")
                    .font(CXTypography.meta)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(4)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CXSpacing.xs)

            if busy {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("正在保存提醒设置")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.muted)
                }
                .frame(maxWidth: .infinity)
            }

            if let error {
                VStack(alignment: .leading, spacing: CXSpacing.md) {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.statusCritical)

                    Button("打开系统设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(CXTypography.supporting.weight(.semibold))
                }
                .padding(CXSpacing.lg)
                .background(
                    CX.statusCritical.opacity(0.05),
                    in: .rect(cornerRadius: CXRadius.lg, style: .continuous)
                )
            }
        }
        .navigationTitle("通知设置")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .denied {
                error = "通知权限已关闭，请到系统设置中开启。"
            }
        }
    }

    private func update(medication: Bool, enabled: Bool) {
        busy = true
        Task { @MainActor in
            defer { busy = false }
            let center = UNUserNotificationCenter.current()
            let id = medication ? "changxi-medication" : "changxi-journal"
            do {
                if enabled {
                    guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                        error = "未获得通知权限，你仍可在应用内查看计划。"
                        return
                    }
                    let content = UNMutableNotificationContent()
                    content.title = "常曦 · 今日计划"
                    content.body = medication
                        ? "到了查看晚间用药计划的时间。"
                        : "记下今天的感受，慢慢照顾自己。"
                    content.sound = .default
                    let trigger = UNCalendarNotificationTrigger(
                        dateMatching: DateComponents(hour: medication ? 20 : 22, minute: 0),
                        repeats: true
                    )
                    try await center.add(
                        UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                    )
                } else {
                    center.removePendingNotificationRequests(withIdentifiers: [id])
                }

                if medication {
                    store.data.medicationReminders = enabled
                } else {
                    store.data.healthReminders = enabled
                }
                error = nil
            } catch {
                self.error = "提醒未能保存，请稍后重试。"
            }
        }
    }
}

private struct ReminderSettingRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: CXSpacing.md) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.08), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(CXTypography.section)
                    Text(subtitle)
                        .font(CXTypography.meta)
                        .foregroundStyle(CX.muted)
                }
            }
        }
    }
}

struct AccessibilitySettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var store = store

        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("显示与触感")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)

                Text("让常曦更适合你的阅读习惯")
                    .font(CXTypography.display)

                Text("字号、触觉和动态效果都应该帮助理解，而不是增加负担。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            SectionEyebrow(title: "阅读")
            VStack(spacing: CXSpacing.md) {
                Toggle(isOn: $store.data.largeText) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("大字模式")
                            .font(CXTypography.section)
                        Text("在应用内进一步放大主要文字与交互控件")
                            .font(CXTypography.meta)
                            .foregroundStyle(CX.muted)
                    }
                }

                Divider().overlay(CX.separator.opacity(0.14))

                Toggle(isOn: $store.data.haptics) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("轻柔触觉")
                            .font(CXTypography.section)
                        Text("只在完成、切换等关键动作提供轻反馈")
                            .font(CXTypography.meta)
                            .foregroundStyle(CX.muted)
                    }
                }
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "动态效果")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: reduceMotion ? "figure.walk.motion.trianglebadge.exclamationmark" : "sparkles")
                        .foregroundStyle(reduceMotion ? CX.statusWarning : CX.actionPrimary)
                        .frame(width: 42, height: 42)
                        .background(
                            (reduceMotion ? CX.statusWarning : CX.actionPrimary).opacity(0.08),
                            in: Circle()
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(reduceMotion ? "已减少动态效果" : "跟随系统动态设置")
                            .font(CXTypography.section)
                        Text(
                            reduceMotion
                                ? "月池会保持更安静，状态主要通过文字和颜色表达。"
                                : "月池和页面转场会使用轻柔动画；系统开启“减少动态效果”后会自动收敛。"
                        )
                        .font(CXTypography.meta)
                        .foregroundStyle(CX.muted)
                        .lineSpacing(4)
                    }
                }

                NavigationLink("体验月池状态") { MotionLabView() }
                    .font(CXTypography.supporting.weight(.semibold))
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)
        }
        .navigationTitle("显示与触感")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MotionLabView: View {
    @State private var state = MoonPoolState.idle
    @State private var amplitude = 0.3

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("月池体验")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)
                Text("动效只表达状态，不替代健康信息")
                    .font(CXTypography.display)
                Text("月相、波纹和光晕负责节奏感；健康结论仍然只通过明确文字与数值表达。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            MoonPoolView(state: state, amplitude: amplitude)

            VStack(alignment: .leading, spacing: CXSpacing.md) {
                SectionEyebrow(title: "状态")
                Picker("月池状态", selection: $state) {
                    ForEach(MoonPoolState.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                SectionEyebrow(title: "波动强度")
                Slider(value: $amplitude)
                    .accessibilityLabel("声音强度")
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)
        }
        .navigationTitle("月池状态体验")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpView: View {
    @Environment(AppStore.self) private var store
    @State private var feedback = ""
    @State private var saved = false

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("帮助与反馈")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)
                Text("先找到答案，再告诉我们哪里还能更好")
                    .font(CXTypography.display)
                Text("常见问题和反馈分开呈现，减少一页里同时出现太多操作。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            SectionEyebrow(title: "常见问题")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                DisclosureGroup("如何记录健康数据？") {
                    Text("在健康页选择血压、血糖或体重，进入对应页面后添加记录。")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.muted)
                }
                Divider().overlay(CX.separator.opacity(0.14))
                DisclosureGroup("常曦会记住哪些事情？") {
                    Text("只有你确认过的内容才进入“已记住”，你可以随时修改或删除。")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.muted)
                }
                Divider().overlay(CX.separator.opacity(0.14))
                DisclosureGroup("这里能联系到真实医生吗？") {
                    Text("当前为体验版本，咨询和预约只保存本机，不会发送给医疗机构。")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.muted)
                }
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "意见反馈")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                TextField("哪里不顺、哪里不清楚，都可以写下来。", text: $feedback, axis: .vertical)
                    .lineLimit(4...8)
                    .padding(CXSpacing.md)
                    .background(CX.raisedSurface, in: .rect(cornerRadius: CXRadius.sm, style: .continuous))

                Button(saved ? "反馈草稿已保存" : "保存反馈草稿") {
                    store.data.feedback = feedback
                    saved = true
                }
                .buttonStyle(PrimaryButton())
                .disabled(feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                ShareLink("分享反馈", item: feedback)
                    .font(CXTypography.supporting.weight(.semibold))
                    .disabled(feedback.isEmpty)
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)
        }
        .navigationTitle("帮助与反馈")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { feedback = store.data.feedback }
        .onChange(of: feedback) { _, _ in saved = false }
        .assistantFormContext(title: "反馈草稿", draft: feedback) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            feedback = trimmed
            saved = false
            return true
        }
    }
}

struct InfoView: View {
    var title: String
    var text: String
    var body: some View { Page { Card { Text(title).font(.title2.bold()); Text(text).lineSpacing(6) } }.navigationTitle(title) }
}
