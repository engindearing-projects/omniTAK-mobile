//
//  TurnByTurnNavigationView.swift
//  OmniTAKMobile
//
//  Turn-by-turn navigation UI with voice guidance for driving
//

import SwiftUI
import CoreLocation

// MARK: - Main Turn-by-Turn Navigation View

struct TurnByTurnNavigationView: View {
    @ObservedObject var navigationService = TurnByTurnNavigationService.shared
    @State private var showStopConfirmation = false
    @State private var showVoiceSettings = false
    @State private var isExpanded = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Dark background for driving visibility
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Current instruction card
                NavigationInstructionCard(navigationService: navigationService)

                // Next instruction preview
                if let nextInstruction = navigationService.nextInstruction {
                    nextInstructionPreview(nextInstruction)
                }

                // Stats panel
                NavigationStatsPanel(navigationService: navigationService)

                // Progress bar
                routeProgressBar

                Spacer()

                // Control bar
                NavigationControlBar(
                    navigationService: navigationService,
                    showStopConfirmation: $showStopConfirmation,
                    showVoiceSettings: $showVoiceSettings
                )
            }
        }
        .preferredColorScheme(.dark)
        .alert("Stop Navigation?", isPresented: $showStopConfirmation) {
            Button("Stop", role: .destructive) {
                navigationService.stopNavigation()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to stop navigation?")
        }
        .sheet(isPresented: $showVoiceSettings) {
            VoiceSettingsView(navigationService: navigationService)
        }
    }

    // MARK: - Next Instruction Preview

    private func nextInstructionPreview(_ instruction: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.turn.up.right")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#888888"))

            Text("Then: \(instruction)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(hex: "#1A1A1A"))
    }

    // MARK: - Route Progress Bar

    private var routeProgressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(hex: "#333333"))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(Color(hex: "#FFFC00"))
                        .frame(width: geometry.size.width * CGFloat(navigationService.percentComplete / 100), height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.3), value: navigationService.percentComplete)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Int(navigationService.percentComplete))% Complete")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#888888"))

                Spacer()

                Text("ETA: \(navigationService.formattedETA)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#FFFC00"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(hex: "#0D0D0D"))
    }
}

// MARK: - Navigation Instruction Card

struct NavigationInstructionCard: View {
    @ObservedObject var navigationService: TurnByTurnNavigationService
    @State private var countdownScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 20) {
            // Large directional arrow
            Image(systemName: navigationService.currentManeuverIcon)
                .font(.system(size: 80, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))
                .shadow(color: Color(hex: "#FFFC00").opacity(0.3), radius: 10)
                .scaleEffect(countdownScale)
                .animation(
                    navigationService.distanceToNextTurn < 50 ?
                    Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default,
                    value: navigationService.distanceToNextTurn
                )
                .onChange(of: navigationService.distanceToNextTurn) { newDistance in
                    if newDistance < 50 {
                        countdownScale = 1.1
                    } else {
                        countdownScale = 1.0
                    }
                }

            // Distance to next turn - large font for visibility
            Text(formatDistance(navigationService.distanceToNextTurn))
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)

            // Current instruction text
            Text(navigationService.currentInstruction)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 20)

            // Street name if available
            if let streetName = currentStreetName {
                Text(streetName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#333333"))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#1E1E1E"), Color(hex: "#0D0D0D")]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var currentStreetName: String? {
        guard navigationService.currentStepIndex < navigationService.navigationInstructions.count else {
            return nil
        }
        return navigationService.navigationInstructions[navigationService.currentStepIndex].streetName
    }

    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 100 {
            return "\(Int(distance))m"
        } else if distance < 1000 {
            let rounded = Int(round(distance / 10) * 10)
            return "\(rounded)m"
        } else {
            let km = distance / 1000
            if km < 10 {
                return String(format: "%.1fkm", km)
            } else {
                return "\(Int(km))km"
            }
        }
    }
}

// MARK: - Navigation Stats Panel

struct NavigationStatsPanel: View {
    @ObservedObject var navigationService: TurnByTurnNavigationService
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 0) {
            // Total distance remaining
            statItem(
                icon: "map.fill",
                label: "Distance",
                value: navigationService.formattedDistanceRemaining,
                color: .white
            )

            Divider()
                .frame(height: 50)
                .background(Color(hex: "#333333"))

            // Time to arrival
            statItem(
                icon: "clock.fill",
                label: "Time",
                value: navigationService.formattedTimeToArrival,
                color: .white
            )

            Divider()
                .frame(height: 50)
                .background(Color(hex: "#333333"))

            // Current speed
            statItem(
                icon: "speedometer",
                label: "Speed",
                value: navigationService.formattedSpeed,
                color: speedColor
            )

            Divider()
                .frame(height: 50)
                .background(Color(hex: "#333333"))

            // Elapsed time
            statItem(
                icon: "timer",
                label: "Elapsed",
                value: formattedElapsedTime,
                color: .white
            )
        }
        .padding(.vertical, 16)
        .background(Color(hex: "#1A1A1A"))
        .onAppear {
            startElapsedTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func statItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#FFFC00"))

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#888888"))
        }
        .frame(maxWidth: .infinity)
    }

    private var speedColor: Color {
        if navigationService.speedKmh > 120 {
            return .red
        } else if navigationService.speedKmh > 80 {
            return .orange
        } else {
            return .white
        }
    }

    private var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func startElapsedTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1
        }
    }
}

// MARK: - Navigation Control Bar

struct NavigationControlBar: View {
    @ObservedObject var navigationService: TurnByTurnNavigationService
    @Binding var showStopConfirmation: Bool
    @Binding var showVoiceSettings: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Primary controls
            HStack(spacing: 16) {
                // Stop button
                controlButton(
                    icon: "stop.fill",
                    label: "Stop",
                    color: .red
                ) {
                    showStopConfirmation = true
                }

                // Pause/Resume button
                controlButton(
                    icon: navigationService.isPaused ? "play.fill" : "pause.fill",
                    label: navigationService.isPaused ? "Resume" : "Pause",
                    color: .orange
                ) {
                    if navigationService.isPaused {
                        navigationService.resumeNavigation()
                    } else {
                        navigationService.pauseNavigation()
                    }
                }

                // Skip waypoint button
                controlButton(
                    icon: "forward.fill",
                    label: "Skip",
                    color: .blue
                ) {
                    navigationService.skipToNextWaypoint()
                }
            }

            // Secondary controls
            HStack(spacing: 16) {
                // Voice toggle
                controlButton(
                    icon: navigationService.voiceGuidanceEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill",
                    label: navigationService.voiceGuidanceEnabled ? "Mute" : "Unmute",
                    color: navigationService.voiceGuidanceEnabled ? Color(hex: "#FFFC00") : .gray
                ) {
                    navigationService.voiceGuidanceEnabled.toggle()
                }

                // Recalculate route
                controlButton(
                    icon: "arrow.triangle.2.circlepath",
                    label: "Reroute",
                    color: .cyan
                ) {
                    navigationService.recalculateRoute()
                }

                // Voice settings
                controlButton(
                    icon: "gearshape.fill",
                    label: "Settings",
                    color: .gray
                ) {
                    showVoiceSettings = true
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(hex: "#0D0D0D"))
    }

    private func controlButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#CCCCCC"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Navigation Compact View (Banner Overlay)

struct NavigationCompactView: View {
    @ObservedObject var navigationService = TurnByTurnNavigationService.shared
    @State private var isExpanded = false

    var body: some View {
        Button(action: { isExpanded = true }) {
            HStack(spacing: 16) {
                // Direction icon
                Image(systemName: navigationService.currentManeuverIcon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .frame(width: 40)

                // Distance
                Text(formatCompactDistance(navigationService.distanceToNextTurn))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Divider()
                    .frame(height: 30)
                    .background(Color(hex: "#555555"))

                // Brief instruction
                Text(briefInstruction)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Expand indicator
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#888888"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.9))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.5), radius: 8)
        }
        .buttonStyle(PlainButtonStyle())
        .fullScreenCover(isPresented: $isExpanded) {
            TurnByTurnNavigationView()
        }
    }

    private var briefInstruction: String {
        if navigationService.currentStepIndex < navigationService.navigationInstructions.count {
            let instruction = navigationService.navigationInstructions[navigationService.currentStepIndex]
            if let streetName = instruction.streetName {
                return "\(instruction.type.voiceInstruction) onto \(streetName)"
            }
            return instruction.type.voiceInstruction
        }
        return navigationService.currentInstruction
    }

    private func formatCompactDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

// MARK: - Voice Settings View

struct VoiceSettingsView: View {
    @ObservedObject var navigationService: TurnByTurnNavigationService
    @State private var voiceRate: Float = 0.5
    @State private var voicePitch: Float = 1.0
    @State private var voiceVolume: Float = 1.0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Voice Rate
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speech Rate")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            Text(rateLabel)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#FFFC00"))
                        }

                        Slider(value: $voiceRate, in: 0.1...1.0, step: 0.1)
                            .tint(Color(hex: "#FFFC00"))
                    }

                    // Voice Pitch
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Voice Pitch")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            Text(String(format: "%.1f", voicePitch))
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#FFFC00"))
                        }

                        Slider(value: $voicePitch, in: 0.5...2.0, step: 0.1)
                            .tint(Color(hex: "#FFFC00"))
                    }

                    // Voice Volume
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Volume")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            Text("\(Int(voiceVolume * 100))%")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#FFFC00"))
                        }

                        Slider(value: $voiceVolume, in: 0.0...1.0, step: 0.1)
                            .tint(Color(hex: "#FFFC00"))
                    }

                    // Test voice button
                    Button(action: testVoice) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                            Text("Test Voice")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#FFFC00"))
                        .cornerRadius(10)
                    }

                    Spacer()

                    // Apply button
                    Button(action: applySettings) {
                        Text("Apply Settings")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#FFFC00"))
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationTitle("Voice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .onAppear {
            voiceRate = navigationService.voiceRate
            voicePitch = navigationService.voicePitch
            voiceVolume = navigationService.voiceVolume
        }
    }

    private var rateLabel: String {
        if voiceRate < 0.3 {
            return "Slow"
        } else if voiceRate < 0.6 {
            return "Normal"
        } else {
            return "Fast"
        }
    }

    private func testVoice() {
        navigationService.configureVoice(rate: voiceRate, pitch: voicePitch, volume: voiceVolume)
        navigationService.speak(text: "Turn left in 200 meters onto Main Street")
    }

    private func applySettings() {
        navigationService.configureVoice(rate: voiceRate, pitch: voicePitch, volume: voiceVolume)
        dismiss()
    }
}

// MARK: - Navigation Button (for toolbar)

struct NavigationButton: View {
    @ObservedObject var navigationService = TurnByTurnNavigationService.shared
    @State private var showNavigationView = false

    var body: some View {
        Button(action: { showNavigationView = true }) {
            ZStack {
                Circle()
                    .fill(navigationService.isNavigating ? Color.green.opacity(0.3) : Color.black.opacity(0.6))
                    .frame(width: 56, height: 56)

                Image(systemName: "location.north.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(navigationService.isNavigating ? .green : .white)

                if navigationService.isNavigating {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(Color.green.opacity(0.5), lineWidth: 2)
                                .scaleEffect(1.3)
                                .opacity(0.5)
                                .animation(
                                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                    value: navigationService.isNavigating
                                )
                        )
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .fullScreenCover(isPresented: $showNavigationView) {
            TurnByTurnNavigationView()
        }
    }
}

// MARK: - Off-Route Warning Banner

struct OffRouteWarningBanner: View {
    @ObservedObject var navigationService = TurnByTurnNavigationService.shared

    var body: some View {
        if navigationService.isOffRoute {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.black)

                Text("Off Route - Recalculating...")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)

                Spacer()

                Button(action: {
                    navigationService.recalculateRoute()
                }) {
                    Text("Reroute")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black)
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.orange)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.3), radius: 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Preview

struct TurnByTurnNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        TurnByTurnNavigationView()
    }
}

struct NavigationCompactView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationCompactView()
            .padding()
            .background(Color.gray.opacity(0.3))
            .previewLayout(.sizeThatFits)
    }
}
