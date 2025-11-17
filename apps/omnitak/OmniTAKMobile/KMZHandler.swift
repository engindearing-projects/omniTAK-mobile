//
//  KMZHandler.swift
//  OmniTAKMobile
//
//  Handler for KMZ files (ZIP archives containing KML)
//

import Foundation
import Compression

class KMZHandler {

    enum KMZError: LocalizedError {
        case invalidKMZ
        case noKMLFound
        case decompressionFailed
        case fileAccessError(String)

        var errorDescription: String? {
            switch self {
            case .invalidKMZ:
                return "Invalid KMZ file format"
            case .noKMLFound:
                return "No KML file found in KMZ archive"
            case .decompressionFailed:
                return "Failed to decompress KMZ archive"
            case .fileAccessError(let message):
                return "File access error: \(message)"
            }
        }
    }

    /// Extract KML data from a KMZ file
    static func extractKML(from kmzURL: URL) throws -> (kmlData: Data, resources: [String: Data]) {
        let data = try Data(contentsOf: kmzURL)
        return try extractKML(from: data)
    }

    /// Extract KML data from KMZ data
    static func extractKML(from kmzData: Data) throws -> (kmlData: Data, resources: [String: Data]) {
        guard let archive = ZipArchive(data: kmzData) else {
            throw KMZError.invalidKMZ
        }

        var kmlData: Data?
        var resources: [String: Data] = [:]

        // Find and extract files
        for entry in archive.entries {
            let fileName = entry.fileName.lowercased()

            if fileName.hasSuffix(".kml") {
                // Prefer doc.kml if present, otherwise use any .kml file
                if kmlData == nil || entry.fileName.lowercased() == "doc.kml" {
                    kmlData = entry.data
                }
            } else if fileName.hasSuffix(".png") ||
                      fileName.hasSuffix(".jpg") ||
                      fileName.hasSuffix(".jpeg") ||
                      fileName.hasSuffix(".gif") {
                // Store image resources
                resources[entry.fileName] = entry.data
            }
        }

        guard let kml = kmlData else {
            throw KMZError.noKMLFound
        }

        return (kml, resources)
    }

    /// Save extracted resources to documents directory
    static func saveResources(_ resources: [String: Data], forKML kmlName: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let kmlResourceDir = documentsPath.appendingPathComponent("KMLResources/\(kmlName)")

        try FileManager.default.createDirectory(at: kmlResourceDir, withIntermediateDirectories: true)

        for (fileName, data) in resources {
            let fileURL = kmlResourceDir.appendingPathComponent(fileName)
            try data.write(to: fileURL)
        }

        return kmlResourceDir
    }
}

// MARK: - Simple ZIP Archive Reader

/// Minimal ZIP archive reader for KMZ files
class ZipArchive {
    struct Entry {
        let fileName: String
        let data: Data
    }

    let entries: [Entry]

    init?(data: Data) {
        var extractedEntries: [Entry] = []

        // ZIP file structure:
        // Local file header signature: 0x04034b50
        // Central directory header signature: 0x02014b50
        // End of central directory signature: 0x06054b50

        var offset = 0
        let bytes = [UInt8](data)

        while offset + 30 <= bytes.count {
            // Check for local file header signature
            let sig = UInt32(bytes[offset]) |
                      (UInt32(bytes[offset + 1]) << 8) |
                      (UInt32(bytes[offset + 2]) << 16) |
                      (UInt32(bytes[offset + 3]) << 24)

            guard sig == 0x04034b50 else {
                // Not a local file header, might be end of local headers
                break
            }

            // Parse local file header
            let compressionMethod = UInt16(bytes[offset + 8]) | (UInt16(bytes[offset + 9]) << 8)
            let compressedSize = UInt32(bytes[offset + 18]) |
                                 (UInt32(bytes[offset + 19]) << 8) |
                                 (UInt32(bytes[offset + 20]) << 16) |
                                 (UInt32(bytes[offset + 21]) << 24)
            let uncompressedSize = UInt32(bytes[offset + 22]) |
                                   (UInt32(bytes[offset + 23]) << 8) |
                                   (UInt32(bytes[offset + 24]) << 16) |
                                   (UInt32(bytes[offset + 25]) << 24)
            let fileNameLength = UInt16(bytes[offset + 26]) | (UInt16(bytes[offset + 27]) << 8)
            let extraFieldLength = UInt16(bytes[offset + 28]) | (UInt16(bytes[offset + 29]) << 8)

            let fileNameStart = offset + 30
            let fileNameEnd = fileNameStart + Int(fileNameLength)

            guard fileNameEnd <= bytes.count else { break }

            let fileNameData = Data(bytes[fileNameStart..<fileNameEnd])
            guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                offset = fileNameEnd + Int(extraFieldLength) + Int(compressedSize)
                continue
            }

            let dataStart = fileNameEnd + Int(extraFieldLength)
            let dataEnd = dataStart + Int(compressedSize)

            guard dataEnd <= bytes.count else { break }

            let compressedData = Data(bytes[dataStart..<dataEnd])

            // Decompress if needed
            var fileData: Data
            if compressionMethod == 0 {
                // Stored (no compression)
                fileData = compressedData
            } else if compressionMethod == 8 {
                // Deflate
                if let decompressed = ZipArchive.inflate(compressedData, expectedSize: Int(uncompressedSize)) {
                    fileData = decompressed
                } else {
                    // Skip file if decompression fails
                    offset = dataEnd
                    continue
                }
            } else {
                // Unsupported compression method
                offset = dataEnd
                continue
            }

            // Skip directory entries
            if !fileName.hasSuffix("/") {
                extractedEntries.append(Entry(fileName: fileName, data: fileData))
            }

            offset = dataEnd
        }

        guard !extractedEntries.isEmpty else { return nil }
        self.entries = extractedEntries
    }

    /// Inflate deflated data using Compression framework
    static func inflate(_ data: Data, expectedSize: Int) -> Data? {
        guard expectedSize > 0 else { return Data() }

        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: expectedSize)
        defer { destinationBuffer.deallocate() }

        let decompressedSize = data.withUnsafeBytes { (sourceBytes: UnsafeRawBufferPointer) -> Int in
            guard let sourcePointer = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }

            // Use raw deflate decompression (ZIP uses raw deflate without zlib header)
            return compression_decode_buffer(
                destinationBuffer,
                expectedSize,
                sourcePointer,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decompressedSize > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
}
