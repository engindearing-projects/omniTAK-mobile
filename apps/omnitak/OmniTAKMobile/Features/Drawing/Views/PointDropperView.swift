//
//  PointDropperView.swift
//  OmniTAKMobile
//
//  Main interface for point dropping and marker management
//

import SwiftUI
import CoreLocation
import MapKit

// MARK: - Point Dropper View

struct PointDropperView: View {
    @ObservedObject var service: PointDropperService
    @Binding var isPresented: Bool

    let currentLocation: CLLocationCoordinate2D?
    let mapCenter: CLLocationCoordinate2D?

    @State private var markerName: String = ""
    @State private var selectedAffiliation: MarkerAffiliation = .hostile
    @State private var remarks: String = ""
    @State private var broadcastImmediately: Bool = false
    @State private var showSALUTEReport: Bool = false
    @State private var showMarkerList: Bool = false
    @State private var selectedMarkerForSALUTE: PointMarker?

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Quick Drop Section
                        quickDropSection

                        // Affiliation Selector
                        affiliationSelector

                        // Name Input
                        nameInputSection

                        // Remarks Section
                        remarksSection

                        // Location Info
                        locationInfoSection

                        // Options
                        optionsSection

                        // Drop Button
                        dropButtonSection

                        // Recent Markers
                        recentMarkersSection

                        // Statistics
                        statisticsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Point Dropper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showMarkerList = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                            Text("\(service.markerCount)")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#FFFC00"))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSALUTEReport) {
            if let marker = selectedMarkerForSALUTE {
                SALUTEReportView(
                    marker: marker,
                    onSave: { report in
                        service.setSALUTEReport(report, for: marker.id)
                        showSALUTEReport = false
                    },
                    onCancel: {
                        showSALUTEReport = false
                    }
                )
            }
        }
        .sheet(isPresented: $showMarkerList) {
            MarkerListView(service: service)
        }
    }

    // MARK: - Quick Drop Section

    private var quickDropSection: some View {
        VStack(spacing: 12) {
            Text("QUICK DROP")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            HStack(spacing: 12) {
                QuickDropButton(
                    affiliation: .hostile,
                    label: "HOSTILE",
                    action: {
                        quickDrop(affiliation: .hostile)
                    }
                )

                QuickDropButton(
                    affiliation: .friendly,
                    label: "FRIENDLY",
                    action: {
                        quickDrop(affiliation: .friendly)
                    }
                )

                QuickDropButton(
                    affiliation: .unknown,
                    label: "UNKNOWN",
                    action: {
                        quickDrop(affiliation: .unknown)
                    }
                )

                QuickDropButton(
                    affiliation: .neutral,
                    label: "NEUTRAL",
                    action: {
                        quickDrop(affiliation: .neutral)
                    }
                )
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Affiliation Selector

    private var affiliationSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AFFILIATION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            HStack(spacing: 8) {
                ForEach(MarkerAffiliation.allCases, id: \.self) { affiliation in
                    AffiliationButton(
                        affiliation: affiliation,
                        isSelected: selectedAffiliation == affiliation,
                        action: {
                            selectedAffiliation = affiliation
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Name Input

    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MARKER NAME")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            TextField("Auto-generated if empty", text: $markerName)
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .foregroundColor(.white)
                .autocapitalization(.allCharacters)

            Text("Leave blank for auto-generated name")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Remarks Section

    private var remarksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REMARKS / NOTES")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            TextEditor(text: $remarks)
                .frame(minHeight: 60)
                .padding(8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .foregroundColor(.white)

            Text("Optional: Additional details about the marker")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Location Info

    private var locationInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DROP LOCATION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            if let location = currentLocation ?? mapCenter {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.cyan)
                        Text("Current Position")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }

                    HStack {
                        Text("LAT:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                        Text(String(format: "%.6f", location.latitude))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)

                        Text("LON:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                        Text(String(format: "%.6f", location.longitude))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)

                        Spacer()
                    }

                    HStack {
                        Image(systemName: "map.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 10))
                        Text(formatMGRS(location))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.orange)
                        Spacer()
                    }
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("No location available")
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Options

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OPTIONS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            Toggle(isOn: $broadcastImmediately) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.cyan)
                    Text("Broadcast immediately")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#FFFC00")))
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Drop Button

    private var dropButtonSection: some View {
        Button(action: dropMarker) {
            HStack(spacing: 12) {
                Image(systemName: "scope")
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: 2) {
                    Text("DROP POINT")
                        .font(.system(size: 18, weight: .bold))

                    Text(selectedAffiliation.displayName.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                }

                Spacer()

                Image(systemName: selectedAffiliation.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(selectedAffiliation.color)
            }
            .padding()
            .background(selectedAffiliation.color.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedAffiliation.color, lineWidth: 2)
            )
        }
        .disabled(currentLocation == nil && mapCenter == nil)
    }

    // MARK: - Recent Markers

    private var recentMarkersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RECENT MARKERS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#FFFC00"))

                Spacer()

                if !service.recentMarkers.isEmpty {
                    Text("\(service.recentMarkers.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                }
            }

            if service.recentMarkers.isEmpty {
                Text("No recent markers")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(service.recentMarkers) { marker in
                            RecentMarkerCard(
                                marker: marker,
                                onTap: {
                                    selectedMarkerForSALUTE = marker
                                    showSALUTEReport = true
                                },
                                onBroadcast: {
                                    service.broadcastMarker(marker)
                                },
                                onDelete: {
                                    service.deleteMarker(marker)
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STATISTICS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            HStack(spacing: 16) {
                PointDropperStatBox(label: "HOSTILE", value: "\(service.hostileCount)", color: .red)
                PointDropperStatBox(label: "FRIENDLY", value: "\(service.friendlyCount)", color: .cyan)
                PointDropperStatBox(label: "UNKNOWN", value: "\(service.unknownCount)", color: .yellow)
                PointDropperStatBox(label: "NEUTRAL", value: "\(service.neutralCount)", color: .green)
            }

            HStack(spacing: 16) {
                PointDropperStatBox(label: "TOTAL", value: "\(service.markerCount)", color: .white)
                PointDropperStatBox(label: "BROADCAST", value: "\(service.broadcastedCount)", color: .orange)
                PointDropperStatBox(label: "SALUTE", value: "\(service.withSALUTECount)", color: .purple)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func quickDrop(affiliation: MarkerAffiliation) {
        guard let location = currentLocation ?? mapCenter else { return }

        let marker = service.quickDrop(at: location, broadcast: broadcastImmediately)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        #if DEBUG
        print("📍 Quick dropped \(affiliation.displayName) marker: \(marker.name)")
        #endif
    }

    private func dropMarker() {
        guard let location = currentLocation ?? mapCenter else { return }

        let name = markerName.isEmpty ? nil : markerName
        let marker = service.createMarker(
            name: name ?? service.recentMarkers.first?.name ?? "Marker",
            affiliation: selectedAffiliation,
            coordinate: location,
            remarks: remarks.isEmpty ? nil : remarks,
            broadcast: broadcastImmediately
        )

        // Prompt for SALUTE report if hostile
        if selectedAffiliation == .hostile {
            selectedMarkerForSALUTE = marker
            showSALUTEReport = true
        }

        // Reset fields
        markerName = ""
        remarks = ""

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func formatMGRS(_ coordinate: CLLocationCoordinate2D) -> String {
        let lat = abs(coordinate.latitude)
        let lon = abs(coordinate.longitude)
        let latDeg = Int(lat)
        let lonDeg = Int(lon)
        let latMin = Int((lat - Double(latDeg)) * 60)
        let lonMin = Int((lon - Double(lonDeg)) * 60)
        return "\(latDeg)\(latMin)N \(lonDeg)\(lonMin)W"
    }
}

// MARK: - Supporting Views

struct QuickDropButton: View {
    let affiliation: MarkerAffiliation
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: affiliation.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(affiliation.color)

                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(affiliation.color.opacity(0.2))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(affiliation.color.opacity(0.5), lineWidth: 1)
            )
        }
    }
}

struct AffiliationButton: View {
    let affiliation: MarkerAffiliation
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: affiliation.iconName)
                    .font(.system(size: 24))

                Text(affiliation.shortCode)
                    .font(.system(size: 10, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(isSelected ? .black : affiliation.color)
            .background(isSelected ? affiliation.color : affiliation.color.opacity(0.2))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(affiliation.color, lineWidth: isSelected ? 3 : 1)
            )
        }
    }
}

struct RecentMarkerCard: View {
    let marker: PointMarker
    let onTap: () -> Void
    let onBroadcast: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: marker.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(marker.affiliation.color)

                Text(marker.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Text(marker.formattedTimestamp)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)

            HStack(spacing: 8) {
                Button(action: onTap) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                }

                Button(action: onBroadcast) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                }

                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }

            if marker.isBroadcast {
                Text("BROADCAST")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(4)
            }

            if marker.saluteReport != nil {
                Text("SALUTE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding()
        .frame(width: 140)
        .background(Color.black.opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(marker.affiliation.color.opacity(0.5), lineWidth: 1)
        )
    }
}

struct PointDropperStatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Marker List View

struct MarkerListView: View {
    @ObservedObject var service: PointDropperService
    @State private var searchText: String = ""
    @State private var filterAffiliation: MarkerAffiliation?
    @Environment(\.dismiss) var dismiss

    var filteredMarkers: [PointMarker] {
        var markers = service.markersSortedByTime()

        if let affiliation = filterAffiliation {
            markers = markers.filter { $0.affiliation == affiliation }
        }

        if !searchText.isEmpty {
            markers = markers.filter { marker in
                marker.name.localizedCaseInsensitiveContains(searchText) ||
                (marker.remarks?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return markers
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter Bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "All", isSelected: filterAffiliation == nil) {
                                filterAffiliation = nil
                            }

                            ForEach(MarkerAffiliation.allCases, id: \.self) { affiliation in
                                FilterChip(
                                    label: affiliation.shortCode,
                                    isSelected: filterAffiliation == affiliation,
                                    color: affiliation.color
                                ) {
                                    filterAffiliation = affiliation
                                }
                            }
                        }
                        .padding()
                    }

                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search markers...", text: $searchText)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // Marker List
                    List {
                        ForEach(filteredMarkers) { marker in
                            MarkerRowView(marker: marker, service: service)
                                .listRowBackground(Color.clear)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let marker = filteredMarkers[index]
                                service.deleteMarker(marker)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("All Markers (\(filteredMarkers.count))")
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
        .preferredColorScheme(.dark)
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isSelected ? .black : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.2))
                .cornerRadius(16)
        }
    }
}

struct MarkerRowView: View {
    let marker: PointMarker
    @ObservedObject var service: PointDropperService

    var body: some View {
        HStack(spacing: 12) {
            // Affiliation Icon
            Image(systemName: marker.iconName)
                .font(.system(size: 24))
                .foregroundColor(marker.affiliation.color)
                .frame(width: 40)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(marker.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text(marker.formattedTimestamp)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)

                if let remarks = marker.remarks {
                    Text(remarks)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if marker.isBroadcast {
                        Label("SENT", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                    }

                    if marker.saluteReport != nil {
                        Label("SALUTE", systemImage: "doc.text.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.purple)
                    }
                }
            }

            Spacer()

            // Actions
            VStack(spacing: 8) {
                Button(action: {
                    service.broadcastMarker(marker)
                }) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                }

                Button(action: {
                    service.deleteMarker(marker)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Point Dropper Button (for map overlay)

struct PointDropperButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: "scope")
                    .font(.system(size: 20, weight: .semibold))
                Text("Drop")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(width: 56, height: 56)
            .background(isPressed ? Color.red.opacity(0.5) : Color.black.opacity(0.6))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Preview

struct PointDropperView_Previews: PreviewProvider {
    static var previews: some View {
        PointDropperView(
            service: PointDropperService.shared,
            isPresented: .constant(true),
            currentLocation: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
            mapCenter: nil
        )
    }
}
