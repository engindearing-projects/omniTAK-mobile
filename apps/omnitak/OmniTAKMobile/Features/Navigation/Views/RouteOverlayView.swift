//
//  RouteOverlayView.swift
//  OmniTAKMobile
//
//  Route display overlay for showing active navigation on the map
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Route Polyline

/// Custom polyline for route display with styling
class RoutePolyline: MKPolyline {
    var routeId: UUID?
    var routeColor: UIColor = .systemBlue
    var lineWidth: CGFloat = 6.0
    var isActive: Bool = false
    var segmentIndex: Int = 0

    // ATAK-style styling properties
    var lineStyle: RouteLineStyle = .solid
    var lineOpacity: CGFloat = 1.0
    var showDirectionArrows: Bool = false
}

// MARK: - Route Polyline Renderer

class RoutePolylineRenderer: MKPolylineRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let routePolyline = polyline as? RoutePolyline else {
            super.draw(mapRect, zoomScale: zoomScale, in: context)
            return
        }

        // Set line properties with opacity
        strokeColor = routePolyline.routeColor.withAlphaComponent(routePolyline.lineOpacity)
        lineWidth = routePolyline.lineWidth
        lineCap = .round
        lineJoin = .round

        // Apply line style (dash pattern)
        if let dashPattern = routePolyline.lineStyle.dashPattern {
            // Scale dash pattern based on zoom
            let scaledPattern = dashPattern.map { NSNumber(value: $0.doubleValue / Double(zoomScale)) }
            lineDashPattern = scaledPattern
        } else {
            lineDashPattern = nil
        }

        // Add glow effect for active route
        if routePolyline.isActive {
            // Draw outer glow
            context.saveGState()
            let glowColor = routePolyline.routeColor.withAlphaComponent(0.3 * routePolyline.lineOpacity)
            context.setShadow(offset: .zero, blur: 8.0 / zoomScale, color: glowColor.cgColor)
            super.draw(mapRect, zoomScale: zoomScale, in: context)
            context.restoreGState()
        }

        // Draw main line
        super.draw(mapRect, zoomScale: zoomScale, in: context)

        // Draw direction arrows if enabled
        if routePolyline.showDirectionArrows {
            drawDirectionArrows(mapRect: mapRect, zoomScale: zoomScale, context: context, polyline: routePolyline)
        }
    }

    /// Draw direction arrows along the polyline
    private func drawDirectionArrows(mapRect: MKMapRect, zoomScale: MKZoomScale, context: CGContext, polyline: RoutePolyline) {
        let path = self.path
        guard let path = path else { return }

        // Get points along the path
        let pointCount = polyline.pointCount
        guard pointCount >= 2 else { return }

        // Calculate arrow interval based on zoom
        let arrowInterval: Int = max(5, Int(Double(pointCount) * 0.1)) // Every 10% of points

        context.saveGState()
        context.setFillColor(polyline.routeColor.withAlphaComponent(polyline.lineOpacity).cgColor)

        for i in stride(from: arrowInterval, to: pointCount - 1, by: arrowInterval) {
            let currentPoint = self.point(for: polyline.points()[i])
            let nextPoint = self.point(for: polyline.points()[min(i + 1, pointCount - 1)])

            // Calculate angle
            let angle = atan2(nextPoint.y - currentPoint.y, nextPoint.x - currentPoint.x)

            // Draw arrow at current point
            let arrowSize: CGFloat = 8.0 / zoomScale

            context.saveGState()
            context.translateBy(x: currentPoint.x, y: currentPoint.y)
            context.rotate(by: angle)

            // Arrow shape
            let arrowPath = CGMutablePath()
            arrowPath.move(to: CGPoint(x: arrowSize, y: 0))
            arrowPath.addLine(to: CGPoint(x: -arrowSize / 2, y: -arrowSize / 2))
            arrowPath.addLine(to: CGPoint(x: -arrowSize / 2, y: arrowSize / 2))
            arrowPath.closeSubpath()

            context.addPath(arrowPath)
            context.fillPath()
            context.restoreGState()
        }

        context.restoreGState()
    }
}

// MARK: - Breadcrumb Trail Polyline (ATAK-style)

/// Custom polyline for breadcrumb trail display during navigation
class BreadcrumbPolyline: MKPolyline {
    var trailColor: UIColor = .cyan
    var lineWidth: CGFloat = 3.0
}

/// Renderer for breadcrumb trail with dashed line style
class BreadcrumbPolylineRenderer: MKPolylineRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let breadcrumbPolyline = polyline as? BreadcrumbPolyline else {
            super.draw(mapRect, zoomScale: zoomScale, in: context)
            return
        }

        // Set breadcrumb trail properties
        strokeColor = breadcrumbPolyline.trailColor
        lineWidth = breadcrumbPolyline.lineWidth
        lineCap = .round
        lineJoin = .round

        // Dashed line style for breadcrumb trail (ATAK-style)
        let dashPattern: [CGFloat] = [8.0 / zoomScale, 4.0 / zoomScale]
        lineDashPattern = dashPattern.map { NSNumber(value: Double($0)) }

        // Draw the dashed line
        super.draw(mapRect, zoomScale: zoomScale, in: context)
    }
}

// MARK: - Self-Healing Route Polylines (ATAK-style)

/// Polyline for the remaining (active) portion of the route
class RemainingRoutePolyline: MKPolyline {
    var routeColor: UIColor = .systemYellow
    var lineWidth: CGFloat = 6.0
}

/// Polyline for the completed portion of the route (faded)
class CompletedRoutePolyline: MKPolyline {
    var routeColor: UIColor = .gray
    var lineWidth: CGFloat = 4.0
}

/// Polyline for the healing connector from current position to route
class HealingConnectorPolyline: MKPolyline {
    var routeColor: UIColor = .systemYellow
    var lineWidth: CGFloat = 4.0
}

/// Renderer for remaining route with glow effect
class RemainingRouteRenderer: MKPolylineRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let remainingPolyline = polyline as? RemainingRoutePolyline else {
            super.draw(mapRect, zoomScale: zoomScale, in: context)
            return
        }

        strokeColor = remainingPolyline.routeColor
        lineWidth = remainingPolyline.lineWidth
        lineCap = .round
        lineJoin = .round

        // Add glow effect for active route
        context.saveGState()
        let glowColor = remainingPolyline.routeColor.withAlphaComponent(0.4)
        context.setShadow(offset: .zero, blur: 10.0 / zoomScale, color: glowColor.cgColor)
        super.draw(mapRect, zoomScale: zoomScale, in: context)
        context.restoreGState()

        // Draw main line
        super.draw(mapRect, zoomScale: zoomScale, in: context)
    }
}

/// Renderer for completed route portion (faded, dashed)
class CompletedRouteRenderer: MKPolylineRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let completedPolyline = polyline as? CompletedRoutePolyline else {
            super.draw(mapRect, zoomScale: zoomScale, in: context)
            return
        }

        strokeColor = completedPolyline.routeColor.withAlphaComponent(0.4)
        lineWidth = completedPolyline.lineWidth
        lineCap = .round
        lineJoin = .round

        // Dashed style for completed portion
        let dashPattern: [CGFloat] = [6.0 / zoomScale, 4.0 / zoomScale]
        lineDashPattern = dashPattern.map { NSNumber(value: Double($0)) }

        super.draw(mapRect, zoomScale: zoomScale, in: context)
    }
}

/// Renderer for healing connector (animated dashed line)
class HealingConnectorRenderer: MKPolylineRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let connectorPolyline = polyline as? HealingConnectorPolyline else {
            super.draw(mapRect, zoomScale: zoomScale, in: context)
            return
        }

        strokeColor = connectorPolyline.routeColor.withAlphaComponent(0.8)
        lineWidth = connectorPolyline.lineWidth
        lineCap = .round
        lineJoin = .round

        // Dotted line for connector
        let dashPattern: [CGFloat] = [4.0 / zoomScale, 4.0 / zoomScale]
        lineDashPattern = dashPattern.map { NSNumber(value: Double($0)) }

        super.draw(mapRect, zoomScale: zoomScale, in: context)
    }
}

// MARK: - Route Navigation Panel (ATAK-Style)

struct RouteNavigationPanel: View {
    @ObservedObject var routeService: RoutePlanningService
    @Binding var isExpanded: Bool
    @State private var isFlashing: Bool = false

    private let flashTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        if let route = routeService.activeRoute, routeService.isNavigating {
            VStack(spacing: 4) {
                // Off-route warning banner (ATAK-style)
                if routeService.isOffRoute {
                    offRouteBanner
                }

                VStack(spacing: 0) {
                    // ATAK-style header with controls
                    atakHeaderView(route: route)

                    if isExpanded {
                        // Expanded details
                        atakExpandedContent(route: route)
                    }
                }
                .background(alertBackgroundColor.opacity(isFlashing && routeService.proximityAlert.shouldFlash ? 0.9 : 1.0))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
            }
            .onReceive(flashTimer) { _ in
                if routeService.proximityAlert.shouldFlash || routeService.isOffRoute {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isFlashing.toggle()
                    }
                } else {
                    isFlashing = false
                }
            }
        }
    }

    // MARK: - Off-Route Warning Banner

    private var offRouteBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)

            VStack(alignment: .leading, spacing: 1) {
                Text("OFF ROUTE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)

                Text("\(Int(routeService.offRouteDistance))m from route")
                    .font(.system(size: 10))
                    .foregroundColor(.black.opacity(0.8))
            }

            Spacer()

            // Reroute button
            Button(action: { routeService.recalculateRouteFromCurrentPosition() }) {
                Text("Reroute")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            isFlashing ? Color.orange : Color.yellow
        )
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    // MARK: - ATAK-Style Header

    private func atakHeaderView(route: Route) -> some View {
        VStack(spacing: 0) {
            // Top row: Navigation controls
            HStack(spacing: 8) {
                // Previous waypoint button
                Button(action: { routeService.skipToPreviousWaypoint() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(canGoPrevious ? .white : .gray.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(6)
                }
                .disabled(!canGoPrevious)

                // Checkpoint counter
                Text(checkpointText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                // Next waypoint button
                Button(action: { routeService.skipToNextWaypoint() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(canGoNext ? .white : .gray.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(6)
                }
                .disabled(!canGoNext)

                Spacer()

                // Mute button
                Button(action: { routeService.toggleMute() }) {
                    Image(systemName: routeService.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(routeService.isMuted ? .orange : .white)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(6)
                }

                // End navigation button
                Button(action: { routeService.stopNavigation() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            // Main instruction row
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                HStack(spacing: 10) {
                    // Direction icon
                    Image(systemName: currentDirectionIcon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(alertIconColor)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 2) {
                        // Current instruction
                        Text(routeService.routeProgress?.currentInstruction ?? "Navigating...")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        // Distance and time to next
                        HStack(spacing: 6) {
                            Text(routeService.routeProgress?.formattedDistanceToNext ?? "--")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(alertIconColor)

                            Text("•")
                                .foregroundColor(.white.opacity(0.5))

                            Text(routeService.routeProgress?.formattedTimeToNext ?? "--")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Spacer()

                    // Expand/collapse chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - ATAK-Style Expanded Content

    private func atakExpandedContent(route: Route) -> some View {
        VStack(spacing: 8) {
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 10)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(alertIconColor)
                        .frame(width: geo.size.width * CGFloat((routeService.routeProgress?.percentComplete ?? 0) / 100), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 10)

            // Stats row
            HStack(spacing: 0) {
                statItem(icon: "speedometer", value: formattedSpeed, label: "Speed")
                statItem(icon: "arrow.triangle.swap", value: routeService.routeProgress?.formattedDistanceRemaining ?? "--", label: "Remaining")
                statItem(icon: "clock", value: routeService.routeProgress?.formattedTimeRemaining ?? "--", label: "Time")
                statItem(icon: "flag.checkered", value: routeService.routeProgress?.formattedETA ?? "--", label: "ETA")
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Helper Views

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed Properties

    private var checkpointText: String {
        guard let route = routeService.activeRoute,
              let progress = routeService.routeProgress else {
            return "Checkpoint -- of --"
        }
        let current = progress.currentWaypointIndex + 1
        let total = route.waypoints.count
        return "Checkpoint \(current) of \(total)"
    }

    private var canGoPrevious: Bool {
        guard let progress = routeService.routeProgress else { return false }
        return progress.currentWaypointIndex > 0
    }

    private var canGoNext: Bool {
        guard let route = routeService.activeRoute,
              let progress = routeService.routeProgress else { return false }
        return progress.currentWaypointIndex < route.waypoints.count - 1
    }

    private var formattedSpeed: String {
        let speedKmh = routeService.currentSpeed * 3.6 // Convert m/s to km/h
        if speedKmh < 1 {
            return "0 km/h"
        }
        return String(format: "%.0f km/h", speedKmh)
    }

    private var alertBackgroundColor: Color {
        switch routeService.proximityAlert {
        case .none, .far:
            return Color(hex: "#1A1A1A")
        case .approaching:
            return Color(hex: "#1A3A1A") // Dark green
        case .near:
            return Color(hex: "#3A3A1A") // Dark yellow
        case .imminent:
            return Color(hex: "#3A1A1A") // Dark red
        case .arrived:
            return Color(hex: "#1A3A1A") // Dark green
        }
    }

    private var alertIconColor: Color {
        switch routeService.proximityAlert {
        case .none, .far:
            return Color(hex: "#00FF00") // Green
        case .approaching:
            return Color(hex: "#00FF00") // Green
        case .near:
            return Color(hex: "#FFFF00") // Yellow
        case .imminent:
            return Color(hex: "#FF4444") // Red
        case .arrived:
            return Color(hex: "#00FF00") // Green
        }
    }

    private var currentDirectionIcon: String {
        guard let instruction = routeService.routeProgress?.currentInstruction.lowercased() else {
            return "arrow.up"
        }

        if instruction.contains("left") {
            return "arrow.turn.up.left"
        } else if instruction.contains("right") {
            return "arrow.turn.up.right"
        } else if instruction.contains("u-turn") || instruction.contains("uturn") {
            return "arrow.uturn.left"
        } else if instruction.contains("merge") {
            return "arrow.merge"
        } else if instruction.contains("exit") {
            return "arrow.up.right"
        } else if instruction.contains("arrive") || instruction.contains("destination") {
            return "flag.checkered"
        } else {
            return "arrow.up"
        }
    }
}

// MARK: - Route Overlay Coordinator

class RouteOverlayCoordinator: ObservableObject {
    @Published var currentRouteOverlays: [RoutePolyline] = []
    @Published var waypointAnnotations: [RouteWaypointAnnotation] = []
    @Published var breadcrumbOverlay: BreadcrumbPolyline?

    // Self-healing route overlays
    private var remainingRouteOverlay: RemainingRoutePolyline?
    private var completedRouteOverlay: CompletedRoutePolyline?
    private var healingConnectorOverlay: HealingConnectorPolyline?
    private var selfHealingEnabled: Bool = true

    weak var mapView: MKMapView?

    func configure(with mapView: MKMapView) {
        self.mapView = mapView
    }

    // MARK: - Self-Healing Route (ATAK-style)

    /// Update the self-healing route display during active navigation
    /// This shows the remaining route from current position, with completed portion faded
    func updateSelfHealingRoute(
        route: Route,
        currentLocation: CLLocationCoordinate2D,
        currentWaypointIndex: Int
    ) {
        guard let mapView = mapView, selfHealingEnabled else { return }

        let allCoordinates = route.allCoordinates
        guard allCoordinates.count >= 2 else { return }

        // Find closest point on route to current location
        let (closestIndex, closestPoint) = findClosestPointOnRoute(
            location: currentLocation,
            coordinates: allCoordinates
        )

        // Clear existing self-healing overlays
        clearSelfHealingOverlays()

        // 1. Create completed portion (from start to closest point) - faded
        if closestIndex > 0 {
            var completedCoords = Array(allCoordinates[0...closestIndex])
            completedCoords.append(closestPoint) // Include the closest point

            let completedPolyline = CompletedRoutePolyline(coordinates: &completedCoords, count: completedCoords.count)
            completedPolyline.routeColor = route.uiColor
            completedPolyline.lineWidth = 4.0

            completedRouteOverlay = completedPolyline
            mapView.addOverlay(completedPolyline, level: .aboveRoads)
        }

        // 2. Create healing connector (from current location to closest point on route)
        let currentLoc = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let closestLoc = CLLocation(latitude: closestPoint.latitude, longitude: closestPoint.longitude)
        let distanceToRoute = currentLoc.distance(from: closestLoc)

        // Only show connector if user is more than 5 meters from route
        if distanceToRoute > 5 {
            var connectorCoords = [currentLocation, closestPoint]
            let connectorPolyline = HealingConnectorPolyline(coordinates: &connectorCoords, count: connectorCoords.count)
            connectorPolyline.routeColor = route.uiColor
            connectorPolyline.lineWidth = 4.0

            healingConnectorOverlay = connectorPolyline
            mapView.addOverlay(connectorPolyline, level: .aboveRoads)
        }

        // 3. Create remaining portion (from closest point to end) - active/bright
        if closestIndex < allCoordinates.count - 1 {
            var remainingCoords = [closestPoint]
            remainingCoords.append(contentsOf: allCoordinates[(closestIndex + 1)...])

            let remainingPolyline = RemainingRoutePolyline(coordinates: &remainingCoords, count: remainingCoords.count)
            remainingPolyline.routeColor = route.uiColor
            remainingPolyline.lineWidth = 6.0

            remainingRouteOverlay = remainingPolyline
            mapView.addOverlay(remainingPolyline, level: .aboveRoads)
        }

        // Update waypoint annotations to show which are completed
        updateWaypointAnnotationsForProgress(route: route, currentWaypointIndex: currentWaypointIndex)
    }

    /// Find the closest point on the route polyline to a given location
    private func findClosestPointOnRoute(
        location: CLLocationCoordinate2D,
        coordinates: [CLLocationCoordinate2D]
    ) -> (index: Int, point: CLLocationCoordinate2D) {
        let currentLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)

        var closestDistance = Double.greatestFiniteMagnitude
        var closestIndex = 0
        var closestPoint = coordinates[0]

        for i in 0..<(coordinates.count - 1) {
            let segmentStart = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let segmentEnd = CLLocation(latitude: coordinates[i + 1].latitude, longitude: coordinates[i + 1].longitude)

            // Find closest point on this segment
            let (point, distance) = closestPointOnSegment(
                from: currentLoc,
                segmentStart: segmentStart,
                segmentEnd: segmentEnd
            )

            if distance < closestDistance {
                closestDistance = distance
                closestIndex = i
                closestPoint = point
            }
        }

        return (closestIndex, closestPoint)
    }

    /// Calculate closest point on a line segment
    private func closestPointOnSegment(
        from point: CLLocation,
        segmentStart: CLLocation,
        segmentEnd: CLLocation
    ) -> (CLLocationCoordinate2D, Double) {
        let px = point.coordinate.latitude
        let py = point.coordinate.longitude
        let ax = segmentStart.coordinate.latitude
        let ay = segmentStart.coordinate.longitude
        let bx = segmentEnd.coordinate.latitude
        let by = segmentEnd.coordinate.longitude

        let dx = bx - ax
        let dy = by - ay

        if dx == 0 && dy == 0 {
            return (segmentStart.coordinate, point.distance(from: segmentStart))
        }

        let t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))

        let closestLat = ax + t * dx
        let closestLon = ay + t * dy
        let closestCoord = CLLocationCoordinate2D(latitude: closestLat, longitude: closestLon)
        let closestLoc = CLLocation(latitude: closestLat, longitude: closestLon)

        return (closestCoord, point.distance(from: closestLoc))
    }

    /// Update waypoint annotations to reflect progress
    private func updateWaypointAnnotationsForProgress(route: Route, currentWaypointIndex: Int) {
        // Update existing annotations to show completed status
        for annotation in waypointAnnotations {
            if let view = mapView?.view(for: annotation) {
                let waypointOrder = annotation.waypoint.order
                if waypointOrder < currentWaypointIndex {
                    // Completed waypoint - fade it
                    view.alpha = 0.5
                } else if waypointOrder == currentWaypointIndex {
                    // Current target - highlight it
                    view.alpha = 1.0
                    view.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                } else {
                    // Future waypoint - normal
                    view.alpha = 0.8
                    view.transform = .identity
                }
            }
        }
    }

    /// Clear self-healing route overlays
    func clearSelfHealingOverlays() {
        guard let mapView = mapView else { return }

        if let overlay = remainingRouteOverlay {
            mapView.removeOverlay(overlay)
            remainingRouteOverlay = nil
        }
        if let overlay = completedRouteOverlay {
            mapView.removeOverlay(overlay)
            completedRouteOverlay = nil
        }
        if let overlay = healingConnectorOverlay {
            mapView.removeOverlay(overlay)
            healingConnectorOverlay = nil
        }
    }

    /// Enable or disable self-healing route display
    func setSelfHealingEnabled(_ enabled: Bool) {
        selfHealingEnabled = enabled
        if !enabled {
            clearSelfHealingOverlays()
        }
    }

    // MARK: - Breadcrumb Trail (ATAK-style)

    /// Update the breadcrumb trail overlay with new coordinates
    func updateBreadcrumbTrail(coordinates: [CLLocationCoordinate2D]) {
        guard let mapView = mapView, coordinates.count >= 2 else { return }

        // Remove existing breadcrumb overlay
        if let existing = breadcrumbOverlay {
            mapView.removeOverlay(existing)
        }

        // Create new breadcrumb polyline
        var coords = coordinates
        let polyline = BreadcrumbPolyline(coordinates: &coords, count: coords.count)
        polyline.trailColor = UIColor.cyan.withAlphaComponent(0.8)
        polyline.lineWidth = 3.0

        breadcrumbOverlay = polyline
        mapView.addOverlay(polyline, level: .aboveRoads)
    }

    /// Clear the breadcrumb trail
    func clearBreadcrumbTrail() {
        guard let mapView = mapView, let overlay = breadcrumbOverlay else { return }
        mapView.removeOverlay(overlay)
        breadcrumbOverlay = nil
    }

    /// Display a route on the map
    func displayRoute(_ route: Route, isActive: Bool = false) {
        guard let mapView = mapView else { return }

        // Remove existing route overlays
        clearRouteOverlays()

        // Get all coordinates
        let coordinates = route.allCoordinates
        guard coordinates.count >= 2 else { return }

        // Create polyline with route styling
        var coords = coordinates
        let polyline = RoutePolyline(coordinates: &coords, count: coords.count)
        polyline.routeId = route.id
        polyline.routeColor = route.uiColor
        polyline.lineWidth = isActive ? CGFloat(route.lineWidth * 1.5) : CGFloat(route.lineWidth)
        polyline.isActive = isActive

        // Apply ATAK-style styling properties
        polyline.lineStyle = route.lineStyle
        polyline.lineOpacity = CGFloat(route.lineOpacity)
        polyline.showDirectionArrows = route.showDirectionArrows

        currentRouteOverlays.append(polyline)
        mapView.addOverlay(polyline, level: .aboveRoads)

        // Add waypoint annotations
        for (index, waypoint) in route.waypoints.enumerated() {
            let annotation = RouteWaypointAnnotation(
                waypoint: waypoint,
                routeColor: route.uiColor,
                isStart: index == 0,
                isEnd: index == route.waypoints.count - 1
            )
            // Store styling info for annotation view rendering
            annotation.waypointIconStyle = route.waypointIconStyle
            annotation.waypointPrefix = route.waypointPrefix
            waypointAnnotations.append(annotation)
            mapView.addAnnotation(annotation)
        }

        // Zoom to fit route
        if let region = route.boundingRegion {
            mapView.setRegion(region, animated: true)
        }
    }

    /// Clear all route overlays
    func clearRouteOverlays() {
        guard let mapView = mapView else { return }

        // Remove polylines
        mapView.removeOverlays(currentRouteOverlays)
        currentRouteOverlays.removeAll()

        // Remove self-healing overlays
        clearSelfHealingOverlays()

        // Remove annotations
        mapView.removeAnnotations(waypointAnnotations)
        waypointAnnotations.removeAll()
    }

    /// Get renderer for route overlay
    func renderer(for overlay: MKOverlay) -> MKOverlayRenderer? {
        if let routePolyline = overlay as? RoutePolyline {
            return RoutePolylineRenderer(polyline: routePolyline)
        }
        if let breadcrumbPolyline = overlay as? BreadcrumbPolyline {
            return BreadcrumbPolylineRenderer(polyline: breadcrumbPolyline)
        }
        // Self-healing route renderers
        if let remainingPolyline = overlay as? RemainingRoutePolyline {
            return RemainingRouteRenderer(polyline: remainingPolyline)
        }
        if let completedPolyline = overlay as? CompletedRoutePolyline {
            return CompletedRouteRenderer(polyline: completedPolyline)
        }
        if let connectorPolyline = overlay as? HealingConnectorPolyline {
            return HealingConnectorRenderer(polyline: connectorPolyline)
        }
        return nil
    }

    /// Get annotation view for route waypoint
    func annotationView(for annotation: MKAnnotation, mapView: MKMapView) -> MKAnnotationView? {
        guard let waypointAnnotation = annotation as? RouteWaypointAnnotation else {
            return nil
        }

        let identifier = "RouteWaypoint"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }

        // Create waypoint marker image
        let size: CGFloat = waypointAnnotation.isStart || waypointAnnotation.isEnd ? 32 : 24
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            // Draw circle
            let rect = CGRect(x: 2, y: 2, width: size - 4, height: size - 4)
            ctx.cgContext.setFillColor(waypointAnnotation.routeColor.cgColor)
            ctx.cgContext.fillEllipse(in: rect)

            // Draw border
            ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.strokeEllipse(in: rect)

            // Draw number or icon using ATAK-style display label
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let text: String
            if waypointAnnotation.isStart {
                text = "S"
            } else if waypointAnnotation.isEnd {
                text = "E"
            } else {
                // Use ATAK-style display label based on icon style and prefix
                text = waypointAnnotation.displayLabel
            }

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: size * 0.4),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]

            let textSize = text.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (size - textSize.width) / 2,
                y: (size - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attrs)
        }

        annotationView?.image = image
        annotationView?.centerOffset = CGPoint(x: 0, y: -size / 2)

        return annotationView
    }
}

// MARK: - Route Quick Actions (for route card)

struct RouteQuickActionsView: View {
    let route: Route
    @ObservedObject var routeService: RoutePlanningService
    @ObservedObject var routeOverlayCoordinator: RouteOverlayCoordinator
    @Environment(\.dismiss) var dismiss

    @State private var isCalculating = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 12) {
            // Calculate Directions button
            if route.segments.isEmpty {
                Button(action: calculateDirections) {
                    HStack {
                        if isCalculating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "map.fill")
                        }
                        Text(isCalculating ? "Calculating..." : "Get Directions")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#FFFC00"))
                    .cornerRadius(10)
                }
                .disabled(isCalculating)
            }

            // Start Navigation button
            Button(action: startNavigation) {
                HStack {
                    Image(systemName: "location.fill")
                    Text(routeService.activeRoute?.id == route.id ? "Route Active" : "Start Navigation")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(routeService.activeRoute?.id == route.id ? Color.green : Color.blue)
                .cornerRadius(10)
            }

            // Show on Map button
            Button(action: showOnMap) {
                HStack {
                    Image(systemName: "map")
                    Text("Show on Map")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#FFFC00"))
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "#FFFC00").opacity(0.2))
                .cornerRadius(10)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func calculateDirections() {
        isCalculating = true

        routeService.calculateRouteDirections(for: route) { result in
            DispatchQueue.main.async {
                isCalculating = false

                switch result {
                case .success(let updatedRoute):
                    routeOverlayCoordinator.displayRoute(updatedRoute, isActive: false)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func startNavigation() {
        // Calculate directions first if needed
        if route.segments.isEmpty {
            isCalculating = true
            routeService.calculateRouteDirections(for: route) { result in
                DispatchQueue.main.async {
                    isCalculating = false

                    switch result {
                    case .success(let updatedRoute):
                        routeService.startNavigation(for: updatedRoute)
                        routeOverlayCoordinator.displayRoute(updatedRoute, isActive: true)
                        dismiss()
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        } else {
            routeService.startNavigation(for: route)
            routeOverlayCoordinator.displayRoute(route, isActive: true)
            dismiss()
        }
    }

    private func showOnMap() {
        routeOverlayCoordinator.displayRoute(route, isActive: false)
        dismiss()
    }
}

// Note: formattedDistance extension is defined in WaypointModels.swift
