//
//  CASRequestModels.swift
//  OmniTAKMobile
//
//  Models for 9-Line CAS (Close Air Support) Request
//

import Foundation
import CoreLocation

// MARK: - CAS Request Model

struct CASRequest: Identifiable, Codable {
    let id: String
    var timestamp: Date

    // Line 1: IP/BP (Initial Point/Battle Position)
    var initialPoint: String

    // Line 2: Heading (magnetic)
    var headingMagnetic: Int

    // Line 3: Distance (nautical miles from IP/BP to target)
    var distanceNM: Double

    // Line 4: Target Elevation (feet MSL)
    var targetElevationFeet: Int

    // Line 5: Target Description
    var targetDescription: String
    var targetType: TargetType

    // Line 6: Target Location (grid coordinates)
    var targetLocationGrid: String
    var targetLat: Double?
    var targetLon: Double?

    // Line 7: Type Mark (laser code, smoke, etc.)
    var markType: MarkType
    var laserCode: String
    var markDetails: String

    // Line 8: Location of Friendlies (position and mark)
    var friendlyPosition: String
    var friendlyDistance: Int  // meters from target
    var friendlyDirection: String
    var friendlyMark: FriendlyMarkType

    // Line 9: Egress Direction/Control Point
    var egressDirection: String
    var controlPoint: String

    // Additional info
    var dangerClose: DangerCloseStatus
    var remarks: String
    var senderUID: String
    var senderCallsign: String

    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        initialPoint: String = "",
        headingMagnetic: Int = 0,
        distanceNM: Double = 0.0,
        targetElevationFeet: Int = 0,
        targetDescription: String = "",
        targetType: TargetType = .troops,
        targetLocationGrid: String = "",
        targetLat: Double? = nil,
        targetLon: Double? = nil,
        markType: MarkType = .none,
        laserCode: String = "",
        markDetails: String = "",
        friendlyPosition: String = "",
        friendlyDistance: Int = 0,
        friendlyDirection: String = "",
        friendlyMark: FriendlyMarkType = .none,
        egressDirection: String = "",
        controlPoint: String = "",
        dangerClose: DangerCloseStatus = .notDangerClose,
        remarks: String = "",
        senderUID: String = "",
        senderCallsign: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.initialPoint = initialPoint
        self.headingMagnetic = headingMagnetic
        self.distanceNM = distanceNM
        self.targetElevationFeet = targetElevationFeet
        self.targetDescription = targetDescription
        self.targetType = targetType
        self.targetLocationGrid = targetLocationGrid
        self.targetLat = targetLat
        self.targetLon = targetLon
        self.markType = markType
        self.laserCode = laserCode
        self.markDetails = markDetails
        self.friendlyPosition = friendlyPosition
        self.friendlyDistance = friendlyDistance
        self.friendlyDirection = friendlyDirection
        self.friendlyMark = friendlyMark
        self.egressDirection = egressDirection
        self.controlPoint = controlPoint
        self.dangerClose = dangerClose
        self.remarks = remarks
        self.senderUID = senderUID
        self.senderCallsign = senderCallsign
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddHHmmZMMMyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: timestamp).uppercased()
    }

    var isDangerClose: Bool {
        dangerClose == .dangerClose
    }

    var nineLineText: String {
        var text = """
        9-LINE CAS REQUEST
        DTG: \(formattedTimestamp)

        LINE 1 - IP/BP: \(initialPoint)
        LINE 2 - HEADING: \(headingMagnetic)° MAGNETIC
        LINE 3 - DISTANCE: \(String(format: "%.1f", distanceNM)) NM
        LINE 4 - TARGET ELEVATION: \(targetElevationFeet) FT MSL
        LINE 5 - TARGET DESCRIPTION: \(targetType.displayName) - \(targetDescription)
        LINE 6 - TARGET LOCATION: \(targetLocationGrid)
        LINE 7 - TYPE MARK: \(markType.displayName)
        """

        if markType == .laser && !laserCode.isEmpty {
            text += " (CODE: \(laserCode))"
        } else if !markDetails.isEmpty {
            text += " (\(markDetails))"
        }

        text += """

        LINE 8 - FRIENDLIES: \(friendlyDirection) \(friendlyDistance)m FROM TARGET
                 MARK: \(friendlyMark.displayName)
                 \(friendlyPosition)
        LINE 9 - EGRESS: \(egressDirection)
                 CONTROL POINT: \(controlPoint)

        """

        if isDangerClose {
            text += "*** DANGER CLOSE ***\n\n"
        }

        text += "REMARKS: \(remarks.isEmpty ? "NONE" : remarks)"

        return text
    }
}

// MARK: - Target Type

enum TargetType: String, Codable, CaseIterable {
    case troops = "TROOPS"
    case vehicles = "VEHICLES"
    case artillery = "ARTILLERY"
    case bunker = "BUNKER"
    case building = "BUILDING"
    case antiAircraft = "AAA"
    case armor = "ARMOR"
    case mortar = "MORTAR"
    case machineGun = "MG"
    case sniper = "SNIPER"
    case command = "COMMAND"
    case logistics = "LOGISTICS"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .troops: return "Troops in Open"
        case .vehicles: return "Vehicles"
        case .artillery: return "Artillery"
        case .bunker: return "Bunker/Fortification"
        case .building: return "Building/Structure"
        case .antiAircraft: return "Anti-Aircraft"
        case .armor: return "Armor/Tanks"
        case .mortar: return "Mortar Position"
        case .machineGun: return "Machine Gun"
        case .sniper: return "Sniper Position"
        case .command: return "Command Post"
        case .logistics: return "Logistics/Supply"
        case .other: return "Other"
        }
    }
}

// MARK: - Mark Type

enum MarkType: String, Codable, CaseIterable {
    case none = "NONE"
    case laser = "LASER"
    case ir = "IR"
    case beacon = "BEACON"
    case smokeWhite = "WP"
    case smokeRed = "RED"
    case smokeGreen = "GREEN"
    case smokeYellow = "YELLOW"
    case smokePurple = "PURPLE"
    case strobeIR = "IR_STROBE"
    case strobeVisible = "VIS_STROBE"
    case mirror = "MIRROR"
    case other = "OTHER"

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "No Mark"
        case .laser: return "Laser"
        case .ir: return "IR Pointer"
        case .beacon: return "Beacon"
        case .smokeWhite: return "White Smoke"
        case .smokeRed: return "Red Smoke"
        case .smokeGreen: return "Green Smoke"
        case .smokeYellow: return "Yellow Smoke"
        case .smokePurple: return "Purple Smoke"
        case .strobeIR: return "IR Strobe"
        case .strobeVisible: return "Visible Strobe"
        case .mirror: return "Mirror Flash"
        case .other: return "Other"
        }
    }
}

// MARK: - Friendly Mark Type

enum FriendlyMarkType: String, Codable, CaseIterable {
    case none = "NONE"
    case panels = "PANELS"
    case vsPanel = "VS17"
    case ir = "IR"
    case smokeWhite = "WP"
    case smokeGreen = "GREEN"
    case strobeIR = "IR_STROBE"
    case strobeVisible = "VIS_STROBE"
    case other = "OTHER"

    var code: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "No Mark"
        case .panels: return "Panels"
        case .vsPanel: return "VS-17 Panel"
        case .ir: return "IR Pointer/Chemlight"
        case .smokeWhite: return "White Smoke"
        case .smokeGreen: return "Green Smoke"
        case .strobeIR: return "IR Strobe"
        case .strobeVisible: return "Visible Strobe"
        case .other: return "Other"
        }
    }
}

// MARK: - Danger Close Status

enum DangerCloseStatus: String, Codable, CaseIterable {
    case notDangerClose = "NOT_DANGER_CLOSE"
    case dangerClose = "DANGER_CLOSE"

    var displayName: String {
        switch self {
        case .notDangerClose: return "Not Danger Close"
        case .dangerClose: return "DANGER CLOSE"
        }
    }

    var description: String {
        switch self {
        case .notDangerClose: return "Friendlies are at safe distance from target"
        case .dangerClose: return "Friendlies within minimum safe distance - increased risk of friendly casualties"
        }
    }
}

// MARK: - Cardinal Directions

enum CardinalDirection: String, CaseIterable {
    case north = "N"
    case northEast = "NE"
    case east = "E"
    case southEast = "SE"
    case south = "S"
    case southWest = "SW"
    case west = "W"
    case northWest = "NW"

    var displayName: String {
        switch self {
        case .north: return "North"
        case .northEast: return "Northeast"
        case .east: return "East"
        case .southEast: return "Southeast"
        case .south: return "South"
        case .southWest: return "Southwest"
        case .west: return "West"
        case .northWest: return "Northwest"
        }
    }
}
