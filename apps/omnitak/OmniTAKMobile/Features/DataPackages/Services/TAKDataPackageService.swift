//
//  TAKDataPackageService.swift
//  OmniTAKMobile
//
//  TAK Server data package retrieval and management service
//  Handles remote data package listing, download, upload, and import
//  Based on TAKAware's DataPackageManager and TAKDataPackageImporter patterns
//

import Foundation
import Combine

// MARK: - Data Package Models

struct RemoteDataPackage: Identifiable, Codable {
    let id: UUID
    let hash: String
    let name: String
    let mimeType: String
    let size: Int64
    let submitter: String?
    let submissionTime: Date?
    let creator: String?
    let expiration: Date?
    let keywords: [String]
    var isDownloaded: Bool
    var localPath: String?

    init(from info: TAKDataPackageInfo) {
        self.id = UUID()
        self.hash = info.hash
        self.name = info.name
        self.mimeType = info.mimeType
        self.size = info.size
        self.submitter = info.submitter
        self.submissionTime = info.submissionTime
        self.creator = info.creator
        self.expiration = info.expiration
        self.keywords = info.keywords ?? []
        self.isDownloaded = false
        self.localPath = nil
    }

    func withDownloadPath(_ path: String) -> RemoteDataPackage {
        var copy = self
        copy.isDownloaded = true
        copy.localPath = path
        return copy
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var isExpired: Bool {
        guard let expiration = expiration else { return false }
        return expiration < Date()
    }
}

enum DataPackageDownloadStatus {
    case idle
    case downloading(progress: Double)
    case processing
    case completed(URL)
    case failed(String)
}

// MARK: - TAK Data Package Service

@MainActor
class TAKDataPackageService: ObservableObject {
    static let shared = TAKDataPackageService()

    // MARK: - Published Properties

    @Published var remotePackages: [RemoteDataPackage] = []
    @Published var downloadedPackages: [RemoteDataPackage] = []
    @Published var isLoading: Bool = false
    @Published var downloadStatus: DataPackageDownloadStatus = .idle
    @Published var lastError: String?
    @Published var lastRefreshTime: Date?

    // MARK: - Private Properties

    private let apiClient = TAKRestAPIClient.shared
    private let userDefaults = UserDefaults.standard
    private let packagesKey = "remote_data_packages"

    // MARK: - Initialization

    init() {
        loadPersistedPackages()
    }

    // MARK: - Public Methods

    /// Fetch available data packages from the TAK server
    func fetchDataPackages() async throws -> [TAKDataPackageInfo] {
        isLoading = true
        lastError = nil

        defer {
            isLoading = false
        }

        do {
            let packageInfos = try await apiClient.getDataPackages()

            // Update local list, preserving download status
            for info in packageInfos {
                if let existingIndex = remotePackages.firstIndex(where: { $0.hash == info.hash }) {
                    // Keep existing download info
                    let existing = remotePackages[existingIndex]
                    remotePackages[existingIndex] = RemoteDataPackage(from: info)
                        .withDownloadPath(existing.localPath ?? "")
                    if !existing.isDownloaded {
                        remotePackages[existingIndex].isDownloaded = false
                        remotePackages[existingIndex].localPath = nil
                    }
                } else {
                    // Add new package
                    remotePackages.append(RemoteDataPackage(from: info))
                }
            }

            // Remove packages that no longer exist on server
            let serverHashes = Set(packageInfos.map { $0.hash })
            remotePackages.removeAll { !serverHashes.contains($0.hash) && !$0.isDownloaded }

            updateDownloadedPackages()
            savePackages()
            lastRefreshTime = Date()

            return packageInfos
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Download a data package by hash
    func downloadPackage(_ package: RemoteDataPackage) async throws -> URL {
        downloadStatus = .downloading(progress: 0)
        lastError = nil

        do {
            let localURL = try await apiClient.downloadDataPackage(hash: package.hash) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadStatus = .downloading(progress: progress)
                }
            }

            downloadStatus = .processing

            // Update package with local path
            if let index = remotePackages.firstIndex(where: { $0.hash == package.hash }) {
                remotePackages[index] = remotePackages[index].withDownloadPath(localURL.path)
            }

            updateDownloadedPackages()
            savePackages()

            downloadStatus = .completed(localURL)

            return localURL
        } catch {
            downloadStatus = .failed(error.localizedDescription)
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Import a downloaded data package
    func importDownloadedPackage(_ package: RemoteDataPackage) async throws {
        guard let localPath = package.localPath else {
            throw TAKAPIError.notFound("Local file")
        }

        let fileURL = URL(fileURLWithPath: localPath)

        // Use DataPackageImportManager to process the package
        let importManager = DataPackageImportManager()

        var lastStatus: ImportStatus = .idle
        try await importManager.importPackage(from: fileURL) { status in
            lastStatus = status
        }

        // Check if import succeeded
        if case .error(let message) = lastStatus {
            throw TAKAPIError.invalidResponse(message)
        }

        print("Imported package: \(package.name)")
    }

    /// Upload a local data package to the server
    func uploadPackage(fileURL: URL, name: String, creatorUid: String? = nil) async throws {
        isLoading = true
        lastError = nil

        defer {
            isLoading = false
        }

        let uid = creatorUid ?? getDeviceUID()

        do {
            try await apiClient.uploadDataPackage(fileURL: fileURL, name: name, creatorUid: uid)

            // Refresh list to show new package
            _ = try? await fetchDataPackages()
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Delete a locally downloaded package
    func deleteLocalPackage(_ package: RemoteDataPackage) {
        guard let localPath = package.localPath else { return }

        let fileURL = URL(fileURLWithPath: localPath)
        try? FileManager.default.removeItem(at: fileURL)

        // Update status
        if let index = remotePackages.firstIndex(where: { $0.hash == package.hash }) {
            remotePackages[index].isDownloaded = false
            remotePackages[index].localPath = nil
        }

        updateDownloadedPackages()
        savePackages()
    }

    /// Get the local path for a downloaded package
    func getLocalPath(for hash: String) -> URL? {
        if let package = remotePackages.first(where: { $0.hash == hash && $0.isDownloaded }),
           let path = package.localPath {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    // MARK: - Private Methods

    private func getDeviceUID() -> String {
        if let uid = userDefaults.string(forKey: "device_uid") {
            return uid
        }
        let newUID = "OmniTAK-\(UUID().uuidString)"
        userDefaults.set(newUID, forKey: "device_uid")
        return newUID
    }

    private func updateDownloadedPackages() {
        downloadedPackages = remotePackages.filter { $0.isDownloaded }
    }

    // MARK: - Persistence

    private func loadPersistedPackages() {
        if let data = userDefaults.data(forKey: packagesKey),
           let decoded = try? JSONDecoder().decode([RemoteDataPackage].self, from: data) {
            remotePackages = decoded
            updateDownloadedPackages()
        }
    }

    private func savePackages() {
        if let encoded = try? JSONEncoder().encode(remotePackages) {
            userDefaults.set(encoded, forKey: packagesKey)
        }
    }

    /// Clear all cached packages
    func clearAll() {
        // Delete local files
        for package in downloadedPackages {
            if let path = package.localPath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }

        remotePackages.removeAll()
        downloadedPackages.removeAll()
        downloadStatus = .idle
        savePackages()
    }
}
