//
//  QuickActionToolbar.swift
//  OmniTAKMobile
//
//  ATAK-style bottom quick-action toolbar for rapid map operations
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Quick Action Toolbar

/// ATAK-style horizontal toolbar fixed at bottom of map view
struct QuickActionToolbar: View {
    @Binding var mapRegion: MKCoordinateRegion
    @Binding var showGrid: Bool
    @Binding var showLayersPanel: Bool
    @Binding var isCursorModeActive: Bool

    let userLocation: CLLocation?
    let onDropPoint: (CLLocationCoordinate2D) -> Void
    let onToggleMeasure: () -> Void

    @State private var measureModeActive = false

    var body: some View {
        HStack(spacing: 6) {
            // Drop Point at current location
            QuickActionButton(
                icon: "mappin.circle.fill",
                label: "Drop",
                isActive: false
            ) {
                if let location = userLocation {
                    onDropPoint(location.coordinate)
                }
            }

            // Measure Tool Toggle
            QuickActionButton(
                icon: "ruler",
                label: "Measure",
                isActive: measureModeActive
            ) {
                measureModeActive.toggle()
                onToggleMeasure()
            }

            // Cursor Mode Toggle
            QuickActionButton(
                icon: "scope",
                label: "Cursor",
                isActive: isCursorModeActive
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCursorModeActive.toggle()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Color.black.opacity(0.8)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
        )
    }
}

// MARK: - Quick Action Button

/// Individual button in the quick action toolbar
struct QuickActionButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)

                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(labelColor)
            }
            .frame(width: 44, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: isActive ? 1.5 : 0)
            )
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var iconColor: Color {
        if isActive {
            return Color(hex: "#FFFF00") // ATAK yellow
        }
        return .white
    }

    private var labelColor: Color {
        if isActive {
            return Color(hex: "#FFFF00").opacity(0.9)
        }
        return .white.opacity(0.8)
    }

    private var backgroundColor: Color {
        if isActive {
            return Color(hex: "#FFFF00").opacity(0.15)
        }
        if isPressed {
            return .white.opacity(0.1)
        }
        return .clear
    }

    private var borderColor: Color {
        if isActive {
            return Color(hex: "#FFFF00").opacity(0.5)
        }
        return .clear
    }
}

// MARK: - Compact Quick Action Bar

/// More compact version with just icons
struct CompactQuickActionBar: View {
    @Binding var showGrid: Bool
    @Binding var isCursorModeActive: Bool

    let onZoomToSelf: () -> Void
    let onDropPoint: () -> Void
    let onToggleMeasure: () -> Void
    let onShowLayers: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CompactActionIcon(icon: "location.fill") {
                onZoomToSelf()
            }

            CompactActionIcon(icon: "mappin.circle.fill") {
                onDropPoint()
            }

            CompactActionIcon(icon: "ruler") {
                onToggleMeasure()
            }

            CompactActionIcon(icon: "square.3.layers.3d") {
                onShowLayers()
            }

            CompactActionIcon(icon: "scope", isActive: isCursorModeActive) {
                isCursorModeActive.toggle()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.8))
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
        )
    }
}

// MARK: - Compact Action Icon

struct CompactActionIcon: View {
    let icon: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isActive ? Color(hex: "#FFFF00") : .white)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extended Quick Action Toolbar

/// Extended version with additional tactical tools
struct ExtendedQuickActionToolbar: View {
    @Binding var mapRegion: MKCoordinateRegion
    @Binding var showGrid: Bool
    @Binding var showLayersPanel: Bool
    @Binding var isCursorModeActive: Bool
    @Binding var showRangeBearingLine: Bool
    @Binding var showRouteHere: Bool

    let userLocation: CLLocation?
    let onZoomToSelf: () -> Void
    let onDropPoint: (CLLocationCoordinate2D) -> Void
    let onToggleMeasure: () -> Void
    let onStartRBLine: () -> Void
    let onRouteHere: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Zoom to Self
                QuickActionButton(
                    icon: "location.fill",
                    label: "Self",
                    isActive: false,
                    action: onZoomToSelf
                )

                // Drop Point
                QuickActionButton(
                    icon: "mappin.circle.fill",
                    label: "Drop",
                    isActive: false
                ) {
                    if let location = userLocation {
                        onDropPoint(location.coordinate)
                    }
                }

                // Measure
                QuickActionButton(
                    icon: "ruler",
                    label: "Measure",
                    isActive: false,
                    action: onToggleMeasure
                )

                // Cursor Mode
                QuickActionButton(
                    icon: "scope",
                    label: "Cursor",
                    isActive: isCursorModeActive
                ) {
                    isCursorModeActive.toggle()
                }

                // Range & Bearing Line
                QuickActionButton(
                    icon: "line.diagonal",
                    label: "R&B",
                    isActive: showRangeBearingLine
                ) {
                    showRangeBearingLine.toggle()
                    onStartRBLine()
                }

                // Route Here
                QuickActionButton(
                    icon: "arrow.triangle.turn.up.right.diamond",
                    label: "Route",
                    isActive: showRouteHere
                ) {
                    showRouteHere.toggle()
                    onRouteHere()
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(
            Color.black.opacity(0.8)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Preview

struct QuickActionToolbar_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3)
                .ignoresSafeArea()

            VStack {
                Spacer()

                QuickActionToolbar(
                    mapRegion: .constant(MKCoordinateRegion()),
                    showGrid: .constant(false),
                    showLayersPanel: .constant(false),
                    isCursorModeActive: .constant(false),
                    userLocation: nil,
                    onDropPoint: { _ in },
                    onToggleMeasure: {}
                )
                .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
}
