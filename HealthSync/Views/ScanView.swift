import SwiftUI

struct ScanView: View {
    @EnvironmentObject private var medicationStore: MedicationStore
    @EnvironmentObject private var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showPhotoPicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    @State private var isAnalyzing = false
    @State private var scanResult: ScanResult?
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    private let cameraService = CameraService()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if selectedImage == nil {
                        imageSelectionSection
                    } else if isAnalyzing {
                        analyzingSection
                    } else if let result = scanResult {
                        resultsSection(result)
                    }
                }
                .padding()
            }
            .navigationTitle("Escanear Receta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                if selectedImage != nil && scanResult == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Limpiar") {
                            selectedImage = nil
                            scanResult = nil
                        }
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: $sourceType)
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker(image: $selectedImage)
            }
            .onChange(of: selectedImage) { _, newValue in
                if let image = newValue {
                    Task {
                        await analyzeImage(image)
                    }
                }
            }
            .alert("Éxito", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Los medicamentos se han añadido correctamente")
            }
            .alert(
                "No se pudo analizar la receta",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { show in
                        if !show { errorMessage = nil }
                    }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Intenta con una imagen mas clara.")
            }
        }
    }
    
    private var imageSelectionSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 60))
                    .foregroundStyle(.teal)
                
                Text("Escanea tu receta médica")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Usa la cámara para escanear una receta médica. La IA extraerá automáticamente los medicamentos.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 40)
            
            VStack(spacing: 12) {
                Button {
                    sourceType = .camera
                    showImagePicker = true
                } label: {
                    Label("Usar Cámara", systemImage: "camera.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Seleccionar de Galería", systemImage: "photo.fill")
                        .font(.headline)
                        .foregroundStyle(.teal)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.teal.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var analyzingSection: some View {
        VStack(spacing: 24) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.teal)
                
                Text("Analizando receta...")
                    .font(.headline)
                
                Text("La IA está extrayendo la información de los medicamentos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 20)
        }
    }
    
    private func resultsSection(_ result: ScanResult) -> some View {
        VStack(spacing: 20) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                    
                    Text("Receta Analizada")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(result.medications.count) medicamentos")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.teal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.teal.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                HStack(spacing: 8) {
                    Image(systemName: result.extractionSource == .appleIntelligence ? "sparkles" : "text.viewfinder")
                        .foregroundStyle(result.extractionSource == .appleIntelligence ? .indigo : .orange)
                    Text(result.extractionSource.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(result.extractionSource == .appleIntelligence ? .indigo : .orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((result.extractionSource == .appleIntelligence ? Color.indigo : Color.orange).opacity(0.12))
                .clipShape(Capsule())
                
                if result.extractionSource == .heuristic {
                    Text("Apple Intelligence no esta disponible en este momento. Se uso analisis local.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let doctor = result.doctorName, !doctor.isEmpty {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading) {
                            Text("Doctor")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(doctor)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                if let date = result.prescriptionDate {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading) {
                            Text("Fecha de Receta")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                Divider()
                
                Text("Medicamentos Detectados")
                    .font(.headline)
                
                if result.medications.isEmpty {
                    Text("No se detectaron medicamentos validos. Prueba con otra foto.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(result.medications) { med in
                        ExtractedMedicationCard(medication: med)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Button {
                saveMedications(from: result)
            } label: {
                Text("Guardar Medicamentos")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(result.medications.isEmpty)
            .opacity(result.medications.isEmpty ? 0.5 : 1)
            
            Button {
                selectedImage = nil
                scanResult = nil
            } label: {
                Text("Escanear Otra Receta")
                    .font(.subheadline)
                    .foregroundStyle(.teal)
            }
        }
    }
    
    @MainActor
    private func analyzeImage(_ image: UIImage) async {
        isAnalyzing = true
        
        if !notificationService.isAuthorized {
            _ = await notificationService.requestAuthorization()
        }
        
        let result = await cameraService.processImage(image)
        
        isAnalyzing = false
        
        if let result = result {
            scanResult = result
        } else {
            errorMessage = cameraService.errorMessage
        }
    }
    
    @MainActor
    private func saveMedications(from result: ScanResult) {
        let calendar = Calendar.current
        let notificationsEnabled = medicationStore.userProfile?.notificationsEnabled ?? true
        
        for extractedMed in result.medications {
            var times: [Date] = []
            
            let freq = extractedMed.frequency.lowercased()
            if freq.contains("8 horas") || freq.contains("cada 8") {
                times = [
                    calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!,
                    calendar.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!,
                    calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
                ]
            } else if freq.contains("12 horas") || freq.contains("cada 12") {
                times = [
                    calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!,
                    calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
                ]
            } else if freq.contains("1 vez") || freq.contains("una vez") {
                times = [calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!]
            } else if freq.contains("2 veces") {
                times = [
                    calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!,
                    calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
                ]
            } else if freq.contains("3 veces") {
                times = [
                    calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!,
                    calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!,
                    calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
                ]
            } else {
                times = [calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!]
            }
            
            let medication = Medication(
                name: extractedMed.name,
                dosage: extractedMed.dosage,
                frequency: extractedMed.frequency,
                instructions: extractedMed.instructions ?? "",
                times: times,
                doctorName: result.doctorName ?? "",
                prescriptionDate: result.prescriptionDate
            )
            
            medicationStore.addMedication(medication)
            
            Task {
                guard notificationsEnabled else { return }
                await notificationService.scheduleMedicationReminder(
                    for: medication,
                    reminderMinutesBefore: medicationStore.userProfile?.reminderMinutesBefore ?? 0
                )
            }
        }
        
        showSuccess = true
    }
}

struct ExtractedMedicationCard: View {
    let medication: ExtractedMedication
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(.teal.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "pills.fill")
                            .font(.caption)
                            .foregroundStyle(.teal)
                    }
                
                Text(medication.name)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
            }
            
            HStack {
                Label(medication.dosage, systemImage: "scalemass.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Label(medication.frequency, systemImage: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(.teal)
            }
            
            if let instructions = medication.instructions, !instructions.isEmpty {
                Text(instructions)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ScanView()
        .environmentObject(MedicationStore())
        .environmentObject(NotificationService())
}
