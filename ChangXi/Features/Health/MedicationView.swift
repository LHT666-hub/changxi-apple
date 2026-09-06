import SwiftUI

struct MedicationView: View {
    @Environment(AppStore.self) private var store
    @State private var adding = false
    @State private var editing: Medication?
    @State private var removing: Medication?
    var body: some View {
        Page {
            Card {
                Text("把用药安排，记得清清楚楚").font(.title2.bold())
                Text("请按本人的处方或药品说明填写，不确定的用法先向医生或药师核对。").foregroundStyle(CX.muted)
                Button { adding = true } label: { Label("添加用药计划", systemImage: "plus") }.buttonStyle(PrimaryButton())
            }
            if store.data.medications.isEmpty {
                ContentUnavailableView("还没有添加药品", systemImage: "pills", description: Text("添加药名、处方剂量与时间后，可以记录服药或漏服。"))
            }
            ForEach(store.data.medications) { medication in
                Card {
                    RowLabel(title: medication.name, subtitle: "\(medication.dosage) · \(String(format: "%02d:%02d", medication.hour, medication.minute))", icon: "pills.fill", chevron: false)
                    if !medication.instructions.isEmpty { Text(medication.instructions).foregroundStyle(CX.muted) }
                    if let record = todayRecord(medication.id) {
                        Label(record.taken ? "今天已记录服药" : "今天已记录漏服", systemImage: record.taken ? "checkmark.circle" : "minus.circle").foregroundStyle(record.taken ? CX.teal : CX.coral)
                        Button("撤销今天的记录") { store.data.doseHistory.removeAll { $0.id == record.id } }.frame(minHeight: 44)
                    } else {
                        HStack {
                            Button("已服药") { record(medication, taken: true) }.buttonStyle(.borderedProminent).frame(minHeight: 44)
                            Button("记录漏服") { record(medication, taken: false) }.frame(minHeight: 44)
                        }
                    }
                    HStack {
                        Button("修改计划") { editing = medication }.frame(minHeight: 44)
                        Spacer()
                        Button("删除药品", role: .destructive) { removing = medication }.frame(minHeight: 44)
                    }
                }
            }
            NavigationLink { DoseHistoryView() } label: { Card { RowLabel(title: "服药历史", subtitle: "\(store.data.doseHistory.count) 条记录", icon: "clock.arrow.circlepath") } }.buttonStyle(.plain)
            Card {
                Text("如果漏服了").font(.title2.bold())
                Text("漏服处理因药物而异。先核对说明书或联系医生、药师确认，本应用不会自动补记或调整剂量。")
                NavigationLink("整理给医生的问题") { ConsultationView() }
            }
        }.navigationTitle("用药管理")
        .sheet(isPresented: $adding) { NavigationStack { MedicationEditor() } }
        .sheet(item: $editing) { medication in NavigationStack { MedicationEditor(medication: medication) } }
        .confirmationDialog("删除这项用药计划？既往记录将保留。", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("删除计划", role: .destructive) { if let id = removing?.id { store.data.medications.removeAll { $0.id == id } }; removing = nil }
        }
    }
    private func todayRecord(_ id: UUID) -> DoseRecord? { store.data.doseHistory.first { $0.medicationID == id && Calendar.current.isDateInToday($0.date) } }
    private func record(_ medication: Medication, taken: Bool) {
        guard todayRecord(medication.id) == nil else { return }
        store.data.doseHistory.append(DoseRecord(medicationID: medication.id, medicationName: medication.name, taken: taken))
        MoonHaptics.shared.play(success: taken, enabled: store.data.haptics)
    }
}

struct MedicationEditor: View {
    var medication: Medication?
    @Environment(AppStore.self) private var store
    @Environment(AuthSession.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var dosage = ""
    @State private var instructions = ""
    @State private var time = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? .now
    var body: some View {
        Form {
            Section("按本人处方填写") {
                TextField("药名", text: $name)
                TextField("处方剂量与用法", text: $dosage)
                DatePicker("每日记录时间", selection: $time, displayedComponents: .hourAndMinute)
                TextField("备注", text: $instructions, axis: .vertical)
            }
            Section { Text("此处为每日一次的记录计划，不会自动创建药物提醒。若处方每天多次服用，可分别添加对应时段的计划。").font(.footnote) }
            Section { Button("保存计划") {
                let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                let updated = Medication(id: medication?.id ?? UUID(), name: name, dosage: dosage, instructions: instructions, hour: components.hour ?? 20, minute: components.minute ?? 0)
                if let i = store.data.medications.firstIndex(where: { $0.id == updated.id }) { store.data.medications[i] = updated } else { store.data.medications.append(updated) }
                archiveMedication(updated)
                dismiss()
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.navigationTitle(medication == nil ? "添加药品" : "修改用药计划")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        .onAppear { if let medication { name = medication.name; dosage = medication.dosage; instructions = medication.instructions; time = Calendar.current.date(from: DateComponents(hour: medication.hour, minute: medication.minute)) ?? .now } }
    }

    /// Task #25：保存用药计划后，尽力归档到云端 health-records（record_type = medication）。
    /// 离线不发请求；归档失败静默，绝不影响本地保存。
    private func archiveMedication(_ medication: Medication) {
        guard AppConfiguration.useRemoteAPI else { return }
        let pid = PatientContext.effectiveID(auth)
        Task { @MainActor in
            await HealthSyncService.shared.archive(
                recordType: "medication",
                title: medication.name,
                content: [
                    "dosage": .string(medication.dosage),
                    "instructions": .string(medication.instructions),
                    "hour": .int(medication.hour),
                    "minute": .int(medication.minute)
                ],
                patientID: pid
            )
        }
    }
}

struct DoseHistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var filter = "全部"
    var body: some View {
        Page {
            Picker("记录类型", selection: $filter) { ForEach(["全部", "已服药", "漏服"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
            let records = store.data.doseHistory.filter { filter == "全部" || (filter == "已服药" ? $0.taken : !$0.taken) }
            if records.isEmpty { ContentUnavailableView("暂无这类记录", systemImage: "pills", description: Text("记录服药后，可在这里回顾。")) }
            ForEach(records.reversed()) { record in
                Card { RowLabel(title: record.medicationName, subtitle: "\(record.date.formatted(date: .abbreviated, time: .shortened)) · \(record.taken ? "已服药" : "漏服")", icon: record.taken ? "checkmark.circle.fill" : "minus.circle", tint: record.taken ? CX.teal : CX.coral, chevron: false) }
            }
        }.navigationTitle("服药历史")
    }
}
