//
//  EmergencyBeaconView.swift
//  OmniTAKMobile
//
//  SwiftUI interface for emergency beacon/SOS functionality
//  Large panic button with confirmation dialogs and status display
//

import SwiftUI
import AudioToolbox

// MARK: - Emergency Beacon View

struct EmergencyBeaconView: View {
    @ObservedObject var beaconService = EmergencyBeaconService.shared
    @Environment(\.dismiss) var dismiss

    @State private var showConfirmation = false
    @State private var showCancelConfirmation = false
    @State private var selectedType: EmergencyType = .alert911
    @State private var customMessage: String = ""
    @State private var showingTypeSelector = false
    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Background
            Color(hex: "#1A1A1A")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                emergencyHeader

                ScrollView {
                    VStack(spacing: 24) {
                        if beaconService.emergencyState.isActive {
                            // Active emergency display
                            activeEmergencyView
                        } else {
                            // Panic button and type selector
                            panicButtonSection
                        }

                        // Status information
                        statusSection
                    }
                    .padding()
                }
            }
        }
        .alert("ACTIVATE EMERGENCY BEACON", isPresented: $showConfirmation) {
            Button("SEND \(selectedType.displayName.uppercased())", role: .destructive) {
                activateEmergency()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will broadcast your location and emergency status to all connected TAK users. Use only in genuine emergencies.")
        }
        .alert("CANCEL EMERGENCY", isPresented: $showCancelConfirmation) {
            Button("Yes, Cancel Emergency", role: .destructive) {
                beaconService.cancelEmergency()
            }
            Button("Keep Active", role: .cancel) { }
        } message: {
            Text("Are you sure you want to cancel the active emergency? A cancellation message will be sent to all users.")
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }

    // MARK: - Header

    private var emergencyHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack(spacing: 4) {
                Text("EMERGENCY BEACON")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(Color(hex: "#FF3B30"))

                if beaconService.emergencyState.isActive {
                    Text("ACTIVE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(4)
                }
            }

            Spacer()

            // Placeholder for symmetry
            Color.clear
                .frame(width: 20, height: 20)
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .overlay(
            Rectangle()
                .frame(height: 3)
                .foregroundColor(beaconService.emergencyState.isActive ? Color.red : Color(hex: "#FF6600")),
            alignment: .bottom
        )
    }

    // MARK: - Panic Button Section

    private var panicButtonSection: some View {
        VStack(spacing: 24) {
            // Emergency type selector
            VStack(spacing: 12) {
                Text("SELECT EMERGENCY TYPE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#999999"))

                VStack(spacing: 8) {
                    ForEach([EmergencyType.alert911, .inContact, .alert], id: \.rawValue) { type in
                        EmergencyTypeButton(
                            type: type,
                            isSelected: selectedType == type
                        ) {
                            selectedType = type
                            provideSelectionFeedback()
                        }
                    }
                }
            }
            .padding()
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(12)

            // Custom message field
            VStack(alignment: .leading, spacing: 8) {
                Text("CUSTOM MESSAGE (OPTIONAL)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#999999"))

                TextField("Additional details...", text: $customMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(12)

            // Main panic button
            Button(action: {
                showConfirmation = true
            }) {
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 220, height: 220)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)

                    // Main button
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [Color(hex: "#FF4444"), Color(hex: "#CC0000")]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .shadow(color: Color.red.opacity(0.8), radius: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        )

                    // Button content
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(.white)

                        Text("SOS")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(.white)

                        Text("PRESS TO ACTIVATE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Text("Press the SOS button to activate emergency beacon")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#999999"))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Active Emergency View

    private var activeEmergencyView: some View {
        VStack(spacing: 24) {
            // Emergency status card
            VStack(spacing: 16) {
                // Flashing warning indicator
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 16, height: 16)
                        .opacity(pulseAnimation ? 1.0 : 0.3)

                    Text("EMERGENCY ACTIVE")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.red)

                    Circle()
                        .fill(Color.red)
                        .frame(width: 16, height: 16)
                        .opacity(pulseAnimation ? 0.3 : 1.0)
                }

                Divider()
                    .background(Color.red.opacity(0.5))

                // Emergency details
                VStack(spacing: 12) {
                    DetailRow(
                        icon: beaconService.currentEmergencyType?.icon ?? "exclamationmark.triangle",
                        label: "Type",
                        value: beaconService.currentEmergencyType?.displayName ?? "Unknown",
                        iconColor: Color.red
                    )

                    DetailRow(
                        icon: "message.fill",
                        label: "Message",
                        value: beaconService.emergencyState.message,
                        iconColor: Color.red
                    )

                    DetailRow(
                        icon: "clock.fill",
                        label: "Duration",
                        value: beaconService.timeSinceActivation,
                        iconColor: Color.red
                    )

                    DetailRow(
                        icon: "antenna.radiowaves.left.and.right",
                        label: "Broadcasts",
                        value: "\(beaconService.emergencyState.broadcastCount)",
                        iconColor: Color.red
                    )

                    if beaconService.isBroadcasting {
                        HStack {
                            Image(systemName: "wave.3.right")
                                .font(.system(size: 14))
                                .foregroundColor(.green)

                            Text("Broadcasting every 30 seconds")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#2A2A2A"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red, lineWidth: 2)
                    )
            )

            // Last broadcast status
            if !beaconService.lastBroadcastStatus.isEmpty {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Color(hex: "#FFFC00"))

                    Text(beaconService.lastBroadcastStatus)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                }
                .padding()
                .background(Color(hex: "#2A2A2A"))
                .cornerRadius(8)
            }

            // Cancel button
            Button(action: {
                showCancelConfirmation = true
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))

                    Text("CANCEL EMERGENCY")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }

            Text("Press to cancel emergency and notify all users")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#999999"))
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 12) {
            Text("BEACON INFORMATION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#999999"))

            VStack(spacing: 0) {
                InfoRow(label: "Protocol", value: "ATAK Emergency CoT")
                Divider().background(Color(hex: "#3A3A3A"))
                InfoRow(label: "Broadcast Interval", value: "30 seconds")
                Divider().background(Color(hex: "#3A3A3A"))
                InfoRow(label: "Message Validity", value: "2 minutes")
                Divider().background(Color(hex: "#3A3A3A"))
                InfoRow(label: "Persistence", value: "Survives app restart")
            }
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(12)
        }
    }

    // MARK: - Actions

    private func activateEmergency() {
        let message = customMessage.isEmpty ? selectedType.defaultMessage : customMessage
        beaconService.activateEmergency(type: selectedType, message: message)
        customMessage = ""
    }

    private func provideSelectionFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - Emergency Type Button

struct EmergencyTypeButton: View {
    let type: EmergencyType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: type.color))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Text(type.defaultMessage)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#999999"))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: type.color))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(hex: type.color).opacity(0.2) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color(hex: type.color) : Color(hex: "#3A3A3A"),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Info Row

struct EmergencyInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#999999"))

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Compact Emergency Button (for toolbar)

struct EmergencyToolbarButton: View {
    @ObservedObject var beaconService = EmergencyBeaconService.shared
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if beaconService.emergencyState.isActive {
                    // Pulsing background for active emergency
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .scaleEffect(pulse ? 1.2 : 1.0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                pulse = true
                            }
                        }
                }

                VStack(spacing: 2) {
                    Image(systemName: beaconService.emergencyState.isActive ? "exclamationmark.triangle.fill" : "sos")
                        .font(.system(size: 20))
                        .foregroundColor(beaconService.emergencyState.isActive ? .red : .white)

                    Text("SOS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(beaconService.emergencyState.isActive ? .red : .white)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EmergencyBeaconView()
}
