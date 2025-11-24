//
//  PointDropperService.swift
//  OmniTAKMobile
//
//  Service for managing point markers, CRUD operations, and CoT broadcasting
//

import Foundation
import Combine
import CoreLocation
import MapKit

// MARK: - Point Dropper Service

/// Centralized service for point marker operations
class PointDropperService: ObservableObject {
    // Published properties
    @Published var markers: [PointMarker] = []
    @Published var selectedMarker: PointMarker?
    @Published var dropperState: PointDropperState = .idle
    @Published var currentAffiliation: MarkerAffiliation = .hostile
    @Published var recentMarkers: [PointMarker] = []

    // TAK Service reference for broadcasting
    private weak var takService: TAKService?

    // Persistence
    private let persistence: PointMarkerPersistence
    private var cancellables = Set<AnyCancellable>()

    // Events
    var onEvent: ((PointDropperEvent) -> Void)?

    // Configuration
    var maxRecentMarkers: Int = 10
    var defaultStaleTime: TimeInterval = 3600  // 1 hour

    // Singleton instance
    static let shared = PointDropperService()

    init(persistence: PointMarkerPersistence = PointMarkerPersistence()) {
        self.persistence = persistence
        loadAllMarkers()
    }

    // MARK: - Configuration

    func configure(takService: TAKService) {
        self.takService = takService
    }

    // MARK: - Marker CRUD Operations

    /// Create a new point marker
    @discardableResult
    func createMarker(
        name: String,
        affiliation: MarkerAffiliation,
        coordinate: CLLocationCoordinate2D,
        altitude: Double? = nil,
        remarks: String? = nil,
        saluteReport: SALUTEReport? = nil,
        createdBy: String? = nil,
        broadcast: Bool = false
    ) -> PointMarker {
        let marker = PointMarker(
            name: name,
            affiliation: affiliation,
            coordinate: coordinate,
            altitude: altitude,
            remarks: remarks,
            saluteReport: saluteReport,
            createdBy: createdBy,
            isBroadcast: broadcast
        )

        markers.append(marker)
        updateRecentMarkers(marker)
        saveMarkers()

        #if DEBUG
        print("📍 Created \(affiliation.displayName) marker: \(name) at (\(coordinate.latitude), \(coordinate.longitude))")
        #endif

        // Broadcast if requested
        if broadcast {
            broadcastMarker(marker)
        }

        onEvent?(.markerCreated(marker))
        return marker
    }

    /// Quick drop marker at location with current affiliation
    @discardableResult
    func quickDrop(at coordinate: CLLocationCoordinate2D, name: String? = nil, broadcast: Bool = false) -> PointMarker {
        let markerName = name ?? generateMarkerName(for: currentAffiliation)
        return createMarker(
            name: markerName,
            affiliation: currentAffiliation,
            coordinate: coordinate,
            broadcast: broadcast
        )
    }

    /// Get marker by ID
    func getMarker(id: UUID) -> PointMarker? {
        return markers.first { $0.id == id }
    }

    /// Get marker by UID
    func getMarker(uid: String) -> PointMarker? {
        return markers.first { $0.uid == uid }
    }

    /// Update an existing marker
    func updateMarker(_ marker: PointMarker) {
        if let index = markers.firstIndex(where: { $0.id == marker.id }) {
            var updatedMarker = marker
            updatedMarker.touch()
            markers[index] = updatedMarker
            updateRecentMarkers(updatedMarker)
            saveMarkers()

            #if DEBUG
            print("✏️ Updated marker: \(marker.name)")
            #endif
            onEvent?(.markerUpdated(updatedMarker))
        }
    }

    /// Delete a marker
    func deleteMarker(_ marker: PointMarker) {
        markers.removeAll { $0.id == marker.id }
        recentMarkers.removeAll { $0.id == marker.id }
        saveMarkers()

        #if DEBUG
        print("🗑️ Deleted marker: \(marker.name)")
        #endif
        onEvent?(.markerDeleted(marker))
    }

    /// Delete marker by ID
    func deleteMarker(id: UUID) {
        if let marker = getMarker(id: id) {
            deleteMarker(marker)
        }
    }

    /// Delete all markers
    func deleteAllMarkers() {
        markers.removeAll()
        recentMarkers.removeAll()
        saveMarkers()
        #if DEBUG
        print("🗑️ Deleted all markers")
        #endif
    }

    /// Delete markers by affiliation
    func deleteMarkers(affiliation: MarkerAffiliation) {
        let count = markers.filter { $0.affiliation == affiliation }.count
        markers.removeAll { $0.affiliation == affiliation }
        recentMarkers.removeAll { $0.affiliation == affiliation }
        saveMarkers()
        #if DEBUG
        print("🗑️ Deleted \(count) \(affiliation.displayName) markers")
        #endif
    }

    // MARK: - SALUTE Report

    /// Add or update SALUTE report for a marker
    func setSALUTEReport(_ report: SALUTEReport, for markerId: UUID) {
        if let index = markers.firstIndex(where: { $0.id == markerId }) {
            markers[index].saluteReport = report
            markers[index].touch()
            saveMarkers()

            let marker = markers[index]
            print("📋 Added SALUTE report to marker: \(marker.name)")
            onEvent?(.saluteReportGenerated(marker))
        }
    }

    /// Generate SALUTE report text for a marker
    func generateSALUTEReportText(for marker: PointMarker) -> String {
        guard let report = marker.saluteReport else {
            return "No SALUTE report available"
        }
        return report.formattedReport
    }

    // MARK: - Broadcasting

    /// Broadcast a marker as CoT message
    func broadcastMarker(_ marker: PointMarker) {
        guard let takService = takService else {
            print("❌ TAKService not configured for broadcasting")
            return
        }

        let xml = MarkerCoTGenerator.generateCoT(for: marker, staleTime: defaultStaleTime)

        if takService.sendCoT(xml: xml) {
            // Update marker to mark as broadcast
            if let index = markers.firstIndex(where: { $0.id == marker.id }) {
                markers[index].isBroadcast = true
                markers[index].touch()
                saveMarkers()
            }

            #if DEBUG
            print("📤 Broadcast marker: \(marker.name)")
            #endif
            onEvent?(.markerBroadcast(marker))
        } else {
            print("❌ Failed to broadcast marker: \(marker.name)")
        }
    }

    /// Broadcast all markers
    func broadcastAllMarkers() {
        for marker in markers {
            broadcastMarker(marker)
        }
    }

    /// Broadcast markers by affiliation
    func broadcastMarkers(affiliation: MarkerAffiliation) {
        let filteredMarkers = markers.filter { $0.affiliation == affiliation }
        for marker in filteredMarkers {
            broadcastMarker(marker)
        }
    }

    // MARK: - Filtering and Sorting

    /// Get markers by affiliation
    func markers(for affiliation: MarkerAffiliation) -> [PointMarker] {
        return markers.filter { $0.affiliation == affiliation }
    }

    /// Get markers sorted by timestamp (newest first)
    func markersSortedByTime() -> [PointMarker] {
        return markers.sorted { $0.timestamp > $1.timestamp }
    }

    /// Get markers sorted by distance from a location
    func markersSortedByDistance(from location: CLLocation) -> [PointMarker] {
        return markers.sorted { marker1, marker2 in
            let loc1 = CLLocation(latitude: marker1.coordinate.latitude,
                                longitude: marker1.coordinate.longitude)
            let loc2 = CLLocation(latitude: marker2.coordinate.latitude,
                                longitude: marker2.coordinate.longitude)

            return location.distance(from: loc1) < location.distance(from: loc2)
        }
    }

    /// Get markers within a radius
    func markersNear(location: CLLocation, radius: CLLocationDistance) -> [PointMarker] {
        return markers.filter { marker in
            let markerLocation = CLLocation(
                latitude: marker.coordinate.latitude,
                longitude: marker.coordinate.longitude
            )
            return location.distance(from: markerLocation) <= radius
        }
    }

    /// Search markers by name
    func searchMarkers(query: String) -> [PointMarker] {
        guard !query.isEmpty else { return markers }

        return markers.filter { marker in
            marker.name.localizedCaseInsensitiveContains(query) ||
            (marker.remarks?.localizedCaseInsensitiveContains(query) ?? false) ||
            marker.affiliation.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Map Annotations

    /// Get all marker annotations for map display
    func getAllAnnotations() -> [PointMarkerAnnotation] {
        return markers.map { $0.createAnnotation() }
    }

    /// Get annotations filtered by affiliation
    func getAnnotations(for affiliation: MarkerAffiliation) -> [PointMarkerAnnotation] {
        return markers
            .filter { $0.affiliation == affiliation }
            .map { $0.createAnnotation() }
    }

    /// Get MKOverlay for marker (circle indicator)
    func getOverlay(for marker: PointMarker, radius: CLLocationDistance = 50) -> MKCircle {
        return MKCircle(center: marker.coordinate, radius: radius)
    }

    // MARK: - State Management

    func startDropping(affiliation: MarkerAffiliation) {
        currentAffiliation = affiliation
        dropperState = .placing
        #if DEBUG
        print("🎯 Point dropper active: \(affiliation.displayName)")
        #endif
    }

    func cancelDropping() {
        dropperState = .idle
        print("❌ Point dropper cancelled")
    }

    func selectMarker(_ marker: PointMarker) {
        selectedMarker = marker
        dropperState = .editing(marker)
    }

    func deselectMarker() {
        selectedMarker = nil
        dropperState = .idle
    }

    // MARK: - Helper Methods

    private func generateMarkerName(for affiliation: MarkerAffiliation) -> String {
        let count = markers.filter { $0.affiliation == affiliation }.count + 1
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HHmm"
        let timeStr = dateFormatter.string(from: Date())

        return "\(affiliation.shortCode)-\(count)-\(timeStr)"
    }

    private func updateRecentMarkers(_ marker: PointMarker) {
        // Remove if already exists
        recentMarkers.removeAll { $0.id == marker.id }

        // Add to front
        recentMarkers.insert(marker, at: 0)

        // Trim to max
        if recentMarkers.count > maxRecentMarkers {
            recentMarkers = Array(recentMarkers.prefix(maxRecentMarkers))
        }
    }

    // MARK: - Persistence

    private func loadAllMarkers() {
        markers = persistence.loadMarkers()
        #if DEBUG
        print("📂 Loaded \(markers.count) point markers")
        #endif

        // Populate recent markers from loaded data
        recentMarkers = Array(markersSortedByTime().prefix(maxRecentMarkers))
    }

    private func saveMarkers() {
        persistence.saveMarkers(markers)
    }

    // MARK: - Statistics

    var markerCount: Int {
        markers.count
    }

    var hostileCount: Int {
        markers.filter { $0.affiliation == .hostile }.count
    }

    var friendlyCount: Int {
        markers.filter { $0.affiliation == .friendly }.count
    }

    var unknownCount: Int {
        markers.filter { $0.affiliation == .unknown }.count
    }

    var neutralCount: Int {
        markers.filter { $0.affiliation == .neutral }.count
    }

    func markerCountByAffiliation() -> [MarkerAffiliation: Int] {
        var counts: [MarkerAffiliation: Int] = [:]
        for affiliation in MarkerAffiliation.allCases {
            counts[affiliation] = markers.filter { $0.affiliation == affiliation }.count
        }
        return counts
    }

    var broadcastedCount: Int {
        markers.filter { $0.isBroadcast }.count
    }

    var withSALUTECount: Int {
        markers.filter { $0.saluteReport != nil }.count
    }
}

// MARK: - Point Marker Persistence

/// Handles saving and loading point markers using UserDefaults
class PointMarkerPersistence {
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let markersKey = "PointDropperService.markers"

    // MARK: - Markers

    func saveMarkers(_ markers: [PointMarker]) {
        do {
            let data = try encoder.encode(markers)
            userDefaults.set(data, forKey: markersKey)
            #if DEBUG
            print("💾 Saved \(markers.count) point markers to UserDefaults")
            #endif
        } catch {
            print("❌ Failed to save point markers: \(error)")
        }
    }

    func loadMarkers() -> [PointMarker] {
        guard let data = userDefaults.data(forKey: markersKey) else {
            return []
        }

        do {
            let markers = try decoder.decode([PointMarker].self, from: data)
            return markers
        } catch {
            print("❌ Failed to load point markers: \(error)")
            return []
        }
    }

    // MARK: - Clear All

    func clearAll() {
        userDefaults.removeObject(forKey: markersKey)
        #if DEBUG
        print("🗑️ Cleared all point marker data from UserDefaults")
        #endif
    }
}
