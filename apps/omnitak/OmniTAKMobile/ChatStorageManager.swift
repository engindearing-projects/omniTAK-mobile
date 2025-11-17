//
//  ChatStorageManager.swift
//  OmniTAKMobile
//
//  Persistence layer for chat message queue
//

import Foundation

// MARK: - Queued Message Status

enum QueuedMessageStatus: String, Codable {
    case pending
    case sending
    case failed
    case completed
}

// MARK: - Queued Message

struct QueuedMessage: Codable, Identifiable {
    let id: String
    let message: ChatMessage
    let xmlPayload: String
    var retryCount: Int
    let createdAt: Date
    var lastAttempt: Date?
    var status: QueuedMessageStatus
}

// MARK: - Chat Storage Manager

class ChatStorageManager {
    static let shared = ChatStorageManager()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // Storage keys
    private let queuedMessagesKey = "com.omnitak.chat.queue"

    private init() {}

    // MARK: - Queued Messages

    func loadQueuedMessages() -> [QueuedMessage] {
        guard let data = defaults.data(forKey: queuedMessagesKey) else { return [] }
        return (try? decoder.decode([QueuedMessage].self, from: data)) ?? []
    }

    func saveQueuedMessages(_ messages: [QueuedMessage]) {
        if let data = try? encoder.encode(messages) {
            defaults.set(data, forKey: queuedMessagesKey)
        }
    }

    // MARK: - Clear All

    func clearAllData() {
        defaults.removeObject(forKey: queuedMessagesKey)
    }
}
