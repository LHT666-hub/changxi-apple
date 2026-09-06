import SwiftUI

struct ServicesView: View {
    @Environment(AppStore.self) private var store
    @State private var category = "医疗服务"
    var body: some View {
        Page {
            VStack(alignment: .leading, spacing: 8) {
                Text("家庭医生服务")
                    .font(.largeTitle.weight(.semibold))
                    .fontDesign(.serif)
                Text("从日常记录，到需要时有人回应。")
                    .foregroundStyle(CX.muted)
            }
            Card {
                NavigationLink { FamilyView() } label: { RowLabel(title: "我的家庭医生", subtitle: "当前服务对象：\(store.data.person)", icon: "house.fill") }.buttonStyle(.plain)
                Divider()
                NavigationLink { DoctorDetailView() } label: { RowLabel(title: "蒋医生", subtitle: "海湾镇社区卫生服务中心\n全科医生 · 示例服务团队", icon: "stethoscope", tint: CX.teal) }.buttonStyle(.plain)
                NavigationLink("联系医生") { ConsultationView() }.buttonStyle(PrimaryButton())
            }
            Picker("服务分类", selection: $category) { ForEach(["医疗服务", "活动通知", "家医课堂"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
            if category == "医疗服务" {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 12)], spacing: 12) {
                    ForEach(ServiceItem.all) { item in
                        NavigationLink { ServiceDetailView(service: item) } label: {
                            ServiceTile(item: item)
                        }.buttonStyle(.plain).accessibilityIdentifier("service-\(item.title)")
                    }
                }
            } else {
                NavigationLink { ArticleView(isClass: category == "家医课堂") } label: {
                    Card { RowLabel(title: category == "家医课堂" ? "让健康记录更有用" : "社区月光散步计划", subtitle: category == "家医课堂" ? "3分钟阅读 · 记录方法" : "周六 18:30 · 社区花园 · 示例活动", icon: category == "家医课堂" ? "book.closed" : "figure.walk") }
                }.buttonStyle(.plain)
            }
            NavigationLink { BookingsView() } label: { Card { RowLabel(title: "我的服务记录", subtitle: "\(store.data.bookings.filter { !$0.cancelled }.count) 条本地预约", icon: "calendar.badge.clock") } }.buttonStyle(.plain)
            DemoLabel()
        }.navigationTitle("服务")
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
        .background(.regularMaterial, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(CX.separator.opacity(0.18), lineWidth: 0.5)
        }
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
        ServiceItem(title: "帮预约", subtitle: "门诊预约 省时省心", icon: "calendar.badge.plus", color: CX.blue),
        ServiceItem(title: "家医咨询", subtitle: "健康问题 随时记录", icon: "bubble.left.and.bubble.right.fill", color: CX.teal),
        ServiceItem(title: "复诊随访", subtitle: "慢病管理 持续关爱", icon: "clock.arrow.circlepath", color: .orange),
        ServiceItem(title: "检查预约", subtitle: "安排检查 整理资料", icon: "testtube.2", color: .purple),
        ServiceItem(title: "转诊协助", subtitle: "记录需求 协助转诊", icon: "arrow.left.arrow.right", color: CX.teal),
        ServiceItem(title: "社区活动", subtitle: "健康讲座 便民活动", icon: "person.3.fill", color: CX.coral)
    ]
}

struct DoctorDetailView: View {
    var body: some View {
        Page {
            Card {
                Image(systemName: "person.crop.circle.fill.badge.checkmark").font(.system(size: 64)).foregroundStyle(CX.blue).frame(maxWidth: .infinity)
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
        Page {
            Card {
                RowLabel(title: service.title, subtitle: service.subtitle, icon: service.icon, tint: service.color, chevron: false)
                Text("服务对象：\(store.data.person)")
                Text("选择期望时间并写下需求。体验版将创建本地服务记录，尚未向医院或医生提交。").foregroundStyle(CX.muted)
                DatePicker("期望时间", selection: $date, in: Date.now...)
                TextField("补充说明", text: $note, axis: .vertical).lineLimit(3...6).padding().background(CX.mist, in: RoundedRectangle(cornerRadius: 16))
                Button(saved ? "已保存本地记录" : "保存预约意向") {
                    store.data.bookings.append(ServiceBooking(service: service.title, person: store.data.person, date: date, note: note))
                    saved = true
                    MoonHaptics.shared.play(success: true, enabled: store.data.haptics)
                }.buttonStyle(PrimaryButton()).disabled(saved)
                if saved { Label("尚未提交至医疗机构", systemImage: "checkmark.circle").foregroundStyle(CX.teal); NavigationLink("查看服务记录") { BookingsView() } }
            }
        }.navigationTitle(service.title)
    }
}

struct BookingsView: View {
    @Environment(AppStore.self) private var store
    @State private var cancelID: UUID?
    var body: some View {
        Page {
            if store.data.bookings.isEmpty { ContentUnavailableView("还没有服务记录", systemImage: "calendar", description: Text("在服务页选择需要的服务，安排一个合适的时间。")) }
            ForEach(store.data.bookings.reversed()) { booking in
                Card {
                    RowLabel(title: booking.service, subtitle: booking.person, icon: "calendar", chevron: false)
                    Text(booking.date.formatted(date: .abbreviated, time: .shortened))
                    if !booking.note.isEmpty { Text(booking.note) }
                    Text(booking.cancelled ? "已取消本地意向" : "本地意向 · 未提交医疗机构").foregroundStyle(CX.muted)
                    if !booking.cancelled { Button("取消意向", role: .destructive) { cancelID = booking.id }.frame(minHeight: 44) }
                }
            }
        }.navigationTitle("服务记录")
        .confirmationDialog("取消这条预约意向？", isPresented: Binding(get: { cancelID != nil }, set: { if !$0 { cancelID = nil } }), titleVisibility: .visible) {
            Button("确认取消", role: .destructive) { if let i = store.data.bookings.firstIndex(where: { $0.id == cancelID }) { store.data.bookings[i].cancelled = true }; cancelID = nil }
        }
    }
}

struct ConsultationView: View {
    @Environment(AppStore.self) private var store
    @State private var question = ""
    @State private var saved = false
    var body: some View {
        Page {
            Card {
                RowLabel(title: "向蒋医生咨询", subtitle: "先整理你想沟通的问题", icon: "stethoscope", chevron: false)
                TextField("发生了什么？从什么时候开始？", text: $question, axis: .vertical).lineLimit(5...12).padding().background(CX.mist, in: RoundedRectangle(cornerRadius: 16))
                Text("本页为咨询流程演示，内容只保存到本机，不会发送给医生。").font(.footnote).foregroundStyle(CX.muted)
                Button(saved ? "咨询草稿已保存" : "保存咨询草稿") {
                    store.data.bookings.append(ServiceBooking(service: "家医咨询草稿", person: store.data.person, date: .now, note: question)); saved = true
                }.buttonStyle(PrimaryButton()).disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saved)
                if saved { NavigationLink("查看我的咨询") { BookingsView() } }
            }
        }.navigationTitle("家医咨询")
    }
}

struct ArticleView: View {
    var isClass: Bool
    var body: some View {
        Page {
            Card {
                Label(isClass ? "家医课堂" : "社区活动", systemImage: isClass ? "book" : "figure.walk").foregroundStyle(CX.muted)
                Text(isClass ? "让健康记录更有用" : "社区月光散步计划").font(.largeTitle.bold())
                Text(isClass ? "把时间和情境一起记下来" : "周六 18:30 · 社区花园").font(.headline)
                Text(isClass ? "除了数值，你也可以记录测量时间、当时的感受，以及餐前或餐后等信息。连续的记录能帮助你和医生回顾变化。\n\n遇到不熟悉的单位或指标，先核对原始报告，再在咨询时一起讨论。\n\n不必追求每天完美完成，漏记以后也可以从下一次重新开始。" : "一次轻松的社区散步，和邻里认识，也给自己一点放松的时间。\n\n集合地点：社区花园入口。\n活动时长：约30分钟，可按自己的节奏提前休息。\n\n这是示例活动，目前不接受真实报名。").lineSpacing(8)
                if !isClass { NavigationLink("保存参与意向") { ServiceDetailView(service: ServiceItem.all[5]) }.buttonStyle(PrimaryButton()) }
            }
        }.navigationTitle(isClass ? "家医课堂" : "活动详情")
    }
}

struct MessagesView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Page {
            NavigationLink { DoctorMessageView() } label: { Card { RowLabel(title: "蒋医生的回复", subtitle: store.data.doctorMessageRead ? "已读 · 示例消息" : "未读 · 示例消息", icon: "stethoscope") } }.buttonStyle(.plain)
            NavigationLink { PlanView() } label: { Card { RowLabel(title: "今日计划", subtitle: "还有\(store.data.plans.count - store.completed)项待完成", icon: "bell") } }.buttonStyle(.plain)
            NavigationLink { MemoryView() } label: { Card { RowLabel(title: "常曦记忆待确认", subtitle: "\(store.pendingMemories)条等待你确认", icon: "sparkles") } }.buttonStyle(.plain)
        }.navigationTitle("消息中心")
    }
}

struct DoctorMessageView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Page {
            MoonPoolView(state: .doctorReply, character: false, compact: true)
            Card {
                RowLabel(title: "蒋医生", subtitle: "示例消息 · 今天 17:30", icon: "stethoscope", chevron: false)
                Text("下次沟通时，可以带上最近一周的测量记录和完整体检报告，我们一起回顾变化。").lineSpacing(6)
                NavigationLink("整理我的回复") { ConsultationView() }.buttonStyle(PrimaryButton())
            }
            DemoLabel()
        }.navigationTitle("医生回复").onAppear { store.data.doctorMessageRead = true }
    }
}
