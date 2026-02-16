import Foundation
import SwiftData

@Model
final class Medication {
    var id: UUID
    var name: String
    var dosage: String
    var frequency: String
    var instructions: String
    var times: [Date]
    var startDate: Date
    var endDate: Date?
    var isActive: Bool
    var takenDates: [Date]
    var doctorName: String
    var prescriptionDate: Date?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        dosage: String,
        frequency: String,
        instructions: String = "",
        times: [Date] = [],
        startDate: Date = Date(),
        endDate: Date? = nil,
        isActive: Bool = true,
        takenDates: [Date] = [],
        doctorName: String = "",
        prescriptionDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.instructions = instructions
        self.times = times
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.takenDates = takenDates
        self.doctorName = doctorName
        self.prescriptionDate = prescriptionDate
        self.createdAt = Date()
    }
    
    var formattedTimes: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return times.map { formatter.string(from: $0) }.joined(separator: ", ")
    }
    
    func isTakenToday() -> Bool {
        let calendar = Calendar.current
        return takenDates.contains { calendar.isDateInToday($0) }
    }
    
    func nextDoseTime() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        for time in times.sorted() {
            let components = calendar.dateComponents([.hour, .minute], from: time)
            var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
            todayComponents.hour = components.hour
            todayComponents.minute = components.minute
            
            if let todayTime = calendar.date(from: todayComponents), todayTime > now {
                return todayTime
            }
        }
        
        if let firstTime = times.sorted().first {
            let components = calendar.dateComponents([.hour, .minute], from: firstTime)
            var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: 1, to: now)!)
            tomorrowComponents.hour = components.hour
            tomorrowComponents.minute = components.minute
            return calendar.date(from: tomorrowComponents)
        }
        
        return nil
    }
}

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var age: Int
    var allergies: String
    var notificationsEnabled: Bool
    var reminderMinutesBefore: Int
    
    init(
        id: UUID = UUID(),
        name: String = "",
        age: Int = 0,
        allergies: String = "",
        notificationsEnabled: Bool = true,
        reminderMinutesBefore: Int = 15
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.allergies = allergies
        self.notificationsEnabled = notificationsEnabled
        self.reminderMinutesBefore = reminderMinutesBefore
    }
}
