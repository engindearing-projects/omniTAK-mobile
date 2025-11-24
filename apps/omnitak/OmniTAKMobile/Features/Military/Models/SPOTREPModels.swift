//
//  SPOTREPModels.swift
//  OmniTAKMobile
//
//  Models for SPOTREP (Spot Report)
//

import Foundation
import CoreLocation

// MARK: - SPOTREP Model

struct SPOTREPReport: Identifiable, Codable {
    let id: String
    var timestamp: Date

    // Date Time Group
    var dateTimeGroup: Date

    // Unit/Location Information
    var unitIdentification: String
    var enemyUnitSize: EnemyUnitSize
    var activityObserved: ActivityType
    var locationGrid: String
    var locationLat: Double?
    var locationLon: Double?

    // Observation Details
    var uniformDescription: String
    var timeOfObservation: Date
    var equipmentObserved: String
    var remarks: String

    // Sender Info
    var senderUID: String
    var senderCallsign: String

    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        dateTimeGroup: Date = Date(),
        unitIdentification: String = "",
        enemyUnitSize: EnemyUnitSize = .unknown,
        activityObserved: ActivityType = .unknown,
        locationGrid: String = "",
        locationLat: Double? = nil,
        locationLon: Double? = nil,
        uniformDescription: String = "",
        timeOfObservation: Date = Date(),
        equipmentObserved: String = "",
        remarks: String = "",
        senderUID: String = "",
        senderCallsign: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.dateTimeGroup = dateTimeGroup
        self.unitIdentification = unitIdentification
        self.enemyUnitSize = enemyUnitSize
        self.activityObserved = activityObserved
        self.locationGrid = locationGrid
        self.locationLat = locationLat
        self.locationLon = locationLon
        self.uniformDescription = uniformDescription
        self.timeOfObservation = timeOfObservation
        self.equipmentObserved = equipmentObserved
        self.remarks = remarks
        self.senderUID = senderUID
        self.senderCallsign = senderCallsign
    }

    var formattedDTG: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddHHmmZMMMyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: dateTimeGroup).uppercased()
    }

    var formattedObservationTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddHHmmZMMMyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: timeOfObservation).uppercased()
    }

    var formattedReportText: String {
        """
        SPOTREP (SPOT REPORT)
        DTG: \(formattedDTG)
        FROM: \(senderCallsign)

        1. UNIT IDENTIFICATION: \(unitIdentification.isEmpty ? "UNKNOWN" : unitIdentification)
        2. SIZE: \(enemyUnitSize.displayName)
        3. ACTIVITY: \(activityObserved.displayName)
        4. LOCATION: \(locationGrid.isEmpty ? "NOT SPECIFIED" : locationGrid)
        5. UNIFORMS/ID: \(uniformDescription.isEmpty ? "NOT OBSERVED" : uniformDescription)
        6. TIME OBSERVED: \(formattedObservationTime)
        7. EQUIPMENT: \(equipmentObserved.isEmpty ? "NONE OBSERVED" : equipmentObserved)
        8. ASSESSMENT/REMARKS: \(remarks.isEmpty ? "NONE" : remarks)

        END REPORT
        """
    }
}

// MARK: - Enemy Unit Size

enum EnemyUnitSize: String, Codable, CaseIterable {
    case unknown = "UNK"
    case individual = "IND"
    case team = "TM"
    case squad = "SQD"
    case section = "SEC"
    case platoon = "PLT"
    case company = "CO"
    case battalion = "BN"
    case regiment = "RGT"
    case brigade = "BDE"
    case division = "DIV"
    case corps = "CORPS"
    case army = "ARMY"

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .individual: return "Individual (1)"
        case .team: return "Team (2-4)"
        case .squad: return "Squad (8-13)"
        case .section: return "Section (2 Squads)"
        case .platoon: return "Platoon (16-44)"
        case .company: return "Company (100-200)"
        case .battalion: return "Battalion (300-1000)"
        case .regiment: return "Regiment (1000-3000)"
        case .brigade: return "Brigade (3000-5000)"
        case .division: return "Division (10000-15000)"
        case .corps: return "Corps (20000-45000)"
        case .army: return "Army (50000+)"
        }
    }

    var shortName: String {
        switch self {
        case .unknown: return "UNK"
        case .individual: return "1"
        case .team: return "TM"
        case .squad: return "SQD"
        case .section: return "SEC"
        case .platoon: return "PLT"
        case .company: return "CO"
        case .battalion: return "BN"
        case .regiment: return "RGT"
        case .brigade: return "BDE"
        case .division: return "DIV"
        case .corps: return "CORPS"
        case .army: return "ARMY"
        }
    }
}

// MARK: - Activity Type

enum ActivityType: String, Codable, CaseIterable {
    case unknown = "UNK"
    case attacking = "ATK"
    case defending = "DEF"
    case moving = "MOV"
    case stationary = "STA"
    case patrolling = "PAT"
    case reconnoitering = "RCN"
    case withdrawing = "WDR"
    case establishing = "EST"
    case resupplying = "RSP"
    case digging = "DIG"
    case assembling = "ASM"
    case dispersing = "DSP"

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .attacking: return "Attacking"
        case .defending: return "Defending"
        case .moving: return "Moving"
        case .stationary: return "Stationary"
        case .patrolling: return "Patrolling"
        case .reconnoitering: return "Reconnoitering"
        case .withdrawing: return "Withdrawing"
        case .establishing: return "Establishing Position"
        case .resupplying: return "Resupplying"
        case .digging: return "Digging In"
        case .assembling: return "Assembling"
        case .dispersing: return "Dispersing"
        }
    }

    var shortName: String {
        switch self {
        case .unknown: return "UNK"
        case .attacking: return "ATK"
        case .defending: return "DEF"
        case .moving: return "MOV"
        case .stationary: return "STA"
        case .patrolling: return "PAT"
        case .reconnoitering: return "RCN"
        case .withdrawing: return "WDR"
        case .establishing: return "EST"
        case .resupplying: return "RSP"
        case .digging: return "DIG"
        case .assembling: return "ASM"
        case .dispersing: return "DSP"
        }
    }
}
