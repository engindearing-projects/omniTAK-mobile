//
//  ChatView.swift
//  OmniTAKTest
//
//  Conversation list UI with unread counts
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var chatManager: ChatManager
    @State private var showNewChat = false
    @Environment(\.dismiss) var dismiss

    var sortedConversations: [Conversation] {
        chatManager.conversations.sorted { $0.lastActivity > $1.lastActivity }
    }

    var body: some View {
        NavigationView {
            ZStack {
                if chatManager.conversations.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        Text("No Conversations")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Start a new chat to begin messaging")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    // Conversation list
                    List {
                        ForEach(sortedConversations) { conversation in
                            NavigationLink(destination: ConversationView(
                                chatManager: chatManager,
                                conversation: conversation
                            )) {
                                ConversationRow(conversation: conversation)
                            }
                        }
                        .onDelete(perform: deleteConversations)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Team Chat")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewChat = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatView(chatManager: chatManager)
            }
        }
    }

    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            let conversation = sortedConversations[index]
            // Don't allow deleting "All Chat Users"
            if conversation.id != ChatRoom.allUsersId {
                chatManager.deleteConversation(conversation)
            }
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(conversation.isGroupChat ? Color.blue : Color.green)
                    .frame(width: 50, height: 50)

                Image(systemName: conversation.isGroupChat ? "person.3.fill" : "person.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }

            // Conversation info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.displayTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    if let lastMessage = conversation.lastMessage {
                        Text(formatTimestamp(lastMessage.timestamp))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }

                HStack {
                    if let lastMessage = conversation.lastMessage {
                        HStack(spacing: 4) {
                            if lastMessage.hasImage {
                                Image(systemName: "photo")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            Text(lastMessage.previewText)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                    } else {
                        Text("No messages yet")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .italic()
                    }

                    Spacer()

                    if conversation.unreadCount > 0 {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 24, height: 24)
                            Text("\(conversation.unreadCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - New Chat View

struct NewChatView: View {
    @ObservedObject var chatManager: ChatManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedParticipant: ChatParticipant?

    var availableParticipants: [ChatParticipant] {
        chatManager.participants.filter { $0.id != chatManager.currentUserId }
    }

    var body: some View {
        NavigationView {
            List {
                Section("GROUP CHATS") {
                    Button(action: {
                        selectAllChatUsers()
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 40, height: 40)
                                Image(systemName: "person.3.fill")
                                    .foregroundColor(.white)
                            }
                            Text("All Chat Users")
                                .foregroundColor(.primary)
                        }
                    }
                }

                if !availableParticipants.isEmpty {
                    Section("PARTICIPANTS") {
                        ForEach(availableParticipants) { participant in
                            Button(action: {
                                startDirectChat(with: participant)
                            }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(participant.callsign)
                                            .foregroundColor(.primary)
                                        if participant.isOnline {
                                            Text("Online")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14))
                                }
                            }
                        }
                    }
                } else {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "person.3.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No participants available")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("Participants will appear as they send position updates")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func selectAllChatUsers() {
        // Navigate to "All Chat Users" conversation
        if chatManager.conversations.first(where: { $0.id == ChatRoom.allUsersId }) != nil {
            // Dismiss this sheet - the user can select it from the list
            dismiss()
        }
    }

    private func startDirectChat(with participant: ChatParticipant) {
        _ = chatManager.getOrCreateDirectConversation(with: participant)
        dismiss()
        // The conversation will now appear in the list
    }
}
