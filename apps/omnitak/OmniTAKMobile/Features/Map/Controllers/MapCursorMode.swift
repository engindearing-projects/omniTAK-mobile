//
//  MapCursorMode.swift
//  OmniTAKMobile
//
//  Cursor mode for precision marker placement with crosshair overlay
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Map Cursor Mode Coordinator

/// Manages cursor mode state and coordinates
class MapCursorModeCoordinator: ObservableObject {
    @Published var isActive: Bool = false
    @Published var cursorCoordinate: CLLocationCoordinate2D?
    @Published var showDropButton: Bool = true

    func activate() {
        isActive = true
        showDropButton = true
    }

    func deactivate() {
        isActive = false
        cursorCoordinate = nil
        showDropButton = false
    }

    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    func updateCursorPosition(coordinate: CLLocationCoordinate2D) {
        cursorCoordinate = coordinate
    }
}

// MARK: - Cursor Mode Overlay View

/// Crosshair overlay displayed in center of map when cursor mode is active
struct CursorModeOverlayView: View {
    @ObservedObject var coordinator: MapCursorModeCoordinator
    let mapRegion: MKCoordinateRegion
    let onDropMarker: (CLLocationCoordinate2D) -> Void
    let onClose: () -> Void

    @State private var showMGRS = true

    var body: some View {
        if coordinator.isActive {
            ZStack {
                // Crosshair
                CrosshairView()

                // Coordinate Display
                VStack {
                    // Close button at top
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 60)
                    }

                    Spacer()

                    // Coordinate info panel
                    CursorCoordinatePanel(
                        coordinate: mapRegion.center,
                        showMGRS: showMGRS,
                        onToggleFormat: { showMGRS.toggle() }
                    )
                    .padding(.bottom, 20)

                    // Drop Here button
                    if coordinator.showDropButton {
                        DropHereButton {
                            onDropMarker(mapRegion.center)
                            // Haptic feedback
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Crosshair View

/// Tactical crosshair overlay
struct CrosshairView: View {
    var crosshairColor: Color = Color(hex: "#FFFF00")
    var lineWidth: CGFloat = 2.0
    var gapSize: CGFloat = 12.0
    var armLength: CGFloat = 30.0

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                // Horizontal line (left)
                Rectangle()
                    .fill(crosshairColor)
                    .frame(width: armLength, height: lineWidth)
                    .position(x: center.x - gapSize - armLength / 2, y: center.y)

                // Horizontal line (right)
                Rectangle()
                    .fill(crosshairColor)
                    .frame(width: armLength, height: lineWidth)
                    .position(x: center.x + gapSize + armLength / 2, y: center.y)

                // Vertical line (top)
                Rectangle()
                    .fill(crosshairColor)
                    .frame(width: lineWidth, height: armLength)
                    .position(x: center.x, y: center.y - gapSize - armLength / 2)

                // Vertical line (bottom)
                Rectangle()
                    .fill(crosshairColor)
                    .frame(width: lineWidth, height: armLength)
                    .position(x: center.x, y: center.y + gapSize + armLength / 2)

                // Center dot
                Circle()
                    .fill(crosshairColor)
                    .frame(width: 4, height: 4)
                    .position(center)

                // Outer circle (optional for better visibility)
                Circle()
                    .stroke(crosshairColor.opacity(0.5), lineWidth: 1)
                    .frame(width: 60, height: 60)
                    .position(center)
            }
        }
        .allowsHitTesting(false) // Allow touches to pass through
    }
}

// MARK: - Cursor Coordinate Panel

/// Panel showing precise coordinates at cursor position
struct CursorCoordinatePanel: View {
    let coordinate: CLLocationCoordinate2D
    let showMGRS: Bool
    let onToggleFormat: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Format toggle
            HStack {
                Text("CURSOR POSITION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "#FFFF00"))

                Spacer()

                Button(action: onToggleFormat) {
                    Text(showMGRS ? "MGRS" : "LAT/LON")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            // Primary coordinate display
            if showMGRS {
                Text(formatMGRS(coordinate))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            } else {
                VStack(spacing: 2) {
                    Text(formatLatitude(coordinate.latitude))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Text(formatLongitude(coordinate.longitude))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }

            // Secondary display (always show both formats)
            if showMGRS {
                HStack(spacing: 4) {
                    Text(String(format: "%.6f", coordinate.latitude))
                        .font(.system(size: 10, design: .monospaced))
                    Text(",")
                        .font(.system(size: 10))
                    Text(String(format: "%.6f", coordinate.longitude))
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundColor(.gray)
            } else {
                Text(formatMGRS(coordinate))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#FFFF00").opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 40)
    }

    // MARK: - Formatting Functions

    private func formatMGRS(_ coordinate: CLLocationCoordinate2D) -> String {
        // Use actual MGRSConverter for accurate MGRS conversion
        return MGRSConverter.formatMGRS(coordinate, precision: .tenMeter, withSpaces: true)
    }

    private func formatLatitude(_ lat: Double) -> String {
        let direction = lat >= 0 ? "N" : "S"
        let absLat = abs(lat)
        let degrees = Int(absLat)
        let minutesDecimal = (absLat - Double(degrees)) * 60
        let minutes = Int(minutesDecimal)
        let seconds = (minutesDecimal - Double(minutes)) * 60

        return String(format: "%d\u{00B0} %02d' %06.3f\" %@", degrees, minutes, seconds, direction)
    }

    private func formatLongitude(_ lon: Double) -> String {
        let direction = lon >= 0 ? "E" : "W"
        let absLon = abs(lon)
        let degrees = Int(absLon)
        let minutesDecimal = (absLon - Double(degrees)) * 60
        let minutes = Int(minutesDecimal)
        let seconds = (minutesDecimal - Double(minutes)) * 60

        return String(format: "%d\u{00B0} %02d' %06.3f\" %@", degrees, minutes, seconds, direction)
    }
}

// MARK: - Drop Here Button

/// Large action button for dropping marker at cursor position
struct DropHereButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 20, weight: .semibold))

                Text("DROP HERE")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#FFFF00"))
                    .shadow(color: Color(hex: "#FFFF00").opacity(0.4), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Cursor Mode Toggle Button

/// Button to toggle cursor mode on/off
struct CursorModeToggleButton: View {
    @ObservedObject var coordinator: MapCursorModeCoordinator

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            coordinator.toggle()
        }) {
            VStack(spacing: 4) {
                Image(systemName: coordinator.isActive ? "scope" : "scope")
                    .font(.system(size: 20, weight: .medium))

                Text("Cursor")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(coordinator.isActive ? Color(hex: "#FFFF00") : .white)
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(coordinator.isActive
                          ? Color(hex: "#FFFF00").opacity(0.2)
                          : Color.black.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(coordinator.isActive
                            ? Color(hex: "#FFFF00").opacity(0.5)
                            : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Precision Crosshair Styles

enum CrosshairStyle {
    case tactical    // Military style with gap
    case simple      // Basic crosshair
    case circle      // Circle with center dot
    case target      // Concentric circles

    var view: some View {
        Group {
            switch self {
            case .tactical:
                CrosshairView()
            case .simple:
                SimpleCrosshairView()
            case .circle:
                CircleCrosshairView()
            case .target:
                TargetCrosshairView()
            }
        }
    }
}

struct SimpleCrosshairView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                // Horizontal line
                path.move(to: CGPoint(x: center.x - 25, y: center.y))
                path.addLine(to: CGPoint(x: center.x + 25, y: center.y))
                // Vertical line
                path.move(to: CGPoint(x: center.x, y: center.y - 25))
                path.addLine(to: CGPoint(x: center.x, y: center.y + 25))
            }
            .stroke(Color(hex: "#FFFF00"), lineWidth: 2)
        }
        .allowsHitTesting(false)
    }
}

struct CircleCrosshairView: View {
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                Circle()
                    .stroke(Color(hex: "#FFFF00"), lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .position(center)

                Circle()
                    .fill(Color(hex: "#FFFF00"))
                    .frame(width: 6, height: 6)
                    .position(center)
            }
        }
        .allowsHitTesting(false)
    }
}

struct TargetCrosshairView: View {
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                Circle()
                    .stroke(Color(hex: "#FFFF00").opacity(0.3), lineWidth: 1)
                    .frame(width: 80, height: 80)
                    .position(center)

                Circle()
                    .stroke(Color(hex: "#FFFF00").opacity(0.5), lineWidth: 1.5)
                    .frame(width: 50, height: 50)
                    .position(center)

                Circle()
                    .stroke(Color(hex: "#FFFF00"), lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .position(center)

                Circle()
                    .fill(Color(hex: "#FFFF00"))
                    .frame(width: 4, height: 4)
                    .position(center)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

struct MapCursorMode_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
                .ignoresSafeArea()

            CursorModeOverlayView(
                coordinator: MapCursorModeCoordinator(),
                mapRegion: MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ),
                onDropMarker: { _ in },
                onClose: {}
            )
        }
        .preferredColorScheme(.dark)
        .onAppear {
            let coordinator = MapCursorModeCoordinator()
            coordinator.activate()
        }
    }
}
