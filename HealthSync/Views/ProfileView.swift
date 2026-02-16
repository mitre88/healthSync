import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var medicationStore: MedicationStore
    @EnvironmentObject private var notificationService: NotificationService
    
    @State private var name = ""
    @State private var age = ""
    @State private var allergies = ""
    @State private var notificationsEnabled = true
    @State private var reminderMinutes = 15
    
    var body: some View {
        NavigationStack {
            List {
                Section("Información Personal") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.teal)
                        
                        Spacer()
                    }
                    .listRowBackground(Color.teal.opacity(0.1))
                    
                    TextField("Nombre completo", text: $name)
                    
                    HStack {
                        Text("Edad")
                        Spacer()
                        TextField("Edad", text: $age)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("años")
                            .foregroundStyle(.secondary)
                    }
                    
                    TextField("Alergias conocidas", text: $allergies, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Notificaciones") {
                    Toggle("Activar recordatorios", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            if newValue {
                                Task {
                                    _ = await notificationService.requestAuthorization()
                                }
                            }
                        }
                    
                    if notificationsEnabled {
                        Picker("Recordar antes de", selection: $reminderMinutes) {
                            Text("5 minutos").tag(5)
                            Text("10 minutos").tag(10)
                            Text("15 minutos").tag(15)
                            Text("30 minutos").tag(30)
                            Text("1 hora").tag(60)
                        }
                    }
                    
                    HStack {
                        Text("Estado")
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(notificationService.isAuthorized ? .green : .orange)
                                .frame(width: 8, height: 8)
                            
                            Text(notificationService.isAuthorized ? "Activas" : "Inactivas")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Estadísticas") {
                    LabeledContent("Medicamentos activos") {
                        Text("\(medicationStore.getActiveMedicationsCount())")
                            .fontWeight(.semibold)
                            .foregroundStyle(.teal)
                    }
                    
                    LabeledContent("Notificaciones programadas") {
                        Text("\(notificationService.pendingNotifications.count)")
                            .fontWeight(.semibold)
                            .foregroundStyle(.teal)
                    }
                    
                    LabeledContent("Medicamentos tomados (total)") {
                        Text("\(medicationStore.medications.reduce(0) { $0 + $1.takenDates.count })")
                            .fontWeight(.semibold)
                            .foregroundStyle(.teal)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        Task {
                            notificationService.cancelAllReminders()
                        }
                    } label: {
                        Label("Cancelar todas las notificaciones", systemImage: "bell.slash.fill")
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("Esto eliminará todos los recordatorios programados. Los medicamentos seguirán guardados.")
                        .font(.caption)
                }
                
                Section {
                    Link(destination: URL(string: "https://www.apple.com/health")!) {
                        Label("Apple Health", systemImage: "heart.fill")
                    }
                    
                    Link(destination: URL(string: "app-settings:")!) {
                        Label("Configuración del Sistema", systemImage: "gear")
                    }
                }
                
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("HealthSync")
                                .font(.headline)
                            Text("Versión 1.0.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Perfil")
            .onAppear {
                loadProfile()
            }
        }
    }
    
    private func loadProfile() {
        if let profile = medicationStore.userProfile {
            name = profile.name
            age = profile.age > 0 ? "\(profile.age)" : ""
            allergies = profile.allergies
            notificationsEnabled = profile.notificationsEnabled
            reminderMinutes = profile.reminderMinutesBefore
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(MedicationStore())
        .environmentObject(NotificationService())
}
