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
        // MARK: - Marker Drop Actions
        case .dropMarker(let affiliation):
            return executeDropMarker(affiliation: affiliation, context: context, services: services)

        // MARK: - Marker Management Actions
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

        // MARK: - Measurement Actions
        case .measure:
            return executeMeasure(context: context, services: services)

        case .measureDistance:
            return executeMeasureDistance(context: context, services: services)

        case .measureArea:
            return executeMeasureArea(context: context, services: services)

        case .measureBearing:
            return executeMeasureBearing(context: context, services: services)

        // MARK: - Navigation Actions
        case .navigate:
            return executeNavigate(context: context, services: services)

        case .addWaypoint:
            return executeAddWaypoint(context: context, services: services)

        case .createRoute:
            return executeCreateRoute(context: context, services: services)

        // MARK: - Utility Actions
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
        guard let pointDropperService = services.pointDropperService else {
            print("PointDropperService not available")
            return false
        }

        // Quick drop marker at the long-press location
        let marker = pointDropperService.quickDrop(
            at: context.mapCoordinate,
            broadcast: false
        )

        // Update affiliation if needed (quickDrop uses currentAffiliation)
        if marker.affiliation != affiliation {
            var updatedMarker = marker
            updatedMarker.affiliation = affiliation
            updatedMarker.cotType = affiliation.cotType
            updatedMarker.iconName = affiliation.iconName
            pointDropperService.updateMarker(updatedMarker)
        }

        print("Dropped \(affiliation.displayName) marker at: \(context.mapCoordinate.latitude), \(context.mapCoordinate.longitude)")

        // Notify via NotificationCenter for UI updates
        NotificationCenter.default.post(
            name: .radialMenuMarkerDropped,
            object: nil,
            userInfo: [
                "marker": marker,
                "affiliation": affiliation
            ]
        )

        return true
    }

    // MARK: - Marker Management Implementation

    private static func executeEditMarker(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let marker = context.pressedMarker else {
            print("No marker to edit")
            return false
        }

        // Post notification to show edit UI
        NotificationCenter.default.post(
            name: .radialMenuEditMarker,
            object: nil,
            userInfo: ["marker": marker]
        )

        print("Edit marker: \(marker.name)")
        return true
    }

    private static func executeDeleteMarker(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        // Check if we're deleting a drawing
        if context.contextType == .drawing,
           let drawingId = context.pressedDrawingId,
           let drawingType = context.pressedDrawingType,
           let drawingStore = services.drawingStore {

            switch drawingType {
            case .marker:
                if let marker = drawingStore.markers.first(where: { $0.id == drawingId }) {
                    drawingStore.deleteMarker(marker)
                    print("Deleted drawing marker: \(marker.name)")
                }
            case .line:
                if let line = drawingStore.lines.first(where: { $0.id == drawingId }) {
                    drawingStore.deleteLine(line)
                    print("Deleted line: \(line.name)")
                }
            case .circle:
                if let circle = drawingStore.circles.first(where: { $0.id == drawingId }) {
                    drawingStore.deleteCircle(circle)
                    print("Deleted circle: \(circle.name)")
                }
            case .polygon:
                if let polygon = drawingStore.polygons.first(where: { $0.id == drawingId }) {
                    drawingStore.deletePolygon(polygon)
                    print("Deleted polygon: \(polygon.name)")
                }
            }

            NotificationCenter.default.post(
                name: .radialMenuDrawingDeleted,
                object: nil,
                userInfo: [
                    "drawingId": drawingId,
                    "drawingType": drawingType
                ]
            )

            return true
        }

        // Check if we're deleting a point marker (from PointDropperService)
        guard let marker = context.pressedMarker,
              let pointDropperService = services.pointDropperService else {
            print("Cannot delete marker - missing marker or service")
            return false
        }

        pointDropperService.deleteMarker(marker)

        NotificationCenter.default.post(
            name: .radialMenuMarkerDeleted,
            object: nil,
            userInfo: ["marker": marker]
        )

        print("Deleted marker: \(marker.name)")
        return true
    }

    private static func executeShareMarker(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let marker = context.pressedMarker else {
            print("No marker to share")
            return false
        }

        // Generate share content
        let shareText = generateShareText(for: marker)

        // Copy to clipboard as immediate action
        UIPasteboard.general.string = shareText

        // Post notification for share sheet
        NotificationCenter.default.post(
            name: .radialMenuShareMarker,
            object: nil,
            userInfo: [
                "marker": marker,
                "shareText": shareText
            ]
        )

        print("Share marker: \(marker.name)")
        return true
    }

    private static func executeNavigateToMarker(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let navigationService = services.navigationService else {
            print("NavigationService not available")
            return false
        }

        let coordinate: CLLocationCoordinate2D
        let name: String

        if let marker = context.pressedMarker {
            coordinate = marker.coordinate
            name = marker.name
        } else if let waypoint = context.pressedWaypoint {
            coordinate = waypoint.coordinate
            name = waypoint.name
        } else {
            coordinate = context.mapCoordinate
            name = "Selected Location"
        }

        // Create temporary waypoint for navigation
        let tempWaypoint = Waypoint(
            name: name,
            coordinate: coordinate
        )

        navigationService.startNavigation(to: tempWaypoint)

        NotificationCenter.default.post(
            name: .radialMenuNavigationStarted,
            object: nil,
            userInfo: ["waypoint": tempWaypoint]
        )

        print("Navigate to: \(name)")
        return true
    }

    private static func executeMarkerInfo(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let marker = context.pressedMarker else {
            print("No marker for info")
            return false
        }

        NotificationCenter.default.post(
            name: .radialMenuShowMarkerInfo,
            object: nil,
            userInfo: ["marker": marker]
        )

        print("Show info for marker: \(marker.name)")
        return true
    }

    // MARK: - Measurement Implementation

    private static func executeMeasure(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let measurementManager = services.measurementManager else {
            print("MeasurementManager not available")
            return false
        }

        measurementManager.startMeasurement(type: .distance)
        measurementManager.handleMapTap(at: context.mapCoordinate)

        NotificationCenter.default.post(
            name: .radialMenuMeasurementStarted,
            object: nil,
            userInfo: ["type": MeasurementType.distance]
        )

        print("Started distance measurement at: \(context.mapCoordinate.latitude), \(context.mapCoordinate.longitude)")
        return true
    }

    private static func executeMeasureDistance(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let measurementManager = services.measurementManager else {
            print("MeasurementManager not available")
            return false
        }

        measurementManager.startMeasurement(type: .distance)
        measurementManager.handleMapTap(at: context.mapCoordinate)

        NotificationCenter.default.post(
            name: .radialMenuMeasurementStarted,
            object: nil,
            userInfo: ["type": MeasurementType.distance]
        )

        return true
    }

    private static func executeMeasureArea(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let measurementManager = services.measurementManager else {
            print("MeasurementManager not available")
            return false
        }

        measurementManager.startMeasurement(type: .area)
        measurementManager.handleMapTap(at: context.mapCoordinate)

        NotificationCenter.default.post(
            name: .radialMenuMeasurementStarted,
            object: nil,
            userInfo: ["type": MeasurementType.area]
        )

        return true
    }

    private static func executeMeasureBearing(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let measurementManager = services.measurementManager else {
            print("MeasurementManager not available")
            return false
        }

        measurementManager.startMeasurement(type: .bearing)
        measurementManager.handleMapTap(at: context.mapCoordinate)

        NotificationCenter.default.post(
            name: .radialMenuMeasurementStarted,
            object: nil,
            userInfo: ["type": MeasurementType.bearing]
        )

        return true
    }

    // MARK: - Navigation Implementation

    private static func executeNavigate(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let navigationService = services.navigationService else {
            print("NavigationService not available")
            return false
        }

        let waypoint = Waypoint(
            name: "Nav Target",
            coordinate: context.mapCoordinate
        )

        navigationService.startNavigation(to: waypoint)

        NotificationCenter.default.post(
            name: .radialMenuNavigationStarted,
            object: nil,
            userInfo: ["coordinate": context.mapCoordinate]
        )

        print("Navigate to: \(context.mapCoordinate.latitude), \(context.mapCoordinate.longitude)")
        return true
    }

    private static func executeAddWaypoint(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let waypointManager = services.waypointManager else {
            print("WaypointManager not available")
            return false
        }

        let waypoint = waypointManager.createWaypoint(
            name: generateWaypointName(),
            coordinate: context.mapCoordinate
        )

        NotificationCenter.default.post(
            name: .radialMenuWaypointAdded,
            object: nil,
            userInfo: ["waypoint": waypoint]
        )

        print("Added waypoint at: \(context.mapCoordinate.latitude), \(context.mapCoordinate.longitude)")
        return true
    }

    private static func executeCreateRoute(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuCreateRoute,
            object: nil,
            userInfo: ["startCoordinate": context.mapCoordinate]
        )

        print("Create route from: \(context.mapCoordinate.latitude), \(context.mapCoordinate.longitude)")
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

        print("Copied coordinates: \(coordString)")
        return true
    }

    private static func executeSetRangeRings(context: RadialMenuContext, services: RadialMenuServices) -> Bool {
        guard let measurementManager = services.measurementManager else {
            print("MeasurementManager not available")
            return false
        }

        measurementManager.startMeasurement(type: .rangeRing)
        measurementManager.handleMapTap(at: context.mapCoordinate)

        NotificationCenter.default.post(
            name: .radialMenuRangeRingsSet,
            object: nil,
            userInfo: ["center": context.mapCoordinate]
        )

        print("Set range rings at: \(context.mapCoordinate.latitude), \(context.mapCoordinate.longitude)")
        return true
    }

    private static func executeCenterMap(context: RadialMenuContext) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuCenterMap,
            object: nil,
            userInfo: ["coordinate": context.mapCoordinate]
        )

        print("Center map on: \(context.mapCoordinate.latitude), \(context.mapCoordinate.longitude)")
        return true
    }

    private static func executeQuickChat(context: RadialMenuContext) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuQuickChat,
            object: nil,
            userInfo: ["context": context]
        )

        print("Quick chat initiated")
        return true
    }

    private static func executeEmergency(context: RadialMenuContext) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuEmergency,
            object: nil,
            userInfo: ["coordinate": context.mapCoordinate]
        )

        print("EMERGENCY action triggered at: \(context.mapCoordinate.latitude), \(context.mapCoordinate.longitude)")
        return true
    }

    private static func executeGetInfo(context: RadialMenuContext) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuGetInfo,
            object: nil,
            userInfo: ["context": context]
        )

        print("Get info for context: \(context.contextType)")
        return true
    }

    private static func executeCustomAction(
        identifier: String,
        context: RadialMenuContext,
        services: RadialMenuServices
    ) -> Bool {
        NotificationCenter.default.post(
            name: .radialMenuCustomAction,
            object: nil,
            userInfo: [
                "identifier": identifier,
                "context": context
            ]
        )

        print("Custom action: \(identifier)")
        return true
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
        let timeStr = dateFormatter.string(from: Date())
        return "WP-\(timeStr)"
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
}
