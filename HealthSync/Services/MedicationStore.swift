import Foundation
import SwiftData

@MainActor
class MedicationStore: ObservableObject {
    @Published var medications: [Medication] = []
    @Published var userProfile: UserProfile?
    
    private var modelContext: ModelContext?
    
    init() {
        userProfile = UserProfile(name: "", age: 0, allergies: "", notificationsEnabled: true)
        loadSampleData()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchMedications()
    }
    
    func fetchMedications() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Medication>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        
        do {
            medications = try context.fetch(descriptor)
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
    
    func getTodayMedications() -> [Medication] {
        let calendar = Calendar.current
        return medications.filter { med in
            med.isActive && (med.endDate == nil || calendar.compare(Date(), to: med.endDate!, toGranularity: .day) != .orderedDescending)
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
    
    private func loadSampleData() {
        let calendar = Calendar.current
        
        let med1 = Medication(
            name: "Paracetamol",
            dosage: "500mg",
            frequency: "Cada 8 horas",
            instructions: "Tomar con alimentos",
            times: [
                calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!,
                calendar.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!,
                calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
            ],
            doctorName: "Dr. García"
        )
        
        let med2 = Medication(
            name: "Omeprazol",
            dosage: "20mg",
            frequency: "1 vez al día",
            instructions: "Tomar en ayunas, 30 min antes del desayuno",
            times: [calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!],
            doctorName: "Dra. Martínez"
        )
        
        let med3 = Medication(
            name: "Amoxicilina",
            dosage: "500mg",
            frequency: "Cada 12 horas",
            instructions: "Completar tratamiento de 7 días",
            times: [
                calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!,
                calendar.date(bySettingHour: 21, minute: 0, second: 0, of: Date())!
            ],
            endDate: calendar.date(byAdding: .day, value: 7, to: Date()),
            doctorName: "Dr. López"
        )
        
        medications = [med1, med2, med3]
    }
}
