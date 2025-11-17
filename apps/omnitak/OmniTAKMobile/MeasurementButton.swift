//
//  MeasurementButton.swift
//  OmniTAKMobile
//
//  Compact button for main map UI to access measurement tools
//

import SwiftUI

// MARK: - Measurement Button

struct MeasurementButton: View {
    @ObservedObject var manager: MeasurementManager
    @Binding var showMeasurementPanel: Bool

    var body: some View {
        Button(action: { showMeasurementPanel.toggle() }) {
            ZStack {
                // Background
                Circle()
                    .fill(manager.isActive ? Color(hex: "#FFFC00") : Color(hex: "#1E1E1E"))
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)

                // Icon
                Image(systemName: "ruler")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(manager.isActive ? Color(hex: "#1E1E1E") : Color(hex: "#FFFC00"))

                // Active indicator badge
                if manager.isActive {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .offset(x: 16, y: -16)
                }

                // Point count badge
                if manager.isActive && !manager.temporaryPoints.isEmpty {
                    Text("\(manager.temporaryPoints.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .offset(x: -16, y: -16)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Measurement Status Bar

struct MeasurementStatusBar: View {
    @ObservedObject var manager: MeasurementManager

    var body: some View {
        if manager.isActive {
            VStack(spacing: 8) {
                // Status indicator
                HStack(spacing: 8) {
                    Image(systemName: manager.currentMeasurementType?.icon ?? "ruler")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#FFFC00"))

                    Text(manager.getInstructions())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Spacer()

                    // Quick action buttons
                    HStack(spacing: 8) {
                        if !manager.temporaryPoints.isEmpty {
                            Button(action: { manager.undoLastPoint() }) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color(hex: "#444444"))
                                    .clipShape(Circle())
                            }
                        }

                        if manager.canComplete() {
                            Button(action: { manager.completeMeasurement() }) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#1E1E1E"))
                                    .padding(6)
                                    .background(Color(hex: "#FFFC00"))
                                    .clipShape(Circle())
                            }
                        }

                        Button(action: { manager.cancelMeasurement() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color(hex: "#FF4444"))
                                .clipShape(Circle())
                        }
                    }
                }

                // Live result preview
                if let preview = liveResultPreview {
                    Text(preview)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(hex: "#1E1E1E").opacity(0.95))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }

    private var liveResultPreview: String? {
        guard let type = manager.currentMeasurementType else { return nil }

        switch type {
        case .distance:
            if let meters = manager.liveResult.distanceMeters {
                return "Distance: \(MeasurementCalculator.formatDistance(meters))"
            }

        case .bearing:
            if let degrees = manager.liveResult.bearingDegrees {
                return "Bearing: \(MeasurementCalculator.formatBearing(degrees))"
            }

        case .area:
            if let sqMeters = manager.liveResult.areaSquareMeters {
                return "Area: \(MeasurementCalculator.formatArea(sqMeters))"
            }

        case .rangeRing:
            if !manager.temporaryPoints.isEmpty {
                return "Range rings configured"
            }
        }

        return nil
    }
}

// MARK: - Floating Measurement Panel

struct FloatingMeasurementPanel: View {
    @ObservedObject var manager: MeasurementManager
    @Binding var isPresented: Bool
    @State private var offset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        MeasurementToolView(manager: manager, isPresented: $isPresented)
            .frame(width: 340)
            .frame(maxHeight: 500)
            .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                    }
            )
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(), value: isPresented)
    }
}

// MARK: - Measurement Tool Picker

struct MeasurementToolPicker: View {
    @ObservedObject var manager: MeasurementManager
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Measure")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#666666"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .background(Color(hex: "#333333"))

            // Tools
            VStack(spacing: 0) {
                ForEach(MeasurementType.allCases, id: \.self) { type in
                    toolRow(type)

                    if type != MeasurementType.allCases.last {
                        Divider()
                            .background(Color(hex: "#333333"))
                            .padding(.leading, 56)
                    }
                }
            }
        }
        .background(Color(hex: "#1E1E1E"))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
    }

    private func toolRow(_ type: MeasurementType) -> some View {
        let isActive = manager.currentMeasurementType == type && manager.isActive

        return Button(action: {
            if isActive {
                manager.cancelMeasurement()
            } else {
                manager.startMeasurement(type: type)
                onDismiss()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)

                    Text(type.instructions)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#888888"))
                        .lineLimit(2)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isActive ? Color(hex: "#2A2A2A") : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Compact Result Badge

struct MeasurementResultBadge: View {
    let result: MeasurementResult
    let type: MeasurementType

    var body: some View {
        if let text = resultText {
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#1E1E1E"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "#FFFC00"))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
        }
    }

    private var resultText: String? {
        switch type {
        case .distance:
            if let meters = result.distanceMeters {
                return MeasurementCalculator.formatDistance(meters)
            }

        case .bearing:
            if let degrees = result.bearingDegrees {
                return String(format: "%.1f\u{00B0}", degrees)
            }

        case .area:
            if let sqMeters = result.areaSquareMeters {
                return MeasurementCalculator.formatArea(sqMeters)
            }

        case .rangeRing:
            return nil
        }

        return nil
    }
}
