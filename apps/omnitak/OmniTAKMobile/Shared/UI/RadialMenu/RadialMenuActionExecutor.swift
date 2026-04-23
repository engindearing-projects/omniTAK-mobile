//
//  RadialMenuActionExecutor.swift
//  OmniTAKMobile
//
//  Executes actions selected from the radial menu
//

import Foundation
import CoreLocation
import MapKit
import UIKit

// MARK: - Radial Menu Action Executor

/// Handles execution of radial menu actions with appropriate service calls
class RadialMenuActionExecutor {

    // MARK: - Main Execution

    /// Execute an action with the given context and services
    @discardableResult
    static func execute(
        action: RadialMenuAction,
        context: RadialMenuContext,
        services: RadialMenuServices
    ) -> Bool {
        switch action {
        case .dropMarker(let affiliation):
            return executeDropMarker(affiliation: affiliation, context: context, services: services)
        case .editMarker:
            return executeEditMarker(context: context, services: services)
        case .deleteMarker:
            return executeDeleteMarker(context: context, services: services)
        case .shareMarker:
            return executeShareMarker(context: context, services: services)
        case .navigateToMarker:
            return executeNavigateToMarker(context: context, services: services)
        case .markerInfo:
            return executeMarkerInfo(context: context, services: services)
        case .measure:
            return executeMeasure(context: context, services: services)
        case .measureDistance:
            return executeMeasureDistance(context: context, services: services)
        case .measureArea:
            return executeMeasureArea(context: context, services: services)
        case .measureBearing:
            return executeMeasureBearing(context: context, services: services)
        case .navigate:
            return executeNavigate(context: context, services: services)
        case .addWaypoint:
            return executeAddWaypoint(context: context, services: services)
        case .createRoute:
            return executeCreateRoute(context: context, services: services)
        case .openDrawingTools:
            return executeOpenDrawingTools(context: context)
        case .openDrawingsList:
            return executeOpenDrawingsList(context: context)
        case .drawLine:
            return executeDrawLine(context: context)
        case .drawCircle:
            return executeDrawCircle(context: context)
        case .drawPolygon:
            return executeDrawPolygon(context: context)
        case .editDrawing:
            return executeEditDrawing(context: context, services: services)
        case .deleteDrawing:
            return executeDeleteDrawing(context: context, services: services)
        case .copyCoordinates:
            return executeCopyCoordinates(context: context)
        case .setRangeRings:
            return executeSetRangeRings(context: context, services: services)
        case .centerMap:
            return executeCenterMap(context: context)
        case .quickChat:
            return executeQuickChat(context: context)
        case .emergency:
            return executeEmergency(context: context)
        case .getInfo:
            return executeGetInfo(context: context)
        case .custom(let identifier):
            return executeCustomAction(identifier: identifier, context: context, services: services)
        }
    }

    // MARK: - Marker Drop Implementation

    private static func executeDropMarker(
        affiliation: MarkerAffiliation,
        context: RadialMenuContext,
        services: RadialMenuServices
    ) -> Bool {
        guard let pointDropperService = services.pointDropperService else { return false }

        let marker = pointDropperService.quickDrop(
            at: context.mapCoordinate,
            broadcast: false
        )

        if marker.affiliation != affiliation {
            var updatedMarker = marker
            updatedMarker.affiliation = affiliation
            updatedMarker.cotType = affiliation.cotType
            updatedMarker.iconName = affiliation.iconName
            pointDropperService.updateMarker(updatedMarker)
        }

        NotificationCenter.default.post(
            name: .radialMenuMarkerDropped,
            object: nil,
            userInfo: ["marker": marker, "affiliation": affiliation]
        )

        return true
    }

    // MARK: - Marker Management Implementation

    private static func executeEditMarker(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        // The shared markerContext radial menu is shown both for PointMarkers
        // (radial/point-dropper markers) AND for drawing shapes (marker, line,
        // circle, polygon) — so the Edit action has to dispatch to whichever
        // one was actually long-pressed. Matches the fallthrough already in
        // executeDeleteMarker.
        if let marker = context.pressedMarker {
            NotificationCenter.default.post(
                name: .radialMenuEditMarker,
                object: nil,
                userInfo: ["marker": marker]
            )
            return true
        }

        if let drawingId = context.pressedDrawingId,
           let drawingType = context.pressedDrawingType {
            NotificationCenter.default.post(
                name: .radialMenuEditDrawing,
                object: nil,
                userInfo: ["drawingId": drawingId, "drawingType": drawingType]
            )
            return true
        }

        return false
    }

    private static func executeDeleteMarker(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        if context.contextType == .drawing,
           let drawingId = context.pressedDrawingId,
           let drawingType = context.pressedDrawingType,
           let drawingStore = services.drawingStore {

            switch drawingType {
            case .marker:
                if let marker = drawingStore.markers.first(where: { $0.id == drawingId }) {
                    drawingStore.deleteMarker(marker)
                }
            case .line:
                if let line = drawingStore.lines.first(where: { $0.id == drawingId }) {
                    drawingStore.deleteLine(line)
                }
            case .circle:
                if let circle = drawingStore.circles.first(where: { $0.id == drawingId }) {
                    drawingStore.deleteCircle(circle)
                }
            case .polygon:
                if let polygon = drawingStore.polygons.first(where: { $0.id == drawingId }) {
                    drawingStore.deletePolygon(polygon)
                }
            }

            NotificationCenter.default.post(
                name: .radialMenuDrawingDeleted,
                object: nil,
                userInfo: ["drawingId": drawingId, "drawingType": drawingType]
            )

            return true
        }

        guard let marker = context.pressedMarker,
              let pointDropperService = services.pointDropperService else { return false }

        pointDropperService.deleteMarker(marker)

        NotificationCenter.default.post(
            name: .radialMenuMarkerDeleted,
            object: nil,
            userInfo: ["marker": marker]
        )

        return true
    }

    private static func executeShareMarker(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let marker = context.pressedMarker else { return false }

        let shareText = generateShareText(for: marker)
        UIPasteboard.general.string = shareText

        NotificationCenter.default.post(
            name: .radialMenuShareMarker,
            object: nil,
            userInfo: ["marker": marker, "shareText": shareText]
        )

        return true
    }

    private static func executeNavigateToMarker(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let routePlanningService = services.routePlanningService else { return false }

        // Get target coordinate and name
        let targetCoordinate: CLLocationCoordinate2D
        let targetName: String

        if let marker = context.pressedMarker {
            targetCoordinate = marker.coordinate
            targetName = marker.name
        } else if let waypoint = context.pressedWaypoint {
            targetCoordinate = waypoint.coordinate
            targetName = waypoint.name
        } else {
            targetCoordinate = context.mapCoordinate
            targetName = "Selected Location"
        }

        // Get current location for start point
        guard let currentLocation = routePlanningService.currentLocation else {
            // Fall back to posting notification to show route planning UI
            NotificationCenter.default.post(
                name: .radialMenuNavigationStarted,
                object: nil,
                userInfo: ["destination": targetCoordinate, "destinationName": targetName]
            )
            return true
        }

        // Create quick 2-point route from current location to target
        let startWaypoint = RouteWaypoint(
            coordinate: currentLocation.coordinate,
            name: "Current Location",
            order: 0,
            instruction: "Start navigation"
        )

        let endWaypoint = RouteWaypoint(
            coordinate: targetCoordinate,
            name: targetName,
            order: 1,
            instruction: "Arrive at \(targetName)"
        )

        // Create and start navigation route
        let route = routePlanningService.createRoute(
            name: "Navigate to \(targetName)",
            waypoints: [startWaypoint, endWaypoint],
            color: "#4CAF50",  // Green for navigation route
            lineStyle: .solid,
            lineOpacity: 0.9,
            lineWidth: 5.0,
            waypointIconStyle: .numbered,
            waypointPrefix: "",
            showDirectionArrows: true
        )

        // Start navigation on this route
        routePlanningService.startNavigation(for: route)

        NotificationCenter.default.post(
            name: .radialMenuNavigationStarted,
            object: nil,
            userInfo: ["route": route, "destination": targetCoordinate]
        )

        return true
    }

    private static func executeMarkerInfo(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let marker = context.pressedMarker else { return false }

        NotificationCenter.default.post(
            name: .radialMenuShowMarkerInfo,
            object: nil,
            userInfo: ["marker": marker]
        )

        return true
    }

    // MARK: - Measurement Implementation

    private static func executeMeasure(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuMeasurementStarted,
            object: nil,
            userInfo: ["type": MeasurementType.distance, "coordinate": context.mapCoordinate]
        )
        return true
    }

    private static func executeMeasureDistance(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuMeasurementStarted,
            object: nil,
            userInfo: ["type": MeasurementType.distance, "coordinate": context.mapCoordinate]
        )
        return true
    }

    private static func executeMeasureArea(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuMeasurementStarted,
            object: nil,
            userInfo: ["type": MeasurementType.area, "coordinate": context.mapCoordinate]
        )
        return true
    }

    private static func executeMeasureBearing(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuMeasurementStarted,
            object: nil,
            userInfo: ["type": MeasurementType.bearing, "coordinate": context.mapCoordinate]
        )
        return true
    }

    // MARK: - Navigation Implementation

    private static func executeNavigate(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let routePlanningService = services.routePlanningService else { return false }

        let targetCoordinate = context.mapCoordinate

        // Get current location for start point
        guard let currentLocation = routePlanningService.currentLocation else {
            // Fall back to posting notification to show route planning UI
            NotificationCenter.default.post(
                name: .radialMenuNavigationStarted,
                object: nil,
                userInfo: ["destination": targetCoordinate, "destinationName": "Nav Target"]
            )
            return true
        }

        // Create quick 2-point route from current location to target
        let startWaypoint = RouteWaypoint(
            coordinate: currentLocation.coordinate,
            name: "Current Location",
            order: 0,
            instruction: "Start navigation"
        )

        let endWaypoint = RouteWaypoint(
            coordinate: targetCoordinate,
            name: "Nav Target",
            order: 1,
            instruction: "Arrive at destination"
        )

        // Create and start navigation route
        let route = routePlanningService.createRoute(
            name: "Quick Route",
            waypoints: [startWaypoint, endWaypoint],
            color: "#4CAF50",  // Green for navigation route
            lineStyle: .solid,
            lineOpacity: 0.9,
            lineWidth: 5.0,
            waypointIconStyle: .numbered,
            waypointPrefix: "",
            showDirectionArrows: true
        )

        // Start navigation on this route
        routePlanningService.startNavigation(for: route)

        NotificationCenter.default.post(
            name: .radialMenuNavigationStarted,
            object: nil,
            userInfo: ["route": route, "coordinate": targetCoordinate]
        )

        return true
    }

    private static func executeAddWaypoint(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        // Use PointDropperService to create a visible marker on the map
        guard let pointDropperService = services.pointDropperService else { return false }

        // Create a neutral waypoint marker that displays immediately
        let marker = pointDropperService.quickDrop(
            at: context.mapCoordinate,
            broadcast: false
        )

        // Update to neutral affiliation with waypoint styling
        var updatedMarker = marker
        updatedMarker.affiliation = .neutral
        updatedMarker.cotType = MarkerAffiliation.neutral.cotType
        updatedMarker.iconName = "mappin.circle.fill"
        updatedMarker.name = generateWaypointName()
        pointDropperService.updateMarker(updatedMarker)

        NotificationCenter.default.post(
            name: .radialMenuWaypointAdded,
            object: nil,
            userInfo: ["marker": updatedMarker]
        )

        return true
    }

    private static func executeCreateRoute(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuCreateRoute,
            object: nil,
            userInfo: ["startCoordinate": context.mapCoordinate]
        )
        return true
    }

    // MARK: - Drawing Implementation

    private static func executeOpenDrawingTools(context: RadialMenuContext) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuOpenDrawingTools,
            object: nil,
            userInfo: ["coordinate": context.mapCoordinate]
        )
        return true
    }

    private static func executeOpenDrawingsList(context: RadialMenuContext) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuOpenDrawingsList,
            object: nil,
            userInfo: [:]
        )
        return true
    }

    private static func executeDrawLine(context: RadialMenuContext) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuDrawLine,
            object: nil,
            userInfo: ["startCoordinate": context.mapCoordinate]
        )
        return true
    }

    private static func executeDrawCircle(context: RadialMenuContext) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuDrawCircle,
            object: nil,
            userInfo: ["centerCoordinate": context.mapCoordinate]
        )
        return true
    }

    private static func executeDrawPolygon(context: RadialMenuContext) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuDrawPolygon,
            object: nil,
            userInfo: ["startCoordinate": context.mapCoordinate]
        )
        return true
    }

    private static func executeEditDrawing(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let drawingId = context.pressedDrawingId,
              let drawingType = context.pressedDrawingType else { return false }

        NotificationCenter.default.post(
            name: .radialMenuEditDrawing,
            object: nil,
            userInfo: ["drawingId": drawingId, "drawingType": drawingType]
        )

        return true
    }

    private static func executeDeleteDrawing(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let drawingId = context.pressedDrawingId,
              let drawingType = context.pressedDrawingType,
              let drawingStore = services.drawingStore else { return false }

        switch drawingType {
        case .marker:
            if let marker = drawingStore.markers.first(where: { $0.id == drawingId }) {
                drawingStore.deleteMarker(marker)
            }
        case .line:
            if let line = drawingStore.lines.first(where: { $0.id == drawingId }) {
                drawingStore.deleteLine(line)
            }
        case .circle:
            if let circle = drawingStore.circles.first(where: { $0.id == drawingId }) {
                drawingStore.deleteCircle(circle)
            }
        case .polygon:
            if let polygon = drawingStore.polygons.first(where: { $0.id == drawingId }) {
                drawingStore.deletePolygon(polygon)
            }
        }

        NotificationCenter.default.post(
            name: .radialMenuDrawingDeleted,
            object: nil,
            userInfo: ["drawingId": drawingId, "drawingType": drawingType]
        )

        return true
    }

    // MARK: - Utility Implementation

    private static func executeCopyCoordinates(context: RadialMenuContext) -> Bool {
        let coordinate = context.mapCoordinate
        let coordString = formatCoordinate(coordinate)

        UIPasteboard.general.string = coordString

        NotificationCenter.default.post(
            name: .radialMenuCoordinatesCopied,
            object: nil,
            userInfo: ["coordinate": coordinate, "formattedString": coordString]
        )

        return true
    }

    private static func executeSetRangeRings(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let measurementManager = services.measurementManager else { return false }

        measurementManager.startMeasurement(type: .rangeRing)
        measurementManager.handleMapTap(at: context.mapCoordinate)

        NotificationCenter.default.post(
            name: .radialMenuRangeRingsSet,
            object: nil,
            userInfo: ["center": context.mapCoordinate]
        )

        return true
    }

    private static func executeCenterMap(context: RadialMenuContext) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuCenterMap,
            object: nil,
            userInfo: ["coordinate": context.mapCoordinate]
        )
        return true
    }

    private static func executeQuickChat(context: RadialMenuContext) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuQuickChat,
            object: nil,
            userInfo: ["context": context]
        )
        return true
    }

    private static func executeEmergency(context: RadialMenuContext) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuEmergency,
            object: nil,
            userInfo: ["coordinate": context.mapCoordinate]
        )
        return true
    }

    private static func executeGetInfo(context: RadialMenuContext) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuGetInfo,
            object: nil,
            userInfo: ["context": context]
        )
        return true
    }

    private static func executeCustomAction(
        identifier: String,
        context: RadialMenuContext,
        services: RadialMenuServices
    ) -> Bool {
        // Handle known custom actions with specific notifications
        switch identifier {
        case "dismiss":
            // Just dismiss the menu - no action needed
            // The menu dismisses automatically when any action is selected
            return true

        case "toggle_app_mode":
            NotificationCenter.default.post(
                name: .radialMenuShowAppModePicker,
                object: nil,
                userInfo: [:]
            )
            return true

        case "show_layers":
            NotificationCenter.default.post(
                name: .radialMenuShowLayers,
                object: nil,
                userInfo: [:]
            )
            return true

        case "meshtastic":
            // Open Meshtastic/mesh radio integration
            NotificationCenter.default.post(
                name: .radialMenuCustomAction,
                object: nil,
                userInfo: ["identifier": "open_meshtastic", "context": context]
            )
            return true

        default:
            NotificationCenter.default.post(
                name: .radialMenuCustomAction,
                object: nil,
                userInfo: ["identifier": identifier, "context": context]
            )
            return true
        }
    }

    // MARK: - Helper Methods

    private static func generateShareText(for marker: PointMarker) -> String {
        let coord = marker.coordinate
        let lat = String(format: "%.6f", coord.latitude)
        let lon = String(format: "%.6f", coord.longitude)

        var text = "\(marker.name)\n"
        text += "Affiliation: \(marker.affiliation.displayName)\n"
        text += "Location: \(lat), \(lon)\n"
        text += "Time: \(marker.formattedTimestamp)\n"

        if let remarks = marker.remarks, !remarks.isEmpty {
            text += "Remarks: \(remarks)\n"
        }

        if let salute = marker.saluteReport {
            text += "\n--- SALUTE ---\n"
            text += salute.formattedReport
        }

        return text
    }

    private static func generateWaypointName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HHmm"
        return "WP-\(dateFormatter.string(from: Date()))"
    }

    private static func formatCoordinate(_ coord: CLLocationCoordinate2D) -> String {
        let lat = coord.latitude
        let lon = coord.longitude

        let latDir = lat >= 0 ? "N" : "S"
        let lonDir = lon >= 0 ? "E" : "W"

        let latDeg = Int(abs(lat))
        let latMin = Int((abs(lat) - Double(latDeg)) * 60)
        let latSec = ((abs(lat) - Double(latDeg)) * 60 - Double(latMin)) * 60

        let lonDeg = Int(abs(lon))
        let lonMin = Int((abs(lon) - Double(lonDeg)) * 60)
        let lonSec = ((abs(lon) - Double(lonDeg)) * 60 - Double(lonMin)) * 60

        return String(format: "%d\u{00B0}%d'%.2f\"%@ %d\u{00B0}%d'%.2f\"%@",
                     latDeg, latMin, latSec, latDir,
                     lonDeg, lonMin, lonSec, lonDir)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let radialMenuMarkerDropped = Notification.Name("radialMenuMarkerDropped")
    static let radialMenuEditMarker = Notification.Name("radialMenuEditMarker")
    static let radialMenuMarkerDeleted = Notification.Name("radialMenuMarkerDeleted")
    static let radialMenuDrawingDeleted = Notification.Name("radialMenuDrawingDeleted")
    static let radialMenuShareMarker = Notification.Name("radialMenuShareMarker")
    static let radialMenuNavigationStarted = Notification.Name("radialMenuNavigationStarted")
    static let radialMenuShowMarkerInfo = Notification.Name("radialMenuShowMarkerInfo")
    static let radialMenuMeasurementStarted = Notification.Name("radialMenuMeasurementStarted")
    static let radialMenuWaypointAdded = Notification.Name("radialMenuWaypointAdded")
    static let radialMenuCreateRoute = Notification.Name("radialMenuCreateRoute")
    static let radialMenuCoordinatesCopied = Notification.Name("radialMenuCoordinatesCopied")
    static let radialMenuRangeRingsSet = Notification.Name("radialMenuRangeRingsSet")
    static let radialMenuCenterMap = Notification.Name("radialMenuCenterMap")
    static let radialMenuQuickChat = Notification.Name("radialMenuQuickChat")
    static let radialMenuEmergency = Notification.Name("radialMenuEmergency")
    static let radialMenuGetInfo = Notification.Name("radialMenuGetInfo")
    static let radialMenuCustomAction = Notification.Name("radialMenuCustomAction")
    // Drawing notifications
    static let radialMenuOpenDrawingTools = Notification.Name("radialMenuOpenDrawingTools")
    static let radialMenuOpenDrawingsList = Notification.Name("radialMenuOpenDrawingsList")
    static let radialMenuDrawLine = Notification.Name("radialMenuDrawLine")
    static let radialMenuDrawCircle = Notification.Name("radialMenuDrawCircle")
    static let radialMenuDrawPolygon = Notification.Name("radialMenuDrawPolygon")
    static let radialMenuEditDrawing = Notification.Name("radialMenuEditDrawing")
    // App mode & layers
    static let radialMenuShowAppModePicker = Notification.Name("radialMenuShowAppModePicker")
    static let radialMenuShowLayers = Notification.Name("radialMenuShowLayers")
}
