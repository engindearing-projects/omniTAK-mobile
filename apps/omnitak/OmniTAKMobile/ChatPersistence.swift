//
//  ChatPersistence.swift
//  OmniTAKTest
//
//  Save/load chat messages and conversations with JSON file storage
//

import Foundation

class ChatPersistence {
    static let shared = ChatPersistence()

    private let conversationsKey = "chat_conversations"
    private let messagesKey = "chat_messages"
    private let participantsKey = "chat_participants"

    // File URLs for JSON storage
    private var conversationsURL: URL {
        getDocumentsDirectory().appendingPathComponent("conversations.json")
    }

    private var messagesURL: URL {
        getDocumentsDirectory().appendingPathComponent("messages.json")
    }

    private var participantsURL: URL {
        getDocumentsDirectory().appendingPathComponent("participants.json")
    }

    private init() {
        // Migrate from UserDefaults to file storage if needed
        migrateFromUserDefaults()
    }

    // MARK: - Directory Helper

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Conversations

    func saveConversations(_ conversations: [Conversation]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(conversations)
            try data.write(to: conversationsURL)
            print("Saved \(conversations.count) conversations to file")
        } catch {
            print("Failed to save conversations: \(error)")
        }
    }

    func loadConversations() -> [Conversation] {
        guard FileManager.default.fileExists(atPath: conversationsURL.path) else {
            print("No conversations file found, returning empty array")
            return []
        }

        do {
            let data = try Data(contentsOf: conversationsURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let conversations = try decoder.decode([Conversation].self, from: data)
            print("Loaded \(conversations.count) conversations from file")
            return conversations
        } catch {
            print("Failed to load conversations: \(error)")
            return []
        }
    }

    // MARK: - Messages

    func saveMessages(_ messages: [ChatMessage]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(messages)
            try data.write(to: messagesURL)
            print("Saved \(messages.count) messages to file")
        } catch {
            print("Failed to save messages: \(error)")
        }
    }

    func loadMessages() -> [ChatMessage] {
        guard FileManager.default.fileExists(atPath: messagesURL.path) else {
            print("No messages file found, returning empty array")
            return []
        }

        do {
            let data = try Data(contentsOf: messagesURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let messages = try decoder.decode([ChatMessage].self, from: data)
            print("Loaded \(messages.count) messages from file")
            return messages
        } catch {
            print("Failed to load messages: \(error)")
            return []
        }
    }

    // MARK: - Participants

    func saveParticipants(_ participants: [ChatParticipant]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(participants)
            try data.write(to: participantsURL)
            print("Saved \(participants.count) participants to file")
        } catch {
            print("Failed to save participants: \(error)")
        }
    }

    func loadParticipants() -> [ChatParticipant] {
        guard FileManager.default.fileExists(atPath: participantsURL.path) else {
            print("No participants file found, returning empty array")
            return []
        }

        do {
            let data = try Data(contentsOf: participantsURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let participants = try decoder.decode([ChatParticipant].self, from: data)
            print("Loaded \(participants.count) participants from file")
            return participants
        } catch {
            print("Failed to load participants: \(error)")
            return []
        }
    }

    // MARK: - Clear All Data

    func clearAllData() {
        do {
            if FileManager.default.fileExists(atPath: conversationsURL.path) {
                try FileManager.default.removeItem(at: conversationsURL)
            }
            if FileManager.default.fileExists(atPath: messagesURL.path) {
                try FileManager.default.removeItem(at: messagesURL)
            }
            if FileManager.default.fileExists(atPath: participantsURL.path) {
                try FileManager.default.removeItem(at: participantsURL)
            }
            print("Cleared all chat data")
        } catch {
            print("Failed to clear chat data: \(error)")
        }
    }

    // MARK: - Migration from UserDefaults

    private func migrateFromUserDefaults() {
        // Check if we have old data in UserDefaults
        if let oldData = UserDefaults.standard.data(forKey: conversationsKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let conversations = try decoder.decode([Conversation].self, from: oldData)
                saveConversations(conversations)
                UserDefaults.standard.removeObject(forKey: conversationsKey)
                print("Migrated conversations from UserDefaults to file storage")
            } catch {
                print("Failed to migrate conversations: \(error)")
            }
        }

        if let oldData = UserDefaults.standard.data(forKey: messagesKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let messages = try decoder.decode([ChatMessage].self, from: oldData)
                saveMessages(messages)
                UserDefaults.standard.removeObject(forKey: messagesKey)
                print("Migrated messages from UserDefaults to file storage")
            } catch {
                print("Failed to migrate messages: \(error)")
            }
        }

        if let oldData = UserDefaults.standard.data(forKey: participantsKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let participants = try decoder.decode([ChatParticipant].self, from: oldData)
                saveParticipants(participants)
                UserDefaults.standard.removeObject(forKey: participantsKey)
                print("Migrated participants from UserDefaults to file storage")
            } catch {
                print("Failed to migrate participants: \(error)")
            }
        }
    }
}
