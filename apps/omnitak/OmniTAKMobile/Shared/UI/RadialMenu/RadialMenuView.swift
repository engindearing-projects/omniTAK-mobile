//
//  RadialMenuView.swift
//  OmniTAKMobile
//
//  Main radial menu view that displays items in a circular arrangement
//  Modern glass-morphism design with smooth animations
//

import SwiftUI

// MARK: - Radial Menu View

/// SwiftUI view that displays menu items in a modern radial arrangement
struct RadialMenuView: View {
    @Binding var isPresented: Bool
    let centerPoint: CGPoint
    let configuration: RadialMenuConfiguration
    let onSelect: (RadialMenuAction) -> Void
    let onEvent: ((RadialMenuEvent) -> Void)?

    /// Optional context label to show in center (e.g., tapped location name)
    var centerLabel: String?

    @State private var selectedIndex: Int? = nil
    @State private var scale: CGFloat = 0
    @State private var itemsAppeared: Bool = false
    @State private var backgroundOpacity: Double = 0
    @State private var dragLocation: CGPoint? = nil

    /// Persistent preference for showing labels - toggle via center button
    @AppStorage("radialMenuShowLabels") private var showLabels: Bool = true

    // Haptic feedback generators
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    // ATAK-style tactical colors
    private let glassBgColor = Color(hex: "#1C1C1C").opacity(0.92)  // Dark charcoal
    private let glassStrokeColor = Color(hex: "#3A3A3A")  // Subtle gray border
    private let centerBgColor = Color(hex: "#2D2D2D")  // Slightly lighter center
    private let accentColor = Color(hex: "#4A90D9")  // ATAK blue accent

    init(
        isPresented: Binding<Bool>,
        centerPoint: CGPoint,
        configuration: RadialMenuConfiguration,
        onSelect: @escaping (RadialMenuAction) -> Void,
        onEvent: ((RadialMenuEvent) -> Void)? = nil,
        centerLabel: String? = nil
    ) {
        self._isPresented = isPresented
        self.centerPoint = centerPoint
        self.configuration = configuration
        self.onSelect = onSelect
        self.onEvent = onEvent
        self.centerLabel = centerLabel
    }

    var body: some View {
        ZStack {
            // Dimming background with blur effect
            Color.black
                .opacity(backgroundOpacity * 0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissMenu()
                }

            // Main radial menu
            ZStack {
                // Outer glass ring
                Circle()
                    .fill(glassBgColor)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)

                // Selection highlight arc (subtle glow)
                if let selected = selectedIndex {
                    SelectionArc(
                        index: selected,
                        totalItems: configuration.items.count,
                        innerRadius: centerCircleRadius + 8,
                        outerRadius: outerRingRadius - 4
                    )
                    .fill(
                        RadialGradient(
                            colors: [configuration.items[selected].color.opacity(0.4), Color.clear],
                            center: .center,
                            startRadius: centerCircleRadius,
                            endRadius: outerRingRadius
                        )
                    )
                    .animation(.easeOut(duration: 0.15), value: selected)
                }

                // Center circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#2A2A2A"), centerBgColor],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: centerCircleDiameter, height: centerCircleDiameter)
                    .overlay(
                        Circle()
                            .stroke(glassStrokeColor, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                // Center content - tappable to toggle labels
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showLabels.toggle()
                    }
                    if configuration.hapticFeedback {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }) {
                    ZStack {
                        if let label = centerLabel {
                            VStack(spacing: 2) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(accentColor)
                                Text(label)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                                    .frame(maxWidth: centerCircleDiameter - 12)
                            }
                        } else {
                            // Toggle indicator
                            VStack(spacing: 4) {
                                Image(systemName: showLabels ? "text.badge.checkmark" : "textformat.size")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(showLabels ? accentColor : .white.opacity(0.5))
                            }
                        }
                    }
                    .frame(width: centerCircleDiameter, height: centerCircleDiameter)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)

                // Radial menu items with icons
                ForEach(Array(configuration.items.enumerated()), id: \.element.id) { index, item in
                    RadialMenuItemButton(
                        item: item,
                        index: index,
                        isSelected: selectedIndex == index,
                        itemSize: effectiveItemSize,
                        offset: iconOffset(at: index),
                        appeared: itemsAppeared
                    )
                }

                // Labels outside the ring with pill background
                if showLabels {
                    ForEach(Array(configuration.items.enumerated()), id: \.element.id) { index, item in
                        Text(item.label)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.7))
                            )
                            .offset(labelOffset(at: index))
                            .opacity(itemsAppeared ? (selectedIndex == index ? 1.0 : 0.85) : 0)
                            .scaleEffect(selectedIndex == index ? 1.08 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double(index) * 0.02), value: itemsAppeared)
                            .animation(.easeOut(duration: 0.15), value: selectedIndex)
                    }
                }
            }
            .frame(width: totalMenuDiameter, height: totalMenuDiameter)
            .position(centerPoint)
            .scaleEffect(scale)

            // Drag gesture overlay
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDragChanged(value.location)
                        }
                        .onEnded { _ in
                            handleDragEnded()
                        }
                )
        }
        .onAppear {
            prepareHaptics()
            showMenu()
        }
        .onDisappear {
            hideMenu()
        }
    }

    // MARK: - Layout Calculations

    /// Larger item size for better touch targets (54pt minimum)
    private var effectiveItemSize: CGFloat {
        max(configuration.itemSize, 54)  // 54pt for good touch targets
    }

    /// Effective radius from configuration
    private var effectiveRadius: CGFloat {
        configuration.radius
    }

    /// Radius where icon centers are positioned - middle zone
    private var iconRingRadius: CGFloat {
        effectiveRadius * 0.52  // Position buttons closer to center for label room
    }

    /// Label ring radius - between buttons and outer edge
    private var labelRingRadius: CGFloat {
        iconRingRadius + (effectiveItemSize / 2) + 18  // Labels just outside buttons
    }

    /// Outer ring extends beyond labels to contain everything
    private var outerRingRadius: CGFloat {
        showLabels ? labelRingRadius + 28 : iconRingRadius + (effectiveItemSize / 2) + 10
    }

    private var outerRingDiameter: CGFloat {
        outerRingRadius * 2
    }

    private var centerCircleRadius: CGFloat {
        max(32, iconRingRadius - (effectiveItemSize / 2) - 4)  // Minimum 32pt center
    }

    private var centerCircleDiameter: CGFloat {
        centerCircleRadius * 2
    }

    /// Total diameter - same as outer ring since labels are inside
    private var totalMenuDiameter: CGFloat {
        outerRingDiameter
    }

    /// Calculate icon offset within the wedge
    private func iconOffset(at index: Int) -> CGSize {
        let itemCount = configuration.items.count
        let angleStep = (2 * Double.pi) / Double(itemCount)
        let angle = Double(index) * angleStep - (Double.pi / 2)  // Start from top

        // Position icons in a ring
        let x = iconRingRadius * CGFloat(cos(angle))
        let y = iconRingRadius * CGFloat(sin(angle))

        return CGSize(width: x, height: y)
    }

    /// Calculate label offset - positioned between buttons and outer edge
    private func labelOffset(at index: Int) -> CGSize {
        let itemCount = configuration.items.count
        let angleStep = (2 * Double.pi) / Double(itemCount)
        let angle = Double(index) * angleStep - (Double.pi / 2)  // Start from top

        // Position label inside the outer ring with padding from edge
        let x = labelRingRadius * CGFloat(cos(angle))
        let y = labelRingRadius * CGFloat(sin(angle))

        return CGSize(width: x, height: y)
    }

    // MARK: - Gesture Handling

    private func handleDragChanged(_ location: CGPoint) {
        dragLocation = location

        let newIndex = configuration.closestItemIndex(to: location, center: centerPoint)

        if newIndex != selectedIndex {
            selectedIndex = newIndex

            if let index = newIndex {
                // Provide haptic feedback on selection change
                if configuration.hapticFeedback {
                    selectionGenerator.selectionChanged()
                }
                onEvent?(.itemHighlighted(index))
            }
        }
    }

    private func handleDragEnded() {
        if let index = selectedIndex, index < configuration.items.count {
            let selectedItem = configuration.items[index]

            // Provide haptic feedback on selection
            if configuration.hapticFeedback {
                impactGenerator.impactOccurred()
            }

            // Execute action
            onSelect(selectedItem.action)
            onEvent?(.itemSelected(selectedItem.action))
        } else {
            onEvent?(.dismissed)
        }

        dismissMenu()
    }

    // MARK: - Menu State

    private func prepareHaptics() {
        if configuration.hapticFeedback {
            impactGenerator.prepare()
            selectionGenerator.prepare()
        }
    }

    private func showMenu() {
        onEvent?(.opened(centerPoint))

        // Initial scale animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            scale = 1.0
            backgroundOpacity = 1.0
        }

        // Staggered item appearance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                itemsAppeared = true
            }
        }

        // Haptic for menu open
        if configuration.hapticFeedback {
            impactGenerator.impactOccurred(intensity: 0.6)
        }
    }

    private func hideMenu() {
        withAnimation(.easeOut(duration: 0.15)) {
            itemsAppeared = false
        }
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 0
            backgroundOpacity = 0
        }
    }

    private func dismissMenu() {
        onEvent?(.dismissed)

        withAnimation(.easeOut(duration: 0.15)) {
            itemsAppeared = false
        }

        withAnimation(.easeOut(duration: 0.2).delay(0.05)) {
            scale = 0
            backgroundOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
        }
    }
}

// MARK: - Radial Menu Item Button

/// Individual menu item with icon and colored background
struct RadialMenuItemButton: View {
    let item: RadialMenuItem
    let index: Int
    let isSelected: Bool
    let itemSize: CGFloat
    let offset: CGSize
    let appeared: Bool

    private var isDestructive: Bool {
        item.action == .deleteMarker || item.action == .deleteDrawing
    }

    private var itemColor: Color {
        isDestructive ? .red : item.color
    }

    var body: some View {
        ZStack {
            // Background circle with color
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            itemColor.opacity(isSelected ? 1.0 : 0.85),
                            itemColor.opacity(isSelected ? 0.9 : 0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: itemSize, height: itemSize)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.4 : 0.2), lineWidth: 1)
                )
                .shadow(
                    color: itemColor.opacity(isSelected ? 0.6 : 0.3),
                    radius: isSelected ? 12 : 6,
                    x: 0,
                    y: isSelected ? 4 : 2
                )

            // Icon - larger for better visibility and easier recognition
            Image(systemName: item.icon)
                .font(.system(size: itemSize * 0.52, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
        }
        .scaleEffect(appeared ? (isSelected ? 1.15 : 1.0) : 0.3)
        .opacity(appeared ? 1.0 : 0)
        .offset(offset)
        .animation(.spring(response: 0.35, dampingFraction: 0.65).delay(Double(index) * 0.03), value: appeared)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Selection Arc Shape

/// Arc shape for selection highlight
struct SelectionArc: Shape {
    let index: Int
    let totalItems: Int
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let angleStep = (2 * Double.pi) / Double(totalItems)

        let startAngle = Double(index) * angleStep - (Double.pi / 2) - (angleStep / 2)
        let endAngle = startAngle + angleStep

        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .radians(startAngle),
            endAngle: .radians(endAngle),
            clockwise: false
        )

        path.addLine(to: CGPoint(
            x: center.x + outerRadius * CGFloat(cos(endAngle)),
            y: center.y + outerRadius * CGFloat(sin(endAngle))
        ))

        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .radians(endAngle),
            endAngle: .radians(startAngle),
            clockwise: true
        )

        path.closeSubpath()

        return path
    }
}

// MARK: - Wedge Shapes for ATAK-style Pie Menu

/// Shape for a single pie wedge divider line
struct WedgeDivider: Shape {
    let index: Int
    let totalItems: Int
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let angleStep = (2 * Double.pi) / Double(totalItems)
        // Offset by half a wedge so dividers are between items
        let angle = Double(index) * angleStep - (Double.pi / 2) - (angleStep / 2)

        let innerPoint = CGPoint(
            x: center.x + innerRadius * CGFloat(cos(angle)),
            y: center.y + innerRadius * CGFloat(sin(angle))
        )
        let outerPoint = CGPoint(
            x: center.x + outerRadius * CGFloat(cos(angle)),
            y: center.y + outerRadius * CGFloat(sin(angle))
        )

        path.move(to: innerPoint)
        path.addLine(to: outerPoint)

        return path
    }
}

/// Shape for a filled pie wedge (used for selection highlight)
struct WedgeShape: Shape {
    let index: Int
    let totalItems: Int
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let angleStep = (2 * Double.pi) / Double(totalItems)

        // Calculate start and end angles for this wedge
        let startAngle = Double(index) * angleStep - (Double.pi / 2) - (angleStep / 2)
        let endAngle = startAngle + angleStep

        // Draw arc from inner radius
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .radians(startAngle),
            endAngle: .radians(endAngle),
            clockwise: false
        )

        // Draw line to outer radius
        path.addLine(to: CGPoint(
            x: center.x + outerRadius * CGFloat(cos(endAngle)),
            y: center.y + outerRadius * CGFloat(sin(endAngle))
        ))

        // Draw arc along outer radius (in reverse)
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .radians(endAngle),
            endAngle: .radians(startAngle),
            clockwise: true
        )

        // Close path back to start
        path.closeSubpath()

        return path
    }
}

// MARK: - Radial Menu Modifier

/// View modifier to add radial menu capability to any view
struct RadialMenuModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var menuLocation: CGPoint
    let configuration: RadialMenuConfiguration
    let onSelect: (RadialMenuAction) -> Void
    let onEvent: ((RadialMenuEvent) -> Void)?
    let centerLabel: String?

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                RadialMenuView(
                    isPresented: $isPresented,
                    centerPoint: menuLocation,
                    configuration: configuration,
                    onSelect: onSelect,
                    onEvent: onEvent,
                    centerLabel: centerLabel
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(999)
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Add a radial menu overlay to this view
    func radialMenu(
        isPresented: Binding<Bool>,
        location: Binding<CGPoint>,
        configuration: RadialMenuConfiguration,
        onSelect: @escaping (RadialMenuAction) -> Void,
        onEvent: ((RadialMenuEvent) -> Void)? = nil,
        centerLabel: String? = nil
    ) -> some View {
        self.modifier(
            RadialMenuModifier(
                isPresented: isPresented,
                menuLocation: location,
                configuration: configuration,
                onSelect: onSelect,
                onEvent: onEvent,
                centerLabel: centerLabel
            )
        )
    }
}

// MARK: - Preview

struct RadialMenuView_Previews: PreviewProvider {
    static var previews: some View {
        RadialMenuPreviewWrapper()
            .preferredColorScheme(.dark)
    }
}

struct RadialMenuPreviewWrapper: View {
    @State private var isPresented = true
    @State private var selectedAction: String = "None"

    var body: some View {
        ZStack {
            // Simulated map background
            Color(hex: "#2A3A2A")
                .ignoresSafeArea()

            VStack {
                Text("Selected: \(selectedAction)")
                    .foregroundColor(.white)
                    .padding()

                Button("Show Menu") {
                    isPresented = true
                }
                .foregroundColor(Color(hex: "#FFFC00"))
            }

            if isPresented {
                RadialMenuView(
                    isPresented: $isPresented,
                    centerPoint: CGPoint(x: 200, y: 400),
                    configuration: RadialMenuConfiguration(
                        items: [
                            // ATAK-style map context menu (8 items like real ATAK)
                            RadialMenuItem(
                                icon: "mappin.circle.fill",
                                label: "Drop Point",
                                action: .addWaypoint
                            ),
                            RadialMenuItem(
                                icon: "play.rectangle.fill",
                                label: "Video",
                                action: .custom("video")
                            ),
                            RadialMenuItem(
                                icon: "antenna.radiowaves.left.and.right",
                                label: "Broadcast",
                                action: .custom("broadcast")
                            ),
                            RadialMenuItem(
                                icon: "doc.text.fill",
                                label: "Details",
                                action: .getInfo
                            ),
                            RadialMenuItem(
                                icon: "trash.fill",
                                label: "Delete",
                                action: .deleteMarker
                            ),
                            RadialMenuItem(
                                icon: "antenna.radiowaves.left.and.right.slash",
                                label: "Mesh",
                                action: .custom("mesh")
                            ),
                            RadialMenuItem(
                                icon: "magnifyingglass",
                                label: "Search",
                                action: .custom("search")
                            ),
                            RadialMenuItem(
                                icon: "viewfinder",
                                label: "Target",
                                action: .custom("target")
                            )
                        ],
                        radius: 120,
                        itemSize: 48
                    ),
                    onSelect: { action in
                        switch action {
                        case .addWaypoint:
                            selectedAction = "Drop Point"
                        case .deleteMarker:
                            selectedAction = "Delete"
                        case .getInfo:
                            selectedAction = "Details"
                        case .custom(let id):
                            selectedAction = id.capitalized
                        default:
                            selectedAction = "Other"
                        }
                    },
                    centerLabel: "Eden Valley"
                )
            }
        }
    }
}
