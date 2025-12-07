//
//  ADSBModels.swift
//  OmniTAKMobile
//
//  ADS-B aircraft data models for flight tracking
//

import Foundation
import CoreLocation
import MapKit
import SwiftUI

// MARK: - ADS-B Provider Types

enum ADSBProvider: String, Codable, CaseIterable, Identifiable {
    case openSky = "opensky"
    case adsbExchange = "adsbexchange"
    case adsbLol = "adsblol"
    case flightRadar24 = "flightradar24"
    case flightAware = "flightaware"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openSky: return "OpenSky Network"
        case .adsbExchange: return "ADS-B Exchange"
        case .adsbLol: return "ADSB.lol"
        case .flightRadar24: return "FlightRadar24"
        case .flightAware: return "FlightAware"
        case .custom: return "Custom Source"
        }
    }

    var icon: String {
        switch self {
        case .openSky: return "globe.americas"
        case .adsbExchange: return "antenna.radiowaves.left.and.right"
        case .adsbLol: return "heart.circle"
        case .flightRadar24: return "dot.radiowaves.right"
        case .flightAware: return "airplane.circle"
        case .custom: return "link"
        }
    }

    var color: Color {
        switch self {
        case .openSky: return .blue
        case .adsbExchange: return .orange
        case .adsbLol: return .pink
        case .flightRadar24: return .yellow
        case .flightAware: return .green
        case .custom: return .purple
        }
    }

    var description: String {
        switch self {
        case .openSky: return "Academic network, free tier available"
        case .adsbExchange: return "Community-driven, unfiltered data"
        case .adsbLol: return "Free community aggregator"
        case .flightRadar24: return "Most popular, requires API key"
        case .flightAware: return "Professional aviation data"
        case .custom: return "Local receiver or custom feed"
        }
    }

    var hasFreeTier: Bool {
        switch self {
        case .openSky, .adsbLol: return true
        case .adsbExchange, .flightRadar24, .flightAware, .custom: return false
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .adsbLol: return false
        case .openSky: return false // Optional but enhances
        case .adsbExchange, .flightRadar24, .flightAware: return true
        case .custom: return false
        }
    }

    var apiKeyLabel: String {
        switch self {
        case .openSky: return "Username & Password"
        case .adsbExchange: return "RapidAPI Key"
        case .flightRadar24: return "API Key"
        case .flightAware: return "API Key"
        case .adsbLol, .custom: return ""
        }
    }

    var signupURL: String? {
        switch self {
        case .openSky: return "https://opensky-network.org/index.php?option=com_users&view=registration"
        case .adsbExchange: return "https://rapidapi.com/adsbx/api/adsbexchange-com1"
        case .flightRadar24: return "https://www.flightradar24.com/premium"
        case .flightAware: return "https://www.flightaware.com/aeroapi/"
        case .adsbLol, .custom: return nil
        }
    }

    var minimumRefreshSeconds: Int {
        switch self {
        case .openSky: return 10
        case .adsbExchange: return 2
        case .adsbLol: return 5
        case .flightRadar24: return 5
        case .flightAware: return 15
        case .custom: return 1
        }
    }
}

// MARK: - Provider Configuration

struct ADSBProviderConfig: Codable, Identifiable, Equatable {
    var id: String { provider.rawValue }
    var provider: ADSBProvider
    var isEnabled: Bool = false
    var apiKey: String = ""
    var apiSecret: String = ""  // For OpenSky password or secondary auth
    var customURL: String = ""  // For custom provider
    var priority: Int = 0       // Lower = higher priority for fallback

    var isConfigured: Bool {
        switch provider {
        case .openSky, .adsbLol:
            return true  // Works without API key
        case .adsbExchange, .flightRadar24, .flightAware:
            return !apiKey.isEmpty
        case .custom:
            return !customURL.isEmpty
        }
    }

    var hasCredentials: Bool {
        !apiKey.isEmpty
    }

    static func defaultConfigs() -> [ADSBProviderConfig] {
        [
            ADSBProviderConfig(provider: .openSky, isEnabled: true, priority: 0),
            ADSBProviderConfig(provider: .adsbLol, isEnabled: false, priority: 1),
            ADSBProviderConfig(provider: .adsbExchange, isEnabled: false, priority: 2),
            ADSBProviderConfig(provider: .flightRadar24, isEnabled: false, priority: 3),
            ADSBProviderConfig(provider: .flightAware, isEnabled: false, priority: 4),
            ADSBProviderConfig(provider: .custom, isEnabled: false, priority: 5),
        ]
    }
}

// MARK: - Aircraft Model

struct Aircraft: Identifiable, Equatable {
    let id: String  // ICAO24 address
    let callsign: String
    let originCountry: String
    let coordinate: CLLocationCoordinate2D
    let altitude: Double  // meters
    let velocity: Double  // m/s
    let heading: Double   // degrees from north
    let verticalRate: Double  // m/s
    let onGround: Bool
    let lastUpdate: Date

    var altitudeFeet: Int {
        Int(altitude * 3.28084)
    }

    var speedKnots: Int {
        Int(velocity * 1.94384)
    }

    var speedMPH: Int {
        Int(velocity * 2.23694)
    }

    var formattedAltitude: String {
        if onGround {
            return "Ground"
        }
        return "\(altitudeFeet.formatted()) ft"
    }

    var formattedSpeed: String {
        "\(speedKnots) kts"
    }

    var climbDescendIndicator: String {
        if verticalRate > 1 {
            return "↑"
        } else if verticalRate < -1 {
            return "↓"
        }
        return "→"
    }

    static func == (lhs: Aircraft, rhs: Aircraft) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - OpenSky API Response

struct OpenSkyResponse: Codable {
    let time: Int
    let states: [[OpenSkyState]]?
}

enum OpenSkyState: Codable {
    case string(String)
    case double(Double)
    case bool(Bool)
    case int(Int)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case .double(let value): return value
        case .int(let value): return Double(value)
        default: return nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
}

// MARK: - Traffic Settings

struct ADSBTrafficSettings: Codable {
    var isEnabled: Bool = false
    var radiusNM: Double = 50  // Nautical miles
    var useCurrentLocation: Bool = true
    var customZipCode: String = ""
    var customLatitude: Double?
    var customLongitude: Double?
    var refreshIntervalSeconds: Int = 10
    var showOnGround: Bool = false
    var minAltitudeFeet: Int = 0
    var maxAltitudeFeet: Int = 60000

    // Multi-provider support
    var providers: [ADSBProviderConfig] = ADSBProviderConfig.defaultConfigs()
    var activeProvider: ADSBProvider = .openSky

    // Legacy API Authentication (migrated to provider configs)
    var apiUsername: String = ""
    var apiPassword: String = ""

    var hasAPICredentials: Bool {
        activeProviderConfig?.hasCredentials ?? false
    }

    var activeProviderConfig: ADSBProviderConfig? {
        providers.first { $0.provider == activeProvider }
    }

    var enabledProviders: [ADSBProviderConfig] {
        providers.filter { $0.isEnabled && $0.isConfigured }
    }

    mutating func updateProvider(_ config: ADSBProviderConfig) {
        if let index = providers.firstIndex(where: { $0.provider == config.provider }) {
            providers[index] = config
        }
    }

    mutating func migrateOldCredentials() {
        // Migrate old OpenSky credentials to new provider config
        if !apiUsername.isEmpty || !apiPassword.isEmpty {
            if let index = providers.firstIndex(where: { $0.provider == .openSky }) {
                providers[index].apiKey = apiUsername
                providers[index].apiSecret = apiPassword
                providers[index].isEnabled = true
            }
            apiUsername = ""
            apiPassword = ""
        }
    }

    var radiusKM: Double {
        radiusNM * 1.852
    }

    var radiusDegrees: Double {
        // Approximate conversion: 1 degree ≈ 111 km at equator
        radiusKM / 111.0
    }

    var minimumRefreshInterval: Int {
        activeProvider.minimumRefreshSeconds
    }

    var requestsPerDay: String {
        switch activeProvider {
        case .openSky:
            return hasAPICredentials ? "~4,000" : "~100"
        case .adsbExchange:
            return "Varies by plan"
        case .adsbLol:
            return "Unlimited"
        case .flightRadar24, .flightAware:
            return "Per subscription"
        case .custom:
            return "Unlimited"
        }
    }
}
