//
//  MEDEVACModels.swift
//  OmniTAKMobile
//
//  Models for 9-Line MEDEVAC Request
//

import Foundation
import CoreLocation

// MARK: - MEDEVAC Request Model

struct MEDEVACRequest: Identifiable, Codable {
    let id: String
    var timestamp: Date

    // Line 1: Location
    var locationGrid: String           // MGRS grid coordinates
    var locationLat: Double?
    var locationLon: Double?

    // Line 2: Radio frequency, call sign, suffix
    var radioFrequency: String
    var callSign: String
    var callSignSuffix: String

    // Line 3: Number of patients by precedence
    var urgentPatients: Int            // A - Urgent (surgical)
    var priorityPatients: Int          // B - Priority
    var routinePatients: Int           // C - Routine
    var conveniencePatients: Int       // D - Convenience

    // Line 4: Special equipment required
    var specialEquipment: SpecialEquipment

    // Line 5: Number of patients by type
    var litterPatients: Int            // L - Litter
    var ambulatoryPatients: Int        // A - Ambulatory

    // Line 6: Security at pickup site
    var pickupSiteSecurity: PickupSiteSecurity

    // Line 7: Method of marking pickup site
    var markingMethod: MarkingMethod

    // Line 8: Patient nationality and status
    var patientNationality: PatientNationality

    // Line 9: CBRN Contamination
    var cbrnContamination: CBRNContamination

    // Optional additional info
    var remarks: String
    var senderUID: String
    var senderCallsign: String

    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        locationGrid: String = "",
        locationLat: Double? = nil,
        locationLon: Double? = nil,
        radioFrequency: String = "",
        callSign: String = "",
        callSignSuffix: String = "",
        urgentPatients: Int = 0,
        priorityPatients: Int = 0,
        routinePatients: Int = 0,
        conveniencePatients: Int = 0,
        specialEquipment: SpecialEquipment = .none,
        litterPatients: Int = 0,
        ambulatoryPatients: Int = 0,
        pickupSiteSecurity: PickupSiteSecurity = .noEnemy,
        markingMethod: MarkingMethod = .none,
        patientNationality: PatientNationality = .usMilitary,
        cbrnContamination: CBRNContamination = .none,
        remarks: String = "",
        senderUID: String = "",
        senderCallsign: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.locationGrid = locationGrid
        self.locationLat = locationLat
        self.locationLon = locationLon
        self.radioFrequency = radioFrequency
        self.callSign = callSign
        self.callSignSuffix = callSignSuffix
        self.urgentPatients = urgentPatients
        self.priorityPatients = priorityPatients
        self.routinePatients = routinePatients
        self.conveniencePatients = conveniencePatients
        self.specialEquipment = specialEquipment
        self.litterPatients = litterPatients
        self.ambulatoryPatients = ambulatoryPatients
        self.pickupSiteSecurity = pickupSiteSecurity
        self.markingMethod = markingMethod
        self.patientNationality = patientNationality
        self.cbrnContamination = cbrnContamination
        self.remarks = remarks
        self.senderUID = senderUID
        self.senderCallsign = senderCallsign
    }

    var totalPatients: Int {
        urgentPatients + priorityPatients + routinePatients + conveniencePatients
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddHHmmZMMMyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: timestamp).uppercased()
    }

    var nineLineText: String {
        """
        9-LINE MEDEVAC REQUEST
        DTG: \(formattedTimestamp)

        LINE 1 - LOCATION: \(locationGrid)
        LINE 2 - FREQ/CALLSIGN: \(radioFrequency) / \(callSign)\(callSignSuffix.isEmpty ? "" : "-" + callSignSuffix)
        LINE 3 - PATIENTS BY PRECEDENCE:
            A-URGENT: \(urgentPatients)
            B-PRIORITY: \(priorityPatients)
            C-ROUTINE: \(routinePatients)
            D-CONVENIENCE: \(conveniencePatients)
        LINE 4 - SPECIAL EQUIPMENT: \(specialEquipment.code) - \(specialEquipment.displayName)
        LINE 5 - PATIENTS BY TYPE:
            L-LITTER: \(litterPatients)
            A-AMBULATORY: \(ambulatoryPatients)
        LINE 6 - SECURITY: \(pickupSiteSecurity.code) - \(pickupSiteSecurity.displayName)
        LINE 7 - MARKING: \(markingMethod.code) - \(markingMethod.displayName)
        LINE 8 - NATIONALITY: \(patientNationality.code) - \(patientNationality.displayName)
        LINE 9 - CBRN: \(cbrnContamination.code) - \(cbrnContamination.displayName)

        REMARKS: \(remarks.isEmpty ? "NONE" : remarks)

        TOTAL PATIENTS: \(totalPatients)
        """
    }
}

// MARK: - Special Equipment (Line 4)

enum SpecialEquipment: String, Codable, CaseIterable {
    case none = "A"
    case hoist = "B"
    case extractionEquipment = "C"
    case ventilator = "D"

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None Required"
        case .hoist: return "Hoist"
        case .extractionEquipment: return "Extraction Equipment"
        case .ventilator: return "Ventilator"
        }
    }
}

// MARK: - Pickup Site Security (Line 6)

enum PickupSiteSecurity: String, Codable, CaseIterable {
    case noEnemy = "N"
    case possibleEnemy = "P"
    case enemyInArea = "E"
    case armedEscortRequired = "X"

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .noEnemy: return "No Enemy Troops in Area"
        case .possibleEnemy: return "Possible Enemy Troops in Area"
        case .enemyInArea: return "Enemy Troops in Area (Approach with Caution)"
        case .armedEscortRequired: return "Armed Escort Required"
        }
    }
}

// MARK: - Marking Method (Line 7)

enum MarkingMethod: String, Codable, CaseIterable {
    case panels = "A"
    case pyrotechnicSignal = "B"
    case smokeSignal = "C"
    case none = "D"
    case other = "E"

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .panels: return "Panels"
        case .pyrotechnicSignal: return "Pyrotechnic Signal"
        case .smokeSignal: return "Smoke Signal"
        case .none: return "None"
        case .other: return "Other"
        }
    }
}

// MARK: - Patient Nationality (Line 8)

enum PatientNationality: String, Codable, CaseIterable {
    case usMilitary = "A"
    case usCivilian = "B"
    case nonUSMilitary = "C"
    case nonUSCivilian = "D"
    case epw = "E"

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .usMilitary: return "US Military"
        case .usCivilian: return "US Civilian"
        case .nonUSMilitary: return "Non-US Military"
        case .nonUSCivilian: return "Non-US Civilian"
        case .epw: return "Enemy Prisoner of War"
        }
    }
}

// MARK: - CBRN Contamination (Line 9)

enum CBRNContamination: String, Codable, CaseIterable {
    case none = "0"
    case nuclear = "N"
    case biological = "B"
    case chemical = "C"

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None/Clean"
        case .nuclear: return "Nuclear"
        case .biological: return "Biological"
        case .chemical: return "Chemical"
        }
    }
}

// MARK: - Patient Precedence

enum PatientPrecedence: String, CaseIterable {
    case urgent = "A"
    case priority = "B"
    case routine = "C"
    case convenience = "D"

    var displayName: String {
        switch self {
        case .urgent: return "Urgent (Surgical)"
        case .priority: return "Priority"
        case .routine: return "Routine"
        case .convenience: return "Convenience"
        }
    }

    var description: String {
        switch self {
        case .urgent: return "Life, limb, or eyesight threatened. Medical treatment required within 2 hours"
        case .priority: return "Requires prompt medical care. Medical treatment required within 4 hours"
        case .routine: return "Requires medical treatment but can safely delay up to 24 hours"
        case .convenience: return "For administrative convenience. Medical treatment not required within 24 hours"
        }
    }
}
