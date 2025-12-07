//
//  AircraftAnnotation.swift
//  OmniTAKMobile
//
//  Custom map annotation for aircraft display
//

import MapKit
import SwiftUI

// MARK: - Aircraft Annotation

class AircraftAnnotation: NSObject, MKAnnotation {
    let aircraft: Aircraft

    var coordinate: CLLocationCoordinate2D {
        aircraft.coordinate
    }

    var title: String? {
        aircraft.callsign.isEmpty ? aircraft.id.uppercased() : aircraft.callsign
    }

    var subtitle: String? {
        "\(aircraft.formattedAltitude) • \(aircraft.formattedSpeed)"
    }

    var category: AircraftCategory {
        AircraftTypeDetector.detectCategory(
            callsign: aircraft.callsign,
            velocity: aircraft.velocity,
            altitude: aircraft.altitude,
            verticalRate: aircraft.verticalRate,
            onGround: aircraft.onGround,
            originCountry: aircraft.originCountry
        )
    }

    var sizeClass: AircraftSizeClass {
        AircraftTypeDetector.detectSizeClass(
            category: category,
            callsign: aircraft.callsign,
            velocity: aircraft.velocity,
            altitude: aircraft.altitude
        )
    }

    init(aircraft: Aircraft) {
        self.aircraft = aircraft
        super.init()
    }
}

// MARK: - Aircraft Annotation View

class AircraftAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "AircraftAnnotationView"

    private var imageView: UIImageView?
    private var hostingController: UIHostingController<AircraftMapIcon>?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        canShowCallout = true
        collisionMode = .circle
        displayPriority = .defaultLow
    }

    override var annotation: MKAnnotation? {
        didSet {
            guard let aircraftAnnotation = annotation as? AircraftAnnotation else { return }
            updateView(for: aircraftAnnotation)
        }
    }

    private func updateView(for aircraftAnnotation: AircraftAnnotation) {
        let aircraft = aircraftAnnotation.aircraft
        let category = aircraftAnnotation.category
        let sizeClass = aircraftAnnotation.sizeClass

        // Calculate icon size based on category and size class
        let baseSize: CGFloat = category.iconSize * sizeClass.scaleFactor
        let viewSize = baseSize + 8 // Add padding for background

        // Remove existing hosting controller
        hostingController?.view.removeFromSuperview()

        // Create SwiftUI icon view
        let iconView = AircraftMapIcon(aircraft: aircraft)
        let hostingVC = UIHostingController(rootView: iconView)
        hostingVC.view.backgroundColor = UIColor.clear
        hostingVC.view.frame = CGRect(x: -viewSize/2, y: -viewSize/2, width: viewSize, height: viewSize)

        addSubview(hostingVC.view)
        hostingController = hostingVC

        // Set frame and center offset
        frame = CGRect(x: 0, y: 0, width: viewSize, height: viewSize)
        centerOffset = CGPoint(x: 0, y: 0)

        // Set display priority based on altitude (higher planes more visible)
        let altFeet = aircraft.altitude * 3.28084
        if altFeet > 35000 {
            displayPriority = .defaultHigh
        } else if altFeet > 20000 {
            displayPriority = .required
        } else {
            displayPriority = .defaultLow
        }
    }
}
