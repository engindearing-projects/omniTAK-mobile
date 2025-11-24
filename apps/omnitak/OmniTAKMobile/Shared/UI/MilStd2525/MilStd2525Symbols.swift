//
//  MilStd2525Symbols.swift
//  OmniTAKMobile
//
//  MIL-STD-2525B Military Symbol Definitions and Mapping
//

import Foundation
import SwiftUI

// MARK: - Affiliation (Identity)

enum MilStdAffiliation: String, CaseIterable {
    case friendly = "f"     // Blue - Friend
    case hostile = "h"      // Red - Hostile/Enemy
    case neutral = "n"      // Green - Neutral
    case unknown = "u"      // Yellow - Unknown
    case pending = "p"      // Yellow - Pending (treated as unknown)
    case assumed = "a"      // Similar to friendly but assumed
    case suspect = "s"      // Orange/Red - Suspect/Joker
    case joker = "j"        // Faker
    case faker = "k"        // Faker

    var color: Color {
        switch self {
        case .friendly, .assumed:
            return Color(red: 0.0, green: 0.5, blue: 1.0)  // Blue
        case .hostile, .suspect, .joker, .faker:
            return Color(red: 1.0, green: 0.2, blue: 0.2)  // Red
        case .neutral:
            return Color(red: 0.0, green: 0.8, blue: 0.4)  // Green
        case .unknown, .pending:
            return Color(red: 1.0, green: 0.85, blue: 0.0) // Yellow
        }
    }

    var fillColor: Color {
        color.opacity(0.3)
    }

    var displayName: String {
        switch self {
        case .friendly: return "Friendly"
        case .hostile: return "Hostile"
        case .neutral: return "Neutral"
        case .unknown: return "Unknown"
        case .pending: return "Pending"
        case .assumed: return "Assumed Friendly"
        case .suspect: return "Suspect"
        case .joker: return "Joker"
        case .faker: return "Faker"
        }
    }
}

// MARK: - Battle Dimension

enum MilStdBattleDimension: String, CaseIterable {
    case ground = "G"       // Ground Track
    case air = "A"          // Air Track
    case sea = "S"          // Sea Surface Track
    case subsurface = "U"   // Subsurface Track
    case space = "P"        // Space Track
    case other = "X"        // Other

    var displayName: String {
        switch self {
        case .ground: return "Ground"
        case .air: return "Air"
        case .sea: return "Sea Surface"
        case .subsurface: return "Subsurface"
        case .space: return "Space"
        case .other: return "Other"
        }
    }

    var defaultIcon: String {
        switch self {
        case .ground: return "figure.walk"
        case .air: return "airplane"
        case .sea: return "ferry"
        case .subsurface: return "water.waves"
        case .space: return "satellite"
        case .other: return "questionmark"
        }
    }
}

// MARK: - Unit Status

enum MilStdStatus: String, CaseIterable {
    case present = "C"          // Present/Confirmed
    case anticipated = "A"      // Anticipated/Planned
    case suspected = "S"        // Suspected
    case exercise = "G"         // Exercise
    case simulation = "X"       // Simulation

    var displayName: String {
        switch self {
        case .present: return "Present"
        case .anticipated: return "Anticipated"
        case .suspected: return "Suspected"
        case .exercise: return "Exercise"
        case .simulation: return "Simulation"
        }
    }

    var isDashed: Bool {
        switch self {
        case .anticipated, .suspected:
            return true
        default:
            return false
        }
    }
}

// MARK: - Echelon/Size

enum MilStdEchelon: String, CaseIterable {
    case team = "A"              // Team/Crew
    case squad = "B"             // Squad
    case section = "C"           // Section
    case platoon = "D"           // Platoon/Detachment
    case company = "E"           // Company/Battery/Troop
    case battalion = "F"         // Battalion/Squadron
    case regiment = "G"          // Regiment/Group
    case brigade = "H"           // Brigade
    case division = "I"          // Division
    case corps = "J"             // Corps/MEF
    case army = "K"              // Army
    case armyGroup = "L"         // Army Group/Front
    case region = "M"            // Region/Theater
    case command = "N"           // Command

    var symbol: String {
        switch self {
        case .team: return "\u{2022}"           // Single dot
        case .squad: return "\u{2022}\u{2022}"  // Two dots
        case .section: return "\u{2022}\u{2022}\u{2022}" // Three dots
        case .platoon: return "I"
        case .company: return "II"
        case .battalion: return "III"
        case .regiment: return "III"
        case .brigade: return "X"
        case .division: return "XX"
        case .corps: return "XXX"
        case .army: return "XXXX"
        case .armyGroup: return "XXXXX"
        case .region: return "XXXXXX"
        case .command: return "\u{2605}"        // Star
        }
    }

    var displayName: String {
        switch self {
        case .team: return "Team"
        case .squad: return "Squad"
        case .section: return "Section"
        case .platoon: return "Platoon"
        case .company: return "Company"
        case .battalion: return "Battalion"
        case .regiment: return "Regiment"
        case .brigade: return "Brigade"
        case .division: return "Division"
        case .corps: return "Corps"
        case .army: return "Army"
        case .armyGroup: return "Army Group"
        case .region: return "Region"
        case .command: return "Command"
        }
    }
}

// MARK: - Unit Type (Function ID)

enum MilStdUnitType: String, CaseIterable {
    // Ground Combat Units
    case infantry = "UCI"
    case mechanizedInfantry = "UCIM"
    case armor = "UCA"
    case cavalry = "UCAV"
    case artillery = "UCF"
    case airDefense = "UCD"
    case engineer = "UCE"
    case reconnaissance = "UCR"
    case specialForces = "UCSF"

    // Combat Support
    case signal = "USS"
    case militaryIntelligence = "USI"
    case chemicalBiological = "USC"
    case militaryPolice = "USMP"
    case civilAffairs = "USCA"

    // Combat Service Support
    case supply = "US"
    case transportation = "UST"
    case maintenance = "USMA"
    case medical = "USM"

    // Aviation
    case aviation = "UCA-"
    case attackHelicopter = "UCAA"
    case utilityHelicopter = "UCAU"
    case reconHelicopter = "UCAR"

    // Other
    case headquarters = "UH"
    case combatSupport = "UCS"
    case unknown = "U"

    var icon: String {
        switch self {
        case .infantry:
            return "figure.walk"
        case .mechanizedInfantry:
            return "car.side"
        case .armor:
            return "shield.fill"
        case .cavalry:
            return "hare.fill"
        case .artillery:
            return "circle.fill"
        case .airDefense:
            return "antenna.radiowaves.left.and.right"
        case .engineer:
            return "wrench.and.screwdriver"
        case .reconnaissance:
            return "eye.fill"
        case .specialForces:
            return "bolt.fill"
        case .signal:
            return "antenna.radiowaves.left.and.right"
        case .militaryIntelligence:
            return "brain.head.profile"
        case .chemicalBiological:
            return "aqi.medium"
        case .militaryPolice:
            return "shield.lefthalf.filled"
        case .civilAffairs:
            return "person.3.fill"
        case .supply:
            return "shippingbox.fill"
        case .transportation:
            return "truck.box.fill"
        case .maintenance:
            return "wrench.fill"
        case .medical:
            return "cross.fill"
        case .aviation:
            return "airplane"
        case .attackHelicopter:
            return "helicopter.fill"
        case .utilityHelicopter:
            return "helicopter"
        case .reconHelicopter:
            return "helicopter"
        case .headquarters:
            return "flag.fill"
        case .combatSupport:
            return "hammer.fill"
        case .unknown:
            return "questionmark"
        }
    }

    var displayName: String {
        switch self {
        case .infantry: return "Infantry"
        case .mechanizedInfantry: return "Mechanized Infantry"
        case .armor: return "Armor"
        case .cavalry: return "Cavalry"
        case .artillery: return "Artillery"
        case .airDefense: return "Air Defense"
        case .engineer: return "Engineer"
        case .reconnaissance: return "Reconnaissance"
        case .specialForces: return "Special Forces"
        case .signal: return "Signal"
        case .militaryIntelligence: return "Military Intelligence"
        case .chemicalBiological: return "Chemical/Biological"
        case .militaryPolice: return "Military Police"
        case .civilAffairs: return "Civil Affairs"
        case .supply: return "Supply"
        case .transportation: return "Transportation"
        case .maintenance: return "Maintenance"
        case .medical: return "Medical"
        case .aviation: return "Aviation"
        case .attackHelicopter: return "Attack Helicopter"
        case .utilityHelicopter: return "Utility Helicopter"
        case .reconHelicopter: return "Reconnaissance Helicopter"
        case .headquarters: return "Headquarters"
        case .combatSupport: return "Combat Support"
        case .unknown: return "Unknown"
        }
    }

    // Standard MIL-STD-2525 symbol character
    var symbolCharacter: String {
        switch self {
        case .infantry:
            return "\u{2694}"      // Crossed swords
        case .mechanizedInfantry:
            return "\u{2694}M"     // Crossed swords with M
        case .armor:
            return "\u{25CB}"      // Circle (represents track)
        case .cavalry:
            return "/"             // Diagonal line
        case .artillery:
            return "\u{2022}"      // Filled circle
        case .airDefense:
            return "\u{22A5}"      // Up tack
        case .engineer:
            return "E"
        case .reconnaissance:
            return "R"
        case .specialForces:
            return "SF"
        case .signal:
            return "\u{2301}"      // Electric arrow
        case .militaryIntelligence:
            return "MI"
        case .chemicalBiological:
            return "CBRN"
        case .militaryPolice:
            return "MP"
        case .civilAffairs:
            return "CA"
        case .supply:
            return "S"
        case .transportation:
            return "T"
        case .maintenance:
            return "M"
        case .medical:
            return "\u{2720}"      // Maltese cross
        case .aviation, .attackHelicopter, .utilityHelicopter, .reconHelicopter:
            return "\u{2708}"      // Airplane
        case .headquarters:
            return "HQ"
        case .combatSupport:
            return "CS"
        case .unknown:
            return "?"
        }
    }
}

// MARK: - Symbol Modifiers

struct MilStdModifiers {
    var isHeadquarters: Bool = false
    var isTaskForce: Bool = false
    var isFeintDummy: Bool = false
    var isInstallation: Bool = false
    var mobility: MilStdMobility = .none
    var operationalCondition: MilStdOperationalCondition = .fullyCapable
}

enum MilStdMobility: String, CaseIterable {
    case none = ""
    case wheeled = "W"
    case wheeledLimited = "WL"
    case tracked = "T"
    case wheeledAndTracked = "WT"
    case towed = "TO"
    case rail = "R"
    case overSnow = "OS"
    case sled = "SL"
    case packAnimals = "PA"
    case barge = "B"
    case amphibious = "A"
}

enum MilStdOperationalCondition: String, CaseIterable {
    case fullyCapable = "A"
    case damaged = "B"
    case destroyed = "C"
    case fullToCapacity = "D"
}

// MARK: - Symbol Properties Container

struct MilStdSymbolProperties {
    let affiliation: MilStdAffiliation
    let battleDimension: MilStdBattleDimension
    let unitType: MilStdUnitType
    let status: MilStdStatus
    let echelon: MilStdEchelon?
    let modifiers: MilStdModifiers

    init(
        affiliation: MilStdAffiliation = .unknown,
        battleDimension: MilStdBattleDimension = .ground,
        unitType: MilStdUnitType = .unknown,
        status: MilStdStatus = .present,
        echelon: MilStdEchelon? = nil,
        modifiers: MilStdModifiers = MilStdModifiers()
    ) {
        self.affiliation = affiliation
        self.battleDimension = battleDimension
        self.unitType = unitType
        self.status = status
        self.echelon = echelon
        self.modifiers = modifiers
    }
}

// MARK: - CoT Type String Parser

class MilStdCoTParser {

    /// Parse a CoT type string into MIL-STD-2525 symbol properties
    /// CoT format: a-{affiliation}-{dimension}-{function}
    /// Example: a-f-G-U-C-I = Friendly Ground Unit Combat Infantry
    static func parse(cotType: String) -> MilStdSymbolProperties {
        let components = cotType.split(separator: "-").map(String.init)

        // Default values
        var affiliation: MilStdAffiliation = .unknown
        var battleDimension: MilStdBattleDimension = .ground
        var unitType: MilStdUnitType = .unknown
        let status: MilStdStatus = .present
        var echelon: MilStdEchelon? = nil
        var modifiers = MilStdModifiers()

        // Parse affiliation (position 1)
        if components.count > 1 {
            affiliation = parseAffiliation(components[1])
        }

        // Parse battle dimension (position 2)
        if components.count > 2 {
            battleDimension = parseBattleDimension(components[2])
        }

        // Parse unit function (positions 3+)
        if components.count > 3 {
            let functionComponents = Array(components[3...])
            let result = parseFunction(functionComponents)
            unitType = result.unitType
            echelon = result.echelon
            modifiers = result.modifiers
        }

        return MilStdSymbolProperties(
            affiliation: affiliation,
            battleDimension: battleDimension,
            unitType: unitType,
            status: status,
            echelon: echelon,
            modifiers: modifiers
        )
    }

    private static func parseAffiliation(_ code: String) -> MilStdAffiliation {
        switch code.lowercased() {
        case "f": return .friendly
        case "h": return .hostile
        case "n": return .neutral
        case "u": return .unknown
        case "p": return .pending
        case "a": return .assumed
        case "s": return .suspect
        case "j": return .joker
        case "k": return .faker
        default: return .unknown
        }
    }

    private static func parseBattleDimension(_ code: String) -> MilStdBattleDimension {
        switch code.uppercased() {
        case "G": return .ground
        case "A": return .air
        case "S": return .sea
        case "U": return .subsurface
        case "P": return .space
        case "X": return .other
        default: return .ground
        }
    }

    private static func parseFunction(_ components: [String]) -> (unitType: MilStdUnitType, echelon: MilStdEchelon?, modifiers: MilStdModifiers) {
        var unitType: MilStdUnitType = .unknown
        var echelon: MilStdEchelon? = nil
        var modifiers = MilStdModifiers()

        guard !components.isEmpty else {
            return (unitType, echelon, modifiers)
        }

        // First component usually indicates unit category
        let primaryCode = components[0].uppercased()

        switch primaryCode {
        case "U", "E":
            // Unit or Equipment
            if components.count > 1 {
                let secondCode = components[1].uppercased()

                switch secondCode {
                case "C":
                    // Combat unit
                    if components.count > 2 {
                        let thirdCode = components[2].uppercased()
                        unitType = parseCombatUnit(thirdCode)
                    }
                case "S":
                    // Support unit
                    if components.count > 2 {
                        let thirdCode = components[2].uppercased()
                        unitType = parseSupportUnit(thirdCode)
                    }
                case "H":
                    // Headquarters
                    modifiers.isHeadquarters = true
                    unitType = .headquarters
                default:
                    unitType = .unknown
                }
            }

        case "I":
            // Installation
            modifiers.isInstallation = true

        case "EV":
            // Evacuation point
            unitType = .medical

        default:
            // Try direct mapping
            unitType = directUnitMapping(primaryCode)
        }

        // Parse echelon if present (usually last component)
        if let lastComponent = components.last, components.count > 1 {
            echelon = parseEchelon(lastComponent)
        }

        return (unitType, echelon, modifiers)
    }

    private static func parseCombatUnit(_ code: String) -> MilStdUnitType {
        switch code {
        case "I": return .infantry
        case "A": return .armor
        case "F": return .artillery
        case "D": return .airDefense
        case "E": return .engineer
        case "R": return .reconnaissance
        case "V": return .cavalry
        case "AV": return .cavalry
        default: return .unknown
        }
    }

    private static func parseSupportUnit(_ code: String) -> MilStdUnitType {
        switch code {
        case "S": return .signal
        case "I": return .militaryIntelligence
        case "C": return .chemicalBiological
        case "MP": return .militaryPolice
        case "M": return .medical
        case "T": return .transportation
        case "MA": return .maintenance
        case "CA": return .civilAffairs
        default: return .supply
        }
    }

    private static func directUnitMapping(_ code: String) -> MilStdUnitType {
        switch code {
        case "INF", "UCI": return .infantry
        case "ARM", "UCA": return .armor
        case "ART", "UCF": return .artillery
        case "CAV", "UCAV": return .cavalry
        case "ENG", "UCE": return .engineer
        case "SIG", "USS": return .signal
        case "MED", "USM": return .medical
        case "HQ", "UH": return .headquarters
        default: return .unknown
        }
    }

    private static func parseEchelon(_ code: String) -> MilStdEchelon? {
        switch code.uppercased() {
        case "A": return .team
        case "B": return .squad
        case "C": return .section
        case "D": return .platoon
        case "E": return .company
        case "F": return .battalion
        case "G": return .regiment
        case "H": return .brigade
        case "I": return .division
        case "J": return .corps
        case "K": return .army
        case "L": return .armyGroup
        case "M": return .region
        case "N": return .command
        default: return nil
        }
    }
}

// MARK: - Extended CoT Type Descriptions

extension MilStdCoTParser {

    /// Get a human-readable description of a CoT type
    static func describe(cotType: String) -> String {
        let props = parse(cotType: cotType)

        var description = props.affiliation.displayName
        description += " \(props.battleDimension.displayName)"

        if let echelon = props.echelon {
            description += " \(echelon.displayName)"
        }

        description += " \(props.unitType.displayName)"

        if props.modifiers.isHeadquarters {
            description += " Headquarters"
        }

        if props.modifiers.isTaskForce {
            description += " Task Force"
        }

        return description
    }

    /// Generate a SIDC (Symbol Identification Code) from properties
    static func generateSIDC(from props: MilStdSymbolProperties) -> String {
        var sidc = "S"  // Standard/Warfighting

        // Affiliation
        switch props.affiliation {
        case .friendly, .assumed: sidc += "F"
        case .hostile, .suspect, .joker, .faker: sidc += "H"
        case .neutral: sidc += "N"
        case .unknown, .pending: sidc += "U"
        }

        // Battle Dimension
        sidc += props.battleDimension.rawValue

        // Status
        sidc += props.status.rawValue

        // Placeholder for function ID
        sidc += "------"

        return sidc
    }
}
