//
//  TAKMissionSyncManager.swift
//  OmniTAKMobile
//
//  TAK Server mission synchronization manager
//  Handles mission retrieval, subscription, content download, and sync
//  Based on TAKAware's DataSyncManager pattern
//

import Foundation
import Combine
import CoreLocation

// MARK: - Mission Sync Models

struct SyncedMission: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String?
    let creatorUid: String?
    let isSubscribed: Bool
    let isPasswordProtected: Bool
    let lastSyncTime: Date?
    let uidCount: Int
    let contentCount: Int
    var localUids: [SyncedMissionUID]
    var localContents: [SyncedMissionContent]

    init(from missionInfo: TAKMissionInfo, subscribed: Bool = false) {
        self.id = UUID()
        self.name = missionInfo.name
        self.description = missionInfo.description
        self.creatorUid = missionInfo.creatorUid
        self.isSubscribed = subscribed
        self.isPasswordProtected = missionInfo.passwordProtected
        self.lastSyncTime = nil
        self.uidCount = missionInfo.uids?.count ?? 0
        self.contentCount = missionInfo.contents?.count ?? 0
        self.localUids = []
        self.localContents = []
    }

    mutating func updateSubscription(_ subscribed: Bool) -> SyncedMission {
        return SyncedMission(
            id: self.id,
            name: self.name,
            description: self.description,
            creatorUid: self.creatorUid,
            isSubscribed: subscribed,
            isPasswordProtected: self.isPasswordProtected,
            lastSyncTime: self.lastSyncTime,
            uidCount: self.uidCount,
            contentCount: self.contentCount,
            localUids: self.localUids,
            localContents: self.localContents
        )
    }

    init(id: UUID, name: String, description: String?, creatorUid: String?, isSubscribed: Bool, isPasswordProtected: Bool, lastSyncTime: Date?, uidCount: Int, contentCount: Int, localUids: [SyncedMissionUID], localContents: [SyncedMissionContent]) {
        self.id = id
        self.name = name
        self.description = description
        self.creatorUid = creatorUid
        self.isSubscribed = isSubscribed
        self.isPasswordProtected = isPasswordProtected
        self.lastSyncTime = lastSyncTime
        self.uidCount = uidCount
        self.contentCount = contentCount
        self.localUids = localUids
        self.localContents = localContents
    }
}

struct SyncedMissionUID: Identifiable, Codable {
    let id: UUID
    let uid: String
    let callsign: String?
    let type: String?
    let location: CLLocationCoordinate2D?
    let timestamp: Date?
    let cotXml: String?

    enum CodingKeys: String, CodingKey {
        case id, uid, callsign, type, latitude, longitude, timestamp, cotXml
    }

    init(from missionUID: TAKMissionUID) {
        self.id = UUID()
        self.uid = missionUID.data
        self.callsign = missionUID.details?.callsign
        self.type = missionUID.details?.type
        if let loc = missionUID.details?.location {
            self.location = CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lon)
        } else {
            self.location = nil
        }
        self.timestamp = missionUID.timestamp
        self.cotXml = nil
    }

    init(id: UUID, uid: String, callsign: String?, type: String?, location: CLLocationCoordinate2D?, timestamp: Date?, cotXml: String?) {
        self.id = id
        self.uid = uid
        self.callsign = callsign
        self.type = type
        self.location = location
        self.timestamp = timestamp
        self.cotXml = cotXml
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        uid = try container.decode(String.self, forKey: .uid)
        callsign = try container.decodeIfPresent(String.self, forKey: .callsign)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)
        cotXml = try container.decodeIfPresent(String.self, forKey: .cotXml)

        if let lat = try container.decodeIfPresent(Double.self, forKey: .latitude),
           let lon = try container.decodeIfPresent(Double.self, forKey: .longitude) {
            location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            location = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(uid, forKey: .uid)
        try container.encodeIfPresent(callsign, forKey: .callsign)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(cotXml, forKey: .cotXml)
        try container.encodeIfPresent(location?.latitude, forKey: .latitude)
        try container.encodeIfPresent(location?.longitude, forKey: .longitude)
    }
}

struct SyncedMissionContent: Identifiable, Codable {
    let id: UUID
    let hash: String
    let name: String
    let mimeType: String?
    let size: Int64
    let localPath: String?
    let isDownloaded: Bool

    init(from missionContent: TAKMissionContent) {
        self.id = UUID()
        self.hash = missionContent.hash
        self.name = missionContent.name
        self.mimeType = missionContent.mimeType
        self.size = missionContent.size ?? 0
        self.localPath = nil
        self.isDownloaded = false
    }

    func withLocalPath(_ path: String) -> SyncedMissionContent {
        return SyncedMissionContent(
            id: self.id,
            hash: self.hash,
            name: self.name,
            mimeType: self.mimeType,
            size: self.size,
            localPath: path,
            isDownloaded: true
        )
    }

    init(id: UUID, hash: String, name: String, mimeType: String?, size: Int64, localPath: String?, isDownloaded: Bool) {
        self.id = id
        self.hash = hash
        self.name = name
        self.mimeType = mimeType
        self.size = size
        self.localPath = localPath
        self.isDownloaded = isDownloaded
    }
}

enum MissionSyncStatus: String, Codable {
    case idle
    case connecting
    case fetchingMissions
    case subscribing
    case downloading
    case syncing
    case completed
    case failed
}

// MARK: - TAK Mission Sync Manager

@MainActor
class TAKMissionSyncManager: ObservableObject {
    static let shared = TAKMissionSyncManager()

    // MARK: - Published Properties

    @Published var missions: [SyncedMission] = []
    @Published var subscribedMissions: [SyncedMission] = []
    @Published var status: MissionSyncStatus = .idle
    @Published var lastError: String?
    @Published var isLoading: Bool = false
    @Published var downloadProgress: Double = 0
    @Published var lastSyncTime: Date?

    // MARK: - Private Properties

    private let apiClient = TAKRestAPIClient.shared
    private let userDefaults = UserDefaults.standard
    private let missionsKey = "synced_missions"
    private var deviceUID: String = ""

    // MARK: - Initialization

    init() {
        loadPersistedMissions()
        deviceUID = getDeviceUID()
    }

    private func getDeviceUID() -> String {
        if let uid = userDefaults.string(forKey: "device_uid") {
            return uid
        }
        let newUID = "OmniTAK-\(UUID().uuidString)"
        userDefaults.set(newUID, forKey: "device_uid")
        return newUID
    }

    // MARK: - Public Methods

    /// Configure and connect to a TAK server
    func connect(to server: TAKServer) async throws {
        status = .connecting
        lastError = nil

        apiClient.configure(from: server)

        // Test connection by fetching server version
        do {
            _ = try await apiClient.getServerVersion()
            status = .idle
        } catch {
            status = .failed
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Fetch available missions from the server
    func fetchMissions() async throws -> [TAKMissionInfo] {
        status = .fetchingMissions
        isLoading = true
        lastError = nil

        defer {
            isLoading = false
        }

        do {
            let missionInfos = try await apiClient.getMissions()

            // Update local missions list
            for info in missionInfos {
                if let index = missions.firstIndex(where: { $0.name == info.name }) {
                    // Update existing
                    var updated = SyncedMission(from: info, subscribed: missions[index].isSubscribed)
                    updated = SyncedMission(
                        id: missions[index].id,
                        name: updated.name,
                        description: updated.description,
                        creatorUid: updated.creatorUid,
                        isSubscribed: missions[index].isSubscribed,
                        isPasswordProtected: updated.isPasswordProtected,
                        lastSyncTime: missions[index].lastSyncTime,
                        uidCount: updated.uidCount,
                        contentCount: updated.contentCount,
                        localUids: missions[index].localUids,
                        localContents: missions[index].localContents
                    )
                    missions[index] = updated
                } else {
                    // Add new
                    missions.append(SyncedMission(from: info))
                }
            }

            updateSubscribedMissions()
            saveMissions()
            status = .completed
            lastSyncTime = Date()

            return missionInfos
        } catch {
            status = .failed
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Subscribe to a mission
    func subscribe(to missionName: String, password: String? = nil) async throws {
        status = .subscribing
        lastError = nil

        do {
            try await apiClient.subscribeMission(name: missionName, uid: deviceUID, password: password)

            // Update local subscription status
            if let index = missions.firstIndex(where: { $0.name == missionName }) {
                missions[index] = SyncedMission(
                    id: missions[index].id,
                    name: missions[index].name,
                    description: missions[index].description,
                    creatorUid: missions[index].creatorUid,
                    isSubscribed: true,
                    isPasswordProtected: missions[index].isPasswordProtected,
                    lastSyncTime: missions[index].lastSyncTime,
                    uidCount: missions[index].uidCount,
                    contentCount: missions[index].contentCount,
                    localUids: missions[index].localUids,
                    localContents: missions[index].localContents
                )
            }

            updateSubscribedMissions()
            saveMissions()

            // Download mission content
            try await downloadMissionContent(missionName: missionName, password: password)

            status = .completed
        } catch {
            status = .failed
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Unsubscribe from a mission
    func unsubscribe(from missionName: String) async throws {
        lastError = nil

        do {
            try await apiClient.unsubscribeMission(name: missionName, uid: deviceUID)

            // Update local subscription status
            if let index = missions.firstIndex(where: { $0.name == missionName }) {
                missions[index] = SyncedMission(
                    id: missions[index].id,
                    name: missions[index].name,
                    description: missions[index].description,
                    creatorUid: missions[index].creatorUid,
                    isSubscribed: false,
                    isPasswordProtected: missions[index].isPasswordProtected,
                    lastSyncTime: missions[index].lastSyncTime,
                    uidCount: missions[index].uidCount,
                    contentCount: missions[index].contentCount,
                    localUids: missions[index].localUids,
                    localContents: missions[index].localContents
                )
            }

            updateSubscribedMissions()
            saveMissions()
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Download mission content (UIDs and files)
    func downloadMissionContent(missionName: String, password: String? = nil) async throws {
        status = .downloading
        downloadProgress = 0
        lastError = nil

        do {
            // Fetch detailed mission info
            let missionInfo = try await apiClient.getMission(name: missionName, password: password)

            guard let index = missions.firstIndex(where: { $0.name == missionName }) else {
                throw TAKAPIError.notFound("Mission")
            }

            // Process UIDs
            var localUids: [SyncedMissionUID] = []
            if let uids = missionInfo.uids {
                for uid in uids {
                    localUids.append(SyncedMissionUID(from: uid))
                }
            }

            downloadProgress = 0.3

            // Fetch CoT content
            let cotContent = try await apiClient.getMissionContent(name: missionName, password: password)

            // Parse CoT messages and update UIDs with full XML
            for (i, var uid) in localUids.enumerated() {
                // Check if this UID's data is in the CoT content
                if cotContent.contains(uid.uid) {
                    // Extract the relevant CoT event XML
                    if let cotXml = extractCoTEvent(for: uid.uid, from: cotContent) {
                        localUids[i] = SyncedMissionUID(
                            id: uid.id,
                            uid: uid.uid,
                            callsign: uid.callsign,
                            type: uid.type,
                            location: uid.location,
                            timestamp: uid.timestamp,
                            cotXml: cotXml
                        )
                    }
                }
            }

            downloadProgress = 0.5

            // Process contents (files)
            var localContents: [SyncedMissionContent] = []
            if let contents = missionInfo.contents {
                for content in contents {
                    localContents.append(SyncedMissionContent(from: content))
                }
            }

            downloadProgress = 0.7

            // Update mission
            missions[index] = SyncedMission(
                id: missions[index].id,
                name: missionName,
                description: missionInfo.description,
                creatorUid: missionInfo.creatorUid,
                isSubscribed: true,
                isPasswordProtected: missionInfo.passwordProtected,
                lastSyncTime: Date(),
                uidCount: localUids.count,
                contentCount: localContents.count,
                localUids: localUids,
                localContents: localContents
            )

            updateSubscribedMissions()
            saveMissions()

            downloadProgress = 1.0
            status = .completed

            // Process UIDs as CoT markers
            processDownloadedUIDs(localUids)

        } catch {
            status = .failed
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Download a specific content file
    func downloadContentFile(mission: SyncedMission, content: SyncedMissionContent) async throws -> URL {
        let data = try await apiClient.downloadContent(hash: content.hash)

        // Save to documents
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let missionPath = documentsPath
            .appendingPathComponent("Missions")
            .appendingPathComponent(mission.name)

        if !FileManager.default.fileExists(atPath: missionPath.path) {
            try FileManager.default.createDirectory(at: missionPath, withIntermediateDirectories: true)
        }

        let filePath = missionPath.appendingPathComponent(content.name)
        try data.write(to: filePath)

        // Update content with local path
        if let missionIndex = missions.firstIndex(where: { $0.id == mission.id }),
           let contentIndex = missions[missionIndex].localContents.firstIndex(where: { $0.id == content.id }) {
            missions[missionIndex].localContents[contentIndex] = content.withLocalPath(filePath.path)
            saveMissions()
        }

        return filePath
    }

    /// Sync all subscribed missions
    func syncAllSubscribed() async {
        status = .syncing
        isLoading = true

        for mission in subscribedMissions {
            do {
                try await downloadMissionContent(missionName: mission.name)
            } catch {
                print("Failed to sync mission \(mission.name): \(error)")
            }
        }

        isLoading = false
        status = .completed
        lastSyncTime = Date()
    }

    // MARK: - Private Methods

    private func extractCoTEvent(for uid: String, from cotContent: String) -> String? {
        // Find event element containing this UID
        let pattern = "<event[^>]*uid=\"\(uid)\"[^>]*>.*?</event>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: cotContent, options: [], range: NSRange(cotContent.startIndex..., in: cotContent)),
           let range = Range(match.range, in: cotContent) {
            return String(cotContent[range])
        }
        return nil
    }

    private func processDownloadedUIDs(_ uids: [SyncedMissionUID]) {
        // Process each UID as a CoT marker
        for uid in uids {
            if let cotXml = uid.cotXml {
                // Parse and add to TAKService markers
                if let eventType = CoTMessageParser.parse(xml: cotXml) {
                    CoTEventHandler.shared.handle(event: eventType)
                }
            } else if let location = uid.location {
                // Create a marker from the UID info
                print("Creating marker for \(uid.callsign ?? uid.uid) at \(location)")
            }
        }
    }

    private func updateSubscribedMissions() {
        subscribedMissions = missions.filter { $0.isSubscribed }
    }

    // MARK: - Persistence

    private func loadPersistedMissions() {
        if let data = userDefaults.data(forKey: missionsKey),
           let decoded = try? JSONDecoder().decode([SyncedMission].self, from: data) {
            missions = decoded
            updateSubscribedMissions()
        }
    }

    private func saveMissions() {
        if let encoded = try? JSONEncoder().encode(missions) {
            userDefaults.set(encoded, forKey: missionsKey)
        }
    }

    /// Clear all synced missions
    func clearAll() {
        missions.removeAll()
        subscribedMissions.removeAll()
        saveMissions()
    }
}
