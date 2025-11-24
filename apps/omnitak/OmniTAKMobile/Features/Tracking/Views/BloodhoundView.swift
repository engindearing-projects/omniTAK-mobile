//
//  BloodhoundView.swift
//  OmniTAKMobile
//
//  Blue Force Tracking (BFT) dashboard view
//  Displays tracked units, statistics, and alerts with ATAK theme
//

import SwiftUI
import MapKit

// MARK: - Bloodhound View

struct BloodhoundView: View {
    @ObservedObject var bloodhoundService: BloodhoundService
    @Binding var mapRegion: MKCoordinateRegion

    @State private var selectedFilter: TrackFilter = .all
    @State private var sortOption: TrackSortOption = .callsign
    @State private var showAlerts = false
    @State private var selectedTrack: BloodhoundTrack?
    @State private var showTrackDetail = false

    // ATAK Theme Colors
    private let backgroundColor = Color(hex: "#1E1E1E")
    private let accentColor = Color(hex: "#FFFC00")
    private let cardBackground = Color.white.opacity(0.05)
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "#CCCCCC")

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Statistics Summary
                    statisticsSummary

                    // Filter Bar
                    filterBar

                    // Unit List
                    unitList

                    // Alerts Section
                    if showAlerts {
                        alertsSection
                    }
                }
            }
            .navigationTitle("BLOODHOUND BFT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            bloodhoundService.clearAlerts()
                        }) {
                            Label("Clear Alerts", systemImage: "bell.slash")
                        }

                        Button(action: {
                            bloodhoundService.clearAllTracks()
                        }) {
                            Label("Clear All Tracks", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(accentColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showTrackDetail) {
            if let track = selectedTrack {
                BloodhoundTrackDetailView(
                    track: track,
                    onCenterMap: { coordinate in
                        centerMap(on: coordinate)
                    },
                    onClose: {
                        showTrackDetail = false
                    }
                )
            }
        }
    }

    // MARK: - Statistics Summary

    private var statisticsSummary: some View {
        VStack(spacing: 12) {
            // Top row - main counts
            HStack(spacing: 16) {
                StatCard(
                    title: "TRACKED",
                    value: "\(bloodhoundService.statistics.totalTracked)",
                    icon: "person.3.fill",
                    color: accentColor
                )

                StatCard(
                    title: "ONLINE",
                    value: "\(bloodhoundService.statistics.onlineCount)",
                    icon: "antenna.radiowaves.left.and.right",
                    color: .green
                )

                StatCard(
                    title: "STALE",
                    value: "\(bloodhoundService.statistics.staleCount)",
                    icon: "clock.badge.exclamationmark",
                    color: .orange
                )
            }

            // Bottom row - movement stats
            HStack(spacing: 16) {
                StatCard(
                    title: "MOVING",
                    value: "\(bloodhoundService.statistics.movingCount)",
                    icon: "figure.walk",
                    color: .cyan
                )

                StatCard(
                    title: "AVG SPEED",
                    value: String(format: "%.1f", bloodhoundService.statistics.averageNetworkSpeed * 3.6),
                    subtitle: "km/h",
                    icon: "speedometer",
                    color: .purple
                )

                Button(action: {
                    withAnimation {
                        showAlerts.toggle()
                    }
                }) {
                    StatCard(
                        title: "ALERTS",
                        value: "\(bloodhoundService.recentAlerts.count)",
                        icon: "exclamationmark.triangle.fill",
                        color: bloodhoundService.recentAlerts.isEmpty ? .gray : .red
                    )
                }
            }
        }
        .padding()
        .background(cardBackground)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 8) {
            // Team Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    BloodhoundFilterChip(title: "All", isSelected: selectedFilter == .all) {
                        selectedFilter = .all
                    }

                    BloodhoundFilterChip(title: "Online", isSelected: selectedFilter == .online) {
                        selectedFilter = .online
                    }

                    BloodhoundFilterChip(title: "Stale", isSelected: selectedFilter == .stale) {
                        selectedFilter = .stale
                    }

                    BloodhoundFilterChip(title: "Moving", isSelected: selectedFilter == .moving) {
                        selectedFilter = .moving
                    }

                    // Team filters
                    ForEach(bloodhoundService.getAvailableTeams(), id: \.self) { team in
                        BloodhoundFilterChip(
                            title: team,
                            isSelected: selectedFilter == .team(team),
                            color: teamColor(team)
                        ) {
                            selectedFilter = .team(team)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Sort Options
            HStack {
                Text("Sort by:")
                    .font(.system(size: 12))
                    .foregroundColor(textSecondary)

                Picker("Sort", selection: $sortOption) {
                    Text("Callsign").tag(TrackSortOption.callsign)
                    Text("Last Seen").tag(TrackSortOption.lastSeen)
                    Text("Speed").tag(TrackSortOption.speed)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 280)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Unit List

    private var unitList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredAndSortedTracks) { track in
                    TrackRow(
                        track: track,
                        accentColor: accentColor,
                        onTap: {
                            selectedTrack = track
                            showTrackDetail = true
                        },
                        onCenterMap: {
                            if let coordinate = track.currentPosition?.coordinate {
                                centerMap(on: coordinate)
                            }
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Alerts Section

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)

                Text("RECENT ALERTS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red)

                Spacer()

                Button(action: {
                    withAnimation {
                        showAlerts = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(bloodhoundService.recentAlerts.prefix(10)) { alert in
                        AlertRow(alert: alert)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
    }

    // MARK: - Computed Properties

    private var filteredAndSortedTracks: [BloodhoundTrack] {
        var tracks: [BloodhoundTrack]

        switch selectedFilter {
        case .all:
            tracks = bloodhoundService.getAllTracks()
        case .online:
            tracks = bloodhoundService.getOnlineTracks()
        case .stale:
            tracks = bloodhoundService.getStaleTracks()
        case .moving:
            tracks = bloodhoundService.getMovingTracks()
        case .team(let teamName):
            tracks = bloodhoundService.getTracksByTeam(teamName)
        }

        switch sortOption {
        case .callsign:
            tracks.sort { $0.callsign < $1.callsign }
        case .lastSeen:
            tracks.sort { $0.lastUpdate > $1.lastUpdate }
        case .speed:
            tracks.sort { ($0.currentSpeed ?? 0) > ($1.currentSpeed ?? 0) }
        }

        return tracks
    }

    // MARK: - Helper Methods

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        withAnimation {
            mapRegion.center = coordinate
            mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func teamColor(_ team: String) -> Color {
        switch team.lowercased() {
        case "cyan":
            return .cyan
        case "blue":
            return .blue
        case "green":
            return .green
        case "red":
            return .red
        case "white":
            return .white
        case "yellow":
            return .yellow
        case "orange":
            return .orange
        case "magenta", "pink":
            return .pink
        case "purple":
            return .purple
        default:
            return .gray
        }
    }
}

// MARK: - Filter Types

enum TrackFilter: Equatable {
    case all
    case online
    case stale
    case moving
    case team(String)
}

enum TrackSortOption {
    case callsign
    case lastSeen
    case speed
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#CCCCCC"))
            }

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "#CCCCCC"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Filter Chip

struct BloodhoundFilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = Color(hex: "#FFFC00")
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color.white.opacity(0.1))
                .cornerRadius(16)
        }
    }
}

// MARK: - Track Row

struct TrackRow: View {
    let track: BloodhoundTrack
    let accentColor: Color
    let onTap: () -> Void
    let onCenterMap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Team Color Indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(teamIndicatorColor)
                    .frame(width: 6, height: 50)

                // Main Info
                VStack(alignment: .leading, spacing: 4) {
                    // Callsign with status
                    HStack(spacing: 6) {
                        Text(track.callsign)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)

                        if track.isStale {
                            Text("STALE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        } else if track.isOnline {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }

                        // Alert indicator
                        if !track.alertFlags.isEmpty {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                    }

                    // Position
                    if let position = track.currentPosition {
                        Text(String(format: "%.5f, %.5f", position.coordinate.latitude, position.coordinate.longitude))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                    }

                    // Speed and Heading
                    HStack(spacing: 16) {
                        if let speed = track.currentSpeed, speed > 0.1 {
                            HStack(spacing: 4) {
                                Image(systemName: "speedometer")
                                    .font(.system(size: 10))
                                Text(String(format: "%.1f km/h", speed * 3.6))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.cyan)
                        }

                        if let heading = track.currentHeading {
                            HStack(spacing: 4) {
                                Image(systemName: "location.north.fill")
                                    .font(.system(size: 10))
                                    .rotationEffect(.degrees(heading))
                                Text(String(format: "%.0f°", heading))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                // Right side - time and action
                VStack(alignment: .trailing, spacing: 8) {
                    Text(track.formattedAge)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(track.isStale ? .orange : .gray)

                    Button(action: onCenterMap) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(accentColor)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var teamIndicatorColor: Color {
        guard let team = track.team else { return .gray }

        switch team.lowercased() {
        case "cyan":
            return .cyan
        case "blue":
            return .blue
        case "green":
            return .green
        case "red":
            return .red
        case "white":
            return .white
        case "yellow":
            return .yellow
        case "orange":
            return .orange
        case "magenta", "pink":
            return .pink
        case "purple":
            return .purple
        default:
            return .gray
        }
    }
}

// MARK: - Alert Row

struct AlertRow: View {
    let alert: TrackAlert

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.type.icon)
                .font(.system(size: 14))
                .foregroundColor(alert.type.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(alert.callsign)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)

                    Text("- \(alert.type.displayName)")
                        .font(.system(size: 11))
                        .foregroundColor(alert.type.color)
                }

                Text(alert.message)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#CCCCCC"))
                    .lineLimit(2)
            }

            Spacer()

            Text(formatAlertTime(alert.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private func formatAlertTime(_ date: Date) -> String {
        let age = Date().timeIntervalSince(date)
        if age < 60 {
            return String(format: "%.0fs", age)
        } else if age < 3600 {
            return String(format: "%.0fm", age / 60)
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Track Detail View

struct BloodhoundTrackDetailView: View {
    let track: BloodhoundTrack
    let onCenterMap: (CLLocationCoordinate2D) -> Void
    let onClose: () -> Void

    private let backgroundColor = Color(hex: "#1E1E1E")
    private let accentColor = Color(hex: "#FFFC00")

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    headerSection

                    // Current Position
                    positionSection

                    // Movement Data
                    movementSection

                    // Track Statistics
                    statisticsSection

                    // Position History
                    historySection
                }
                .padding()
            }
            .background(backgroundColor.edgesIgnoringSafeArea(.all))
            .navigationTitle(track.callsign)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onClose()
                    }
                    .foregroundColor(accentColor)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Team indicator
            if let team = track.team {
                Text(team.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(teamColor.opacity(0.3))
                    .cornerRadius(8)
            }

            // Status
            HStack(spacing: 12) {
                if track.isStale {
                    Label("STALE", systemImage: "clock.badge.exclamationmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                } else if track.isOnline {
                    Label("ONLINE", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                } else {
                    Label("OFFLINE", systemImage: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }

                Text("Last seen: \(track.formattedAge) ago")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            // Center on map button
            Button(action: {
                if let coordinate = track.currentPosition?.coordinate {
                    onCenterMap(coordinate)
                }
            }) {
                Label("Center on Map", systemImage: "location.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(accentColor)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT POSITION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accentColor)

            if let position = track.currentPosition {
                DetailRowView(label: "Latitude", value: String(format: "%.6f°", position.coordinate.latitude))
                DetailRowView(label: "Longitude", value: String(format: "%.6f°", position.coordinate.longitude))
                DetailRowView(label: "Altitude", value: String(format: "%.1f m (%.1f ft)", position.altitude, position.altitude * 3.28084))
                DetailRowView(label: "Updated", value: position.timestamp.formatted())
            } else {
                Text("No position data")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var movementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MOVEMENT")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accentColor)

            if let speed = track.currentSpeed {
                DetailRowView(label: "Current Speed", value: String(format: "%.2f m/s (%.1f km/h)", speed, speed * 3.6))
            }

            if let heading = track.currentHeading {
                DetailRowView(label: "Heading", value: String(format: "%.0f°", heading))
            }

            DetailRowView(label: "Average Speed", value: String(format: "%.2f m/s (%.1f km/h)", track.averageSpeed, track.averageSpeed * 3.6))

            // Predicted position
            if let predicted = track.predictPosition(secondsAhead: 60) {
                DetailRowView(label: "Est. in 1 min", value: String(format: "%.5f, %.5f", predicted.latitude, predicted.longitude))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRACK STATISTICS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accentColor)

            DetailRowView(label: "UID", value: track.uid, monospace: true)
            DetailRowView(label: "Track Points", value: "\(track.positions.count)")

            if let firstPos = track.positions.first {
                DetailRowView(label: "First Seen", value: firstPos.timestamp.formatted())
            }

            DetailRowView(label: "Last Update", value: track.lastUpdate.formatted())

            // Alert flags
            if !track.alertFlags.isEmpty {
                Text("Active Alerts:")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)

                if track.alertFlags.contains(.staleTrack) {
                    Text("- Stale Track")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
                if track.alertFlags.contains(.positionJump) {
                    Text("- Position Jump")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
                if track.alertFlags.contains(.highSpeed) {
                    Text("- High Speed")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                }
                if track.alertFlags.contains(.rapidMovement) {
                    Text("- Rapid Movement")
                        .font(.system(size: 10))
                        .foregroundColor(.purple)
                }
                if track.alertFlags.contains(.altitudeChange) {
                    Text("- Altitude Change")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("POSITION HISTORY (Last 10)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accentColor)

            ForEach(track.positions.suffix(10).reversed()) { position in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.5f, %.5f", position.coordinate.latitude, position.coordinate.longitude))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)

                        HStack(spacing: 8) {
                            if let speed = position.speed {
                                Text(String(format: "%.1f km/h", speed * 3.6))
                                    .font(.system(size: 10))
                                    .foregroundColor(.cyan)
                            }

                            if let course = position.course {
                                Text(String(format: "%.0f°", course))
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    Spacer()

                    Text(position.timestamp.formatted(.dateTime.hour().minute().second()))
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)

                Divider()
                    .background(Color.gray.opacity(0.3))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var teamColor: Color {
        guard let team = track.team else { return .gray }

        switch team.lowercased() {
        case "cyan":
            return .cyan
        case "blue":
            return .blue
        case "green":
            return .green
        case "red":
            return .red
        case "white":
            return .white
        case "yellow":
            return .yellow
        case "orange":
            return .orange
        case "magenta", "pink":
            return .pink
        case "purple":
            return .purple
        default:
            return .gray
        }
    }
}

// MARK: - Detail Row View

struct DetailRowView: View {
    let label: String
    let value: String
    var monospace: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(monospace ? .system(size: 12, design: .monospaced) : .system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
