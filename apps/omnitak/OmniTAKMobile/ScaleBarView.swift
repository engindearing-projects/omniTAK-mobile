import SwiftUI
import MapKit
import CoreLocation

// MARK: - Scale Bar View
// ATAK-style map scale indicator that adjusts based on zoom level

struct ScaleBarView: View {
    let region: MKCoordinateRegion
    let isVisible: Bool

    @State private var scaleWidth: CGFloat = 100
    @State private var scaleText: String = "1 km"
    @State private var isExpanded: Bool = false

    var body: some View {
        if isVisible {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if isExpanded {
                        expandedScaleBar
                    } else {
                        collapsedScaleBar
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 80)
            }
        }
    }

    private var collapsedScaleBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "ruler")
                .font(.system(size: 10))
                .foregroundColor(.white)

            Text(scaleText)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.7))
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded = true
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        .onAppear {
            updateScale()
        }
        .onChange(of: region.span.latitudeDelta) { _ in
            updateScale()
        }
        .onChange(of: region.span.longitudeDelta) { _ in
            updateScale()
        }
    }

    private var expandedScaleBar: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Scale bar graphic
            HStack(spacing: 0) {
                // Left segment (white)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: scaleWidth / 2, height: 4)

                // Right segment (black)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: scaleWidth / 2, height: 4)
            }
            .overlay(
                HStack(spacing: 0) {
                    // Left tick
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: 12)

                    Spacer()

                    // Middle tick
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: 12)

                    Spacer()

                    // Right tick
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: 12)
                }
                .frame(width: scaleWidth)
            )

            // Scale text
            Text(scaleText)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
        }
        .padding(8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded = false
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        .onAppear {
            updateScale()
        }
        .onChange(of: region.span.latitudeDelta) { _ in
            updateScale()
        }
        .onChange(of: region.span.longitudeDelta) { _ in
            updateScale()
        }
    }

    private func updateScale() {
        // Calculate the actual distance represented by the region
        let center = region.center
        let span = region.span

        // Create two points at the center latitude, separated by longitude span
        let point1 = CLLocation(
            latitude: center.latitude,
            longitude: center.longitude - span.longitudeDelta / 2
        )
        let point2 = CLLocation(
            latitude: center.latitude,
            longitude: center.longitude + span.longitudeDelta / 2
        )

        // Calculate distance in meters
        let distanceMeters = point1.distance(from: point2)

        // Determine appropriate scale
        let (distance, unit) = calculateScale(from: distanceMeters)

        // Update scale bar width (proportional to screen width, max 120px)
        let maxWidth: CGFloat = 120
        let minWidth: CGFloat = 60

        // Adjust width based on "nice" scale values
        scaleWidth = min(maxWidth, max(minWidth, maxWidth * CGFloat(distance) / CGFloat(getNiceNumber(distanceMeters))))

        scaleText = "\(formatDistance(distance)) \(unit)"
    }

    private func calculateScale(from meters: Double) -> (Double, String) {
        // Determine the most appropriate scale based on distance

        if meters >= 1000000 {
            // Thousands of kilometers
            let km = meters / 1000
            let nice = getNiceNumber(km)
            return (nice, "km")
        } else if meters >= 1000 {
            // Kilometers
            let km = meters / 1000
            let nice = getNiceNumber(km)
            return (nice, "km")
        } else {
            // Meters
            let nice = getNiceNumber(meters)
            return (nice, "m")
        }
    }

    private func getNiceNumber(_ value: Double) -> Double {
        // Round to "nice" numbers for scale display
        let magnitude = pow(10, floor(log10(value)))

        let normalizedValue = value / magnitude

        let niceValue: Double
        if normalizedValue <= 1 {
            niceValue = 1
        } else if normalizedValue <= 2 {
            niceValue = 2
        } else if normalizedValue <= 5 {
            niceValue = 5
        } else {
            niceValue = 10
        }

        return niceValue * magnitude
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.0f", distance)
        } else if distance >= 100 {
            return String(format: "%.0f", distance)
        } else if distance >= 10 {
            return String(format: "%.0f", distance)
        } else if distance >= 1 {
            return String(format: "%.1f", distance)
        } else {
            return String(format: "%.2f", distance)
        }
    }
}

// MARK: - Grid Overlay View
// ATAK-style MGRS grid overlay for tactical map reference

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
            .allowsHitTesting(false) // Allow touches to pass through
        }
    }

    private func drawGrid(context: GraphicsContext, size: CGSize, geometry: GeometryProxy) {
        let gridColor = Color(hex: "#FFFC00").opacity(0.3)
        let gridSpacing: CGFloat = 50 // pixels

        // Draw vertical lines
        var x: CGFloat = 0
        while x <= size.width {
            let path = Path { p in
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.stroke(path, with: .color(gridColor), lineWidth: 1)
            x += gridSpacing
        }

        // Draw horizontal lines
        var y: CGFloat = 0
        while y <= size.height {
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(gridColor), lineWidth: 1)
            y += gridSpacing
        }

        // Draw grid labels (simplified - real MGRS would show actual grid squares)
        drawGridLabels(context: context, size: size, spacing: gridSpacing)
    }

    private func drawGridLabels(context: GraphicsContext, size: CGSize, spacing: CGFloat) {
        let labelColor = Color(hex: "#FFFC00").opacity(0.5)

        // Calculate MGRS grid zone
        let zone = Int((region.center.longitude + 180) / 6) + 1
        let latBand = getLatitudeBand(region.center.latitude)

        // Draw grid zone designation in corners
        let label = "\(zone)\(latBand)"

        let context = context
        context.drawLayer { ctx in
            // Top-left corner
            let text = Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(labelColor)

            ctx.draw(text, at: CGPoint(x: 20, y: 20))
        }
    }

    private func getLatitudeBand(_ latitude: Double) -> String {
        let bands = ["C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X"]
        let index = Int((latitude + 80) / 8)
        if index < 0 || index >= bands.count {
            return "X"
        }
        return bands[index]
    }
}

// MARK: - Preview

struct ScaleBarView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.ignoresSafeArea()

            VStack(spacing: 40) {
                // Close zoom
                ScaleBarView(
                    region: MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ),
                    isVisible: true
                )

                // Medium zoom
                ScaleBarView(
                    region: MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    ),
                    isVisible: true
                )

                // Far zoom
                ScaleBarView(
                    region: MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
                        span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
                    ),
                    isVisible: true
                )
            }
        }

        // Grid overlay preview
        ZStack {
            Color.black.ignoresSafeArea()

            GridOverlayView(
                region: MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                ),
                isVisible: true
            )
        }
    }
}
