//
//  RadialMenuView.swift
//  OmniTAKMobile
//
//  Main radial menu view that displays items in a circular arrangement
//  ATAK-style pie wedge design with monochrome icons
//

import SwiftUI

// MARK: - Radial Menu View

/// SwiftUI view that displays menu items in ATAK-style pie wedge arrangement
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
    @State private var backgroundOpacity: Double = 0
    @State private var dragLocation: CGPoint? = nil

    /// Persistent preference for showing labels - toggle via center button
    @AppStorage("radialMenuShowLabels") private var showLabels: Bool = true

    // Haptic feedback generators
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    // ATAK-style colors
    private let ringBackgroundColor = Color(hex: "#E8E4D9")  // Cream/off-white like ATAK
    private let centerBackgroundColor = Color(hex: "#3A3A3A")  // Dark center
    private let dividerColor = Color(hex: "#CCCCCC")  // Light gray dividers
    private let iconColor = Color(hex: "#2A2A2A")  // Dark icons

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
            // Dimming background
            Color.black
                .opacity(backgroundOpacity * 0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissMenu()
                }

            // Main radial menu
            ZStack {
                // Outer ring background (cream/white)
                Circle()
                    .fill(ringBackgroundColor)

                // Pie wedge dividers
                ForEach(0..<configuration.items.count, id: \.self) { index in
                    WedgeDivider(
                        index: index,
                        totalItems: configuration.items.count,
                        innerRadius: centerCircleRadius,
                        outerRadius: outerRingRadius
                    )
                    .stroke(dividerColor, lineWidth: 1)
                }

                // Selection highlight wedge
                if let selected = selectedIndex {
                    WedgeShape(
                        index: selected,
                        totalItems: configuration.items.count,
                        innerRadius: centerCircleRadius,
                        outerRadius: outerRingRadius
                    )
                    .fill(Color.black.opacity(0.1))
                }

                // Center dark circle
                Circle()
                    .fill(centerBackgroundColor)
                    .frame(width: centerCircleDiameter, height: centerCircleDiameter)

                // Center circle border
                Circle()
                    .strokeBorder(dividerColor, lineWidth: 1)
                    .frame(width: centerCircleDiameter, height: centerCircleDiameter)

                // Center content - tappable to toggle labels
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showLabels.toggle()
                    }
                    // Haptic feedback for toggle
                    if configuration.hapticFeedback {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }) {
                    ZStack {
                        if let label = centerLabel {
                            VStack(spacing: 2) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                Text(label)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .frame(maxWidth: centerCircleDiameter - 8)
                            }
                        } else {
                            // Toggle indicator: "Aa" when labels hidden, dot when shown
                            if showLabels {
                                Circle()
                                    .fill(Color(hex: "#FFFC00"))
                                    .frame(width: 12, height: 12)
                            } else {
                                Text("Aa")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    .frame(width: centerCircleDiameter, height: centerCircleDiameter)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)

                // Radial menu item icons
                ForEach(Array(configuration.items.enumerated()), id: \.element.id) { index, item in
                    let isDestructive = item.action == .deleteMarker || item.action == .deleteDrawing

                    Image(systemName: item.icon)
                        .font(.system(size: configuration.itemSize * 0.45, weight: .medium))
                        .foregroundColor(isDestructive ? .red : iconColor)
                        .scaleEffect(selectedIndex == index ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: selectedIndex)
                        .offset(iconOffset(at: index))
                }

                // Radial menu item labels (when enabled)
                if showLabels {
                    ForEach(Array(configuration.items.enumerated()), id: \.element.id) { index, item in
                        Text(item.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                            .offset(labelOffset(at: index))
                            .opacity(selectedIndex == index ? 1.0 : 0.85)
                            .animation(.easeInOut(duration: 0.15), value: selectedIndex)
                    }
                }

                // Outer ring border
                Circle()
                    .strokeBorder(dividerColor, lineWidth: 1.5)
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

    /// Effective radius - larger when labels are shown to make room
    private var effectiveRadius: CGFloat {
        showLabels ? configuration.radius * 1.15 : configuration.radius
    }

    private var outerRingRadius: CGFloat {
        effectiveRadius
    }

    private var outerRingDiameter: CGFloat {
        effectiveRadius * 2
    }

    private var centerCircleRadius: CGFloat {
        effectiveRadius * 0.38  // ~38% of outer radius for center circle
    }

    private var centerCircleDiameter: CGFloat {
        centerCircleRadius * 2
    }

    /// Radius for label text positioning (outside the icon ring)
    private var labelRadius: CGFloat {
        effectiveRadius * 0.72  // Position labels between center and edge
    }

    /// Total diameter including space for labels
    private var totalMenuDiameter: CGFloat {
        showLabels ? outerRingDiameter + 80 : outerRingDiameter  // Extra space for labels
    }

    /// Calculate icon offset within the wedge (centered between inner and outer radius)
    private func iconOffset(at index: Int) -> CGSize {
        let itemCount = configuration.items.count
        let angleStep = (2 * Double.pi) / Double(itemCount)
        let angle = Double(index) * angleStep - (Double.pi / 2)  // Start from top

        // Position icon at midpoint between center circle and outer edge
        let iconRadius = (centerCircleRadius + outerRingRadius) / 2

        let x = iconRadius * CGFloat(cos(angle))
        let y = iconRadius * CGFloat(sin(angle))

        return CGSize(width: x, height: y)
    }

    /// Calculate label offset - positioned outside the menu ring
    private func labelOffset(at index: Int) -> CGSize {
        let itemCount = configuration.items.count
        let angleStep = (2 * Double.pi) / Double(itemCount)
        let angle = Double(index) * angleStep - (Double.pi / 2)  // Start from top

        // Position label outside the outer ring
        let labelDistanceFromCenter = outerRingRadius + 18

        let x = labelDistanceFromCenter * CGFloat(cos(angle))
        let y = labelDistanceFromCenter * CGFloat(sin(angle))

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

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            scale = 1.0
            backgroundOpacity = 1.0
        }
    }

    private func hideMenu() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 0
            backgroundOpacity = 0
        }
    }

    private func dismissMenu() {
        onEvent?(.dismissed)

        withAnimation(.easeOut(duration: 0.2)) {
            scale = 0
            backgroundOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
        }
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
