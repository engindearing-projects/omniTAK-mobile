//
//  RadialMenuGestureHandler.swift
//  OmniTAKMobile
//
//  UILongPressGestureRecognizer wrapper for SwiftUI to handle radial menu gestures
//

import SwiftUI
import UIKit

// MARK: - Long Press Gesture Recognizer

/// UIViewRepresentable wrapper for UILongPressGestureRecognizer
struct LongPressGestureView: UIViewRepresentable {
    let minimumPressDuration: TimeInterval
    let onLongPressStarted: (CGPoint) -> Void
    let onLocationChanged: (CGPoint) -> Void
    let onLongPressEnded: (CGPoint) -> Void
    let onLongPressCancelled: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPressGesture.minimumPressDuration = minimumPressDuration
        longPressGesture.allowableMovement = CGFloat.greatestFiniteMagnitude

        view.addGestureRecognizer(longPressGesture)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let parent: LongPressGestureView

        init(_ parent: LongPressGestureView) {
            self.parent = parent
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            let location = gesture.location(in: gesture.view)

            switch gesture.state {
            case .began:
                parent.onLongPressStarted(location)
            case .changed:
                parent.onLocationChanged(location)
            case .ended:
                parent.onLongPressEnded(location)
            case .cancelled, .failed:
                parent.onLongPressCancelled()
            default:
                break
            }
        }
    }
}

// MARK: - Radial Menu Gesture Handler

/// Complete gesture handler for the radial menu
struct RadialMenuGestureHandler: ViewModifier {
    @Binding var isMenuPresented: Bool
    @Binding var menuLocation: CGPoint
    let configuration: RadialMenuConfiguration
    let minimumPressDuration: TimeInterval
    let onSelect: (RadialMenuAction) -> Void
    let onEvent: ((RadialMenuEvent) -> Void)?

    @State private var currentDragLocation: CGPoint = .zero
    @State private var selectedIndex: Int? = nil

    private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    init(
        isMenuPresented: Binding<Bool>,
        menuLocation: Binding<CGPoint>,
        configuration: RadialMenuConfiguration,
        minimumPressDuration: TimeInterval = 0.5,
        onSelect: @escaping (RadialMenuAction) -> Void,
        onEvent: ((RadialMenuEvent) -> Void)? = nil
    ) {
        self._isMenuPresented = isMenuPresented
        self._menuLocation = menuLocation
        self.configuration = configuration
        self.minimumPressDuration = minimumPressDuration
        self.onSelect = onSelect
        self.onEvent = onEvent
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                LongPressGestureView(
                    minimumPressDuration: minimumPressDuration,
                    onLongPressStarted: handleLongPressStarted,
                    onLocationChanged: handleLocationChanged,
                    onLongPressEnded: handleLongPressEnded,
                    onLongPressCancelled: handleLongPressCancelled
                )
            )
    }

    // MARK: - Gesture Handlers

    private func handleLongPressStarted(_ location: CGPoint) {
        // Prepare haptic feedback
        impactGenerator.prepare()
        selectionGenerator.prepare()

        // Trigger haptic feedback for menu appearance
        if configuration.hapticFeedback {
            impactGenerator.impactOccurred()
        }

        // Set menu location and present
        menuLocation = location
        isMenuPresented = true
        currentDragLocation = location
        selectedIndex = nil

        onEvent?(.opened(location))
    }

    private func handleLocationChanged(_ location: CGPoint) {
        currentDragLocation = location

        // Calculate which item is being hovered over
        let newIndex = configuration.closestItemIndex(to: location, center: menuLocation)

        if newIndex != selectedIndex {
            selectedIndex = newIndex

            if let index = newIndex, configuration.hapticFeedback {
                selectionGenerator.selectionChanged()
                onEvent?(.itemHighlighted(index))
            }
        }
    }

    private func handleLongPressEnded(_ location: CGPoint) {
        guard isMenuPresented else { return }

        let finalIndex = configuration.closestItemIndex(to: location, center: menuLocation)

        if let index = finalIndex, index < configuration.items.count {
            let selectedItem = configuration.items[index]

            // Trigger selection haptic
            if configuration.hapticFeedback {
                impactGenerator.impactOccurred()
            }

            onSelect(selectedItem.action)
            onEvent?(.itemSelected(selectedItem.action))
        } else {
            onEvent?(.dismissed)
        }

        isMenuPresented = false
        selectedIndex = nil
    }

    private func handleLongPressCancelled() {
        isMenuPresented = false
        selectedIndex = nil
        onEvent?(.dismissed)
    }
}

// MARK: - View Extension for Radial Menu Gesture

extension View {
    /// Add radial menu gesture handling to a view
    func radialMenuGesture(
        isPresented: Binding<Bool>,
        location: Binding<CGPoint>,
        configuration: RadialMenuConfiguration,
        minimumPressDuration: TimeInterval = 0.5,
        onSelect: @escaping (RadialMenuAction) -> Void,
        onEvent: ((RadialMenuEvent) -> Void)? = nil
    ) -> some View {
        self.modifier(
            RadialMenuGestureHandler(
                isMenuPresented: isPresented,
                menuLocation: location,
                configuration: configuration,
                minimumPressDuration: minimumPressDuration,
                onSelect: onSelect,
                onEvent: onEvent
            )
        )
    }
}

// MARK: - Tap Location Modifier

/// Helper modifier to get tap location
struct TapLocationModifier: ViewModifier {
    let onTap: (CGPoint) -> Void

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // iOS 15 compatible - tap triggers action without location
                            onTap(.zero)
                        }
                }
            )
    }
}

extension View {
    /// Get the location of a tap gesture
    func onTapWithLocation(_ action: @escaping (CGPoint) -> Void) -> some View {
        self.modifier(TapLocationModifier(onTap: action))
    }
}

// MARK: - Preview

struct RadialMenuGestureHandler_Previews: PreviewProvider {
    static var previews: some View {
        GestureHandlerPreviewWrapper()
            .preferredColorScheme(.dark)
    }
}

struct GestureHandlerPreviewWrapper: View {
    @State private var isMenuPresented = false
    @State private var menuLocation: CGPoint = .zero
    @State private var lastAction: String = "Long press anywhere"

    var body: some View {
        ZStack {
            Color(hex: "#1E1E1E")
                .ignoresSafeArea()

            VStack {
                Text(lastAction)
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding()

                Text("Long press on the screen to open radial menu")
                    .foregroundColor(Color(hex: "#CCCCCC"))
                    .font(.subheadline)
            }
        }
        .radialMenuGesture(
            isPresented: $isMenuPresented,
            location: $menuLocation,
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
                    )
                ]
            ),
            onSelect: { action in
                switch action {
                case .dropMarker(let affiliation):
                    lastAction = "Selected: Drop \(affiliation.displayName)"
                case .measure:
                    lastAction = "Selected: Measure"
                case .navigate:
                    lastAction = "Selected: Navigate"
                default:
                    lastAction = "Selected: Action"
                }
            }
        )
        .radialMenu(
            isPresented: $isMenuPresented,
            location: $menuLocation,
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
                    )
                ]
            ),
            onSelect: { _ in }
        )
    }
}
