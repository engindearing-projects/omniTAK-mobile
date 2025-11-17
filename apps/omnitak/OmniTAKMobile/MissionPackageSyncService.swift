import Foundation
import Combine
import Network

/// Core service for bi-directional synchronization of mission packages with TAK servers
@MainActor
class MissionPackageSyncService: ObservableObject {

    // MARK: - Published Properties

    @Published var packages: [MissionPackage] = []
    @Published var activeOperations: [SyncOperation] = []
    @Published var conflicts: [SyncConflict] = []
    @Published var serverConfiguration: ServerConfiguration = ServerConfiguration()
    @Published var statistics: SyncStatistics = SyncStatistics()

    @Published var isConnected: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    @Published var networkStatus: NetworkStatus = .unknown

    @Published var currentOperationProgress: Double = 0
    @Published var totalSyncProgress: Double = 0

    // MARK: - Private Properties

    private var syncTimer: Timer?
    private var networkMonitor: NWPathMonitor?
    private var cancellables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "com.omnitak.sync", qos: .utility)

    private let userDefaults = UserDefaults.standard
    private let packagesKey = "missionPackages"
    private let configKey = "serverConfiguration"
    private let statsKey = "syncStatistics"

    // MARK: - Initialization

    init() {
        loadPersistedData()
        setupNetworkMonitoring()
        startAutoSyncIfEnabled()
    }

    deinit {
        syncTimer?.invalidate()
        networkMonitor?.cancel()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                switch path.status {
                case .satisfied:
                    if path.usesInterfaceType(.wifi) {
                        self.networkStatus = .wifi
                    } else if path.usesInterfaceType(.cellular) {
                        self.networkStatus = .cellular
                    } else {
                        self.networkStatus = .other
                    }
                    self.handleOnlineTransition()
                case .unsatisfied:
                    self.networkStatus = .offline
                    self.handleOfflineTransition()
                case .requiresConnection:
                    self.networkStatus = .offline
                @unknown default:
                    self.networkStatus = .unknown
                }
            }
        }
        networkMonitor?.start(queue: queue)
    }

    private func handleOnlineTransition() {
        if serverConfiguration.enableAutoSync {
            if serverConfiguration.syncOnWiFiOnly && networkStatus != .wifi {
                return
            }
            syncAllPackages()
        }
        updateOfflinePackages()
    }

    private func handleOfflineTransition() {
        isConnected = false
        markPendingOperationsOffline()
    }

    private func markPendingOperationsOffline() {
        for i in packages.indices {
            if packages[i].syncStatus == .syncing {
                packages[i].syncStatus = .offline
            }
        }
    }

    private func updateOfflinePackages() {
        for i in packages.indices {
            if packages[i].syncStatus == .offline {
                packages[i].syncStatus = .pending
            }
        }
    }

    // MARK: - Auto Sync

    private func startAutoSyncIfEnabled() {
        guard serverConfiguration.enableAutoSync else { return }

        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(serverConfiguration.syncIntervalSeconds),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncAllPackages()
            }
        }
    }

    func updateSyncInterval(_ seconds: Int) {
        serverConfiguration.syncIntervalSeconds = seconds
        saveConfiguration()
        startAutoSyncIfEnabled()
    }

    func toggleAutoSync(_ enabled: Bool) {
        serverConfiguration.enableAutoSync = enabled
        saveConfiguration()
        if enabled {
            startAutoSyncIfEnabled()
        } else {
            syncTimer?.invalidate()
            syncTimer = nil
        }
    }

    // MARK: - Server Connection

    func connect() async -> Bool {
        guard serverConfiguration.isConfigured else {
            syncError = "Server not configured"
            return false
        }

        guard networkStatus != .offline else {
            syncError = "No network connection"
            return false
        }

        do {
            let connected = try await performServerHandshake()
            isConnected = connected
            if connected {
                syncError = nil
            }
            return connected
        } catch {
            syncError = "Connection failed: \(error.localizedDescription)"
            isConnected = false
            return false
        }
    }

    private func performServerHandshake() async throws -> Bool {
        // Simulate server handshake
        guard let url = URL(string: "\(serverConfiguration.fullURL)/api/v1/handshake") else {
            throw SyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        if let apiKey = serverConfiguration.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // In production, this would be a real network call
        // For now, simulate success if URL is valid
        try await Task.sleep(nanoseconds: 500_000_000)
        return true
    }

    func disconnect() {
        isConnected = false
        syncTimer?.invalidate()
        syncTimer = nil
    }

    // MARK: - Sync Operations

    func syncAllPackages() {
        guard !isSyncing else { return }
        guard networkStatus != .offline else {
            syncError = "Cannot sync while offline"
            return
        }

        if serverConfiguration.syncOnWiFiOnly && networkStatus != .wifi {
            syncError = "Sync requires WiFi connection"
            return
        }

        Task {
            isSyncing = true
            syncError = nil
            totalSyncProgress = 0

            let packagesToSync = packages.filter { $0.syncStatus != .synced }
            let totalPackages = packagesToSync.count

            for (index, package) in packagesToSync.enumerated() {
                await syncPackage(package)
                totalSyncProgress = Double(index + 1) / Double(totalPackages)
            }

            await fetchNewPackagesFromServer()

            lastSyncTime = Date()
            statistics.lastSyncTime = lastSyncTime
            updateStatistics()
            savePersistedData()

            isSyncing = false
            totalSyncProgress = 1.0
        }
    }

    func syncPackage(_ package: MissionPackage) async {
        guard let index = packages.firstIndex(where: { $0.id == package.id }) else { return }

        packages[index].syncStatus = .syncing
        currentOperationProgress = 0

        let operation = SyncOperation(
            packageId: package.id,
            operationType: .upload,
            status: .inProgress,
            totalBytes: package.metadata.sizeBytes
        )
        activeOperations.append(operation)

        do {
            // Check for conflicts first
            if let conflict = try await checkForConflicts(package) {
                packages[index].syncStatus = .conflict
                conflicts.append(conflict)
                updateOperationStatus(operation.id, status: .failed, error: "Conflict detected")
                return
            }

            // Perform sync
            try await uploadPackageToServer(package)

            packages[index].syncStatus = .synced
            packages[index].serverHash = packages[index].localHash
            packages[index].version += 1

            updateOperationStatus(operation.id, status: .completed)
            statistics.syncedPackages += 1
            statistics.totalBytesUploaded += package.metadata.sizeBytes

        } catch {
            packages[index].syncStatus = .failed
            updateOperationStatus(operation.id, status: .failed, error: error.localizedDescription)
            syncError = "Sync failed: \(error.localizedDescription)"
        }

        currentOperationProgress = 1.0
    }

    private func uploadPackageToServer(_ package: MissionPackage) async throws {
        // Simulate upload with progress
        let chunkSize: Int64 = 1024 * 100 // 100KB chunks
        var bytesUploaded: Int64 = 0

        while bytesUploaded < package.metadata.sizeBytes {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
            bytesUploaded = min(bytesUploaded + chunkSize, package.metadata.sizeBytes)
            currentOperationProgress = Double(bytesUploaded) / Double(package.metadata.sizeBytes)

            if let opIndex = activeOperations.firstIndex(where: { $0.packageId == package.id }) {
                activeOperations[opIndex].bytesTransferred = bytesUploaded
                activeOperations[opIndex].progress = currentOperationProgress
            }
        }
    }

    func downloadPackage(packageId: UUID) async {
        let operation = SyncOperation(
            packageId: packageId,
            operationType: .download,
            status: .inProgress
        )
        activeOperations.append(operation)

        do {
            let package = try await fetchPackageFromServer(packageId)
            packages.append(package)

            updateOperationStatus(operation.id, status: .completed)
            statistics.syncedPackages += 1
            statistics.totalBytesDownloaded += package.metadata.sizeBytes

        } catch {
            updateOperationStatus(operation.id, status: .failed, error: error.localizedDescription)
            syncError = "Download failed: \(error.localizedDescription)"
        }
    }

    private func fetchPackageFromServer(_ packageId: UUID) async throws -> MissionPackage {
        // Simulate server fetch
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Return a mock package
        return MissionPackage(
            id: packageId,
            name: "Downloaded Package",
            description: "Package downloaded from server",
            syncStatus: .synced
        )
    }

    private func fetchNewPackagesFromServer() async {
        // Simulate fetching list of packages from server
        try? await Task.sleep(nanoseconds: 500_000_000)

        // In production, this would fetch actual packages
        // For now, just update connection status
    }

    private func checkForConflicts(_ package: MissionPackage) async throws -> SyncConflict? {
        // Simulate conflict check
        try await Task.sleep(nanoseconds: 100_000_000)

        // Check if server has newer version
        guard let serverHash = package.serverHash,
              let localHash = package.localHash,
              serverHash != localHash else {
            return nil
        }

        // Create conflict if versions differ
        return SyncConflict(
            packageId: package.id,
            packageName: package.name,
            serverVersion: package.version + 1,
            clientVersion: package.version,
            serverModified: Date().addingTimeInterval(-3600),
            clientModified: package.lastModified,
            conflictingFields: ["contents", "metadata"]
        )
    }

    private func updateOperationStatus(_ operationId: UUID, status: SyncOperationStatus, error: String? = nil) {
        guard let index = activeOperations.firstIndex(where: { $0.id == operationId }) else { return }
        activeOperations[index].status = status
        activeOperations[index].errorMessage = error
        if status == .completed || status == .failed || status == .cancelled {
            activeOperations[index].endTime = Date()
        }
    }

    // MARK: - Conflict Resolution

    func resolveConflict(_ conflict: SyncConflict, resolution: ConflictResolution) async {
        guard let conflictIndex = conflicts.firstIndex(where: { $0.id == conflict.id }) else { return }
        guard let packageIndex = packages.firstIndex(where: { $0.id == conflict.packageId }) else { return }

        conflicts[conflictIndex].resolution = resolution

        switch resolution {
        case .serverWins:
            await applyServerVersion(packageId: conflict.packageId)
        case .clientWins:
            await pushClientVersion(packageId: conflict.packageId)
        case .merge:
            await attemptAutoMerge(packageId: conflict.packageId)
        case .manual:
            // Leave for manual resolution
            break
        }

        conflicts[conflictIndex].resolved = true
        conflicts[conflictIndex].resolvedAt = Date()
        packages[packageIndex].syncStatus = .synced

        // Remove resolved conflict
        conflicts.remove(at: conflictIndex)
        savePersistedData()
    }

    private func applyServerVersion(packageId: UUID) async {
        // Fetch and apply server version
        try? await Task.sleep(nanoseconds: 500_000_000)

        if let index = packages.firstIndex(where: { $0.id == packageId }) {
            packages[index].serverHash = packages[index].localHash
            packages[index].syncStatus = .synced
        }
    }

    private func pushClientVersion(packageId: UUID) async {
        // Force push client version to server
        try? await Task.sleep(nanoseconds: 500_000_000)

        if let index = packages.firstIndex(where: { $0.id == packageId }) {
            packages[index].version += 1
            packages[index].syncStatus = .synced
        }
    }

    private func attemptAutoMerge(packageId: UUID) async {
        // Attempt to merge changes
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        if let index = packages.firstIndex(where: { $0.id == packageId }) {
            packages[index].version += 1
            packages[index].syncStatus = .synced
        }
    }

    func resolveAllConflicts(with resolution: ConflictResolution) async {
        for conflict in conflicts {
            await resolveConflict(conflict, resolution: resolution)
        }
    }

    // MARK: - Package Management

    func addPackage(_ package: MissionPackage) {
        var newPackage = package
        newPackage.updateLocalHash()
        packages.append(newPackage)
        statistics.totalPackages += 1
        statistics.pendingPackages += 1
        savePersistedData()
    }

    func removePackage(_ package: MissionPackage) {
        packages.removeAll { $0.id == package.id }
        conflicts.removeAll { $0.packageId == package.id }
        activeOperations.removeAll { $0.packageId == package.id }
        updateStatistics()
        savePersistedData()
    }

    func updatePackage(_ package: MissionPackage) {
        guard let index = packages.firstIndex(where: { $0.id == package.id }) else { return }
        var updatedPackage = package
        updatedPackage.lastModified = Date()
        updatedPackage.updateLocalHash()
        updatedPackage.syncStatus = .pending
        packages[index] = updatedPackage
        savePersistedData()
    }

    // MARK: - Statistics

    private func updateStatistics() {
        statistics.totalPackages = packages.count
        statistics.syncedPackages = packages.filter { $0.syncStatus == .synced }.count
        statistics.pendingPackages = packages.filter { $0.syncStatus == .pending }.count
        statistics.conflictedPackages = packages.filter { $0.syncStatus == .conflict }.count
        statistics.failedPackages = packages.filter { $0.syncStatus == .failed }.count

        if statistics.totalPackages > 0 {
            statistics.successRate = Double(statistics.syncedPackages) / Double(statistics.totalPackages)
        }

        saveStatistics()
    }

    // MARK: - Persistence

    private func loadPersistedData() {
        loadPackages()
        loadConfiguration()
        loadStatistics()
    }

    private func savePersistedData() {
        savePackages()
        saveConfiguration()
        saveStatistics()
    }

    private func loadPackages() {
        guard let data = userDefaults.data(forKey: packagesKey),
              let decoded = try? JSONDecoder().decode([MissionPackage].self, from: data) else {
            return
        }
        packages = decoded
    }

    private func savePackages() {
        guard let encoded = try? JSONEncoder().encode(packages) else { return }
        userDefaults.set(encoded, forKey: packagesKey)
    }

    private func loadConfiguration() {
        guard let data = userDefaults.data(forKey: configKey),
              let decoded = try? JSONDecoder().decode(ServerConfiguration.self, from: data) else {
            return
        }
        serverConfiguration = decoded
    }

    private func saveConfiguration() {
        guard let encoded = try? JSONEncoder().encode(serverConfiguration) else { return }
        userDefaults.set(encoded, forKey: configKey)
    }

    private func loadStatistics() {
        guard let data = userDefaults.data(forKey: statsKey),
              let decoded = try? JSONDecoder().decode(SyncStatistics.self, from: data) else {
            return
        }
        statistics = decoded
    }

    private func saveStatistics() {
        guard let encoded = try? JSONEncoder().encode(statistics) else { return }
        userDefaults.set(encoded, forKey: statsKey)
    }

    // MARK: - Utility Methods

    func clearAllData() {
        packages.removeAll()
        activeOperations.removeAll()
        conflicts.removeAll()
        statistics = SyncStatistics()
        lastSyncTime = nil
        syncError = nil
        savePersistedData()
    }

    func retryFailedOperations() {
        let failedOps = activeOperations.filter { $0.status == .failed && $0.canRetry }
        for operation in failedOps {
            if let index = activeOperations.firstIndex(where: { $0.id == operation.id }) {
                activeOperations[index].retryCount += 1
                activeOperations[index].status = .queued
            }
        }
        syncAllPackages()
    }

    func cancelOperation(_ operation: SyncOperation) {
        guard let index = activeOperations.firstIndex(where: { $0.id == operation.id }) else { return }
        activeOperations[index].status = .cancelled
        activeOperations[index].endTime = Date()
    }

    func removeCompletedOperations() {
        activeOperations.removeAll { $0.status == .completed || $0.status == .cancelled }
    }
}

// MARK: - Supporting Types

enum NetworkStatus: String {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case offline = "Offline"
    case other = "Other"
    case unknown = "Unknown"

    var iconName: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .offline: return "wifi.slash"
        case .other: return "network"
        case .unknown: return "questionmark.circle"
        }
    }
}

enum SyncError: LocalizedError {
    case invalidURL
    case connectionFailed
    case unauthorized
    case serverError(Int)
    case networkUnavailable
    case timeout
    case conflictDetected
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .connectionFailed: return "Failed to connect to server"
        case .unauthorized: return "Authentication failed"
        case .serverError(let code): return "Server error: \(code)"
        case .networkUnavailable: return "Network unavailable"
        case .timeout: return "Request timed out"
        case .conflictDetected: return "Sync conflict detected"
        case .invalidData: return "Invalid data received"
        }
    }
}
