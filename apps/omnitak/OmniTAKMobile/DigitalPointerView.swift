//
//  DigitalPointerView.swift
//  OmniTAKMobile
//
//  Digital Pointer UI overlay views for team coordination
//  Provides visual overlays, control panels, and list views for digital pointers
//

import SwiftUI
import CoreLocation
import MapKit

// MARK: - Digital Pointer Overlay

/// Main overlay showing all active team pointers on the map
struct DigitalPointerOverlay: View {
    @ObservedObject var pointerService = DigitalPointerService.shared
    let mapView: MKMapView?
    let userLocation: CLLocationCoordinate2D?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Render all active team pointers
                ForEach(pointerService.getActivePointers()) { pointer in
                    if let screenPosition = screenPosition(for: pointer.clCoordinate, in: geometry) {
                        DigitalPointerAnnotationView(
                            pointer: pointer,
                            userLocation: userLocation,
                            screenPosition: screenPosition
                        )
                        .position(screenPosition)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func screenPosition(for coordinate: CLLocationCoordinate2D, in geometry: GeometryProxy) -> CGPoint? {
        guard let mapView = mapView else { return nil }

        let point = mapView.convert(coordinate, toPointTo: mapView)

        // Check if the point is within visible bounds
        let bounds = mapView.bounds
        guard point.x >= 0 && point.x <= bounds.width &&
              point.y >= 0 && point.y <= bounds.height else {
            return nil
        }

        return point
    }
}

// MARK: - Digital Pointer Annotation View

/// Individual pointer marker with animations and info
struct DigitalPointerAnnotationView: View {
    let pointer: DigitalPointerEvent
    let userLocation: CLLocationCoordinate2D?
    let screenPosition: CGPoint

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        VStack(spacing: 4) {
            // Callsign label
            Text(pointer.senderCallsign)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.8))
                .cornerRadius(4)

            // Pointer circle with pulse animation
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(pointerColor.opacity(pulseOpacity * 0.5), lineWidth: 2)
                    .frame(width: 40 * pulseScale, height: 40 * pulseScale)

                // Middle pulse ring
                Circle()
                    .stroke(pointerColor.opacity(pulseOpacity * 0.7), lineWidth: 1.5)
                    .frame(width: 30 * pulseScale, height: 30 * pulseScale)

                // Main pointer circle
                Circle()
                    .fill(pointerColor.opacity(expirationOpacity))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    )
                    .shadow(color: pointerColor.opacity(0.6), radius: 8)

                // Center dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
            }

            // Distance indicator
            if let distance = distanceToUser {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 8))
                    Text(formatDistance(distance))
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(Color(hex: "#FFFC00"))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.8))
                .cornerRadius(4)
            }

            // Optional message
            if let message = pointer.message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#CCCCCC"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(4)
                    .lineLimit(2)
            }

            // Countdown timer
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.system(size: 8))
                Text(formatTimeRemaining(pointer.timeRemaining))
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(timerColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.8))
            .cornerRadius(4)
        }
        .opacity(expirationOpacity)
        .onAppear {
            startPulseAnimation()
        }
    }

    private var pointerColor: Color {
        Color(hex: pointer.color)
    }

    private var expirationOpacity: Double {
        let remaining = pointer.timeRemaining
        let total = DigitalPointerService.shared.pointerTimeout
        let ratio = remaining / total

        // Start fading at 20% time remaining
        if ratio < 0.2 {
            return max(0.3, ratio * 5)
        }
        return 1.0
    }

    private var timerColor: Color {
        let remaining = pointer.timeRemaining
        if remaining < 10 {
            return Color.red
        } else if remaining < 20 {
            return Color.orange
        }
        return Color(hex: "#00FFFF")
    }

    private var distanceToUser: CLLocationDistance? {
        guard let userLocation = userLocation else { return nil }
        let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let pointerLoc = CLLocation(latitude: pointer.clCoordinate.latitude, longitude: pointer.clCoordinate.longitude)
        return userLoc.distance(from: pointerLoc)
    }

    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }

    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let secs = Int(seconds)
        return String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.5
            pulseOpacity = 0.3
        }
    }
}

// MARK: - Digital Pointer Control Panel

/// Control panel for managing the local pointer
struct DigitalPointerControlPanel: View {
    @ObservedObject var pointerService = DigitalPointerService.shared
    @Environment(\.dismiss) var dismiss

    @State private var messageText: String = ""
    @State private var selectedColor: DigitalPointerService.PointerColor = .orange
    @State private var timerValue: String = "00:00"
    @State private var timerUpdateTask: Timer?

    var body: some View {
        ZStack {
            // Background
            Color(hex: "#1A1A1A")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                controlPanelHeader

                ScrollView {
                    VStack(spacing: 20) {
                        // Status indicator
                        statusSection

                        // Main toggle button
                        toggleSection

                        // Color picker
                        colorPickerSection

                        // Message field
                        messageSection

                        // Active timer
                        if pointerService.isActive {
                            timerSection
                        }

                        // Broadcast info
                        broadcastInfoSection
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            loadCurrentSettings()
            startTimerUpdate()
        }
        .onDisappear {
            stopTimerUpdate()
        }
    }

    // MARK: - Header

    private var controlPanelHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack(spacing: 4) {
                Text("DIGITAL POINTER")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(Color(hex: "#00FFFF"))

                if pointerService.isActive {
                    Text("BROADCASTING")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.green)
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
                .foregroundColor(pointerService.isActive ? Color.green : Color(hex: "#00FFFF")),
            alignment: .bottom
        )
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Status indicator circle
                Circle()
                    .fill(pointerService.isActive ? Color.green : Color(hex: "#666666"))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )

                Text(pointerService.isActive ? "Pointer Active" : "Pointer Inactive")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if pointerService.isActive {
                    Text(timerValue)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#00FFFF"))
                }
            }

            if pointerService.isActive {
                Text("Tap anywhere on the map to update pointer location")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#333300").opacity(0.3))
                    .cornerRadius(8)
            } else {
                Text("Activate pointer to share your cursor position with team")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#999999"))
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Toggle Section

    private var toggleSection: some View {
        Button(action: {
            togglePointer()
        }) {
            HStack(spacing: 16) {
                Image(systemName: pointerService.isActive ? "hand.point.up.left.fill" : "hand.point.up.left")
                    .font(.system(size: 24))
                    .foregroundColor(pointerService.isActive ? Color(hex: "#00FFFF") : .white)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pointerService.isActive ? "DEACTIVATE POINTER" : "ACTIVATE POINTER")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text(pointerService.isActive ? "Stop broadcasting location" : "Start sharing cursor position")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#999999"))
                }

                Spacer()

                Image(systemName: pointerService.isActive ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(pointerService.isActive ? .red : .green)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#2A2A2A"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                pointerService.isActive ? Color(hex: "#00FFFF") : Color(hex: "#3A3A3A"),
                                lineWidth: pointerService.isActive ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Color Picker Section

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("POINTER COLOR")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#999999"))

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(atakColors, id: \.rawValue) { color in
                    ColorButton(
                        color: color,
                        isSelected: selectedColor == color
                    ) {
                        selectedColor = color
                        pointerService.setPointerColor(color)
                        provideSelectionFeedback()
                    }
                }
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    private var atakColors: [DigitalPointerService.PointerColor] {
        [.cyan, .green, .yellow, .orange, .magenta, .red]
    }

    // MARK: - Message Section

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ANNOTATION MESSAGE (OPTIONAL)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#999999"))

            HStack {
                TextField("Short message...", text: $messageText)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color(hex: "#3A3A3A"))
                    .cornerRadius(8)
                    .onChange(of: messageText) { newValue in
                        pointerService.setPointerMessage(newValue)
                    }

                if !messageText.isEmpty {
                    Button(action: {
                        messageText = ""
                        pointerService.setPointerMessage("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                }
            }

            Text("\(messageText.count)/50 characters")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#666666"))
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#00FFFF"))

                Text("ACTIVE DURATION")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#999999"))

                Spacer()

                Text(pointerService.timeSinceActivation)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFFC00"))
            }

            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 16))
                    .foregroundColor(.green)

                Text("Broadcast Count")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#CCCCCC"))

                Spacer()

                Text("\(pointerService.broadcastCount)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#2A2A2A"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#00FFFF").opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Broadcast Info Section

    private var broadcastInfoSection: some View {
        VStack(spacing: 12) {
            Text("BROADCAST INFORMATION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#999999"))

            VStack(spacing: 0) {
                PointerInfoRow(label: "Broadcast Interval", value: "\(Int(pointerService.broadcastInterval))s")
                Divider().background(Color(hex: "#3A3A3A"))
                PointerInfoRow(label: "Pointer Timeout", value: "\(Int(pointerService.pointerTimeout))s")
                Divider().background(Color(hex: "#3A3A3A"))
                PointerInfoRow(label: "Team Pointers Active", value: "\(pointerService.activePointerCount)")

                if !pointerService.lastBroadcastStatus.isEmpty {
                    Divider().background(Color(hex: "#3A3A3A"))
                    HStack {
                        Text("Last Status")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#999999"))
                        Spacer()
                        Text(pointerService.lastBroadcastStatus)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(12)
        }
    }

    // MARK: - Actions

    private func togglePointer() {
        pointerService.togglePointer()

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func loadCurrentSettings() {
        messageText = pointerService.pointerMessage

        // Find matching color
        if let color = DigitalPointerService.PointerColor.allCases.first(where: { $0.rawValue == pointerService.pointerColor }) {
            selectedColor = color
        }
    }

    private func provideSelectionFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    private func startTimerUpdate() {
        updateTimerValue()
        timerUpdateTask = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimerValue()
        }
    }

    private func stopTimerUpdate() {
        timerUpdateTask?.invalidate()
        timerUpdateTask = nil
    }

    private func updateTimerValue() {
        timerValue = pointerService.timeSinceActivation
    }
}

// MARK: - Color Button

struct ColorButton: View {
    let color: DigitalPointerService.PointerColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: color.rawValue))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
                    )
                    .shadow(color: Color(hex: color.rawValue).opacity(0.5), radius: isSelected ? 8 : 0)

                Text(color.displayName)
                    .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : Color(hex: "#999999"))
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(hex: color.rawValue).opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Info Row

struct PointerInfoRow: View {
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

// MARK: - Digital Pointer List View

/// List view showing all active team pointers
struct DigitalPointerListView: View {
    @ObservedObject var pointerService = DigitalPointerService.shared
    @Environment(\.dismiss) var dismiss

    var onZoomToPointer: ((CLLocationCoordinate2D) -> Void)?

    var body: some View {
        ZStack {
            Color(hex: "#1A1A1A")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                listHeader

                if pointerService.teamPointers.isEmpty {
                    emptyStateView
                } else {
                    pointerListView
                }
            }
        }
    }

    // MARK: - Header

    private var listHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack(spacing: 4) {
                Text("TEAM POINTERS")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(Color(hex: "#00FFFF"))

                Text("\(pointerService.activePointerCount) Active")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#999999"))
            }

            Spacer()

            Button(action: {
                pointerService.clearAllTeamPointers()
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#FF3B30"))
            }
            .disabled(pointerService.teamPointers.isEmpty)
            .opacity(pointerService.teamPointers.isEmpty ? 0.3 : 1.0)
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .overlay(
            Rectangle()
                .frame(height: 3)
                .foregroundColor(Color(hex: "#00FFFF")),
            alignment: .bottom
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "hand.point.up.left")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#3A3A3A"))

            Text("No Active Pointers")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "#666666"))

            Text("Team member pointers will appear here when they share their cursor positions.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#999999"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Pointer List

    private var pointerListView: some View {
        List {
            ForEach(pointerService.teamPointers) { pointer in
                PointerListRow(
                    pointer: pointer,
                    onTap: {
                        onZoomToPointer?(pointer.clCoordinate)
                        dismiss()
                    }
                )
                .listRowBackground(Color(hex: "#2A2A2A"))
                .listRowSeparatorTint(Color(hex: "#3A3A3A"))
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let pointer = pointerService.teamPointers[index]
                    pointerService.teamPointers.removeAll { $0.id == pointer.id }
                }
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
        .listStyle(PlainListStyle())
        
    }
}

// MARK: - Pointer List Row

struct PointerListRow: View {
    let pointer: DigitalPointerEvent
    let onTap: () -> Void

    @State private var timeRemaining: String = ""
    @State private var timerTask: Timer?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Color indicator
                Circle()
                    .fill(Color(hex: pointer.color))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )

                // Sender info
                VStack(alignment: .leading, spacing: 4) {
                    Text(pointer.senderCallsign)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    if let message = pointer.message, !message.isEmpty {
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        // Coordinates
                        Text(formatCoordinate(pointer.clCoordinate))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "#999999"))
                    }
                }

                Spacer()

                // Time remaining
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 10))
                        Text(timeRemaining)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(timerColor)

                    Image(systemName: "location.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#00FFFF"))
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            updateTimeRemaining()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private var timerColor: Color {
        let remaining = pointer.timeRemaining
        if remaining < 10 {
            return Color.red
        } else if remaining < 20 {
            return Color.orange
        }
        return Color(hex: "#00FFFF")
    }

    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    private func updateTimeRemaining() {
        let seconds = Int(pointer.timeRemaining)
        timeRemaining = String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func startTimer() {
        timerTask = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimeRemaining()
        }
    }

    private func stopTimer() {
        timerTask?.invalidate()
        timerTask = nil
    }
}

// MARK: - Digital Pointer Toolbar Button

/// Compact button for toolbar showing pointer status
struct DigitalPointerToolbarButton: View {
    @ObservedObject var pointerService = DigitalPointerService.shared
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if pointerService.isActive {
                    // Pulsing background for active pointer
                    Circle()
                        .fill(Color(hex: "#00FFFF").opacity(0.3))
                        .frame(width: 44, height: 44)
                        .scaleEffect(pulse ? 1.2 : 1.0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                pulse = true
                            }
                        }
                }

                VStack(spacing: 2) {
                    Image(systemName: pointerService.isActive ? "hand.point.up.left.fill" : "hand.point.up.left")
                        .font(.system(size: 20))
                        .foregroundColor(pointerService.isActive ? Color(hex: "#00FFFF") : .white)

                    Text("PTR")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(pointerService.isActive ? Color(hex: "#00FFFF") : .white)
                }

                // Badge for team pointers count
                if pointerService.activePointerCount > 0 {
                    Text("\(pointerService.activePointerCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 14, y: -14)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Control Panel") {
    DigitalPointerControlPanel()
}

#Preview("List View") {
    DigitalPointerListView()
}

#Preview("Toolbar Button") {
    ZStack {
        Color.black.ignoresSafeArea()
        DigitalPointerToolbarButton {
            print("Tapped")
        }
    }
}
