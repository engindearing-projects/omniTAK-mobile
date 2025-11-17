//
//  RadialMenuView.swift
//  OmniTAKMobile
//
//  Main radial menu view that displays items in a circular arrangement
//

import SwiftUI

// MARK: - Radial Menu View

/// SwiftUI view that displays menu items in a circle around a center point
struct RadialMenuView: View {
    @Binding var isPresented: Bool
    let centerPoint: CGPoint
    let configuration: RadialMenuConfiguration
    let onSelect: (RadialMenuAction) -> Void
    let onEvent: ((RadialMenuEvent) -> Void)?

    @State private var selectedIndex: Int? = nil
    @State private var scale: CGFloat = 0
    @State private var backgroundOpacity: Double = 0
    @State private var dragLocation: CGPoint? = nil

    // Haptic feedback generators
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    init(
        isPresented: Binding<Bool>,
        centerPoint: CGPoint,
        configuration: RadialMenuConfiguration,
        onSelect: @escaping (RadialMenuAction) -> Void,
        onEvent: ((RadialMenuEvent) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.centerPoint = centerPoint
        self.configuration = configuration
        self.onSelect = onSelect
        self.onEvent = onEvent
    }

    var body: some View {
        ZStack {
            // Dimming background
            Color.black
                .opacity(backgroundOpacity * configuration.backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissMenu()
                }

            // Blur effect behind menu
            if #available(iOS 15.0, *) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: configuration.radius * 2.5, height: configuration.radius * 2.5)
                    .position(centerPoint)
                    .opacity(backgroundOpacity)
            }

            // Center indicator
            Circle()
                .fill(configuration.accentColor.opacity(0.3))
                .frame(width: 20, height: 20)
                .scaleEffect(scale)
                .position(centerPoint)

            // Radial menu items
            ForEach(Array(configuration.items.enumerated()), id: \.element.id) { index, item in
                let position = configuration.itemPosition(at: index, center: centerPoint)

                RadialMenuItemView(
                    item: item,
                    isSelected: selectedIndex == index,
                    size: configuration.itemSize,
                    showLabel: configuration.showLabels,
                    animationDelay: Double(index) * 0.03
                )
                .position(position)
                .scaleEffect(scale)
            }

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

// MARK: - Radial Menu Modifier

/// View modifier to add radial menu capability to any view
struct RadialMenuModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var menuLocation: CGPoint
    let configuration: RadialMenuConfiguration
    let onSelect: (RadialMenuAction) -> Void
    let onEvent: ((RadialMenuEvent) -> Void)?

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                RadialMenuView(
                    isPresented: $isPresented,
                    centerPoint: menuLocation,
                    configuration: configuration,
                    onSelect: onSelect,
                    onEvent: onEvent
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
        onEvent: ((RadialMenuEvent) -> Void)? = nil
    ) -> some View {
        self.modifier(
            RadialMenuModifier(
                isPresented: isPresented,
                menuLocation: location,
                configuration: configuration,
                onSelect: onSelect,
                onEvent: onEvent
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
            Color(hex: "#1E1E1E")
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
                        itemSize: 50
                    ),
                    onSelect: { action in
                        switch action {
                        case .dropMarker(let affiliation):
                            selectedAction = "Drop \(affiliation.displayName)"
                        case .measure:
                            selectedAction = "Measure"
                        case .navigate:
                            selectedAction = "Navigate"
                        case .addWaypoint:
                            selectedAction = "Add Waypoint"
                        default:
                            selectedAction = "Other"
                        }
                    }
                )
            }
        }
    }
}
