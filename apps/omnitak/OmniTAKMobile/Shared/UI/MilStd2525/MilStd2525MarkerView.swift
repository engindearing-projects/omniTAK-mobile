//
//  MilStd2525MarkerView.swift
//  OmniTAKMobile
//
//  MIL-STD-2525B compliant map marker annotation view with proper affiliation shapes
//

import MapKit
import SwiftUI
import UIKit

// MARK: - MIL-STD-2525 Map Annotation View

/// Custom MKAnnotationView that displays MIL-STD-2525B military symbols
class MilStd2525MapAnnotationView: MKAnnotationView {
    private let markerSize: CGFloat = 24
    private let callsignHeight: CGFloat = 14
    private var hostingController: UIHostingController<MilStdMarkerSymbolView>?

    var cotType: String = "a-u-G" {
        didSet {
            updateSymbol()
        }
    }

    var callsign: String = "UNKNOWN" {
        didSet {
            updateSymbol()
        }
    }

    var echelon: MilStdEchelon? = nil {
        didSet {
            updateSymbol()
        }
    }

    var isMarkerSelected: Bool = false {
        didSet {
            updateSymbol()
        }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        canShowCallout = false // Custom info panel instead
        centerOffset = CGPoint(x: 0, y: -markerSize / 2)
        frame = CGRect(x: 0, y: 0, width: markerSize * 2.5, height: markerSize + callsignHeight + 6)

        // Create initial hosting controller
        let symbolView = MilStdMarkerSymbolView(
            cotType: cotType,
            callsign: callsign,
            echelon: echelon,
            size: markerSize,
            isSelected: isMarkerSelected
        )
        hostingController = UIHostingController(rootView: symbolView)
        hostingController?.view.backgroundColor = .clear

        if let hostView = hostingController?.view {
            hostView.frame = bounds
            hostView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(hostView)
        }

        backgroundColor = .clear
    }

    private func updateSymbol() {
        let newView = MilStdMarkerSymbolView(
            cotType: cotType,
            callsign: callsign,
            echelon: echelon,
            size: markerSize,
            isSelected: isMarkerSelected
        )
        hostingController?.rootView = newView
    }

    func configure(cotType: String, callsign: String, echelon: MilStdEchelon? = nil) {
        self.cotType = cotType
        self.callsign = callsign
        self.echelon = echelon
        updateSymbol()
    }
}

// MARK: - SwiftUI Marker Symbol View

/// SwiftUI view for the marker symbol with proper MIL-STD-2525B shapes
struct MilStdMarkerSymbolView: View {
    let cotType: String
    let callsign: String
    let echelon: MilStdEchelon?
    let size: CGFloat
    let isSelected: Bool

    private var properties: MilStdSymbolProperties {
        var props = MilStdCoTParser.parse(cotType: cotType)
        if let echelonOverride = echelon {
            props = MilStdSymbolProperties(
                affiliation: props.affiliation,
                battleDimension: props.battleDimension,
                unitType: props.unitType,
                status: props.status,
                echelon: echelonOverride,
                modifiers: props.modifiers
            )
        }
        return props
    }

    // Adaptive stroke width based on size
    private var strokeWidth: CGFloat {
        max(1.5, size * 0.08)
    }

    // Adaptive icon size
    private var iconSize: CGFloat {
        size * 0.45
    }

    // Adaptive corner radius for friendly rectangle
    private var cornerRadius: CGFloat {
        size * 0.12
    }

    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                // Selection highlight
                if isSelected {
                    affiliationShape
                        .fill(Color.white.opacity(0.25))
                        .frame(width: size * 1.2, height: size * 1.2)
                        .blur(radius: 3)
                }

                // Shadow/glow for visibility on any background
                affiliationShape
                    .fill(Color.black.opacity(0.4))
                    .frame(width: size + 2, height: size + 2)
                    .blur(radius: 1)

                // Main affiliation shape with fill
                affiliationShape
                    .fill(properties.affiliation.fillColor)
                    .frame(width: size, height: size)

                // Shape outline
                affiliationShape
                    .stroke(properties.affiliation.color, lineWidth: strokeWidth)
                    .frame(width: size, height: size)

                // Unit type icon inside
                Image(systemName: properties.unitType.icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(properties.affiliation.color)
            }

            // Callsign label - compact and readable
            Text(callsign)
                .font(.system(size: max(8, size * 0.35), weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(properties.affiliation.color.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                )
        }
    }

    private var affiliationShape: AnyShape {
        switch properties.affiliation {
        case .friendly, .assumed:
            // Rectangle for friendly (blue) - with rounded corners
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
        case .hostile, .suspect, .joker, .faker:
            // Diamond for hostile (red)
            return AnyShape(RotatedSquare())
        case .neutral:
            // Square for neutral (green) - slight rounding
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius * 0.5))
        case .unknown, .pending:
            // Quatrefoil/Cloverleaf for unknown (yellow)
            return AnyShape(QuatrefoilShape())
        }
    }
}

// MARK: - Custom Shapes for Affiliation

/// Diamond shape (45-degree rotated square) for hostile units
struct RotatedSquare: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfWidth = rect.width / 2
        let halfHeight = rect.height / 2

        path.move(to: CGPoint(x: center.x, y: center.y - halfHeight))
        path.addLine(to: CGPoint(x: center.x + halfWidth, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + halfHeight))
        path.addLine(to: CGPoint(x: center.x - halfWidth, y: center.y))
        path.closeSubpath()

        return path
    }
}

/// Quatrefoil/Cloverleaf shape for unknown units
struct QuatrefoilShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 3.2

        // Create four overlapping circles
        let offsets: [(CGFloat, CGFloat)] = [
            (0, -radius * 0.65),   // Top
            (radius * 0.65, 0),     // Right
            (0, radius * 0.65),     // Bottom
            (-radius * 0.65, 0)     // Left
        ]

        for (dx, dy) in offsets {
            let circleCenter = CGPoint(x: center.x + dx, y: center.y + dy)
            path.addEllipse(in: CGRect(
                x: circleCenter.x - radius,
                y: circleCenter.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }

        return path
    }
}

// MARK: - Compact Marker Symbol (Icon Only)

/// Smaller version showing just the shape without callsign
struct CompactMilStdMarkerView: View {
    let cotType: String
    let size: CGFloat

    private var properties: MilStdSymbolProperties {
        MilStdCoTParser.parse(cotType: cotType)
    }

    private var strokeWidth: CGFloat {
        max(1.5, size * 0.08)
    }

    private var cornerRadius: CGFloat {
        size * 0.12
    }

    var body: some View {
        ZStack {
            // Shadow for visibility
            affiliationShape
                .fill(Color.black.opacity(0.35))
                .frame(width: size + 1, height: size + 1)
                .blur(radius: 0.5)

            affiliationShape
                .fill(properties.affiliation.fillColor)
                .frame(width: size, height: size)

            affiliationShape
                .stroke(properties.affiliation.color, lineWidth: strokeWidth)
                .frame(width: size, height: size)

            Image(systemName: properties.unitType.icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(properties.affiliation.color)
        }
    }

    private var affiliationShape: AnyShape {
        switch properties.affiliation {
        case .friendly, .assumed:
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
        case .hostile, .suspect, .joker, .faker:
            return AnyShape(RotatedSquare())
        case .neutral:
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius * 0.5))
        case .unknown, .pending:
            return AnyShape(QuatrefoilShape())
        }
    }
}

// MARK: - MIL-STD Symbol Legend

/// Visual legend showing all affiliation shapes
struct MilStdAffiliationLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UNIT AFFILIATIONS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFF00"))

            ForEach([
                ("Friendly", "a-f-G-U-C-I", "Blue Rectangle"),
                ("Hostile", "a-h-G-U-C-I", "Red Diamond"),
                ("Neutral", "a-n-G-U-C-I", "Green Square"),
                ("Unknown", "a-u-G-U-C-I", "Yellow Quatrefoil")
            ], id: \.0) { name, type, shape in
                HStack(spacing: 12) {
                    CompactMilStdMarkerView(cotType: type, size: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)

                        Text(shape)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
        )
    }
}

// MARK: - UIKit Integration Helper

/// Helper to create annotation views for MapKit
extension MilStd2525MapAnnotationView {
    static func create(
        for annotation: MKAnnotation,
        cotType: String,
        callsign: String,
        echelon: MilStdEchelon? = nil
    ) -> MilStd2525MapAnnotationView {
        let view = MilStd2525MapAnnotationView(annotation: annotation, reuseIdentifier: "MilStd2525Marker")
        view.configure(cotType: cotType, callsign: callsign, echelon: echelon)
        return view
    }
}

// MARK: - CoT Marker Annotation

/// Custom annotation class that holds CoT marker data
class CoTMarkerAnnotation: NSObject, MKAnnotation {
    let cotMarker: CoTMarker
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    init(marker: CoTMarker) {
        self.cotMarker = marker
        self.coordinate = marker.coordinate
        self.title = marker.callsign
        self.subtitle = marker.type
        super.init()
    }
}

// MARK: - Preview

struct MilStd2525MarkerView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Text("MIL-STD-2525B Map Markers")
                    .font(.title2)
                    .foregroundColor(.white)

                HStack(spacing: 30) {
                    MilStdMarkerSymbolView(
                        cotType: "a-f-G-U-C-I",
                        callsign: "ALPHA-1",
                        echelon: .platoon,
                        size: 40,
                        isSelected: false
                    )

                    MilStdMarkerSymbolView(
                        cotType: "a-h-G-U-C-A",
                        callsign: "HOSTILE-3",
                        echelon: .company,
                        size: 40,
                        isSelected: true
                    )

                    MilStdMarkerSymbolView(
                        cotType: "a-n-G-U-C",
                        callsign: "NEUTRAL",
                        echelon: nil,
                        size: 40,
                        isSelected: false
                    )

                    MilStdMarkerSymbolView(
                        cotType: "a-u-G",
                        callsign: "UNKNOWN",
                        echelon: nil,
                        size: 40,
                        isSelected: false
                    )
                }

                MilStdAffiliationLegend()
                    .frame(width: 280)
            }
            .padding()
        }
        .preferredColorScheme(.dark)
    }
}
