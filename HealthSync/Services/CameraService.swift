import SwiftUI
import Vision
import VisionKit
import PhotosUI

@MainActor
class CameraService: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    private let prescriptionIntelligenceService = PrescriptionIntelligenceService()
    
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
        
        let extractedData = await prescriptionIntelligenceService.extract(from: recognizedText)
        let confidence = extractedData.source == .appleIntelligence ? 0.95 : 0.8
        
        return ScanResult(
            recognizedText: recognizedText,
            confidence: confidence,
            medications: extractedData.medications,
            doctorName: extractedData.doctorName,
            prescriptionDate: extractedData.prescriptionDate,
            extractionSource: extractedData.source
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
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [parent] object, _ in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        parent.image = image
                    }
                }
            }
        }
    }
}
