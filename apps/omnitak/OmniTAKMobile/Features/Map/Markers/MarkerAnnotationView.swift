//
//  MarkerAnnotationView.swift
//  OmniTAKMobile
//
//  Custom MKAnnotationView for point markers with tactical styling
//

import MapKit
import SwiftUI
import UIKit

// MARK: - Point Marker Annotation View

/// Custom annotation view for tactical point markers
class PointMarkerAnnotationView: MKAnnotationView {

    // MARK: - Properties

    private var marker: PointMarker?
    private let iconImageView = UIImageView()
    private let labelView = UILabel()
    private let badgeView = UIView()
    private let badgeLabel = UILabel()

    static let reuseIdentifier = "PointMarkerAnnotation"

    // MARK: - Initialization

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }

    // MARK: - Setup

    private func setupViews() {
        canShowCallout = true
        isDraggable = false
        clusteringIdentifier = "PointMarkerCluster"

        // Configure icon view
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)

        // Configure label
        labelView.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        labelView.textColor = .white
        labelView.textAlignment = .center
        labelView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        labelView.layer.cornerRadius = 4
        labelView.layer.masksToBounds = true
        labelView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelView)

        // Configure badge
        badgeView.layer.cornerRadius = 8
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.isHidden = true
        addSubview(badgeView)

        badgeLabel.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.textAlignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeView.addSubview(badgeLabel)

        // Layout constraints
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),

            labelView.centerXAnchor.constraint(equalTo: centerXAnchor),
            labelView.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 2),
            labelView.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            labelView.heightAnchor.constraint(equalToConstant: 16),

            badgeView.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: -8),
            badgeView.bottomAnchor.constraint(equalTo: iconImageView.topAnchor, constant: 8),
            badgeView.widthAnchor.constraint(equalToConstant: 16),
            badgeView.heightAnchor.constraint(equalToConstant: 16),

            badgeLabel.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
            badgeLabel.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor)
        ])

        // Set frame
        frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        centerOffset = CGPoint(x: 0, y: -25)
    }

    // MARK: - Configuration

    func configure(with markerAnnotation: PointMarkerAnnotation) {
        self.marker = markerAnnotation.marker
        updateAppearance()
        setupCallout()
    }

    private func updateAppearance() {
        guard let marker = marker else { return }

        // Create icon image
        let iconImage = createMarkerIcon(for: marker)
        iconImageView.image = iconImage

        // Update label
        labelView.text = " \(marker.name) "
        labelView.sizeToFit()
        labelView.frame.size.width = max(labelView.frame.width + 8, 40)
        labelView.frame.size.height = 16

        // Update badge for SALUTE reports
        if marker.saluteReport != nil {
            badgeView.isHidden = false
            badgeView.backgroundColor = UIColor.systemPurple
            badgeLabel.text = "S"
        } else if marker.isBroadcast {
            badgeView.isHidden = false
            badgeView.backgroundColor = UIColor.systemGreen
            badgeLabel.text = "B"
        } else {
            badgeView.isHidden = true
        }

        // Add glow effect for hostile markers
        if marker.affiliation == .hostile {
            layer.shadowColor = UIColor.red.cgColor
            layer.shadowRadius = 8
            layer.shadowOpacity = 0.6
            layer.shadowOffset = .zero
        } else {
            layer.shadowOpacity = 0
        }
    }

    private func createMarkerIcon(for marker: PointMarker) -> UIImage {
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            // Draw background circle
            let bgColor = marker.affiliation.uiColor
            bgColor.setFill()
            let circlePath = UIBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            circlePath.fill()

            // Draw border
            UIColor.white.setStroke()
            circlePath.lineWidth = 2
            circlePath.stroke()

            // Draw icon
            let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            if let icon = UIImage(systemName: marker.iconName, withConfiguration: iconConfig) {
                let iconSize = icon.size
                let iconRect = CGRect(
                    x: (size.width - iconSize.width) / 2,
                    y: (size.height - iconSize.height) / 2,
                    width: iconSize.width,
                    height: iconSize.height
                )
                icon.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: iconRect)
            }
        }
    }

    private func setupCallout() {
        guard let marker = marker else { return }

        // Create custom callout accessory
        let detailButton = UIButton(type: .detailDisclosure)
        rightCalloutAccessoryView = detailButton

        // Create left accessory with affiliation indicator
        let affiliationView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        affiliationView.backgroundColor = marker.affiliation.uiColor.withAlphaComponent(0.3)
        affiliationView.layer.cornerRadius = 8

        let affiliationLabel = UILabel(frame: affiliationView.bounds)
        affiliationLabel.text = marker.affiliation.shortCode
        affiliationLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        affiliationLabel.textColor = marker.affiliation.uiColor
        affiliationLabel.textAlignment = .center
        affiliationView.addSubview(affiliationLabel)

        leftCalloutAccessoryView = affiliationView
    }

    // MARK: - Override

    override func prepareForReuse() {
        super.prepareForReuse()
        marker = nil
        badgeView.isHidden = true
        layer.shadowOpacity = 0
    }
}

// MARK: - Marker Detail Callout View

/// SwiftUI view for marker detail callout
struct MarkerDetailCalloutView: View {
    let marker: PointMarker
    let onEdit: () -> Void
    let onSALUTE: () -> Void
    let onBroadcast: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: marker.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(marker.affiliation.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(marker.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text(marker.affiliation.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(marker.affiliation.color)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                }
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Location Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                    Text("LOCATION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                }

                Text(marker.mgrsString)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                Text("LAT: \(String(format: "%.6f", marker.coordinate.latitude)) LON: \(String(format: "%.6f", marker.coordinate.longitude))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)
            }

            // Time Info
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Text(marker.formattedTimestamp)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
            }

            // Remarks
            if let remarks = marker.remarks, !remarks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("REMARKS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)

                    Text(remarks)
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .lineLimit(3)
                }
            }

            // SALUTE Summary
            if let salute = marker.saluteReport {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.purple)
                        Text("SALUTE REPORT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.purple)
                    }

                    Text(salute.summary)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(8)
            }

            // Status Badges
            HStack(spacing: 8) {
                if marker.isBroadcast {
                    StatusBadge(text: "BROADCAST", color: .green)
                }

                if marker.saluteReport != nil {
                    StatusBadge(text: "SALUTE", color: .purple)
                }

                Spacer()
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Action Buttons
            HStack(spacing: 12) {
                ActionButton(icon: "pencil", label: "Edit", color: .blue, action: onEdit)
                ActionButton(icon: "doc.text", label: "SALUTE", color: .purple, action: onSALUTE)
                ActionButton(icon: "antenna.radiowaves.left.and.right", label: "Send", color: .cyan, action: onBroadcast)
                ActionButton(icon: "trash", label: "Delete", color: .red, action: onDelete)
            }
        }
        .padding()
        .background(Color(hex: "#1E1E1E"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(marker.affiliation.color.opacity(0.5), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.5), radius: 10)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .cornerRadius(4)
    }
}

struct PointMarkerActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .cornerRadius(8)
        }
    }
}

// MARK: - Marker Info Panel (Floating)

struct PointMarkerInfoPanel: View {
    let marker: PointMarker
    @Binding var isPresented: Bool
    let onEdit: () -> Void
    let onSALUTE: () -> Void
    let onBroadcast: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack {
            Spacer()

            MarkerDetailCalloutView(
                marker: marker,
                onEdit: onEdit,
                onSALUTE: onSALUTE,
                onBroadcast: onBroadcast,
                onDelete: onDelete,
                onClose: { isPresented = false }
            )
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(), value: isPresented)
    }
}

// MARK: - Long Press Gesture Handler for Map

/// Handles long press on map for quick marker placement
struct LongPressMarkerGesture {
    static func handleLongPress(
        at location: CGPoint,
        in mapView: MKMapView,
        service: PointDropperService,
        onMarkerCreated: ((PointMarker) -> Void)? = nil
    ) {
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        // Quick drop with current affiliation
        let marker = service.quickDrop(at: coordinate, broadcast: false)

        // Notify
        onMarkerCreated?(marker)

        #if DEBUG
        print("📍 Long press marker created at: \(coordinate.latitude), \(coordinate.longitude)")
        #endif
    }
}

// MARK: - Point Marker Cluster Annotation View

class PointMarkerClusterAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "PointMarkerCluster"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        centerOffset = CGPoint(x: 0, y: -10)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()

        if let cluster = annotation as? MKClusterAnnotation {
            let totalCount = cluster.memberAnnotations.count

            // Count by affiliation
            var hostileCount = 0
            var friendlyCount = 0
            var unknownCount = 0
            var neutralCount = 0

            for memberAnnotation in cluster.memberAnnotations {
                if let markerAnnotation = memberAnnotation as? PointMarkerAnnotation {
                    switch markerAnnotation.marker.affiliation {
                    case .hostile: hostileCount += 1
                    case .friendly: friendlyCount += 1
                    case .unknown: unknownCount += 1
                    case .neutral: neutralCount += 1
                    }
                }
            }

            // Determine dominant affiliation
            let maxCount = max(hostileCount, friendlyCount, unknownCount, neutralCount)
            let dominantAffiliation: MarkerAffiliation
            if hostileCount == maxCount {
                dominantAffiliation = .hostile
            } else if friendlyCount == maxCount {
                dominantAffiliation = .friendly
            } else if unknownCount == maxCount {
                dominantAffiliation = .unknown
            } else {
                dominantAffiliation = .neutral
            }

            // Create cluster image
            image = createClusterImage(count: totalCount, affiliation: dominantAffiliation)
        }
    }

    private func createClusterImage(count: Int, affiliation: MarkerAffiliation) -> UIImage {
        let size = CGSize(width: 40, height: 40)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            // Draw background
            affiliation.uiColor.setFill()
            let path = UIBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            path.fill()

            // Draw border
            UIColor.white.setStroke()
            path.lineWidth = 2
            path.stroke()

            // Draw count text
            let text = "\(count)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
}
