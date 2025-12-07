//
//  VerticalQuickActionMenu.swift
//  OmniTAKMobile
//
//  ATAK-style horizontal quick action menu with semi-transparent circular buttons
//  Positioned in top-right area
//

import SwiftUI
import CoreLocation

struct VerticalQuickActionMenu: View {
    // Map state bindings
    @Binding var showMeasurement: Bool
    @Binding var showDrawingPanel: Bool
    @Binding var showLayersPanel: Bool
    @Binding var showEmergencySOS: Bool
    @Binding var showToolsMenu: Bool
    @Binding var isCursorModeActive: Bool

    // Location for zoom action
    let userLocation: CLLocationCoordinate2D?
    let onZoomToSelf: () -> Void
    let onDropPoint: () -> Void

    @State private var isVisible = true
    @ObservedObject private var pluginManager = PluginSettingsManager.shared

    var body: some View {
        HStack(spacing: 6) {
            // Zoom to Self (always enabled)
            QuickActionCircularButton(
                icon: "location.fill",
                isActive: false,
                isEnabled: true,
                color: .white,
                action: {
                    onZoomToSelf()
                }
            )
            .accessibilityLabel("Zoom to my location")

            // Drop Point (always enabled - core feature)
            QuickActionCircularButton(
                icon: "mappin.circle.fill",
                isActive: isCursorModeActive,
                isEnabled: true,
                color: .white,
                action: {
                    onDropPoint()
                }
            )
            .accessibilityLabel("Drop waypoint")

            // Measure Tool
            QuickActionCircularButton(
                icon: "ruler",
                isActive: showMeasurement,
                isEnabled: pluginManager.isEnabled(.measurementTools),
                color: .white,
                action: {
                    if pluginManager.isEnabled(.measurementTools) {
                        showMeasurement.toggle()
                    }
                }
            )
            .accessibilityLabel("Measurement tool")

            // Drawing Tools
            QuickActionCircularButton(
                icon: "pencil.tip.crop.circle",
                isActive: showDrawingPanel,
                isEnabled: pluginManager.isEnabled(.drawingTools),
                color: .white,
                action: {
                    if pluginManager.isEnabled(.drawingTools) {
                        showDrawingPanel.toggle()
                    }
                }
            )
            .accessibilityLabel("Drawing tools")

            // Layers (always enabled - core feature)
            QuickActionCircularButton(
                icon: "square.3.layers.3d",
                isActive: showLayersPanel,
                isEnabled: true,
                color: .white,
                action: {
                    showLayersPanel.toggle()
                }
            )
            .accessibilityLabel("Map layers")

            // Emergency SOS (Red accent)
            QuickActionCircularButton(
                icon: "exclamationmark.triangle.fill",
                isActive: showEmergencySOS,
                isEnabled: pluginManager.isEnabled(.emergencyBeacon),
                color: Color(hex: "#FF5252"),
                action: {
                    if pluginManager.isEnabled(.emergencyBeacon) {
                        showEmergencySOS.toggle()
                    }
                }
            )
            .accessibilityLabel("Emergency SOS")

            // Tools Menu (always enabled)
            QuickActionCircularButton(
                icon: "ellipsis.circle",
                isActive: showToolsMenu,
                isEnabled: true,
                color: .white,
                action: {
                    showToolsMenu.toggle()
                }
            )
            .accessibilityLabel("More tools")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        )
        .opacity(isVisible ? 1.0 : 0.0)
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
}

// MARK: - Circular Action Button

private struct QuickActionCircularButton: View {
    let icon: String
    let isActive: Bool
    var isEnabled: Bool = true
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            action()
        }) {
            ZStack {
                // Background circle
                Circle()
                    .fill(backgroundFillColor)
                    .frame(width: 36, height: 36)

                // Active border
                if isActive && isEnabled {
                    Circle()
                        .strokeBorder(Color(hex: "#FFFC00"), lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                        .shadow(color: Color(hex: "#FFFC00").opacity(0.5), radius: 3, x: 0, y: 0)
                }

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(iconColor)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .opacity(isEnabled ? 1.0 : 0.4)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled else { return }
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }

    private var backgroundFillColor: Color {
        if !isEnabled {
            return Color.black.opacity(0.3)
        }
        return isActive ? Color(hex: "#FFFC00").opacity(0.3) : Color.black.opacity(0.6)
    }

    private var iconColor: Color {
        if !isEnabled {
            return .gray.opacity(0.5)
        }
        return isActive ? Color(hex: "#FFFC00") : color
    }
}

// MARK: - Preview

#if DEBUG
struct VerticalQuickActionMenu_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Simulate map background
            Color.gray.edgesIgnoringSafeArea(.all)

            HStack {
                Spacer()

                VerticalQuickActionMenu(
                    showMeasurement: .constant(false),
                    showDrawingPanel: .constant(false),
                    showLayersPanel: .constant(true),
                    showEmergencySOS: .constant(false),
                    showToolsMenu: .constant(false),
                    isCursorModeActive: .constant(false),
                    userLocation: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
                    onZoomToSelf: { print("Zoom to self") },
                    onDropPoint: { print("Drop point") }
                )
                .padding(.trailing, 16)
                .padding(.bottom, 140)
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif
