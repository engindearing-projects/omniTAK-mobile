//
//  MilStdIconService.swift
//  OmniTAKMobile
//
//  Service for mapping CoT types to MIL-STD-2525 SIDC icons
//

import Foundation
import SwiftUI

// MARK: - CoT Type Definition

struct CoTTypeDefinition: Codable, Identifiable {
    let value: String      // CoT type (e.g., "a-f-G-U")
    let sidc: String       // SIDC code with .svg extension
    let label: String
    let description: String
    let category: String   // friendly, hostile, neutral, unknown

    var id: String { value }

    var sidcCode: String {
        sidc.replacingOccurrences(of: ".svg", with: "")
    }

    var affiliation: Affiliation {
        Affiliation(rawValue: category) ?? .unknown
    }
}

// MARK: - Affiliation

enum Affiliation: String, Codable, CaseIterable {
    case friendly
    case hostile
    case neutral
    case unknown

    var color: Color {
        switch self {
        case .friendly: return .blue
        case .hostile: return .red
        case .neutral: return .green
        case .unknown: return .yellow
        }
    }

    var frameColor: Color {
        switch self {
        case .friendly: return Color(red: 0.0, green: 0.6, blue: 1.0)
        case .hostile: return Color(red: 1.0, green: 0.2, blue: 0.2)
        case .neutral: return Color(red: 0.0, green: 0.8, blue: 0.4)
        case .unknown: return Color(red: 1.0, green: 0.85, blue: 0.0)
        }
    }

    var displayName: String {
        rawValue.capitalized
    }

    static func from(cotType: String) -> Affiliation {
        // CoT types: a-X-... where X is the affiliation
        // f = friendly, h = hostile, n = neutral, u = unknown
        guard cotType.count >= 3 else { return .unknown }

        let index = cotType.index(cotType.startIndex, offsetBy: 2)
        let affiliationChar = cotType[index]

        switch affiliationChar {
        case "f": return .friendly
        case "h": return .hostile
        case "n": return .neutral
        case "u": return .unknown
        default: return .unknown
        }
    }
}

// MARK: - Battle Dimension

enum BattleDimension: String, CaseIterable {
    case air = "A"
    case ground = "G"
    case sea = "S"
    case subsurface = "U"
    case space = "P"
    case other = "X"

    var displayName: String {
        switch self {
        case .air: return "Air"
        case .ground: return "Ground"
        case .sea: return "Sea/Surface"
        case .subsurface: return "Subsurface"
        case .space: return "Space"
        case .other: return "Other"
        }
    }

    static func from(cotType: String) -> BattleDimension {
        // CoT types: a-X-Y-... where Y is the dimension
        guard cotType.count >= 5 else { return .other }

        let index = cotType.index(cotType.startIndex, offsetBy: 4)
        let dimensionChar = String(cotType[index])

        return BattleDimension(rawValue: dimensionChar) ?? .other
    }
}

// MARK: - MIL-STD Icon Service

class MilStdIconService {
    static let shared = MilStdIconService()

    private var cotTypeMap: [String: CoTTypeDefinition] = [:]
    private var sidcToCoTMap: [String: CoTTypeDefinition] = [:]
    private var defaultDefinitions: [CoTTypeDefinition] = []

    // Fallback SIDC codes by affiliation
    private let fallbackSIDC: [Affiliation: String] = [
        .friendly: "SFGPU------",
        .hostile: "SHGPU------",
        .neutral: "SNGPU------",
        .unknown: "SUGPU------"
    ]

    private init() {
        loadDefaultMappings()
    }

    // MARK: - Public Methods

    /// Get SIDC code for a CoT type
    func getSIDC(for cotType: String) -> String {
        // Try exact match first
        if let definition = cotTypeMap[cotType] {
            return definition.sidcCode
        }

        // Try progressively shorter matches
        var searchType = cotType
        while searchType.count > 3 {
            if let definition = cotTypeMap[searchType] {
                return definition.sidcCode
            }
            // Remove last segment (after last hyphen)
            if let lastHyphen = searchType.lastIndex(of: "-") {
                searchType = String(searchType[..<lastHyphen])
            } else {
                break
            }
        }

        // Return fallback based on affiliation
        let affiliation = Affiliation.from(cotType: cotType)
        return fallbackSIDC[affiliation] ?? "SUGPU------"
    }

    /// Get SVG file name for a CoT type
    func getSVGFileName(for cotType: String) -> String {
        return getSIDC(for: cotType) + ".svg"
    }

    /// Get definition for a CoT type
    func getDefinition(for cotType: String) -> CoTTypeDefinition? {
        return cotTypeMap[cotType]
    }

    /// Get affiliation from CoT type
    func getAffiliation(for cotType: String) -> Affiliation {
        return Affiliation.from(cotType: cotType)
    }

    /// Get battle dimension from CoT type
    func getBattleDimension(for cotType: String) -> BattleDimension {
        return BattleDimension.from(cotType: cotType)
    }

    /// Get all available definitions
    func getAllDefinitions() -> [CoTTypeDefinition] {
        return defaultDefinitions
    }

    /// Get definitions by category
    func getDefinitions(for affiliation: Affiliation) -> [CoTTypeDefinition] {
        return defaultDefinitions.filter { $0.affiliation == affiliation }
    }

    /// Check if an SVG icon exists for the SIDC
    func iconExists(for sidc: String) -> Bool {
        let fileName = sidc.hasSuffix(".svg") ? sidc : "\(sidc).svg"
        return Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".svg", with: ""),
                               withExtension: "svg",
                               subdirectory: "MilStdIcons") != nil
    }

    /// Get URL for icon file
    func getIconURL(for cotType: String) -> URL? {
        let sidc = getSIDC(for: cotType)
        return Bundle.main.url(forResource: sidc,
                               withExtension: "svg",
                               subdirectory: "MilStdIcons")
    }

    // MARK: - Private Methods

    private func loadDefaultMappings() {
        // Load from bundled YAML or use hardcoded defaults
        if let yamlURL = Bundle.main.url(forResource: "cot_types", withExtension: "yaml"),
           let yamlString = try? String(contentsOf: yamlURL, encoding: .utf8) {
            parseYAML(yamlString)
        } else {
            loadHardcodedDefaults()
        }
    }

    private func parseYAML(_ yaml: String) {
        // Simple YAML parsing for our known structure
        // In production, consider using Yams library
        loadHardcodedDefaults()
    }

    private func loadHardcodedDefaults() {
        defaultDefinitions = [
            // Friendly Ground Units
            CoTTypeDefinition(value: "a-f-G-U", sidc: "SFGPU------.svg", label: "Friendly Ground - Generic", description: "Generic friendly marker", category: "friendly"),
            CoTTypeDefinition(value: "a-f-G-U-C-I", sidc: "SFGPUCI----.svg", label: "Friendly Infantry", description: "Friendly ground infantry unit", category: "friendly"),
            CoTTypeDefinition(value: "a-f-G-U-C-A", sidc: "SFGPUCA----.svg", label: "Friendly Armor", description: "Friendly ground armored unit", category: "friendly"),
            CoTTypeDefinition(value: "a-f-G-U-C-S", sidc: "SFGPUCS----.svg", label: "Friendly Combat Support", description: "Friendly combat support unit", category: "friendly"),
            CoTTypeDefinition(value: "a-f-G-U-U-L-C", sidc: "SFGPUULC----.svg", label: "Law Enforcement", description: "Police or law enforcement", category: "friendly"),
            CoTTypeDefinition(value: "a-f-G-U-S-M", sidc: "SFGPUSM----.svg", label: "Medical", description: "Ambulance or medical vehicle", category: "friendly"),
            CoTTypeDefinition(value: "a-f-G-E-V-U", sidc: "SFGPEVU----.svg", label: "Utility Vehicle", description: "Utility or service vehicle", category: "friendly"),
            CoTTypeDefinition(value: "a-f-G-E-V-M", sidc: "SFGPEVM----.svg", label: "Civilian Vehicle", description: "Civilian motor vehicle", category: "friendly"),
            CoTTypeDefinition(value: "a-f-G-E-V-F", sidc: "SFGPEVF----.svg", label: "Full Track Vehicle", description: "Full track armored vehicle", category: "friendly"),
            CoTTypeDefinition(value: "a-f-G-E-V-L", sidc: "SFGPEVL----.svg", label: "Light Vehicle", description: "Light armored vehicle", category: "friendly"),
            CoTTypeDefinition(value: "a-f-F-G-S", sidc: "SFFP-------.svg", label: "Special Forces", description: "Special operations forces", category: "friendly"),

            // Friendly Air Units
            CoTTypeDefinition(value: "a-f-A", sidc: "SFAP-------.svg", label: "Friendly Air", description: "Friendly air unit", category: "friendly"),
            CoTTypeDefinition(value: "a-f-A-M-F", sidc: "SFAP-------.svg", label: "Fixed Wing", description: "Friendly fixed-wing aircraft", category: "friendly"),
            CoTTypeDefinition(value: "a-f-A-M-h", sidc: "SFAPMh------.svg", label: "Rotary Wing", description: "Friendly helicopter", category: "friendly"),
            CoTTypeDefinition(value: "a-f-A-C-F", sidc: "SFAPACF----.svg", label: "Fighter Aircraft", description: "Fighter/interceptor aircraft", category: "friendly"),
            CoTTypeDefinition(value: "a-f-A-C-R", sidc: "SFAPACR----.svg", label: "Reconnaissance Aircraft", description: "Reconnaissance aircraft", category: "friendly"),

            // Friendly Maritime
            CoTTypeDefinition(value: "a-f-S", sidc: "SFSP-------.svg", label: "Friendly Maritime", description: "Friendly naval vessel", category: "friendly"),

            // Hostile Units
            CoTTypeDefinition(value: "a-h-G-U", sidc: "SHGPU------.svg", label: "Hostile Ground - Generic", description: "Generic hostile marker", category: "hostile"),
            CoTTypeDefinition(value: "a-h-G-U-C-I", sidc: "SHGPUCI----.svg", label: "Hostile Infantry", description: "Hostile infantry unit", category: "hostile"),
            CoTTypeDefinition(value: "a-h-G-U-C-A", sidc: "SHGPUCA----.svg", label: "Hostile Armor", description: "Hostile armored vehicle", category: "hostile"),
            CoTTypeDefinition(value: "a-h-G-U-C-C", sidc: "SHGPUCC----.svg", label: "Hostile Cavalry", description: "Hostile cavalry/recon unit", category: "hostile"),
            CoTTypeDefinition(value: "a-h-G-E-V-C", sidc: "SHGPEVC----.svg", label: "Hostile Civil Vehicle", description: "Hostile civilian vehicle", category: "hostile"),

            // Neutral Units
            CoTTypeDefinition(value: "a-n-G-U", sidc: "SNGPU------.svg", label: "Neutral Ground", description: "Neutral ground unit", category: "neutral"),
            CoTTypeDefinition(value: "a-n-A-M-F", sidc: "SNAP-------.svg", label: "Neutral Air", description: "Neutral aircraft", category: "neutral"),
            CoTTypeDefinition(value: "a-n-S", sidc: "SNSP-------.svg", label: "Neutral Maritime", description: "Neutral vessel", category: "neutral"),

            // Unknown Units
            CoTTypeDefinition(value: "a-u-G-U", sidc: "SUGPU------.svg", label: "Unknown Ground", description: "Unknown ground unit", category: "unknown"),
            CoTTypeDefinition(value: "a-u-G-U-C-I", sidc: "SUGPUCI----.svg", label: "Unknown Infantry", description: "Unknown infantry unit", category: "unknown"),
            CoTTypeDefinition(value: "a-u-A", sidc: "SUA---------.svg", label: "Unknown Air", description: "Unknown aircraft", category: "unknown"),
        ]

        // Build lookup maps
        for def in defaultDefinitions {
            cotTypeMap[def.value] = def
            sidcToCoTMap[def.sidcCode] = def
        }
    }
}

// MARK: - SwiftUI View Extension for SVG Icons

/// Wrapper view that renders MIL-STD-2525 symbols using CoT types
/// Use MilStd2525SymbolView directly for more control
struct MilStdIcon: View {
    let cotType: String
    let size: CGFloat
    var showLabel: Bool = false
    var label: String? = nil

    var body: some View {
        MilStd2525SymbolView(
            cotType: cotType,
            size: size,
            showLabel: showLabel,
            label: label
        )
    }
}
