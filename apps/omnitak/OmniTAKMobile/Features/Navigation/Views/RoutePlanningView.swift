//
//  RoutePlanningView.swift
//  OmniTAKMobile
//
//  Route planning UI for creating and managing routes
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Route List View

struct RouteListView: View {
    @ObservedObject var routeService = RoutePlanningService.shared
    @State private var showCreateRoute = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if routeService.routes.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(routeService.routes) { route in
                                    RouteCard(route: route)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateRoute = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hex: "#FFFC00"))
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateRoute) {
            RouteCreatorView()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Routes")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Create a route to plan your navigation")
                .font(.system(size: 14))
                .foregroundColor(.gray)

            Button(action: { showCreateRoute = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Route")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#FFFC00"))
                .padding()
                .background(Color(hex: "#FFFC00").opacity(0.2))
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - Route Card

struct RouteCard: View {
    let route: Route
    @ObservedObject var routeService = RoutePlanningService.shared
    @State private var showDetail = false

    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(route.swiftUIColor)
                        .frame(width: 12, height: 12)

                    Text(route.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    if routeService.activeRoute?.id == route.id {
                        Text("ACTIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#FFFC00"))
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Distance")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(formatDistance(route.totalDistance))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Waypoints")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text("\(route.waypoints.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Est. Time")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(formatTime(route.estimatedTime))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Spacer()
                }

                // Waypoint preview
                HStack(spacing: 8) {
                    ForEach(Array(route.waypoints.prefix(4).enumerated()), id: \.offset) { index, waypoint in
                        HStack(spacing: 4) {
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 16, height: 16)
                                .background(route.swiftUIColor)
                                .cornerRadius(8)

                            Text(waypoint.name)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }

                        if index < min(route.waypoints.count - 1, 3) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }

                    if route.waypoints.count > 4 {
                        Text("+\(route.waypoints.count - 4) more")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetail) {
            RouteDetailView(route: route)
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Route Detail View

struct RouteDetailView: View {
    let route: Route
    @ObservedObject var routeService = RoutePlanningService.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var isCalculating = false
    @State private var calculatedRoute: Route?
    @State private var showError = false
    @State private var errorMessage = ""

    private var displayRoute: Route {
        calculatedRoute ?? route
    }

    private var hasDirections: Bool {
        !displayRoute.segments.isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Route Info Card
                        VStack(spacing: 12) {
                            HStack {
                                Circle()
                                    .fill(displayRoute.swiftUIColor)
                                    .frame(width: 16, height: 16)

                                Text(displayRoute.name)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)

                                Spacer()

                                // Directions status badge
                                if hasDirections {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                        Text("Directions")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(6)
                                }
                            }

                            HStack(spacing: 30) {
                                StatItem(title: "Distance", value: formatDistance(displayRoute.totalDistance))
                                StatItem(title: "Waypoints", value: "\(displayRoute.waypoints.count)")
                                StatItem(title: "Est. Time", value: formatTime(displayRoute.estimatedTime))
                            }
                        }
                        .padding()
                        .background(Color(hex: "#2A2A2A"))
                        .cornerRadius(12)

                        // Get Directions button (if not calculated)
                        if !hasDirections {
                            Button(action: calculateDirections) {
                                HStack {
                                    if isCalculating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "map.fill")
                                    }
                                    Text(isCalculating ? "Calculating Route..." : "Get Driving Directions")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                            .disabled(isCalculating)

                            Text("Get turn-by-turn directions using Apple Maps")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }

                        // Turn-by-turn instructions (if calculated)
                        if hasDirections {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("TURN-BY-TURN DIRECTIONS")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.gray)

                                    Spacer()

                                    Text("\(allInstructions.count) steps")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }

                                ForEach(Array(allInstructions.prefix(10).enumerated()), id: \.offset) { index, instruction in
                                    HStack(spacing: 12) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.black)
                                            .frame(width: 22, height: 22)
                                            .background(Color(hex: "#FFFC00"))
                                            .cornerRadius(11)

                                        Text(instruction)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)

                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }

                                if allInstructions.count > 10 {
                                    Text("+ \(allInstructions.count - 10) more steps")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .padding()
                            .background(Color(hex: "#2A2A2A"))
                            .cornerRadius(12)
                        }

                        // Waypoints List
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WAYPOINTS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)

                            ForEach(Array(displayRoute.waypoints.enumerated()), id: \.offset) { index, waypoint in
                                WaypointRow(index: index + 1, waypoint: waypoint, color: displayRoute.swiftUIColor)
                            }
                        }

                        // Actions
                        VStack(spacing: 12) {
                            Button(action: startNavigation) {
                                HStack {
                                    if isCalculating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "location.fill")
                                    }
                                    Text(routeService.activeRoute?.id == route.id ? "Route Active" : "Start Navigation")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "#FFFC00"))
                                .cornerRadius(10)
                            }
                            .disabled(isCalculating)

                            Button(action: showOnMap) {
                                HStack {
                                    Image(systemName: "map")
                                    Text("Show on Map")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.cyan)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cyan.opacity(0.2))
                                .cornerRadius(10)
                            }

                            Button(action: deleteRoute) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("Delete Route")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Route Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var allInstructions: [String] {
        displayRoute.segments.flatMap { $0.instructions }
    }

    private func calculateDirections() {
        isCalculating = true

        routeService.calculateRouteDirections(for: route) { result in
            DispatchQueue.main.async {
                isCalculating = false

                switch result {
                case .success(let updatedRoute):
                    calculatedRoute = updatedRoute
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func startNavigation() {
        if hasDirections {
            routeService.startNavigation(for: displayRoute)
            presentationMode.wrappedValue.dismiss()
        } else {
            // Calculate directions first, then start navigation
            isCalculating = true
            routeService.calculateRouteDirections(for: route) { result in
                DispatchQueue.main.async {
                    isCalculating = false

                    switch result {
                    case .success(let updatedRoute):
                        calculatedRoute = updatedRoute
                        routeService.startNavigation(for: updatedRoute)
                        presentationMode.wrappedValue.dismiss()
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }

    private func showOnMap() {
        // Set active route to show on map
        routeService.activeRoute = displayRoute
        presentationMode.wrappedValue.dismiss()
    }

    private func deleteRoute() {
        routeService.deleteRoute(route)
        presentationMode.wrappedValue.dismiss()
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Waypoint Row

struct WaypointRow: View {
    let index: Int
    let waypoint: RouteWaypoint
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 28, height: 28)
                .background(color)
                .cornerRadius(14)

            VStack(alignment: .leading, spacing: 2) {
                Text(waypoint.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                if let instruction = waypoint.instruction {
                    Text(instruction)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            if let distance = waypoint.distanceToNext {
                Text(formatDistance(distance))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(hex: "#333333"))
        .cornerRadius(8)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }
}

// MARK: - Route Creator View

struct RouteCreatorView: View {
    @ObservedObject var routeService = RoutePlanningService.shared
    @ObservedObject var locationManager = LocationManager.shared
    @State private var routeName = ""
    @State private var selectedColor: RouteColorPreset = .orange
    @State private var waypoints: [RouteWaypoint] = []
    @State private var showWaypointPicker = false
    @State private var editingWaypointIndex: Int? = nil
    @Environment(\.presentationMode) var presentationMode

    // ATAK-style route styling options
    @State private var lineStyle: RouteLineStyle = .solid
    @State private var lineOpacity: Double = 1.0
    @State private var lineWidth: Double = 4.0
    @State private var waypointIconStyle: WaypointIconStyle = .numbered
    @State private var waypointPrefix: String = ""
    @State private var showDirectionArrows: Bool = false
    @State private var showAdvancedStyling: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Route Name
                    TextField("Route Name", text: $routeName)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .background(Color(hex: "#333333"))
                        .cornerRadius(8)
                        .foregroundColor(.white)

                    // Color Picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(RouteColorPreset.allCases, id: \.self) { color in
                                Button(action: { selectedColor = color }) {
                                    Circle()
                                        .fill(color.swiftUIColor)
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 2)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // ATAK-Style Route Styling Options
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: { withAnimation { showAdvancedStyling.toggle() } }) {
                            HStack {
                                Text("ROUTE STYLING")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.gray)
                                Spacer()
                                Image(systemName: showAdvancedStyling ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }

                        if showAdvancedStyling {
                            VStack(spacing: 12) {
                                // Line Style
                                HStack {
                                    Text("Line Style")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Picker("", selection: $lineStyle) {
                                        ForEach(RouteLineStyle.allCases, id: \.self) { style in
                                            Text(style.displayName).tag(style)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .frame(width: 180)
                                }

                                // Line Width
                                HStack {
                                    Text("Line Width")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(Int(lineWidth))pt")
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.gray)
                                        .frame(width: 40)
                                }
                                Slider(value: $lineWidth, in: 2...10, step: 1)
                                    .accentColor(selectedColor.swiftUIColor)

                                // Line Opacity
                                HStack {
                                    Text("Opacity")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(Int(lineOpacity * 100))%")
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.gray)
                                        .frame(width: 50)
                                }
                                Slider(value: $lineOpacity, in: 0.2...1.0, step: 0.1)
                                    .accentColor(selectedColor.swiftUIColor)

                                Divider()
                                    .background(Color.gray.opacity(0.3))

                                // Waypoint Icon Style
                                HStack {
                                    Text("Waypoint Style")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Menu {
                                        ForEach(WaypointIconStyle.allCases, id: \.self) { style in
                                            Button(action: { waypointIconStyle = style }) {
                                                Label(style.displayName, systemImage: style.icon)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: waypointIconStyle.icon)
                                            Text(waypointIconStyle.displayName)
                                        }
                                        .font(.system(size: 13))
                                        .foregroundColor(selectedColor.swiftUIColor)
                                    }
                                }

                                // Waypoint Prefix
                                HStack {
                                    Text("Prefix")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                    Spacer()
                                    TextField("e.g. WP-", text: $waypointPrefix)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .padding(6)
                                        .background(Color(hex: "#333333"))
                                        .cornerRadius(4)
                                        .foregroundColor(.white)
                                        .frame(width: 100)
                                        .multilineTextAlignment(.trailing)
                                }

                                // Direction Arrows Toggle
                                Toggle(isOn: $showDirectionArrows) {
                                    Text("Show Direction Arrows")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                }
                                .toggleStyle(SwitchToggleStyle(tint: selectedColor.swiftUIColor))

                                // Preview
                                HStack(spacing: 8) {
                                    Text("Preview:")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(selectedColor.swiftUIColor.opacity(lineOpacity))
                                        .frame(width: 60, height: lineWidth)
                                    Text(waypointIconStyle.label(for: 0, prefix: waypointPrefix))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(selectedColor.swiftUIColor)
                                        .cornerRadius(8)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding()
                    .background(Color(hex: "#2A2A2A"))
                    .cornerRadius(12)

                    // Waypoints
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("WAYPOINTS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)

                            Spacer()

                            // Add current GPS location button
                            Button(action: addCurrentLocationAsWaypoint) {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                    Text("GPS")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.cyan)
                            }
                            .disabled(locationManager.location == nil)
                            .opacity(locationManager.location == nil ? 0.5 : 1.0)

                            Button(action: { showWaypointPicker = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(Color(hex: "#FFFC00"))
                            }
                        }

                        if waypoints.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("Tap Add to pick waypoints on the map")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                Text("or tap GPS to use your current location")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ForEach(Array(waypoints.enumerated()), id: \.offset) { index, waypoint in
                                HStack(spacing: 8) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 24, height: 24)
                                        .background(selectedColor.swiftUIColor)
                                        .cornerRadius(12)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(waypoint.name)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                        Text(formatCoordinate(waypoint.coordinate))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    // Set to current GPS location button
                                    Button(action: { setWaypointToCurrentLocation(at: index) }) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.cyan)
                                            .frame(width: 28, height: 28)
                                            .background(Color.cyan.opacity(0.2))
                                            .cornerRadius(6)
                                    }
                                    .disabled(locationManager.location == nil)
                                    .opacity(locationManager.location == nil ? 0.5 : 1.0)

                                    Button(action: { removeWaypoint(at: index) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red.opacity(0.7))
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                    .padding()
                    .background(Color(hex: "#2A2A2A"))
                    .cornerRadius(12)

                    Spacer()

                    // Create Button
                    Button(action: createRoute) {
                        Text("Create Route")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canCreate ? Color(hex: "#FFFC00") : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(!canCreate)

                    if !canCreate && !routeName.isEmpty {
                        Text("Add at least 2 waypoints to create a route")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }
                .padding()
            }
            .navigationTitle("New Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
        .sheet(isPresented: $showWaypointPicker) {
            WaypointPickerView(
                existingWaypoints: waypoints,
                routeColor: selectedColor.swiftUIColor
            ) { coordinate, name in
                addWaypoint(at: coordinate, name: name)
            }
        }
    }

    private var canCreate: Bool {
        !routeName.isEmpty && waypoints.count >= 2
    }

    private func addWaypoint(at coordinate: CLLocationCoordinate2D, name: String) {
        let waypoint = RouteWaypoint(
            coordinate: coordinate,
            name: name,
            order: waypoints.count
        )
        waypoints.append(waypoint)
    }

    private func removeWaypoint(at index: Int) {
        waypoints.remove(at: index)
        // Reorder
        for i in 0..<waypoints.count {
            waypoints[i].order = i
        }
    }

    private func addCurrentLocationAsWaypoint() {
        guard let location = locationManager.location else { return }

        let waypointNumber = waypoints.count + 1
        let waypoint = RouteWaypoint(
            coordinate: location.coordinate,
            name: "Current Location \(waypointNumber)",
            order: waypoints.count
        )
        waypoints.append(waypoint)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func setWaypointToCurrentLocation(at index: Int) {
        guard let location = locationManager.location,
              index < waypoints.count else { return }

        // Update the waypoint's coordinates to current GPS location
        waypoints[index].latitude = location.coordinate.latitude
        waypoints[index].longitude = location.coordinate.longitude

        // Update the name to indicate it's based on current location
        if !waypoints[index].name.contains("(GPS)") {
            waypoints[index].name = "\(waypoints[index].name) (GPS)"
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func createRoute() {
        _ = routeService.createRoute(
            name: routeName,
            waypoints: waypoints,
            color: selectedColor.rawValue,
            lineStyle: lineStyle,
            lineOpacity: lineOpacity,
            lineWidth: lineWidth,
            waypointIconStyle: waypointIconStyle,
            waypointPrefix: waypointPrefix,
            showDirectionArrows: showDirectionArrows
        )
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        presentationMode.wrappedValue.dismiss()
    }

    private func formatCoordinate(_ coord: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
    }
}

// MARK: - Waypoint Picker View

struct WaypointPickerView: View {
    let existingWaypoints: [RouteWaypoint]
    let routeColor: Color
    let onWaypointSelected: (CLLocationCoordinate2D, String) -> Void

    @ObservedObject var locationManager = LocationManager.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var waypointName = ""
    @State private var showNameInput = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                // Map
                Map(coordinateRegion: $region, annotationItems: existingWaypoints) { waypoint in
                    MapAnnotation(coordinate: waypoint.coordinate) {
                        VStack(spacing: 2) {
                            Text("\(waypoint.order + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 20, height: 20)
                                .background(routeColor)
                                .cornerRadius(10)
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 8))
                                .foregroundColor(routeColor)
                                .offset(y: -4)
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                // Center crosshair for picking location
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(Color(hex: "#FFFC00"))
                            Circle()
                                .fill(Color(hex: "#FFFC00").opacity(0.3))
                                .frame(width: 12, height: 12)
                        }
                        Spacer()
                    }
                    Spacer()
                }

                // Bottom panel
                VStack {
                    Spacer()

                    VStack(spacing: 12) {
                        if showNameInput {
                            TextField("Waypoint name", text: $waypointName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding()
                                .background(Color(hex: "#333333"))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Selected Location")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                Text(formatCoordinate(region.center))
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            Button(action: confirmWaypoint) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text(showNameInput ? "Add Waypoint" : "Set Location")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(hex: "#FFFC00"))
                                .cornerRadius(8)
                            }
                        }

                        Text("Pan the map to position the crosshair at your desired waypoint location")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color(hex: "#1E1E1E"))
                    .cornerRadius(16, corners: [.topLeft, .topRight])
                }
            }
            .navigationTitle("Add Waypoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: centerOnCurrentLocation) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.cyan)
                    }
                    .disabled(locationManager.location == nil)
                }
            }
        }
        .onAppear {
            // Center on user location if available, otherwise use existing waypoints or default
            if let lastWaypoint = existingWaypoints.last {
                region.center = lastWaypoint.coordinate
            }
        }
    }

    private func confirmWaypoint() {
        if showNameInput {
            let name = waypointName.isEmpty ? "Waypoint \(existingWaypoints.count + 1)" : waypointName
            onWaypointSelected(region.center, name)
            dismiss()
        } else {
            showNameInput = true
            waypointName = "Waypoint \(existingWaypoints.count + 1)"
        }
    }

    private func formatCoordinate(_ coord: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
    }

    private func centerOnCurrentLocation() {
        guard let location = locationManager.location else { return }
        withAnimation {
            region.center = location.coordinate
        }
    }
}


// MARK: - Route Button

struct RouteButton: View {
    @ObservedObject var routeService = RoutePlanningService.shared
    @State private var showRouteList = false

    var body: some View {
        Button(action: { showRouteList = true }) {
            ZStack {
                Circle()
                    .fill(routeService.activeRoute != nil ? Color.orange.opacity(0.3) : Color.black.opacity(0.6))
                    .frame(width: 56, height: 56)

                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(routeService.activeRoute != nil ? .orange : .white)

                if routeService.activeRoute != nil {
                    Circle()
                        .stroke(Color.orange, lineWidth: 2)
                        .frame(width: 56, height: 56)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showRouteList) {
            RouteListView()
        }
    }
}
