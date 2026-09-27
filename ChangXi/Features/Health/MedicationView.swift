import SwiftUI

struct MedicationView: View {
    @Environment(AppStore.self) private var store
    @State private var adding = false
    @State private var editing: Medication?
    @State private var removing: Medication?

    var body: some View {
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text("用药")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.statusPositive)
                    .tracking(0.6)
                Text("把用药安排记得清楚")
                    .font(CXTypography.display)
                Text("只记录本人处方或药品说明中的用法；不确定时先向医生或药师核对。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            Button {
                adding = true
            } label: {
                Label("添加用药计划", systemImage: "plus")
            }
            .buttonStyle(PrimaryButton())

            if store.data.medications.isEmpty {
                CXEmptyState(
                    title: "还没有添加药品",
                    message: "添加药名、处方剂量与时间后，就可以记录每天是否服药。",
                    icon: "pills"
                )
            } else {
                SectionEyebrow(title: "今天", action: "\(store.data.medications.count) 项计划")

                ForEach(store.data.medications) { medication in
                    medicationCard(medication)
                }
            }

            SectionEyebrow(title: "记录")
            NavigationLink { DoseHistoryView() } label: {
                HStack(spacing: CXSpacing.md) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(CX.actionPrimary)
                        .frame(width: 42, height: 42)
                        .background(CX.actionPrimary.opacity(0.08), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("服药历史")
                            .font(CXTypography.section)
                        Text("\(store.data.doseHistory.count) 条记录")
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

            SectionEyebrow(title: "如果漏服了")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                Text("漏服处理因药物而异。先核对说明书或联系医生、药师确认，本应用不会自动补记或调整剂量。")
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(4)

                NavigationLink("整理给医生的问题") { ConsultationView() }
                    .font(CXTypography.supporting.weight(.semibold))
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)
        }
        .navigationTitle("用药管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $adding) {
            NavigationStack { MedicationEditor() }
        }
        .sheet(item: $editing) { medication in
            NavigationStack { MedicationEditor(medication: medication) }
        }
        .confirmationDialog(
            "删除这项用药计划？既往记录将保留。",
            isPresented: Binding(
                get: { removing != nil },
                set: { if !$0 { removing = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除计划", role: .destructive) {
                if let id = removing?.id {
                    store.data.medications.removeAll { $0.id == id }
                }
                removing = nil
            }
        }
    }

    @ViewBuilder
    private func medicationCard(_ medication: Medication) -> some View {
        VStack(alignment: .leading, spacing: CXSpacing.md) {
            HStack(spacing: CXSpacing.md) {
                Image(systemName: "pills.fill")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(CX.statusPositive)
                    .frame(width: 44, height: 44)
                    .background(CX.statusPositive.opacity(0.08), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(medication.name)
                        .font(CXTypography.title)
                    Text("\(medication.dosage) · \(String(format: "%02d:%02d", medication.hour, medication.minute))")
                        .font(CXTypography.supporting)
                        .foregroundStyle(CX.muted)
                }

                Spacer()
            }

            if !medication.instructions.isEmpty {
                Text(medication.instructions)
                    .font(CXTypography.supporting)
                    .foregroundStyle(CX.muted)
            }

            if let record = todayRecord(medication.id) {
                Label(
                    record.taken ? "今天已记录服药" : "今天已记录漏服",
                    systemImage: record.taken ? "checkmark.circle.fill" : "minus.circle"
                )
                .font(CXTypography.supporting.weight(.semibold))
                .foregroundStyle(record.taken ? CX.statusPositive : CX.statusCritical)

                Button("撤销今天的记录") {
                    store.data.doseHistory.removeAll { $0.id == record.id }
                }
                .font(CXTypography.meta.weight(.semibold))
            } else {
                HStack(spacing: CXSpacing.sm) {
                    Button("已服药") {
                        record(medication, taken: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)

                    Button("记录漏服") {
                        record(medication, taken: false)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            }

            HStack {
                Button("修改计划") { editing = medication }
                    .font(CXTypography.meta.weight(.semibold))
                Spacer()
                Button("删除药品", role: .destructive) { removing = medication }
                    .font(CXTypography.meta.weight(.semibold))
            }
        }
        .padding(CXSpacing.lg)
        .cxContentSurface(cornerRadius: CXRadius.lg)
    }

    private func todayRecord(_ id: UUID) -> DoseRecord? {
        store.data.doseHistory.first {
            $0.medicationID == id && Calendar.current.isDateInToday($0.date)
        }
    }

    private func record(_ medication: Medication, taken: Bool) {
        guard todayRecord(medication.id) == nil else { return }
        store.data.doseHistory.append(
            DoseRecord(
                medicationID: medication.id,
                medicationName: medication.name,
                taken: taken
            )
        )
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
        Page(illustrated: true) {
            VStack(alignment: .leading, spacing: CXSpacing.xs) {
                Text(medication == nil ? "添加用药" : "修改用药")
                    .font(CXTypography.micro.weight(.semibold))
                    .foregroundStyle(CX.statusPositive)
                    .tracking(0.6)

                Text("按处方把关键信息记清楚")
                    .font(CXTypography.display)

                Text("常曦只帮你记录，不会根据这里的内容自动调整剂量或频次。")
                    .font(CXTypography.body)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(5)
            }

            SectionEyebrow(title: "处方信息")
            VStack(alignment: .leading, spacing: CXSpacing.md) {
                LabeledMedicationField(title: "药名", hint: "必填") {
                    TextField("例如：阿司匹林", text: $name)
                }

                LabeledMedicationField(title: "剂量与用法", hint: "按处方填写") {
                    TextField("例如：100 mg，每日一次", text: $dosage)
                }

                Divider().overlay(CX.separator.opacity(0.14))

                DatePicker("每日记录时间", selection: $time, displayedComponents: .hourAndMinute)
                    .font(CXTypography.supporting)
            }
            .padding(CXSpacing.lg)
            .cxContentSurface(cornerRadius: CXRadius.lg)

            SectionEyebrow(title: "补充说明", action: "可选")
            TextField("例如：随餐服用、医生特别交代", text: $instructions, axis: .vertical)
                .lineLimit(3...6)
                .padding(CXSpacing.md)
                .background(CX.surface, in: .rect(cornerRadius: CXRadius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: CXRadius.md, style: .continuous)
                        .strokeBorder(CX.separator.opacity(0.12), lineWidth: 0.5)
                }

            Button("保存计划") {
                save()
            }
            .buttonStyle(PrimaryButton())
            .disabled(
                name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )

            HStack(alignment: .top, spacing: CXSpacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundStyle(CX.actionPrimary)
                Text("这里按“每日一次”建立记录计划。若处方一天多次，可分别添加对应时段。")
                    .font(CXTypography.meta)
                    .foregroundStyle(CX.muted)
                    .lineSpacing(4)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CXSpacing.xs)
        }
        .navigationTitle(medication == nil ? "添加药品" : "修改用药计划")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
        .onAppear {
            if let medication {
                name = medication.name
                dosage = medication.dosage
                instructions = medication.instructions
                time = Calendar.current.date(
                    from: DateComponents(hour: medication.hour, minute: medication.minute)
                ) ?? .now
            }
        }
        .assistantFormContext(title: "用药计划备注", draft: instructions) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            instructions = trimmed
            return true
        }
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let updated = Medication(
            id: medication?.id ?? UUID(),
            name: name,
            dosage: dosage,
            instructions: instructions,
            hour: components.hour ?? 20,
            minute: components.minute ?? 0
        )
        if let i = store.data.medications.firstIndex(where: { $0.id == updated.id }) {
            store.data.medications[i] = updated
        } else {
            store.data.medications.append(updated)
        }
        archiveMedication(updated)
        dismiss()
    }

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

private struct LabeledMedicationField<Content: View>: View {
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

struct DoseHistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var filter = "全部"
    var body: some View {
        Page {
            Picker("记录类型", selection: $filter) { ForEach(["全部", "已服药", "漏服"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
            let records = store.data.doseHistory.filter { filter == "全部" || (filter == "已服药" ? $0.taken : !$0.taken) }
            if records.isEmpty { CXEmptyState(title: "暂无这类记录", message: "记录服药或漏服后，可以在这里回顾。", icon: "pills") }
            ForEach(records.reversed()) { record in
                Card { RowLabel(title: record.medicationName, subtitle: "\(record.date.formatted(date: .abbreviated, time: .shortened)) · \(record.taken ? "已服药" : "漏服")", icon: record.taken ? "checkmark.circle.fill" : "minus.circle", tint: record.taken ? CX.teal : CX.coral, chevron: false) }
            }
        }.navigationTitle("服药历史")
    }
}
