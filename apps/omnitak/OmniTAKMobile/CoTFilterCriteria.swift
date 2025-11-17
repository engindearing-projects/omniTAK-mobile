//
//  CoTFilterCriteria.swift
//  OmniTAKTest
//
//  Filter configuration and criteria management
//

import Foundation
import Combine
import SwiftUI

// MARK: - Sort Options

enum CoTSortOption: String, CaseIterable, Identifiable, Codable {
    case distance = "distance"
    case age = "age"
    case callsign = "callsign"
    case affiliation = "affiliation"
    case category = "category"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .distance: return "Distance"
        case .age: return "Age"
        case .callsign: return "Callsign"
        case .affiliation: return "Affiliation"
        case .category: return "Category"
        }
    }

    var icon: String {
        switch self {
        case .distance: return "location.circle"
        case .age: return "clock"
        case .callsign: return "textformat"
        case .affiliation: return "shield.fill"
        case .category: return "square.grid.2x2"
        }
    }
}

// MARK: - Filter Criteria

final class CoTFilterCriteria: ObservableObject {
    // Search
    @Published var searchText: String = ""

    // Affiliation Filters
    @Published var selectedAffiliations: Set<CoTAffiliation> = Set(CoTAffiliation.allCases)

    // Category Filters
    @Published var selectedCategories: Set<CoTCategory> = Set(CoTCategory.allCases)

    // Distance Filter (in meters)
    @Published var minDistance: Double = 0
    @Published var maxDistance: Double = 50000 // 50km default
    @Published var distanceEnabled: Bool = false

    // Age Filter (in seconds)
    @Published var minAge: Double = 0
    @Published var maxAge: Double = 3600 // 1 hour default
    @Published var ageEnabled: Bool = false

    // Sort Options
    @Published var sortBy: CoTSortOption = .distance
    @Published var sortAscending: Bool = true

    // Team Filter
    @Published var selectedTeams: Set<String> = []
    @Published var teamFilterEnabled: Bool = false

    // Stale Units
    @Published var showStaleUnits: Bool = true

    // MARK: - Computed Properties

    var isFiltering: Bool {
        !searchText.isEmpty ||
        selectedAffiliations.count != CoTAffiliation.allCases.count ||
        selectedCategories.count != CoTCategory.allCases.count ||
        distanceEnabled ||
        ageEnabled ||
        teamFilterEnabled ||
        !showStaleUnits
    }

    var activeFilterCount: Int {
        var count = 0
        if !searchText.isEmpty { count += 1 }
        if selectedAffiliations.count != CoTAffiliation.allCases.count { count += 1 }
        if selectedCategories.count != CoTCategory.allCases.count { count += 1 }
        if distanceEnabled { count += 1 }
        if ageEnabled { count += 1 }
        if teamFilterEnabled { count += 1 }
        if !showStaleUnits { count += 1 }
        return count
    }

    // MARK: - Quick Filter Presets

    func applyQuickFilter(_ preset: QuickFilterPreset) {
        switch preset {
        case .all:
            resetFilters()
        case .friendlyOnly:
            selectedAffiliations = [.friendly, .assumedFriend]
            selectedCategories = Set(CoTCategory.allCases)
        case .hostileOnly:
            selectedAffiliations = [.hostile, .suspect]
            selectedCategories = Set(CoTCategory.allCases)
        case .nearby:
            distanceEnabled = true
            maxDistance = 5000 // 5km
        case .recent:
            ageEnabled = true
            maxAge = 300 // 5 minutes
        case .groundUnits:
            selectedCategories = [.ground]
            selectedAffiliations = Set(CoTAffiliation.allCases)
        case .airUnits:
            selectedCategories = [.air]
            selectedAffiliations = Set(CoTAffiliation.allCases)
        }
    }

    func resetFilters() {
        searchText = ""
        selectedAffiliations = Set(CoTAffiliation.allCases)
        selectedCategories = Set(CoTCategory.allCases)
        distanceEnabled = false
        ageEnabled = false
        teamFilterEnabled = false
        showStaleUnits = true
        sortBy = .distance
        sortAscending = true
    }

    // MARK: - Filter State Persistence

    func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "cot_filter_criteria")
        }
    }

    static func loadFromUserDefaults() -> CoTFilterCriteria {
        if let data = UserDefaults.standard.data(forKey: "cot_filter_criteria"),
           let criteria = try? JSONDecoder().decode(CoTFilterCriteria.self, from: data) {
            return criteria
        }
        return CoTFilterCriteria()
    }
}

// MARK: - Codable Conformance

extension CoTFilterCriteria: Codable {
    enum CodingKeys: String, CodingKey {
        case searchText
        case selectedAffiliations
        case selectedCategories
        case minDistance
        case maxDistance
        case distanceEnabled
        case minAge
        case maxAge
        case ageEnabled
        case sortBy
        case sortAscending
        case selectedTeams
        case teamFilterEnabled
        case showStaleUnits
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(searchText, forKey: .searchText)
        try container.encode(Array(selectedAffiliations), forKey: .selectedAffiliations)
        try container.encode(Array(selectedCategories), forKey: .selectedCategories)
        try container.encode(minDistance, forKey: .minDistance)
        try container.encode(maxDistance, forKey: .maxDistance)
        try container.encode(distanceEnabled, forKey: .distanceEnabled)
        try container.encode(minAge, forKey: .minAge)
        try container.encode(maxAge, forKey: .maxAge)
        try container.encode(ageEnabled, forKey: .ageEnabled)
        try container.encode(sortBy, forKey: .sortBy)
        try container.encode(sortAscending, forKey: .sortAscending)
        try container.encode(Array(selectedTeams), forKey: .selectedTeams)
        try container.encode(teamFilterEnabled, forKey: .teamFilterEnabled)
        try container.encode(showStaleUnits, forKey: .showStaleUnits)
    }

    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        searchText = try container.decode(String.self, forKey: .searchText)
        selectedAffiliations = Set(try container.decode([CoTAffiliation].self, forKey: .selectedAffiliations))
        selectedCategories = Set(try container.decode([CoTCategory].self, forKey: .selectedCategories))
        minDistance = try container.decode(Double.self, forKey: .minDistance)
        maxDistance = try container.decode(Double.self, forKey: .maxDistance)
        distanceEnabled = try container.decode(Bool.self, forKey: .distanceEnabled)
        minAge = try container.decode(Double.self, forKey: .minAge)
        maxAge = try container.decode(Double.self, forKey: .maxAge)
        ageEnabled = try container.decode(Bool.self, forKey: .ageEnabled)
        sortBy = try container.decode(CoTSortOption.self, forKey: .sortBy)
        sortAscending = try container.decode(Bool.self, forKey: .sortAscending)
        selectedTeams = Set(try container.decode([String].self, forKey: .selectedTeams))
        teamFilterEnabled = try container.decode(Bool.self, forKey: .teamFilterEnabled)
        showStaleUnits = try container.decode(Bool.self, forKey: .showStaleUnits)
    }
}

// MARK: - Quick Filter Presets

enum QuickFilterPreset: String, CaseIterable, Identifiable {
    case all = "all"
    case friendlyOnly = "friendly"
    case hostileOnly = "hostile"
    case nearby = "nearby"
    case recent = "recent"
    case groundUnits = "ground"
    case airUnits = "air"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All Units"
        case .friendlyOnly: return "Friendly"
        case .hostileOnly: return "Hostile"
        case .nearby: return "Nearby"
        case .recent: return "Recent"
        case .groundUnits: return "Ground"
        case .airUnits: return "Air"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .friendlyOnly: return "shield.fill"
        case .hostileOnly: return "exclamationmark.triangle.fill"
        case .nearby: return "location.circle.fill"
        case .recent: return "clock.fill"
        case .groundUnits: return "car.fill"
        case .airUnits: return "airplane"
        }
    }

    var color: Color {
        switch self {
        case .all: return .white
        case .friendlyOnly: return .cyan
        case .hostileOnly: return .red
        case .nearby: return .green
        case .recent: return .orange
        case .groundUnits: return .brown
        case .airUnits: return .blue
        }
    }
}
