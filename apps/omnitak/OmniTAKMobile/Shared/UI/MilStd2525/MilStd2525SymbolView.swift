//
//  MilStd2525SymbolView.swift
//  OmniTAKMobile
//
//  SwiftUI View for rendering MIL-STD-2525B Military Symbols
//

import SwiftUI

// MARK: - Main Symbol View

struct MilStd2525SymbolView: View {
    let cotType: String
    var echelonOverride: MilStdEchelon? = nil
    var statusOverride: MilStdStatus? = nil
    var size: CGFloat = 40
    var showLabel: Bool = false
    var label: String? = nil

    private var properties: MilStdSymbolProperties {
        var props = MilStdCoTParser.parse(cotType: cotType)
        if let echelon = echelonOverride {
            props = MilStdSymbolProperties(
                affiliation: props.affiliation,
                battleDimension: props.battleDimension,
                unitType: props.unitType,
                status: statusOverride ?? props.status,
                echelon: echelon,
                modifiers: props.modifiers
            )
        } else if let status = statusOverride {
            props = MilStdSymbolProperties(
                affiliation: props.affiliation,
                battleDimension: props.battleDimension,
                unitType: props.unitType,
                status: status,
                echelon: props.echelon,
                modifiers: props.modifiers
            )
        }
        return props
    }

    var body: some View {
        VStack(spacing: 2) {
            // Echelon indicator above frame
            if let echelon = properties.echelon {
                EchelonIndicatorView(echelon: echelon, color: properties.affiliation.color)
                    .frame(height: size * 0.3)
            }

            // Main symbol frame with icon
            ZStack {
                // Frame shape based on affiliation
                AffiliationFrameView(
                    affiliation: properties.affiliation,
                    battleDimension: properties.battleDimension,
                    status: properties.status,
                    modifiers: properties.modifiers
                )

                // Unit type icon
                UnitTypeIconView(
                    unitType: properties.unitType,
                    color: properties.affiliation.color
                )
                .frame(width: size * 0.6, height: size * 0.6)

                // Task force indicator
                if properties.modifiers.isTaskForce {
                    TaskForceIndicatorView(color: properties.affiliation.color)
                }

                // Headquarters indicator
                if properties.modifiers.isHeadquarters {
                    HeadquartersIndicatorView(color: properties.affiliation.color)
                        .offset(y: size * 0.6)
                }

                // Feint/Dummy indicator
                if properties.modifiers.isFeintDummy {
                    FeintDummyIndicatorView(color: properties.affiliation.color)
                        .offset(y: -size * 0.6)
                }
            }
            .frame(width: size, height: size)

            // Optional label
            if showLabel, let labelText = label {
                Text(labelText)
                    .font(.system(size: size * 0.25, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Affiliation Frame Shape

struct AffiliationFrameView: View {
    let affiliation: MilStdAffiliation
    let battleDimension: MilStdBattleDimension
    let status: MilStdStatus
    let modifiers: MilStdModifiers

    var body: some View {
        GeometryReader { geometry in
            let lineWidth: CGFloat = 2.5

            ZStack {
                // Fill
                affiliationShape(size: geometry.size)
                    .fill(affiliation.fillColor)

                // Stroke
                if status.isDashed {
                    affiliationShape(size: geometry.size)
                        .stroke(
                            affiliation.color,
                            style: StrokeStyle(
                                lineWidth: lineWidth,
                                dash: [5, 3]
                            )
                        )
                } else {
                    affiliationShape(size: geometry.size)
                        .stroke(affiliation.color, lineWidth: lineWidth)
                }
            }
        }
    }

    private func affiliationShape(size: CGSize) -> AnyShape {
        switch affiliation {
        case .friendly, .assumed:
            // Rectangle for friendly
            return AnyShape(RoundedRectangle(cornerRadius: 2))
        case .hostile, .suspect, .joker, .faker:
            // Diamond for hostile
            return AnyShape(Diamond())
        case .neutral:
            // Square for neutral (same as rectangle but emphasized)
            return AnyShape(Rectangle())
        case .unknown, .pending:
            // Cloverleaf/quatrefoil for unknown
            return AnyShape(Cloverleaf())
        }
    }
}

// MARK: - Type Erased Shape

struct AnyShape: Shape {
    private let pathClosure: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathClosure = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        pathClosure(rect)
    }
}

extension AnyShape: @unchecked Sendable {}

// MARK: - Custom Shapes

struct Diamond: Shape {
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

struct Cloverleaf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 3

        // Create four overlapping circles (quatrefoil)
        let offsets: [(CGFloat, CGFloat)] = [
            (0, -radius * 0.7),   // Top
            (radius * 0.7, 0),     // Right
            (0, radius * 0.7),     // Bottom
            (-radius * 0.7, 0)     // Left
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

// MARK: - Unit Type Icon

struct UnitTypeIconView: View {
    let unitType: MilStdUnitType
    let color: Color

    var body: some View {
        ZStack {
            // Use SF Symbol if available, otherwise draw custom
            if let sfSymbol = sfSymbolName {
                Image(systemName: sfSymbol)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(color)
            } else {
                // Custom drawn symbol
                CustomUnitSymbol(unitType: unitType, color: color)
            }
        }
    }

    private var sfSymbolName: String? {
        switch unitType {
        case .infantry:
            return nil  // Use custom crossed rifles
        case .mechanizedInfantry:
            return "car.side.fill"
        case .armor:
            return nil  // Use custom oval
        case .cavalry:
            return nil  // Use custom diagonal
        case .artillery:
            return nil  // Use custom dot
        case .airDefense:
            return "antenna.radiowaves.left.and.right"
        case .engineer:
            return "wrench.and.screwdriver.fill"
        case .reconnaissance:
            return "eye.fill"
        case .specialForces:
            return "bolt.fill"
        case .signal:
            return "bolt.horizontal.fill"
        case .militaryIntelligence:
            return "brain.head.profile"
        case .chemicalBiological:
            return "aqi.medium"
        case .militaryPolice:
            return "shield.lefthalf.filled"
        case .civilAffairs:
            return "person.3.fill"
        case .supply:
            return "shippingbox.fill"
        case .transportation:
            return "truck.box.fill"
        case .maintenance:
            return "wrench.fill"
        case .medical:
            return "cross.fill"
        case .aviation:
            return "airplane"
        case .attackHelicopter:
            return "helicopter.fill"
        case .utilityHelicopter:
            return "helicopter"
        case .reconHelicopter:
            return "helicopter"
        case .headquarters:
            return "flag.fill"
        case .combatSupport:
            return "hammer.fill"
        case .unknown:
            return "questionmark"
        }
    }
}

// MARK: - Custom Unit Symbol Drawing

struct CustomUnitSymbol: View {
    let unitType: MilStdUnitType
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

                switch unitType {
                case .infantry:
                    // Crossed diagonal lines (X)
                    drawInfantry(context: context, center: center, size: size)

                case .armor:
                    // Oval/Ellipse
                    drawArmor(context: context, center: center, size: size)

                case .cavalry:
                    // Single diagonal line
                    drawCavalry(context: context, center: center, size: size)

                case .artillery:
                    // Filled circle
                    drawArtillery(context: context, center: center, size: size)

                default:
                    // Default: Draw text symbol
                    drawTextSymbol(context: context, center: center, size: size)
                }
            }
        }
    }

    private func drawInfantry(context: GraphicsContext, center: CGPoint, size: CGFloat) {
        var path = Path()
        let halfSize = size * 0.4

        // Draw X
        path.move(to: CGPoint(x: center.x - halfSize, y: center.y - halfSize))
        path.addLine(to: CGPoint(x: center.x + halfSize, y: center.y + halfSize))
        path.move(to: CGPoint(x: center.x + halfSize, y: center.y - halfSize))
        path.addLine(to: CGPoint(x: center.x - halfSize, y: center.y + halfSize))

        context.stroke(path, with: .color(color), lineWidth: 3)
    }

    private func drawArmor(context: GraphicsContext, center: CGPoint, size: CGFloat) {
        let ellipse = Path(ellipseIn: CGRect(
            x: center.x - size * 0.4,
            y: center.y - size * 0.25,
            width: size * 0.8,
            height: size * 0.5
        ))

        context.stroke(ellipse, with: .color(color), lineWidth: 3)
    }

    private func drawCavalry(context: GraphicsContext, center: CGPoint, size: CGFloat) {
        var path = Path()
        let halfSize = size * 0.4

        // Single diagonal line
        path.move(to: CGPoint(x: center.x - halfSize, y: center.y + halfSize))
        path.addLine(to: CGPoint(x: center.x + halfSize, y: center.y - halfSize))

        context.stroke(path, with: .color(color), lineWidth: 3)
    }

    private func drawArtillery(context: GraphicsContext, center: CGPoint, size: CGFloat) {
        let circle = Path(ellipseIn: CGRect(
            x: center.x - size * 0.2,
            y: center.y - size * 0.2,
            width: size * 0.4,
            height: size * 0.4
        ))

        context.fill(circle, with: .color(color))
    }

    private func drawTextSymbol(context: GraphicsContext, center: CGPoint, size: CGFloat) {
        let text = Text(unitType.symbolCharacter)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundColor(color)

        context.draw(text, at: center)
    }
}

// MARK: - Echelon Indicator

struct EchelonIndicatorView: View {
    let echelon: MilStdEchelon
    let color: Color

    var body: some View {
        Text(echelon.symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(color)
    }
}

// MARK: - Task Force Indicator

struct TaskForceIndicatorView: View {
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let rect = geometry.frame(in: .local)
                // Vertical line through top of frame
                path.move(to: CGPoint(x: rect.midX, y: 0))
                path.addLine(to: CGPoint(x: rect.midX, y: -rect.height * 0.3))
                // Horizontal line at top
                path.move(to: CGPoint(x: rect.minX, y: 0))
                path.addLine(to: CGPoint(x: rect.maxX, y: 0))
            }
            .stroke(color, lineWidth: 2)
        }
    }
}

// MARK: - Headquarters Indicator

struct HeadquartersIndicatorView: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 4, height: 20)
    }
}

// MARK: - Feint/Dummy Indicator

struct FeintDummyIndicatorView: View {
    let color: Color

    var body: some View {
        Text(">")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(color)
    }
}

// MARK: - Map Marker Symbol View

struct MilStdMapMarkerView: View {
    let cotType: String
    let callsign: String
    var echelon: MilStdEchelon? = nil
    var status: MilStdStatus = .present
    var size: CGFloat = 48
    var showCallsign: Bool = true
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Selection highlight
                if isSelected {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: size * 1.4, height: size * 1.4)
                }

                // Main symbol
                MilStd2525SymbolView(
                    cotType: cotType,
                    echelonOverride: echelon,
                    statusOverride: status,
                    size: size,
                    showLabel: false
                )
                .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
            }

            // Callsign label
            if showCallsign {
                Text(callsign)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.75))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
    }
}

// MARK: - Scalable Symbol for Different Zoom Levels

struct ScalableMilStdSymbolView: View {
    let cotType: String
    let zoomLevel: Double
    let baseSize: CGFloat

    private var scaledSize: CGFloat {
        // Scale symbol based on zoom level
        // Lower zoom = smaller symbols, higher zoom = larger symbols
        let minSize: CGFloat = 20
        let maxSize: CGFloat = 80
        let scaleFactor = CGFloat(min(max(zoomLevel / 15.0, 0.5), 2.0))

        return min(max(baseSize * scaleFactor, minSize), maxSize)
    }

    private var showDetails: Bool {
        zoomLevel > 10
    }

    var body: some View {
        MilStd2525SymbolView(
            cotType: cotType,
            size: scaledSize,
            showLabel: showDetails
        )
    }
}

// MARK: - Symbol Legend View

struct MilStdSymbolLegendView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Affiliations
                Section(header: Text("Affiliations").font(.headline)) {
                    ForEach(MilStdAffiliation.allCases.prefix(4), id: \.self) { affiliation in
                        HStack {
                            MilStd2525SymbolView(
                                cotType: "a-\(affiliation.rawValue)-G-U-C-I",
                                size: 30
                            )
                            Text(affiliation.displayName)
                            Spacer()
                        }
                    }
                }

                Divider()

                // Echelons
                Section(header: Text("Echelons").font(.headline)) {
                    ForEach([MilStdEchelon.team, .squad, .platoon, .company, .battalion, .brigade, .division], id: \.self) { echelon in
                        HStack {
                            Text(echelon.symbol)
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 40)
                            Text(echelon.displayName)
                            Spacer()
                        }
                    }
                }

                Divider()

                // Unit Types
                Section(header: Text("Unit Types").font(.headline)) {
                    ForEach([MilStdUnitType.infantry, .armor, .artillery, .cavalry, .engineer, .medical], id: \.self) { unitType in
                        HStack {
                            MilStd2525SymbolView(
                                cotType: "a-f-G-U-C-I",
                                size: 30
                            )
                            Text(unitType.displayName)
                            Spacer()
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Preview Provider

struct MilStd2525SymbolView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("MIL-STD-2525B Symbols")
                .font(.title)

            HStack(spacing: 30) {
                VStack {
                    MilStd2525SymbolView(
                        cotType: "a-f-G-U-C-I",
                        echelonOverride: .battalion,
                        size: 50
                    )
                    Text("Friendly Infantry")
                        .font(.caption)
                }

                VStack {
                    MilStd2525SymbolView(
                        cotType: "a-h-G-U-C-A",
                        echelonOverride: .company,
                        size: 50
                    )
                    Text("Hostile Armor")
                        .font(.caption)
                }

                VStack {
                    MilStd2525SymbolView(
                        cotType: "a-n-G-U-C-F",
                        echelonOverride: .platoon,
                        size: 50
                    )
                    Text("Neutral Artillery")
                        .font(.caption)
                }

                VStack {
                    MilStd2525SymbolView(
                        cotType: "a-u-G-U-C",
                        size: 50
                    )
                    Text("Unknown Unit")
                        .font(.caption)
                }
            }

            Divider()

            HStack(spacing: 30) {
                VStack {
                    MilStdMapMarkerView(
                        cotType: "a-f-G-U-C-I",
                        callsign: "Alpha-1",
                        echelon: .squad,
                        size: 40,
                        isSelected: false
                    )
                }

                VStack {
                    MilStdMapMarkerView(
                        cotType: "a-h-G-U-C-A",
                        callsign: "Enemy Tank",
                        echelon: .platoon,
                        size: 40,
                        isSelected: true
                    )
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}

// MARK: - UIKit Integration for MapKit

#if canImport(UIKit)
import UIKit

class MilStdSymbolAnnotationView: UIView {
    private var hostingController: UIHostingController<MilStdMapMarkerView>?

    init(cotType: String, callsign: String, echelon: MilStdEchelon? = nil, size: CGFloat = 48) {
        super.init(frame: CGRect(x: 0, y: 0, width: size * 1.5, height: size * 2))

        let symbolView = MilStdMapMarkerView(
            cotType: cotType,
            callsign: callsign,
            echelon: echelon,
            size: size
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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateSymbol(cotType: String, callsign: String, echelon: MilStdEchelon? = nil, isSelected: Bool = false) {
        let newView = MilStdMapMarkerView(
            cotType: cotType,
            callsign: callsign,
            echelon: echelon,
            isSelected: isSelected
        )
        hostingController?.rootView = newView
    }
}
#endif
