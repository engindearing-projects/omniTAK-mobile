//
//  RadialMenuButton.swift
//  OmniTAKMobile
//
//  Toggle button for enabling/disabling radial menu mode
//

import SwiftUI
import CoreLocation

// MARK: - Radial Menu Toggle Button

/// Button to toggle radial menu mode on/off
struct RadialMenuButton: View {
    @ObservedObject var coordinator: RadialMenuMapCoordinator
    @State private var showTooltip: Bool = false

    var body: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            coordinator.toggleEnabled()

            // Show tooltip briefly when enabled
            if coordinator.isRadialMenuEnabled {
                showTooltip = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        showTooltip = false
                    }
                }
            }
        }) {
            ZStack {
                // Button background
                Circle()
                    .fill(coordinator.isRadialMenuEnabled ?
                          Color(hex: "#FFFC00").opacity(0.3) :
                          Color.black.opacity(0.6))
                    .frame(width: 56, height: 56)

                // Icon
                Image(systemName: coordinator.isRadialMenuEnabled ?
                      "circle.hexagongrid.fill" :
                      "circle.hexagongrid")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(coordinator.isRadialMenuEnabled ?
                                   Color(hex: "#FFFC00") :
                                   .white)

                // Active indicator
                if coordinator.isRadialMenuEnabled {
                    Circle()
                        .stroke(Color(hex: "#FFFC00"), lineWidth: 2)
                        .frame(width: 56, height: 56)
                        .scaleEffect(showTooltip ? 1.2 : 1.0)
                        .opacity(showTooltip ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: showTooltip)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            // Tooltip
            Group {
                if showTooltip {
                    Text("Long-press map for menu")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(6)
                        .offset(y: -50)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        )
    }
}

// MARK: - Compact Radial Menu Button

/// Smaller version for toolbar integration
struct RadialMenuCompactButton: View {
    @ObservedObject var coordinator: RadialMenuMapCoordinator

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            coordinator.toggleEnabled()
        }) {
            VStack(spacing: 4) {
                Image(systemName: coordinator.isRadialMenuEnabled ?
                      "circle.hexagongrid.fill" :
                      "circle.hexagongrid")
                    .font(.system(size: 20, weight: .semibold))

                Text("Radial")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(coordinator.isRadialMenuEnabled ?
                           Color(hex: "#FFFC00") :
                           .white)
            .frame(width: 56, height: 56)
            .background(coordinator.isRadialMenuEnabled ?
                       Color(hex: "#FFFC00").opacity(0.2) :
                       Color.black.opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(coordinator.isRadialMenuEnabled ?
                           Color(hex: "#FFFC00") :
                           Color.clear, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Radial Menu Status Indicator

/// Small indicator showing radial menu mode is active
struct RadialMenuStatusIndicator: View {
    @ObservedObject var coordinator: RadialMenuMapCoordinator

    var body: some View {
        if coordinator.isRadialMenuEnabled {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "#FFFC00"))
                    .frame(width: 8, height: 8)
                    .shadow(color: Color(hex: "#FFFC00"), radius: 4)

                Text("RADIAL MENU")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "#FFFC00"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
        }
    }
}

// MARK: - Floating Radial Menu Toggle

/// Floating action button for radial menu toggle
struct FloatingRadialMenuToggle: View {
    @ObservedObject var coordinator: RadialMenuMapCoordinator
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            if isExpanded {
                // Quick action buttons
                VStack(spacing: 8) {
                    quickActionButton(
                        icon: "scope",
                        color: .red,
                        action: {
                            coordinator.menuConfiguration = .quickActionsMenu(
                                at: CLLocationCoordinate2D(latitude: 0, longitude: 0)
                            )
                        }
                    )

                    quickActionButton(
                        icon: "ruler",
                        color: .orange,
                        action: {
                            coordinator.menuConfiguration = .measurementContextMenu()
                        }
                    )
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Main toggle button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#FFFC00"), Color(hex: "#FFA500")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)

                    Image(systemName: isExpanded ? "xmark" : "circle.hexagongrid.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.black)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .shadow(color: Color(hex: "#FFFC00").opacity(0.5), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func quickActionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct RadialMenuButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(hex: "#1E1E1E")
                .ignoresSafeArea()

            VStack(spacing: 30) {
                RadialMenuButton(coordinator: RadialMenuMapCoordinator())

                RadialMenuCompactButton(coordinator: RadialMenuMapCoordinator())

                RadialMenuStatusIndicator(coordinator: RadialMenuMapCoordinator())

                FloatingRadialMenuToggle(coordinator: RadialMenuMapCoordinator())
            }
        }
        .preferredColorScheme(.dark)
    }
}
