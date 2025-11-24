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
    /// Actions: Mark Hostile, Mark Friendly, Measure Distance, Navigate Here, Add Waypoint
    static var mapContextMenu: RadialMenuConfiguration {
        RadialMenuConfiguration(
            items: [
                RadialMenuItem(
                    icon: "exclamationmark.triangle.fill",
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
                    icon: "ruler",
                    label: "Measure",
                    color: Color(hex: "#FFFC00"),
                    action: .measure
                ),
                RadialMenuItem(
                    icon: "location.fill",
                    label: "Navigate",
                    color: .green,
                    action: .navigate
                ),
                RadialMenuItem(
                    icon: "mappin.and.ellipse",
                    label: "Waypoint",
                    color: .orange,
                    action: .addWaypoint
                )
            ],
            radius: 100,
            itemSize: 50,
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
                    color: Color(hex: "#FFFC00"),
                    action: .editMarker
                ),
                RadialMenuItem(
                    icon: "trash.fill",
                    label: "Delete",
                    color: .red,
                    action: .deleteMarker
                ),
                RadialMenuItem(
                    icon: "square.and.arrow.up.fill",
                    label: "Share",
                    color: .blue,
                    action: .shareMarker
                ),
                RadialMenuItem(
                    icon: "arrow.triangle.turn.up.right.circle.fill",
                    label: "Navigate",
                    color: .green,
                    action: .navigate
                ),
                RadialMenuItem(
                    icon: "info.circle.fill",
                    label: "Info",
                    color: .gray,
                    action: .getInfo
                )
            ],
            radius: 100,
            itemSize: 50,
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
                    color: Color(hex: "#FFFC00"),
                    action: .addWaypoint
                ),
                RadialMenuItem(
                    icon: "point.topleft.down.curvedto.point.bottomright.up.fill",
                    label: "Route",
                    color: .orange,
                    action: .createRoute
                ),
                RadialMenuItem(
                    icon: "bubble.left.fill",
                    label: "Chat",
                    color: .blue,
                    action: .quickChat
                ),
                RadialMenuItem(
                    icon: "dot.radiowaves.left.and.right",
                    label: "Mesh",
                    color: .green,
                    action: .custom("meshtastic")
                ),
                RadialMenuItem(
                    icon: "exclamationmark.octagon.fill",
                    label: "Emergency",
                    color: .red,
                    action: .emergency
                )
            ],
            radius: 90,
            itemSize: 55,
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
                    color: .cyan,
                    action: .dropMarker(.friendly)
                ),
                RadialMenuItem(
                    icon: "exclamationmark.triangle.fill",
                    label: "Hostile",
                    color: .red,
                    action: .dropMarker(.hostile)
                ),
                RadialMenuItem(
                    icon: "questionmark.circle.fill",
                    label: "Unknown",
                    color: .yellow,
                    action: .dropMarker(.unknown)
                ),
                RadialMenuItem(
                    icon: "circle.fill",
                    label: "Neutral",
                    color: .green,
                    action: .dropMarker(.neutral)
                )
            ],
            radius: 85,
            itemSize: 55,
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
                    color: Color(hex: "#FFFC00"),
                    action: .measure
                ),
                RadialMenuItem(
                    icon: "arrow.up.left.and.arrow.down.right",
                    label: "Area",
                    color: .orange,
                    action: .custom("placeholder")
                ),
                RadialMenuItem(
                    icon: "scope",
                    label: "Bearing",
                    color: .cyan,
                    action: .custom("placeholder")
                ),
                RadialMenuItem(
                    icon: "mountain.2.fill",
                    label: "Elevation",
                    color: .green,
                    action: .custom("placeholder")
                )
            ],
            radius: 95,
            itemSize: 50,
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
                    color: .green,
                    action: .navigate
                ),
                RadialMenuItem(
                    icon: "map.fill",
                    label: "Route",
                    color: .blue,
                    action: .createRoute
                ),
                RadialMenuItem(
                    icon: "mappin.and.ellipse",
                    label: "Waypoint",
                    color: .orange,
                    action: .addWaypoint
                ),
                RadialMenuItem(
                    icon: "location.north.line.fill",
                    label: "Center",
                    color: Color(hex: "#FFFC00"),
                    action: .custom("placeholder")
                )
            ],
            radius: 95,
            itemSize: 50,
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
                    color: Color(hex: "#FFFC00"),
                    action: .addWaypoint
                ),
                RadialMenuItem(
                    icon: "info.circle.fill",
                    label: "Info",
                    color: .blue,
                    action: .getInfo
                ),
                RadialMenuItem(
                    icon: "xmark.circle.fill",
                    label: "Cancel",
                    color: .red,
                    action: .custom("placeholder")
                )
            ],
            radius: 70,
            itemSize: 45,
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
        case .custom:
            return "Custom Action"
        }
    }
}
