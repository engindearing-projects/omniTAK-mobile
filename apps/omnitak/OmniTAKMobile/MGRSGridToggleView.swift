//
//  MGRSGridToggleView.swift
//  OmniTAKMobile
//
//  Floating button and control panel for MGRS grid overlay
//

import SwiftUI
import MapKit

// MARK: - MGRS Grid Toggle Button

struct MGRSGridToggleView: View {
    @ObservedObject var overlayCoordinator: MapOverlayCoordinator
    @ObservedObject var stateManager: MapStateManager
    @State private var showGridOptions = false

    var body: some View {
        VStack(spacing: 8) {
            // Main toggle button
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    if overlayCoordinator.mgrsGridEnabled {
                        showGridOptions.toggle()
                    } else {
                        overlayCoordinator.mgrsGridEnabled = true
                        showGridOptions = true
                    }
                }
                hapticFeedback()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: overlayCoordinator.mgrsGridEnabled ? "grid.circle.fill" : "grid.circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(overlayCoordinator.mgrsGridEnabled ? .green : .white)

                    Text("MGRS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 56, height: 56)
                .background(overlayCoordinator.mgrsGridEnabled ? Color.black.opacity(0.8) : Color.black.opacity(0.6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(overlayCoordinator.mgrsGridEnabled ? Color.green.opacity(0.6) : Color.clear, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // Expanded options panel
            if showGridOptions && overlayCoordinator.mgrsGridEnabled {
                MGRSGridOptionsPanel(
                    overlayCoordinator: overlayCoordinator,
                    stateManager: stateManager,
                    isPresented: $showGridOptions
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
        }
    }

    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - MGRS Grid Options Panel

struct MGRSGridOptionsPanel: View {
    @ObservedObject var overlayCoordinator: MapOverlayCoordinator
    @ObservedObject var stateManager: MapStateManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("MGRS GRID")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 16))
                }
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Current MGRS coordinate display
            VStack(alignment: .leading, spacing: 4) {
                Text("CENTER")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)

                Text(overlayCoordinator.currentCenterMGRS.isEmpty ? "--" : overlayCoordinator.currentCenterMGRS)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(6)

            // Grid Density
            VStack(alignment: .leading, spacing: 6) {
                Text("DENSITY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)

                ForEach(MGRSGridDensity.allCases) { density in
                    DensityOptionButton(
                        density: density,
                        isSelected: overlayCoordinator.mgrsGridDensity == density,
                        action: {
                            overlayCoordinator.mgrsGridDensity = density
                            hapticFeedback()
                        }
                    )
                }
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Grid Options
            VStack(alignment: .leading, spacing: 8) {
                Text("OPTIONS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)

                Toggle(isOn: $overlayCoordinator.showMGRSLabels) {
                    HStack(spacing: 6) {
                        Image(systemName: "textformat")
                            .font(.system(size: 12))
                        Text("Show Labels")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white)
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Disable button
            Button(action: {
                withAnimation(.spring()) {
                    overlayCoordinator.mgrsGridEnabled = false
                    isPresented = false
                }
                hapticFeedback()
            }) {
                HStack {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 12))
                    Text("Hide Grid")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.2))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 180)
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
    }

    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Density Option Button

struct DensityOptionButton: View {
    let density: MGRSGridDensity
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(density.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                    .foregroundColor(.white)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.green.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MGRS Coordinate Display Overlay

struct MGRSCoordinateOverlay: View {
    @ObservedObject var overlayCoordinator: MapOverlayCoordinator
    @ObservedObject var stateManager: MapStateManager

    var body: some View {
        if overlayCoordinator.mgrsGridEnabled {
            VStack(spacing: 4) {
                // Grid Zone Designator
                Text(getGridZoneDesignator())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)

                // Full MGRS coordinate
                Text(overlayCoordinator.currentCenterMGRS)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }

    private func getGridZoneDesignator() -> String {
        let mgrs = overlayCoordinator.currentCenterMGRS
        let components = mgrs.components(separatedBy: " ")
        if components.count >= 2 {
            return "\(components[0]) \(components[1])"
        }
        return components.first ?? "--"
    }
}

// MARK: - Grid Style Selector

struct GridStyleSelector: View {
    @ObservedObject var overlayCoordinator: MapOverlayCoordinator
    @State private var selectedStyle: GridStyle = .military

    enum GridStyle: String, CaseIterable {
        case military = "Military"
        case tactical = "Tactical"
        case subtle = "Subtle"

        var lineColor: UIColor {
            switch self {
            case .military:
                return UIColor.gray.withAlphaComponent(0.6)
            case .tactical:
                return UIColor.black.withAlphaComponent(0.7)
            case .subtle:
                return UIColor.gray.withAlphaComponent(0.3)
            }
        }

        var labelColor: UIColor {
            switch self {
            case .military:
                return UIColor.white.withAlphaComponent(0.9)
            case .tactical:
                return UIColor.white
            case .subtle:
                return UIColor.white.withAlphaComponent(0.7)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STYLE")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.gray)

            ForEach(GridStyle.allCases, id: \.rawValue) { style in
                Button(action: {
                    selectedStyle = style
                    applyStyle(style)
                }) {
                    HStack {
                        Text(style.rawValue)
                            .font(.system(size: 11))
                            .foregroundColor(.white)

                        Spacer()

                        if selectedStyle == style {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedStyle == style ? Color.green.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func applyStyle(_ style: GridStyle) {
        overlayCoordinator.mgrsLineColor = style.lineColor
        overlayCoordinator.mgrsLabelColor = style.labelColor
    }
}

// MARK: - Cursor Crosshair View

struct CursorCrosshairView: View {
    @ObservedObject var stateManager: MapStateManager

    var body: some View {
        if stateManager.showCoordinateCrosshair {
            GeometryReader { geometry in
                ZStack {
                    // Vertical line
                    Rectangle()
                        .fill(Color.red.opacity(0.8))
                        .frame(width: 2, height: 40)

                    // Horizontal line
                    Rectangle()
                        .fill(Color.red.opacity(0.8))
                        .frame(width: 40, height: 2)

                    // Center dot
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)

                    // Coordinate label
                    VStack {
                        Spacer()

                        Text(stateManager.formattedCenterCoordinate)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(4)
                            .offset(y: 30)
                    }
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Coordinate Format Picker

struct CoordinateFormatPicker: View {
    @ObservedObject var stateManager: MapStateManager

    var body: some View {
        Menu {
            ForEach(CoordinateDisplayFormat.allCases) { format in
                Button(action: {
                    stateManager.coordinateFormat = format
                    stateManager.savePreferences()
                }) {
                    HStack {
                        Text(format.displayName)
                        if stateManager.coordinateFormat == format {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "location.circle")
                    .font(.system(size: 12))
                Text(stateManager.coordinateFormat.shortName)
                    .font(.system(size: 11, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
        }
    }
}
