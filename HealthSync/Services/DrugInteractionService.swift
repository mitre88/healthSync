import Foundation

// MARK: - Drug Interaction Checker

class DrugInteractionChecker {
    
    struct Interaction: Identifiable {
        let id = UUID()
        let drug1: String
        let drug2: String
        let severity: Severity
        let description: String
        let recommendation: String
        
        enum Severity: String, CaseIterable {
            case minor = "Menor"
            case moderate = "Moderada"
            case major = "Mayor"
            case contraindicated = "Contraindicada"
            
            var color: String {
                switch self {
                case .minor: return "yellow"
                case .moderate: return "orange"
                case .major: return "red"
                case .contraindicated: return "purple"
                }
            }
            
            var icon: String {
                switch self {
                case .minor: return "info.circle"
                case .moderate: return "exclamationmark.triangle"
                case .major: return "exclamationmark.octagon"
                case .contraindicated: return "xmark.octagon"
                }
            }
        }
    }
    
    // Known drug interactions database (simplified)
    private let interactions: [(drugs: [String], severity: Interaction.Severity, description: String, recommendation: String)] = [
        // Psiquiátricos - Ejemplos basados en los que tomas
        (
            ["escitalopram", "mirtazapina"],
            .moderate,
            "Ambos son antidepresivos. Puede aumentar el riesgo de síndrome serotoninérgico.",
            "Monitorear síntomas. Consultar con el psiquiatra si hay agitación, confusión o fiebre."
        ),
        (
            ["escitalopram", "pregabalina"],
            .minor,
            "Puede aumentar ligeramente los efectos sedantes.",
            "Evitar conducir hasta conocer los efectos. No suspender sin consultar."
        ),
        (
            ["mirtazapina", "pregabalina"],
            .moderate,
            "Aumento significativo de sedación y somnolencia.",
            "Tomar antes de dormir. Evitar alcohol. Informar al médico si hay exceso de sueño."
        ),
        // Interacciones comunes
        (
            ["warfarina", "aspirina"],
            .major,
            "Aumento del riesgo de sangrado.",
            "Requiere monitoreo cercano del INR. Consultar al médico inmediatamente."
        ),
        (
            ["metformina", "alcohol"],
            .moderate,
            "Riesgo de acidosis láctica.",
            "Limitar consumo de alcohol. Informar al médico sobre hábitos de consumo."
        ),
        (
            ["ibuprofeno", "aspirina"],
            .minor,
            "El ibuprofeno puede reducir el efecto cardioprotector de la aspirina.",
            "Espaciar la toma o considerar alternativas. Consultar al médico."
        ),
        (
            ["fluoxetina", "tramadol"],
            .major,
            "Alto riesgo de síndrome serotoninérgico.",
            "EVITAR esta combinación. Buscar atención médica inmediata si hay síntomas."
        ),
        (
            ["clonazepam", "alcohol"],
            .major,
            "Depresión severa del sistema nervioso central.",
            "NO combinar con alcohol. Riesgo de coma o paro respiratorio."
        )
    ]
    
    func checkInteractions(_ medications: [ExtractedMedication]) -> [Interaction] {
        var foundInteractions: [Interaction] = []
        let medicationNames = medications.map { $0.name.lowercased() }
        
        for interaction in interactions {
            let drugsInInteraction = interaction.drugs
            let matchingDrugs = medicationNames.filter { medName in
                drugsInInteraction.contains { interactionDrug in
                    medName.contains(interactionDrug.lowercased())
                }
            }
            
            // If 2 or more drugs from the interaction are present
            if matchingDrugs.count >= 2 {
                foundInteractions.append(Interaction(
                    drug1: matchingDrugs[0].capitalized,
                    drug2: matchingDrugs[1].capitalized,
                    severity: interaction.severity,
                    description: interaction.description,
                    recommendation: interaction.recommendation
                ))
            }
        }
        
        return foundInteractions.sorted { $0.severity.rawValue > $1.severity.rawValue }
    }
    
    func checkInteractionsWithUserMedications(
        newMedications: [ExtractedMedication],
        userMedications: [Medication]
    ) -> [Interaction] {
        let allMedications = newMedications + userMedications.map {
            ExtractedMedication(
                name: $0.name,
                dosage: $0.dosage,
                frequency: $0.frequency,
                instructions: nil
            )
        }
        return checkInteractions(allMedications)
    }
}

// MARK: - Validation Service

class MedicationValidator {
    
    struct ValidationError: Identifiable {
        let id = UUID()
        let field: String
        let message: String
        let severity: ErrorSeverity
        
        enum ErrorSeverity {
            case warning
            case error
        }
    }
    
    func validate(_ medication: Medication) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Validate name
        if medication.name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(ValidationError(
                field: "nombre",
                message: "El nombre del medicamento es obligatorio",
                severity: .error
            ))
        }
        
        // Validate dosage
        if medication.dosage.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(ValidationError(
                field: "dosis",
                message: "La dosis es obligatoria",
                severity: .error
            ))
        }
        
        // Validate times
        if medication.times.isEmpty {
            errors.append(ValidationError(
                field: "horarios",
                message: "Debe configurar al menos un horario",
                severity: .error
            ))
        }
        
        // Validate dates
        if let endDate = medication.endDate {
            if endDate < medication.startDate {
                errors.append(ValidationError(
                    field: "fechas",
                    message: "La fecha de fin no puede ser anterior a la fecha de inicio",
                    severity: .error
                ))
            }
            
            // Warning if medication is expired
            if endDate < Date() {
                errors.append(ValidationError(
                    field: "vencimiento",
                    message: "Este medicamento ha vencido",
                    severity: .warning
                ))
            }
        }
        
        // Warning if more than 5 doses per day
        if medication.times.count > 5 {
            errors.append(ValidationError(
                field: "frecuencia",
                message: "Más de 5 tomas al día. Verificar con el médico.",
                severity: .warning
            ))
        }
        
        return errors
    }
    
    func validatePrescriptionDate(_ date: Date?) -> ValidationError? {
        guard let date = date else { return nil }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let prescriptionDay = calendar.startOfDay(for: date)
        
        // Check if date is in the future
        if prescriptionDay > today {
            return ValidationError(
                field: "fecha",
                message: "La fecha de la receta está en el futuro",
                severity: .error
            )
        }
        
        // Warning if prescription is older than 6 months
        if let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: today),
           prescriptionDay < sixMonthsAgo {
            return ValidationError(
                field: "fecha",
                message: "La receta tiene más de 6 meses. Considerar renovar.",
                severity: .warning
            )
        }
        
        return nil
    }
}

// MARK: - Dosage Parser

class DosageParser {
    
    struct ParsedDosage {
        let amount: Double
        let unit: String
        let formatted: String
    }
    
    func parse(_ dosageString: String) -> ParsedDosage? {
        let pattern = #"(\d+(?:\.\d+)?)\s*(mg|ml|mcg|UI|g|gr|mg/ml|ml/hora)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: dosageString, options: [], range: NSRange(location: 0, length: dosageString.utf16.count)) else {
            return nil
        }
        
        guard let amountRange = Range(match.range(at: 1), in: dosageString),
              let unitRange = Range(match.range(at: 2), in: dosageString),
              let amount = Double(String(dosageString[amountRange])) else {
            return nil
        }
        
        return ParsedDosage(
            amount: amount,
            unit: String(dosageString[unitRange]).lowercased(),
            formatted: "\(amount) \(String(dosageString[unitRange]))"
        )
    }
    
    func normalizeFrequency(_ frequency: String) -> String {
        let lowercased = frequency.lowercased()
        
        // Spanish patterns
        if lowercased.contains("cada 24") || lowercased.contains("1 vez") || lowercased.contains("once") {
            return "1 vez al día"
        } else if lowercased.contains("cada 12") || lowercased.contains("2 veces") || lowercased.contains("twice") {
            return "2 veces al día"
        } else if lowercased.contains("cada 8") || lowercased.contains("3 veces") || lowercased.contains("three times") {
            return "3 veces al día"
        } else if lowercased.contains("cada 6") || lowercased.contains("4 veces") {
            return "4 veces al día"
        } else if lowercased.contains("cada 4") || lowercased.contains("6 veces") {
            return "6 veces al día"
        }
        
        // English patterns
        if lowercased.contains("daily") || lowercased.contains("every day") {
            return "1 vez al día"
        } else if lowercased.contains("bid") || lowercased.contains("b.i.d") {
            return "2 veces al día"
        } else if lowercased.contains("tid") || lowercased.contains("t.i.d") {
            return "3 veces al día"
        } else if lowercased.contains("qid") || lowercased.contains("q.i.d") {
            return "4 veces al día"
        }
        
        return frequency
    }
    
    func generateTimes(from frequency: String, startTime: Date = Date()) -> [Date] {
        let normalized = normalizeFrequency(frequency)
        let calendar = Calendar.current
        
        var times: [Date] = []
        
        switch normalized {
        case "1 vez al día":
            times = [calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startTime)!]
            
        case "2 veces al día":
            times = [
                calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startTime)!,
                calendar.date(bySettingHour: 20, minute: 0, second: 0, of: startTime)!
            ]
            
        case "3 veces al día":
            times = [
                calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startTime)!,
                calendar.date(bySettingHour: 14, minute: 0, second: 0, of: startTime)!,
                calendar.date(bySettingHour: 20, minute: 0, second: 0, of: startTime)!
            ]
            
        case "4 veces al día":
            times = [
                calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startTime)!,
                calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startTime)!,
                calendar.date(bySettingHour: 16, minute: 0, second: 0, of: startTime)!,
                calendar.date(bySettingHour: 20, minute: 0, second: 0, of: startTime)!
            ]
            
        case "6 veces al día":
            times = [
                calendar.date(bySettingHour: 6, minute: 0, second: 0, of: startTime)!,
                calendar.date(bySettingHour: 10, minute: 0, second: 0, of: startTime)!,
                calendar.date(bySettingHour: 14, minute: 0, second: 0, of: startTime)!,
                calendar.date(bySettingHour: 18, minute: 0, second: 0, of: startTime)!,
                calendar.date(bySettingHour: 22, minute: 0, second: 0, of: startTime)!,
                calendar.date(bySettingHour: 2, minute: 0, second: 0, of: startTime)!
            ]
            
        default:
            // Default to morning
            times = [calendar.date(bySettingHour: 8, minute: 0, second: 0, of: startTime)!]
        }
        
        return times
    }
}
