//
//  CoTFilterManager.swift
//  OmniTAKTest
//
//  CoT filtering logic and event enrichment
//

import Foundation
import CoreLocation
import Combine

// MARK: - CoT Filter Manager

class CoTFilterManager: ObservableObject {
    @Published var filteredEvents: [EnrichedCoTEvent] = []
    @Published var allEvents: [EnrichedCoTEvent] = []

    private var userLocation: CLLocation?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {}

    // MARK: - Update Methods

    /// Update the user's location for distance/bearing calculations
    func updateUserLocation(_ location: CLLocation?) {
        self.userLocation = location
        // Re-enrich all events with new location
        allEvents = allEvents.map { event in
            enrichEvent(event, userLocation: location)
        }
    }

    /// Update events from TAKService
    func updateEvents(_ cotEvents: [CoTEvent], userLocation: CLLocation?) {
        self.userLocation = userLocation

        // Convert CoTEvents to EnrichedCoTEvents
        allEvents = cotEvents.map { event in
            EnrichedCoTEvent(from: event, userLocation: userLocation)
        }
    }

    // MARK: - Filtering

    /// Apply filters to events based on criteria
    func applyFilters(criteria: CoTFilterCriteria) -> [EnrichedCoTEvent] {
        var filtered = allEvents

        // 1. Search Text Filter (callsign or UID)
        if !criteria.searchText.isEmpty {
            let searchLower = criteria.searchText.lowercased()
            filtered = filtered.filter { event in
                event.callsign.lowercased().contains(searchLower) ||
                event.uid.lowercased().contains(searchLower)
            }
        }

        // 2. Affiliation Filter
        if criteria.selectedAffiliations.count != CoTAffiliation.allCases.count {
            filtered = filtered.filter { event in
                criteria.selectedAffiliations.contains(event.affiliation)
            }
        }

        // 3. Category Filter
        if criteria.selectedCategories.count != CoTCategory.allCases.count {
            filtered = filtered.filter { event in
                criteria.selectedCategories.contains(event.category)
            }
        }

        // 4. Distance Filter
        if criteria.distanceEnabled {
            filtered = filtered.filter { event in
                guard let distance = event.distance else { return false }
                return distance >= criteria.minDistance && distance <= criteria.maxDistance
            }
        }

        // 5. Age Filter
        if criteria.ageEnabled {
            filtered = filtered.filter { event in
                event.age >= criteria.minAge && event.age <= criteria.maxAge
            }
        }

        // 6. Team Filter
        if criteria.teamFilterEnabled && !criteria.selectedTeams.isEmpty {
            filtered = filtered.filter { event in
                guard let team = event.team else { return false }
                return criteria.selectedTeams.contains(team)
            }
        }

        // 7. Stale Units Filter
        if !criteria.showStaleUnits {
            filtered = filtered.filter { !$0.isStale }
        }

        // 8. Sorting
        filtered = sortEvents(filtered, by: criteria.sortBy, ascending: criteria.sortAscending)

        return filtered
    }

    // MARK: - Sorting

    private func sortEvents(
        _ events: [EnrichedCoTEvent],
        by sortOption: CoTSortOption,
        ascending: Bool
    ) -> [EnrichedCoTEvent] {
        let sorted: [EnrichedCoTEvent]

        switch sortOption {
        case .distance:
            sorted = events.sorted { (a, b) in
                let distA = a.distance ?? Double.infinity
                let distB = b.distance ?? Double.infinity
                return ascending ? distA < distB : distA > distB
            }
        case .age:
            sorted = events.sorted { (a, b) in
                return ascending ? a.age < b.age : a.age > b.age
            }
        case .callsign:
            sorted = events.sorted { (a, b) in
                return ascending ?
                    a.callsign.lowercased() < b.callsign.lowercased() :
                    a.callsign.lowercased() > b.callsign.lowercased()
            }
        case .affiliation:
            sorted = events.sorted { (a, b) in
                return ascending ?
                    a.affiliation.displayName < b.affiliation.displayName :
                    a.affiliation.displayName > b.affiliation.displayName
            }
        case .category:
            sorted = events.sorted { (a, b) in
                return ascending ?
                    a.category.displayName < b.category.displayName :
                    a.category.displayName > b.category.displayName
            }
        }

        return sorted
    }

    // MARK: - Event Enrichment

    /// Re-enrich an event with updated calculations
    private func enrichEvent(_ event: EnrichedCoTEvent, userLocation: CLLocation?) -> EnrichedCoTEvent {
        var enriched = event

        // Recalculate distance and bearing
        if let userLoc = userLocation {
            let eventLocation = CLLocation(
                latitude: event.coordinate.latitude,
                longitude: event.coordinate.longitude
            )
            enriched.distance = userLoc.distance(from: eventLocation)
            enriched.bearing = calculateBearing(from: userLoc.coordinate, to: event.coordinate)
        } else {
            enriched.distance = nil
            enriched.bearing = nil
        }

        // Update age
        enriched.age = Date().timeIntervalSince(event.timestamp)

        return enriched
    }

    // MARK: - Statistics

    /// Get filter statistics
    func getStatistics(for events: [EnrichedCoTEvent]) -> FilterStatistics {
        let affiliationCounts = Dictionary(grouping: events, by: { $0.affiliation })
            .mapValues { $0.count }

        let categoryCounts = Dictionary(grouping: events, by: { $0.category })
            .mapValues { $0.count }

        let avgDistance = events.compactMap { $0.distance }.reduce(0, +) / Double(max(events.count, 1))
        let avgAge = events.map { $0.age }.reduce(0, +) / Double(max(events.count, 1))

        return FilterStatistics(
            totalCount: events.count,
            affiliationCounts: affiliationCounts,
            categoryCounts: categoryCounts,
            averageDistance: avgDistance,
            averageAge: avgAge
        )
    }

    /// Get all unique teams
    func getAllTeams() -> [String] {
        let teams = allEvents.compactMap { $0.team }
        return Array(Set(teams)).sorted()
    }
}

// MARK: - Filter Statistics

struct FilterStatistics {
    let totalCount: Int
    let affiliationCounts: [CoTAffiliation: Int]
    let categoryCounts: [CoTCategory: Int]
    let averageDistance: Double
    let averageAge: Double

    var formattedAverageDistance: String {
        if averageDistance < 1000 {
            return String(format: "%.0f m", averageDistance)
        } else {
            return String(format: "%.2f km", averageDistance / 1000.0)
        }
    }

    var formattedAverageAge: String {
        if averageAge < 60 {
            return String(format: "%.0fs", averageAge)
        } else if averageAge < 3600 {
            return String(format: "%.0fm", averageAge / 60)
        } else {
            return String(format: "%.1fh", averageAge / 3600)
        }
    }
}

// MARK: - Helper Functions

private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let lat1 = from.latitude * .pi / 180
    let lon1 = from.longitude * .pi / 180
    let lat2 = to.latitude * .pi / 180
    let lon2 = to.longitude * .pi / 180

    let dLon = lon2 - lon1
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let radiansBearing = atan2(y, x)
    let degreesBearing = radiansBearing * 180 / .pi

    return (degreesBearing + 360).truncatingRemainder(dividingBy: 360)
}
