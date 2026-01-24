//
//  MapContextMenus.swift
//  OmniTAKMobile
//
//  Context-specific menu configurations for different map interactions
//  ATAK-style radial menus with pie wedge design
//

import Foundation
import SwiftUI
import CoreLocation
import MapKit

// MARK: - Map Context Menu Configurations

extension RadialMenuConfiguration {

    // MARK: - Empty Map Context Menu

    /// Menu for long-press on empty map area - ATAK-style 8-item radial menu
    /// Matches ATAK's standard map context menu layout
    static func mapContextMenu(at coordinate: CLLocationCoordinate2D) -> RadialMenuConfiguration {
        let items = [
            // Top - Drop Point (primary action)
            RadialMenuItem(
                icon: "mappin.circle.fill",
                label: "Point",
                action: .addWaypoint
            ),
            // Top-right - Route/Navigate
            RadialMenuItem(
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                label: "Route",
                action: .navigate
            ),
            // Right - Measure
            RadialMenuItem(
                icon: "ruler.fill",
                label: "Measure",
                action: .measure
            ),
            // Bottom-right - R&B Line (Range & Bearing)
            RadialMenuItem(
                icon: "line.diagonal",
                label: "R&B Line",
                action: .measureBearing
            ),
            // Bottom - Draw
            RadialMenuItem(
                icon: "pencil.tip.crop.circle",
                label: "Draw",
                action: .openDrawingTools
            ),
            // Bottom-left - Drawings list
            RadialMenuItem(
                icon: "list.bullet.rectangle.fill",
                label: "Drawn",
                action: .openDrawingsList
            ),
            // Left - Layers
            RadialMenuItem(
                icon: "square.stack.3d.up.fill",
                label: "Layers",
                action: .custom("show_layers")
            ),
            // Top-left - Copy coordinates
            RadialMenuItem(
                icon: "doc.on.clipboard",
                label: "Copy Loc",
                action: .copyCoordinates
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 120,
            itemSize: 48,
            hapticFeedback: true,
            showLabels: false  // ATAK style: icons only
        )
    }

    // MARK: - Extended Map Context Menu (with affiliation markers)

    /// Extended menu for quick marker placement with affiliation options
    static func extendedMapContextMenu(at coordinate: CLLocationCoordinate2D) -> RadialMenuConfiguration {
        let items = [
            // Top - Hostile (red in ATAK)
            RadialMenuItem(
                icon: "scope",
                label: "Hostile",
                action: .dropMarker(.hostile)
            ),
            // Top-right - Friendly
            RadialMenuItem(
                icon: "shield.fill",
                label: "Friendly",
                action: .dropMarker(.friendly)
            ),
            // Right - Unknown
            RadialMenuItem(
                icon: "questionmark.diamond.fill",
                label: "Unknown",
                action: .dropMarker(.unknown)
            ),
            // Bottom-right - Neutral
            RadialMenuItem(
                icon: "circle.fill",
                label: "Neutral",
                action: .dropMarker(.neutral)
            ),
            // Bottom - Waypoint
            RadialMenuItem(
                icon: "mappin.circle.fill",
                label: "Waypoint",
                action: .addWaypoint
            ),
            // Bottom-left - Measure
            RadialMenuItem(
                icon: "ruler.fill",
                label: "Measure",
                action: .measure
            ),
            // Left - Navigate
            RadialMenuItem(
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                label: "Navigate",
                action: .navigate
            ),
            // Top-left - Copy Location
            RadialMenuItem(
                icon: "doc.on.clipboard",
                label: "Copy Loc",
                action: .copyCoordinates
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 120,
            itemSize: 48,
            hapticFeedback: true,
            showLabels: false
        )
    }

    // MARK: - Point Marker Context Menu

    /// Menu for long-press on existing point marker - ATAK style
    static func markerContextMenu(for marker: PointMarker) -> RadialMenuConfiguration {
        let items = [
            // Top - Navigate to
            RadialMenuItem(
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                label: "Navigate",
                action: .navigateToMarker
            ),
            // Top-right - Edit
            RadialMenuItem(
                icon: "pencil",
                label: "Edit",
                action: .editMarker
            ),
            // Right - Share
            RadialMenuItem(
                icon: "square.and.arrow.up.fill",
                label: "Share",
                action: .shareMarker
            ),
            // Bottom-right - Measure to
            RadialMenuItem(
                icon: "ruler.fill",
                label: "Distance",
                action: .measureDistance
            ),
            // Bottom - Delete (red)
            RadialMenuItem(
                icon: "trash.fill",
                label: "Delete",
                action: .deleteMarker
            ),
            // Bottom-left - Copy coordinates
            RadialMenuItem(
                icon: "doc.on.clipboard",
                label: "Copy Loc",
                action: .copyCoordinates
            ),
            // Left - Range rings
            RadialMenuItem(
                icon: "circle.dashed",
                label: "Range Ring",
                action: .setRangeRings
            ),
            // Top-left - Info
            RadialMenuItem(
                icon: "info.circle.fill",
                label: "Info",
                action: .markerInfo
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 120,
            itemSize: 48,
            hapticFeedback: true,
            showLabels: false
        )
    }

    // MARK: - Waypoint Context Menu

    /// Menu for long-press on waypoint - ATAK style
    static func waypointContextMenu(for waypoint: Waypoint) -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                label: "Navigate",
                action: .navigateToMarker
            ),
            RadialMenuItem(
                icon: "pencil",
                label: "Edit",
                action: .editMarker
            ),
            RadialMenuItem(
                icon: "ruler.fill",
                label: "Distance",
                action: .measureDistance
            ),
            RadialMenuItem(
                icon: "trash.fill",
                label: "Delete",
                action: .deleteMarker
            ),
            RadialMenuItem(
                icon: "doc.on.clipboard",
                label: "Copy Loc",
                action: .copyCoordinates
            ),
            RadialMenuItem(
                icon: "info.circle.fill",
                label: "Info",
                action: .getInfo
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 110,
            itemSize: 48,
            hapticFeedback: true,
            showLabels: false
        )
    }

    // MARK: - CoT Unit Context Menu

    /// Menu for long-press on CoT unit (friendly, hostile, etc.) - ATAK style
    static func unitContextMenu(for annotation: MKAnnotation) -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "arrow.triangle.turn.up.right.diamond.fill",
                label: "Navigate",
                action: .navigateToMarker
            ),
            RadialMenuItem(
                icon: "message.fill",
                label: "Chat",
                action: .quickChat
            ),
            RadialMenuItem(
                icon: "ruler.fill",
                label: "Distance",
                action: .measureDistance
            ),
            RadialMenuItem(
                icon: "doc.on.clipboard",
                label: "Copy Loc",
                action: .copyCoordinates
            ),
            RadialMenuItem(
                icon: "circle.dashed",
                label: "Range Ring",
                action: .setRangeRings
            ),
            RadialMenuItem(
                icon: "info.circle.fill",
                label: "Info",
                action: .getInfo
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 110,
            itemSize: 48,
            hapticFeedback: true,
            showLabels: false
        )
    }

    // MARK: - Measurement Context Menu

    /// Menu for measurement-specific actions - ATAK style
    static func measurementContextMenu() -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "ruler.fill",
                label: "Distance",
                action: .measureDistance
            ),
            RadialMenuItem(
                icon: "square.dashed",
                label: "Area",
                action: .measureArea
            ),
            RadialMenuItem(
                icon: "location.north.line.fill",
                label: "Bearing",
                action: .measureBearing
            ),
            RadialMenuItem(
                icon: "circle.dashed",
                label: "Range Ring",
                action: .setRangeRings
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 100,
            itemSize: 48,
            hapticFeedback: true,
            showLabels: false
        )
    }

    // MARK: - Quick Actions Menu

    /// Compact 4-item menu for quick tactical actions - ATAK style
    static func quickActionsMenu(at coordinate: CLLocationCoordinate2D) -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "scope",
                label: "Hostile",
                action: .dropMarker(.hostile)
            ),
            RadialMenuItem(
                icon: "shield.fill",
                label: "Friendly",
                action: .dropMarker(.friendly)
            ),
            RadialMenuItem(
                icon: "mappin.circle.fill",
                label: "Waypoint",
                action: .addWaypoint
            ),
            RadialMenuItem(
                icon: "ruler.fill",
                label: "Measure",
                action: .measure
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 100,
            itemSize: 48,
            hapticFeedback: true,
            showLabels: false
        )
    }

    // MARK: - Emergency Context Menu

    /// Menu for emergency/SOS actions - ATAK style
    static func emergencyMenu() -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "exclamationmark.triangle.fill",
                label: "SOS",
                action: .emergency
            ),
            RadialMenuItem(
                icon: "cross.circle.fill",
                label: "Medical",
                action: .custom("medical_emergency")
            ),
            RadialMenuItem(
                icon: "shield.fill",
                label: "Security",
                action: .custom("security_alert")
            ),
            RadialMenuItem(
                icon: "location.fill",
                label: "Broadcast",
                action: .custom("broadcast_position")
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 100,
            itemSize: 48,
            hapticFeedback: true,
            showLabels: false
        )
    }

    // MARK: - Drawing Context Menu

    /// Menu for drawing/annotation actions - ATAK style
    static func drawingContextMenu() -> RadialMenuConfiguration {
        let items = [
            RadialMenuItem(
                icon: "pencil.tip",
                label: "Freehand",
                action: .custom("freehand_draw")
            ),
            RadialMenuItem(
                icon: "line.diagonal",
                label: "Line",
                action: .drawLine
            ),
            RadialMenuItem(
                icon: "circle",
                label: "Circle",
                action: .drawCircle
            ),
            RadialMenuItem(
                icon: "square",
                label: "Rectangle",
                action: .custom("draw_rectangle")
            ),
            RadialMenuItem(
                icon: "pentagon",
                label: "Polygon",
                action: .drawPolygon
            ),
            RadialMenuItem(
                icon: "arrow.uturn.backward",
                label: "Undo",
                action: .custom("undo_draw")
            )
        ]

        return RadialMenuConfiguration(
            items: items,
            radius: 110,
            itemSize: 48,
            hapticFeedback: true,
            showLabels: false
        )
    }
}
