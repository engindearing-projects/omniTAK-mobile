//
//  MapContextMenus.swift
//  OmniTAKMobile
//
//  Context-specific menu configurations for different map interactions
//

import Foundation
import SwiftUI
import CoreLocation
import MapKit

// MARK: - Map Context Menu Configurations

extension RadialMenuConfiguration {

    // MARK: - Empty Map Context Menu

    /// Menu for long-press on empty map area - primary actions for map interaction
    /// Options: Drop Point, Measure, Draw, Layers, R&B Line, Route Here (ATAK-style)
    static func mapContextMenu(at coordinate: CLLocationCoordinate2D) -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "mappin.circle.fill",
                label: "Drop Point",
                color: Color(hex: "#FFFF00"),  // ATAK accent yellow
                action: .addWaypoint
            ),
            RadialMenuItem(
                icon: "ruler",
                label: "Measure",
                color: .orange,
                action: .measure
            ),
            RadialMenuItem(
                icon: "pencil.tip.crop.circle",
                label: "Draw",
                color: .cyan,
                action: .custom("draw_shape")
            ),
            RadialMenuItem(
                icon: "square.3.layers.3d",
                label: "Layers",
                color: Color(hex: "#FFFF00"),  // ATAK accent yellow
                action: .custom("show_layers")
            ),
            RadialMenuItem(
                icon: "line.diagonal",
                label: "R&B Line",
                color: .purple,
                action: .measureBearing
            ),
            RadialMenuItem(
                icon: "arrow.triangle.turn.up.right.diamond",
                label: "Route Here",
                color: .green,
                action: .navigate
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 110,
            itemSize: 54,
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - Extended Map Context Menu (with affiliation markers)

    /// Extended menu including marker affiliation options
    static func extendedMapContextMenu(at coordinate: CLLocationCoordinate2D) -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "scope",
                label: "Hostile",
                color: .red,
                action: .dropMarker(.hostile)
            ),
            RadialMenuItem(
                icon: "shield.fill",
                label: "Friendly",
                color: .cyan,
                action: .dropMarker(.friendly)
            ),
            RadialMenuItem(
                icon: "questionmark.circle.fill",
                label: "Unknown",
                color: .yellow,
                action: .dropMarker(.unknown)
            ),
            RadialMenuItem(
                icon: "ruler",
                label: "Measure",
                color: .orange,
                action: .measure
            ),
            RadialMenuItem(
                icon: "location.fill",
                label: "Navigate",
                color: .green,
                action: .navigate
            ),
            RadialMenuItem(
                icon: "mappin",
                label: "Waypoint",
                color: .purple,
                action: .addWaypoint
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 110,
            itemSize: 54,
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - Point Marker Context Menu

    /// Menu for long-press on existing point marker
    static func markerContextMenu(for marker: PointMarker) -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "pencil",
                label: "Edit",
                color: .blue,
                action: .editMarker
            ),
            RadialMenuItem(
                icon: "trash",
                label: "Delete",
                color: .red,
                action: .deleteMarker
            ),
            RadialMenuItem(
                icon: "square.and.arrow.up",
                label: "Share",
                color: .green,
                action: .shareMarker
            ),
            RadialMenuItem(
                icon: "arrow.triangle.turn.up.right.diamond",
                label: "Navigate",
                color: .orange,
                action: .navigateToMarker
            ),
            RadialMenuItem(
                icon: "info.circle",
                label: "Info",
                color: .gray,
                action: .markerInfo
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 100,
            itemSize: 52,
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - Waypoint Context Menu

    /// Menu for long-press on waypoint
    static func waypointContextMenu(for waypoint: Waypoint) -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "pencil",
                label: "Edit",
                color: .blue,
                action: .editMarker
            ),
            RadialMenuItem(
                icon: "trash",
                label: "Delete",
                color: .red,
                action: .deleteMarker
            ),
            RadialMenuItem(
                icon: "location.north.fill",
                label: "Navigate",
                color: .green,
                action: .navigateToMarker
            ),
            RadialMenuItem(
                icon: "ruler",
                label: "Distance",
                color: .orange,
                action: .measureDistance
            ),
            RadialMenuItem(
                icon: "info.circle",
                label: "Info",
                color: .gray,
                action: .getInfo
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 100,
            itemSize: 52,
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - CoT Unit Context Menu

    /// Menu for long-press on CoT unit (friendly, hostile, etc.)
    static func unitContextMenu(for annotation: MKAnnotation) -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "arrow.triangle.turn.up.right.diamond",
                label: "Navigate",
                color: .green,
                action: .navigateToMarker
            ),
            RadialMenuItem(
                icon: "message.fill",
                label: "Chat",
                color: .blue,
                action: .quickChat
            ),
            RadialMenuItem(
                icon: "ruler",
                label: "Distance",
                color: .orange,
                action: .measureDistance
            ),
            RadialMenuItem(
                icon: "info.circle",
                label: "Info",
                color: .gray,
                action: .getInfo
            ),
            RadialMenuItem(
                icon: "doc.on.clipboard",
                label: "Copy Loc",
                color: .purple,
                action: .copyCoordinates
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 100,
            itemSize: 52,
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - Measurement Context Menu

    /// Menu for measurement-specific actions
    static func measurementContextMenu() -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "ruler",
                label: "Distance",
                color: .orange,
                action: .measureDistance
            ),
            RadialMenuItem(
                icon: "square.dashed",
                label: "Area",
                color: .green,
                action: .measureArea
            ),
            RadialMenuItem(
                icon: "location.north.line",
                label: "Bearing",
                color: .blue,
                action: .measureBearing
            ),
            RadialMenuItem(
                icon: "circle.dashed",
                label: "Range Ring",
                color: .purple,
                action: .setRangeRings
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 95,
            itemSize: 50,
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - Quick Actions Menu

    /// Compact menu for quick tactical actions
    static func quickActionsMenu(at coordinate: CLLocationCoordinate2D) -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "scope",
                label: "Hostile",
                color: .red,
                action: .dropMarker(.hostile)
            ),
            RadialMenuItem(
                icon: "shield.fill",
                label: "Friendly",
                color: .cyan,
                action: .dropMarker(.friendly)
            ),
            RadialMenuItem(
                icon: "mappin",
                label: "Waypoint",
                color: .purple,
                action: .addWaypoint
            ),
            RadialMenuItem(
                icon: "ruler",
                label: "Measure",
                color: .orange,
                action: .measure
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 85,
            itemSize: 48,
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - Emergency Context Menu

    /// Menu for emergency/SOS actions
    static func emergencyMenu() -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "exclamationmark.triangle.fill",
                label: "SOS",
                color: .red,
                action: .emergency
            ),
            RadialMenuItem(
                icon: "cross.circle.fill",
                label: "Medical",
                color: .white,
                action: .custom("medical_emergency")
            ),
            RadialMenuItem(
                icon: "shield.fill",
                label: "Security",
                color: .blue,
                action: .custom("security_alert")
            ),
            RadialMenuItem(
                icon: "location.fill",
                label: "Broadcast",
                color: .green,
                action: .custom("broadcast_position")
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 95,
            itemSize: 52,
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - Drawing Context Menu

    /// Menu for drawing/annotation actions
    static func drawingContextMenu() -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "pencil.tip",
                label: "Draw",
                color: Color(hex: "#FFFC00"),
                action: .custom("freehand_draw")
            ),
            RadialMenuItem(
                icon: "line.diagonal",
                label: "Line",
                color: .orange,
                action: .custom("draw_line")
            ),
            RadialMenuItem(
                icon: "circle",
                label: "Circle",
                color: .blue,
                action: .custom("draw_circle")
            ),
            RadialMenuItem(
                icon: "square",
                label: "Rectangle",
                color: .green,
                action: .custom("draw_rectangle")
            ),
            RadialMenuItem(
                icon: "pentagon",
                label: "Polygon",
                color: .purple,
                action: .custom("draw_polygon")
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 105,
            itemSize: 50,
            hapticFeedback: true,
            showLabels: true
        )
    }
}
