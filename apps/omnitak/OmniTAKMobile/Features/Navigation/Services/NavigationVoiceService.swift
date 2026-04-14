//
//  NavigationVoiceService.swift
//  OmniTAKMobile
//
//  ATAK-style voice guidance for route navigation
//  Provides checkpoint approach and arrival announcements
//

import Foundation
import AVFoundation
import Combine

/// Service for voice-guided navigation announcements (ATAK-style)
class NavigationVoiceService: NSObject, ObservableObject {
    static let shared = NavigationVoiceService()

    // MARK: - Published Properties

    @Published var isMuted: Bool = false {
        didSet {
            if isMuted {
                stopSpeaking()
            }
        }
    }
    @Published var isSpeaking: Bool = false
    @Published var voiceRate: Float = 0.5 // 0.0 - 1.0 (AVSpeechUtteranceDefaultSpeechRate)
    @Published var voiceVolume: Float = 1.0 // 0.0 - 1.0

    // MARK: - Private Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var announcementQueue: [NavigationAnnouncement] = []
    private var isProcessingQueue = false
    private var lastAnnouncementTime: Date?
    private var lastAnnouncementType: AnnouncementType?

    // Configurable settings
    private let minimumAnnouncementInterval: TimeInterval = 3.0 // Minimum seconds between announcements
    private let preferredVoiceLanguage = "en-US"

    // MARK: - Announcement Types

    enum AnnouncementType: String {
        case approaching = "approaching"
        case arrival = "arrival"
        case offRoute = "off_route"
        case routeRecalculated = "recalculated"
        case navigationStart = "start"
        case navigationEnd = "end"
        case checkpoint = "checkpoint"
    }

    struct NavigationAnnouncement {
        let text: String
        let type: AnnouncementType
        let priority: AnnouncementPriority
        let waypointName: String?

        enum AnnouncementPriority: Int, Comparable {
            case low = 0
            case normal = 1
            case high = 2
            case critical = 3

            static func < (lhs: AnnouncementPriority, rhs: AnnouncementPriority) -> Bool {
                return lhs.rawValue < rhs.rawValue
            }
        }
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }

    private func setupAudioSession() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playback category with duck others to lower music/podcasts during speech
            try audioSession.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("[NavigationVoiceService] Failed to setup audio session: \(error)")
        }
        #endif
    }

    // MARK: - Public API

    /// Announce approaching a checkpoint
    func announceApproaching(waypointName: String, distance: Double, customCue: String? = nil) {
        guard !isMuted else { return }

        let distanceText = formatDistance(distance)
        let text = customCue ?? "Approaching \(waypointName) in \(distanceText)"

        let announcement = NavigationAnnouncement(
            text: text,
            type: .approaching,
            priority: distance < 100 ? .high : .normal,
            waypointName: waypointName
        )

        queueAnnouncement(announcement)
    }

    /// Announce arrival at a checkpoint
    func announceArrival(waypointName: String, customCue: String? = nil) {
        guard !isMuted else { return }

        let text = customCue ?? "You have arrived at \(waypointName)"

        let announcement = NavigationAnnouncement(
            text: text,
            type: .arrival,
            priority: .high,
            waypointName: waypointName
        )

        queueAnnouncement(announcement)
    }

    /// Announce checkpoint reached during multi-waypoint route
    func announceCheckpointReached(waypointName: String, checkpointNumber: Int, totalCheckpoints: Int) {
        guard !isMuted else { return }

        let text = "Checkpoint \(checkpointNumber) of \(totalCheckpoints). \(waypointName)"

        let announcement = NavigationAnnouncement(
            text: text,
            type: .checkpoint,
            priority: .normal,
            waypointName: waypointName
        )

        queueAnnouncement(announcement)
    }

    /// Announce off-route warning
    func announceOffRoute(distance: Double) {
        guard !isMuted else { return }

        let distanceText = formatDistance(distance)
        let text = "You are off route by \(distanceText). Recalculating."

        let announcement = NavigationAnnouncement(
            text: text,
            type: .offRoute,
            priority: .critical,
            waypointName: nil
        )

        // Clear lower priority announcements for off-route
        announcementQueue.removeAll { $0.priority < .critical }
        queueAnnouncement(announcement)
    }

    /// Announce route recalculated
    func announceRouteRecalculated() {
        guard !isMuted else { return }

        let announcement = NavigationAnnouncement(
            text: "Route recalculated",
            type: .routeRecalculated,
            priority: .normal,
            waypointName: nil
        )

        queueAnnouncement(announcement)
    }

    /// Announce navigation started
    func announceNavigationStart(routeName: String, totalCheckpoints: Int) {
        guard !isMuted else { return }

        let text = "Starting navigation on \(routeName). \(totalCheckpoints) checkpoints."

        let announcement = NavigationAnnouncement(
            text: text,
            type: .navigationStart,
            priority: .high,
            waypointName: nil
        )

        queueAnnouncement(announcement)
    }

    /// Announce navigation complete
    func announceNavigationComplete(routeName: String) {
        guard !isMuted else { return }

        let text = "You have completed the route \(routeName). Navigation ended."

        let announcement = NavigationAnnouncement(
            text: text,
            type: .navigationEnd,
            priority: .high,
            waypointName: nil
        )

        queueAnnouncement(announcement)
    }

    /// Speak arbitrary text
    func speak(_ text: String, priority: NavigationAnnouncement.AnnouncementPriority = .normal) {
        guard !isMuted else { return }

        let announcement = NavigationAnnouncement(
            text: text,
            type: .checkpoint,
            priority: priority,
            waypointName: nil
        )

        queueAnnouncement(announcement)
    }

    /// Stop all speech immediately
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        announcementQueue.removeAll()
        isProcessingQueue = false
        isSpeaking = false
    }

    /// Toggle mute state
    func toggleMute() {
        isMuted.toggle()
    }

    // MARK: - Private Methods

    private func queueAnnouncement(_ announcement: NavigationAnnouncement) {
        // Prevent duplicate announcements of the same type within minimum interval
        if let lastTime = lastAnnouncementTime,
           let lastType = lastAnnouncementType,
           lastType == announcement.type,
           Date().timeIntervalSince(lastTime) < minimumAnnouncementInterval {
            return
        }

        // Insert based on priority (higher priority first)
        if let insertIndex = announcementQueue.firstIndex(where: { $0.priority < announcement.priority }) {
            announcementQueue.insert(announcement, at: insertIndex)
        } else {
            announcementQueue.append(announcement)
        }

        processQueue()
    }

    private func processQueue() {
        guard !isProcessingQueue, !announcementQueue.isEmpty else { return }

        isProcessingQueue = true

        let announcement = announcementQueue.removeFirst()
        speakAnnouncement(announcement)
    }

    private func speakAnnouncement(_ announcement: NavigationAnnouncement) {
        let utterance = AVSpeechUtterance(string: announcement.text)

        // Configure voice
        if let voice = AVSpeechSynthesisVoice(language: preferredVoiceLanguage) {
            utterance.voice = voice
        }

        // Set rate and volume
        utterance.rate = voiceRate
        utterance.volume = voiceVolume

        // Slightly higher pitch for warnings
        if announcement.priority == .critical {
            utterance.pitchMultiplier = 1.1
        }

        // Track announcement
        lastAnnouncementTime = Date()
        lastAnnouncementType = announcement.type

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            let km = meters / 1000
            if km >= 10 {
                return String(format: "%.0f kilometers", km)
            } else {
                return String(format: "%.1f kilometers", km)
            }
        } else {
            let rounded = Int(meters / 50) * 50 // Round to nearest 50m
            return "\(max(50, rounded)) meters"
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension NavigationVoiceService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.isProcessingQueue = false
            self?.processQueue() // Process next in queue
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.isProcessingQueue = false
        }
    }
}
