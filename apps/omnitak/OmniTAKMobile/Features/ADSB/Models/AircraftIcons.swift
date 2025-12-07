//
//  AircraftIcons.swift
//  OmniTAKMobile
//
//  Robust aircraft icon system with support for various types, sizes, and models
//

import SwiftUI

// MARK: - Aircraft Category

enum AircraftCategory: String, CaseIterable {
    case commercialJet = "commercial_jet"
    case regionalJet = "regional_jet"
    case turboprop = "turboprop"
    case lightAircraft = "light_aircraft"
    case businessJet = "business_jet"
    case cargoFreighter = "cargo_freighter"
    case helicopter = "helicopter"
    case military = "military"
    case militaryFighter = "military_fighter"
    case militaryTransport = "military_transport"
    case glider = "glider"
    case balloon = "balloon"
    case drone = "drone"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .commercialJet: return "Commercial Jet"
        case .regionalJet: return "Regional Jet"
        case .turboprop: return "Turboprop"
        case .lightAircraft: return "Light Aircraft"
        case .businessJet: return "Business Jet"
        case .cargoFreighter: return "Cargo Freighter"
        case .helicopter: return "Helicopter"
        case .military: return "Military"
        case .militaryFighter: return "Military Fighter"
        case .militaryTransport: return "Military Transport"
        case .glider: return "Glider"
        case .balloon: return "Balloon"
        case .drone: return "Drone/UAV"
        case .unknown: return "Unknown"
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .commercialJet, .cargoFreighter, .militaryTransport:
            return 16
        case .regionalJet, .businessJet, .military:
            return 14
        case .turboprop, .helicopter:
            return 13
        case .lightAircraft, .militaryFighter:
            return 12
        case .glider, .balloon, .drone:
            return 11
        case .unknown:
            return 12
        }
    }

    var baseColor: Color {
        switch self {
        case .commercialJet, .regionalJet:
            return Color(hex: "#4FC3F7") // Light blue
        case .cargoFreighter:
            return Color(hex: "#FFB74D") // Orange
        case .businessJet:
            return Color(hex: "#81C784") // Green
        case .turboprop:
            return Color(hex: "#90CAF9") // Blue
        case .lightAircraft:
            return Color(hex: "#A5D6A7") // Light green
        case .helicopter:
            return Color(hex: "#CE93D8") // Purple
        case .military, .militaryFighter, .militaryTransport:
            return Color(hex: "#EF5350") // Red
        case .glider:
            return Color(hex: "#B0BEC5") // Gray blue
        case .balloon:
            return Color(hex: "#FFCC80") // Light orange
        case .drone:
            return Color(hex: "#FF8A65") // Deep orange
        case .unknown:
            return Color(hex: "#BDBDBD") // Gray
        }
    }
}

// MARK: - Aircraft Size Class

enum AircraftSizeClass: String {
    case heavy = "H"       // A380, B747, B777, A350, etc.
    case large = "L"       // B737, A320, B757, etc.
    case medium = "M"      // Regional jets, turboprops
    case small = "S"       // Light aircraft, GA
    case ultralight = "U"  // Gliders, balloons, drones

    var scaleFactor: CGFloat {
        switch self {
        case .heavy: return 1.4
        case .large: return 1.2
        case .medium: return 1.0
        case .small: return 0.85
        case .ultralight: return 0.7
        }
    }
}

// MARK: - Aircraft Type Detector

struct AircraftTypeDetector {

    // MARK: - Main Detection Method

    static func detectCategory(
        callsign: String,
        velocity: Double,
        altitude: Double,
        verticalRate: Double,
        onGround: Bool,
        originCountry: String
    ) -> AircraftCategory {

        let callsignUpper = callsign.uppercased().trimmingCharacters(in: .whitespaces)

        // Check for helicopters first (distinctive patterns)
        if isHelicopter(callsign: callsignUpper) {
            return .helicopter
        }

        // Check for military
        if let militaryType = detectMilitary(callsign: callsignUpper, originCountry: originCountry) {
            return militaryType
        }

        // Check for cargo/freight
        if isCargoFreighter(callsign: callsignUpper) {
            return .cargoFreighter
        }

        // Use speed and altitude heuristics
        let speedKnots = velocity * 1.94384
        let altFeet = altitude * 3.28084

        // Very slow, low altitude - likely light aircraft or glider
        if speedKnots < 100 && altFeet < 10000 {
            if speedKnots < 50 {
                return .glider
            }
            return .lightAircraft
        }

        // Check for business jet patterns
        if isBusinessJet(callsign: callsignUpper, speedKnots: speedKnots, altFeet: altFeet) {
            return .businessJet
        }

        // Regional speeds and altitudes
        if speedKnots < 350 && altFeet < 30000 {
            // Check for turboprop patterns
            if isTurboprop(callsign: callsignUpper, speedKnots: speedKnots) {
                return .turboprop
            }
            return .regionalJet
        }

        // High speed, high altitude - commercial jet
        if speedKnots > 350 || altFeet > 30000 {
            return .commercialJet
        }

        // Default based on airline prefix
        if isCommercialAirline(callsign: callsignUpper) {
            return .commercialJet
        }

        return .unknown
    }

    // MARK: - Size Class Detection

    static func detectSizeClass(
        category: AircraftCategory,
        callsign: String,
        velocity: Double,
        altitude: Double
    ) -> AircraftSizeClass {

        let callsignUpper = callsign.uppercased()
        let speedKnots = velocity * 1.94384
        let altFeet = altitude * 3.28084

        // Check for known heavy aircraft operators
        if isHeavyAircraft(callsign: callsignUpper) {
            return .heavy
        }

        switch category {
        case .commercialJet:
            // High speed + high altitude suggests larger aircraft
            if speedKnots > 480 && altFeet > 38000 {
                return .heavy
            }
            return .large

        case .cargoFreighter:
            // Cargo is usually large or heavy
            if speedKnots > 450 {
                return .heavy
            }
            return .large

        case .militaryTransport:
            return .heavy

        case .regionalJet, .businessJet:
            return .medium

        case .turboprop:
            return .medium

        case .military, .militaryFighter:
            return .medium

        case .helicopter:
            return .small

        case .lightAircraft:
            return .small

        case .glider, .balloon, .drone:
            return .ultralight

        case .unknown:
            if speedKnots > 400 {
                return .large
            }
            return .medium
        }
    }

    // MARK: - Detection Helpers

    private static func isHelicopter(callsign: String) -> Bool {
        // Common helicopter operator prefixes
        let heliPatterns = ["LIFE", "HELI", "MED", "AIR1", "RESCUE", "PHI", "ERA", "CHC", "BHL", "HNZ"]

        // Check for medical/rescue helicopter patterns
        for pattern in heliPatterns {
            if callsign.contains(pattern) {
                return true
            }
        }

        return false
    }

    private static func detectMilitary(callsign: String, originCountry: String) -> AircraftCategory? {
        // US Military prefixes
        let usMilitaryPrefixes = [
            "RCH", "REACH", // USAF tankers/transport
            "EVAC",         // Medical evacuation
            "NAVY", "VV",   // US Navy
            "ARMY",         // US Army
            "USAF",         // US Air Force
            "TOPCAT", "BOLT", "VIPER", "HAWK", // Fighter callsigns
            "DOOM", "REAPER", "HUNTER", // Drone callsigns
            "JAKE", "KNIFE", "RAIDR"
        ]

        // Check US military
        for prefix in usMilitaryPrefixes {
            if callsign.hasPrefix(prefix) {
                if ["TOPCAT", "BOLT", "VIPER", "HAWK", "DOOM", "KNIFE"].contains(where: { callsign.hasPrefix($0) }) {
                    return .militaryFighter
                }
                if ["REAPER", "HUNTER"].contains(where: { callsign.hasPrefix($0) }) {
                    return .drone
                }
                if ["RCH", "REACH", "EVAC"].contains(where: { callsign.hasPrefix($0) }) {
                    return .militaryTransport
                }
                return .military
            }
        }

        // Generic military patterns
        if callsign.hasPrefix("FORCE") || callsign.hasPrefix("GUARD") {
            return .military
        }

        return nil
    }

    private static func isCargoFreighter(callsign: String) -> Bool {
        // Major cargo airline prefixes
        let cargoPrefixes = [
            "FDX", "GTI", "UPS", "ABX", "ATN",  // FedEx, Atlas, UPS, ABX, ATN
            "KAL", "CLX", "CAO", "MAS",          // Korean Cargo, Cargolux, Air China Cargo
            "BOX", "QTR", "ETH", "DHL",          // Qatar Cargo, Ethiopian Cargo, DHL
            "PAC", "POL", "SQC", "CKK"           // Polar, Polaris, Singapore Cargo, China Cargo
        ]

        for prefix in cargoPrefixes {
            if callsign.hasPrefix(prefix) {
                return true
            }
        }

        // Pattern matching for cargo
        if callsign.contains("CARGO") || callsign.contains("FREIGHT") {
            return true
        }

        return false
    }

    private static func isBusinessJet(callsign: String, speedKnots: Double, altFeet: Double) -> Bool {
        // Business jet operators
        let bizjetPrefixes = [
            "EJA", "NJA", "LXJ", "XOJ",  // NetJets, Flexjet
            "TWY", "FLX", "VNY", "XA"
        ]

        for prefix in bizjetPrefixes {
            if callsign.hasPrefix(prefix) {
                return true
            }
        }

        // N-number registrations at high altitude with moderate speed
        if callsign.hasPrefix("N") && callsign.count <= 6 {
            if altFeet > 35000 && speedKnots > 350 && speedKnots < 500 {
                return true
            }
        }

        return false
    }

    private static func isTurboprop(callsign: String, speedKnots: Double) -> Bool {
        // Turboprop operators
        let turbopropPrefixes = [
            "SKW", // SkyWest (some turboprops)
            "ENY", // Envoy (American Eagle)
            "PDT", // Piedmont
            "ASH", "MES" // Mesa
        ]

        // Speed-based heuristic: turboprops typically cruise 250-350 knots
        if speedKnots > 200 && speedKnots < 350 {
            for prefix in turbopropPrefixes {
                if callsign.hasPrefix(prefix) {
                    return true
                }
            }
        }

        return false
    }

    private static func isCommercialAirline(callsign: String) -> Bool {
        // Major airline prefixes (3-letter ICAO codes)
        let airlinePrefixes = [
            "AAL", "UAL", "DAL", "SWA", "JBU",  // American, United, Delta, Southwest, JetBlue
            "ASA", "FFT", "NKS", "SKW", "RPA",  // Alaska, Frontier, Spirit, SkyWest, Republic
            "BAW", "DLH", "AFR", "KLM", "SAS",  // British, Lufthansa, Air France, KLM, SAS
            "ANA", "JAL", "CPA", "SIA", "QFA",  // ANA, JAL, Cathay, Singapore, Qantas
            "UAE", "ETD", "QTR", "THY", "ACA"   // Emirates, Etihad, Qatar, Turkish, Air Canada
        ]

        for prefix in airlinePrefixes {
            if callsign.hasPrefix(prefix) {
                return true
            }
        }

        return false
    }

    private static func isHeavyAircraft(callsign: String) -> Bool {
        // Airlines known for heavy aircraft operations
        let heavyOperators = [
            "UAE", "QTR", "SIA", "CPA", "ETD",  // Middle East/Asia widebody operators
            "BAW", "AFR", "DLH", "KLM",          // European legacy carriers
            "ANA", "JAL", "QFA",                 // Asian carriers
            "AAL", "UAL", "DAL"                  // US legacy (some routes)
        ]

        // Cargo is often heavy
        let heavyCargo = ["FDX", "UPS", "GTI", "CAL", "CLX"]

        for prefix in heavyOperators + heavyCargo {
            if callsign.hasPrefix(prefix) {
                return true
            }
        }

        return false
    }
}

// MARK: - Aircraft Icon View

struct AircraftIconView: View {
    let category: AircraftCategory
    let sizeClass: AircraftSizeClass
    let heading: Double
    let isOnGround: Bool
    let isSelected: Bool

    init(
        category: AircraftCategory,
        sizeClass: AircraftSizeClass = .medium,
        heading: Double = 0,
        isOnGround: Bool = false,
        isSelected: Bool = false
    ) {
        self.category = category
        self.sizeClass = sizeClass
        self.heading = heading
        self.isOnGround = isOnGround
        self.isSelected = isSelected
    }

    var body: some View {
        ZStack {
            // Selection ring
            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: 1.5)
                    .frame(width: iconSize + 6, height: iconSize + 6)
            }

            // Subtle shadow background
            Circle()
                .fill(Color.black.opacity(0.4))
                .frame(width: iconSize + 2, height: iconSize + 2)

            // Aircraft icon
            iconImage
                .font(.system(size: iconSize * 0.65, weight: .medium))
                .foregroundColor(iconColor)
                .rotationEffect(.degrees(heading - 90)) // Adjust for north-up
        }
        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
    }

    private var iconSize: CGFloat {
        category.iconSize * sizeClass.scaleFactor
    }

    private var iconColor: Color {
        if isOnGround {
            return Color(white: 0.5)
        }
        return category.baseColor
    }

    @ViewBuilder
    private var iconImage: some View {
        switch category {
        case .commercialJet, .regionalJet, .businessJet, .turboprop, .militaryTransport:
            Image(systemName: "airplane")
        case .cargoFreighter:
            Image(systemName: "airplane")
        case .lightAircraft:
            Image(systemName: "airplane")
        case .helicopter:
            Image(systemName: "circle.hexagongrid.fill")
        case .military, .militaryFighter:
            Image(systemName: "airplane")
        case .glider:
            Image(systemName: "wind")
        case .balloon:
            Image(systemName: "aqi.medium")
        case .drone:
            Image(systemName: "camera.metering.multispot")
        case .unknown:
            Image(systemName: "airplane")
        }
    }
}

// MARK: - Map Annotation Icon

struct AircraftMapIcon: View {
    let aircraft: Aircraft

    var body: some View {
        let category = AircraftTypeDetector.detectCategory(
            callsign: aircraft.callsign,
            velocity: aircraft.velocity,
            altitude: aircraft.altitude,
            verticalRate: aircraft.verticalRate,
            onGround: aircraft.onGround,
            originCountry: aircraft.originCountry
        )

        let sizeClass = AircraftTypeDetector.detectSizeClass(
            category: category,
            callsign: aircraft.callsign,
            velocity: aircraft.velocity,
            altitude: aircraft.altitude
        )

        AircraftIconView(
            category: category,
            sizeClass: sizeClass,
            heading: aircraft.heading,
            isOnGround: aircraft.onGround,
            isSelected: false
        )
    }
}

// MARK: - List Row Icon

struct AircraftListIcon: View {
    let aircraft: Aircraft
    let size: CGFloat

    init(aircraft: Aircraft, size: CGFloat = 28) {
        self.aircraft = aircraft
        self.size = size
    }

    private var category: AircraftCategory {
        AircraftTypeDetector.detectCategory(
            callsign: aircraft.callsign,
            velocity: aircraft.velocity,
            altitude: aircraft.altitude,
            verticalRate: aircraft.verticalRate,
            onGround: aircraft.onGround,
            originCountry: aircraft.originCountry
        )
    }

    var body: some View {
        ZStack {
            // Outer ring with category color
            Circle()
                .stroke(aircraft.onGround ? Color(white: 0.4) : category.baseColor.opacity(0.6), lineWidth: 1.5)
                .frame(width: size, height: size)

            // Inner fill
            Circle()
                .fill(Color(white: 0.15))
                .frame(width: size - 3, height: size - 3)

            // Icon
            iconForCategory(category)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(aircraft.onGround ? Color(white: 0.5) : category.baseColor)
                .rotationEffect(.degrees(aircraft.heading - 90))
        }
    }

    @ViewBuilder
    private func iconForCategory(_ category: AircraftCategory) -> some View {
        switch category {
        case .helicopter:
            Image(systemName: "circle.hexagongrid.fill")
        case .drone:
            Image(systemName: "camera.metering.multispot")
        case .balloon:
            Image(systemName: "aqi.medium")
        case .glider:
            Image(systemName: "wind")
        default:
            Image(systemName: "airplane")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AircraftIcons_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Aircraft Icons by Category")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                ForEach(AircraftCategory.allCases, id: \.self) { category in
                    VStack(spacing: 8) {
                        AircraftIconView(
                            category: category,
                            sizeClass: .medium,
                            heading: 45,
                            isOnGround: false,
                            isSelected: false
                        )

                        Text(category.displayName)
                            .font(.system(size: 10))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding()

            Divider()

            Text("Size Classes")
                .font(.headline)

            HStack(spacing: 20) {
                ForEach([AircraftSizeClass.heavy, .large, .medium, .small, .ultralight], id: \.self) { size in
                    VStack {
                        AircraftIconView(
                            category: .commercialJet,
                            sizeClass: size,
                            heading: 0,
                            isOnGround: false
                        )
                        Text(size.rawValue)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
#endif
