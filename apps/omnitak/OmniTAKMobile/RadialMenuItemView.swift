//
//  RadialMenuItemView.swift
//  OmniTAKMobile
//
//  Individual menu item appearance for the radial menu
//

import SwiftUI

// MARK: - Radial Menu Item View

/// View for a single item in the radial menu
struct RadialMenuItemView: View {
    let item: RadialMenuItem
    let isSelected: Bool
    let size: CGFloat
    let showLabel: Bool
    let animationDelay: Double

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 4) {
            // Icon Circle
            ZStack {
                // Background circle
                Circle()
                    .fill(isSelected ? item.color : Color(hex: "#2A2A2A"))
                    .frame(width: size, height: size)

                // Border
                Circle()
                    .strokeBorder(
                        isSelected ? item.color : Color(hex: "#3A3A3A"),
                        lineWidth: isSelected ? 3 : 1.5
                    )
                    .frame(width: size, height: size)

                // Glow effect when selected
                if isSelected {
                    Circle()
                        .fill(item.color.opacity(0.3))
                        .frame(width: size + 10, height: size + 10)
                        .blur(radius: 8)
                }

                // Icon
                Image(systemName: item.icon)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: "#1E1E1E") : item.color)
            }
            .frame(width: size + 10, height: size + 10)
            .scaleEffect(isSelected ? 1.15 : 1.0)

            // Label
            if showLabel {
                Text(item.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? item.color : .white)
                    .lineLimit(1)
                    .frame(width: size + 20)
                    .minimumScaleFactor(0.7)
            }
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(animationDelay)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Radial Menu Item Button Style

/// Custom button style for radial menu items
struct RadialMenuItemButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct RadialMenuItemView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(hex: "#1E1E1E")
                .ignoresSafeArea()

            HStack(spacing: 40) {
                // Normal state
                RadialMenuItemView(
                    item: RadialMenuItem(
                        icon: "exclamationmark.triangle.fill",
                        label: "Hostile",
                        color: .red,
                        action: .dropMarker(.hostile)
                    ),
                    isSelected: false,
                    size: 50,
                    showLabel: true,
                    animationDelay: 0
                )

                // Selected state
                RadialMenuItemView(
                    item: RadialMenuItem(
                        icon: "shield.fill",
                        label: "Friendly",
                        color: .cyan,
                        action: .dropMarker(.friendly)
                    ),
                    isSelected: true,
                    size: 50,
                    showLabel: true,
                    animationDelay: 0
                )

                // Without label
                RadialMenuItemView(
                    item: RadialMenuItem(
                        icon: "ruler",
                        label: "Measure",
                        color: Color(hex: "#FFFC00"),
                        action: .measure
                    ),
                    isSelected: false,
                    size: 50,
                    showLabel: false,
                    animationDelay: 0
                )
            }
        }
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}
