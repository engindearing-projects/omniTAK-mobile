//
//  VideoStreamService.swift
//  OmniTAKMobile
//
//  Service for managing video feeds and stream persistence
//

import Foundation
import Combine
import CoreLocation

class VideoStreamService: ObservableObject {
    static let shared = VideoStreamService()

    // MARK: - Published Properties

    @Published var feeds: [VideoFeed] = []
    @Published var recentFeeds: [VideoFeed] = []
    @Published var activeStreamCount: Int = 0

    // MARK: - Storage Keys

    private let feedsStorageKey = "VideoFeeds"
    private let recentFeedsKey = "RecentVideoFeeds"
    private let maxRecentFeeds = 10

    // MARK: - Initialization

    private init() {
        loadFeeds()
    }

    // MARK: - Feed Management

    func addFeed(_ feed: VideoFeed) {
        let newFeed = feed

        // Validate URL before adding
        guard newFeed.isValidURL else {
            print("VideoStreamService: Invalid URL for feed \(feed.name)")
            return
        }

        // Check for duplicates
        if !feeds.contains(where: { $0.url == feed.url }) {
            feeds.append(newFeed)
            saveFeeds()
            print("VideoStreamService: Added feed '\(newFeed.name)'")
        } else {
            print("VideoStreamService: Feed with URL already exists")
        }
    }

    func updateFeed(_ feed: VideoFeed) {
        if let index = feeds.firstIndex(where: { $0.id == feed.id }) {
            feeds[index] = feed
            saveFeeds()
            print("VideoStreamService: Updated feed '\(feed.name)'")
        }
    }

    func deleteFeed(_ feed: VideoFeed) {
        feeds.removeAll { $0.id == feed.id }
        recentFeeds.removeAll { $0.id == feed.id }
        saveFeeds()
        saveRecentFeeds()
        print("VideoStreamService: Deleted feed '\(feed.name)'")
    }

    func deleteFeed(at indexSet: IndexSet) {
        let feedsToDelete = indexSet.map { feeds[$0] }
        feeds.remove(atOffsets: indexSet)

        for feed in feedsToDelete {
            recentFeeds.removeAll { $0.id == feed.id }
        }

        saveFeeds()
        saveRecentFeeds()
    }

    func toggleFavorite(_ feed: VideoFeed) {
        if let index = feeds.firstIndex(where: { $0.id == feed.id }) {
            feeds[index].isFavorite.toggle()
            saveFeeds()
        }
    }

    // MARK: - Recent Feeds

    func markFeedAccessed(_ feed: VideoFeed) {
        // Update last accessed time in main list
        if let index = feeds.firstIndex(where: { $0.id == feed.id }) {
            feeds[index].updateLastAccessed()
            saveFeeds()
        }

        // Update recent feeds list
        var updatedFeed = feed
        updatedFeed.updateLastAccessed()

        // Remove if already in recent list
        recentFeeds.removeAll { $0.id == feed.id }

        // Add to front of list
        recentFeeds.insert(updatedFeed, at: 0)

        // Trim to max size
        if recentFeeds.count > maxRecentFeeds {
            recentFeeds = Array(recentFeeds.prefix(maxRecentFeeds))
        }

        saveRecentFeeds()
    }

    func clearRecentFeeds() {
        recentFeeds.removeAll()
        saveRecentFeeds()
    }

    // MARK: - URL Validation

    func validateStreamURL(_ urlString: String) -> (isValid: Bool, protocol: VideoProtocol?, error: String?) {
        guard let url = URL(string: urlString) else {
            return (false, nil, "Invalid URL format")
        }

        guard let scheme = url.scheme?.lowercased() else {
            return (false, nil, "URL missing scheme (http://, https://, rtsp://)")
        }

        var detectedProtocol: VideoProtocol?

        switch scheme {
        case "rtsp", "rtsps":
            detectedProtocol = .rtsp
        case "http", "https":
            if url.pathExtension.lowercased() == "m3u8" || urlString.contains(".m3u8") {
                detectedProtocol = .hls
            } else {
                detectedProtocol = .http
            }
        default:
            return (false, nil, "Unsupported URL scheme: \(scheme)")
        }

        // Check for common issues
        if url.host == nil || url.host!.isEmpty {
            return (false, detectedProtocol, "URL missing host")
        }

        return (true, detectedProtocol, nil)
    }

    func detectProtocol(from urlString: String) -> VideoProtocol {
        let validation = validateStreamURL(urlString)
        return validation.protocol ?? .http
    }

    // MARK: - Filtering and Sorting

    var favoriteFeeds: [VideoFeed] {
        feeds.filter { $0.isFavorite }
    }

    var feedsWithLocation: [VideoFeed] {
        feeds.filter { $0.hasLocation }
    }

    func feeds(forProtocol protocol: VideoProtocol) -> [VideoFeed] {
        feeds.filter { $0.streamProtocol == `protocol` }
    }

    func sortedFeeds(by sortOption: FeedSortOption) -> [VideoFeed] {
        switch sortOption {
        case .name:
            return feeds.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recentlyAccessed:
            return feeds.sorted { $0.lastAccessed > $1.lastAccessed }
        case .dateCreated:
            return feeds.sorted { $0.createdAt > $1.createdAt }
        case .favorite:
            return feeds.sorted { $0.isFavorite && !$1.isFavorite }
        }
    }

    // MARK: - Persistence

    private func saveFeeds() {
        do {
            let data = try JSONEncoder().encode(feeds)
            UserDefaults.standard.set(data, forKey: feedsStorageKey)
            print("VideoStreamService: Saved \(feeds.count) feeds")
        } catch {
            print("VideoStreamService: Failed to save feeds: \(error)")
        }
    }

    private func loadFeeds() {
        guard let data = UserDefaults.standard.data(forKey: feedsStorageKey) else {
            print("VideoStreamService: No saved feeds found")
            return
        }

        do {
            feeds = try JSONDecoder().decode([VideoFeed].self, from: data)
            print("VideoStreamService: Loaded \(feeds.count) feeds")
        } catch {
            print("VideoStreamService: Failed to load feeds: \(error)")
            feeds = []
        }

        loadRecentFeeds()
    }

    private func saveRecentFeeds() {
        do {
            let data = try JSONEncoder().encode(recentFeeds)
            UserDefaults.standard.set(data, forKey: recentFeedsKey)
        } catch {
            print("VideoStreamService: Failed to save recent feeds: \(error)")
        }
    }

    private func loadRecentFeeds() {
        guard let data = UserDefaults.standard.data(forKey: recentFeedsKey) else {
            return
        }

        do {
            recentFeeds = try JSONDecoder().decode([VideoFeed].self, from: data)
        } catch {
            print("VideoStreamService: Failed to load recent feeds: \(error)")
            recentFeeds = []
        }
    }

    // MARK: - Sample Data (for testing)

    func addSampleFeeds() {
        let samples = [
            VideoFeed(
                name: "Sample HLS Stream",
                url: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
                streamProtocol: .hls,
                notes: "Public test HLS stream"
            ),
            VideoFeed(
                name: "Big Buck Bunny",
                url: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
                streamProtocol: .hls,
                notes: "Sample video content"
            )
        ]

        for sample in samples {
            if !feeds.contains(where: { $0.name == sample.name }) {
                addFeed(sample)
            }
        }
    }

    // MARK: - Export/Import

    func exportFeeds() -> Data? {
        try? JSONEncoder().encode(feeds)
    }

    func importFeeds(from data: Data) -> Int {
        do {
            let importedFeeds = try JSONDecoder().decode([VideoFeed].self, from: data)
            var importCount = 0

            for feed in importedFeeds {
                if !feeds.contains(where: { $0.url == feed.url }) {
                    feeds.append(feed)
                    importCount += 1
                }
            }

            if importCount > 0 {
                saveFeeds()
            }

            return importCount
        } catch {
            print("VideoStreamService: Failed to import feeds: \(error)")
            return 0
        }
    }
}

// MARK: - Sort Options

enum FeedSortOption: String, CaseIterable {
    case name = "Name"
    case recentlyAccessed = "Recently Accessed"
    case dateCreated = "Date Created"
    case favorite = "Favorites First"
}
