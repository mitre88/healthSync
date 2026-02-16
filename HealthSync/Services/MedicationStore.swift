import Foundation
import SwiftData

@MainActor
class MedicationStore: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var userProfile: UserProfile?
    
    private var modelContext: ModelContext?
    
    init() {
        userProfile = UserProfile(
            name: "",
            age: 0,
            allergies: "",
            notificationsEnabled: true,
            reminderMinutesBefore: 15
        )
    }
    
    func setModelContext(_ context: ModelContext) {
        modelContext = context
        fetchMedications()
        fetchOrCreateUserProfile()
    }
    
    func fetchMedications() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Medication>()
        
        do {
            medications = try context
                .fetch(descriptor)
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("Error fetching medications: \(error)")
        }
    }
    
    func addMedication(_ medication: Medication) {
        guard let context = modelContext else {
            medications.append(medication)
            return
        }
        
        context.insert(medication)
        
        do {
            try context.save()
            fetchMedications()
        } catch {
            print("Error saving medication: \(error)")
        }
    }
    
    func updateMedication(_ medication: Medication) {
        guard let context = modelContext else { return }
        
        do {
            try context.save()
            fetchMedications()
        } catch {
            print("Error updating medication: \(error)")
        }
    }
    
    func deleteMedication(_ medication: Medication) {
        guard let context = modelContext else {
            medications.removeAll { $0.id == medication.id }
            return
        }
        
        context.delete(medication)
        
        do {
            try context.save()
            fetchMedications()
        } catch {
            print("Error deleting medication: \(error)")
        }
    }
    
    func markAsTaken(_ medication: Medication) {
        medication.takenDates.append(Date())
        updateMedication(medication)
    }
    
    func updateUserProfile(
        name: String,
        age: Int,
        allergies: String,
        notificationsEnabled: Bool,
        reminderMinutesBefore: Int
    ) {
        let profile = userProfile ?? UserProfile()
        profile.name = name
        profile.age = max(age, 0)
        profile.allergies = allergies
        profile.notificationsEnabled = notificationsEnabled
        profile.reminderMinutesBefore = reminderMinutesBefore
        userProfile = profile
        
        guard let context = modelContext else { return }
        
        if profile.modelContext == nil {
            context.insert(profile)
        }
        
        do {
            try context.save()
        } catch {
            print("Error saving user profile: \(error)")
        }
    }
    
    func getTodayMedications() -> [Medication] {
        let calendar = Calendar.current
        return medications.filter { medication in
            guard medication.isActive else { return false }
            guard let endDate = medication.endDate else { return true }
            return calendar.compare(Date(), to: endDate, toGranularity: .day) != .orderedDescending
        }
    }
    
    func getUpcomingReminders() -> [(Medication, Date)] {
        var reminders: [(Medication, Date)] = []
        
        for medication in getTodayMedications() {
            if let nextDose = medication.nextDoseTime() {
                reminders.append((medication, nextDose))
            }
        }
        
        return reminders.sorted { $0.1 < $1.1 }
    }
    
    func getActiveMedicationsCount() -> Int {
        medications.filter { $0.isActive }.count
    }
    
    private func fetchOrCreateUserProfile() {
        guard let context = modelContext else { return }
        
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        
        do {
            if let existingProfile = try context.fetch(descriptor).first {
                userProfile = existingProfile
                return
            }
            
            let profile = userProfile ?? UserProfile()
            context.insert(profile)
            try context.save()
            userProfile = profile
        } catch {
            print("Error fetching user profile: \(error)")
        }
    }
}
