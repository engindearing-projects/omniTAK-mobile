//
//  WaypointListView.swift
//  OmniTAKMobile
//
//  UI for browsing, managing, and navigating to waypoints
//

import SwiftUI
import MapKit

// MARK: - Waypoint List View

struct WaypointListView: View {
    @ObservedObject var waypointManager = WaypointManager.shared
    @ObservedObject var navigationService = NavigationService.shared
    @State private var searchQuery = ""
    @State private var showingAddWaypoint = false
    @State private var sortMode: SortMode = .name
    @State private var selectedWaypoint: Waypoint?
    @State private var showingWaypointDetail = false

    enum SortMode: String, CaseIterable {
        case name = "Name"
        case distance = "Distance"
        case created = "Created"

        var icon: String {
            switch self {
            case .name: return "textformat"
            case .distance: return "location"
            case .created: return "clock"
            }
        }
    }

    var filteredWaypoints: [Waypoint] {
        let waypoints = searchQuery.isEmpty ?
            waypointManager.waypoints :
            waypointManager.searchWaypoints(query: searchQuery)

        return sortedWaypoints(waypoints)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchQuery, placeholder: "Search waypoints...")
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // Sort controls
                HStack(spacing: 12) {
                    ForEach(SortMode.allCases, id: \.self) { mode in
                        Button(action: {
                            sortMode = mode
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                Text(mode.rawValue)
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                sortMode == mode ?
                                    Color.cyan : Color.gray.opacity(0.2)
                            )
                            .foregroundColor(sortMode == mode ? .black : .white)
                            .cornerRadius(8)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Waypoint list
                if filteredWaypoints.isEmpty {
                    EmptyWaypointsView(searchQuery: searchQuery)
                } else {
                    List {
                        ForEach(filteredWaypoints) { waypoint in
                            WaypointRowView(
                                waypoint: waypoint,
                                navigationService: navigationService
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedWaypoint = waypoint
                                showingWaypointDetail = true
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    waypointManager.deleteWaypoint(waypoint)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    navigationService.toggleNavigation(to: waypoint)
                                } label: {
                                    Label(
                                        isNavigatingToWaypoint(waypoint) ? "Stop" : "Navigate",
                                        systemImage: isNavigatingToWaypoint(waypoint) ? "stop.fill" : "location.fill"
                                    )
                                }
                                .tint(isNavigatingToWaypoint(waypoint) ? .orange : .cyan)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Waypoints (\(waypointManager.waypointCount))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddWaypoint = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                    }
                }
            }
            .sheet(isPresented: $showingAddWaypoint) {
                AddWaypointView()
            }
            .sheet(item: $selectedWaypoint) { waypoint in
                WaypointDetailView(waypoint: waypoint)
            }
        }
    }

    private func sortedWaypoints(_ waypoints: [Waypoint]) -> [Waypoint] {
        switch sortMode {
        case .name:
            return waypoints.sorted { $0.name < $1.name }
        case .distance:
            if let location = navigationService.currentLocation {
                return waypointManager.waypointsSortedByDistance(from: location)
            }
            return waypoints
        case .created:
            return waypoints.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func isNavigatingToWaypoint(_ waypoint: Waypoint) -> Bool {
        navigationService.navigationState.isNavigating &&
        navigationService.navigationState.targetWaypoint?.id == waypoint.id
    }
}

// MARK: - Waypoint Row View

struct WaypointRowView: View {
    let waypoint: Waypoint
    @ObservedObject var navigationService: NavigationService

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: waypoint.icon.rawValue)
                .font(.system(size: 24))
                .foregroundColor(waypoint.color.swiftUIColor)
                .frame(width: 40)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(waypoint.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                if let remarks = waypoint.remarks, !remarks.isEmpty {
                    Text(remarks)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                // Distance and bearing
                if let distance = navigationService.distance(to: waypoint),
                   let bearing = navigationService.bearing(to: waypoint) {
                    HStack(spacing: 8) {
                        Label(
                            distance.formattedDistance,
                            systemImage: "arrow.right"
                        )
                        .font(.caption)
                        .foregroundColor(.cyan)

                        Label(
                            String(format: "%.0f°", bearing),
                            systemImage: "location.north"
                        )
                        .font(.caption)
                        .foregroundColor(.yellow)
                    }
                }
            }

            Spacer()

            // Navigation indicator
            if navigationService.navigationState.isNavigating &&
               navigationService.navigationState.targetWaypoint?.id == waypoint.id {
                Image(systemName: "location.fill.viewfinder")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Empty Waypoints View

struct EmptyWaypointsView: View {
    let searchQuery: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: searchQuery.isEmpty ? "mappin.slash" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(searchQuery.isEmpty ? "No waypoints" : "No results found")
                .font(.title3)
                .foregroundColor(.white)

            Text(searchQuery.isEmpty ?
                 "Tap + to add a waypoint" :
                 "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Add Waypoint View

struct AddWaypointView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var waypointManager = WaypointManager.shared
    @ObservedObject var navigationService = NavigationService.shared

    @State private var name = ""
    @State private var remarks = ""
    @State private var selectedIcon: WaypointIcon = .waypoint
    @State private var selectedColor: WaypointColor = .blue
    @State private var useCurrentLocation = true
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var altitude = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Name")) {
                    TextField("Waypoint name", text: $name)
                }

                Section(header: Text("Description")) {
                    TextEditor(text: $remarks)
                        .frame(height: 80)
                }

                Section(header: Text("Location")) {
                    Toggle("Use Current Location", isOn: $useCurrentLocation)

                    if !useCurrentLocation {
                        HStack {
                            Text("Lat:")
                            TextField("0.0", text: $latitude)
                                .keyboardType(.decimalPad)
                        }

                        HStack {
                            Text("Lon:")
                            TextField("0.0", text: $longitude)
                                .keyboardType(.decimalPad)
                        }
                    }

                    HStack {
                        Text("Alt (m):")
                        TextField("Optional", text: $altitude)
                            .keyboardType(.decimalPad)
                    }
                }

                Section(header: Text("Icon")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(WaypointIcon.allCases, id: \.self) { icon in
                                VStack(spacing: 4) {
                                    Image(systemName: icon.rawValue)
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedIcon == icon ? .cyan : .gray)
                                        .frame(width: 50, height: 50)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedIcon == icon ?
                                                     Color.cyan.opacity(0.2) :
                                                        Color.gray.opacity(0.1))
                                        )
                                        .onTapGesture {
                                            selectedIcon = icon
                                        }

                                    Text(icon.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section(header: Text("Color")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(WaypointColor.allCases, id: \.self) { color in
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Add Waypoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveWaypoint()
                    }
                    .disabled(name.isEmpty || !isValidCoordinate())
                }
            }
        }
    }

    private func isValidCoordinate() -> Bool {
        if useCurrentLocation {
            return navigationService.currentLocation != nil
        } else {
            guard let lat = Double(latitude), let lon = Double(longitude) else {
                return false
            }
            return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
        }
    }

    private func saveWaypoint() {
        let coordinate: CLLocationCoordinate2D
        let alt: Double?

        if useCurrentLocation {
            guard let location = navigationService.currentLocation else { return }
            coordinate = location.coordinate
            alt = location.altitude
        } else {
            guard let lat = Double(latitude), let lon = Double(longitude) else { return }
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            alt = Double(altitude)
        }

        _ = waypointManager.createWaypoint(
            name: name,
            coordinate: coordinate,
            altitude: alt,
            remarks: remarks.isEmpty ? nil : remarks,
            icon: selectedIcon,
            color: selectedColor
        )

        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Waypoint Detail View

struct WaypointDetailView: View {
    let waypoint: Waypoint
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var navigationService = NavigationService.shared
    @ObservedObject var takService = TAKService()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Icon and name
                    VStack(spacing: 12) {
                        Image(systemName: waypoint.icon.rawValue)
                            .font(.system(size: 60))
                            .foregroundColor(waypoint.color.swiftUIColor)

                        Text(waypoint.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let remarks = waypoint.remarks {
                            Text(remarks)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()

                    // Coordinates
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(
                            icon: "location.north",
                            label: "Latitude",
                            value: String(format: "%.6f°", waypoint.coordinate.latitude)
                        )

                        DetailRow(
                            icon: "location",
                            label: "Longitude",
                            value: String(format: "%.6f°", waypoint.coordinate.longitude)
                        )

                        if let altitude = waypoint.altitude {
                            DetailRow(
                                icon: "arrow.up",
                                label: "Altitude",
                                value: String(format: "%.1f m", altitude)
                            )
                        }

                        if let distance = navigationService.distance(to: waypoint) {
                            DetailRow(
                                icon: "arrow.right",
                                label: "Distance",
                                value: distance.formattedDistance
                            )
                        }

                        if let bearing = navigationService.bearing(to: waypoint) {
                            DetailRow(
                                icon: "safari",
                                label: "Bearing",
                                value: String(format: "%.0f°", bearing)
                            )
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Actions
                    VStack(spacing: 12) {
                        Button(action: {
                            navigationService.startNavigation(to: waypoint)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                Text("Navigate Here")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan)
                            .cornerRadius(12)
                        }

                        Button(action: {
                            _ = takService.sendWaypoint(waypoint)
                        }) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Share via CoT")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField(placeholder, text: $text)
                .foregroundColor(.white)

            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}

// MARK: - Preview

#Preview {
    WaypointListView()
        .preferredColorScheme(.dark)
}
