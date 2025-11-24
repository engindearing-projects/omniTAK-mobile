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
                                    .fill(route.swiftUIColor)
                                    .frame(width: 16, height: 16)

                                Text(route.name)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)

                                Spacer()
                            }

                            HStack(spacing: 30) {
                                StatItem(title: "Distance", value: formatDistance(route.totalDistance))
                                StatItem(title: "Waypoints", value: "\(route.waypoints.count)")
                                StatItem(title: "Est. Time", value: formatTime(route.estimatedTime))
                            }
                        }
                        .padding()
                        .background(Color(hex: "#2A2A2A"))
                        .cornerRadius(12)

                        // Waypoints List
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WAYPOINTS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)

                            ForEach(Array(route.waypoints.enumerated()), id: \.offset) { index, waypoint in
                                WaypointRow(index: index + 1, waypoint: waypoint, color: route.swiftUIColor)
                            }
                        }

                        // Actions
                        VStack(spacing: 12) {
                            Button(action: activateRoute) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text(routeService.activeRoute?.id == route.id ? "Route Active" : "Start Navigation")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "#FFFC00"))
                                .cornerRadius(10)
                            }

                            Button(action: shareRoute) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share Route")
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
    }

    private func activateRoute() {
        routeService.activeRoute = route
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func shareRoute() {
        // Share route via activity controller
        // This would typically be handled via a sheet
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
    @State private var routeName = ""
    @State private var selectedColor: RouteColorPreset = .orange
    @State private var waypoints: [RouteWaypoint] = []
    @Environment(\.presentationMode) var presentationMode

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

                    // Waypoints
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("WAYPOINTS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)

                            Spacer()

                            Button(action: addWaypoint) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Color(hex: "#FFFC00"))
                            }
                        }

                        if waypoints.isEmpty {
                            Text("Tap + to add waypoints")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            ForEach(Array(waypoints.enumerated()), id: \.offset) { index, waypoint in
                                HStack {
                                    Text("\(index + 1). \(waypoint.name)")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button(action: { removeWaypoint(at: index) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.vertical, 8)
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
    }

    private var canCreate: Bool {
        !routeName.isEmpty && waypoints.count >= 2
    }

    private func addWaypoint() {
        // In real implementation, would show map to pick location
        let waypoint = RouteWaypoint(
            coordinate: CLLocationCoordinate2D(latitude: 38.8977 + Double.random(in: -0.01...0.01),
                                               longitude: -77.0365 + Double.random(in: -0.01...0.01)),
            name: "Waypoint \(waypoints.count + 1)",
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

    private func createRoute() {
        _ = routeService.createRoute(name: routeName, waypoints: waypoints, color: selectedColor.rawValue)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        presentationMode.wrappedValue.dismiss()
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
