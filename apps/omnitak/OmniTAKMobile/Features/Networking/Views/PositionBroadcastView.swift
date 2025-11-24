//
//  PositionBroadcastView.swift
//  OmniTAKMobile
//
//  UI for controlling automatic position broadcasting (PLI/SA)
//

import SwiftUI

struct PositionBroadcastView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var broadcastService = PositionBroadcastService.shared
    @State private var showAdvancedSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Status Card
                        statusCard

                        // Main Toggle
                        mainToggleCard

                        // User Identity
                        identityCard

                        // Timing Settings
                        timingCard

                        // Statistics
                        statisticsCard

                        // Advanced Settings
                        if showAdvancedSettings {
                            advancedCard
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Position Broadcasting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showAdvancedSettings.toggle()
                    }) {
                        Image(systemName: showAdvancedSettings ? "gearshape.fill" : "gearshape")
                    }
                }
            }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 12) {
            HStack {
                // Status indicator
                Circle()
                    .fill(broadcastService.isEnabled ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                    .shadow(color: broadcastService.isEnabled ? .green : .clear, radius: 4)

                Text(broadcastService.isEnabled ? "BROADCASTING" : "OFFLINE")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(broadcastService.isEnabled ? .green : .gray)

                Spacer()

                // Battery indicator
                HStack(spacing: 4) {
                    Image(systemName: batteryIcon)
                        .foregroundColor(batteryColor)
                    Text("\(Int(broadcastService.batteryLevel * 100))%")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }

            if let error = broadcastService.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Spacer()
                }
            }

            // Next broadcast countdown
            if broadcastService.isEnabled {
                HStack {
                    Text("Next broadcast in:")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                    Text(broadcastService.nextBroadcastIn)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(broadcastService.isEnabled ? Color.green.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Main Toggle Card

    private var mainToggleCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#FFFC00"))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Automatic Broadcasting")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Share your position with the network")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                Toggle("", isOn: $broadcastService.isEnabled)
                    .labelsHidden()
            }

            // Manual broadcast button
            Button(action: {
                broadcastService.forceBroadcast()
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("Broadcast Now")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(hex: "#FFFC00"))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Identity Card

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("IDENTITY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            HStack {
                Text("Callsign")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer()
                TextField("Callsign", text: $broadcastService.userCallsign)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 120)
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            HStack {
                Text("Team Color")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer()
                Menu {
                    ForEach(teamColors, id: \.self) { color in
                        Button(color) {
                            broadcastService.teamColor = color
                        }
                    }
                } label: {
                    HStack {
                        Circle()
                            .fill(teamColorSwiftUI(broadcastService.teamColor))
                            .frame(width: 12, height: 12)
                        Text(broadcastService.teamColor)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#FFFC00"))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            HStack {
                Text("Role")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer()
                Menu {
                    ForEach(teamRoles, id: \.self) { role in
                        Button(role) {
                            broadcastService.teamRole = role
                        }
                    }
                } label: {
                    HStack {
                        Text(broadcastService.teamRole)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#FFFC00"))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            HStack {
                Text("UID")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer()
                Text(broadcastService.userUID.prefix(12) + "...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Timing Card

    private var timingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIMING")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Update Interval")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(broadcastService.updateInterval))s")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }

                Slider(value: $broadcastService.updateInterval, in: 5...300, step: 5)
                    .accentColor(Color(hex: "#FFFC00"))

                HStack {
                    Text("5s")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Faster updates = more network traffic")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("5m")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Stale Time")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(broadcastService.staleTime))s")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }

                Slider(value: $broadcastService.staleTime, in: 60...600, step: 30)
                    .accentColor(Color(hex: "#FFFC00"))

                HStack {
                    Text("1m")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Time until your marker becomes stale")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("10m")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Statistics Card

    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATISTICS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            HStack {
                PLIStatItem(title: "Total Broadcasts", value: "\(broadcastService.broadcastCount)")
                Spacer()
                PLIStatItem(title: "Last Broadcast", value: broadcastService.timeSinceLastBroadcast)
                Spacer()
                PLIStatItem(title: "Status", value: broadcastService.deviceStatus)
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Advanced Card

    private var advancedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADVANCED")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            HStack {
                Text("CoT Type")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer()
                Text("a-f-G-U-C")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            HStack {
                Text("Protocol")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer()
                Text("CoT 2.0 XML")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            HStack {
                Text("Platform ID")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer()
                Text("OmniTAK-iOS")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private var batteryIcon: String {
        if broadcastService.batteryLevel >= 0.75 {
            return "battery.100"
        } else if broadcastService.batteryLevel >= 0.5 {
            return "battery.75"
        } else if broadcastService.batteryLevel >= 0.25 {
            return "battery.25"
        } else {
            return "battery.0"
        }
    }

    private var batteryColor: Color {
        if broadcastService.batteryLevel >= 0.5 {
            return .green
        } else if broadcastService.batteryLevel >= 0.2 {
            return .orange
        } else {
            return .red
        }
    }

    private let teamColors = ["Cyan", "Green", "Yellow", "Orange", "Magenta", "Red", "White", "Maroon"]

    private let teamRoles = ["Team Lead", "Team Member", "Observer", "HQ", "Medic", "Forward Observer", "Sniper", "RTO"]

    private func teamColorSwiftUI(_ colorName: String) -> Color {
        switch colorName {
        case "Cyan": return .cyan
        case "Green": return .green
        case "Yellow": return .yellow
        case "Orange": return .orange
        case "Magenta": return .pink
        case "Red": return .red
        case "White": return .white
        case "Maroon": return Color(red: 0.5, green: 0, blue: 0)
        default: return .cyan
        }
    }
}

// MARK: - PLI Stat Item

struct PLIStatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
