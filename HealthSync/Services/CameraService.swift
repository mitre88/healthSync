import SwiftUI
import Vision
import VisionKit
import CoreImage
import PhotosUI

@MainActor
class CameraService: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    func processImage(_ image: UIImage) async -> ScanResult? {
        isProcessing = true
        errorMessage = nil
        
        defer { isProcessing = false }
        
        guard let cgImage = image.cgImage else {
            errorMessage = "No se pudo procesar la imagen"
            return nil
        }
        
        let recognizedText = await recognizeText(from: cgImage)
        
        guard !recognizedText.isEmpty else {
            errorMessage = "No se pudo detectar texto en la imagen"
            return nil
        }
        
        let extractedData = extractMedicationData(from: recognizedText)
        
        return ScanResult(
            recognizedText: recognizedText,
            confidence: 0.85,
            medications: extractedData.medications,
            doctorName: extractedData.doctorName,
            prescriptionDate: extractedData.prescriptionDate
        )
    }
    
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
            
            request.recognitionLanguages = ["es-ES", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    
    private func extractMedicationData(from text: String) -> (medications: [ExtractedMedication], doctorName: String?, prescriptionDate: Date?) {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        var medications: [ExtractedMedication] = []
        var doctorName: String?
        var prescriptionDate: Date?
        
        let doctorPatterns = ["Dr\\.", "Dra\\.", "Doctor", "Doctora", "Médico", "Dr ", "Dra "]
        let datePatterns = ["\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}", "\\d{1,2}\\s+de\\s+\\w+\\s+de\\s+\\d{4}"]
        
        for line in lines {
            for pattern in doctorPatterns {
                if line.range(of: pattern, options: .regularExpression) != nil {
                    doctorName = line
                    break
                }
            }
            
            for pattern in datePatterns {
                if let range = line.range(of: pattern, options: .regularExpression),
                   doctorName == nil || !line.contains(doctorName ?? "") {
                    let dateStr = String(line[range])
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd/MM/yyyy"
                    if let date = formatter.date(from: dateStr) {
                        prescriptionDate = date
                    } else {
                        formatter.dateFormat = "dd-MM-yyyy"
                        prescriptionDate = formatter.date(from: dateStr)
                    }
                }
            }
        }
        
        let medicationKeywords = ["mg", "ml", "tablet", "tableta", "cápsula", "capsula", "jarabe", "gotas", "inyectable", "comprimido", "cada", "horas", "días", "vez", "veces", "oral", "tomar"]
        
        var currentMedication: String?
        var currentDosage: String = ""
        var currentFrequency: String = ""
        var currentInstructions: String = ""
        
        for line in lines {
            let lowercased = line.lowercased()
            let hasMedicationKeyword = medicationKeywords.contains { lowercased.contains($0) }
            
            if hasMedicationKeyword {
                if currentMedication != nil && !currentDosage.isEmpty {
                    medications.append(ExtractedMedication(
                        name: currentMedication ?? "Medicamento",
                        dosage: currentDosage,
                        frequency: currentFrequency,
                        instructions: currentInstructions.isEmpty ? nil : currentInstructions
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
                
                if lowercased.contains("cada") {
                    if let freqRange = lowercased.range(of: #"cada\s+\d+\s*(horas?|días?)"#, options: .regularExpression) {
                        currentFrequency = String(lowercased[freqRange])
                    }
                }
                
                if lowercased.contains("vez") || lowercased.contains("veces") {
                    if lowercased.contains("1 vez") { currentFrequency = "1 vez al día" }
                    else if lowercased.contains("2 veces") { currentFrequency = "2 veces al día" }
                    else if lowercased.contains("3 veces") { currentFrequency = "3 veces al día" }
                }
                
            } else if currentMedication != nil {
                currentInstructions += (currentInstructions.isEmpty ? "" : " ") + line
            }
        }
        
        if let med = currentMedication, !med.isEmpty {
            medications.append(ExtractedMedication(
                name: med,
                dosage: currentDosage.isEmpty ? "Según indicación" : currentDosage,
                frequency: currentFrequency.isEmpty ? "Según indicación médica" : currentFrequency,
                instructions: currentInstructions.isEmpty ? nil : currentInstructions
            ))
        }
        
        if medications.isEmpty {
            let words = text.components(separatedBy: .whitespacesAndNewlines)
            var tempMed: String?
            
            for word in words {
                if word.range(of: #"\d+\s*(mg|ml)"#, options: .regularExpression) != nil {
                    if let med = tempMed {
                        medications.append(ExtractedMedication(
                            name: med,
                            dosage: word,
                            frequency: "Según indicación médica"
                        ))
                    }
                    tempMed = nil
                } else if word.count > 3 && word.first?.isUppercase == true {
                    tempMed = word
                }
            }
        }
        
        return (medications, doctorName, prescriptionDate)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self?.parent.image = image
                    }
                }
            }
        }
    }
}
