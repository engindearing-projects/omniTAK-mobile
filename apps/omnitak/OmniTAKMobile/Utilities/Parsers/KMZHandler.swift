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

    /// Central directory entry info
    private struct CentralDirEntry {
        let fileName: String
        let compressionMethod: UInt16
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let localHeaderOffset: UInt32
    }

    let entries: [Entry]

    init?(data: Data) {
        var extractedEntries: [Entry] = []
        let bytes = [UInt8](data)

        print("🗜️ ZipArchive: Parsing \(data.count) bytes")

        // Parse the central directory to get accurate file info
        // This is more reliable than sequential parsing for macOS-created ZIPs
        let centralDirEntries = ZipArchive.parseCentralDirectory(bytes: bytes)
        print("🗜️ ZipArchive: Found \(centralDirEntries.count) entries in central directory")

        for entry in centralDirEntries {
            print("   📁 Central dir: '\(entry.fileName)' compressed=\(entry.compressedSize) uncompressed=\(entry.uncompressedSize)")
        }

        // Extract each file using central directory info
        for centralEntry in centralDirEntries {
            // Skip directories and macOS metadata files
            if centralEntry.fileName.hasSuffix("/") {
                print("🗜️ ZipArchive: Skipping directory '\(centralEntry.fileName)'")
                continue
            }
            if centralEntry.fileName.hasPrefix("__MACOSX/") || centralEntry.fileName.contains("/._") {
                print("🗜️ ZipArchive: Skipping macOS metadata '\(centralEntry.fileName)'")
                continue
            }

            let offset = Int(centralEntry.localHeaderOffset)
            guard offset + 30 <= bytes.count else {
                print("🗜️ ZipArchive: Invalid local header offset for '\(centralEntry.fileName)'")
                continue
            }

            // Verify local file header signature
            let sig = UInt32(bytes[offset]) |
                      (UInt32(bytes[offset + 1]) << 8) |
                      (UInt32(bytes[offset + 2]) << 16) |
                      (UInt32(bytes[offset + 3]) << 24)

            guard sig == 0x04034b50 else {
                print("🗜️ ZipArchive: Invalid signature at offset \(offset) for '\(centralEntry.fileName)'")
                continue
            }

            // Parse local file header (for extra field length which may differ from central dir)
            let fileNameLength = Int(UInt16(bytes[offset + 26]) | (UInt16(bytes[offset + 27]) << 8))
            let extraFieldLength = Int(UInt16(bytes[offset + 28]) | (UInt16(bytes[offset + 29]) << 8))

            let dataStart = offset + 30 + fileNameLength + extraFieldLength
            let dataEnd = dataStart + Int(centralEntry.compressedSize)

            print("🗜️ ZipArchive: Entry '\(centralEntry.fileName)' method=\(centralEntry.compressionMethod) compressed=\(centralEntry.compressedSize) uncompressed=\(centralEntry.uncompressedSize)")

            guard dataEnd <= bytes.count else {
                print("   ❌ Data extends past end (need \(dataEnd), have \(bytes.count))")
                continue
            }

            let compressedData = Data(bytes[dataStart..<dataEnd])

            // Decompress if needed
            var fileData: Data
            if centralEntry.compressionMethod == 0 {
                // Stored (no compression)
                fileData = compressedData
                print("   ✅ Stored: \(fileData.count) bytes")
            } else if centralEntry.compressionMethod == 8 {
                // Deflate
                if let decompressed = ZipArchive.inflateRawDeflate(compressedData, expectedSize: Int(centralEntry.uncompressedSize)) {
                    fileData = decompressed
                    print("   ✅ Inflated: \(fileData.count) bytes (expected \(centralEntry.uncompressedSize))")
                } else {
                    print("   ❌ Decompression failed for '\(centralEntry.fileName)'")
                    continue
                }
            } else {
                print("   ⚠️ Unsupported compression method: \(centralEntry.compressionMethod)")
                continue
            }

            extractedEntries.append(Entry(fileName: centralEntry.fileName, data: fileData))
        }

        print("🗜️ ZipArchive: Extracted \(extractedEntries.count) entries")
        guard !extractedEntries.isEmpty else { return nil }
        self.entries = extractedEntries
    }

    /// Parse the central directory to get accurate file sizes
    private static func parseCentralDirectory(bytes: [UInt8]) -> [CentralDirEntry] {
        var entries: [CentralDirEntry] = []

        // Find End of Central Directory record (search from end)
        // Signature: 0x06054b50
        var eocdOffset = -1
        for i in stride(from: bytes.count - 22, through: 0, by: -1) {
            if i + 4 <= bytes.count {
                let sig = UInt32(bytes[i]) |
                          (UInt32(bytes[i + 1]) << 8) |
                          (UInt32(bytes[i + 2]) << 16) |
                          (UInt32(bytes[i + 3]) << 24)
                if sig == 0x06054b50 {
                    eocdOffset = i
                    break
                }
            }
        }

        guard eocdOffset >= 0, eocdOffset + 22 <= bytes.count else {
            print("🗜️ ZipArchive: Could not find End of Central Directory")
            return entries
        }

        // Parse EOCD
        let centralDirOffset = Int(UInt32(bytes[eocdOffset + 16]) |
                                   (UInt32(bytes[eocdOffset + 17]) << 8) |
                                   (UInt32(bytes[eocdOffset + 18]) << 16) |
                                   (UInt32(bytes[eocdOffset + 19]) << 24))
        let numEntries = Int(UInt16(bytes[eocdOffset + 10]) | (UInt16(bytes[eocdOffset + 11]) << 8))

        print("🗜️ ZipArchive: Central directory at offset \(centralDirOffset), \(numEntries) entries")

        // Parse central directory entries
        var cdOffset = centralDirOffset
        for _ in 0..<numEntries {
            guard cdOffset + 46 <= bytes.count else { break }

            let sig = UInt32(bytes[cdOffset]) |
                      (UInt32(bytes[cdOffset + 1]) << 8) |
                      (UInt32(bytes[cdOffset + 2]) << 16) |
                      (UInt32(bytes[cdOffset + 3]) << 24)

            guard sig == 0x02014b50 else {
                print("🗜️ ZipArchive: Invalid central directory signature at \(cdOffset)")
                break
            }

            let compressionMethod = UInt16(bytes[cdOffset + 10]) | (UInt16(bytes[cdOffset + 11]) << 8)
            let compressedSize = UInt32(bytes[cdOffset + 20]) |
                                 (UInt32(bytes[cdOffset + 21]) << 8) |
                                 (UInt32(bytes[cdOffset + 22]) << 16) |
                                 (UInt32(bytes[cdOffset + 23]) << 24)
            let uncompressedSize = UInt32(bytes[cdOffset + 24]) |
                                   (UInt32(bytes[cdOffset + 25]) << 8) |
                                   (UInt32(bytes[cdOffset + 26]) << 16) |
                                   (UInt32(bytes[cdOffset + 27]) << 24)
            let fileNameLength = Int(UInt16(bytes[cdOffset + 28]) | (UInt16(bytes[cdOffset + 29]) << 8))
            let extraFieldLength = Int(UInt16(bytes[cdOffset + 30]) | (UInt16(bytes[cdOffset + 31]) << 8))
            let commentLength = Int(UInt16(bytes[cdOffset + 32]) | (UInt16(bytes[cdOffset + 33]) << 8))
            let localHeaderOffset = UInt32(bytes[cdOffset + 42]) |
                                    (UInt32(bytes[cdOffset + 43]) << 8) |
                                    (UInt32(bytes[cdOffset + 44]) << 16) |
                                    (UInt32(bytes[cdOffset + 45]) << 24)

            let fileNameStart = cdOffset + 46
            let fileNameEnd = fileNameStart + fileNameLength

            guard fileNameEnd <= bytes.count else { break }

            let fileNameData = Data(bytes[fileNameStart..<fileNameEnd])
            if let fileName = String(data: fileNameData, encoding: .utf8) {
                entries.append(CentralDirEntry(
                    fileName: fileName,
                    compressionMethod: compressionMethod,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    localHeaderOffset: localHeaderOffset
                ))
            }

            cdOffset = fileNameEnd + extraFieldLength + commentLength
        }

        return entries
    }

    /// Inflate raw deflate data (as used in ZIP files)
    static func inflateRawDeflate(_ data: Data, expectedSize: Int) -> Data? {
        guard expectedSize > 0 else { return Data() }
        guard !data.isEmpty else { return nil }

        // Allocate buffer with extra space
        let bufferSize = expectedSize + 4096
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }

        // Approach 1: Add zlib header to make raw deflate zlib-compatible
        // zlib header: 0x78 0x9C (default compression)
        var zlibData = Data([0x78, 0x9C])
        zlibData.append(data)

        var decompressedSize = zlibData.withUnsafeBytes { (sourceBytes: UnsafeRawBufferPointer) -> Int in
            guard let sourcePointer = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_decode_buffer(
                destinationBuffer,
                bufferSize,
                sourcePointer,
                zlibData.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        if decompressedSize >= expectedSize {
            // Return exactly the expected size
            return Data(bytes: destinationBuffer, count: expectedSize)
        }

        // Approach 2: Try raw data directly
        decompressedSize = data.withUnsafeBytes { (sourceBytes: UnsafeRawBufferPointer) -> Int in
            guard let sourcePointer = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_decode_buffer(
                destinationBuffer,
                bufferSize,
                sourcePointer,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        if decompressedSize >= expectedSize {
            return Data(bytes: destinationBuffer, count: expectedSize)
        }

        // Approach 3: Try with different zlib headers
        for header: [UInt8] in [[0x78, 0x01], [0x78, 0x5E], [0x78, 0xDA]] {
            var testData = Data(header)
            testData.append(data)

            decompressedSize = testData.withUnsafeBytes { (sourceBytes: UnsafeRawBufferPointer) -> Int in
                guard let sourcePointer = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return 0
                }
                return compression_decode_buffer(
                    destinationBuffer,
                    bufferSize,
                    sourcePointer,
                    testData.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }

            if decompressedSize >= expectedSize {
                return Data(bytes: destinationBuffer, count: expectedSize)
            }
        }

        // If we got close to expected size, accept it
        if decompressedSize > 0 && decompressedSize >= expectedSize - 16 {
            print("   ⚠️ Decompressed size \(decompressedSize) close to expected \(expectedSize), accepting")
            return Data(bytes: destinationBuffer, count: decompressedSize)
        }

        print("   ❌ All decompression methods failed (got \(decompressedSize), expected \(expectedSize))")
        return nil
    }

    /// Legacy inflate method (kept for compatibility)
    static func inflate(_ data: Data, expectedSize: Int) -> Data? {
        return inflateRawDeflate(data, expectedSize: expectedSize)
    }
}
