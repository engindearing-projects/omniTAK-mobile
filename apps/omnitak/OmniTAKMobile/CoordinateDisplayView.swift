import SwiftUI
import CoreLocation

// MARK: - Coordinate Display View
// ATAK-style coordinate display showing multiple formats (Lat/Lon, MGRS, UTM)

struct CoordinateDisplayView: View {
    let coordinate: CLLocationCoordinate2D?
    let isVisible: Bool
    @State private var selectedFormat: CoordinateFormat = .mgrs
    @State private var isExpanded: Bool = false

    var body: some View {
        if isVisible, let coordinate = coordinate {
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer()
                        if isExpanded {
                            expandedCoordinateDisplay(for: coordinate)
                        } else {
                            collapsedCoordinateDisplay(for: coordinate)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.bottom, 20)
                    Spacer()
                }
            }
        }
    }

    private func collapsedCoordinateDisplay(for coordinate: CLLocationCoordinate2D) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#00FFFF"))

            Text(selectedFormat.rawValue)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))
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
    }

    private func expandedCoordinateDisplay(for coordinate: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Format selector buttons - scrollable for better UX
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(CoordinateFormat.allCases, id: \.self) { format in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFormat = format
                            }
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }) {
                            VStack(spacing: 2) {
                                Text(format.rawValue)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(selectedFormat == format ? .black : .white)

                                // Show indicator for special formats
                                if format == .bng {
                                    Text("UK")
                                        .font(.system(size: 7, weight: .medium))
                                        .foregroundColor(selectedFormat == format ? .black.opacity(0.7) : .white.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedFormat == format ? Color(hex: "#FFFC00") : Color.white.opacity(0.2))
                            .cornerRadius(6)
                        }
                    }
                }
            }
            .padding(.bottom, 4)

            // Coordinate value display
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(selectedFormat.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)

                    // Special indicator for BNG
                    if selectedFormat == .bng {
                        Image(systemName: "map.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }

                Text(formatCoordinate(coordinate, format: selectedFormat))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00FFFF"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded = false
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }

    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D, format: CoordinateFormat) -> String {
        switch format {
        case .latlon:
            return formatLatLon(coordinate)
        case .mgrs:
            return formatMGRS(coordinate)
        case .utm:
            return formatUTM(coordinate)
        case .bng:
            return formatBNG(coordinate)
        }
    }

    // MARK: - Lat/Lon Formatting

    private func formatLatLon(_ coordinate: CLLocationCoordinate2D) -> String {
        let latDirection = coordinate.latitude >= 0 ? "N" : "S"
        let lonDirection = coordinate.longitude >= 0 ? "E" : "W"

        let lat = abs(coordinate.latitude)
        let lon = abs(coordinate.longitude)

        // Degrees, Minutes, Seconds format
        let latDeg = Int(lat)
        let latMin = Int((lat - Double(latDeg)) * 60)
        let latSec = Int(((lat - Double(latDeg)) * 60 - Double(latMin)) * 60)

        let lonDeg = Int(lon)
        let lonMin = Int((lon - Double(lonDeg)) * 60)
        let lonSec = Int(((lon - Double(lonDeg)) * 60 - Double(lonMin)) * 60)

        return String(format: "%02d°%02d'%02d\"%@ %03d°%02d'%02d\"%@",
                      latDeg, latMin, latSec, latDirection,
                      lonDeg, lonMin, lonSec, lonDirection)
    }

    // MARK: - MGRS Formatting

    private func formatMGRS(_ coordinate: CLLocationCoordinate2D) -> String {
        // Simplified MGRS conversion (production should use proper library)
        let zone = Int((coordinate.longitude + 180) / 6) + 1
        let latBand = getLatitudeBand(coordinate.latitude)

        // Grid square (simplified - real MGRS uses 100km grid squares)
        let gridSquares = [
            "AA", "AB", "AC", "AD", "AE", "AF", "AG", "AH", "AJ", "AK",
            "BA", "BB", "BC", "BD", "BE", "BF", "BG", "BH", "BJ", "BK",
            "CA", "CB", "CC", "CD", "CE", "CF", "CG", "CH", "CJ", "CK",
            "DA", "DB", "DC", "DD", "DE", "DF", "DG", "DH", "DJ", "DK",
            "EA", "EB", "EC", "ED", "EE", "EF", "EG", "EH", "EJ", "EK",
            "FA", "FB", "FC", "FD", "FE", "FF", "FG", "FH", "FJ", "FK"
        ]
        let gridIndex = abs(Int(coordinate.latitude * 10 + coordinate.longitude * 10)) % gridSquares.count
        let gridSquare = gridSquares[gridIndex]

        // Easting and Northing (simplified calculation)
        let easting = Int((coordinate.longitude - Double((zone - 1) * 6 - 180)) * 111320 / 100000 * 10000) % 100000
        let northing = Int((coordinate.latitude + 90) * 111320 / 100000 * 10000) % 100000

        return String(format: "%02d%@ %@ %05d %05d", zone, latBand, gridSquare, easting, northing)
    }

    private func getLatitudeBand(_ latitude: Double) -> String {
        let bands = ["C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X"]
        let index = Int((latitude + 80) / 8)
        if index < 0 || index >= bands.count {
            return "X"
        }
        return bands[index]
    }

    // MARK: - UTM Formatting

    private func formatUTM(_ coordinate: CLLocationCoordinate2D) -> String {
        // UTM conversion (simplified)
        let zone = Int((coordinate.longitude + 180) / 6) + 1
        let latBand = getLatitudeBand(coordinate.latitude)

        // Calculate UTM easting and northing (simplified)
        let k0 = 0.9996 // UTM scale factor
        let e = 0.0818191908426 // WGS84 eccentricity
        let a = 6378137.0 // WGS84 equatorial radius

        let lon = coordinate.longitude * .pi / 180
        let lat = coordinate.latitude * .pi / 180
        let lonOriginDegrees = Double((zone - 1) * 6 - 180 + 3)
        let lonOrigin = lonOriginDegrees * .pi / 180

        let N = a / sqrt(1 - pow(e * sin(lat), 2))
        let T = pow(tan(lat), 2)
        let C = pow(e, 2) * pow(cos(lat), 2) / (1 - pow(e, 2))
        let A = (lon - lonOrigin) * cos(lat)

        // Easting
        let easting = Int(k0 * N * (A + (1 - T + C) * pow(A, 3) / 6) + 500000)

        // Northing
        let M = a * ((1 - pow(e, 2) / 4 - 3 * pow(e, 4) / 64) * lat)
        var northing = Int(k0 * M)

        // Add 10,000,000 meters for southern hemisphere
        if coordinate.latitude < 0 {
            northing += 10000000
        }

        return String(format: "%02d%@ %06dE %07dN", zone, latBand, easting, northing)
    }

    // MARK: - BNG Formatting

    private func formatBNG(_ coordinate: CLLocationCoordinate2D) -> String {
        // Use the BNGConverter for accurate conversion
        if BNGConverter.isWithinBNGBounds(coordinate) {
            return BNGConverter.formatBNG(coordinate, precision: .tenMeter, withSpaces: true)
        } else {
            return "Out of BNG bounds"
        }
    }
}

// MARK: - Coordinate Format Enum

enum CoordinateFormat: String, CaseIterable {
    case latlon = "LAT/LON"
    case mgrs = "MGRS"
    case utm = "UTM"
    case bng = "BNG"

    var displayName: String {
        switch self {
        case .latlon:
            return "Latitude/Longitude"
        case .mgrs:
            return "Military Grid Reference System"
        case .utm:
            return "Universal Transverse Mercator"
        case .bng:
            return "British National Grid"
        }
    }
}

// MARK: - Preview

struct CoordinateDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.ignoresSafeArea()

            VStack(spacing: 40) {
                // Washington DC
                CoordinateDisplayView(
                    coordinate: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
                    isVisible: true
                )

                // Sydney, Australia
                CoordinateDisplayView(
                    coordinate: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),
                    isVisible: true
                )

                // Tokyo, Japan
                CoordinateDisplayView(
                    coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
                    isVisible: true
                )
            }
        }
    }
}
