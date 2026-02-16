import Foundation

struct Prescription: Identifiable, Codable {
    let id: UUID
    let doctorName: String
    let doctorSpecialty: String?
    let prescriptionDate: Date
    let medications: [ExtractedMedication]
    let notes: String?
    let rawText: String
    let imageData: Data?
    
    init(
        id: UUID = UUID(),
        doctorName: String,
        doctorSpecialty: String? = nil,
        prescriptionDate: Date,
        medications: [ExtractedMedication],
        notes: String? = nil,
        rawText: String,
        imageData: Data? = nil
    ) {
        self.id = id
        self.doctorName = doctorName
        self.doctorSpecialty = doctorSpecialty
        self.prescriptionDate = prescriptionDate
        self.medications = medications
        self.notes = notes
        self.rawText = rawText
        self.imageData = imageData
    }
}

struct ExtractedMedication: Identifiable, Codable {
    let id: UUID
    let name: String
    let dosage: String
    let frequency: String
    let instructions: String?
    let duration: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        dosage: String,
        frequency: String,
        instructions: String? = nil,
        duration: String? = nil
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.instructions = instructions
        self.duration = duration
    }
}

struct ScanResult {
    let recognizedText: String
    let confidence: Double
    let medications: [ExtractedMedication]
    let doctorName: String?
    let prescriptionDate: Date?
}
