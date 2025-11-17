import SwiftUI
import CoreLocation

// MARK: - Compass Overlay View
// ATAK-style rotating compass showing current heading

struct CompassOverlayView: View {
    let heading: CLLocationDirection? // 0-360 degrees, 0 = North
    let isVisible: Bool

    @State private var displayHeading: Double = 0
    @State private var isExpanded: Bool = false

    var body: some View {
        if isVisible {
            VStack {
                HStack {
                    Spacer()
                    if isExpanded {
                        expandedCompassView
                    } else {
                        collapsedCompassView
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 60)
                Spacer()
            }
        }
    }

    private var collapsedCompassView: some View {
        ZStack {
            // Small compass indicator - 60x60
            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 60, height: 60)

            Circle()
                .stroke(Color(hex: "#FFFC00").opacity(0.3), lineWidth: 1.5)
                .frame(width: 60, height: 60)

            // Simplified compass rose
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 48, height: 48)

                // North indicator (red)
                VStack(spacing: 0) {
                    Triangle()
                        .fill(Color.red)
                        .frame(width: 8, height: 12)
                    Spacer()
                }
                .frame(height: 42)

                // South indicator (white)
                VStack(spacing: 0) {
                    Spacer()
                    Triangle()
                        .fill(Color.white)
                        .frame(width: 6, height: 8)
                        .rotationEffect(.degrees(180))
                }
                .frame(height: 42)

                // East-West line
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 42, height: 1)
            }
            .rotationEffect(.degrees(-displayHeading))
            .animation(.easeInOut(duration: 0.3), value: displayHeading)

            // Center dot
            Circle()
                .fill(Color(hex: "#FFFC00"))
                .frame(width: 6, height: 6)

            // Heading text
            VStack {
                Spacer()
                Text(headingText)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .offset(y: 34)
            }
        }
        .frame(width: 60, height: 60)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded = true
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        .onChange(of: heading) { newHeading in
            if let newHeading = newHeading {
                displayHeading = newHeading
            }
        }
    }

    private var expandedCompassView: some View {
        ZStack {
            // Outer container with ATAK styling
            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 100, height: 100)

            Circle()
                .stroke(Color(hex: "#FFFC00").opacity(0.3), lineWidth: 2)
                .frame(width: 100, height: 100)

            // Compass rose - rotates based on heading
            ZStack {
                // Cardinal directions background circle
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 80, height: 80)

                // North indicator (red)
                VStack(spacing: 0) {
                    Triangle()
                        .fill(Color.red)
                        .frame(width: 12, height: 16)
                    Spacer()
                }
                .frame(height: 70)

                // South indicator (white)
                VStack(spacing: 0) {
                    Spacer()
                    Triangle()
                        .fill(Color.white)
                        .frame(width: 8, height: 12)
                        .rotationEffect(.degrees(180))
                }
                .frame(height: 70)

                // East-West line
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 70, height: 1)

                // Cardinal direction letters
                VStack {
                    Text("N")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                        .offset(y: -32)

                    Spacer()

                    Text("S")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .offset(y: 32)
                }
                .frame(height: 0)

                HStack {
                    Text("W")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .offset(x: -32)

                    Spacer()

                    Text("E")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .offset(x: 32)
                }
                .frame(width: 0)
            }
            .rotationEffect(.degrees(-displayHeading))
            .animation(.easeInOut(duration: 0.3), value: displayHeading)

            // Center dot
            Circle()
                .fill(Color(hex: "#FFFC00"))
                .frame(width: 8, height: 8)

            // Heading display at bottom
            VStack {
                Spacer()
                Text(headingText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(4)
                    .offset(y: 52)
            }
        }
        .frame(width: 100, height: 100)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded = false
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        .onChange(of: heading) { newHeading in
            if let newHeading = newHeading {
                displayHeading = newHeading
            }
        }
    }

    private var headingText: String {
        guard let heading = heading else { return "---°" }

        let normalized = Int(heading.rounded()) % 360
        return String(format: "%03d°", normalized)
    }

    private var cardinalDirection: String {
        guard let heading = heading else { return "---" }

        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5) / 45.0) % 8
        return directions[index]
    }
}

// MARK: - Triangle Shape for Compass Indicators

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

struct CompassOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.ignoresSafeArea()

            VStack(spacing: 40) {
                CompassOverlayView(heading: 0, isVisible: true)
                CompassOverlayView(heading: 45, isVisible: true)
                CompassOverlayView(heading: 180, isVisible: true)
                CompassOverlayView(heading: 270, isVisible: true)
            }
        }
    }
}

