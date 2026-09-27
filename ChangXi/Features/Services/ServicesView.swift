import SwiftUI

struct ServicesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var category = "医疗服务"

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("服务")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)

                Text("需要的时候，有人接住下一步")
                    .font(CXTypography.display)

                Text("预约、咨询、随访和社区服务都放在这里，不必一次想清所有步骤。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            VStack(alignment: .leading, spacing: CXSpacing.md) {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: "stethoscope")
                        .font(.title2.weight(.medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(CX.statusPositive)
                        .frame(width: 52, height: 52)
                        .background(CX.statusPositive.opacity(0.08), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("蒋医生")
                            .font(CXTypography.title)
                        Text("全科医生 · 示例家庭医生团队")
                            .font(CXTypography.supporting)
                            .foregroundStyle(CX.muted)
                        Text("当前服务对象：\(store.data.person)")
                            .font(CXTypography.meta)
                            .foregroundStyle(CX.muted)
                    }

                    Spacer()
                }

                HStack(spacing: CXSpacing.sm) {
                    NavigationLink { DoctorDetailView() } label: {
                        Label("查看医生", systemImage: "person.crop.circle")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)

                    NavigationLink { ConsultationView() } label: {
                        Label("联系医生", systemImage: "bubble.left.and.bubble.right")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(PrimaryButton())
                }
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            Picker("服务分类", selection: $category) {
                ForEach(["医疗服务", "活动通知", "家医课堂"], id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)

            if category == "医疗服务" {
                SectionEyebrow(title: "常用服务")
                CXGlassGroup(spacing: 12) {
                    LazyVGrid(
                        columns: CXLayout.adaptiveColumns(minimum: 156, dynamicTypeSize: dynamicTypeSize),
                        spacing: 12
                    ) {
                        ForEach(ServiceItem.all) { item in
                            NavigationLink { ServiceDetailView(service: item) } label: {
                                ServiceTile(item: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("service-\(item.title)")
                        }
                    }
                }
            } else {
                SectionEyebrow(title: category)
                NavigationLink { ArticleView(isClass: category == "家医课堂") } label: {
                    HStack(spacing: CXSpacing.md) {
                        Image(systemName: category == "家医课堂" ? "book.closed" : "figure.walk")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(CX.actionPrimary)
                            .frame(width: 48, height: 48)
                            .background(CX.actionPrimary.opacity(0.08), in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(category == "家医课堂" ? "让健康记录更有用" : "社区月光散步计划")
                                .font(CXTypography.section)
                            Text(category == "家医课堂" ? "3 分钟阅读 · 记录方法" : "周六 18:30 · 社区花园 · 示例活动")
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

            SectionEyebrow(title: "我的服务")
            NavigationLink { BookingsView() } label: {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(CX.actionPrimary)
                        .frame(width: 42, height: 42)
                        .background(CX.actionPrimary.opacity(0.08), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("服务记录")
                            .font(CXTypography.section)
                        Text("\(store.data.bookings.filter { !$0.cancelled }.count) 条本地记录")
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

            if AppConfiguration.useRemoteAPI {
                NavigationLink { CareTaskView() } label: {
                    HStack(spacing: CXSpacing.md) {
                        Image(systemName: "checklist")
                            .foregroundStyle(CX.statusPositive)
                            .frame(width: 42, height: 42)
                            .background(CX.statusPositive.opacity(0.08), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("照护任务")
                                .font(CXTypography.section)
                            Text("玄同会诊生成的照护建议")
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

            DemoLabel()
        }
        .navigationTitle("服务")
    }
}

private struct ServiceTile: View {
    let item: ServiceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: item.icon)
                .font(.title2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(item.color)
                .frame(width: 44, height: 44)
                .background(item.color.opacity(0.11), in: .rect(cornerRadius: 13, style: .continuous))

            Text(item.title)
                .font(.headline)

            Text(item.subtitle)
                .font(.subheadline)
                .foregroundStyle(CX.muted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CX.faint)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, minHeight: 164, alignment: .leading)
        .padding(16)
        .cxContentSurface(cornerRadius: CXRadius.md)
        .contentShape(Rectangle())
    }
}

struct ServiceItem: Identifiable {
    var id: String { title }
    var title: String
    var subtitle: String
    var icon: String
    var color: Color
    static let all = [
        ServiceItem(title: "帮预约", subtitle: "门诊预约 省时省心", icon: "calendar.badge.plus", color: CX.actionPrimary),
        ServiceItem(title: "家医咨询", subtitle: "健康问题 随时记录", icon: "bubble.left.and.bubble.right.fill", color: CX.statusPositive),
        ServiceItem(title: "复诊随访", subtitle: "慢病管理 持续关爱", icon: "clock.arrow.circlepath", color: .orange),
        ServiceItem(title: "检查预约", subtitle: "安排检查 整理资料", icon: "testtube.2", color: .purple),
        ServiceItem(title: "转诊协助", subtitle: "记录需求 协助转诊", icon: "arrow.left.arrow.right", color: CX.statusPositive),
        ServiceItem(title: "社区活动", subtitle: "健康讲座 便民活动", icon: "person.3.fill", color: CX.statusCritical)
    ]
}

struct DoctorDetailView: View {
    var body: some View {
        Page {
            Card {
                Image(systemName: "person.crop.circle.fill.badge.checkmark").font(.system(size: 64)).foregroundStyle(CX.actionPrimary).frame(maxWidth: .infinity)
                Text("蒋医生").font(.title.bold()).frame(maxWidth: .infinity)
                Text("全科医生 · 海湾镇社区卫生服务中心").foregroundStyle(CX.muted)
                Text("服务方向：日常健康管理、慢病随访、报告沟通。此医生资料为产品演示示例。")
                NavigationLink("发起咨询") { ConsultationView() }.buttonStyle(PrimaryButton())
            }
            Card {
                Text("可选择的服务").font(.title2.bold())
                ForEach([ServiceItem.all[0], ServiceItem.all[2], ServiceItem.all[4]]) { item in
                    NavigationLink { ServiceDetailView(service: item) } label: { RowLabel(title: item.title, subtitle: item.subtitle, icon: item.icon) }.buttonStyle(.plain)
                }
            }
            DemoLabel()
        }.navigationTitle("家庭医生")
    }
}

struct ServiceDetailView: View {
    let service: ServiceItem
    @Environment(AppStore.self) private var store
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
    @State private var note = ""
    @State private var saved = false

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("服务意向")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(service.color)
                    .tracking(0.6)
                Text(service.title)
                    .font(CXTypography.display)
                Text(service.subtitle)
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
            }

            HStack(spacing: CXSpacing.md) {
                Image(systemName: service.icon)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(service.color)
                    .frame(width: 54, height: 54)
                    .background(service.color.opacity(0.09), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("服务对象")
                        .font(CXTypography.micro.weight(.semibold))
                        .foregroundStyle(CX.muted)
                    Text(store.data.person)
                        .font(CXTypography.section)
                }

                Spacer()
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "期望时间")
            VStack(alignment: .leading, spacing: CXSpacing.sm) {
                DatePicker("选择时间", selection: $date, in: Date.now...)
                    .font(CXTypography.supporting)

                Text("这里只记录你的期望时间，不代表医院或医生已确认。")
                    .font(CXTypography.meta)
                    .foregroundStyle(CX.muted)
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "补充说明", action: "可选")
            TextField("例如：希望周末上午，想咨询最近的体检报告", text: $note, axis: .vertical)
                .lineLimit(4...8)
                .padding(CXSpacing.md)
                .background(CX.surface, in: .rect(cornerRadius: CXRadius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous)
                        .strokeBorder(CX.separator.opacity(0.12), lineWidth: 0.5)
                }

            Button(saved ? "已保存本地记录" : "保存预约意向") {
                store.data.bookings.append(
                    ServiceBooking(service: service.title, person: store.data.person, date: date, note: note)
                )
                saved = true
                MoonHaptics.shared.play(success: true, enabled: store.data.haptics)
            }
            .buttonStyle(PrimaryButton())
            .disabled(saved)

            if saved {
                VStack(spacing: CXSpacing.sm) {
                    Label("尚未提交至医疗机构", systemImage: "checkmark.circle.fill")
                        .font(CXTypography.supporting.weight(.semibold))
                        .foregroundStyle(CX.statusPositive)

                    NavigationLink("查看服务记录") { BookingsView() }
                        .font(CXTypography.supporting.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(CXSpacing.md)
                .background(CX.statusPositive.opacity(0.06), in: .rect(cornerRadius: CXRadius.md, style: .continuous))
            }

            Text("当前为体验版，本页只保存本机服务意向。")
                .font(CXTypography.meta)
                .foregroundStyle(CX.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(service.title)
        .navigationBarTitleDisplayMode(.inline)
        .assistantFormContext(title: "\(service.title)说明", draft: note) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            note = trimmed
            saved = false
            return true
        }
    }
}

struct BookingsView: View {
    @Environment(AppStore.self) private var store
    @State private var cancelID: UUID?

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("服务记录")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)
                Text("看清哪些只是本机意向")
                    .font(CXTypography.display)
                Text("当前体验版不会把这些记录自动提交给医疗机构。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            if store.data.bookings.isEmpty {
                CXEmptyState(
                    title: "还没有服务记录",
                    message: "从服务页保存一次本机意向后，会按时间出现在这里。",
                    icon: "calendar.badge.clock"
                )
            } else {
                SectionEyebrow(title: "本机记录", action: "\(store.data.bookings.count) 条")

                ForEach(store.data.bookings.reversed()) { booking in
                    VStack(alignment: .leading, spacing: CXSpacing.md) {
                        HStack(spacing: CXSpacing.md) {
                            Image(systemName: booking.cancelled ? "xmark.circle" : "calendar")
                                .foregroundStyle(booking.cancelled ? CX.muted : CX.actionPrimary)
                                .frame(width: 42, height: 42)
                                .background(
                                    (booking.cancelled ? CX.muted : CX.actionPrimary).opacity(0.08),
                                    in: Circle()
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(booking.service)
                                    .font(CXTypography.section)
                                Text(booking.person)
                                    .font(CXTypography.meta)
                                    .foregroundStyle(CX.muted)
                            }

                            Spacer()
                        }

                        Text(booking.date.formatted(date: .abbreviated, time: .shortened))
                            .font(CXTypography.supporting)

                        if !booking.note.isEmpty {
                            Text(booking.note)
                                .font(CXTypography.supporting)
                                .foregroundStyle(CX.muted)
                        }

                        Label(
                            booking.cancelled ? "已取消本地意向" : "本地意向 · 未提交医疗机构",
                            systemImage: booking.cancelled ? "minus.circle" : "iphone"
                        )
                        .font(CXTypography.meta.weight(.semibold))
                        .foregroundStyle(booking.cancelled ? CX.muted : CX.statusWarning)

                        if !booking.cancelled {
                            Button("取消意向", role: .destructive) {
                                cancelID = booking.id
                            }
                            .font(CXTypography.meta.weight(.semibold))
                            .frame(minHeight: 44)
                        }
                    }
                    .padding(CXSpacing.lg)
                    .cxContentSurface(cornerRadius: CXRadius.lg)
                }
            }
        }
        .navigationTitle("服务记录")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "取消这条预约意向？",
            isPresented: Binding(
                get: { cancelID != nil },
                set: { if !$0 { cancelID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("确认取消", role: .destructive) {
                if let i = store.data.bookings.firstIndex(where: { $0.id == cancelID }) {
                    store.data.bookings[i].cancelled = true
                }
                cancelID = nil
            }
        }
    }
}

struct ConsultationView: View {
    @Environment(AppStore.self) private var store
    @State private var question = ""
    @State private var saved = false

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("家医咨询")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.statusPositive)
                    .tracking(0.6)
                Text("先把想问的事整理清楚")
                    .font(CXTypography.display)
                Text("不用一次写完整，先记下发生了什么、从什么时候开始，以及最想确认的问题。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            HStack(spacing: CXSpacing.md) {
                Image(systemName: "stethoscope")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(CX.statusPositive)
                    .frame(width: 52, height: 52)
                    .background(CX.statusPositive.opacity(0.08), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("蒋医生")
                        .font(CXTypography.title)
                    Text("全科医生 · 示例家庭医生团队")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.muted)
                }

                Spacer()
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "咨询内容")
            VStack(alignment: .leading, spacing: CXSpacing.sm) {
                TextField("发生了什么？从什么时候开始？", text: $question, axis: .vertical)
                    .lineLimit(6...12)
                    .padding(CXSpacing.md)
                    .background(CX.raisedSurface, in: .rect(cornerRadius: CXRadius.sm, style: .continuous))

                Text("这只是咨询草稿，当前不会发送给医生。")
                    .font(CXTypography.meta)
                    .foregroundStyle(CX.muted)
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            Button(saved ? "咨询草稿已保存" : "保存咨询草稿") {
                store.data.bookings.append(
                    ServiceBooking(
                        service: "家医咨询草稿",
                        person: store.data.person,
                        date: .now,
                        note: question
                    )
                )
                saved = true
            }
            .buttonStyle(PrimaryButton())
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saved)

            if saved {
                NavigationLink("查看我的咨询") { BookingsView() }
                    .font(CXTypography.supporting.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("家医咨询")
        .navigationBarTitleDisplayMode(.inline)
        .assistantFormContext(title: "咨询草稿", draft: question) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            question = trimmed
            saved = false
            return true
        }
    }
}

struct ArticleView: View {
    var isClass: Bool

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text(isClass ? "家医课堂" : "社区活动")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(isClass ? CX.actionPrimary : CX.statusPositive)
                    .tracking(0.6)
                Text(isClass ? "让健康记录更有用" : "社区月光散步计划")
                    .font(CXTypography.display)
                Text(isClass ? "把时间和情境一起记下来" : "周六 18:30 · 社区花园")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
            }

            Text(
                isClass
                    ? "除了数值，你也可以记录测量时间、当时的感受，以及餐前或餐后等信息。连续的记录能帮助你和医生回顾变化。\n\n遇到不熟悉的单位或指标，先核对原始报告，再在咨询时一起讨论。\n\n不必追求每天完美完成，漏记以后也可以从下一次重新开始。"
                    : "一次轻松的社区散步，和邻里认识，也给自己一点放松的时间。\n\n集合地点：社区花园入口。\n活动时长：约30分钟，可按自己的节奏提前休息。\n\n这是示例活动，目前不接受真实报名。"
            )
            .font(CXTypography.body)
            .lineSpacing(7)
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            if !isClass {
                NavigationLink("保存参与意向") {
                    ServiceDetailView(service: ServiceItem.all[5])
                }
                .buttonStyle(PrimaryButton())
            }
        }
        .navigationTitle(isClass ? "家医课堂" : "活动详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MessagesView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("消息")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.actionPrimary)
                    .tracking(0.6)

                Text("把需要你看一眼的事放在这里")
                    .font(CXTypography.display)

                Text("医生示例回复、今日计划和待确认记忆分开呈现，不和服务入口混在一起。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            VStack(spacing: CXSpacing.sm) {
                ProfileEntryRow(
                    title: "蒋医生的回复",
                    subtitle: store.data.doctorMessageRead ? "已读 · 示例消息" : "未读 · 示例消息",
                    icon: "stethoscope",
                    tint: CX.statusPositive
                ) {
                    DoctorMessageView()
                }

                ProfileEntryRow(
                    title: "今日计划",
                    subtitle: "还有 \(store.data.plans.count - store.completed) 项待完成",
                    icon: "bell",
                    tint: CX.statusWarning
                ) {
                    PlanView()
                }

                ProfileEntryRow(
                    title: "常曦记忆待确认",
                    subtitle: "\(store.pendingMemories) 条等待你确认",
                    icon: "sparkles",
                    tint: CX.actionPrimary
                ) {
                    MemoryView()
                }
            }
        }
        .navigationTitle("消息中心")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DoctorMessageView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Page(illustrated: true) {
            MoonPoolView(state: .doctorReply, character: true, compact: true)

            VStack(alignment: .leading, spacing: CXSpacing.md) {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: "stethoscope")
                        .foregroundStyle(CX.statusPositive)
                        .frame(width: 42, height: 42)
                        .background(CX.statusPositive.opacity(0.08), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("蒋医生")
                            .font(CXTypography.title)
                        Text("示例消息 · 今天 17:30")
                            .font(CXTypography.meta)
                            .foregroundStyle(CX.muted)
                    }

                    Spacer()
                }

                Text("下次沟通时，可以带上最近一周的测量记录和完整体检报告，我们一起回顾变化。")
                    .font(CXTypography.body)
                    .lineSpacing(6)

                NavigationLink("整理我的回复") {
                    ConsultationView()
                }
                .buttonStyle(PrimaryButton())
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            DemoLabel()
        }
        .navigationTitle("医生回复")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.data.doctorMessageRead = true
        }
    }
}
