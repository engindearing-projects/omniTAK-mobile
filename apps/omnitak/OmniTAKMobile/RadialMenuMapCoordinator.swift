//
//  RadialMenuMapCoordinator.swift
//  OmniTAKMobile
//
//  Coordinates radial menu with map view - handles long-press, context detection, and action execution
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Radial Menu Map Coordinator

/// Coordinates the radial menu with the map view
class RadialMenuMapCoordinator: ObservableObject {
    // MARK: - Published Properties

    @Published var showRadialMenu: Bool = false
    @Published var menuCenterPoint: CGPoint = .zero
    @Published var menuConfiguration: RadialMenuConfiguration = RadialMenuConfiguration()
    @Published var currentContext: RadialMenuContext?
    @Published var isRadialMenuEnabled: Bool = true
    @Published var highlightedItemIndex: Int? = nil

    // MARK: - Services

    var services: RadialMenuServices

    // MARK: - Event Handlers

    var onActionExecuted: ((RadialMenuAction, Bool) -> Void)?
    var onMenuShown: ((RadialMenuContext) -> Void)?
    var onMenuDismissed: (() -> Void)?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let annotationHitTestRadius: CGFloat = 44.0  // Standard touch target size

    // MARK: - Initialization

    init(services: RadialMenuServices = .shared) {
        self.services = services
    }

    // MARK: - Long Press Handling

    /// Handle long press gesture on the map
    func handleLongPress(at screenPoint: CGPoint, on mapView: MKMapView) {
        guard isRadialMenuEnabled else { return }

        // Convert screen point to map coordinate
        let coordinate = mapView.convert(screenPoint, toCoordinateFrom: mapView)

        // Check if press is on an annotation
        let annotation = findAnnotation(near: screenPoint, in: mapView)

        // Build context
        let context: RadialMenuContext

        if let annotation = annotation {
            // Check what type of annotation
            if let markerAnnotation = annotation as? PointMarkerAnnotation {
                context = RadialMenuContext(
                    screenPoint: screenPoint,
                    mapCoordinate: coordinate,
                    pressedAnnotation: annotation,
                    pressedMarker: markerAnnotation.marker,
                    pressedWaypoint: nil,
                    pressedDrawingId: nil,
                    pressedDrawingType: nil,
                    contextType: .pointMarker
                )
                configureMarkerMenu(for: markerAnnotation.marker)
            } else if let waypointAnnotation = annotation as? WaypointAnnotation {
                context = RadialMenuContext(
                    screenPoint: screenPoint,
                    mapCoordinate: coordinate,
                    pressedAnnotation: annotation,
                    pressedMarker: nil,
                    pressedWaypoint: waypointAnnotation.waypoint,
                    pressedDrawingId: nil,
                    pressedDrawingType: nil,
                    contextType: .waypoint
                )
                configureWaypointMenu(for: waypointAnnotation.waypoint)
            } else {
                // Generic annotation (CoT unit, etc.)
                context = RadialMenuContext(
                    screenPoint: screenPoint,
                    mapCoordinate: coordinate,
                    pressedAnnotation: annotation,
                    pressedMarker: nil,
                    pressedWaypoint: nil,
                    pressedDrawingId: nil,
                    pressedDrawingType: nil,
                    contextType: .cotUnit
                )
                configureUnitMenu(for: annotation)
            }
        } else {
            // Empty map area
            context = RadialMenuContext.empty(at: screenPoint, coordinate: coordinate)
            configureMapMenu(at: coordinate)
        }

        currentContext = context

        // Adjust menu position if near edges
        menuCenterPoint = adjustMenuPosition(screenPoint, menuRadius: menuConfiguration.radius)

        // Trigger haptic feedback
        RadialMenuHaptic.menuAppear.trigger()

        // Show menu with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showRadialMenu = true
        }

        onMenuShown?(context)
        print("Radial menu opened at: \(coordinate.latitude), \(coordinate.longitude)")
    }

    // MARK: - Menu Configuration

    private func configureMapMenu(at coordinate: CLLocationCoordinate2D) {
        menuConfiguration = .mapContextMenu(at: coordinate)
    }

    private func configureMarkerMenu(for marker: PointMarker) {
        menuConfiguration = .markerContextMenu(for: marker)
    }

    private func configureWaypointMenu(for waypoint: Waypoint) {
        menuConfiguration = .waypointContextMenu(for: waypoint)
    }

    private func configureUnitMenu(for annotation: MKAnnotation) {
        menuConfiguration = .unitContextMenu(for: annotation)
    }

    // MARK: - Action Execution

    /// Execute the selected action from the radial menu
    func executeAction(_ action: RadialMenuAction) {
        guard let context = currentContext else {
            print("No context available for action execution")
            return
        }

        // Trigger haptic feedback
        RadialMenuHaptic.itemSelect.trigger()

        // Dismiss menu first
        dismissMenu()

        // Execute the action
        let success = RadialMenuActionExecutor.execute(
            action: action,
            context: context,
            services: services
        )

        onActionExecuted?(action, success)

        print("Executed action: \(action.identifier), success: \(success)")
    }

    /// Handle item highlight (for preview)
    func highlightItem(at index: Int?) {
        if highlightedItemIndex != index {
            highlightedItemIndex = index
            if index != nil {
                RadialMenuHaptic.itemHighlight.trigger()
            }
        }
    }

    // MARK: - Menu Dismissal

    /// Dismiss the radial menu
    func dismissMenu() {
        guard showRadialMenu else { return }

        RadialMenuHaptic.menuDismiss.trigger()

        withAnimation(.easeOut(duration: 0.2)) {
            showRadialMenu = false
        }

        // Clear state after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.currentContext = nil
            self.highlightedItemIndex = nil
        }

        onMenuDismissed?()
        print("Radial menu dismissed")
    }

    // MARK: - Helper Methods

    /// Find annotation near the given screen point
    private func findAnnotation(near screenPoint: CGPoint, in mapView: MKMapView) -> MKAnnotation? {
        for annotation in mapView.annotations {
            // Skip user location
            if annotation is MKUserLocation {
                continue
            }

            let annotationPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)
            let distance = hypot(screenPoint.x - annotationPoint.x, screenPoint.y - annotationPoint.y)

            if distance < annotationHitTestRadius {
                return annotation
            }
        }
        return nil
    }

    /// Adjust menu position to keep it within screen bounds
    private func adjustMenuPosition(_ point: CGPoint, menuRadius: CGFloat) -> CGPoint {
        let screenBounds = UIScreen.main.bounds
        let padding: CGFloat = 20.0
        let requiredSpace = menuRadius + padding

        var adjustedPoint = point

        // Adjust X
        if adjustedPoint.x < requiredSpace {
            adjustedPoint.x = requiredSpace
        } else if adjustedPoint.x > screenBounds.width - requiredSpace {
            adjustedPoint.x = screenBounds.width - requiredSpace
        }

        // Adjust Y
        if adjustedPoint.y < requiredSpace + 100 {  // Account for status bar
            adjustedPoint.y = requiredSpace + 100
        } else if adjustedPoint.y > screenBounds.height - requiredSpace - 100 {  // Account for toolbar
            adjustedPoint.y = screenBounds.height - requiredSpace - 100
        }

        return adjustedPoint
    }

    // MARK: - Service Configuration

    /// Configure services for the coordinator
    func configure(
        pointDropperService: PointDropperService? = nil,
        measurementManager: MeasurementManager? = nil,
        navigationService: NavigationService? = nil,
        waypointManager: WaypointManager? = nil,
        drawingStore: DrawingStore? = nil
    ) {
        if let pds = pointDropperService {
            services.pointDropperService = pds
        }
        if let mm = measurementManager {
            services.measurementManager = mm
        }
        if let ns = navigationService {
            services.navigationService = ns
        }
        if let wm = waypointManager {
            services.waypointManager = wm
        }
        if let ds = drawingStore {
            services.drawingStore = ds
        }
    }

    // MARK: - Toggle Radial Menu Mode

    /// Enable or disable radial menu
    func setEnabled(_ enabled: Bool) {
        isRadialMenuEnabled = enabled
        if !enabled && showRadialMenu {
            dismissMenu()
        }
        print("Radial menu \(enabled ? "enabled" : "disabled")")
    }

    func toggleEnabled() {
        setEnabled(!isRadialMenuEnabled)
    }

    // MARK: - Context Menu Display

    enum ContextMenuType {
        case mapContext
        case markerContext
    }

    /// Show context menu at a specific point for a coordinate
    func showContextMenu(
        at screenPoint: CGPoint,
        for coordinate: CLLocationCoordinate2D,
        menuType: ContextMenuType,
        drawingId: UUID? = nil,
        drawingType: RadialMenuContext.DrawingType? = nil
    ) {
        guard isRadialMenuEnabled else { return }

        // Build context
        let context: RadialMenuContext
        switch menuType {
        case .mapContext:
            context = RadialMenuContext.empty(at: screenPoint, coordinate: coordinate)
            configureMapMenu(at: coordinate)
        case .markerContext:
            context = RadialMenuContext(
                screenPoint: screenPoint,
                mapCoordinate: coordinate,
                pressedAnnotation: nil,
                pressedMarker: nil,
                pressedWaypoint: nil,
                pressedDrawingId: drawingId,
                pressedDrawingType: drawingType,
                contextType: .drawing
            )
            // Use marker context menu for drawn shapes
            menuConfiguration = RadialMenuPresets.markerContextMenu
        }

        currentContext = context

        // Adjust menu position if near edges
        menuCenterPoint = adjustMenuPosition(screenPoint, menuRadius: menuConfiguration.radius)

        // Trigger haptic feedback
        RadialMenuHaptic.menuAppear.trigger()

        // Show menu with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showRadialMenu = true
        }

        onMenuShown?(context)
        print("Radial menu opened at: \(coordinate.latitude), \(coordinate.longitude) - type: \(menuType), drawingId: \(drawingId?.uuidString ?? "none")")
    }
}


