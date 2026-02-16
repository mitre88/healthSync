import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var medicationStore: MedicationStore
    @EnvironmentObject private var notificationService: NotificationService
    @State private var showingScan = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    todayMedicationsSection
                    upcomingRemindersSection
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("HealthSync")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingScan = true
                    } label: {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingScan) {
                ScanView()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(greeting)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(.teal.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "pills.fill")
                            .font(.title2)
                            .foregroundStyle(.teal)
                    }
            }
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Activos",
                    value: "\(medicationStore.getActiveMedicationsCount())",
                    icon: "pill.fill",
                    color: .teal
                )
                
                StatCard(
                    title: "Hoy",
                    value: "\(medicationStore.getTodayMedications().count)",
                    icon: "calendar",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private var todayMedicationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Medicamentos de Hoy")
                .font(.headline)
            
            let todayMeds = medicationStore.getTodayMedications()
            
            if todayMeds.isEmpty {
                emptyStateView
            } else {
                ForEach(todayMeds) { medication in
                    MedicationCard(medication: medication) {
                        medicationStore.markAsTaken(medication)
                    }
                }
            }
        }
    }
    
    private var upcomingRemindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Próximos Recordatorios")
                    .font(.headline)
                Spacer()
                Image(systemName: "clock.fill")
                    .foregroundStyle(.teal)
            }
            
            let reminders = medicationStore.getUpcomingReminders().prefix(3)
            
            if reminders.isEmpty {
                Text("No hay recordatorios pendientes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reminders, id: \.0.id) { medication, time in
                    HStack {
                        Circle()
                            .fill(.teal.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "pills.fill")
                                    .font(.caption)
                                    .foregroundStyle(.teal)
                            }
                        
                        VStack(alignment: .leading) {
                            Text(medication.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(medication.dosage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(time.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.teal)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acciones Rápidas")
                .font(.headline)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Escanear",
                    icon: "camera.fill",
                    color: .teal
                ) {
                    showingScan = true
                }
                
                QuickActionButton(
                    title: "Medicamentos",
                    icon: "pills.fill",
                    color: .blue
                ) { }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "pills.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("No hay medicamentos para hoy")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                showingScan = true
            } label: {
                Text("Escanear Receta")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.teal)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Buenos días" }
        else if hour < 18 { return "Buenas tardes" }
        else { return "Buenas noches" }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MedicationCard: View {
    let medication: Medication
    let onMarkTaken: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(medication.isTakenToday() ? Color.green.opacity(0.2) : Color.teal.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: medication.isTakenToday() ? "checkmark" : "pills.fill")
                        .foregroundStyle(medication.isTakenToday() ? .green : .teal)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(medication.name)
                    .font(.headline)
                
                Text(medication.dosage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(medication.formattedTimes)
                    .font(.caption)
                    .foregroundStyle(.teal)
            }
            
            Spacer()
            
            if !medication.isTakenToday() {
                Button {
                    onMarkTaken()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.teal)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(MedicationStore())
        .environmentObject(NotificationService())
}
