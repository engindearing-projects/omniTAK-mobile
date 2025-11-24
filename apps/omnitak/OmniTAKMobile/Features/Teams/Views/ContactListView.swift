//
//  ContactListView.swift
//  OmniTAKMobile
//
//  Contact list panel showing all active units with ATAK-style UI
//

import SwiftUI
import MapKit

struct ContactListView: View {
    @ObservedObject var chatManager: ChatManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedContact: ChatParticipant?
    @State private var showContactDetail = false
    @State private var sortOption: ContactSortOption = .lastSeen

    enum ContactSortOption: String, CaseIterable {
        case callsign = "Callsign"
        case lastSeen = "Last Seen"
        case status = "Status"
    }

    var filteredContacts: [ChatParticipant] {
        var contacts = chatManager.participants

        // Filter by search text
        if !searchText.isEmpty {
            contacts = contacts.filter { participant in
                participant.callsign.localizedCaseInsensitiveContains(searchText) ||
                participant.id.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort based on selected option
        switch sortOption {
        case .callsign:
            contacts.sort { $0.callsign < $1.callsign }
        case .lastSeen:
            contacts.sort { $0.lastSeen > $1.lastSeen }
        case .status:
            contacts.sort { (c1, c2) in
                if c1.isOnline != c2.isOnline {
                    return c1.isOnline && !c2.isOnline
                }
                return c1.callsign < c2.callsign
            }
        }

        return contacts
    }

    var onlineCount: Int {
        chatManager.participants.filter { $0.isOnline }.count
    }

    var body: some View {
        NavigationView {
            ZStack {
                // ATAK-style dark background
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Stats Bar
                    HStack(spacing: 20) {
                        StatsBadge(
                            icon: "person.3.fill",
                            label: "Total",
                            value: "\(chatManager.participants.count)",
                            color: Color(hex: "#FFFC00")
                        )

                        StatsBadge(
                            icon: "circle.fill",
                            label: "Online",
                            value: "\(onlineCount)",
                            color: Color(hex: "#4CAF50")
                        )

                        StatsBadge(
                            icon: "circle",
                            label: "Offline",
                            value: "\(chatManager.participants.count - onlineCount)",
                            color: Color(hex: "#666666")
                        )
                    }
                    .padding()
                    .background(Color(hex: "#2A2A2A"))
                    .overlay(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(Color(hex: "#FFFC00")),
                        alignment: .bottom
                    )

                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(hex: "#FFFC00"))

                        TextField("Search contacts...", text: $searchText)
                            .foregroundColor(.white)
                            .autocapitalization(.none)

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color(hex: "#666666"))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(hex: "#2A2A2A"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#FFFC00").opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                    // Sort Options
                    HStack(spacing: 16) {
                        Text("SORT BY:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#999999"))

                        ForEach(ContactSortOption.allCases, id: \.self) { option in
                            Button(action: { sortOption = option }) {
                                Text(option.rawValue)
                                    .font(.system(size: 11, weight: sortOption == option ? .bold : .regular))
                                    .foregroundColor(sortOption == option ? Color(hex: "#FFFC00") : Color(hex: "#CCCCCC"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        sortOption == option ? Color(hex: "#FFFC00").opacity(0.2) : Color.clear
                                    )
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(sortOption == option ? Color(hex: "#FFFC00") : Color.clear, lineWidth: 1)
                                    )
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    // Contact List
                    if filteredContacts.isEmpty {
                        Spacer()
                        EmptyContactsView(searchText: searchText)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredContacts) { contact in
                                    ContactRow(contact: contact)
                                        .onTapGesture {
                                            selectedContact = contact
                                            showContactDetail = true
                                        }

                                    Divider()
                                        .background(Color(hex: "#3A3A3A"))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(Color(hex: "#FFFC00"))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { sortOption = .callsign }) {
                            Label("Sort by Callsign", systemImage: sortOption == .callsign ? "checkmark" : "")
                        }
                        Button(action: { sortOption = .lastSeen }) {
                            Label("Sort by Last Seen", systemImage: sortOption == .lastSeen ? "checkmark" : "")
                        }
                        Button(action: { sortOption = .status }) {
                            Label("Sort by Status", systemImage: sortOption == .status ? "checkmark" : "")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(Color(hex: "#FFFC00"))
                    }
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showContactDetail) {
                if let contact = selectedContact {
                    ContactDetailView(contact: contact, chatManager: chatManager)
                }
            }
        }
    }
}

// MARK: - Stats Badge

struct StatsBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#999999"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let contact: ChatParticipant

    var statusColor: Color {
        contact.isOnline ? Color(hex: "#4CAF50") : Color(hex: "#666666")
    }

    var lastSeenText: String {
        let now = Date()
        let interval = now.timeIntervalSince(contact.lastSeen)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(Color(hex: "#2A2A2A"))
                    .frame(width: 50, height: 50)

                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "#1E1E1E"), lineWidth: 2)
                    )
                    .offset(x: 15, y: 15)

                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#FFFC00"))
            }

            // Contact info
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.callsign)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    // Status text
                    Text(contact.isOnline ? "ONLINE" : "OFFLINE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusColor)

                    Text("•")
                        .foregroundColor(Color(hex: "#666666"))

                    // Last seen
                    Text(lastSeenText)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#999999"))
                }
            }

            Spacer()

            // Action indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#666666"))
        }
        .padding(16)
        .background(Color(hex: "#1E1E1E"))
        .contentShape(Rectangle())
    }
}

// MARK: - Empty Contacts View

struct EmptyContactsView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "person.3.slash" : "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#666666"))

            Text(searchText.isEmpty ? "No Contacts" : "No Results")
                .font(.title2)
                .foregroundColor(Color(hex: "#CCCCCC"))

            Text(searchText.isEmpty ?
                 "Contacts will appear as units join the network" :
                 "No contacts match '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#999999"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Preview

struct ContactListView_Previews: PreviewProvider {
    static var previews: some View {
        let chatManager = ChatManager.shared

        // Add some sample contacts
        chatManager.participants = [
            ChatParticipant(id: "1", callsign: "ALPHA-1", isOnline: true),
            ChatParticipant(id: "2", callsign: "BRAVO-2", lastSeen: Date().addingTimeInterval(-3600), isOnline: false),
            ChatParticipant(id: "3", callsign: "CHARLIE-3", isOnline: true),
            ChatParticipant(id: "4", callsign: "DELTA-4", lastSeen: Date().addingTimeInterval(-86400), isOnline: false)
        ]

        return ContactListView(chatManager: chatManager)
    }
}
