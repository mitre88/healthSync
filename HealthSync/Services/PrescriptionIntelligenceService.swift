import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct PrescriptionExtractionResult {
    let medications: [ExtractedMedication]
    let doctorName: String?
    let prescriptionDate: Date?
    let source: ExtractionSource
}

@MainActor
final class PrescriptionIntelligenceService {
    private let heuristicExtractor = HeuristicPrescriptionExtractor()
    
    func extract(from recognizedText: String) async -> PrescriptionExtractionResult {
        let trimmedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return PrescriptionExtractionResult(
                medications: [],
                doctorName: nil,
                prescriptionDate: nil,
                source: .heuristic
            )
        }
        
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            
            if model.isAvailable {
                do {
                    let structured = try await extractWithFoundationModel(from: trimmedText, model: model)
                    if !structured.medications.isEmpty {
                        return structured
                    }
                } catch {
                    print("FoundationModels extraction failed: \(error)")
                }
            }
        }
        #endif
        
        return heuristicExtractor.extract(from: trimmedText)
    }
    
    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func extractWithFoundationModel(
        from text: String,
        model: SystemLanguageModel
    ) async throws -> PrescriptionExtractionResult {
        let instructions = """
        Eres un asistente para interpretar recetas medicas escritas en espanol.
        Extrae solo datos que esten presentes en el texto OCR.
        Si no hay dato, responde con cadena vacia.
        No inventes medicamentos, dosis ni frecuencias.
        """
        
        let prompt = """
        Analiza esta receta medica OCR y devuelve:
        - Nombre del doctor (doctorName)
        - Fecha de receta en formato yyyy-MM-dd (prescriptionDateISO8601)
        - Lista de medicamentos con nombre, dosis, frecuencia e instrucciones.
        
        Texto OCR:
        \(text)
        """
        
        let session = LanguageModelSession(model: model, instructions: instructions)
        let response = try await session.respond(to: prompt, generating: FoundationModelPrescriptionExtraction.self)
        let parsed = response.content
        
        let medications = parsed.medications
            .map { medication in
                ExtractedMedication(
                    name: normalized(medication.name),
                    dosage: nonEmptyOrFallback(normalized(medication.dosage), fallback: "Segun indicacion"),
                    frequency: nonEmptyOrFallback(normalized(medication.frequency), fallback: "Segun indicacion medica"),
                    instructions: nilIfEmpty(normalized(medication.instructions)),
                    duration: nilIfEmpty(normalized(medication.duration))
                )
            }
            .filter { !$0.name.isEmpty }
        
        return PrescriptionExtractionResult(
            medications: medications,
            doctorName: nilIfEmpty(normalized(parsed.doctorName)),
            prescriptionDate: parseDate(parsed.prescriptionDateISO8601),
            source: .appleIntelligence
        )
    }
    #endif
    
    private func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "•", with: "")
            .replacingOccurrences(of: "- ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func nilIfEmpty(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }
    
    private func nonEmptyOrFallback(_ value: String, fallback: String) -> String {
        value.isEmpty ? fallback : value
    }
    
    private func parseDate(_ rawValue: String) -> Date? {
        let cleaned = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        
        let formatters: [DateFormatter] = {
            let formats = ["yyyy-MM-dd", "dd/MM/yyyy", "dd-MM-yyyy", "yyyy/MM/dd"]
            return formats.map { format in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = format
                return formatter
            }
        }()
        
        for formatter in formatters {
            if let date = formatter.date(from: cleaned) {
                return date
            }
        }
        
        return nil
    }
}

private struct HeuristicPrescriptionExtractor {
    func extract(from text: String) -> PrescriptionExtractionResult {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var medications: [ExtractedMedication] = []
        var doctorName: String?
        var prescriptionDate: Date?
        
        let doctorPatterns = ["Dr\\.", "Dra\\.", "Doctor", "Doctora", "Medico", "Dr ", "Dra "]
        let datePatterns = ["\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}", "\\d{4}[/-]\\d{1,2}[/-]\\d{1,2}"]
        
        for line in lines {
            for pattern in doctorPatterns where line.range(of: pattern, options: .regularExpression) != nil {
                doctorName = line
                break
            }
            
            for pattern in datePatterns {
                guard let range = line.range(of: pattern, options: .regularExpression) else { continue }
                let dateString = String(line[range])
                if let parsedDate = parseDate(dateString) {
                    prescriptionDate = parsedDate
                    break
                }
            }
        }
        
        let medicationKeywords = [
            "mg", "ml", "tablet", "tableta", "capsula", "jarabe", "gotas",
            "inyectable", "comprimido", "cada", "horas", "dias", "vez", "veces", "tomar"
        ]
        
        var currentMedication: String?
        var currentDosage = ""
        var currentFrequency = ""
        var currentInstructions = ""
        
        for line in lines {
            let lowercased = line.lowercased()
            let hasMedicationKeyword = medicationKeywords.contains { lowercased.contains($0) }
            
            if hasMedicationKeyword {
                if let currentMedication, !currentDosage.isEmpty {
                    medications.append(ExtractedMedication(
                        name: currentMedication,
                        dosage: currentDosage,
                        frequency: nonEmptyOrFallback(currentFrequency, fallback: "Segun indicacion medica"),
                        instructions: nilIfEmpty(currentInstructions)
                    ))
                    currentDosage = ""
                    currentFrequency = ""
                    currentInstructions = ""
                }
                
                currentMedication = line
                
                if let mgRange = lowercased.range(of: #"\d+\s*mg"#, options: .regularExpression) {
                    currentDosage = String(lowercased[mgRange])
                } else if let mlRange = lowercased.range(of: #"\d+\s*ml"#, options: .regularExpression) {
                    currentDosage = String(lowercased[mlRange])
                }
                
                if let freqRange = lowercased.range(of: #"cada\s+\d+\s*(horas?|dias?)"#, options: .regularExpression) {
                    currentFrequency = String(lowercased[freqRange])
                } else if lowercased.contains("1 vez") || lowercased.contains("una vez") {
                    currentFrequency = "1 vez al dia"
                } else if lowercased.contains("2 veces") {
                    currentFrequency = "2 veces al dia"
                } else if lowercased.contains("3 veces") {
                    currentFrequency = "3 veces al dia"
                }
            } else if currentMedication != nil {
                currentInstructions += (currentInstructions.isEmpty ? "" : " ") + line
            }
        }
        
        if let med = currentMedication, !med.isEmpty {
            medications.append(ExtractedMedication(
                name: med,
                dosage: nonEmptyOrFallback(currentDosage, fallback: "Segun indicacion"),
                frequency: nonEmptyOrFallback(currentFrequency, fallback: "Segun indicacion medica"),
                instructions: nilIfEmpty(currentInstructions)
            ))
        }
        
        if medications.isEmpty {
            medications = fallbackMedications(from: text)
        }
        
        return PrescriptionExtractionResult(
            medications: medications,
            doctorName: doctorName,
            prescriptionDate: prescriptionDate,
            source: .heuristic
        )
    }
    
    private func fallbackMedications(from text: String) -> [ExtractedMedication] {
        var extracted: [ExtractedMedication] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var candidateName: String?
        
        for word in words {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            if cleaned.range(of: #"\d+\s*(mg|ml)"#, options: .regularExpression) != nil {
                if let candidateName {
                    extracted.append(ExtractedMedication(
                        name: candidateName,
                        dosage: cleaned,
                        frequency: "Segun indicacion medica"
                    ))
                }
                candidateName = nil
            } else if cleaned.count > 3, cleaned.first?.isUppercase == true {
                candidateName = cleaned
            }
        }
        
        return extracted
    }
    
    private func parseDate(_ rawValue: String) -> Date? {
        let formats = ["dd/MM/yyyy", "dd-MM-yyyy", "yyyy-MM-dd", "yyyy/MM/dd"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: rawValue) {
                return date
            }
        }
        return nil
    }
    
    private func nilIfEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private func nonEmptyOrFallback(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "Datos estructurados extraidos de una receta medica")
private struct FoundationModelPrescriptionExtraction {
    @Guide(description: "Nombre del doctor que firma la receta. Cadena vacia si no existe")
    var doctorName: String
    
    @Guide(description: "Fecha de la receta en formato yyyy-MM-dd. Cadena vacia si no existe")
    var prescriptionDateISO8601: String
    
    @Guide(description: "Lista de medicamentos indicados en la receta")
    var medications: [Medication]
    
    @Generable(description: "Medicamento recetado")
    struct Medication {
        @Guide(description: "Nombre del medicamento")
        var name: String
        
        @Guide(description: "Dosis exacta, por ejemplo 500 mg o 10 ml")
        var dosage: String
        
        @Guide(description: "Frecuencia de toma, por ejemplo cada 8 horas")
        var frequency: String
        
        @Guide(description: "Indicaciones adicionales de uso. Cadena vacia si no existe")
        var instructions: String
        
        @Guide(description: "Duracion del tratamiento. Cadena vacia si no existe")
        var duration: String
    }
}
#endif
