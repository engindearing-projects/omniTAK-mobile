//
//  NetworkPreferencesView.swift
//  OmniTAKMobile
//
//  Network preferences matching ATAK design
//

import SwiftUI

// MARK: - Network Preferences View (ATAK Style)

struct NetworkPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var serverManager = ServerManager.shared
    @State private var showQuickConnect = false

    var body: some View {
        NavigationView {
            ZStack {
                // ATAK-style black background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Cyan accent bar
                    Rectangle()
                        .fill(Color(hex: "#00BCD4"))
                        .frame(height: 2)

                    // Section header (ATAK style)
                    HStack {
                        Text("NETWORK PREFERENCES")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: "#999999"))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#0A0A0A"))

                    // Preferences list
                    ScrollView {
                        VStack(spacing: 0) {
                            // MANAGE SERVER CONNECTIONS
                            PreferenceRow(
                                icon: "server.rack",
                                iconColor: Color(hex: "#00BCD4"),
                                title: "MANAGE SERVER CONNECTIONS",
                                description: "Tap to configure TAK Server connections (\(serverManager.servers.count) server\(serverManager.servers.count == 1 ? "" : "s") configured)",
                                showIndicator: serverManager.servers.count > 0,
                                indicatorColor: Color(hex: "#00FF00"),
                                onTap: { showQuickConnect = true }
                            )

                            Divider().background(Color(hex: "#222222"))

                            // Network Connection Preferences
                            PreferenceRow(
                                icon: "wifi",
                                iconColor: Color(hex: "#00BCD4"),
                                title: "Network Connection Preferences",
                                description: "Adjust network connections",
                                onTap: { /* TODO: Network connection prefs */ }
                            )

                            Divider().background(Color(hex: "#222222"))

                            // Datalink Preferences
                            PreferenceRow(
                                icon: "dot.radiowaves.left.and.right",
                                iconColor: Color(hex: "#00BCD4"),
                                title: "Datalink Preferences",
                                description: "Adjust Datalink Messages Preferences",
                                onTap: { /* TODO: Datalink prefs */ }
                            )
                        }
                    }
                }
            }
            .navigationTitle("ATAK v5.5.1.8 (7f381e4d)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Settings/My Preferences")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white)
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { /* Home icon */ }) {
                        Image(systemName: "house.fill")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showQuickConnect) {
            QuickConnectView()
        }
    }
}

// MARK: - Preference Row (ATAK Style)

struct PreferenceRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    var showIndicator: Bool = false
    var indicatorColor: Color = .clear
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon with indicator
                ZStack(alignment: .topLeading) {
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(iconColor)
                        .frame(width: 48, height: 48)

                    if showIndicator {
                        Circle()
                            .fill(indicatorColor)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                            )
                    }
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#AAAAAA"))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#666666"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color.black)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct NetworkPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkPreferencesView()
            .preferredColorScheme(.dark)
    }
}
#endif
