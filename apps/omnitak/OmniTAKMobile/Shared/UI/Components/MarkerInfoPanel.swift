//
//  MarkerInfoPanel.swift
//  OmniTAKTest
//
//  Bottom sliding panel with full unit details and actions
//

import SwiftUI
import MapKit
import CoreLocation

struct MarkerInfoPanel: View {
    let marker: EnhancedCoTMarker
    let userLocation: CLLocation?
    let onCenter: () -> Void
    let onMessage: () -> Void
    let onTrack: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var panelHeight: PanelHeight = .collapsed

    enum PanelHeight: CGFloat {
        case collapsed = 150
        case half = 400
        case full = 600
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 6)
                    .padding(.top, 8)

                // Header with callsign and affiliation
                HStack(spacing: 12) {
                    // Affiliation icon
                    Image(systemName: marker.affiliation.icon)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(marker.affiliation.color)
                        .frame(width: 50, height: 50)
                        .background(marker.affiliation.color.opacity(0.2))
                        .cornerRadius(25)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(marker.callsign)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 8) {
                            // Affiliation badge
                            Text(marker.affiliation.displayName)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(marker.affiliation.color.opacity(0.8))
                                .cornerRadius(4)

                            // Unit type badge
                            Text(marker.unitType.displayName)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.6))
                                .cornerRadius(4)

                            // Stale indicator
                            if marker.isStale {
                                Text("STALE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(4)
                            }
                        }
                    }

                    Spacer()

                    // Close button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .background(Color.black.opacity(0.95))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        handleDragEnd(translation: value.translation.height)
                    }
            )

            // Content area (scrollable)
            ScrollView {
                VStack(spacing: 16) {
                    // Action Buttons
                    HStack(spacing: 12) {
                        ActionButton(icon: "location.fill", label: "Center", color: .cyan) {
                            onCenter()
                        }

                        ActionButton(icon: "message.fill", label: "Message", color: .green) {
                            onMessage()
                        }

                        ActionButton(icon: "arrow.triangle.turn.up.right.circle.fill", label: "Track", color: .orange) {
                            onTrack()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Location Information
                    InfoSection(title: "LOCATION") {
                        InfoRow(label: "Coordinates", value: coordinatesString)
                        InfoRow(label: "Altitude", value: altitudeString)
                        InfoRow(label: "Grid", value: mgrsString)

                        if let userLoc = userLocation {
                            InfoRow(label: "Distance", value: distanceString(from: userLoc))
                            InfoRow(label: "Bearing", value: bearingString(from: userLoc))
                        }
                    }

                    // Movement Information
                    if marker.speed != nil || marker.course != nil {
                        InfoSection(title: "MOVEMENT") {
                            if let speed = marker.speed {
                                InfoRow(label: "Speed", value: String(format: "%.1f m/s (%.1f km/h)", speed, speed * 3.6))
                            }
                            if let course = marker.course {
                                InfoRow(label: "Course", value: String(format: "%.0f°", course))
                            }
                        }
                    }

                    // Accuracy Information
                    InfoSection(title: "ACCURACY") {
                        InfoRow(label: "CE (Circular)", value: String(format: "±%.1f m", marker.ce))
                        InfoRow(label: "LE (Linear)", value: String(format: "±%.1f m", marker.le))
                    }

                    // Team Information
                    if let team = marker.team {
                        InfoSection(title: "TEAM") {
                            InfoRow(label: "Name", value: team)
                        }
                    }

                    // Device Information
                    if marker.device != nil || marker.platform != nil || marker.battery != nil {
                        InfoSection(title: "DEVICE") {
                            if let device = marker.device {
                                InfoRow(label: "Device", value: device)
                            }
                            if let platform = marker.platform {
                                InfoRow(label: "Platform", value: platform)
                            }
                            if let battery = marker.battery {
                                InfoRow(label: "Battery", value: "\(battery)%",
                                       valueColor: batteryColor(battery))
                            }
                        }
                    }

                    // Remarks
                    if let remarks = marker.remarks {
                        InfoSection(title: "REMARKS") {
                            Text(remarks)
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(6)
                        }
                    }

                    // Timing Information
                    InfoSection(title: "TIMING") {
                        InfoRow(label: "Last Update", value: lastUpdateString)
                        InfoRow(label: "Age", value: ageString)
                        InfoRow(label: "UID", value: marker.uid)
                        InfoRow(label: "Type", value: marker.type)
                    }
                }
                .padding(.bottom, 20)
            }
            .background(Color.black.opacity(0.9))
        }
        .frame(height: panelHeight.rawValue + dragOffset)
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.5), radius: 10)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: panelHeight)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
    }

    // MARK: - Helper Functions

    private func handleDragEnd(translation: CGFloat) {
        let threshold: CGFloat = 50

        if translation < -threshold {
            // Swipe up
            if panelHeight == .collapsed {
                panelHeight = .half
            } else if panelHeight == .half {
                panelHeight = .full
            }
        } else if translation > threshold {
            // Swipe down
            if panelHeight == .full {
                panelHeight = .half
            } else if panelHeight == .half {
                panelHeight = .collapsed
            } else {
                onDismiss()
            }
        }

        dragOffset = 0
    }

    private var coordinatesString: String {
        String(format: "%.6f, %.6f", marker.coordinate.latitude, marker.coordinate.longitude)
    }

    private var altitudeString: String {
        String(format: "%.1f m (%.0f ft)", marker.altitudeMeters, marker.altitudeFeet)
    }

    private var mgrsString: String {
        // Simple MGRS approximation - in production use proper conversion library
        "N/A (requires MGRS lib)"
    }

    private func distanceString(from location: CLLocation) -> String {
        let distance = marker.distance(from: location)
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.2f km", distance / 1000)
        }
    }

    private func bearingString(from location: CLLocation) -> String {
        let bearing = marker.bearing(from: location)
        let direction = compassDirection(bearing)
        return String(format: "%.0f° (%@)", bearing, direction)
    }

    private func compassDirection(_ bearing: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((bearing + 22.5) / 45.0) % 8
        return directions[index]
    }

    private var lastUpdateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: marker.lastUpdate)
    }

    private var ageString: String {
        let age = marker.ageInSeconds
        if age < 60 {
            return String(format: "%.0f seconds", age)
        } else if age < 3600 {
            return String(format: "%.0f minutes", age / 60)
        } else {
            return String(format: "%.1f hours", age / 3600)
        }
    }

    private func batteryColor(_ battery: Int) -> Color {
        if battery > 50 { return .green }
        if battery > 20 { return .yellow }
        return .red
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(color.opacity(0.8))
                    .cornerRadius(12)

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Info Section Component

struct InfoSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 16)

            VStack(spacing: 1) {
                content
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.2))
    }
}

// MARK: - View Extension for Rounded Corners

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
