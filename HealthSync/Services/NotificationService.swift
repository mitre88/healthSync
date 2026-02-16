import Foundation
import UserNotifications

@MainActor
class NotificationService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task {
            await refreshAuthorizationStatus()
            await refreshPendingNotifications()
        }
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            await refreshAuthorizationStatus()
            return isAuthorized
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }
    
    func scheduleMedicationReminder(
        for medication: Medication,
        reminderMinutesBefore: Int = 0
    ) async {
        guard isAuthorized else { return }
        
        await cancelMedicationReminders(for: medication)
        
        for (index, time) in medication.times.enumerated() {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: time)
            
            let content = UNMutableNotificationContent()
            content.title = "HealthSync - Recordatorio"
            content.body = "Es hora de tomar \(medication.name) - \(medication.dosage)"
            content.sound = .default
            content.badge = 1
            content.userInfo = ["medicationId": medication.id.uuidString, "timeIndex": index]
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
            let request = UNNotificationRequest(
                identifier: "\(medication.id.uuidString)-\(index)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("Error scheduling notification: \(error)")
            }
            
            if reminderMinutesBefore > 0,
               let reminderDate = calendar.date(byAdding: .minute, value: -reminderMinutesBefore, to: time) {
                let reminderComponents = calendar.dateComponents([.hour, .minute], from: reminderDate)
                let reminderContent = UNMutableNotificationContent()
                reminderContent.title = "HealthSync - Proximo medicamento"
                reminderContent.body = "En \(reminderMinutesBefore) min: \(medication.name) - \(medication.dosage)"
                reminderContent.sound = .default
                reminderContent.userInfo = ["medicationId": medication.id.uuidString, "timeIndex": index, "kind": "advance"]
                
                let reminderTrigger = UNCalendarNotificationTrigger(
                    dateMatching: reminderComponents,
                    repeats: true
                )
                
                let reminderRequest = UNNotificationRequest(
                    identifier: "\(medication.id.uuidString)-pre-\(index)",
                    content: reminderContent,
                    trigger: reminderTrigger
                )
                
                do {
                    try await UNUserNotificationCenter.current().add(reminderRequest)
                } catch {
                    print("Error scheduling pre-reminder: \(error)")
                }
            }
        }
        
        await refreshPendingNotifications()
    }
    
    func cancelMedicationReminders(for medication: Medication) async {
        for index in medication.times.indices {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [
                    "\(medication.id.uuidString)-\(index)",
                    "\(medication.id.uuidString)-pre-\(index)"
                ]
            )
        }
        await refreshPendingNotifications()
    }
    
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        pendingNotifications = []
    }
    
    func refreshPendingNotifications() async {
        pendingNotifications = await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
    
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
    }
    
    func getNotificationSettings() async -> UNNotificationSettings {
        await UNUserNotificationCenter.current().notificationSettings()
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let medicationIdString = userInfo["medicationId"] as? String,
           let medicationId = UUID(uuidString: medicationIdString) {
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .medicationReminderTapped,
                    object: nil,
                    userInfo: ["medicationId": medicationId]
                )
            }
        }
        
        completionHandler()
    }
}

extension Notification.Name {
    static let medicationReminderTapped = Notification.Name("medicationReminderTapped")
}
