import SwiftUI
import Vision
import VisionKit
import CoreImage
import PhotosUI
import Foundation

// MARK: - Foundation Models Integration (iOS 26)

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
    private let prescriptionIntelligenceService = PrescriptionIntelligenceService()
    
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
        
        // Step 2: Extract with PrescriptionIntelligenceService (Foundation Models + regex fallback)
        processingStage = .analyzing
        let extractedData = await prescriptionIntelligenceService.extract(from: recognizedText)
        
        guard !extractedData.medications.isEmpty else {
            errorMessage = "No se pudieron identificar medicamentos. Intenta con una foto más clara de la receta."
            return nil
        }
        
        // Step 3: Check for drug interactions
        processingStage = .validating
        let interactions = drugInteractionChecker.checkInteractions(extractedData.medications)
        
        let confidence = extractedData.source == .appleIntelligence ? 0.95 : calculateConfidence(for: extractedData.medications)
        
        return ScanResult(
            recognizedText: recognizedText,
            confidence: confidence,
            medications: extractedData.medications,
            doctorName: extractedData.doctorName,
            prescriptionDate: extractedData.prescriptionDate,
            drugInteractions: interactions,
            extractionSource: extractedData.source
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
    
    // MARK: - Helper Methods
    
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

// MARK: - Image Picker

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
