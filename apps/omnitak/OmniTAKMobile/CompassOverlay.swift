//
//  CompassOverlay.swift
//  OmniTAKMobile
//
//  Compass overlay UI for navigation and bearing display
//

import SwiftUI
import CoreLocation

// MARK: - Compass Overlay

/// Tactical compass overlay showing heading, bearing, and navigation info
struct CompassOverlay: View {
    @ObservedObject var navigationService: NavigationService
    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 0) {
            // Compact compass view
            if navigationService.navigationState.isNavigating {
                NavigatingCompassView(navigationService: navigationService)
                    .onTapGesture {
                        withAnimation {
                            showDetails.toggle()
                        }
                    }
            } else {
                SimpleCompassView(navigationService: navigationService)
            }

            // Expanded navigation details
            if showDetails && navigationService.navigationState.isNavigating {
                NavigationDetailsView(navigationService: navigationService)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Simple Compass View

struct SimpleCompassView: View {
    @ObservedObject var navigationService: NavigationService

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 16))
                .foregroundColor(.cyan)
                .rotationEffect(.degrees(navigationService.compassRoseRotation()))

            Text(navigationService.compassData.formattedHeading)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)

            Text(navigationService.compassData.cardinalDirection)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.cyan)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Navigating Compass View

struct NavigatingCompassView: View {
    @ObservedObject var navigationService: NavigationService

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                // Compass rose
                ZStack {
                    // Background circle
                    Circle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 60, height: 60)

                    // Rotating compass rose
                    Image(systemName: "location.north.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.cyan.opacity(0.3))
                        .rotationEffect(.degrees(navigationService.compassRoseRotation()))

                    // Navigation needle (points to target)
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.yellow)
                        .rotationEffect(.degrees(navigationService.compassNeedleRotation()))
                        .offset(y: -8)

                    // Center dot
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }

                // Navigation info
                VStack(alignment: .leading, spacing: 4) {
                    if let targetName = navigationService.navigationState.targetWaypoint?.name {
                        Text(targetName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        // Distance
                        Label(
                            navigationService.formattedDistance(),
                            systemImage: "arrow.right"
                        )
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)

                        // Bearing
                        Label(
                            navigationService.formattedBearing(),
                            systemImage: "location.north"
                        )
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.yellow)
                    }

                    // ETA
                    if navigationService.navigationState.estimatedTimeOfArrival != nil {
                        Label(
                            "ETA: \(navigationService.formattedETA())",
                            systemImage: "clock"
                        )
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    }
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Navigation Details View

struct NavigationDetailsView: View {
    @ObservedObject var navigationService: NavigationService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Waypoint details
            if let waypoint = navigationService.navigationState.targetWaypoint {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Waypoint")
                        .font(.caption)
                        .foregroundColor(.gray)

                    HStack {
                        Image(systemName: waypoint.icon.rawValue)
                            .foregroundColor(waypoint.color.swiftUIColor)

                        Text(waypoint.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    if let remarks = waypoint.remarks {
                        Text(remarks)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    // Coordinates
                    Text(coordinateString(waypoint.coordinate))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                .padding(.bottom, 8)
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Navigation stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                NavigationStatCell(
                    label: "Distance",
                    value: navigationService.formattedDistance(),
                    icon: "arrow.right",
                    color: .cyan
                )

                NavigationStatCell(
                    label: "Bearing",
                    value: navigationService.formattedBearing(),
                    icon: "location.north",
                    color: .yellow
                )

                NavigationStatCell(
                    label: "Speed",
                    value: navigationService.formattedSpeed(),
                    icon: "speedometer",
                    color: .green
                )

                NavigationStatCell(
                    label: "ETA",
                    value: navigationService.formattedETA(),
                    icon: "clock",
                    color: .orange
                )
            }

            // Stop navigation button
            Button(action: {
                navigationService.stopNavigation()
            }) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("Stop Navigation")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                )
        )
        .padding(.top, 4)
    }

    private func coordinateString(_ coordinate: CLLocationCoordinate2D) -> String {
        let latDir = coordinate.latitude >= 0 ? "N" : "S"
        let lonDir = coordinate.longitude >= 0 ? "E" : "W"
        return String(format: "%.6f°%@ %.6f°%@",
                     abs(coordinate.latitude), latDir,
                     abs(coordinate.longitude), lonDir)
    }
}

// MARK: - Navigation Stat Cell

struct NavigationStatCell: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundColor(.gray)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Full Screen Compass View

/// Full-screen tactical compass for detailed navigation
struct FullScreenCompassView: View {
    @ObservedObject var navigationService: NavigationService
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()

            VStack(spacing: 30) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text("Compass")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    // Placeholder for symmetry
                    Color.clear.frame(width: 24)
                }
                .padding()

                // Large compass rose
                ZStack {
                    // Outer ring with cardinal directions
                    CompassRing()
                        .rotationEffect(.degrees(navigationService.compassRoseRotation()))

                    // Center compass
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 200, height: 200)

                    // Heading indicator
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.cyan)
                        .offset(y: -70)

                    // Navigation needle (if navigating)
                    if navigationService.navigationState.isNavigating {
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                            .rotationEffect(.degrees(navigationService.compassNeedleRotation()))
                            .offset(y: -60)
                    }

                    // Center dot
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)

                    // Heading text
                    VStack(spacing: 4) {
                        Text(navigationService.compassData.formattedHeading)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)

                        Text(navigationService.compassData.cardinalDirection)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.cyan)
                    }
                    .offset(y: 80)
                }
                .frame(width: 300, height: 300)

                // Navigation info (if navigating)
                if let waypoint = navigationService.navigationState.targetWaypoint {
                    VStack(spacing: 16) {
                        Text("Navigating to:")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text(waypoint.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        HStack(spacing: 20) {
                            StatBox(
                                label: "Distance",
                                value: navigationService.formattedDistance(),
                                color: .cyan
                            )

                            StatBox(
                                label: "Bearing",
                                value: navigationService.formattedBearing(),
                                color: .yellow
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                }

                Spacer()
            }
        }
    }
}

// MARK: - Compass Ring

struct CompassRing: View {
    var body: some View {
        ZStack {
            // Ring
            Circle()
                .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                .frame(width: 280, height: 280)

            // Cardinal directions
            ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                Text(direction)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(direction == "N" ? .red : .cyan)
                    .rotationEffect(.degrees(rotationForDirection(direction)))
                    .offset(y: -150)
                    .rotationEffect(.degrees(-rotationForDirection(direction)))
            }

            // Tick marks
            ForEach(0..<36) { i in
                Rectangle()
                    .fill(i % 9 == 0 ? Color.cyan : Color.gray.opacity(0.5))
                    .frame(width: 2, height: i % 9 == 0 ? 15 : 8)
                    .offset(y: -140)
                    .rotationEffect(.degrees(Double(i) * 10))
            }
        }
    }

    private func rotationForDirection(_ direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(width: 120)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Preview

#Preview {
    let navService = NavigationService.shared

    return ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            CompassOverlay(navigationService: navService)
                .padding()
        }
    }
}
