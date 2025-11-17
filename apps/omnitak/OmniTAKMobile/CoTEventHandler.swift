//
//  CoTEventHandler.swift
//  OmniTAKMobile
//
//  Route parsed CoT events to appropriate handlers and publish updates via Combine
//

import Foundation
import Combine
import CoreLocation
import UserNotifications

// MARK: - CoT Event Handler

class CoTEventHandler: ObservableObject {
    static let shared = CoTEventHandler()

    // MARK: - Published Properties

    @Published var latestPositionUpdate: CoTEvent?
    @Published var latestChatMessage: ChatMessage?
    @Published var activeEmergencies: [EmergencyAlert] = []
    @Published var receivedEventCount: Int = 0
    @Published var lastEventTime: Date?

    // MARK: - Event Publishers

    let positionUpdatePublisher = PassthroughSubject<CoTEvent, Never>()
    let chatMessagePublisher = PassthroughSubject<ChatMessage, Never>()
    let emergencyAlertPublisher = PassthroughSubject<EmergencyAlert, Never>()
    let waypointPublisher = PassthroughSubject<CoTEvent, Never>()
    let unknownEventPublisher = PassthroughSubject<String, Never>()

    // MARK: - Notification Names

    static let positionUpdateNotification = Notification.Name("CoTPositionUpdate")
    static let chatMessageNotification = Notification.Name("CoTChatMessage")
    static let emergencyAlertNotification = Notification.Name("CoTEmergencyAlert")
    static let waypointNotification = Notification.Name("CoTWaypoint")

    // MARK: - Dependencies

    private weak var takService: TAKService?
    private weak var chatManager: ChatManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    var enableNotifications: Bool = true
    var enableEmergencyAlerts: Bool = true

    private init() {
        requestNotificationPermissions()
    }

    // MARK: - Setup

    func configure(takService: TAKService, chatManager: ChatManager) {
        self.takService = takService
        self.chatManager = chatManager

        print("CoTEventHandler: Configured with TAKService and ChatManager")
    }

    // MARK: - Event Routing

    /// Handle a parsed CoT event and route to appropriate handlers
    func handle(event: CoTEventType) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.receivedEventCount += 1
            self.lastEventTime = Date()

            switch event {
            case .positionUpdate(let cotEvent):
                self.handlePositionUpdate(cotEvent)

            case .chatMessage(let message):
                self.handleChatMessage(message)

            case .emergencyAlert(let alert):
                self.handleEmergencyAlert(alert)

            case .waypoint(let cotEvent):
                self.handleWaypoint(cotEvent)

            case .unknown(let typeStr):
                self.handleUnknownEvent(typeStr)
            }
        }
    }

    // MARK: - Position Update Handler

    private func handlePositionUpdate(_ event: CoTEvent) {
        print("CoTEventHandler: Position update from \(event.detail.callsign) at (\(event.point.lat), \(event.point.lon))")

        latestPositionUpdate = event

        // Update TAKService markers
        takService?.updateEnhancedMarker(from: event)
        takService?.cotEvents.append(event)

        // Update participant info for chat
        if let participant = ChatXMLParser.parseParticipantFromPresence(xml: createPresenceXML(from: event)) {
            chatManager?.updateParticipant(participant)
            chatManager?.updateParticipantLastSeen(id: participant.id)
        } else {
            // Create basic participant from CoT event
            let participant = ChatParticipant(
                id: event.uid,
                callsign: event.detail.callsign,
                lastSeen: event.time,
                isOnline: true
            )
            chatManager?.updateParticipant(participant)
        }

        // Publish to Combine subscribers
        positionUpdatePublisher.send(event)

        // Post notification for map updates
        NotificationCenter.default.post(
            name: CoTEventHandler.positionUpdateNotification,
            object: self,
            userInfo: ["event": event]
        )

        // Trigger callback
        takService?.onCoTReceived?(event)
    }

    // MARK: - Chat Message Handler

    private func handleChatMessage(_ message: ChatMessage) {
        print("CoTEventHandler: Chat message from \(message.senderCallsign): \(message.messageText)")

        latestChatMessage = message

        // Forward to ChatManager
        chatManager?.receiveMessage(message)

        // Update sender's last seen
        chatManager?.updateParticipantLastSeen(id: message.senderId)

        // Publish to Combine subscribers
        chatMessagePublisher.send(message)

        // Post notification
        NotificationCenter.default.post(
            name: CoTEventHandler.chatMessageNotification,
            object: self,
            userInfo: ["message": message]
        )

        // Trigger callback
        takService?.onChatMessageReceived?(message)

        // Show local notification if app is in background
        if enableNotifications {
            showChatNotification(message)
        }
    }

    // MARK: - Emergency Alert Handler

    private func handleEmergencyAlert(_ alert: EmergencyAlert) {
        print("CoTEventHandler: Emergency alert from \(alert.callsign) - \(alert.alertType.rawValue)")

        if alert.cancel {
            // Remove cancelled alert
            activeEmergencies.removeAll { $0.uid == alert.uid }
            print("CoTEventHandler: Emergency cancelled for \(alert.callsign)")
        } else {
            // Add or update active emergency
            if let index = activeEmergencies.firstIndex(where: { $0.uid == alert.uid }) {
                activeEmergencies[index] = alert
            } else {
                activeEmergencies.append(alert)
            }
        }

        // Publish to Combine subscribers
        emergencyAlertPublisher.send(alert)

        // Post notification
        NotificationCenter.default.post(
            name: CoTEventHandler.emergencyAlertNotification,
            object: self,
            userInfo: ["alert": alert]
        )

        // Show critical notification for emergencies
        if enableEmergencyAlerts && !alert.cancel {
            showEmergencyNotification(alert)
        }
    }

    // MARK: - Waypoint Handler

    private func handleWaypoint(_ event: CoTEvent) {
        print("CoTEventHandler: Waypoint received - \(event.detail.callsign)")

        // Import waypoint into WaypointManager
        _ = WaypointManager.shared.importFromCoT(
            uid: event.uid,
            type: event.type,
            coordinate: CLLocationCoordinate2D(latitude: event.point.lat, longitude: event.point.lon),
            callsign: event.detail.callsign,
            altitude: event.point.hae,
            remarks: event.detail.remarks
        )

        // Update marker
        takService?.updateEnhancedMarker(from: event)

        // Publish to Combine subscribers
        waypointPublisher.send(event)

        // Post notification
        NotificationCenter.default.post(
            name: CoTEventHandler.waypointNotification,
            object: self,
            userInfo: ["event": event]
        )
    }

    // MARK: - Unknown Event Handler

    private func handleUnknownEvent(_ typeStr: String) {
        print("CoTEventHandler: Unknown event type: \(typeStr)")
        unknownEventPublisher.send(typeStr)
    }

    // MARK: - Helper Methods

    private func createPresenceXML(from event: CoTEvent) -> String {
        // Create minimal presence XML for participant parsing
        return """
        <event uid="\(event.uid)" type="\(event.type)" time="\(ISO8601DateFormatter().string(from: event.time))">
            <point lat="\(event.point.lat)" lon="\(event.point.lon)" hae="\(event.point.hae)"/>
            <detail>
                <contact callsign="\(event.detail.callsign)"/>
            </detail>
        </event>
        """
    }

    // MARK: - Notifications

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("CoTEventHandler: Notification permissions granted")
            } else if let error = error {
                print("CoTEventHandler: Notification permission error: \(error)")
            }
        }
    }

    private func showChatNotification(_ message: ChatMessage) {
        let content = UNMutableNotificationContent()
        content.title = "Message from \(message.senderCallsign)"
        content.body = message.messageText
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: message.id,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("CoTEventHandler: Failed to show chat notification: \(error)")
            }
        }
    }

    private func showEmergencyNotification(_ alert: EmergencyAlert) {
        let content = UNMutableNotificationContent()
        content.title = "EMERGENCY ALERT"
        content.body = "\(alert.callsign): \(alert.alertType.rawValue)"
        if let message = alert.message {
            content.body += " - \(message)"
        }
        content.sound = .defaultCritical
        content.interruptionLevel = .critical

        let request = UNNotificationRequest(
            identifier: alert.id,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("CoTEventHandler: Failed to show emergency notification: \(error)")
            }
        }
    }

    // MARK: - Statistics

    func getStatistics() -> CoTEventStatistics {
        return CoTEventStatistics(
            totalEventsReceived: receivedEventCount,
            activeEmergencyCount: activeEmergencies.count,
            lastEventTime: lastEventTime
        )
    }

    // MARK: - Cleanup

    func clearEmergencies() {
        activeEmergencies.removeAll()
    }

    func resetStatistics() {
        receivedEventCount = 0
        lastEventTime = nil
    }
}

// MARK: - Statistics Model

struct CoTEventStatistics {
    let totalEventsReceived: Int
    let activeEmergencyCount: Int
    let lastEventTime: Date?
}
