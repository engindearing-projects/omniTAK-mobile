//
//  UnitPreferences.swift
//  OmniTAKMobile
//
//  Centralized unit system preferences for metric/imperial display
//

import Foundation
import SwiftUI

// MARK: - Unit System

enum UnitSystem: String, CaseIterable, Codable {
    case metric = "Metric"
    case imperial = "Imperial"

    var displayName: String {
        return rawValue
    }

    var description: String {
        switch self {
        case .metric:
            return "Kilometers, meters, km/h"
        case .imperial:
            return "Miles, feet, mph"
        }
    }
}

// MARK: - Unit Preferences

class UnitPreferences: ObservableObject {
    static let shared = UnitPreferences()

    @AppStorage("unitSystem") var unitSystem: UnitSystem = .metric

    private init() {}

    // MARK: - Distance Formatting

    /// Format distance with appropriate unit based on preference
    func formatDistance(_ meters: Double, showUnit: Bool = true) -> String {
        switch unitSystem {
        case .metric:
            return formatDistanceMetric(meters, showUnit: showUnit)
        case .imperial:
            return formatDistanceImperial(meters, showUnit: showUnit)
        }
    }

    private func formatDistanceMetric(_ meters: Double, showUnit: Bool) -> String {
        if meters < 1000 {
            let unit = showUnit ? " m" : ""
            return String(format: "%.1f%@", meters, unit)
        } else if meters < 10000 {
            let unit = showUnit ? " km" : ""
            return String(format: "%.2f%@", meters / 1000.0, unit)
        } else {
            let unit = showUnit ? " km" : ""
            return String(format: "%.1f%@", meters / 1000.0, unit)
        }
    }

    private func formatDistanceImperial(_ meters: Double, showUnit: Bool) -> String {
        let feet = meters * 3.28084
        let miles = meters / 1609.344

        if feet < 1000 {
            let unit = showUnit ? " ft" : ""
            return String(format: "%.0f%@", feet, unit)
        } else if miles < 0.1 {
            let unit = showUnit ? " ft" : ""
            return String(format: "%.0f%@", feet, unit)
        } else if miles < 10 {
            let unit = showUnit ? " mi" : ""
            return String(format: "%.2f%@", miles, unit)
        } else {
            let unit = showUnit ? " mi" : ""
            return String(format: "%.1f%@", miles, unit)
        }
    }

    // MARK: - Short Distance (for scale bars, small measurements)

    func formatShortDistance(_ meters: Double) -> (value: String, unit: String) {
        switch unitSystem {
        case .metric:
            if meters >= 1000 {
                let km = meters / 1000
                return (formatNumber(km), "km")
            } else {
                return (formatNumber(meters), "m")
            }
        case .imperial:
            let feet = meters * 3.28084
            let miles = meters / 1609.344

            if miles >= 0.1 {
                return (formatNumber(miles), "mi")
            } else {
                return (formatNumber(feet), "ft")
            }
        }
    }

    private func formatNumber(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 1 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    // MARK: - Speed Formatting

    /// Format speed from meters/second to appropriate unit
    func formatSpeed(_ metersPerSecond: Double, showUnit: Bool = true) -> String {
        switch unitSystem {
        case .metric:
            let kmh = metersPerSecond * 3.6
            let unit = showUnit ? " km/h" : ""
            return String(format: "%.1f%@", kmh, unit)
        case .imperial:
            let mph = metersPerSecond * 2.23694
            let unit = showUnit ? " mph" : ""
            return String(format: "%.1f%@", mph, unit)
        }
    }

    /// Get the speed value converted to user's preferred unit
    func speedValue(_ metersPerSecond: Double) -> Double {
        switch unitSystem {
        case .metric:
            return metersPerSecond * 3.6 // km/h
        case .imperial:
            return metersPerSecond * 2.23694 // mph
        }
    }

    /// Get the speed unit abbreviation
    var speedUnit: String {
        switch unitSystem {
        case .metric:
            return "km/h"
        case .imperial:
            return "mph"
        }
    }

    // MARK: - Altitude Formatting

    /// Format altitude with appropriate unit
    func formatAltitude(_ meters: Double, showUnit: Bool = true) -> String {
        switch unitSystem {
        case .metric:
            let unit = showUnit ? " m" : ""
            return String(format: "%.1f%@", meters, unit)
        case .imperial:
            let feet = meters * 3.28084
            let unit = showUnit ? " ft" : ""
            return String(format: "%.0f%@", feet, unit)
        }
    }

    /// Get altitude value in user's preferred unit
    func altitudeValue(_ meters: Double) -> Double {
        switch unitSystem {
        case .metric:
            return meters
        case .imperial:
            return meters * 3.28084
        }
    }

    /// Get the altitude unit abbreviation
    var altitudeUnit: String {
        switch unitSystem {
        case .metric:
            return "m"
        case .imperial:
            return "ft"
        }
    }

    // MARK: - Area Formatting

    /// Format area with appropriate unit
    func formatArea(_ squareMeters: Double, showUnit: Bool = true) -> String {
        switch unitSystem {
        case .metric:
            return formatAreaMetric(squareMeters, showUnit: showUnit)
        case .imperial:
            return formatAreaImperial(squareMeters, showUnit: showUnit)
        }
    }

    private func formatAreaMetric(_ sqMeters: Double, showUnit: Bool) -> String {
        if sqMeters < 10000 {
            let unit = showUnit ? " m²" : ""
            return String(format: "%.1f%@", sqMeters, unit)
        } else if sqMeters < 1000000 {
            let unit = showUnit ? " ha" : ""
            return String(format: "%.2f%@", sqMeters / 10000.0, unit)
        } else {
            let unit = showUnit ? " km²" : ""
            return String(format: "%.2f%@", sqMeters / 1000000.0, unit)
        }
    }

    private func formatAreaImperial(_ sqMeters: Double, showUnit: Bool) -> String {
        let sqFeet = sqMeters * 10.7639
        let acres = sqMeters / 4046.86
        let sqMiles = sqMeters / 2589988.0

        if sqFeet < 43560 { // Less than 1 acre
            let unit = showUnit ? " ft²" : ""
            return String(format: "%.0f%@", sqFeet, unit)
        } else if acres < 640 { // Less than 1 square mile
            let unit = showUnit ? " ac" : ""
            return String(format: "%.2f%@", acres, unit)
        } else {
            let unit = showUnit ? " mi²" : ""
            return String(format: "%.2f%@", sqMiles, unit)
        }
    }

    // MARK: - Dual Format (shows both units)

    /// Format distance showing both metric and imperial
    func formatDistanceDual(_ meters: Double) -> String {
        let metric = formatDistanceMetric(meters, showUnit: true)
        let imperial = formatDistanceImperial(meters, showUnit: true)
        return "\(metric) (\(imperial))"
    }

    /// Format altitude showing both metric and imperial
    func formatAltitudeDual(_ meters: Double) -> String {
        let metric = String(format: "%.1f m", meters)
        let imperial = String(format: "%.0f ft", meters * 3.28084)
        return "\(metric) (\(imperial))"
    }

    /// Format speed showing both metric and imperial
    func formatSpeedDual(_ metersPerSecond: Double) -> String {
        let kmh = metersPerSecond * 3.6
        let mph = metersPerSecond * 2.23694
        return String(format: "%.1f km/h (%.1f mph)", kmh, mph)
    }
}

// MARK: - Environment Key

private struct UnitPreferencesKey: EnvironmentKey {
    static let defaultValue = UnitPreferences.shared
}

extension EnvironmentValues {
    var unitPreferences: UnitPreferences {
        get { self[UnitPreferencesKey.self] }
        set { self[UnitPreferencesKey.self] = newValue }
    }
}

// MARK: - Convenience Static Methods

/// Static convenience methods for formatting with unit preferences
/// Use these instead of MeasurementCalculator.formatDistance() for user-facing displays
struct UnitFormatter {
    /// Format distance using global unit preferences
    static func distance(_ meters: Double) -> String {
        return UnitPreferences.shared.formatDistance(meters)
    }

    /// Format area using global unit preferences
    static func area(_ squareMeters: Double) -> String {
        return UnitPreferences.shared.formatArea(squareMeters)
    }

    /// Format speed using global unit preferences
    static func speed(_ metersPerSecond: Double) -> String {
        return UnitPreferences.shared.formatSpeed(metersPerSecond)
    }

    /// Format altitude using global unit preferences
    static func altitude(_ meters: Double) -> String {
        return UnitPreferences.shared.formatAltitude(meters)
    }

    /// Format distance showing both metric and imperial
    static func distanceDual(_ meters: Double) -> String {
        return UnitPreferences.shared.formatDistanceDual(meters)
    }

    /// Format altitude showing both metric and imperial
    static func altitudeDual(_ meters: Double) -> String {
        return UnitPreferences.shared.formatAltitudeDual(meters)
    }

    /// Format speed showing both metric and imperial
    static func speedDual(_ metersPerSecond: Double) -> String {
        return UnitPreferences.shared.formatSpeedDual(metersPerSecond)
    }
}
