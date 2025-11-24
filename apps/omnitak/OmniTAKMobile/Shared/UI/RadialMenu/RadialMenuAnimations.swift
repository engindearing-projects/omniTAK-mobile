//
//  RadialMenuAnimations.swift
//  OmniTAKMobile
//
//  Animation utilities and effects for the radial menu
//

import SwiftUI

// MARK: - Animation Constants

enum RadialMenuAnimationConstants {
    static let defaultSpringResponse: Double = 0.35
    static let defaultSpringDampingFraction: Double = 0.7
    static let staggerDelay: Double = 0.03
    static let fadeInDuration: Double = 0.2
    static let fadeOutDuration: Double = 0.15
    static let selectionScaleFactor: CGFloat = 1.15
    static let rotationAngle: Double = 30 // degrees
}

// MARK: - Radial Menu Animation

/// Animation wrapper for radial menu transitions
struct RadialMenuAnimation {
    /// Spring animation for menu appearance
    static var menuAppear: Animation {
        .spring(
            response: RadialMenuAnimationConstants.defaultSpringResponse,
            dampingFraction: RadialMenuAnimationConstants.defaultSpringDampingFraction
        )
    }

    /// Animation for menu disappearance
    static var menuDisappear: Animation {
        .easeOut(duration: RadialMenuAnimationConstants.fadeOutDuration)
    }

    /// Staggered animation for individual items
    static func itemAppear(delay: Double) -> Animation {
        .spring(
            response: 0.4,
            dampingFraction: 0.7
        )
        .delay(delay)
    }

    /// Animation for item selection highlight
    static var selectionHighlight: Animation {
        .spring(response: 0.25, dampingFraction: 0.6)
    }

    /// Rotation animation for items appearing
    static var rotateIn: Animation {
        .spring(response: 0.5, dampingFraction: 0.8)
    }
}

// MARK: - Animated Radial Menu Item

/// Radial menu item with enhanced animations
struct AnimatedRadialMenuItem: View {
    let item: RadialMenuItem
    let isSelected: Bool
    let size: CGFloat
    let showLabel: Bool
    let index: Int
    let totalItems: Int
    let animationStyle: RadialMenuAnimationStyle

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0
    @State private var offset: CGFloat = 0

    var body: some View {
        VStack(spacing: 4) {
            // Icon Circle with animations
            ZStack {
                // Pulsing background when selected
                if isSelected {
                    Circle()
                        .fill(item.color.opacity(0.2))
                        .frame(width: size + 20, height: size + 20)
                        .scaleEffect(pulseScale)
                        .blur(radius: 10)
                }

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

                // Icon
                Image(systemName: item.icon)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: "#1E1E1E") : item.color)
                    .rotationEffect(.degrees(isSelected ? 0 : rotation))
            }
            .scaleEffect(isSelected ? RadialMenuAnimationConstants.selectionScaleFactor : 1.0)
            .animation(RadialMenuAnimation.selectionHighlight, value: isSelected)

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
        .offset(x: 0, y: offset)
        .onAppear {
            performEntryAnimation()
        }
    }

    @State private var pulseScale: CGFloat = 1.0

    private func performEntryAnimation() {
        let delay = RadialMenuAnimationConstants.staggerDelay * Double(index)

        switch animationStyle {
        case .springBounce:
            withAnimation(RadialMenuAnimation.itemAppear(delay: delay)) {
                scale = 1.0
                opacity = 1.0
            }

        case .rotateIn:
            rotation = RadialMenuAnimationConstants.rotationAngle
            withAnimation(RadialMenuAnimation.rotateIn.delay(delay)) {
                scale = 1.0
                opacity = 1.0
                rotation = 0
            }

        case .slideIn:
            offset = -20
            withAnimation(.easeOut(duration: 0.3).delay(delay)) {
                scale = 1.0
                opacity = 1.0
                offset = 0
            }

        case .fadeIn:
            withAnimation(.easeIn(duration: 0.2).delay(delay)) {
                scale = 1.0
                opacity = 1.0
            }
        }

        // Start pulsing animation if selected
        if isSelected {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.3
            }
        }
    }
}

// MARK: - Animation Styles

/// Different animation styles for the radial menu
enum RadialMenuAnimationStyle {
    case springBounce    // Default spring animation
    case rotateIn        // Items rotate into place
    case slideIn         // Items slide from center outward
    case fadeIn          // Simple fade in
}

// MARK: - Animated Background

/// Animated background for the radial menu
struct AnimatedRadialMenuBackground: View {
    let centerPoint: CGPoint
    let radius: CGFloat
    let opacity: Double

    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0

    var body: some View {
        ZStack {
            // Outer ring animation
            Circle()
                .stroke(Color(hex: "#FFFC00").opacity(0.3), lineWidth: 2)
                .frame(width: radius * 2.2, height: radius * 2.2)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)
                .position(centerPoint)

            // Inner glow
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#FFFC00").opacity(0.1),
                    Color.clear
                ]),
                center: .center,
                startRadius: 10,
                endRadius: radius
            )
            .frame(width: radius * 2, height: radius * 2)
            .position(centerPoint)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                ringScale = 1.0
                ringOpacity = 0.5
            }
        }
    }
}

// MARK: - Ripple Effect

/// Ripple effect animation for tap feedback
struct RippleEffect: View {
    let position: CGPoint
    let color: Color

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 50, height: 50)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(position)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    scale = 3
                    opacity = 0
                }
            }
    }
}

// MARK: - Connecting Lines

/// Optional connecting lines from center to items
struct RadialMenuConnectingLines: View {
    let centerPoint: CGPoint
    let itemPositions: [CGPoint]
    let color: Color

    @State private var lineProgress: CGFloat = 0

    var body: some View {
        ForEach(0..<itemPositions.count, id: \.self) { index in
            Path { path in
                path.move(to: centerPoint)
                path.addLine(to: itemPositions[index])
            }
            .trim(from: 0, to: lineProgress)
            .stroke(color.opacity(0.3), lineWidth: 1)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                lineProgress = 1.0
            }
        }
    }
}

// MARK: - Pulse Animation Modifier

struct PulseAnimationModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulseAnimation() -> some View {
        self.modifier(PulseAnimationModifier())
    }
}

// MARK: - Glow Effect Modifier

struct GlowEffectModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.3), radius: radius / 3)
            .shadow(color: color.opacity(0.2), radius: radius / 2)
            .shadow(color: color.opacity(0.1), radius: radius)
    }
}

extension View {
    func glowEffect(color: Color, radius: CGFloat = 10) -> some View {
        self.modifier(GlowEffectModifier(color: color, radius: radius))
    }
}

// MARK: - Preview

struct RadialMenuAnimations_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(hex: "#1E1E1E")
                .ignoresSafeArea()

            VStack(spacing: 50) {
                HStack(spacing: 30) {
                    AnimatedRadialMenuItem(
                        item: RadialMenuItem(
                            icon: "exclamationmark.triangle.fill",
                            label: "Hostile",
                            color: .red,
                            action: .dropMarker(.hostile)
                        ),
                        isSelected: false,
                        size: 50,
                        showLabel: true,
                        index: 0,
                        totalItems: 4,
                        animationStyle: .springBounce
                    )

                    AnimatedRadialMenuItem(
                        item: RadialMenuItem(
                            icon: "shield.fill",
                            label: "Friendly",
                            color: .cyan,
                            action: .dropMarker(.friendly)
                        ),
                        isSelected: true,
                        size: 50,
                        showLabel: true,
                        index: 1,
                        totalItems: 4,
                        animationStyle: .rotateIn
                    )
                }

                AnimatedRadialMenuBackground(
                    centerPoint: CGPoint(x: 100, y: 100),
                    radius: 80,
                    opacity: 1.0
                )
                .frame(width: 200, height: 200)
            }
        }
        .preferredColorScheme(.dark)
    }
}
