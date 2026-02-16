import SwiftUI

@main
struct HealthSyncApp: App {
    @StateObject private var medicationStore = MedicationStore()
    @StateObject private var notificationService = NotificationService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(medicationStore)
                .environmentObject(notificationService)
                .tint(.teal)
        }
    }
}
