import SwiftUI
import UserNotifications

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Page {
            NavigationLink { AccountView() } label: {
                Card { RowLabel(title: store.data.name, subtitle: "家庭医生：蒋医生\n每一天，都值得被好好照顾", icon: "person.crop.circle.fill") }
            }.buttonStyle(.plain)
            NavigationLink { MemoryView() } label: {
                VStack(alignment: .leading, spacing: 12) {
                    Label("常曦记忆", systemImage: "moon.stars.fill").font(.title2.bold())
                    Text("记住了 \(store.data.memories.filter(\.confirmed).count) 条重要信息")
                    Text("\(store.pendingMemories) 条等待你确认").font(.subheadline)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24).foregroundStyle(.white).background(LinearGradient(colors: [CX.blue, CX.ink], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))
            }.buttonStyle(.plain)
            Card {
                NavigationLink { HealthArchiveView() } label: { RowLabel(title: "我的健康档案", subtitle: "健康数据 · 用药记录 · 检查报告", icon: "heart.fill", tint: CX.coral) }
                Divider()
                NavigationLink { FamilyView() } label: { RowLabel(title: "家人与照护", subtitle: "服务对象 · 照护计划", icon: "person.2.fill") }
                Divider()
                NavigationLink { DevicesView() } label: { RowLabel(title: "我的设备", subtitle: "设备管理 · 数据同步", icon: "applewatch", tint: .purple) }
            }.buttonStyle(.plain)
            Card {
                NavigationLink { PrivacyView() } label: { RowLabel(title: "隐私与授权", subtitle: "数据安全 · 权限管理", icon: "checkmark.shield.fill", tint: CX.teal) }
                Divider()
                NavigationLink { NotificationSettingsView() } label: { RowLabel(title: "通知设置", subtitle: "用药提醒 · 健康提醒", icon: "bell.fill", tint: .orange) }
                Divider()
                NavigationLink { AccessibilitySettingsView() } label: { RowLabel(title: "显示与触感", subtitle: "大字模式 · 动态效果", icon: "textformat.size") }
                Divider()
                NavigationLink { HelpView() } label: { RowLabel(title: "帮助与反馈", subtitle: "使用指南 · 常见问题", icon: "questionmark.circle.fill", tint: .purple) }
            }.buttonStyle(.plain)
            DemoLabel()
        }.navigationTitle("我的")
    }
}

struct MemoryView: View {
    @Environment(AppStore.self) private var store
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
            if items.isEmpty { ContentUnavailableView("这里暂时没有记忆", systemImage: "moon.stars", description: Text("你的确认、修改和删除，都会被尊重。")) }
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
            Button { if let i = store.data.memories.firstIndex(where: { $0.id == item.id }) { store.data.memories[i].confirmed = true }; MoonHaptics.shared.play(success: true, enabled: store.data.haptics) } label: { Label("确认", systemImage: "checkmark") }.buttonStyle(.borderedProminent).disabled(!store.data.rememberAllowed).frame(minHeight: 44)
        }
        Button { editing = item } label: { Label("修改", systemImage: "pencil") }.frame(minHeight: 44)
        Button(role: .destructive) { deleting = item } label: { Label(item.confirmed ? "删除" : "不记住", systemImage: "xmark") }.frame(minHeight: 44)
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
    @State private var saved = false
    var body: some View {
        Form {
            Section("个人资料") { TextField("称呼", text: $name); Button(saved ? "已保存" : "保存资料") { store.data.name = name; store.data.person = "\(name)（本人）"; saved = true }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            Section("账户") { Label("访客体验", systemImage: "person.crop.circle"); Text("此版本无需注册。真实登录、短信验证与云端同步将在账户服务接通后开放。").foregroundStyle(.secondary) }
        }.navigationTitle("个人资料").onAppear { name = store.data.name }.onChange(of: name) { _, _ in saved = false }
    }
}

struct FamilyView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        Form {
            Section("服务对象") { Picker("为谁安排服务", selection: $store.data.person) { Text("\(store.data.name)（本人）").tag("\(store.data.name)（本人）"); Text("家人（示例照护对象）").tag("家人（示例照护对象）") }.pickerStyle(.inline) }
            Section { Text("切换对象只影响新建服务意向的归属。健康记录和常曦记忆仍属于本人。家人档案需要本人授权后才能同步。") }
            Section("照护计划") { NavigationLink("查看服务安排") { BookingsView() }; NavigationLink("查看本人的今日计划") { PlanView() } }
        }.navigationTitle("家人与照护")
    }
}

struct HealthArchiveView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Page {
            Card {
                ForEach(MetricKind.allCases) { kind in NavigationLink { MetricDetailView(kind: kind) } label: { RowLabel(title: kind.rawValue, subtitle: "\(store.data.readings.filter { $0.kind == kind }.count)条记录", icon: kind.icon) }.buttonStyle(.plain) }
                NavigationLink { MedicationView() } label: { RowLabel(title: "用药管理", icon: "pills") }.buttonStyle(.plain)
            }
            ReportListContent()
            Card { Text("睡前记录").font(.headline); Text(store.data.journal.isEmpty ? "还没有记录，今晚留一句话给自己吧。" : store.data.journal) }
        }.navigationTitle("健康档案")
    }
}

struct MedicationView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Page {
            Card {
                RowLabel(title: "晚间用药计划", subtitle: "20:00 · 每日提醒", icon: "pills.fill", chevron: false)
                Text("核对本人处方后再记录服药。示例中不预填药名和剂量，避免把演示内容当成用药建议。").foregroundStyle(CX.muted)
                if let plan = store.data.plans.first(where: { $0.title == "晚间用药" }) { NavigationLink(plan.completed ? "查看今日服药记录" : "记录今日服药") { PlanDetailView(planID: plan.id) }.buttonStyle(PrimaryButton()) }
            }
            Card {
                Text("如果漏服了").font(.title2.bold())
                Text("先核对药品说明书中对应药物的漏服处理说明，或联系医生、药师确认。本应用不会自动补记服药，也不会根据一次漏服调整剂量。")
                NavigationLink("整理给医生的问题") { ConsultationView() }
            }
            NavigationLink { NotificationSettingsView() } label: { Card { RowLabel(title: "用药提醒设置", icon: "bell") } }.buttonStyle(.plain)
        }.navigationTitle("用药管理")
    }
}

struct DevicesView: View {
    @State private var checking = false
    @State private var checked = false
    var body: some View {
        Page {
            ContentUnavailableView("还没有连接设备", systemImage: "applewatch", description: Text("当前版本支持手动记录。设备同步与健康 App 授权尚未开放。"))
            Button(checking ? "正在检查…" : "检查设备支持") { checking = true }.buttonStyle(PrimaryButton()).disabled(checking)
            if checked { Card { Text("此体验版暂无可配对设备。"); NavigationLink("手动记录健康数据") { HealthArchiveView() } } }
        }.navigationTitle("我的设备")
        .task(id: checking) { guard checking else { return }; do { try await Task.sleep(for: .milliseconds(700)); checked = true; checking = false } catch { checking = false } }
    }
}

struct PrivacyView: View {
    @Environment(AppStore.self) private var store
    @State private var reset = false
    var body: some View {
        @Bindable var store = store
        Form {
            Section("你的数据由你掌握") { Text("健康记录、对话、记忆和服务草稿保存在此设备的应用文档目录，并启用系统文件保护。本演示版不会把这些内容上传至常曦服务器。"); Toggle("允许确认常曦记忆", isOn: $store.data.rememberAllowed) }
            Section("系统权限") {
                Text("麦克风和相机只在你主动使用时申请。语音转写由 Apple 语音服务提供，部分设备或语言可能需要网络处理。照片只读取你主动选择的项目。")
                Button("打开系统权限设置") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            }
            Section("数据管理") { NavigationLink("管理常曦记忆") { MemoryView() }; ShareLink("导出本地数据", item: store.exportJSON); Button("清除本地数据并重新体验", role: .destructive) { reset = true } }
        }.navigationTitle("隐私与授权")
        .confirmationDialog("清除本机记录、对话与设置？", isPresented: $reset, titleVisibility: .visible) { Button("清除并重置示例", role: .destructive) { UNUserNotificationCenter.current().removeAllPendingNotificationRequests(); store.resetDemo() } }
    }
}

struct NotificationSettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        Form {
            Section("每日提醒") {
                Toggle("20:00 用药计划提醒", isOn: Binding(get: { store.data.medicationReminders }, set: { update(medication: true, enabled: $0) })).disabled(busy)
                Toggle("22:00 睡前记录提醒", isOn: Binding(get: { store.data.healthReminders }, set: { update(medication: false, enabled: $0) })).disabled(busy)
            }
            Section { Text("开启时才向系统请求通知权限。这些提醒在本机安排，不包含远程医生消息推送。") }
            if let error { Section { Text(error).foregroundStyle(CX.coral); Button("打开系统设置") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } } }
        }.navigationTitle("通知设置")
        .task { let settings = await UNUserNotificationCenter.current().notificationSettings(); if settings.authorizationStatus == .denied { error = "通知权限已关闭，请到系统设置中开启。" } }
    }
    private func update(medication: Bool, enabled: Bool) {
        busy = true
        Task { @MainActor in
            defer { busy = false }
            let center = UNUserNotificationCenter.current()
            let id = medication ? "changxi-medication" : "changxi-journal"
            do {
                if enabled {
                    guard try await center.requestAuthorization(options: [.alert, .sound]) else { error = "未获得通知权限，你仍可在应用内查看计划。"; return }
                    let content = UNMutableNotificationContent()
                    content.title = "常曦 · 今日计划"
                    content.body = medication ? "到了查看晚间用药计划的时间。" : "记下今天的感受，慢慢照顾自己。"
                    content.sound = .default
                    let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: medication ? 20 : 22, minute: 0), repeats: true)
                    try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                } else { center.removePendingNotificationRequests(withIdentifiers: [id]) }
                if medication { store.data.medicationReminders = enabled } else { store.data.healthReminders = enabled }
                error = nil
            } catch { self.error = "提醒未能保存，请稍后重试。" }
        }
    }
}

struct AccessibilitySettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        @Bindable var store = store
        Form {
            Toggle("大字模式", isOn: $store.data.largeText)
            Toggle("轻柔触觉反馈", isOn: $store.data.haptics)
            Section("动态效果") { Text(reduceMotion ? "已跟随系统减少动态效果。月池保持静止，状态通过文字表达。" : "月池跟随系统“减少动态效果”设置。可在系统设置 → 辅助功能 → 动态效果中调整。") }
            NavigationLink("体验月池状态") { MotionLabView() }
        }.navigationTitle("显示与触感")
    }
}

struct MotionLabView: View {
    @State private var state = MoonPoolState.idle
    @State private var amplitude = 0.3
    var body: some View {
        Page(illustrated: true) {
            MoonPoolView(state: state, amplitude: amplitude)
            Card {
                Picker("月池状态", selection: $state) { ForEach(MoonPoolState.allCases) { Text($0.label).tag($0) } }
                Text("声音强度演示").font(.headline)
                Slider(value: $amplitude).accessibilityLabel("声音强度")
                Text("月相只表达过程，健康信息由数值和文字表达。").font(.footnote).foregroundStyle(CX.muted)
            }
        }.navigationTitle("月池状态体验")
    }
}

struct HelpView: View {
    @Environment(AppStore.self) private var store
    @State private var feedback = ""
    @State private var saved = false
    var body: some View {
        Page {
            Card {
                DisclosureGroup("如何记录健康数据？") { Text("在健康页选择血压、血糖或体重，点击添加记录。输入数值、时间和备注后保存。") }
                Divider()
                DisclosureGroup("常曦会记住哪些事情？") { Text("只有你确认的记忆才进入“已记住”。你可以随时修改或删除，也可在隐私页暂停确认记忆。") }
                Divider()
                DisclosureGroup("这里能联系到真实医生吗？") { Text("目前是前端体验版本，医生消息为示例。咨询和预约只保存到本机，不会发送给医疗机构。") }
            }
            Card {
                Text("意见反馈").font(.title2.bold())
                TextField("有什么可以做得更好？", text: $feedback, axis: .vertical).lineLimit(4...8)
                Button(saved ? "已保存反馈草稿" : "保存反馈草稿") { store.data.feedback = feedback; saved = true }.buttonStyle(PrimaryButton()).disabled(feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                ShareLink("分享反馈", item: feedback).disabled(feedback.isEmpty)
            }
        }.navigationTitle("帮助与反馈").onAppear { feedback = store.data.feedback }.onChange(of: feedback) { _, _ in saved = false }
    }
}

struct InfoView: View {
    var title: String
    var text: String
    var body: some View { Page { Card { Text(title).font(.title2.bold()); Text(text).lineSpacing(6) } }.navigationTitle(title) }
}
