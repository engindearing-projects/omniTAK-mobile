//
//  GeofenceManager.swift
//  OmniTAKMobile
//
//  Storage and state manager for geofences
//

import Foundation
import CoreLocation

class GeofenceManager: ObservableObject {
    static let shared = GeofenceManager()

    @Published var geofences: [Geofence] = []

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let storageKey = "com.omnitak.geofences.all"

    private init() {
        loadGeofences()
    }

    // MARK: - Load/Save

    func loadGeofences() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        geofences = (try? decoder.decode([Geofence].self, from: data)) ?? []
    }

    func saveGeofences() {
        if let data = try? encoder.encode(geofences) {
            defaults.set(data, forKey: storageKey)
        }
    }

    // MARK: - CRUD Operations

    func addGeofence(_ geofence: Geofence) {
        geofences.append(geofence)
        saveGeofences()
    }

    func updateGeofence(_ geofence: Geofence) {
        if let index = geofences.firstIndex(where: { $0.id == geofence.id }) {
            geofences[index] = geofence
            saveGeofences()
        }
    }

    func deleteGeofence(_ geofence: Geofence) {
        geofences.removeAll { $0.id == geofence.id }
        saveGeofences()
    }

    func toggleGeofence(_ geofence: Geofence) {
        if let index = geofences.firstIndex(where: { $0.id == geofence.id }) {
            geofences[index].isActive.toggle()
            saveGeofences()
        }
    }

    // MARK: - State Updates

    func updateGeofenceEntryState(_ id: UUID, isInside: Bool) {
        guard let index = geofences.firstIndex(where: { $0.id == id }) else { return }

        if isInside && !geofences[index].userInsideGeofence {
            // Entering geofence
            geofences[index].userInsideGeofence = true
            geofences[index].entryTime = Date()
        } else if !isInside && geofences[index].userInsideGeofence {
            // Exiting geofence
            if let entryTime = geofences[index].entryTime {
                let dwellDuration = Date().timeIntervalSince(entryTime)
                geofences[index].totalDwellTime += dwellDuration
            }
            geofences[index].userInsideGeofence = false
            geofences[index].entryTime = nil
        }

        saveGeofences()
    }

    func updateLastTriggered(_ id: UUID) {
        guard let index = geofences.firstIndex(where: { $0.id == id }) else { return }
        geofences[index].lastTriggeredAt = Date()
        saveGeofences()
    }

    // MARK: - Queries

    func getActiveGeofences() -> [Geofence] {
        geofences.filter { $0.isActive }
    }

    func getGeofence(by id: UUID) -> Geofence? {
        geofences.first { $0.id == id }
    }

    // MARK: - Clear

    func clearAllData() {
        geofences.removeAll()
        defaults.removeObject(forKey: storageKey)
    }
}
