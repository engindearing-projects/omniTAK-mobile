//
//  EchelonModels.swift
//  OmniTAKMobile
//
//  Data models for military organizational hierarchy and echelon structure
//

import Foundation
import SwiftUI

// MARK: - Echelon Level

/// Standard military echelon levels from smallest to largest
enum EchelonLevel: String, CaseIterable, Codable, Comparable {
    case team = "team"
    case squad = "squad"
    case platoon = "platoon"
    case company = "company"
    case battalion = "battalion"
    case brigade = "brigade"
    case division = "division"
    case corps = "corps"

    var displayName: String {
        switch self {
        case .team: return "Team"
        case .squad: return "Squad"
        case .platoon: return "Platoon"
        case .company: return "Company"
        case .battalion: return "Battalion"
        case .brigade: return "Brigade"
        case .division: return "Division"
        case .corps: return "Corps"
        }
    }

    /// NATO APP-6 echelon symbol
    var natoSymbol: String {
        switch self {
        case .team: return "•"
        case .squad: return "••"
        case .platoon: return "•••"
        case .company: return "I"
        case .battalion: return "II"
        case .brigade: return "III"
        case .division: return "XX"
        case .corps: return "XXX"
        }
    }

    /// Standard personnel strength for this echelon
    var standardStrength: Int {
        switch self {
        case .team: return 4
        case .squad: return 9
        case .platoon: return 40
        case .company: return 150
        case .battalion: return 700
        case .brigade: return 3500
        case .division: return 15000
        case .corps: return 45000
        }
    }

    /// Order value for comparison
    var orderValue: Int {
        switch self {
        case .team: return 0
        case .squad: return 1
        case .platoon: return 2
        case .company: return 3
        case .battalion: return 4
        case .brigade: return 5
        case .division: return 6
        case .corps: return 7
        }
    }

    static func < (lhs: EchelonLevel, rhs: EchelonLevel) -> Bool {
        lhs.orderValue < rhs.orderValue
    }

    /// Icon name for display
    var iconName: String {
        switch self {
        case .team: return "person.2.fill"
        case .squad: return "person.3.fill"
        case .platoon: return "rectangle.3.group.fill"
        case .company: return "building.fill"
        case .battalion: return "building.2.fill"
        case .brigade: return "shield.fill"
        case .division: return "shield.lefthalf.filled"
        case .corps: return "shield.checkered"
        }
    }
}

// MARK: - Unit Type

/// Types of military units
enum MilitaryUnitType: String, CaseIterable, Codable {
    case infantry = "infantry"
    case armor = "armor"
    case artillery = "artillery"
    case aviation = "aviation"
    case support = "support"
    case engineer = "engineer"
    case signal = "signal"
    case medical = "medical"
    case logistics = "logistics"
    case reconnaissance = "reconnaissance"
    case airDefense = "air_defense"
    case specialForces = "special_forces"
    case headquarters = "headquarters"
    case combined = "combined"

    var displayName: String {
        switch self {
        case .infantry: return "Infantry"
        case .armor: return "Armor"
        case .artillery: return "Artillery"
        case .aviation: return "Aviation"
        case .support: return "Support"
        case .engineer: return "Engineer"
        case .signal: return "Signal"
        case .medical: return "Medical"
        case .logistics: return "Logistics"
        case .reconnaissance: return "Reconnaissance"
        case .airDefense: return "Air Defense"
        case .specialForces: return "Special Forces"
        case .headquarters: return "Headquarters"
        case .combined: return "Combined Arms"
        }
    }

    var iconName: String {
        switch self {
        case .infantry: return "figure.walk"
        case .armor: return "shield.fill"
        case .artillery: return "burst.fill"
        case .aviation: return "airplane"
        case .support: return "wrench.and.screwdriver.fill"
        case .engineer: return "hammer.fill"
        case .signal: return "antenna.radiowaves.left.and.right"
        case .medical: return "cross.fill"
        case .logistics: return "truck.box.fill"
        case .reconnaissance: return "binoculars.fill"
        case .airDefense: return "shield.slash.fill"
        case .specialForces: return "bolt.shield.fill"
        case .headquarters: return "star.fill"
        case .combined: return "rectangle.stack.fill"
        }
    }

    var color: Color {
        switch self {
        case .infantry: return .blue
        case .armor: return .orange
        case .artillery: return .red
        case .aviation: return .cyan
        case .support: return .gray
        case .engineer: return .brown
        case .signal: return .purple
        case .medical: return .white
        case .logistics: return .green
        case .reconnaissance: return .yellow
        case .airDefense: return .pink
        case .specialForces: return .indigo
        case .headquarters: return Color(hex: "#FFFC00")
        case .combined: return .mint
        }
    }
}

// MARK: - Unit Status

/// Operational status of a military unit
enum UnitStatus: String, CaseIterable, Codable {
    case operational = "operational"
    case degraded = "degraded"
    case combatIneffective = "combat_ineffective"
    case reconstituting = "reconstituting"
    case inReserve = "in_reserve"

    var displayName: String {
        switch self {
        case .operational: return "Operational"
        case .degraded: return "Degraded"
        case .combatIneffective: return "Combat Ineffective"
        case .reconstituting: return "Reconstituting"
        case .inReserve: return "In Reserve"
        }
    }

    var color: Color {
        switch self {
        case .operational: return .green
        case .degraded: return .yellow
        case .combatIneffective: return .red
        case .reconstituting: return .orange
        case .inReserve: return .gray
        }
    }

    var iconName: String {
        switch self {
        case .operational: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .combatIneffective: return "xmark.circle.fill"
        case .reconstituting: return "arrow.clockwise.circle.fill"
        case .inReserve: return "pause.circle.fill"
        }
    }

    /// Effectiveness multiplier for strength calculations
    var effectivenessMultiplier: Double {
        switch self {
        case .operational: return 1.0
        case .degraded: return 0.7
        case .combatIneffective: return 0.3
        case .reconstituting: return 0.5
        case .inReserve: return 0.0
        }
    }
}

// MARK: - Branch of Service

/// Military branches
enum BranchOfService: String, CaseIterable, Codable {
    case army = "army"
    case navy = "navy"
    case airforce = "airforce"
    case marines = "marines"
    case coastGuard = "coast_guard"
    case spaceForce = "space_force"
    case nationalGuard = "national_guard"
    case reserve = "reserve"

    var displayName: String {
        switch self {
        case .army: return "Army"
        case .navy: return "Navy"
        case .airforce: return "Air Force"
        case .marines: return "Marines"
        case .coastGuard: return "Coast Guard"
        case .spaceForce: return "Space Force"
        case .nationalGuard: return "National Guard"
        case .reserve: return "Reserve"
        }
    }

    var iconName: String {
        switch self {
        case .army: return "shield.fill"
        case .navy: return "ferry.fill"
        case .airforce: return "airplane"
        case .marines: return "globe.americas.fill"
        case .coastGuard: return "lifepreserver.fill"
        case .spaceForce: return "sparkles"
        case .nationalGuard: return "shield.checkered"
        case .reserve: return "shield.lefthalf.filled"
        }
    }

    var primaryColor: Color {
        switch self {
        case .army: return .green
        case .navy: return .blue
        case .airforce: return .cyan
        case .marines: return .red
        case .coastGuard: return .orange
        case .spaceForce: return .purple
        case .nationalGuard: return .yellow
        case .reserve: return .gray
        }
    }
}

// MARK: - Military Unit

/// Represents a military organizational unit
struct MilitaryUnit: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var uid: String
    var name: String
    var shortName: String
    var echelon: EchelonLevel
    var unitType: MilitaryUnitType
    var branch: BranchOfService
    var status: UnitStatus

    // Hierarchy
    var parentId: UUID?
    var childrenIds: [UUID]

    // Strength & Personnel
    var authorizedStrength: Int
    var currentStrength: Int
    var remarks: String?

    // Metadata
    let createdAt: Date
    var modifiedAt: Date
    var commander: String?
    var location: String?

    // TAK Integration
    var cotType: String

    init(
        id: UUID = UUID(),
        name: String,
        shortName: String = "",
        echelon: EchelonLevel,
        unitType: MilitaryUnitType = .infantry,
        branch: BranchOfService = .army,
        status: UnitStatus = .operational,
        parentId: UUID? = nil,
        authorizedStrength: Int? = nil,
        currentStrength: Int? = nil,
        commander: String? = nil,
        location: String? = nil,
        remarks: String? = nil
    ) {
        self.id = id
        self.uid = "unit-\(id.uuidString)"
        self.name = name
        self.shortName = shortName.isEmpty ? String(name.prefix(10)) : shortName
        self.echelon = echelon
        self.unitType = unitType
        self.branch = branch
        self.status = status
        self.parentId = parentId
        self.childrenIds = []
        self.authorizedStrength = authorizedStrength ?? echelon.standardStrength
        self.currentStrength = currentStrength ?? (authorizedStrength ?? echelon.standardStrength)
        self.remarks = remarks
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.commander = commander
        self.location = location
        self.cotType = "a-f-G-U"  // Friendly ground unit
    }

    // MARK: - Computed Properties

    /// Personnel strength percentage
    var strengthPercentage: Double {
        guard authorizedStrength > 0 else { return 0 }
        return Double(currentStrength) / Double(authorizedStrength) * 100
    }

    /// Formatted strength display
    var strengthDisplay: String {
        "\(currentStrength)/\(authorizedStrength) (\(Int(strengthPercentage))%)"
    }

    /// Effective combat strength considering status
    var effectiveStrength: Int {
        Int(Double(currentStrength) * status.effectivenessMultiplier)
    }

    /// Full display name with echelon symbol
    var fullDisplayName: String {
        "[\(echelon.natoSymbol)] \(name)"
    }

    /// Has subordinate units
    var hasChildren: Bool {
        !childrenIds.isEmpty
    }

    /// Is a top-level unit (no parent)
    var isRootUnit: Bool {
        parentId == nil
    }

    // MARK: - Equatable

    static func == (lhs: MilitaryUnit, rhs: MilitaryUnit) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Helper Methods

    mutating func touch() {
        modifiedAt = Date()
    }

    mutating func addChild(_ childId: UUID) {
        if !childrenIds.contains(childId) {
            childrenIds.append(childId)
            touch()
        }
    }

    mutating func removeChild(_ childId: UUID) {
        childrenIds.removeAll { $0 == childId }
        touch()
    }

    mutating func updateStrength(current: Int) {
        self.currentStrength = max(0, min(current, authorizedStrength * 2))
        touch()
    }

    mutating func updateStatus(_ newStatus: UnitStatus) {
        self.status = newStatus
        touch()
    }
}

// MARK: - Unit Hierarchy Node

/// Tree node wrapper for hierarchical display
struct UnitHierarchyNode: Identifiable {
    let id: UUID
    let unit: MilitaryUnit
    var children: [UnitHierarchyNode]
    var depth: Int
    var isExpanded: Bool

    init(unit: MilitaryUnit, children: [UnitHierarchyNode] = [], depth: Int = 0, isExpanded: Bool = true) {
        self.id = unit.id
        self.unit = unit
        self.children = children
        self.depth = depth
        self.isExpanded = isExpanded
    }

    /// Total strength including all subordinate units
    var totalStrength: Int {
        unit.currentStrength + children.reduce(0) { $0 + $1.totalStrength }
    }

    /// Total authorized strength including all subordinate units
    var totalAuthorizedStrength: Int {
        unit.authorizedStrength + children.reduce(0) { $0 + $1.totalAuthorizedStrength }
    }

    /// Total effective strength including all subordinate units
    var totalEffectiveStrength: Int {
        unit.effectiveStrength + children.reduce(0) { $0 + $1.totalEffectiveStrength }
    }

    /// Count of all units in this subtree
    var totalUnitCount: Int {
        1 + children.reduce(0) { $0 + $1.totalUnitCount }
    }
}

// MARK: - Hierarchy Export/Import Model

/// Model for exporting/importing unit hierarchies
struct HierarchyExportModel: Codable {
    let version: String
    let exportDate: Date
    let units: [MilitaryUnit]

    init(units: [MilitaryUnit]) {
        self.version = "1.0"
        self.exportDate = Date()
        self.units = units
    }
}
