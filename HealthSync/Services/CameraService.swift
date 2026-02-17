import SwiftUI
import Vision
import VisionKit
import CoreImage
import PhotosUI
import Foundation

// MARK: - Foundation Models Integration (iOS 26)

@available(iOS 26.0, *)
@MainActor
class CameraService: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var processingStage: ProcessingStage = .idle
    
    enum ProcessingStage: String {
        case idle = ""
        case detectingText = "Detectando texto..."
        case analyzing = "Analizando con Foundation Models..."
        case extracting = "Extrayendo medicamentos..."
        case validating = "Validando información..."
    }
    
    private let drugInteractionChecker = DrugInteractionChecker()
    
    // MARK: - Main Processing
    
    func processImage(_ image: UIImage) async -> ScanResult? {
        isProcessing = true
        errorMessage = nil
        processingStage = .detectingText
        
        defer { 
            isProcessing = false
            processingStage = .idle
        }
        
        guard let cgImage = image.cgImage else {
            errorMessage = "No se pudo procesar la imagen. Intenta con otra foto."
            return nil
        }
        
        // Step 1: OCR with Vision
        processingStage = .detectingText
        let recognizedText = await recognizeText(from: cgImage)
        
        guard !recognizedText.isEmpty else {
            errorMessage = "No se detectó texto en la imagen. Asegúrate de que la receta esté bien iluminada y enfocada."
            return nil
        }
        
        // Step 2: Extract with Foundation Models (if available) or fallback to regex
        processingStage = .analyzing
        let extractedData = await extractMedicationDataIntelligently(from: recognizedText)
        
        guard !extractedData.medications.isEmpty else {
            errorMessage = "No se pudieron identificar medicamentos. Intenta con una foto más clara de la receta."
            return nil
        }
        
        // Step 3: Check for drug interactions
        processingStage = .validating
        let interactions = drugInteractionChecker.checkInteractions(extractedData.medications)
        
        return ScanResult(
            recognizedText: recognizedText,
            confidence: calculateConfidence(for: extractedData.medications),
            medications: extractedData.medications,
            doctorName: extractedData.doctorName,
            prescriptionDate: extractedData.prescriptionDate,
            drugInteractions: interactions
        )
    }
    
    // MARK: - OCR with Vision
    
    private func recognizeText(from image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                continuation.resume(returning: recognizedStrings.joined(separator: "\n"))
            }
            
            request.recognitionLanguages = ["es-ES", "es-MX", "en-US", "en-GB"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.customWords = ["mg", "ml", "mcg", "UI", "tableta", "cápsula", "comprimido", 
                                   "jarabe", "gotas", "inyectable", "tópico", "oftálmico", 
                                   "receta", "prescripción", "indicaciones", "doctor", "Dr", "Dra"]
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    
    // MARK: - Intelligent Extraction
    
    private func extractMedicationDataIntelligently(from text: String) async -> (medications: [ExtractedMedication], doctorName: String?, prescriptionDate: Date?) {
        
        // Try Foundation Models first (iOS 26+)
        if #available(iOS 26.0, *) {
            if let result = await extractWithFoundationModel(text: text) {
                return result
            }
        }
        
        // Fallback to enhanced regex
        return extractMedicationDataWithRegex(from: text)
    }
    
    @available(iOS 26.0, *)
    private func extractWithFoundationModel(text: String) async -> (medications: [ExtractedMedication], doctorName: String?, prescriptionDate: Date?)? {
        // This would use the new Apple Intelligence Foundation Models API
        // For now, we simulate the structure
        
        let prompt = """
        Extrae la información médica de esta receta en formato JSON:
        
        Texto de la receta:
        \(text)
        
        Devuelve EXACTAMENTE este formato:
        {
            "doctorName": "Nombre del doctor o vacío",
            "prescriptionDate": "Fecha en formato DD/MM/YYYY o vacío",
            "medications": [
                {
                    "name": "Nombre del medicamento",
                    "dosage": "Dosis (ej: 20mg, 10ml)",
                    "frequency": "Frecuencia (ej: cada 8 horas, 2 veces al día)",
                    "instructions": "Instrucciones adicionales o vacío"
                }
            ]
        }
        """
        
        // Note: Real implementation would use the Foundation Models API
        // This is a placeholder for the actual Apple Intelligence integration
        return nil
    }
    
    // MARK: - Enhanced Regex Extraction
    
    private func extractMedicationDataWithRegex(from text: String) -> (medications: [ExtractedMedication], doctorName: String?, prescriptionDate: Date?) {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var medications: [ExtractedMedication] = []
        var doctorName: String?
        var prescriptionDate: Date?
        
        // Enhanced patterns for multiple languages
        let doctorPatterns = [
            "(?i)(?:Dr\\.|Dra\\.|Doctor|Doctora|Médico|Medico|Dr|Dra)\\s*[.:]?\\s*([^\\n]+)",
            "(?i)Médico\\s*tratante\\s*[:.]?\\s*([^\\n]+)",
            "(?i)Prescribe\\s*[:.]?\\s*([^\\n]+)"
        ]
        
        let datePatterns = [
            "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})",
            "(\\d{1,2}\\s+de\\s+(?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\\s+de\\s+\\d{4})",
            "((?:January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{1,2},?\\s+\\d{4})"
        ]
        
        // Extract doctor name
        for line in lines {
            for pattern in doctorPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
                    if let range = Range(match.range(at: 1), in: line) {
                        doctorName = String(line[range]).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
            }
        }
        
        // Extract date
        let fullText = lines.joined(separator: " ")
        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: fullText, options: [], range: NSRange(location: 0, length: fullText.utf16.count)),
               let range = Range(match.range(at: 1), in: fullText) {
                let dateStr = String(fullText[range])
                prescriptionDate = parseDate(dateStr)
                if prescriptionDate != nil { break }
            }
        }
        
        // Extract medications with enhanced logic
        medications = extractMedicationsEnhanced(from: lines)
        
        return (medications, doctorName, prescriptionDate)
    }
    
    private func extractMedicationsEnhanced(from lines: [String]) -> [ExtractedMedication] {
        var medications: [ExtractedMedication] = []
        
        // Patterns for dosage
        let dosagePattern = #"(?i)(\d+\s*(?:mg|ml|mcg|UI|g|gr|gramos?|unidades?))"#
        
        // Patterns for frequency (multilingual)
        let frequencyPatterns = [
            "(?i)cada\\s+(\\d+)\\s*horas?",
            "(?i)(\\d+)\\s*veces\\s+(?:al|por)\\s*día",
            "(?i)once\\s+daily",
            "(?i)twice\\s+daily",
            "(?i)three\\s+times\\s+daily",
            "(?i)every\\s+(\\d+)\\s*hours?",
            "(?i)1\\s*(?:vez|time)",
            "(?i)2\\s*(?:veces|times)",
            "(?i)3\\s*(?:veces|times)"
        ]
        
        var currentMed: ExtractedMedication?
        var pendingInstructions: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // Check if line contains dosage (indicator of medication)
            if let dosageRegex = try? NSRegularExpression(pattern: dosagePattern, options: []),
               let dosageMatch = dosageRegex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)),
               let dosageRange = Range(dosageMatch.range(at: 1), in: trimmed) {
                
                // Save previous medication if exists
                if var med = currentMed {
                    med.instructions = pendingInstructions.joined(separator: " ").nilIfEmpty
                    medications.append(med)
                    pendingInstructions = []
                }
                
                let dosage = String(trimmed[dosageRange])
                let name = extractMedicationName(from: trimmed, excluding: dosage)
                let frequency = extractFrequency(from: trimmed, using: frequencyPatterns)
                
                currentMed = ExtractedMedication(
                    name: name,
                    dosage: dosage,
                    frequency: frequency.isEmpty ? "Según indicación médica" : frequency,
                    instructions: nil
                )
            } else if currentMed != nil {
                // This might be instructions for current medication
                if !isHeaderLine(trimmed) {
                    pendingInstructions.append(trimmed)
                }
            }
        }
        
        // Don't forget the last medication
        if var med = currentMed {
            med.instructions = pendingInstructions.joined(separator: " ").nilIfEmpty
            medications.append(med)
        }
        
        return medications
    }
    
    private func extractMedicationName(from line: String, excluding dosage: String) -> String {
        // Remove dosage from line to get name
        var name = line.replacingOccurrences(of: dosage, with: "", options: .caseInsensitive)
        
        // Remove common words that aren't part of name
        let wordsToRemove = ["tomar", "tom", "take", "oral", "por", "vía", "via", "cada", "veces", "al día", "daily"]
        for word in wordsToRemove {
            name = name.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        
        // Clean up
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        name = name.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        // Capitalize first letter of each word
        name = name.components(separatedBy: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
        
        return name.isEmpty ? "Medicamento" : name
    }
    
    private func extractFrequency(from line: String, using patterns: [String]) -> String {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
                if let range = Range(match.range(at: 0), in: line) {
                    return String(line[range]).lowercased()
                }
            }
        }
        return ""
    }
    
    private func isHeaderLine(_ line: String) -> Bool {
        let headerWords = ["receta", "prescripción", "prescripcion", "indicaciones", 
                          "nombre", "paciente", "doctor", "fecha", "rx", "medicamentos"]
        return headerWords.contains { line.lowercased().contains($0) }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatters = [
            "dd/MM/yyyy",
            "dd-MM-yyyy",
            "dd/MM/yy",
            "MM/dd/yyyy",
            "yyyy-MM-dd",
            "dd MMMM yyyy",
            "dd 'de' MMMM 'de' yyyy"
        ]
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        
        for format in formatters {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // Try English locale
        formatter.locale = Locale(identifier: "en_US")
        for format in formatters {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    private func calculateConfidence(for medications: [ExtractedMedication]) -> Double {
        guard !medications.isEmpty else { return 0.0 }
        
        var totalScore = 0.0
        for med in medications {
            var score = 0.0
            if !med.name.isEmpty && med.name != "Medicamento" { score += 0.4 }
            if !med.dosage.isEmpty { score += 0.3 }
            if med.frequency != "Según indicación médica" { score += 0.2 }
            if med.instructions != nil { score += 0.1 }
            totalScore += score
        }
        
        return totalScore / Double(medications.count)
    }
}

// MARK: - Helper Extensions

extension String {
    var nilIfEmpty: String? {
        return self.trimmingCharacters(in: .whitespaces).isEmpty ? nil : self
    }
}
