//
//  AppModePreferences.swift
//  OmniTAKMobile
//
//  App mode/persona system for different use cases:
//  Tactical, Fire/Rescue, SAR, Civilian
//

import SwiftUI

// MARK: - App Mode

enum AppMode: String, CaseIterable, Codable, Identifiable {
    case tactical = "tactical"
    case fireRescue = "fire_rescue"
    case sar = "sar"
    case civilian = "civilian"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tactical: return "Tactical"
        case .fireRescue: return "Fire/Rescue"
        case .sar: return "SAR"
        case .civilian: return "Civilian"
        }
    }

    var subtitle: String {
        switch self {
        case .tactical: return "Military & Law Enforcement"
        case .fireRescue: return "Firefighting & EMS"
        case .sar: return "Search & Rescue"
        case .civilian: return "General Use"
        }
    }

    var icon: String {
        switch self {
        case .tactical: return "shield.checkered"
        case .fireRescue: return "flame.fill"
        case .sar: return "binoculars.fill"
        case .civilian: return "figure.wave"
        }
    }

    var accentColor: Color {
        switch self {
        case .tactical: return Color(hex: "#FFFC00")  // TAK Yellow
        case .fireRescue: return Color(hex: "#FF4444")  // Fire Red
        case .sar: return Color(hex: "#FF8C00")  // SAR Orange
        case .civilian: return Color(hex: "#4A90D9")  // Calm Blue
        }
    }

    var secondaryColor: Color {
        switch self {
        case .tactical: return Color(hex: "#00FF00")  // Mil Green
        case .fireRescue: return Color(hex: "#FFD700")  // Safety Yellow
        case .sar: return Color(hex: "#32CD32")  // Lime Green
        case .civilian: return Color(hex: "#50C878")  // Emerald
        }
    }

    /// Terminology adaptations per mode
    var terminology: ModeTerminology {
        switch self {
        case .tactical:
            return ModeTerminology(
                friendlyMarker: "Friendly",
                hostileMarker: "Hostile",
                unknownMarker: "Unknown",
                neutralMarker: "Neutral",
                waypoint: "Waypoint",
                team: "Unit",
                base: "FOB"
            )
        case .fireRescue:
            return ModeTerminology(
                friendlyMarker: "Crew",
                hostileMarker: "Hazard",
                unknownMarker: "Unknown",
                neutralMarker: "Resource",
                waypoint: "Marker",
                team: "Engine",
                base: "ICP"
            )
        case .sar:
            return ModeTerminology(
                friendlyMarker: "Searcher",
                hostileMarker: "Hazard",
                unknownMarker: "Clue",
                neutralMarker: "POI",
                waypoint: "Waypoint",
                team: "Team",
                base: "Base Camp"
            )
        case .civilian:
            return ModeTerminology(
                friendlyMarker: "Friend",
                hostileMarker: "Caution",
                unknownMarker: "Unknown",
                neutralMarker: "Point",
                waypoint: "Pin",
                team: "Group",
                base: "Home"
            )
        }
    }
}

// MARK: - Mode Terminology

struct ModeTerminology {
    let friendlyMarker: String
    let hostileMarker: String
    let unknownMarker: String
    let neutralMarker: String
    let waypoint: String
    let team: String
    let base: String
}

// MARK: - App Mode Manager

class AppModeManager: ObservableObject {
    static let shared = AppModeManager()

    @AppStorage("appMode") private var storedMode: String = AppMode.tactical.rawValue

    @Published var currentMode: AppMode {
        didSet {
            storedMode = currentMode.rawValue
            NotificationCenter.default.post(name: .appModeChanged, object: currentMode)
        }
    }

    var accentColor: Color { currentMode.accentColor }
    var secondaryColor: Color { currentMode.secondaryColor }
    var terminology: ModeTerminology { currentMode.terminology }

    private init() {
        self.currentMode = AppMode(rawValue: UserDefaults.standard.string(forKey: "appMode") ?? "tactical") ?? .tactical
    }

    func setMode(_ mode: AppMode) {
        currentMode = mode
    }
}

// MARK: - Notification

extension Notification.Name {
    static let appModeChanged = Notification.Name("appModeChanged")
}
