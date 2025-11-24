import Foundation

// MARK: - Mission Package Models

/// Represents a complete mission package with all its contents and metadata
struct MissionPackage: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var contents: [MissionPackageContent]
    var metadata: PackageMetadata
    var syncStatus: SyncStatus
    var lastModified: Date
    var version: Int
    var serverHash: String?
    var localHash: String?

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        contents: [MissionPackageContent] = [],
        metadata: PackageMetadata = PackageMetadata(),
        syncStatus: SyncStatus = .pending,
        lastModified: Date = Date(),
        version: Int = 1,
        serverHash: String? = nil,
        localHash: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.contents = contents
        self.metadata = metadata
        self.syncStatus = syncStatus
        self.lastModified = lastModified
        self.version = version
        self.serverHash = serverHash
        self.localHash = localHash
    }

    /// Calculate local hash for conflict detection
    mutating func updateLocalHash() {
        let data = try? JSONEncoder().encode(contents)
        localHash = data?.base64EncodedString().prefix(32).description
    }

    /// Check if package has conflicts
    var hasConflict: Bool {
        guard let server = serverHash, let local = localHash else { return false }
        return server != local && syncStatus == .conflict
    }
}

/// Metadata associated with a mission package
struct PackageMetadata: Codable, Equatable {
    var creator: String
    var createdAt: Date
    var teamId: String?
    var classification: String
    var expirationDate: Date?
    var tags: [String]
    var priority: PackagePriority
    var sizeBytes: Int64

    init(
        creator: String = "Unknown",
        createdAt: Date = Date(),
        teamId: String? = nil,
        classification: String = "UNCLASSIFIED",
        expirationDate: Date? = nil,
        tags: [String] = [],
        priority: PackagePriority = .normal,
        sizeBytes: Int64 = 0
    ) {
        self.creator = creator
        self.createdAt = createdAt
        self.teamId = teamId
        self.classification = classification
        self.expirationDate = expirationDate
        self.tags = tags
        self.priority = priority
        self.sizeBytes = sizeBytes
    }
}

/// Priority level for mission packages
enum PackagePriority: String, Codable, CaseIterable {
    case critical = "CRITICAL"
    case high = "HIGH"
    case normal = "NORMAL"
    case low = "LOW"

    var displayName: String {
        rawValue.capitalized
    }

    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .normal: return 2
        case .low: return 3
        }
    }
}

// MARK: - Package Content Types

/// Different types of content that can be included in a mission package
enum MissionPackageContent: Codable, Equatable, Identifiable {
    case maps(MapData)
    case markers([MarkerData])
    case routes([RouteData])
    case geofences([GeofenceData])
    case media([MediaData])
    case overlays([OverlayData])
    case checkpoints([CheckpointData])

    var id: String {
        switch self {
        case .maps(let data): return "maps-\(data.id)"
        case .markers(let items): return "markers-\(items.count)"
        case .routes(let items): return "routes-\(items.count)"
        case .geofences(let items): return "geofences-\(items.count)"
        case .media(let items): return "media-\(items.count)"
        case .overlays(let items): return "overlays-\(items.count)"
        case .checkpoints(let items): return "checkpoints-\(items.count)"
        }
    }

    var displayName: String {
        switch self {
        case .maps: return "Maps"
        case .markers: return "Markers"
        case .routes: return "Routes"
        case .geofences: return "Geofences"
        case .media: return "Media"
        case .overlays: return "Overlays"
        case .checkpoints: return "Checkpoints"
        }
    }

    var iconName: String {
        switch self {
        case .maps: return "map.fill"
        case .markers: return "mappin.circle.fill"
        case .routes: return "point.topright.arrow.triangle.backward.to.point.bottomleft.filled.scurvepath"
        case .geofences: return "square.on.square.dashed"
        case .media: return "photo.on.rectangle.angled"
        case .overlays: return "square.3.layers.3d"
        case .checkpoints: return "flag.checkered"
        }
    }

    var itemCount: Int {
        switch self {
        case .maps: return 1
        case .markers(let items): return items.count
        case .routes(let items): return items.count
        case .geofences(let items): return items.count
        case .media(let items): return items.count
        case .overlays(let items): return items.count
        case .checkpoints(let items): return items.count
        }
    }
}

/// Map data content
struct MapData: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var tileSource: String
    var bounds: MapBounds
    var zoomLevels: ClosedRange<Int>
    var offlineAvailable: Bool
    var filePath: String?

    init(
        id: UUID = UUID(),
        name: String,
        tileSource: String,
        bounds: MapBounds,
        zoomLevels: ClosedRange<Int> = 1...18,
        offlineAvailable: Bool = false,
        filePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.tileSource = tileSource
        self.bounds = bounds
        self.zoomLevels = zoomLevels
        self.offlineAvailable = offlineAvailable
        self.filePath = filePath
    }
}

/// Geographic bounds for maps
struct MapBounds: Codable, Equatable {
    var north: Double
    var south: Double
    var east: Double
    var west: Double
}

/// Marker/point of interest data
struct MarkerData: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var type: String
    var iconPath: String?
    var notes: String
    var timestamp: Date

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        type: String = "generic",
        iconPath: String? = nil,
        notes: String = "",
        timestamp: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.type = type
        self.iconPath = iconPath
        self.notes = notes
        self.timestamp = timestamp
    }
}

/// Route/path data
struct RouteData: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var waypoints: [PackageWaypoint]
    var distance: Double
    var estimatedTime: TimeInterval
    var routeType: String
    var color: String

    init(
        id: UUID = UUID(),
        name: String,
        waypoints: [PackageWaypoint] = [],
        distance: Double = 0,
        estimatedTime: TimeInterval = 0,
        routeType: String = "ground",
        color: String = "#FF0000"
    ) {
        self.id = id
        self.name = name
        self.waypoints = waypoints
        self.distance = distance
        self.estimatedTime = estimatedTime
        self.routeType = routeType
        self.color = color
    }
}

/// Individual waypoint in a route
struct PackageWaypoint: Codable, Equatable, Identifiable {
    let id: UUID
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var name: String?
    var order: Int

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        name: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.name = name
        self.order = order
    }
}

/// Geofence/boundary data
struct GeofenceData: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var polygon: [Coordinate]
    var alertOnEntry: Bool
    var alertOnExit: Bool
    var color: String
    var fillOpacity: Double

    init(
        id: UUID = UUID(),
        name: String,
        polygon: [Coordinate] = [],
        alertOnEntry: Bool = true,
        alertOnExit: Bool = true,
        color: String = "#FF0000",
        fillOpacity: Double = 0.3
    ) {
        self.id = id
        self.name = name
        self.polygon = polygon
        self.alertOnEntry = alertOnEntry
        self.alertOnExit = alertOnExit
        self.color = color
        self.fillOpacity = fillOpacity
    }
}

/// Geographic coordinate
struct Coordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double
}

/// Media attachment data
struct MediaData: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var type: MediaType
    var filePath: String
    var thumbnailPath: String?
    var sizeBytes: Int64
    var uploadDate: Date
    var geoTagged: Bool
    var location: Coordinate?

    init(
        id: UUID = UUID(),
        name: String,
        type: MediaType,
        filePath: String,
        thumbnailPath: String? = nil,
        sizeBytes: Int64 = 0,
        uploadDate: Date = Date(),
        geoTagged: Bool = false,
        location: Coordinate? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.sizeBytes = sizeBytes
        self.uploadDate = uploadDate
        self.geoTagged = geoTagged
        self.location = location
    }
}

/// Types of media content
enum MediaType: String, Codable {
    case image = "IMAGE"
    case video = "VIDEO"
    case audio = "AUDIO"
    case document = "DOCUMENT"
}

/// Overlay layer data
struct OverlayData: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var type: String
    var filePath: String
    var opacity: Double
    var visible: Bool

    init(
        id: UUID = UUID(),
        name: String,
        type: String,
        filePath: String,
        opacity: Double = 1.0,
        visible: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.filePath = filePath
        self.opacity = opacity
        self.visible = visible
    }
}

/// Checkpoint data for mission tracking
struct CheckpointData: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var location: Coordinate
    var completed: Bool
    var completedAt: Date?
    var order: Int
    var notes: String

    init(
        id: UUID = UUID(),
        name: String,
        location: Coordinate,
        completed: Bool = false,
        completedAt: Date? = nil,
        order: Int = 0,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.completed = completed
        self.completedAt = completedAt
        self.order = order
        self.notes = notes
    }
}

// MARK: - Sync Status

/// Current synchronization status of a mission package
enum SyncStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case syncing = "SYNCING"
    case synced = "SYNCED"
    case conflict = "CONFLICT"
    case failed = "FAILED"
    case offline = "OFFLINE"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .syncing: return "Syncing"
        case .synced: return "Synced"
        case .conflict: return "Conflict"
        case .failed: return "Failed"
        case .offline: return "Offline"
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock.arrow.circlepath"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.circle.fill"
        case .conflict: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.circle.fill"
        case .offline: return "wifi.slash"
        }
    }

    var color: String {
        switch self {
        case .pending: return "#FFA500"
        case .syncing: return "#00BFFF"
        case .synced: return "#00FF00"
        case .conflict: return "#FFFC00"
        case .failed: return "#FF0000"
        case .offline: return "#808080"
        }
    }
}

// MARK: - Sync Operations

/// Represents a single sync operation (upload or download)
struct SyncOperation: Identifiable, Codable, Equatable {
    let id: UUID
    let packageId: UUID
    var operationType: SyncOperationType
    var status: SyncOperationStatus
    var progress: Double
    var bytesTransferred: Int64
    var totalBytes: Int64
    var startTime: Date
    var endTime: Date?
    var errorMessage: String?
    var retryCount: Int
    var maxRetries: Int

    init(
        id: UUID = UUID(),
        packageId: UUID,
        operationType: SyncOperationType,
        status: SyncOperationStatus = .queued,
        progress: Double = 0,
        bytesTransferred: Int64 = 0,
        totalBytes: Int64 = 0,
        startTime: Date = Date(),
        endTime: Date? = nil,
        errorMessage: String? = nil,
        retryCount: Int = 0,
        maxRetries: Int = 3
    ) {
        self.id = id
        self.packageId = packageId
        self.operationType = operationType
        self.status = status
        self.progress = progress
        self.bytesTransferred = bytesTransferred
        self.totalBytes = totalBytes
        self.startTime = startTime
        self.endTime = endTime
        self.errorMessage = errorMessage
        self.retryCount = retryCount
        self.maxRetries = maxRetries
    }

    var canRetry: Bool {
        retryCount < maxRetries && (status == .failed || status == .cancelled)
    }

    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    var transferRate: Double? {
        guard let dur = duration, dur > 0 else { return nil }
        return Double(bytesTransferred) / dur
    }
}

/// Type of sync operation
enum SyncOperationType: String, Codable {
    case upload = "UPLOAD"
    case download = "DOWNLOAD"
    case merge = "MERGE"
    case delete = "DELETE"

    var displayName: String {
        rawValue.capitalized
    }

    var iconName: String {
        switch self {
        case .upload: return "arrow.up.circle"
        case .download: return "arrow.down.circle"
        case .merge: return "arrow.triangle.merge"
        case .delete: return "trash.circle"
        }
    }
}

/// Status of a sync operation
enum SyncOperationStatus: String, Codable {
    case queued = "QUEUED"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"
    case failed = "FAILED"
    case cancelled = "CANCELLED"
    case paused = "PAUSED"

    var displayName: String {
        switch self {
        case .queued: return "Queued"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .paused: return "Paused"
        }
    }
}

// MARK: - Conflict Resolution

/// Strategy for resolving sync conflicts
enum ConflictResolution: String, Codable, CaseIterable {
    case serverWins = "SERVER_WINS"
    case clientWins = "CLIENT_WINS"
    case merge = "MERGE"
    case manual = "MANUAL"

    var displayName: String {
        switch self {
        case .serverWins: return "Server Wins"
        case .clientWins: return "Client Wins"
        case .merge: return "Auto Merge"
        case .manual: return "Manual Resolution"
        }
    }

    var description: String {
        switch self {
        case .serverWins: return "Accept server version, discard local changes"
        case .clientWins: return "Keep local version, overwrite server"
        case .merge: return "Attempt to merge both versions automatically"
        case .manual: return "Review and resolve conflicts manually"
        }
    }
}

/// Represents a specific conflict between server and client versions
struct SyncConflict: Identifiable, Codable, Equatable {
    let id: UUID
    let packageId: UUID
    var packageName: String
    var serverVersion: Int
    var clientVersion: Int
    var serverModified: Date
    var clientModified: Date
    var conflictingFields: [String]
    var resolution: ConflictResolution?
    var resolved: Bool
    var resolvedAt: Date?

    init(
        id: UUID = UUID(),
        packageId: UUID,
        packageName: String,
        serverVersion: Int,
        clientVersion: Int,
        serverModified: Date,
        clientModified: Date,
        conflictingFields: [String] = [],
        resolution: ConflictResolution? = nil,
        resolved: Bool = false,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.packageId = packageId
        self.packageName = packageName
        self.serverVersion = serverVersion
        self.clientVersion = clientVersion
        self.serverModified = serverModified
        self.clientModified = clientModified
        self.conflictingFields = conflictingFields
        self.resolution = resolution
        self.resolved = resolved
        self.resolvedAt = resolvedAt
    }
}

// MARK: - Server Configuration

/// Configuration for TAK Mission Package server connection
struct ServerConfiguration: Codable, Equatable {
    var serverURL: String
    var port: Int
    var useTLS: Bool
    var certificatePath: String?
    var username: String?
    var apiKey: String?
    var syncIntervalSeconds: Int
    var maxPackageSizeMB: Int
    var enableAutoSync: Bool
    var syncOnWiFiOnly: Bool
    var defaultConflictResolution: ConflictResolution

    init(
        serverURL: String = "",
        port: Int = 8443,
        useTLS: Bool = true,
        certificatePath: String? = nil,
        username: String? = nil,
        apiKey: String? = nil,
        syncIntervalSeconds: Int = 300,
        maxPackageSizeMB: Int = 100,
        enableAutoSync: Bool = true,
        syncOnWiFiOnly: Bool = false,
        defaultConflictResolution: ConflictResolution = .serverWins
    ) {
        self.serverURL = serverURL
        self.port = port
        self.useTLS = useTLS
        self.certificatePath = certificatePath
        self.username = username
        self.apiKey = apiKey
        self.syncIntervalSeconds = syncIntervalSeconds
        self.maxPackageSizeMB = maxPackageSizeMB
        self.enableAutoSync = enableAutoSync
        self.syncOnWiFiOnly = syncOnWiFiOnly
        self.defaultConflictResolution = defaultConflictResolution
    }

    var fullURL: String {
        let scheme = useTLS ? "https" : "http"
        return "\(scheme)://\(serverURL):\(port)"
    }

    var isConfigured: Bool {
        !serverURL.isEmpty && port > 0
    }
}

// MARK: - Sync Statistics

/// Statistics about sync operations
struct SyncStatistics: Codable, Equatable {
    var totalPackages: Int
    var syncedPackages: Int
    var pendingPackages: Int
    var conflictedPackages: Int
    var failedPackages: Int
    var totalBytesUploaded: Int64
    var totalBytesDownloaded: Int64
    var lastSyncTime: Date?
    var averageSyncDuration: TimeInterval
    var successRate: Double

    init(
        totalPackages: Int = 0,
        syncedPackages: Int = 0,
        pendingPackages: Int = 0,
        conflictedPackages: Int = 0,
        failedPackages: Int = 0,
        totalBytesUploaded: Int64 = 0,
        totalBytesDownloaded: Int64 = 0,
        lastSyncTime: Date? = nil,
        averageSyncDuration: TimeInterval = 0,
        successRate: Double = 0
    ) {
        self.totalPackages = totalPackages
        self.syncedPackages = syncedPackages
        self.pendingPackages = pendingPackages
        self.conflictedPackages = conflictedPackages
        self.failedPackages = failedPackages
        self.totalBytesUploaded = totalBytesUploaded
        self.totalBytesDownloaded = totalBytesDownloaded
        self.lastSyncTime = lastSyncTime
        self.averageSyncDuration = averageSyncDuration
        self.successRate = successRate
    }
}
