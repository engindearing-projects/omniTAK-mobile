//
//  VideoStreamModels.swift
//  OmniTAKMobile
//
//  Video streaming data models for RTSP/HTTP/HLS streams
//

import Foundation
import CoreLocation

// MARK: - Video Protocol

enum VideoProtocol: String, Codable, CaseIterable {
    case http = "HTTP"
    case rtsp = "RTSP"
    case hls = "HLS"

    var displayName: String {
        return self.rawValue
    }

    var iconName: String {
        switch self {
        case .http: return "globe"
        case .rtsp: return "video.badge.waveform"
        case .hls: return "play.rectangle.on.rectangle"
        }
    }

    var isNativelySupported: Bool {
        switch self {
        case .http, .hls: return true
        case .rtsp: return false
        }
    }

    var description: String {
        switch self {
        case .http: return "Standard HTTP video stream"
        case .rtsp: return "Real Time Streaming Protocol (limited support)"
        case .hls: return "HTTP Live Streaming (Apple native)"
        }
    }
}

// MARK: - Video Feed Status

enum VideoFeedStatus: String, Codable {
    case unknown
    case connecting
    case playing
    case paused
    case buffering
    case error
    case stopped

    var iconName: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .connecting: return "wifi"
        case .playing: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .buffering: return "hourglass"
        case .error: return "exclamationmark.triangle.fill"
        case .stopped: return "stop.circle"
        }
    }
}

// MARK: - Video Feed

struct VideoFeed: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var url: String
    var streamProtocol: VideoProtocol
    var lastAccessed: Date
    var thumbnailData: Data?
    var location: CodableCoordinate?
    var createdAt: Date
    var notes: String?
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        streamProtocol: VideoProtocol = .http,
        lastAccessed: Date = Date(),
        thumbnailData: Data? = nil,
        location: CLLocationCoordinate2D? = nil,
        createdAt: Date = Date(),
        notes: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.streamProtocol = streamProtocol
        self.lastAccessed = lastAccessed
        self.thumbnailData = thumbnailData
        self.location = location.map { CodableCoordinate(coordinate: $0) }
        self.createdAt = createdAt
        self.notes = notes
        self.isFavorite = isFavorite
    }

    // MARK: - Validation

    var isValidURL: Bool {
        guard let url = URL(string: url) else { return false }

        switch streamProtocol {
        case .http:
            return url.scheme == "http" || url.scheme == "https"
        case .rtsp:
            return url.scheme == "rtsp" || url.scheme == "rtsps"
        case .hls:
            let isHTTP = url.scheme == "http" || url.scheme == "https"
            let isM3U8 = url.pathExtension.lowercased() == "m3u8" || url.absoluteString.contains(".m3u8")
            return isHTTP && isM3U8
        }
    }

    var urlObject: URL? {
        URL(string: url)
    }

    // MARK: - Helpers

    var hasLocation: Bool {
        location != nil
    }

    var coordinate: CLLocationCoordinate2D? {
        location?.clCoordinate
    }

    mutating func updateLastAccessed() {
        lastAccessed = Date()
    }

    mutating func setLocation(_ coordinate: CLLocationCoordinate2D?) {
        if let coord = coordinate {
            location = CodableCoordinate(coordinate: coord)
        } else {
            location = nil
        }
    }

    // MARK: - Equatable

    static func == (lhs: VideoFeed, rhs: VideoFeed) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Video Stream Error

enum VideoStreamError: Error, LocalizedError {
    case invalidURL
    case unsupportedProtocol
    case networkUnavailable
    case streamNotFound
    case playbackFailed(String)
    case authenticationRequired
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid stream URL"
        case .unsupportedProtocol:
            return "RTSP streams require external player support. Native iOS only supports HTTP/HLS streams."
        case .networkUnavailable:
            return "Network connection unavailable"
        case .streamNotFound:
            return "Stream not found or unavailable"
        case .playbackFailed(let reason):
            return "Playback failed: \(reason)"
        case .authenticationRequired:
            return "Authentication required for this stream"
        case .timeout:
            return "Connection timed out"
        }
    }
}

// MARK: - Video Playback State

struct VideoPlaybackState: Equatable {
    var status: VideoFeedStatus
    var currentTime: TimeInterval
    var duration: TimeInterval?
    var isLive: Bool
    var bufferProgress: Double
    var error: String?

    static let initial = VideoPlaybackState(
        status: .unknown,
        currentTime: 0,
        duration: nil,
        isLive: true,
        bufferProgress: 0,
        error: nil
    )

    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    var formattedDuration: String {
        guard let dur = duration else { return "--:--" }
        return formatTime(dur)
    }

    var progressPercentage: Double {
        guard let dur = duration, dur > 0 else { return 0 }
        return currentTime / dur
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Video Feed Statistics

struct VideoFeedStatistics {
    var totalPlayTime: TimeInterval
    var playCount: Int
    var lastError: String?
    var lastErrorDate: Date?

    static let initial = VideoFeedStatistics(
        totalPlayTime: 0,
        playCount: 0,
        lastError: nil,
        lastErrorDate: nil
    )
}
