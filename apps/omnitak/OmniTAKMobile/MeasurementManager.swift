//
//  MeasurementManager.swift
//  OmniTAKMobile
//
//  State management for measurement tools
//

import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - Measurement Manager

class MeasurementManager: ObservableObject {
    // MARK: - Published Properties

    @Published var isActive: Bool = false
    @Published var currentMeasurementType: MeasurementType?
    @Published var currentMeasurement: Measurement?
    @Published var temporaryPoints: [CLLocationCoordinate2D] = []
    @Published var savedMeasurements: [Measurement] = []
    @Published var rangeRings: [RangeRing] = []
    @Published var rangeRingConfiguration: RangeRingConfiguration = .defaultConfiguration()
    @Published var liveResult: MeasurementResult = .empty()

    // MARK: - Private Properties

    private let persistenceKey = "saved_measurements"
    private let rangeRingsKey = "saved_range_rings"
    private let configurationKey = "range_ring_configuration"

    // MARK: - Initialization

    init() {
        loadSavedData()
    }

    // MARK: - Start Measurement

    func startMeasurement(type: MeasurementType) {
        isActive = true
        currentMeasurementType = type
        temporaryPoints.removeAll()
        currentMeasurement = Measurement(type: type)
        liveResult = .empty()
        print("Started measurement mode: \(type.rawValue)")
    }

    // MARK: - Handle Map Tap

    func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        guard isActive, let type = currentMeasurementType else { return }

        switch type {
        case .distance:
            temporaryPoints.append(coordinate)
            updateLiveResult()
            print("Distance point added (\(temporaryPoints.count) points)")

        case .bearing:
            if temporaryPoints.count < 2 {
                temporaryPoints.append(coordinate)
                updateLiveResult()
                print("Bearing point \(temporaryPoints.count) added")

                if temporaryPoints.count == 2 {
                    // Bearing measurement complete
                    completeMeasurement()
                }
            }

        case .area:
            temporaryPoints.append(coordinate)
            updateLiveResult()
            print("Area point added (\(temporaryPoints.count) points)")

        case .rangeRing:
            if temporaryPoints.isEmpty {
                temporaryPoints = [coordinate]
                createRangeRings(at: coordinate)
                print("Range ring center set")
            }
        }
    }

    // MARK: - Update Live Result

    private func updateLiveResult() {
        guard let type = currentMeasurementType else { return }
        liveResult = MeasurementCalculator.calculate(type: type, points: temporaryPoints)
    }

    // MARK: - Create Range Rings

    private func createRangeRings(at center: CLLocationCoordinate2D) {
        let config = rangeRingConfiguration

        for distance in config.distances {
            let ring = RangeRing(
                center: center,
                radiusMeters: distance,
                color: config.color,
                label: formatRangeRingLabel(distance)
            )
            rangeRings.append(ring)
        }

        saveRangeRings()
        cancelMeasurement()
    }

    private func formatRangeRingLabel(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000.0)
        }
    }

    // MARK: - Complete Measurement

    func completeMeasurement() {
        guard isActive, let type = currentMeasurementType else { return }

        var canComplete = false

        switch type {
        case .distance:
            canComplete = temporaryPoints.count >= 2

        case .bearing:
            canComplete = temporaryPoints.count >= 2

        case .area:
            canComplete = temporaryPoints.count >= 3

        case .rangeRing:
            canComplete = !temporaryPoints.isEmpty
        }

        if canComplete {
            var measurement = Measurement(type: type, points: temporaryPoints)
            measurement.result = liveResult
            savedMeasurements.append(measurement)
            saveMeasurements()
            print("Completed \(type.rawValue) measurement")
        } else {
            print("Cannot complete measurement - insufficient points")
        }

        cancelMeasurement()
    }

    // MARK: - Cancel Measurement

    func cancelMeasurement() {
        isActive = false
        currentMeasurementType = nil
        currentMeasurement = nil
        temporaryPoints.removeAll()
        liveResult = .empty()
        print("Measurement cancelled")
    }

    // MARK: - Undo Last Point

    func undoLastPoint() {
        guard isActive, !temporaryPoints.isEmpty else { return }
        temporaryPoints.removeLast()
        updateLiveResult()
        print("Removed last point (\(temporaryPoints.count) points remaining)")
    }

    // MARK: - Clear All Measurements

    func clearAllMeasurements() {
        savedMeasurements.removeAll()
        saveMeasurements()
        print("Cleared all measurements")
    }

    // MARK: - Remove Measurement

    func removeMeasurement(_ measurement: Measurement) {
        savedMeasurements.removeAll { $0.id == measurement.id }
        saveMeasurements()
        print("Removed measurement: \(measurement.name)")
    }

    // MARK: - Clear All Range Rings

    func clearAllRangeRings() {
        rangeRings.removeAll()
        saveRangeRings()
        print("Cleared all range rings")
    }

    // MARK: - Remove Range Ring

    func removeRangeRing(_ ring: RangeRing) {
        rangeRings.removeAll { $0.id == ring.id }
        saveRangeRings()
        print("Removed range ring: \(ring.label)")
    }

    // MARK: - Update Range Ring Configuration

    func updateRangeRingConfiguration(_ config: RangeRingConfiguration) {
        rangeRingConfiguration = config
        saveConfiguration()
    }

    func addCustomRangeRingDistance(_ distance: Double) {
        if !rangeRingConfiguration.distances.contains(distance) {
            rangeRingConfiguration.distances.append(distance)
            rangeRingConfiguration.distances.sort()
            saveConfiguration()
        }
    }

    func removeRangeRingDistance(_ distance: Double) {
        rangeRingConfiguration.distances.removeAll { $0 == distance }
        saveConfiguration()
    }

    // MARK: - Get Instructions

    func getInstructions() -> String {
        guard isActive, let type = currentMeasurementType else {
            return "Select a measurement tool to begin"
        }

        switch type {
        case .distance:
            if temporaryPoints.isEmpty {
                return "Tap map to start distance measurement"
            } else if temporaryPoints.count == 1 {
                return "Tap map to add more points (1 point placed)"
            } else {
                return "Tap to add points or press Complete (\(temporaryPoints.count) points)"
            }

        case .bearing:
            if temporaryPoints.isEmpty {
                return "Tap map to set start point"
            } else if temporaryPoints.count == 1 {
                return "Tap map to set end point"
            } else {
                return "Bearing measurement complete"
            }

        case .area:
            if temporaryPoints.isEmpty {
                return "Tap map to start polygon"
            } else if temporaryPoints.count < 3 {
                return "Tap to add vertices (need \(3 - temporaryPoints.count) more)"
            } else {
                return "Tap to add vertices or press Complete (\(temporaryPoints.count) vertices)"
            }

        case .rangeRing:
            if temporaryPoints.isEmpty {
                return "Tap map to set range ring center"
            } else {
                return "Range rings created"
            }
        }
    }

    // MARK: - Can Complete

    func canComplete() -> Bool {
        guard isActive, let type = currentMeasurementType else { return false }

        switch type {
        case .distance:
            return temporaryPoints.count >= 2

        case .bearing:
            return temporaryPoints.count >= 2

        case .area:
            return temporaryPoints.count >= 3

        case .rangeRing:
            return !temporaryPoints.isEmpty
        }
    }

    // MARK: - Get Temporary Overlay

    func getTemporaryOverlay() -> MKOverlay? {
        guard isActive, let type = currentMeasurementType else { return nil }

        switch type {
        case .distance:
            if temporaryPoints.count >= 2 {
                return MKPolyline(coordinates: temporaryPoints, count: temporaryPoints.count)
            }

        case .bearing:
            if temporaryPoints.count >= 2 {
                return MKPolyline(coordinates: temporaryPoints, count: temporaryPoints.count)
            }

        case .area:
            if temporaryPoints.count >= 3 {
                return MKPolygon(coordinates: temporaryPoints, count: temporaryPoints.count)
            } else if temporaryPoints.count >= 2 {
                return MKPolyline(coordinates: temporaryPoints, count: temporaryPoints.count)
            }

        case .rangeRing:
            // Range rings are rendered separately
            break
        }

        return nil
    }

    // MARK: - Get Temporary Annotations

    func getTemporaryAnnotations() -> [MKPointAnnotation] {
        guard isActive else { return [] }

        return temporaryPoints.enumerated().map { index, coordinate in
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "Point \(index + 1)"

            if let type = currentMeasurementType {
                switch type {
                case .bearing:
                    if index == 0 {
                        annotation.title = "Start"
                    } else if index == 1 {
                        annotation.title = "End"
                    }
                case .area:
                    annotation.title = "Vertex \(index + 1)"
                default:
                    break
                }
            }

            return annotation
        }
    }

    // MARK: - Persistence

    private func saveMeasurements() {
        if let encoded = try? JSONEncoder().encode(savedMeasurements) {
            UserDefaults.standard.set(encoded, forKey: persistenceKey)
        }
    }

    private func saveRangeRings() {
        if let encoded = try? JSONEncoder().encode(rangeRings) {
            UserDefaults.standard.set(encoded, forKey: rangeRingsKey)
        }
    }

    private func saveConfiguration() {
        if let encoded = try? JSONEncoder().encode(rangeRingConfiguration) {
            UserDefaults.standard.set(encoded, forKey: configurationKey)
        }
    }

    private func loadSavedData() {
        // Load measurements
        if let data = UserDefaults.standard.data(forKey: persistenceKey),
           let measurements = try? JSONDecoder().decode([Measurement].self, from: data) {
            savedMeasurements = measurements
        }

        // Load range rings
        if let data = UserDefaults.standard.data(forKey: rangeRingsKey),
           let rings = try? JSONDecoder().decode([RangeRing].self, from: data) {
            rangeRings = rings
        }

        // Load configuration
        if let data = UserDefaults.standard.data(forKey: configurationKey),
           let config = try? JSONDecoder().decode(RangeRingConfiguration.self, from: data) {
            rangeRingConfiguration = config
        }
    }

    // MARK: - Copy to Clipboard

    func copyResultToClipboard() -> String {
        guard let type = currentMeasurementType else { return "" }

        var text = ""

        switch type {
        case .distance:
            if let meters = liveResult.distanceMeters {
                text = "Distance: \(MeasurementCalculator.formatDistance(meters))\n"
                text += "Miles: \(String(format: "%.3f mi", liveResult.distanceMiles ?? 0))\n"
                text += "Nautical Miles: \(String(format: "%.3f NM", liveResult.distanceNauticalMiles ?? 0))\n"
                text += "Feet: \(String(format: "%.1f ft", liveResult.distanceFeet ?? 0))"
            }

        case .bearing:
            if let degrees = liveResult.bearingDegrees {
                text = "Bearing: \(MeasurementCalculator.formatBearing(degrees))\n"
                text += "Mils: \(String(format: "%.0f mil", liveResult.bearingMils ?? 0))\n"
                text += "Back Bearing: \(String(format: "%.1f\u{00B0}", liveResult.backBearingDegrees ?? 0))"

                if let meters = liveResult.distanceMeters {
                    text += "\nDistance: \(MeasurementCalculator.formatDistance(meters))"
                }
            }

        case .area:
            if let sqMeters = liveResult.areaSquareMeters {
                text = "Area: \(MeasurementCalculator.formatArea(sqMeters))\n"
                text += "Acres: \(String(format: "%.3f ac", liveResult.areaAcres ?? 0))\n"
                text += "Hectares: \(String(format: "%.3f ha", liveResult.areaHectares ?? 0))\n"
                text += "Square Miles: \(String(format: "%.6f mi\u{00B2}", liveResult.areaSquareMiles ?? 0))"

                if let perimeter = liveResult.perimeterMeters {
                    text += "\nPerimeter: \(MeasurementCalculator.formatDistance(perimeter))"
                }
            }

        case .rangeRing:
            text = "Range Ring Center\n"
            if let center = temporaryPoints.first {
                text += "Location: \(center.formatDecimalDegrees())\n"
                text += "Rings: \(rangeRingConfiguration.distances.map { formatRangeRingLabel($0) }.joined(separator: ", "))"
            }
        }

        return text
    }
}
