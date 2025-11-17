//
//  EchelonService.swift
//  OmniTAKMobile
//
//  Core service for managing military unit hierarchy
//

import Foundation
import SwiftUI
import Combine

// MARK: - Echelon Service

/// Service for building and managing military unit hierarchy
class EchelonService: ObservableObject {

    // MARK: - Published Properties

    @Published var units: [UUID: MilitaryUnit] = [:]
    @Published var rootUnitIds: [UUID] = []
    @Published var lastError: String?
    @Published var isDirty: Bool = false

    // MARK: - Private Properties

    private let storageKey = "OmniTAK_UnitHierarchy"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        loadFromStorage()
        setupAutoSave()
    }

    // MARK: - Auto Save

    private func setupAutoSave() {
        $isDirty
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .filter { $0 }
            .sink { [weak self] _ in
                self?.saveToStorage()
            }
            .store(in: &cancellables)
    }

    // MARK: - CRUD Operations

    /// Add a new unit to the hierarchy
    @discardableResult
    func addUnit(_ unit: MilitaryUnit) -> UUID {
        var newUnit = unit

        // Add to parent if specified
        if let parentId = unit.parentId, var parent = units[parentId] {
            parent.addChild(unit.id)
            units[parentId] = parent
        } else {
            // No parent means it's a root unit
            if !rootUnitIds.contains(unit.id) {
                rootUnitIds.append(unit.id)
            }
        }

        units[unit.id] = newUnit
        isDirty = true

        return unit.id
    }

    /// Create and add a new unit
    @discardableResult
    func createUnit(
        name: String,
        shortName: String = "",
        echelon: EchelonLevel,
        unitType: MilitaryUnitType = .infantry,
        branch: BranchOfService = .army,
        parentId: UUID? = nil,
        commander: String? = nil,
        location: String? = nil
    ) -> UUID {
        let unit = MilitaryUnit(
            name: name,
            shortName: shortName,
            echelon: echelon,
            unitType: unitType,
            branch: branch,
            parentId: parentId,
            commander: commander,
            location: location
        )
        return addUnit(unit)
    }

    /// Update an existing unit
    func updateUnit(_ unit: MilitaryUnit) {
        guard units[unit.id] != nil else {
            lastError = "Unit not found: \(unit.id)"
            return
        }

        var updatedUnit = unit
        updatedUnit.touch()
        units[unit.id] = updatedUnit
        isDirty = true
    }

    /// Remove a unit and optionally its children
    func removeUnit(_ unitId: UUID, cascade: Bool = false) {
        guard let unit = units[unitId] else {
            lastError = "Unit not found: \(unitId)"
            return
        }

        // Handle children
        if cascade {
            // Recursively remove all children
            for childId in unit.childrenIds {
                removeUnit(childId, cascade: true)
            }
        } else {
            // Move children to parent (or make them root units)
            for childId in unit.childrenIds {
                if var child = units[childId] {
                    child.parentId = unit.parentId
                    if let newParentId = unit.parentId, var newParent = units[newParentId] {
                        newParent.addChild(childId)
                        units[newParentId] = newParent
                    } else {
                        rootUnitIds.append(childId)
                    }
                    units[childId] = child
                }
            }
        }

        // Remove from parent
        if let parentId = unit.parentId, var parent = units[parentId] {
            parent.removeChild(unitId)
            units[parentId] = parent
        }

        // Remove from root units if applicable
        rootUnitIds.removeAll { $0 == unitId }

        // Remove the unit itself
        units.removeValue(forKey: unitId)
        isDirty = true
    }

    /// Move a unit to a new parent
    func moveUnit(_ unitId: UUID, toParent newParentId: UUID?) {
        guard var unit = units[unitId] else {
            lastError = "Unit not found: \(unitId)"
            return
        }

        // Prevent circular references
        if let newParentId = newParentId {
            if isDescendant(unitId, of: newParentId) {
                lastError = "Cannot move unit to its own descendant"
                return
            }
        }

        // Remove from old parent
        if let oldParentId = unit.parentId, var oldParent = units[oldParentId] {
            oldParent.removeChild(unitId)
            units[oldParentId] = oldParent
        } else {
            rootUnitIds.removeAll { $0 == unitId }
        }

        // Add to new parent
        if let newParentId = newParentId, var newParent = units[newParentId] {
            newParent.addChild(unitId)
            units[newParentId] = newParent
            unit.parentId = newParentId
        } else {
            unit.parentId = nil
            if !rootUnitIds.contains(unitId) {
                rootUnitIds.append(unitId)
            }
        }

        unit.touch()
        units[unitId] = unit
        isDirty = true
    }

    // MARK: - Query Operations

    /// Get unit by ID
    func getUnit(_ unitId: UUID) -> MilitaryUnit? {
        units[unitId]
    }

    /// Get all units at a specific echelon level
    func getUnits(atEchelon echelon: EchelonLevel) -> [MilitaryUnit] {
        units.values.filter { $0.echelon == echelon }.sorted { $0.name < $1.name }
    }

    /// Get all units of a specific type
    func getUnits(ofType type: MilitaryUnitType) -> [MilitaryUnit] {
        units.values.filter { $0.unitType == type }.sorted { $0.name < $1.name }
    }

    /// Get all units with a specific status
    func getUnits(withStatus status: UnitStatus) -> [MilitaryUnit] {
        units.values.filter { $0.status == status }.sorted { $0.name < $1.name }
    }

    /// Get all units in a specific branch
    func getUnits(inBranch branch: BranchOfService) -> [MilitaryUnit] {
        units.values.filter { $0.branch == branch }.sorted { $0.name < $1.name }
    }

    /// Get children of a unit
    func getChildren(of unitId: UUID) -> [MilitaryUnit] {
        guard let unit = units[unitId] else { return [] }
        return unit.childrenIds.compactMap { units[$0] }.sorted { $0.name < $1.name }
    }

    /// Get parent of a unit
    func getParent(of unitId: UUID) -> MilitaryUnit? {
        guard let unit = units[unitId], let parentId = unit.parentId else { return nil }
        return units[parentId]
    }

    /// Get all ancestors of a unit (from immediate parent to root)
    func getAncestors(of unitId: UUID) -> [MilitaryUnit] {
        var ancestors: [MilitaryUnit] = []
        var currentId = unitId

        while let unit = units[currentId], let parentId = unit.parentId {
            if let parent = units[parentId] {
                ancestors.append(parent)
                currentId = parentId
            } else {
                break
            }
        }

        return ancestors
    }

    /// Get all descendants of a unit (all children recursively)
    func getDescendants(of unitId: UUID) -> [MilitaryUnit] {
        guard let unit = units[unitId] else { return [] }

        var descendants: [MilitaryUnit] = []

        for childId in unit.childrenIds {
            if let child = units[childId] {
                descendants.append(child)
                descendants.append(contentsOf: getDescendants(of: childId))
            }
        }

        return descendants
    }

    /// Check if a unit is a descendant of another
    func isDescendant(_ unitId: UUID, of ancestorId: UUID) -> Bool {
        var currentId = unitId

        while let unit = units[currentId], let parentId = unit.parentId {
            if parentId == ancestorId {
                return true
            }
            currentId = parentId
        }

        return false
    }

    /// Get all root units
    func getRootUnits() -> [MilitaryUnit] {
        rootUnitIds.compactMap { units[$0] }.sorted { $0.name < $1.name }
    }

    // MARK: - Strength Calculations

    /// Calculate total strength rollup for a unit (including all subordinates)
    func calculateTotalStrength(for unitId: UUID) -> Int {
        guard let unit = units[unitId] else { return 0 }

        var total = unit.currentStrength
        for childId in unit.childrenIds {
            total += calculateTotalStrength(for: childId)
        }

        return total
    }

    /// Calculate total authorized strength rollup for a unit
    func calculateTotalAuthorizedStrength(for unitId: UUID) -> Int {
        guard let unit = units[unitId] else { return 0 }

        var total = unit.authorizedStrength
        for childId in unit.childrenIds {
            total += calculateTotalAuthorizedStrength(for: childId)
        }

        return total
    }

    /// Calculate total effective strength (considering unit status)
    func calculateTotalEffectiveStrength(for unitId: UUID) -> Int {
        guard let unit = units[unitId] else { return 0 }

        var total = unit.effectiveStrength
        for childId in unit.childrenIds {
            total += calculateTotalEffectiveStrength(for: childId)
        }

        return total
    }

    /// Get strength percentage for a unit hierarchy
    func getStrengthPercentage(for unitId: UUID) -> Double {
        let total = calculateTotalStrength(for: unitId)
        let authorized = calculateTotalAuthorizedStrength(for: unitId)
        guard authorized > 0 else { return 0 }
        return Double(total) / Double(authorized) * 100
    }

    // MARK: - Hierarchy Tree Building

    /// Build hierarchical tree structure for display
    func buildHierarchyTree() -> [UnitHierarchyNode] {
        rootUnitIds.compactMap { buildNode(for: $0, depth: 0) }.sorted { $0.unit.name < $1.unit.name }
    }

    /// Build a single node and its children
    private func buildNode(for unitId: UUID, depth: Int) -> UnitHierarchyNode? {
        guard let unit = units[unitId] else { return nil }

        let children = unit.childrenIds.compactMap { buildNode(for: $0, depth: depth + 1) }
            .sorted { $0.unit.name < $1.unit.name }

        return UnitHierarchyNode(unit: unit, children: children, depth: depth)
    }

    /// Flatten hierarchy tree for list display
    func flattenHierarchy(expandedIds: Set<UUID>) -> [(MilitaryUnit, Int)] {
        var result: [(MilitaryUnit, Int)] = []

        for rootId in rootUnitIds {
            flattenNode(rootId, depth: 0, expandedIds: expandedIds, into: &result)
        }

        return result
    }

    private func flattenNode(_ unitId: UUID, depth: Int, expandedIds: Set<UUID>, into result: inout [(MilitaryUnit, Int)]) {
        guard let unit = units[unitId] else { return }

        result.append((unit, depth))

        if expandedIds.contains(unitId) {
            for childId in unit.childrenIds.sorted(by: {
                (units[$0]?.name ?? "") < (units[$1]?.name ?? "")
            }) {
                flattenNode(childId, depth: depth + 1, expandedIds: expandedIds, into: &result)
            }
        }
    }

    // MARK: - Persistence

    /// Save hierarchy to UserDefaults
    func saveToStorage() {
        do {
            let exportModel = HierarchyExportModel(units: Array(units.values))
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(exportModel)
            UserDefaults.standard.set(data, forKey: storageKey)
            isDirty = false
            lastError = nil
        } catch {
            lastError = "Failed to save hierarchy: \(error.localizedDescription)"
        }
    }

    /// Load hierarchy from UserDefaults
    func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            // No saved data, start fresh
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let exportModel = try decoder.decode(HierarchyExportModel.self, from: data)

            // Rebuild units dictionary
            units.removeAll()
            rootUnitIds.removeAll()

            for unit in exportModel.units {
                units[unit.id] = unit
                if unit.isRootUnit {
                    rootUnitIds.append(unit.id)
                }
            }

            isDirty = false
            lastError = nil
        } catch {
            lastError = "Failed to load hierarchy: \(error.localizedDescription)"
        }
    }

    /// Export hierarchy to JSON string
    func exportToJSON() -> String? {
        do {
            let exportModel = HierarchyExportModel(units: Array(units.values))
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(exportModel)
            return String(data: data, encoding: .utf8)
        } catch {
            lastError = "Failed to export hierarchy: \(error.localizedDescription)"
            return nil
        }
    }

    /// Import hierarchy from JSON string
    func importFromJSON(_ jsonString: String, merge: Bool = false) -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            lastError = "Invalid JSON string"
            return false
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let exportModel = try decoder.decode(HierarchyExportModel.self, from: data)

            if !merge {
                // Replace existing data
                units.removeAll()
                rootUnitIds.removeAll()
            }

            for unit in exportModel.units {
                units[unit.id] = unit
                if unit.isRootUnit && !rootUnitIds.contains(unit.id) {
                    rootUnitIds.append(unit.id)
                }
            }

            isDirty = true
            lastError = nil
            return true
        } catch {
            lastError = "Failed to import hierarchy: \(error.localizedDescription)"
            return false
        }
    }

    /// Clear all hierarchy data
    func clearAll() {
        units.removeAll()
        rootUnitIds.removeAll()
        isDirty = true
        saveToStorage()
    }

    // MARK: - Sample Data

    /// Create sample military hierarchy for testing
    func createSampleHierarchy() {
        // Create a sample division structure
        let divisionId = createUnit(
            name: "1st Infantry Division",
            shortName: "1ID",
            echelon: .division,
            unitType: .infantry,
            commander: "MG John Smith",
            location: "Fort Riley, KS"
        )

        // Create brigades
        let brigade1Id = createUnit(
            name: "1st Brigade Combat Team",
            shortName: "1BCT",
            echelon: .brigade,
            unitType: .combined,
            parentId: divisionId,
            commander: "COL James Wilson"
        )

        let brigade2Id = createUnit(
            name: "2nd Brigade Combat Team",
            shortName: "2BCT",
            echelon: .brigade,
            unitType: .combined,
            parentId: divisionId,
            commander: "COL Sarah Johnson"
        )

        let artilleryBrigadeId = createUnit(
            name: "Division Artillery",
            shortName: "DIVARTY",
            echelon: .brigade,
            unitType: .artillery,
            parentId: divisionId,
            commander: "COL Michael Brown"
        )

        // Create battalions for 1st Brigade
        let battalion1Id = createUnit(
            name: "1st Battalion, 16th Infantry",
            shortName: "1-16 IN",
            echelon: .battalion,
            unitType: .infantry,
            parentId: brigade1Id,
            commander: "LTC Robert Davis"
        )

        let battalion2Id = createUnit(
            name: "2nd Battalion, 16th Infantry",
            shortName: "2-16 IN",
            echelon: .battalion,
            unitType: .infantry,
            parentId: brigade1Id,
            commander: "LTC Emily Taylor"
        )

        let armorBattalionId = createUnit(
            name: "1st Battalion, 63rd Armor",
            shortName: "1-63 AR",
            echelon: .battalion,
            unitType: .armor,
            parentId: brigade1Id,
            commander: "LTC Thomas Lee"
        )

        // Create companies for 1st Battalion
        let alphaCompanyId = createUnit(
            name: "Alpha Company",
            shortName: "A Co",
            echelon: .company,
            unitType: .infantry,
            parentId: battalion1Id,
            commander: "CPT Jennifer Martinez"
        )

        if var alphaCompany = units[alphaCompanyId] {
            alphaCompany.currentStrength = 135
            units[alphaCompanyId] = alphaCompany
        }

        let bravoCompanyId = createUnit(
            name: "Bravo Company",
            shortName: "B Co",
            echelon: .company,
            unitType: .infantry,
            parentId: battalion1Id,
            commander: "CPT David Anderson"
        )

        if var bravoCompany = units[bravoCompanyId] {
            bravoCompany.currentStrength = 142
            bravoCompany.status = .degraded
            units[bravoCompanyId] = bravoCompany
        }

        let charlieCompanyId = createUnit(
            name: "Charlie Company",
            shortName: "C Co",
            echelon: .company,
            unitType: .infantry,
            parentId: battalion1Id,
            commander: "CPT Lisa White"
        )

        if var charlieCompany = units[charlieCompanyId] {
            charlieCompany.currentStrength = 148
            units[charlieCompanyId] = charlieCompany
        }

        // Create platoons for Alpha Company
        let _ = createUnit(
            name: "1st Platoon",
            shortName: "1st PLT",
            echelon: .platoon,
            unitType: .infantry,
            parentId: alphaCompanyId,
            commander: "1LT Mark Thompson"
        )

        let _ = createUnit(
            name: "2nd Platoon",
            shortName: "2nd PLT",
            echelon: .platoon,
            unitType: .infantry,
            parentId: alphaCompanyId,
            commander: "1LT Amy Garcia"
        )

        let _ = createUnit(
            name: "3rd Platoon",
            shortName: "3rd PLT",
            echelon: .platoon,
            unitType: .infantry,
            parentId: alphaCompanyId,
            commander: "2LT Brian Clark"
        )

        // Create battalions for 2nd Brigade
        let _ = createUnit(
            name: "1st Battalion, 26th Infantry",
            shortName: "1-26 IN",
            echelon: .battalion,
            unitType: .infantry,
            parentId: brigade2Id,
            commander: "LTC William Harris"
        )

        // Create artillery battalions
        let _ = createUnit(
            name: "1st Battalion, 5th Field Artillery",
            shortName: "1-5 FA",
            echelon: .battalion,
            unitType: .artillery,
            parentId: artilleryBrigadeId,
            commander: "LTC Karen Young"
        )

        isDirty = true
    }
}
