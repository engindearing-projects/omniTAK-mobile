//
//  RadialMenuPresets.swift
//  OmniTAKMobile
//
//  Pre-configured radial menu setups for common TAK operations
//

import SwiftUI

// MARK: - Radial Menu Presets

/// Factory class for creating pre-configured radial menus
enum RadialMenuPresets {

    // MARK: - Map Context Menu

    /// Menu for map interactions (long-press on empty map area)
    /// Actions: Mark Hostile, Mark Friendly, Draw, Drawings, Measure, Waypoint
    // ATAK-style tactical colors
    private static let atakRed = Color(hex: "#C62828")      // Hostile red
    private static let atakBlue = Color(hex: "#1565C0")     // Friendly blue
    private static let atakGreen = Color(hex: "#2E7D32")    // Navigation green
    private static let atakOrange = Color(hex: "#EF6C00")   // Warning orange
    private static let atakTan = Color(hex: "#8D6E63")      // Neutral tan
    private static let atakGray = Color(hex: "#546E7A")     // Tool gray
    private static let atakOlive = Color(hex: "#7CB342")    // Olive/action
    private static let atakPurple = Color(hex: "#7B1FA2")   // Drawing purple

    static var mapContextMenu: RadialMenuConfiguration {
        RadialMenuConfiguration(
            items: [
                RadialMenuItem(
                    icon: "exclamationmark.triangle.fill",
                    label: "Hostile",
                    color: atakRed,
                    action: .dropMarker(.hostile)
                ),
                RadialMenuItem(
                    icon: "shield.fill",
                    label: "Friendly",
                    color: atakBlue,
                    action: .dropMarker(.friendly)
                ),
                RadialMenuItem(
                    icon: "pencil.tip.crop.circle",
                    label: "Draw",
                    color: atakPurple,
                    action: .openDrawingTools
                ),
                RadialMenuItem(
                    icon: "list.bullet.rectangle",
                    label: "Drawings",
                    color: atakGray,
                    action: .openDrawingsList
                ),
                RadialMenuItem(
                    icon: "ruler",
                    label: "Measure",
                    color: atakOrange,
                    action: .measure
                ),
                RadialMenuItem(
                    icon: "mappin.and.ellipse",
                    label: "Waypoint",
                    color: atakOlive,
                    action: .addWaypoint
                )
            ],
            radius: 130,  // Larger to contain labels inside black ring
            itemSize: 56, // Good touch targets
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - Marker Context Menu

    /// Menu for marker interactions (long-press on existing marker)
    /// Actions: Edit, Delete, Share, Navigate To, Get Info
    static var markerContextMenu: RadialMenuConfiguration {
        RadialMenuConfiguration(
            items: [
                RadialMenuItem(
                    icon: "pencil.circle.fill",
                    label: "Edit",
                    color: atakOrange,
                    action: .editMarker
                ),
                RadialMenuItem(
                    icon: "trash.fill",
                    label: "Delete",
                    color: atakRed,
                    action: .deleteMarker
                ),
                RadialMenuItem(
                    icon: "square.and.arrow.up.fill",
                    label: "Share",
                    color: atakBlue,
                    action: .shareMarker
                ),
                RadialMenuItem(
                    icon: "arrow.triangle.turn.up.right.circle.fill",
                    label: "Navigate",
                    color: atakGreen,
                    action: .navigate
                ),
                RadialMenuItem(
                    icon: "info.circle.fill",
                    label: "Info",
                    color: atakGray,
                    action: .getInfo
                )
            ],
            radius: 120,  // Larger to contain labels
            itemSize: 56, // Good touch targets
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - Quick Actions Menu

    /// Menu for quick tactical actions
    /// Actions: Drop Point, Start Route, Quick Chat, Meshtastic, Emergency
    static var quickActionsMenu: RadialMenuConfiguration {
        RadialMenuConfiguration(
            items: [
                RadialMenuItem(
                    icon: "mappin.circle.fill",
                    label: "Drop Point",
                    color: atakOlive,
                    action: .addWaypoint
                ),
                RadialMenuItem(
                    icon: "point.topleft.down.curvedto.point.bottomright.up.fill",
                    label: "Route",
                    color: atakOrange,
                    action: .createRoute
                ),
                RadialMenuItem(
                    icon: "bubble.left.fill",
                    label: "Chat",
                    color: atakBlue,
                    action: .quickChat
                ),
                RadialMenuItem(
                    icon: "dot.radiowaves.left.and.right",
                    label: "Mesh",
                    color: atakGreen,
                    action: .custom("meshtastic")
                ),
                RadialMenuItem(
                    icon: "exclamationmark.octagon.fill",
                    label: "Emergency",
                    color: atakRed,
                    action: .emergency
                )
            ],
            radius: 120,  // Contains labels
            itemSize: 56, // Good touch targets
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - Marker Affiliation Menu

    /// Menu specifically for selecting marker affiliation
    static var affiliationMenu: RadialMenuConfiguration {
        RadialMenuConfiguration(
            items: [
                RadialMenuItem(
                    icon: "shield.fill",
                    label: "Friendly",
                    color: atakBlue,
                    action: .dropMarker(.friendly)
                ),
                RadialMenuItem(
                    icon: "exclamationmark.triangle.fill",
                    label: "Hostile",
                    color: atakRed,
                    action: .dropMarker(.hostile)
                ),
                RadialMenuItem(
                    icon: "questionmark.circle.fill",
                    label: "Unknown",
                    color: Color(hex: "#FDD835"),  // ATAK yellow for unknown
                    action: .dropMarker(.unknown)
                ),
                RadialMenuItem(
                    icon: "circle.fill",
                    label: "Neutral",
                    color: atakGreen,
                    action: .dropMarker(.neutral)
                )
            ],
            radius: 115,  // Contains labels
            itemSize: 58, // Good touch targets
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - Measurement Tools Menu

    /// Menu for measurement and analysis tools
    static var measurementMenu: RadialMenuConfiguration {
        RadialMenuConfiguration(
            items: [
                RadialMenuItem(
                    icon: "ruler",
                    label: "Distance",
                    color: atakOrange,
                    action: .measureDistance
                ),
                RadialMenuItem(
                    icon: "square.dashed",
                    label: "Area",
                    color: atakTan,
                    action: .measureArea
                ),
                RadialMenuItem(
                    icon: "scope",
                    label: "Bearing",
                    color: atakBlue,
                    action: .measureBearing
                ),
                RadialMenuItem(
                    icon: "target",
                    label: "Range Rings",
                    color: atakGreen,
                    action: .setRangeRings
                )
            ],
            radius: 115,  // Contains labels
            itemSize: 56, // Good touch targets
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - Navigation Menu

    /// Menu for navigation options
    static var navigationMenu: RadialMenuConfiguration {
        RadialMenuConfiguration(
            items: [
                RadialMenuItem(
                    icon: "location.fill",
                    label: "Navigate",
                    color: atakGreen,
                    action: .navigate
                ),
                RadialMenuItem(
                    icon: "map.fill",
                    label: "Route",
                    color: atakBlue,
                    action: .createRoute
                ),
                RadialMenuItem(
                    icon: "mappin.and.ellipse",
                    label: "Waypoint",
                    color: atakOlive,
                    action: .addWaypoint
                ),
                RadialMenuItem(
                    icon: "location.north.line.fill",
                    label: "Center",
                    color: atakGray,
                    action: .centerMap
                )
            ],
            radius: 115,  // Contains labels
            itemSize: 56, // Good touch targets
            hapticFeedback: true,
            showLabels: true
        )
    }

    // MARK: - Compact Menu

    /// Smaller menu with fewer items for tight spaces
    static var compactMenu: RadialMenuConfiguration {
        RadialMenuConfiguration(
            items: [
                RadialMenuItem(
                    icon: "plus.circle.fill",
                    label: "Add",
                    color: atakOlive,
                    action: .addWaypoint
                ),
                RadialMenuItem(
                    icon: "info.circle.fill",
                    label: "Info",
                    color: atakBlue,
                    action: .getInfo
                ),
                RadialMenuItem(
                    icon: "xmark.circle.fill",
                    label: "Cancel",
                    color: atakGray,
                    action: .custom("dismiss")
                )
            ],
            radius: 90,   // Compact but usable
            itemSize: 54, // Good touch target
            hapticFeedback: true,
            showLabels: false
        )
    }
}

// MARK: - Custom Menu Builder

/// Builder for creating custom radial menu configurations
class RadialMenuBuilder {
    private var items: [RadialMenuItem] = []
    private var radius: CGFloat = 100
    private var itemSize: CGFloat = 50
    private var animationDuration: Double = 0.3
    private var hapticFeedback: Bool = true
    private var showLabels: Bool = true
    private var backgroundOpacity: Double = 0.7

    /// Add an item to the menu
    @discardableResult
    func addItem(
        icon: String,
        label: String,
        color: Color = Color(hex: "#FFFC00"),
        action: RadialMenuAction
    ) -> RadialMenuBuilder {
        let item = RadialMenuItem(
            icon: icon,
            label: label,
            color: color,
            action: action
        )
        items.append(item)
        return self
    }

    /// Set the menu radius
    @discardableResult
    func setRadius(_ radius: CGFloat) -> RadialMenuBuilder {
        self.radius = radius
        return self
    }

    /// Set the item size
    @discardableResult
    func setItemSize(_ size: CGFloat) -> RadialMenuBuilder {
        self.itemSize = size
        return self
    }

    /// Set animation duration
    @discardableResult
    func setAnimationDuration(_ duration: Double) -> RadialMenuBuilder {
        self.animationDuration = duration
        return self
    }

    /// Enable or disable haptic feedback
    @discardableResult
    func setHapticFeedback(_ enabled: Bool) -> RadialMenuBuilder {
        self.hapticFeedback = enabled
        return self
    }

    /// Show or hide labels
    @discardableResult
    func setShowLabels(_ show: Bool) -> RadialMenuBuilder {
        self.showLabels = show
        return self
    }

    /// Set background opacity
    @discardableResult
    func setBackgroundOpacity(_ opacity: Double) -> RadialMenuBuilder {
        self.backgroundOpacity = opacity
        return self
    }

    /// Build the configuration
    func build() -> RadialMenuConfiguration {
        RadialMenuConfiguration(
            items: items,
            radius: radius,
            itemSize: itemSize,
            animationDuration: animationDuration,
            hapticFeedback: hapticFeedback,
            showLabels: showLabels,
            backgroundOpacity: backgroundOpacity
        )
    }
}

// MARK: - Preview

struct RadialMenuPresets_Previews: PreviewProvider {
    static var previews: some View {
        RadialMenuPresetsPreviewWrapper()
            .preferredColorScheme(.dark)
    }
}

struct RadialMenuPresetsPreviewWrapper: View {
    @State private var isPresented = true
    @State private var menuLocation = CGPoint(x: 200, y: 400)
    @State private var selectedPreset = "Map Context"
    @State private var lastAction = "None"

    var currentConfiguration: RadialMenuConfiguration {
        switch selectedPreset {
        case "Map Context":
            return RadialMenuPresets.mapContextMenu
        case "Marker Context":
            return RadialMenuPresets.markerContextMenu
        case "Quick Actions":
            return RadialMenuPresets.quickActionsMenu
        case "Affiliation":
            return RadialMenuPresets.affiliationMenu
        default:
            return RadialMenuPresets.mapContextMenu
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "#1E1E1E")
                .ignoresSafeArea()

            VStack {
                Text("Preset: \(selectedPreset)")
                    .foregroundColor(.white)
                    .font(.headline)

                Text("Last Action: \(lastAction)")
                    .foregroundColor(Color(hex: "#CCCCCC"))
                    .font(.subheadline)
                    .padding(.bottom, 20)

                HStack {
                    ForEach(["Map Context", "Marker Context", "Quick Actions", "Affiliation"], id: \.self) { preset in
                        Button(preset) {
                            selectedPreset = preset
                            isPresented = true
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedPreset == preset ? Color(hex: "#FFFC00") : Color(hex: "#3A3A3A"))
                        .foregroundColor(selectedPreset == preset ? .black : .white)
                        .cornerRadius(4)
                    }
                }
            }

            if isPresented {
                RadialMenuView(
                    isPresented: $isPresented,
                    centerPoint: menuLocation,
                    configuration: currentConfiguration,
                    onSelect: { action in
                        lastAction = actionDescription(action)
                    }
                )
            }
        }
    }

    func actionDescription(_ action: RadialMenuAction) -> String {
        switch action {
        case .dropMarker(let affiliation):
            return "Drop \(affiliation.displayName)"
        case .measure:
            return "Measure"
        case .measureDistance:
            return "Measure Distance"
        case .measureArea:
            return "Measure Area"
        case .measureBearing:
            return "Measure Bearing"
        case .navigate:
            return "Navigate"
        case .createRoute:
            return "Create Route"
        case .addWaypoint:
            return "Add Waypoint"
        case .quickChat:
            return "Quick Chat"
        case .editMarker:
            return "Edit Marker"
        case .deleteMarker:
            return "Delete Marker"
        case .shareMarker:
            return "Share Marker"
        case .navigateToMarker:
            return "Navigate To"
        case .markerInfo:
            return "Marker Info"
        case .copyCoordinates:
            return "Copy Coordinates"
        case .setRangeRings:
            return "Set Range Rings"
        case .centerMap:
            return "Center Map"
        case .getInfo:
            return "Get Info"
        case .emergency:
            return "Emergency"
        case .openDrawingTools:
            return "Drawing Tools"
        case .openDrawingsList:
            return "Drawings List"
        case .drawLine:
            return "Draw Line"
        case .drawCircle:
            return "Draw Circle"
        case .drawPolygon:
            return "Draw Polygon"
        case .editDrawing:
            return "Edit Drawing"
        case .deleteDrawing:
            return "Delete Drawing"
        case .custom:
            return "Custom Action"
        }
    }
}
