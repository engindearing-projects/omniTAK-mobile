//
//  ContactDetailView.swift
//  OmniTAKMobile
//
//  Detailed view for individual contacts showing position, status, and messaging options
//

import SwiftUI
import MapKit

struct ContactDetailView: View {
    let contact: ChatParticipant
    @ObservedObject var chatManager: ChatManager
    @Environment(\.dismiss) var dismiss
    @State private var showChat = false
    @State private var mapRegion: MKCoordinateRegion

    init(contact: ChatParticipant, chatManager: ChatManager) {
        self.contact = contact
        self.chatManager = chatManager

        // Initialize map region (default location, will be updated if contact has position)
        _mapRegion = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    var statusColor: Color {
        contact.isOnline ? Color(hex: "#4CAF50") : Color(hex: "#666666")
    }

    var lastSeenText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: contact.lastSeen)
    }

    var timeSinceLastSeen: String {
        let now = Date()
        let interval = now.timeIntervalSince(contact.lastSeen)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }

    var messageCount: Int {
        chatManager.messages.filter { message in
            message.senderId == contact.id || message.recipientId == contact.id
        }.count
    }

    var lastMessageDate: Date? {
        chatManager.messages
            .filter { message in
                message.senderId == contact.id || message.recipientId == contact.id
            }
            .sorted { $0.timestamp > $1.timestamp }
            .first?
            .timestamp
    }

    var body: some View {
        NavigationView {
            ZStack {
                // ATAK-style dark background
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Header Section with Avatar
                        VStack(spacing: 16) {
                            // Status indicator avatar
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#2A2A2A"))
                                    .frame(width: 100, height: 100)

                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(hex: "#1E1E1E"), lineWidth: 3)
                                    )
                                    .offset(x: 35, y: 35)

                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color(hex: "#FFFC00"))
                            }
                            .shadow(color: Color(hex: "#FFFC00").opacity(0.3), radius: 10)

                            // Callsign
                            Text(contact.callsign)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)

                            // Status badge
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: statusColor, radius: 4)

                                Text(contact.isOnline ? "ONLINE" : "OFFLINE")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(statusColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#2A2A2A"))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "#2A2A2A"),
                                    Color(hex: "#1E1E1E")
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(Color(hex: "#FFFC00")),
                            alignment: .bottom
                        )

                        // Information Sections
                        VStack(spacing: 16) {
                            // Connection Info Section
                            DetailSection(title: "CONNECTION INFO") {
                                DetailRow(
                                    icon: "antenna.radiowaves.left.and.right",
                                    label: "Unit ID",
                                    value: contact.id,
                                    valueColor: Color(hex: "#FFFC00")
                                )

                                DetailRow(
                                    icon: "clock.fill",
                                    label: "Last Seen",
                                    value: lastSeenText,
                                    valueColor: Color(hex: "#CCCCCC")
                                )

                                DetailRow(
                                    icon: "timer",
                                    label: "Time Since",
                                    value: timeSinceLastSeen,
                                    valueColor: statusColor
                                )

                                if let endpoint = contact.endpoint {
                                    DetailRow(
                                        icon: "network",
                                        label: "Endpoint",
                                        value: endpoint,
                                        valueColor: Color(hex: "#CCCCCC")
                                    )
                                }
                            }

                            // Communication Section
                            DetailSection(title: "COMMUNICATION") {
                                DetailRow(
                                    icon: "message.fill",
                                    label: "Messages",
                                    value: "\(messageCount) message\(messageCount == 1 ? "" : "s")",
                                    valueColor: Color(hex: "#CCCCCC")
                                )

                                if let lastMsg = lastMessageDate {
                                    DetailRow(
                                        icon: "clock.arrow.circlepath",
                                        label: "Last Message",
                                        value: formatDate(lastMsg),
                                        valueColor: Color(hex: "#CCCCCC")
                                    )
                                }
                            }

                            // Action Buttons
                            VStack(spacing: 12) {
                                ATAKButton(
                                    icon: "message.fill",
                                    title: "Send Message",
                                    color: Color(hex: "#FFFC00")
                                ) {
                                    startChat()
                                }

                                ATAKButton(
                                    icon: "mappin.circle.fill",
                                    title: "Show on Map",
                                    color: Color(hex: "#4CAF50")
                                ) {
                                    // TODO: Navigate to map and center on contact position
                                }

                                ATAKButton(
                                    icon: "location.fill",
                                    title: "Navigate to Contact",
                                    color: Color(hex: "#2196F3")
                                ) {
                                    // TODO: Start navigation to contact
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("Contact Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                },
                trailing: Menu {
                    Button(action: { startChat() }) {
                        Label("Send Message", systemImage: "message")
                    }
                    Button(action: { /* TODO: Share contact */ }) {
                        Label("Share Contact", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive, action: { /* TODO: Block contact */ }) {
                        Label("Block Contact", systemImage: "hand.raised")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            )
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showChat) {
                if let conversation = chatManager.conversations.first(where: {
                    $0.participants.contains(where: { $0.id == contact.id })
                }) {
                    ConversationView(chatManager: chatManager, conversation: conversation)
                }
            }
        }
    }

    private func startChat() {
        _ = chatManager.getOrCreateDirectConversation(with: contact)
        showChat = true
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Detail Section

struct DetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: "#999999"))
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content
            }
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#3A3A3A"), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - ATAK Button

struct ATAKButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#666666"))
            }
            .padding(16)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview

struct ContactDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let chatManager = ChatManager.shared
        let contact = ChatParticipant(
            id: "ALPHA-1-UID",
            callsign: "ALPHA-1",
            endpoint: "192.168.1.100:4242:tcp",
            lastSeen: Date().addingTimeInterval(-300),
            isOnline: true
        )

        return ContactDetailView(contact: contact, chatManager: chatManager)
    }
}
