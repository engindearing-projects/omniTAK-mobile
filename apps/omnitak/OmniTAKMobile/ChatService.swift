//
//  ChatService.swift
//  OmniTAKMobile
//
//  Core messaging service with message queue, retry logic, and CoT integration
//

import Foundation
import Combine
import CoreLocation
import UIKit

// QueuedMessage and QueuedMessageStatus are defined in ChatStorageManager.swift

// MARK: - Chat Service

class ChatService: ObservableObject {
    static let shared = ChatService()

    @Published var messages: [ChatMessage] = []
    @Published var conversations: [Conversation] = []
    @Published var participants: [ChatParticipant] = []
    @Published var unreadCount: Int = 0
    @Published var isConnected: Bool = false
    @Published var queuedMessages: [QueuedMessage] = []

    private let chatManager = ChatManager.shared
    private let storageManager = ChatStorageManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var retryTimer: Timer?
    private let maxRetries = 3
    private let retryInterval: TimeInterval = 30.0

    var currentUserId: String {
        chatManager.currentUserId
    }

    var currentUserCallsign: String {
        get { chatManager.currentUserCallsign }
        set { chatManager.currentUserCallsign = newValue }
    }

    private init() {
        setupBindings()
        loadQueuedMessages()
        startRetryTimer()
    }

    deinit {
        retryTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Sync with ChatManager
        chatManager.$messages
            .sink { [weak self] messages in
                self?.messages = messages
            }
            .store(in: &cancellables)

        chatManager.$conversations
            .sink { [weak self] conversations in
                self?.conversations = conversations
                self?.updateUnreadCount()
            }
            .store(in: &cancellables)

        chatManager.$participants
            .sink { [weak self] participants in
                self?.participants = participants
            }
            .store(in: &cancellables)
    }

    private func updateUnreadCount() {
        unreadCount = conversations.reduce(0) { $0 + $1.unreadCount }
    }

    func configure(takService: TAKService, locationManager: LocationManager) {
        chatManager.configure(takService: takService, locationManager: locationManager)
        isConnected = true
    }

    // MARK: - Send Messages

    func sendTextMessage(_ text: String, to conversationId: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        chatManager.sendMessage(text: text, to: conversationId)
    }

    func sendLocationMessage(location: CLLocation, to conversationId: String) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let locationText = String(format: "Location: %.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
        let message = ChatMessage(
            conversationId: conversationId,
            senderId: currentUserId,
            senderCallsign: currentUserCallsign,
            messageText: locationText,
            timestamp: Date(),
            status: .sending,
            type: .location,
            isFromSelf: true
        )

        chatManager.receiveMessage(message)

        // Generate location-specific CoT if needed
        let xml = ChatCoTGenerator.generateLocationShareXML(
            location: location,
            senderUid: currentUserId,
            senderCallsign: currentUserCallsign
        )

        queueMessage(message, xmlPayload: xml)
    }

    func sendAlertMessage(_ alertText: String, to conversationId: String) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        let message = ChatMessage(
            conversationId: conversationId,
            senderId: currentUserId,
            senderCallsign: currentUserCallsign,
            messageText: "ALERT: \(alertText)",
            timestamp: Date(),
            status: .sending,
            type: .alert,
            isFromSelf: true
        )

        chatManager.receiveMessage(message)
    }

    func sendBroadcastMessage(_ text: String) {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        // Send to broadcast channel
        let broadcastConversationId = ChatRoom.broadcastId

        // Ensure broadcast conversation exists
        if !conversations.contains(where: { $0.id == broadcastConversationId }) {
            let broadcastConversation = ChatRoom.createBroadcastConversation()
            chatManager.conversations.append(broadcastConversation)
        }

        chatManager.sendMessage(text: text, to: broadcastConversationId)
    }

    // MARK: - Receive Messages

    func receiveMessage(_ message: ChatMessage) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        chatManager.receiveMessage(message)
        updateUnreadCount()
    }

    func handleIncomingCoT(xml: String) {
        if let message = ChatXMLParser.parseGeoChatMessage(xml: xml) {
            receiveMessage(message)
        }

        // Also update participant info
        if let participant = ChatXMLParser.parseParticipantFromPresence(xml: xml) {
            chatManager.updateParticipant(participant)
        }
    }

    // MARK: - Conversation Management

    func getOrCreateDirectConversation(with participant: ChatParticipant) -> Conversation {
        return chatManager.getOrCreateDirectConversation(with: participant)
    }

    func getMessages(for conversationId: String) -> [ChatMessage] {
        return chatManager.getMessages(for: conversationId)
    }

    func markConversationAsRead(conversationId: String) {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()

        chatManager.markConversationAsRead(conversationId: conversationId)
        updateUnreadCount()
    }

    func deleteConversation(_ conversation: Conversation) {
        chatManager.deleteConversation(conversation)
    }

    // MARK: - Message Queue

    private func queueMessage(_ message: ChatMessage, xmlPayload: String) {
        let queuedMessage = QueuedMessage(
            id: message.id,
            message: message,
            xmlPayload: xmlPayload,
            retryCount: 0,
            createdAt: Date(),
            lastAttempt: nil,
            status: .pending
        )

        queuedMessages.append(queuedMessage)
        saveQueuedMessages()
        processQueue()
    }

    private func processQueue() {
        guard isConnected else { return }

        for index in queuedMessages.indices {
            guard queuedMessages[index].status == .pending &&
                  queuedMessages[index].retryCount < maxRetries else {
                continue
            }

            queuedMessages[index].status = .sending
            queuedMessages[index].lastAttempt = Date()

            // Attempt to send
            let success = attemptSend(queuedMessages[index])

            if success {
                queuedMessages[index].status = .completed
            } else {
                queuedMessages[index].retryCount += 1
                queuedMessages[index].status = queuedMessages[index].retryCount >= maxRetries ? .failed : .pending
            }
        }

        // Remove completed messages
        queuedMessages.removeAll { $0.status == .completed }
        saveQueuedMessages()
    }

    private func attemptSend(_ queuedMessage: QueuedMessage) -> Bool {
        // In real implementation, this would use TAKService
        print("Attempting to send queued message: \(queuedMessage.id)")
        return true
    }

    private func startRetryTimer() {
        retryTimer = Timer.scheduledTimer(withTimeInterval: retryInterval, repeats: true) { [weak self] _ in
            self?.processQueue()
        }
    }

    private func saveQueuedMessages() {
        storageManager.saveQueuedMessages(queuedMessages)
    }

    private func loadQueuedMessages() {
        queuedMessages = storageManager.loadQueuedMessages()
    }

    // MARK: - Participant Management

    func updateParticipant(_ participant: ChatParticipant) {
        chatManager.updateParticipant(participant)
    }

    func getParticipant(byId id: String) -> ChatParticipant? {
        return chatManager.getParticipant(byId: id)
    }

    func getOnlineParticipants() -> [ChatParticipant] {
        return participants.filter { $0.isOnline && $0.id != currentUserId }
    }

    // MARK: - Search and History

    func searchMessages(query: String) -> [ChatMessage] {
        return chatManager.searchMessages(query: query)
    }

    func getRecentMessages(limit: Int = 50) -> [ChatMessage] {
        return chatManager.getRecentMessages(limit: limit)
    }

    func getConversationStats(for conversationId: String) -> ConversationStats {
        return chatManager.getConversationStats(for: conversationId)
    }

    // MARK: - Cleanup

    func clearOldMessages(olderThanDays days: Int) {
        chatManager.deleteOldMessages(olderThan: days)
    }

    func clearAllData() {
        chatManager.clearAllData()
        queuedMessages.removeAll()
        saveQueuedMessages()
    }
}
