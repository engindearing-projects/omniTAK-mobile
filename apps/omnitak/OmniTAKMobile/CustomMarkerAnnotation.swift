//
//  CustomMarkerAnnotation.swift
//  OmniTAKTest
//
//  Custom map marker with unit-specific icons and callsign labels
//

import MapKit
import SwiftUI
import UIKit

class CustomMarkerAnnotation: MKAnnotationView {
    private let markerSize: CGFloat = 40
    private let labelHeight: CGFloat = 20
    private let labelPadding: CGFloat = 10

    var marker: EnhancedCoTMarker? {
        didSet {
            updateView()
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
        canShowCallout = false  // We'll use custom info panel
        centerOffset = CGPoint(x: 0, y: -markerSize / 2)
    }

    private func updateView() {
        guard let marker = marker else { return }

        // Create custom marker with icon and label
        let totalHeight = markerSize + labelHeight + 4
        let totalWidth = max(markerSize, CGFloat(marker.callsign.count * 7) + labelPadding)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: totalHeight))

        let image = renderer.image { context in
            // Draw icon background circle
            let iconX = (totalWidth - markerSize) / 2
            let iconRect = CGRect(x: iconX, y: 0, width: markerSize, height: markerSize)
            marker.affiliation.color.uiColor.setFill()
            let circlePath = UIBezierPath(ovalIn: iconRect)
            circlePath.fill()

            // Draw white border
            UIColor.white.setStroke()
            circlePath.lineWidth = 2
            circlePath.stroke()

            // Draw unit icon
            let iconConfig = UIImage.SymbolConfiguration(pointSize: markerSize * 0.5, weight: .bold)
            if let iconImage = UIImage(systemName: marker.unitType.iconName, withConfiguration: iconConfig) {
                let iconSize = iconImage.size
                let iconCenterX = iconX + (markerSize - iconSize.width) / 2
                let iconY = (markerSize - iconSize.height) / 2

                iconImage.withTintColor(.white, renderingMode: .alwaysOriginal).draw(at: CGPoint(x: iconCenterX, y: iconY))
            }

            // Draw callsign label
            let labelY = markerSize + 2
            let labelWidth = totalWidth - 4
            let labelRect = CGRect(x: 2, y: labelY, width: labelWidth, height: labelHeight)

            // Label background
            marker.affiliation.color.uiColor.withAlphaComponent(0.9).setFill()
            let labelPath = UIBezierPath(roundedRect: labelRect, cornerRadius: 4)
            labelPath.fill()

            // Label text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]

            let text = marker.callsign as NSString
            text.draw(in: labelRect, withAttributes: attributes)
        }

        self.image = image
    }
}

// MARK: - Color Extension

extension Color {
    var uiColor: UIColor {
        if #available(iOS 14.0, *) {
            return UIColor(self)
        } else {
            let components = self.cgColor?.components ?? [0, 0, 0, 1]
            return UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3])
        }
    }
}
