//
//  DataPackageModels.swift
//  OmniTAKMobile
//
//  Data models for TAK data packages (.zip containing overlays, icons, configs)
//

import Foundation

// MARK: - Data Package Model

struct DataPackage: Codable, Identifiable {
    var id: UUID
    var name: String
    var version: String
    var importDate: Date
    var size: Int64
    var contents: [PackageContent]
    var description: String?
    var author: String?
    var checksum: String?

    init(id: UUID = UUID(),
         name: String,
         version: String = "1.0",
         importDate: Date = Date(),
         size: Int64 = 0,
         contents: [PackageContent] = [],
         description: String? = nil,
         author: String? = nil,
         checksum: String? = nil) {
        self.id = id
        self.name = name
        self.version = version
        self.importDate = importDate
        self.size = size
        self.contents = contents
        self.description = description
        self.author = author
        self.checksum = checksum
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var overlayCount: Int {
        contents.filter {
            if case .overlay = $0 { return true }
            return false
        }.count
    }

    var iconCount: Int {
        contents.filter {
            if case .icon = $0 { return true }
            return false
        }.count
    }

    var configCount: Int {
        contents.filter {
            if case .config = $0 { return true }
            return false
        }.count
    }

    var mapCacheCount: Int {
        contents.filter {
            if case .mapCache = $0 { return true }
            return false
        }.count
    }

    var contentsSummary: String {
        var parts: [String] = []
        if overlayCount > 0 {
            parts.append("\(overlayCount) overlay\(overlayCount == 1 ? "" : "s")")
        }
        if iconCount > 0 {
            parts.append("\(iconCount) icon\(iconCount == 1 ? "" : "s")")
        }
        if configCount > 0 {
            parts.append("\(configCount) config\(configCount == 1 ? "" : "s")")
        }
        if mapCacheCount > 0 {
            parts.append("\(mapCacheCount) cache\(mapCacheCount == 1 ? "" : "s")")
        }
        return parts.isEmpty ? "Empty package" : parts.joined(separator: ", ")
    }
}

// MARK: - Package Content Types

enum PackageContent: Codable, Equatable {
    case overlay(String)    // KML/KMZ files
    case icon(String)       // Custom icons
    case config(String)     // Configuration files
    case mapCache(String)   // Offline tiles

    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let value = try container.decode(String.self, forKey: .value)

        switch type {
        case "overlay":
            self = .overlay(value)
        case "icon":
            self = .icon(value)
        case "config":
            self = .config(value)
        case "mapCache":
            self = .mapCache(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .overlay(let value):
            try container.encode("overlay", forKey: .type)
            try container.encode(value, forKey: .value)
        case .icon(let value):
            try container.encode("icon", forKey: .type)
            try container.encode(value, forKey: .value)
        case .config(let value):
            try container.encode("config", forKey: .type)
            try container.encode(value, forKey: .value)
        case .mapCache(let value):
            try container.encode("mapCache", forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }

    var fileName: String {
        switch self {
        case .overlay(let name), .icon(let name), .config(let name), .mapCache(let name):
            return name
        }
    }

    var typeString: String {
        switch self {
        case .overlay:
            return "Overlay"
        case .icon:
            return "Icon"
        case .config:
            return "Config"
        case .mapCache:
            return "Map Cache"
        }
    }

    var iconName: String {
        switch self {
        case .overlay:
            return "map"
        case .icon:
            return "photo"
        case .config:
            return "gearshape"
        case .mapCache:
            return "square.grid.3x3"
        }
    }
}

// MARK: - Package Manifest

struct PackageManifest: Codable {
    var name: String
    var version: String
    var description: String?
    var author: String?
    var createdDate: Date
    var contents: [String]

    init(name: String,
         version: String = "1.0",
         description: String? = nil,
         author: String? = nil,
         createdDate: Date = Date(),
         contents: [String] = []) {
        self.name = name
        self.version = version
        self.description = description
        self.author = author
        self.createdDate = createdDate
        self.contents = contents
    }
}

// MARK: - Import/Export Results

struct PackageImportResult {
    var package: DataPackage
    var warnings: [String]
    var skippedFiles: [String]
    var success: Bool

    init(package: DataPackage, warnings: [String] = [], skippedFiles: [String] = [], success: Bool = true) {
        self.package = package
        self.warnings = warnings
        self.skippedFiles = skippedFiles
        self.success = success
    }
}

struct PackageExportResult {
    var packageURL: URL
    var packageSize: Int64
    var includedContents: [PackageContent]
    var success: Bool

    init(packageURL: URL, packageSize: Int64 = 0, includedContents: [PackageContent] = [], success: Bool = true) {
        self.packageURL = packageURL
        self.packageSize = packageSize
        self.includedContents = includedContents
        self.success = success
    }
}

// MARK: - Error Types

enum DataPackageError: LocalizedError {
    case invalidPackage
    case manifestNotFound
    case extractionFailed(String)
    case compressionFailed(String)
    case fileNotFound(String)
    case unsupportedFormat(String)
    case storageError(String)
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .invalidPackage:
            return "Invalid data package format"
        case .manifestNotFound:
            return "Package manifest not found"
        case .extractionFailed(let detail):
            return "Failed to extract package: \(detail)"
        case .compressionFailed(let detail):
            return "Failed to compress package: \(detail)"
        case .fileNotFound(let file):
            return "File not found: \(file)"
        case .unsupportedFormat(let format):
            return "Unsupported file format: \(format)"
        case .storageError(let detail):
            return "Storage error: \(detail)"
        case .checksumMismatch:
            return "Package checksum does not match"
        }
    }
}
