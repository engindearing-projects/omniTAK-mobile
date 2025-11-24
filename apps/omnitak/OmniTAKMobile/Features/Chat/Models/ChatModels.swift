//
//  ChatModels.swift
//  OmniTAKTest
//
//  TAK GeoChat data models
//

import Foundation

// MARK: - Chat Message Status

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case failed
}

// MARK: - Chat Message Type

enum ChatMessageType: String, Codable {
    case text
    case geochat
    case system
    case location
    case alert
}

// MARK: - Attachment Type

enum AttachmentType: String, Codable {
    case none
    case image
    case file
}

// MARK: - Image Attachment

struct ImageAttachment: Codable, Equatable {
    let id: String
    let filename: String
    let mimeType: String
    let fileSize: Int
    var localPath: String? // Path to locally stored file
    var thumbnailPath: String? // Path to thumbnail
    var base64Data: String? // For inline transmission (smaller images)
    var remoteURL: String? // For external link reference

    init(
        id: String = UUID().uuidString,
        filename: String,
        mimeType: String = "image/jpeg",
        fileSize: Int,
        localPath: String? = nil,
        thumbnailPath: String? = nil,
        base64Data: String? = nil,
        remoteURL: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.localPath = localPath
        self.thumbnailPath = thumbnailPath
        self.base64Data = base64Data
        self.remoteURL = remoteURL
    }
}

// MARK: - Chat Participant

struct ChatParticipant: Identifiable, Codable, Equatable, Hashable {
    let id: String // UID from CoT
    var callsign: String
    var endpoint: String? // IP:port:protocol for direct messages
    var lastSeen: Date
    var isOnline: Bool

    init(id: String, callsign: String, endpoint: String? = nil, lastSeen: Date = Date(), isOnline: Bool = true) {
        self.id = id
        self.callsign = callsign
        self.endpoint = endpoint
        self.lastSeen = lastSeen
        self.isOnline = isOnline
    }

    static func == (lhs: ChatParticipant, rhs: ChatParticipant) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String // Message UID
    let conversationId: String
    let senderId: String // Sender UID
    let senderCallsign: String
    var recipientId: String? // nil for group messages
    var recipientCallsign: String?
    let messageText: String
    let timestamp: Date
    var status: MessageStatus
    let type: ChatMessageType
    var isFromSelf: Bool
    var attachmentType: AttachmentType
    var imageAttachment: ImageAttachment?

    init(
        id: String = UUID().uuidString,
        conversationId: String,
        senderId: String,
        senderCallsign: String,
        recipientId: String? = nil,
        recipientCallsign: String? = nil,
        messageText: String,
        timestamp: Date = Date(),
        status: MessageStatus = .sending,
        type: ChatMessageType = .geochat,
        isFromSelf: Bool = false,
        attachmentType: AttachmentType = .none,
        imageAttachment: ImageAttachment? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderCallsign = senderCallsign
        self.recipientId = recipientId
        self.recipientCallsign = recipientCallsign
        self.messageText = messageText
        self.timestamp = timestamp
        self.status = status
        self.type = type
        self.isFromSelf = isFromSelf
        self.attachmentType = attachmentType
        self.imageAttachment = imageAttachment
    }

    // Helper to check if message has image
    var hasImage: Bool {
        return attachmentType == .image && imageAttachment != nil
    }

    // Get display text for message preview
    var previewText: String {
        if hasImage {
            return messageText.isEmpty ? "[Photo]" : messageText
        }
        return messageText
    }
}

// MARK: - Conversation

struct Conversation: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var participants: [ChatParticipant]
    var lastMessage: ChatMessage?
    var unreadCount: Int
    var isGroupChat: Bool
    var lastActivity: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        participants: [ChatParticipant] = [],
        lastMessage: ChatMessage? = nil,
        unreadCount: Int = 0,
        isGroupChat: Bool = false,
        lastActivity: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.participants = participants
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
        self.isGroupChat = isGroupChat
        self.lastActivity = lastActivity
    }

    // Get the display title for the conversation
    var displayTitle: String {
        if isGroupChat {
            return title
        } else if let participant = participants.first {
            return participant.callsign
        } else {
            return title
        }
    }

    // Get the other participant in a direct conversation
    func otherParticipant(excludingId: String) -> ChatParticipant? {
        return participants.first { $0.id != excludingId }
    }
}

// MARK: - Chat Room Type

enum ChatRoomType: String, Codable {
    case direct
    case group
    case broadcast
}

// MARK: - Chat Room (All Users)

struct ChatRoom {
    static let allUsersId = "All Chat Users"
    static let allUsersTitle = "All Chat Users"
    static let broadcastId = "BROADCAST"
    static let broadcastTitle = "All Users Broadcast"

    static func createAllUsersConversation() -> Conversation {
        return Conversation(
            id: allUsersId,
            title: allUsersTitle,
            participants: [],
            isGroupChat: true
        )
    }

    static func createBroadcastConversation() -> Conversation {
        return Conversation(
            id: broadcastId,
            title: broadcastTitle,
            participants: [],
            isGroupChat: true
        )
    }
}

// MARK: - Conversation Statistics

struct ConversationStats {
    let totalMessages: Int
    let sentMessages: Int
    let receivedMessages: Int
    let firstMessageDate: Date?
    let lastMessageDate: Date?

    var averageMessagesPerDay: Double {
        guard let firstDate = firstMessageDate, let lastDate = lastMessageDate else {
            return 0
        }

        let daysDifference = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1
        let days = max(daysDifference, 1)
        return Double(totalMessages) / Double(days)
    }
}
