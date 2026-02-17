import SwiftUI

struct MedicationsView: View {
    @EnvironmentObject private var medicationStore: MedicationStore
    @EnvironmentObject private var notificationService: NotificationService
    @State private var showingAddMedication = false
    @State private var selectedMedication: Medication?
    @State private var showingDeleteAlert = false
    @State private var medicationToDelete: Medication?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(medicationStore.medications) { medication in
                    MedicationRow(medication: medication)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMedication = medication
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            deleteButton(for: medication)
                        }
                        .swipeActions(edge: .leading) {
                            takeButton(for: medication)
                        }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Medicamentos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddMedication = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMedication) {
                AddMedicationView()
            }
            .sheet(item: $selectedMedication) { medication in
                MedicationDetailView(medication: medication)
            }
            .alert("Eliminar Medicamento", isPresented: $showingDeleteAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    if let med = medicationToDelete {
                        Task {
                            await notificationService.cancelMedicationReminders(for: med)
                            medicationStore.deleteMedication(med)
                        }
                        medicationToDelete = nil
                    }
                }
            } message: {
                Text("¿Estás seguro de que deseas eliminar este medicamento?")
            }
        }
    }
    
    private func deleteButton(for medication: Medication) -> some View {
        Button(role: .destructive) {
            medicationToDelete = medication
            showingDeleteAlert = true
        } label: {
            Label("Eliminar", systemImage: "trash")
        }
    }
    
    private func takeButton(for medication: Medication) -> some View {
        Button {
            medicationStore.markAsTaken(medication)
        } label: {
            Label("Tomado", systemImage: "checkmark")
        }
        .tint(.green)
    }
}

struct MedicationRow: View {
    let medication: Medication
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(medication.isActive ? Color.teal.opacity(0.2) : Color.gray.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "pills.fill")
                        .foregroundStyle(medication.isActive ? .teal : .gray)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(medication.name)
                        .font(.headline)
                    
                    if !medication.isActive {
                        Text("Inactivo")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.gray)
                            .clipShape(Capsule())
                    }
                    
                    if medication.isTakenToday() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                
                Text(medication.dosage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Label(medication.frequency, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.teal)
                    
                    if !medication.doctorName.isEmpty {
                        Label(medication.doctorName, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddMedicationView: View {
    @EnvironmentObject private var medicationStore: MedicationStore
    @EnvironmentObject private var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var dosage = ""
    @State private var frequency = ""
    @State private var instructions = ""
    @State private var doctorName = ""
    @State private var times: [Date] = []
    @State private var showingTimePicker = false
    
    private let frequencyOptions = [
        "1 vez al día",
        "2 veces al día",
        "3 veces al día",
        "Cada 8 horas",
        "Cada 12 horas",
        "Cada 24 horas",
        "Según indicación médica"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Información del Medicamento") {
                    TextField("Nombre del medicamento", text: $name)
                    TextField("Dosis (ej: 500mg)", text: $dosage)
                    
                    Picker("Frecuencia", selection: $frequency) {
                        Text("Seleccionar frecuencia").tag("")
                        ForEach(frequencyOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    
                    TextField("Instrucciones adicionales", text: $instructions, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Doctor") {
                    TextField("Nombre del doctor", text: $doctorName)
                }
                
                Section("Horarios") {
                    ForEach(times.indices, id: \.self) { index in
                        DatePicker(
                            "Hora \(index + 1)",
                            selection: $times[index],
                            displayedComponents: .hourAndMinute
                        )
                    }
                    .onDelete { indices in
                        times.remove(atOffsets: indices)
                    }
                    
                    Button {
                        let calendar = Calendar.current
                        times.append(calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!)
                    } label: {
                        Label("Agregar horario", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Nuevo Medicamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        saveMedication()
                    }
                    .disabled(name.isEmpty || dosage.isEmpty || frequency.isEmpty)
                }
            }
        }
    }
    
    private func saveMedication() {
        let medication = Medication(
            name: name,
            dosage: dosage,
            frequency: frequency,
            instructions: instructions,
            times: times.isEmpty ? [Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!] : times,
            doctorName: doctorName
        )
        
        medicationStore.addMedication(medication)
        
        let notificationsEnabled = medicationStore.userProfile?.notificationsEnabled ?? true
        
        Task {
            if notificationsEnabled, await notificationService.requestAuthorization() {
                await notificationService.scheduleMedicationReminder(
                    for: medication,
                    reminderMinutesBefore: medicationStore.userProfile?.reminderMinutesBefore ?? 0
                )
            }
        }
        
        dismiss()
    }
}

struct MedicationDetailView: View {
    @EnvironmentObject private var medicationStore: MedicationStore
    @EnvironmentObject private var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss
    
    @State var medication: Medication
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Información") {
                    LabeledContent("Nombre", value: medication.name)
                    LabeledContent("Dosis", value: medication.dosage)
                    LabeledContent("Frecuencia", value: medication.frequency)
                    
                    if !medication.instructions.isEmpty {
                        LabeledContent("Instrucciones") {
                            Text(medication.instructions)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Horarios") {
                    ForEach(medication.times, id: \.self) { time in
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.teal)
                            Spacer()
                            Text(time.formatted(date: .omitted, time: .shortened))
                                .fontWeight(.medium)
                        }
                    }
                }
                
                if !medication.doctorName.isEmpty {
                    Section("Prescripción") {
                        LabeledContent("Doctor", value: medication.doctorName)
                        
                        if let date = medication.prescriptionDate {
                            LabeledContent("Fecha", value: date.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                }
                
                Section("Estado") {
                    Toggle("Activo", isOn: Binding(
                        get: { medication.isActive },
                        set: { medication.isActive = $0 }
                    ))
                    .onChange(of: medication.isActive) { _, newValue in
                        medicationStore.updateMedication(medication)
                        
                        Task {
                            if newValue {
                                if medicationStore.userProfile?.notificationsEnabled ?? true {
                                    await notificationService.scheduleMedicationReminder(
                                        for: medication,
                                        reminderMinutesBefore: medicationStore.userProfile?.reminderMinutesBefore ?? 0
                                    )
                                }
                            } else {
                                await notificationService.cancelMedicationReminders(for: medication)
                            }
                        }
                    }
                    
                    LabeledContent("Veces tomado", value: "\(medication.takenDates.count)")
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Eliminar Medicamento", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(medication.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .alert("Eliminar Medicamento", isPresented: $showingDeleteAlert) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    Task {
                        await notificationService.cancelMedicationReminders(for: medication)
                        medicationStore.deleteMedication(medication)
                        dismiss()
                    }
                }
            } message: {
                Text("¿Estás seguro de que deseas eliminar este medicamento?")
            }
        }
    }
}

#Preview {
    MedicationsView()
        .environmentObject(MedicationStore())
        .environmentObject(NotificationService())
}
