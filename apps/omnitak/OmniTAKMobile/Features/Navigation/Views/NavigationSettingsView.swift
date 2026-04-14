//
//  NavigationSettingsView.swift
//  OmniTAKMobile
//
//  Navigation preferences and configuration (ATAK-style)
//

import SwiftUI

// MARK: - Navigation Settings Model

/// Persisted navigation settings via UserDefaults
class NavigationSettings: ObservableObject {
    static let shared = NavigationSettings()

    // MARK: - Voice Guidance Settings

    @AppStorage("nav_voiceEnabled") var voiceEnabled: Bool = true
    @AppStorage("nav_voiceVolume") var voiceVolume: Double = 1.0
    @AppStorage("nav_voiceRate") var voiceRate: Double = 0.5

    // MARK: - Off-Route Detection Settings

    @AppStorage("nav_offRouteThreshold") var offRouteThreshold: Double = 150.0
    @AppStorage("nav_autoReroute") var autoReroute: Bool = true
    @AppStorage("nav_offRouteDelay") var offRouteDelaySeconds: Double = 10.0

    // MARK: - Checkpoint Approach Settings

    @AppStorage("nav_approach1Distance") var approach1Distance: Double = 500.0
    @AppStorage("nav_approach2Distance") var approach2Distance: Double = 200.0
    @AppStorage("nav_approach3Distance") var approach3Distance: Double = 100.0
    @AppStorage("nav_arrivalThreshold") var arrivalThreshold: Double = 30.0

    // MARK: - Breadcrumb Trail Settings

    @AppStorage("nav_breadcrumbEnabled") var breadcrumbEnabled: Bool = true
    @AppStorage("nav_breadcrumbMinDistance") var breadcrumbMinDistance: Double = 10.0
    @AppStorage("nav_breadcrumbColor") var breadcrumbColorName: String = "cyan"

    // MARK: - Map Orientation Settings

    @AppStorage("nav_mapOrientation") var mapOrientationString: String = "northUp"
    @AppStorage("nav_autoZoom") var autoZoom: Bool = true
    @AppStorage("nav_keepScreenOn") var keepScreenOn: Bool = true

    // MARK: - Route Display Settings

    @AppStorage("nav_showRouteProgress") var showRouteProgress: Bool = true
    @AppStorage("nav_showSpeedDisplay") var showSpeedDisplay: Bool = true
    @AppStorage("nav_showETADisplay") var showETADisplay: Bool = true
    @AppStorage("nav_compactNavigationPanel") var compactNavigationPanel: Bool = false

    // MARK: - Computed Properties

    var mapOrientation: MapOrientation {
        get { MapOrientation(rawValue: mapOrientationString) ?? .northUp }
        set { mapOrientationString = newValue.rawValue }
    }

    var breadcrumbColor: BreadcrumbColor {
        get { BreadcrumbColor(rawValue: breadcrumbColorName) ?? .cyan }
        set { breadcrumbColorName = newValue.rawValue }
    }

    // MARK: - Apply to Services

    /// Apply current settings to navigation services
    func applyToServices() {
        // Apply to voice service
        let voiceService = NavigationVoiceService.shared
        voiceService.isMuted = !voiceEnabled
        voiceService.voiceVolume = Float(voiceVolume)
        voiceService.voiceRate = Float(voiceRate)

        // Apply to route planning service
        let routeService = RoutePlanningService.shared
        routeService.offRouteThreshold = offRouteThreshold
        routeService.autoRerouteEnabled = autoReroute
        routeService.breadcrumbEnabled = breadcrumbEnabled
    }
}

// MARK: - Supporting Enums

enum MapOrientation: String, CaseIterable {
    case northUp = "northUp"
    case trackUp = "trackUp"

    var displayName: String {
        switch self {
        case .northUp: return "North Up"
        case .trackUp: return "Track Up"
        }
    }

    var iconName: String {
        switch self {
        case .northUp: return "location.north.fill"
        case .trackUp: return "location.north.line.fill"
        }
    }
}

enum BreadcrumbColor: String, CaseIterable {
    case cyan = "cyan"
    case green = "green"
    case orange = "orange"
    case yellow = "yellow"
    case blue = "blue"
    case white = "white"

    var color: Color {
        switch self {
        case .cyan: return .cyan
        case .green: return .green
        case .orange: return .orange
        case .yellow: return Color(hex: "#FFFC00")
        case .blue: return .blue
        case .white: return .white
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Navigation Settings View

struct NavigationSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = NavigationSettings.shared

    var body: some View {
        NavigationView {
            List {
                // Voice Guidance Section
                voiceGuidanceSection

                // Off-Route Detection Section
                offRouteSection

                // Checkpoint Approach Section
                checkpointApproachSection

                // Breadcrumb Trail Section
                breadcrumbSection

                // Map Display Section
                mapDisplaySection

                // Navigation Panel Section
                navigationPanelSection

                // Reset Section
                resetSection
            }
            .navigationTitle("Navigation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        settings.applyToServices()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                settings.applyToServices()
            }
        }
    }

    // MARK: - Voice Guidance Section

    private var voiceGuidanceSection: some View {
        Section {
            Toggle(isOn: $settings.voiceEnabled) {
                Label("Voice Guidance", systemImage: "speaker.wave.3.fill")
            }

            if settings.voiceEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Volume", systemImage: "speaker.fill")
                        Spacer()
                        Text("\(Int(settings.voiceVolume * 100))%")
                            .foregroundColor(.gray)
                            .font(.system(size: 14, design: .monospaced))
                    }
                    Slider(value: $settings.voiceVolume, in: 0.1...1.0, step: 0.1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Speech Rate", systemImage: "speedometer")
                        Spacer()
                        Text(speechRateDescription)
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    Slider(value: $settings.voiceRate, in: 0.3...0.7, step: 0.1)
                }

                Button(action: testVoice) {
                    Label("Test Voice", systemImage: "play.circle.fill")
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        } header: {
            Text("VOICE GUIDANCE")
        } footer: {
            Text("Announces checkpoint approaches and navigation events.")
        }
    }

    private var speechRateDescription: String {
        if settings.voiceRate < 0.4 {
            return "Slow"
        } else if settings.voiceRate < 0.6 {
            return "Normal"
        } else {
            return "Fast"
        }
    }

    private func testVoice() {
        let voiceService = NavigationVoiceService.shared
        voiceService.voiceVolume = Float(settings.voiceVolume)
        voiceService.voiceRate = Float(settings.voiceRate)
        voiceService.isMuted = false
        voiceService.speak("Navigation voice test. Approaching checkpoint alpha in 200 meters.")
    }

    // MARK: - Off-Route Detection Section

    private var offRouteSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Off-Route Threshold", systemImage: "arrow.triangle.branch")
                    Spacer()
                    Text("\(Int(settings.offRouteThreshold))m")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, design: .monospaced))
                }
                Slider(value: $settings.offRouteThreshold, in: 50...300, step: 25)
            }

            Toggle(isOn: $settings.autoReroute) {
                Label("Auto-Reroute", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
            }

            if settings.autoReroute {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Reroute Delay", systemImage: "timer")
                        Spacer()
                        Text("\(Int(settings.offRouteDelaySeconds))s")
                            .foregroundColor(.gray)
                            .font(.system(size: 14, design: .monospaced))
                    }
                    Slider(value: $settings.offRouteDelaySeconds, in: 5...30, step: 5)
                }
            }
        } header: {
            Text("OFF-ROUTE DETECTION")
        } footer: {
            Text("ATAK default: 150m. Triggers warning when you deviate from planned route.")
        }
    }

    // MARK: - Checkpoint Approach Section

    private var checkpointApproachSection: some View {
        Section {
            approachDistanceRow(
                label: "First Alert",
                binding: $settings.approach1Distance,
                range: 300...1000,
                step: 50,
                icon: "bell",
                color: .green
            )

            approachDistanceRow(
                label: "Second Alert",
                binding: $settings.approach2Distance,
                range: 100...500,
                step: 25,
                icon: "bell.badge",
                color: .yellow
            )

            approachDistanceRow(
                label: "Final Alert",
                binding: $settings.approach3Distance,
                range: 50...200,
                step: 10,
                icon: "bell.badge.fill",
                color: .orange
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label {
                        Text("Arrival Threshold")
                    } icon: {
                        Image(systemName: "flag.checkered")
                            .foregroundColor(.red)
                    }
                    Spacer()
                    Text("\(Int(settings.arrivalThreshold))m")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, design: .monospaced))
                }
                Slider(value: $settings.arrivalThreshold, in: 10...100, step: 5)
            }
        } header: {
            Text("CHECKPOINT APPROACH")
        } footer: {
            Text("Distance thresholds for voice announcements when approaching waypoints.")
        }
    }

    private func approachDistanceRow(
        label: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label {
                    Text(label)
                } icon: {
                    Image(systemName: icon)
                        .foregroundColor(color)
                }
                Spacer()
                Text("\(Int(binding.wrappedValue))m")
                    .foregroundColor(.gray)
                    .font(.system(size: 14, design: .monospaced))
            }
            Slider(value: binding, in: range, step: step)
        }
    }

    // MARK: - Breadcrumb Trail Section

    private var breadcrumbSection: some View {
        Section {
            Toggle(isOn: $settings.breadcrumbEnabled) {
                Label("Breadcrumb Trail", systemImage: "point.topleft.down.curvedto.point.bottomright.up.fill")
            }

            if settings.breadcrumbEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Point Spacing", systemImage: "ruler")
                        Spacer()
                        Text("\(Int(settings.breadcrumbMinDistance))m")
                            .foregroundColor(.gray)
                            .font(.system(size: 14, design: .monospaced))
                    }
                    Slider(value: $settings.breadcrumbMinDistance, in: 5...50, step: 5)
                }

                Picker(selection: $settings.breadcrumbColorName) {
                    ForEach(BreadcrumbColor.allCases, id: \.rawValue) { color in
                        HStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 12, height: 12)
                            Text(color.displayName)
                        }
                        .tag(color.rawValue)
                    }
                } label: {
                    Label("Trail Color", systemImage: "paintbrush.fill")
                }
            }
        } header: {
            Text("BREADCRUMB TRAIL")
        } footer: {
            Text("Records your actual path traveled during navigation.")
        }
    }

    // MARK: - Map Display Section

    private var mapDisplaySection: some View {
        Section {
            Picker(selection: $settings.mapOrientationString) {
                ForEach(MapOrientation.allCases, id: \.rawValue) { orientation in
                    Label(orientation.displayName, systemImage: orientation.iconName)
                        .tag(orientation.rawValue)
                }
            } label: {
                Label("Map Orientation", systemImage: "compass.drawing")
            }

            Toggle(isOn: $settings.autoZoom) {
                Label("Auto-Zoom to Route", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
            }

            Toggle(isOn: $settings.keepScreenOn) {
                Label("Keep Screen On", systemImage: "sun.max.fill")
            }
        } header: {
            Text("MAP DISPLAY")
        } footer: {
            Text("North Up maintains fixed orientation. Track Up rotates map to match your heading.")
        }
    }

    // MARK: - Navigation Panel Section

    private var navigationPanelSection: some View {
        Section {
            Toggle(isOn: $settings.showRouteProgress) {
                Label("Show Progress Bar", systemImage: "chart.bar.fill")
            }

            Toggle(isOn: $settings.showSpeedDisplay) {
                Label("Show Speed", systemImage: "speedometer")
            }

            Toggle(isOn: $settings.showETADisplay) {
                Label("Show ETA", systemImage: "clock.fill")
            }

            Toggle(isOn: $settings.compactNavigationPanel) {
                Label("Compact Mode", systemImage: "rectangle.compress.vertical")
            }
        } header: {
            Text("NAVIGATION PANEL")
        } footer: {
            Text("Customize the information displayed during active navigation.")
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        Section {
            Button(action: resetToDefaults) {
                Label("Reset to ATAK Defaults", systemImage: "arrow.counterclockwise")
                    .foregroundColor(.orange)
            }
        } footer: {
            Text("Restore navigation settings to match ATAK defaults.")
        }
    }

    private func resetToDefaults() {
        // Voice
        settings.voiceEnabled = true
        settings.voiceVolume = 1.0
        settings.voiceRate = 0.5

        // Off-Route
        settings.offRouteThreshold = 150.0
        settings.autoReroute = true
        settings.offRouteDelaySeconds = 10.0

        // Checkpoint Approach
        settings.approach1Distance = 500.0
        settings.approach2Distance = 200.0
        settings.approach3Distance = 100.0
        settings.arrivalThreshold = 30.0

        // Breadcrumb
        settings.breadcrumbEnabled = true
        settings.breadcrumbMinDistance = 10.0
        settings.breadcrumbColorName = "cyan"

        // Map Display
        settings.mapOrientationString = "northUp"
        settings.autoZoom = true
        settings.keepScreenOn = true

        // Navigation Panel
        settings.showRouteProgress = true
        settings.showSpeedDisplay = true
        settings.showETADisplay = true
        settings.compactNavigationPanel = false

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Preview

struct NavigationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationSettingsView()
            .preferredColorScheme(.dark)
    }
}
