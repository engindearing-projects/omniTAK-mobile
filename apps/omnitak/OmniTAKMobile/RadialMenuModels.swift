//
//  RadialMenuModels.swift
//  OmniTAKMobile
//
//  Data models for the radial/wheel menu component - ATAK's signature interaction pattern
//

import Foundation
import SwiftUI
import CoreLocation
import MapKit

// MARK: - Radial Menu Item

/// Individual item in the radial menu
struct RadialMenuItem: Identifiable {
    let id: UUID
    let icon: String           // SF Symbol name
    let label: String
    let color: Color
    let action: RadialMenuAction
    var isEnabled: Bool
    var badge: String?

    init(
        id: UUID = UUID(),
        icon: String,
        label: String,
        color: Color = Color(hex: "#FFFC00"),
        action: RadialMenuAction,
        isEnabled: Bool = true,
        badge: String? = nil
    ) {
        self.id = id
        self.icon = icon
        self.label = label
        self.color = color
        self.action = action
        self.isEnabled = isEnabled
        self.badge = badge
    }
}

// MARK: - Radial Menu Action

/// Actions that can be triggered from the radial menu
enum RadialMenuAction: Equatable {
    // Marker Actions
    case dropMarker(MarkerAffiliation)
    case editMarker
    case deleteMarker
    case shareMarker
    case navigateToMarker
    case markerInfo

    // Map Actions
    case measure
    case measureDistance
    case measureArea
    case measureBearing

    // Navigation Actions
    case navigate
    case addWaypoint
    case createRoute

    // Utility Actions
    case copyCoordinates
    case setRangeRings
    case centerMap
    case quickChat
    case emergency
    case getInfo

    // Custom Action (non-equatable, requires special handling)
    case custom(String)

    var identifier: String {
        switch self {
        case .dropMarker(let affiliation):
            return "dropMarker_\(affiliation.rawValue)"
        case .editMarker:
            return "editMarker"
        case .deleteMarker:
            return "deleteMarker"
        case .shareMarker:
            return "shareMarker"
        case .navigateToMarker:
            return "navigateToMarker"
        case .markerInfo:
            return "markerInfo"
        case .measure:
            return "measure"
        case .measureDistance:
            return "measureDistance"
        case .measureArea:
            return "measureArea"
        case .measureBearing:
            return "measureBearing"
        case .navigate:
            return "navigate"
        case .addWaypoint:
            return "addWaypoint"
        case .createRoute:
            return "createRoute"
        case .copyCoordinates:
            return "copyCoordinates"
        case .setRangeRings:
            return "setRangeRings"
        case .centerMap:
            return "centerMap"
        case .quickChat:
            return "quickChat"
        case .emergency:
            return "emergency"
        case .getInfo:
            return "getInfo"
        case .custom(let id):
            return "custom_\(id)"
        }
    }

    /// Check if action has associated value that needs special handling
    var needsExternalHandling: Bool {
        switch self {
        case .custom:
            return false
        default:
            return true
        }
    }
}

// MARK: - Menu Context

/// Context information about where the menu was invoked
struct RadialMenuContext {
    let screenPoint: CGPoint
    let mapCoordinate: CLLocationCoordinate2D
    let pressedAnnotation: MKAnnotation?
    let pressedMarker: PointMarker?
    let pressedWaypoint: Waypoint?
    let pressedDrawingId: UUID?
    let pressedDrawingType: DrawingType?
    let contextType: ContextType

    enum ContextType {
        case emptyMap
        case pointMarker
        case waypoint
        case cotUnit
        case drawing
    }

    enum DrawingType {
        case marker
        case line
        case circle
        case polygon
    }

    static func empty(at screenPoint: CGPoint, coordinate: CLLocationCoordinate2D) -> RadialMenuContext {
        return RadialMenuContext(
            screenPoint: screenPoint,
            mapCoordinate: coordinate,
            pressedAnnotation: nil,
            pressedMarker: nil,
            pressedWaypoint: nil,
            pressedDrawingId: nil,
            pressedDrawingType: nil,
            contextType: .emptyMap
        )
    }
}

// MARK: - Services Container

/// Container for services used by the radial menu
struct RadialMenuServices {
    weak var pointDropperService: PointDropperService?
    weak var measurementManager: MeasurementManager?
    weak var navigationService: NavigationService?
    weak var waypointManager: WaypointManager?
    weak var drawingStore: DrawingStore?

    init(
        pointDropperService: PointDropperService? = nil,
        measurementManager: MeasurementManager? = nil,
        navigationService: NavigationService? = nil,
        waypointManager: WaypointManager? = nil,
        drawingStore: DrawingStore? = nil
    ) {
        self.pointDropperService = pointDropperService
        self.measurementManager = measurementManager
        self.navigationService = navigationService
        self.waypointManager = waypointManager
        self.drawingStore = drawingStore
    }

    static let shared = RadialMenuServices(
        pointDropperService: PointDropperService.shared,
        measurementManager: nil,
        navigationService: NavigationService.shared,
        waypointManager: WaypointManager.shared,
        drawingStore: nil
    )
}

// MARK: - Haptic Feedback

/// Haptic feedback types for radial menu interactions
enum RadialMenuHaptic {
    case menuAppear
    case itemHighlight
    case itemSelect
    case menuDismiss
    case error

    func trigger() {
        switch self {
        case .menuAppear:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()

        case .itemHighlight:
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()

        case .itemSelect:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()

        case .menuDismiss:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()

        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }
}

// MARK: - Radial Menu Configuration

/// Configuration for the radial menu appearance and behavior
struct RadialMenuConfiguration {
    var items: [RadialMenuItem]
    var radius: CGFloat = 100           // Distance from center to items
    var itemSize: CGFloat = 50          // Size of each menu item circle
    var animationDuration: Double = 0.3
    var hapticFeedback: Bool = true
    var showLabels: Bool = true         // Show text labels below icons
    var backgroundOpacity: Double = 0.7 // Dimming background opacity
    var accentColor: Color = Color(hex: "#FFFC00")  // TAK yellow
    var backgroundColor: Color = Color(hex: "#1E1E1E")  // Dark theme

    init(
        items: [RadialMenuItem] = [],
        radius: CGFloat = 100,
        itemSize: CGFloat = 50,
        animationDuration: Double = 0.3,
        hapticFeedback: Bool = true,
        showLabels: Bool = true,
        backgroundOpacity: Double = 0.7
    ) {
        self.items = items
        self.radius = radius
        self.itemSize = itemSize
        self.animationDuration = animationDuration
        self.hapticFeedback = hapticFeedback
        self.showLabels = showLabels
        self.backgroundOpacity = backgroundOpacity
    }

    /// Calculate the position of an item at a given index
    func itemPosition(at index: Int, center: CGPoint) -> CGPoint {
        guard items.count > 0 else { return center }

        let angleStep = (2 * Double.pi) / Double(items.count)
        let angle = Double(index) * angleStep - (Double.pi / 2) // Start from top

        let x = center.x + radius * CGFloat(cos(angle))
        let y = center.y + radius * CGFloat(sin(angle))

        return CGPoint(x: x, y: y)
    }

    /// Calculate which item index is closest to a given point
    func closestItemIndex(to point: CGPoint, center: CGPoint) -> Int? {
        guard items.count > 0 else { return nil }

        // Calculate distance from center
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        // Must be far enough from center to select an item
        let minSelectionDistance = radius * 0.3
        guard distance > minSelectionDistance else { return nil }

        // Calculate angle from center to point
        var angle = atan2(dy, dx)

        // Adjust angle to start from top (-pi/2)
        angle += Double.pi / 2
        if angle < 0 {
            angle += 2 * Double.pi
        }

        // Calculate which item this angle corresponds to
        let angleStep = (2 * Double.pi) / Double(items.count)
        let index = Int(round(angle / angleStep)) % items.count

        return index
    }
}

// MARK: - Radial Menu State

/// State management for the radial menu
enum RadialMenuState {
    case hidden
    case appearing
    case visible
    case selecting(Int) // Index of currently selected item
    case disappearing

    var isVisible: Bool {
        switch self {
        case .hidden, .disappearing:
            return false
        case .appearing, .visible, .selecting:
            return true
        }
    }
}

// MARK: - Radial Menu Event

/// Events emitted by the radial menu
enum RadialMenuEvent {
    case opened(CGPoint)           // Menu opened at location
    case itemHighlighted(Int)      // Item at index highlighted
    case itemSelected(RadialMenuAction)  // Item selected
    case dismissed                 // Menu dismissed without selection
}
