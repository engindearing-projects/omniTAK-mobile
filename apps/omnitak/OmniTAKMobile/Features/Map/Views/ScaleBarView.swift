import SwiftUI
import MapKit
import CoreLocation

// MARK: - Scale Bar View
// ATAK-style map scale indicator that adjusts based on zoom level
// Uses computed properties for instant reactivity during map movement

struct ScaleBarView: View {
    let region: MKCoordinateRegion
    let isVisible: Bool

    @State private var isExpanded: Bool = false

    // Computed scale values for instant reactivity
    private var scaleInfo: (width: CGFloat, text: String) {
        calculateScaleInfo()
    }

    var body: some View {
        if isVisible {
            VStack {
                Spacer()
                HStack {
                    if isExpanded {
                        expandedScaleBar
                    } else {
                        collapsedScaleBar
                    }
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.bottom, 225)
            }
        }
    }

    private var collapsedScaleBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "ruler")
                .font(.system(size: 10))
                .foregroundColor(.white)

            Text(scaleInfo.text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .animation(.none, value: scaleInfo.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.7))
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = true
            }
        }
    }

    private var expandedScaleBar: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Scale bar graphic
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: scaleInfo.width / 2, height: 4)

                Rectangle()
                    .fill(Color.black)
                    .frame(width: scaleInfo.width / 2, height: 4)
            }
            .overlay(
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: 12)
                    Spacer()
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: 12)
                    Spacer()
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: 12)
                }
                .frame(width: scaleInfo.width)
            )

            Text(scaleInfo.text)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .animation(.none, value: scaleInfo.text)
        }
        .padding(8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = false
            }
        }
    }

    // MARK: - Scale Calculation (Computed - No State)

    private func calculateScaleInfo() -> (width: CGFloat, text: String) {
        let center = region.center
        let span = region.span

        // Calculate distance across the visible region
        let point1 = CLLocation(
            latitude: center.latitude,
            longitude: center.longitude - span.longitudeDelta / 2
        )
        let point2 = CLLocation(
            latitude: center.latitude,
            longitude: center.longitude + span.longitudeDelta / 2
        )

        let distanceMeters = point1.distance(from: point2)

        // Get nice rounded scale value
        let (distance, unit) = calculateScale(from: distanceMeters)

        // Calculate proportional width
        let maxWidth: CGFloat = 120
        let minWidth: CGFloat = 60
        let niceNum = getNiceNumber(distanceMeters)
        let width = min(maxWidth, max(minWidth, maxWidth * CGFloat(distance) / CGFloat(niceNum)))

        let text = "\(formatDistance(distance)) \(unit)"

        return (width, text)
    }

    private func calculateScale(from meters: Double) -> (Double, String) {
        let unitSystem = UnitPreferences.shared.unitSystem

        switch unitSystem {
        case .metric:
            if meters >= 1000 {
                let km = meters / 1000
                return (getNiceNumber(km), "km")
            } else {
                return (getNiceNumber(meters), "m")
            }
        case .imperial:
            let feet = meters * 3.28084
            let miles = meters / 1609.344

            if miles >= 0.1 {
                return (getNiceNumber(miles), "mi")
            } else {
                return (getNiceNumber(feet), "ft")
            }
        }
    }

    private func getNiceNumber(_ value: Double) -> Double {
        guard value > 0 else { return 1 }
        let magnitude = pow(10, floor(log10(value)))
        let normalized = value / magnitude

        let nice: Double
        if normalized <= 1 { nice = 1 }
        else if normalized <= 2 { nice = 2 }
        else if normalized <= 5 { nice = 5 }
        else { nice = 10 }

        return nice * magnitude
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance >= 100 {
            return String(format: "%.0f", distance)
        } else if distance >= 1 {
            return String(format: "%.0f", distance)
        } else {
            return String(format: "%.1f", distance)
        }
    }
}

// MARK: - Grid Overlay View

struct GridOverlayView: View {
    let region: MKCoordinateRegion
    let isVisible: Bool

    var body: some View {
        if isVisible {
            GeometryReader { geometry in
                Canvas { context, size in
                    drawGrid(context: context, size: size, geometry: geometry)
                }
            }
            .allowsHitTesting(false)
        } else {
            EmptyView()
        }
    }

    private func drawGrid(context: GraphicsContext, size: CGSize, geometry: GeometryProxy) {
        let gridColor = Color(hex: "#FFFC00").opacity(0.3)
        let gridSpacing: CGFloat = 50

        var x: CGFloat = 0
        while x <= size.width {
            let path = Path { p in
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.stroke(path, with: .color(gridColor), lineWidth: 1)
            x += gridSpacing
        }

        var y: CGFloat = 0
        while y <= size.height {
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(gridColor), lineWidth: 1)
            y += gridSpacing
        }

        drawGridLabels(context: context, size: size, spacing: gridSpacing)
    }

    private func drawGridLabels(context: GraphicsContext, size: CGSize, spacing: CGFloat) {
        let labelColor = Color(hex: "#FFFC00").opacity(0.5)
        let zone = Int((region.center.longitude + 180) / 6) + 1
        let latBand = getLatitudeBand(region.center.latitude)
        let label = "\(zone)\(latBand)"

        context.drawLayer { ctx in
            let text = Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(labelColor)
            ctx.draw(text, at: CGPoint(x: 20, y: 20))
        }
    }

    private func getLatitudeBand(_ latitude: Double) -> String {
        let bands = ["C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X"]
        let index = Int((latitude + 80) / 8)
        if index < 0 || index >= bands.count { return "X" }
        return bands[index]
    }
}
