import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var medicationStore: MedicationStore
    @EnvironmentObject private var notificationService: NotificationService
    
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    datePickerSection
                    
                    scheduleTimeline
                    
                    notificationsStatus
                }
                .padding()
            }
            .navigationTitle("Horarios")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await refreshNotifications()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await refreshNotifications()
            }
        }
    }
    
    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seleccionar Fecha")
                .font(.headline)
            
            DatePicker(
                "Fecha",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(.teal)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var scheduleTimeline: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Horarios del Día")
                .font(.headline)
            
            let schedule = getScheduleForDate(selectedDate)
            
            if schedule.isEmpty {
                emptyScheduleView
            } else {
                ForEach(schedule.sorted(by: { $0.time < $1.time })) { item in
                    ScheduleItemView(item: item) {
                        if let med = medicationStore.medications.first(where: { $0.id == item.medicationId }) {
                            medicationStore.markAsTaken(med)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var emptyScheduleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("No hay medicamentos programados")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    private var notificationsStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Estado de Notificaciones")
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(notificationService.isAuthorized ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
            }
            
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.teal)
                
                VStack(alignment: .leading) {
                    Text("Notificaciones pendientes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(notificationService.pendingNotifications.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            
            if !notificationService.isAuthorized {
                Button {
                    Task {
                        _ = await notificationService.requestAuthorization()
                    }
                } label: {
                    Text("Habilitar Notificaciones")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func getScheduleForDate(_ date: Date) -> [ScheduleItem] {
        var items: [ScheduleItem] = []
        let calendar = Calendar.current
        
        for medication in medicationStore.medications where medication.isActive {
            for time in medication.times {
                let components = calendar.dateComponents([.hour, .minute], from: time)
                var scheduleComponents = calendar.dateComponents([.year, .month, .day], from: date)
                scheduleComponents.hour = components.hour
                scheduleComponents.minute = components.minute
                
                if let scheduleTime = calendar.date(from: scheduleComponents) {
                    let isTaken = medication.takenDates.contains { takenDate in
                        calendar.isDate(takenDate, inSameDayAs: date) &&
                        calendar.component(.hour, from: takenDate) == components.hour &&
                        calendar.component(.minute, from: takenDate) == components.minute
                    }
                    
                    items.append(ScheduleItem(
                        medicationId: medication.id,
                        medicationName: medication.name,
                        dosage: medication.dosage,
                        time: scheduleTime,
                        isTaken: isTaken
                    ))
                }
            }
        }
        
        return items
    }
    
    private func refreshNotifications() async {
        await notificationService.refreshPendingNotifications()
    }
}

struct ScheduleItem: Identifiable {
    let id = UUID()
    let medicationId: UUID
    let medicationName: String
    let dosage: String
    let time: Date
    let isTaken: Bool
}

struct ScheduleItemView: View {
    let item: ScheduleItem
    let onMarkTaken: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Circle()
                    .fill(item.isTaken ? Color.green : Color.teal)
                    .frame(width: 12, height: 12)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
            }
            .frame(height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.time.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.teal)
                
                Text(item.medicationName)
                    .font(.headline)
                
                Text(item.dosage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if item.isTaken {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Button {
                    onMarkTaken()
                } label: {
                    Image(systemName: "circle")
                        .foregroundStyle(.teal)
                        .font(.title2)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ScheduleView()
        .environmentObject(MedicationStore())
        .environmentObject(NotificationService())
}
