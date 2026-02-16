import SwiftUI
import SwiftData

@main
struct HealthSyncApp: App {
    @StateObject private var medicationStore = MedicationStore()
    @StateObject private var notificationService = NotificationService()
    
    private let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Medication.self,
            UserProfile.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(medicationStore)
                .environmentObject(notificationService)
                .tint(.teal)
        }
        .modelContainer(sharedModelContainer)
    }
}
