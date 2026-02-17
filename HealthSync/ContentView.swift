import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var medicationStore: MedicationStore
    @State private var selectedTab = 0
    @State private var hasConfiguredModelContext = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Inicio")
                }
                .tag(0)
            
            ScanView()
                .tabItem {
                    Image(systemName: "doc.text.viewfinder")
                    Text("Escanear")
                }
                .tag(1)
            
            MedicationsView()
                .tabItem {
                    Image(systemName: "pills.fill")
                    Text("Medicamentos")
                }
                .tag(2)
            
            ScheduleView()
                .tabItem {
                    Image(systemName: "calendar.badge.clock")
                    Text("Horarios")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Perfil")
                }
                .tag(4)
        }
        .tint(.teal)
        .task {
            guard !hasConfiguredModelContext else { return }
            medicationStore.setModelContext(modelContext)
            hasConfiguredModelContext = true
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MedicationStore())
        .environmentObject(NotificationService())
}
