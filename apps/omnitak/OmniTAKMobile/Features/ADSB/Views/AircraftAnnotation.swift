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
    private(set) var aircraft: Aircraft

    // Dynamic coordinate for smooth updates
    @objc dynamic var coordinate: CLLocationCoordinate2D

    // Track if annotation needs visual update
    var needsVisualUpdate: Bool = false

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
        self.coordinate = aircraft.coordinate
        super.init()
    }

    /// Update aircraft data in-place without removing annotation
    func update(with newAircraft: Aircraft) {
        let positionChanged = coordinate.latitude != newAircraft.coordinate.latitude ||
                              coordinate.longitude != newAircraft.coordinate.longitude
        let headingChanged = abs(aircraft.heading - newAircraft.heading) > 1.0
        let altitudeChanged = abs(aircraft.altitude - newAircraft.altitude) > 10

        aircraft = newAircraft

        // Update coordinate (triggers MKMapView position update via KVO)
        if positionChanged {
            coordinate = newAircraft.coordinate
        }

        // Flag for visual update if heading or altitude changed significantly
        needsVisualUpdate = headingChanged || altitudeChanged
    }
}

// MARK: - Aircraft Annotation View

class AircraftAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "AircraftAnnotationView"

    private var hostingController: UIHostingController<AircraftMapIcon>?
    private var currentAircraftId: String?

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

    /// Call this to refresh the view when aircraft data updates in-place
    func refreshIfNeeded() {
        guard let aircraftAnnotation = annotation as? AircraftAnnotation,
              aircraftAnnotation.needsVisualUpdate else { return }

        // Update the hosting controller's root view instead of recreating
        if let hostingController = hostingController {
            hostingController.rootView = AircraftMapIcon(aircraft: aircraftAnnotation.aircraft)
        }

        updateDisplayPriority(for: aircraftAnnotation.aircraft)
        aircraftAnnotation.needsVisualUpdate = false
    }

    private func updateView(for aircraftAnnotation: AircraftAnnotation) {
        let aircraft = aircraftAnnotation.aircraft
        let category = aircraftAnnotation.category
        let sizeClass = aircraftAnnotation.sizeClass

        // Calculate icon size based on category and size class
        let baseSize: CGFloat = category.iconSize * sizeClass.scaleFactor
        let viewSize = baseSize + 8 // Add padding for background

        // Only recreate hosting controller if it doesn't exist or aircraft ID changed
        if hostingController == nil || currentAircraftId != aircraft.id {
            hostingController?.view.removeFromSuperview()

            let iconView = AircraftMapIcon(aircraft: aircraft)
            let hostingVC = UIHostingController(rootView: iconView)
            hostingVC.view.backgroundColor = UIColor.clear
            hostingVC.view.frame = CGRect(x: -viewSize/2, y: -viewSize/2, width: viewSize, height: viewSize)

            addSubview(hostingVC.view)
            hostingController = hostingVC
            currentAircraftId = aircraft.id
        } else {
            // Just update the root view without recreating the controller
            hostingController?.rootView = AircraftMapIcon(aircraft: aircraft)
            hostingController?.view.frame = CGRect(x: -viewSize/2, y: -viewSize/2, width: viewSize, height: viewSize)
        }

        // Set frame and center offset
        frame = CGRect(x: 0, y: 0, width: viewSize, height: viewSize)
        centerOffset = CGPoint(x: 0, y: 0)

        updateDisplayPriority(for: aircraft)
        aircraftAnnotation.needsVisualUpdate = false
    }

    private func updateDisplayPriority(for aircraft: Aircraft) {
        let altFeet = aircraft.altitude * 3.28084
        if altFeet > 35000 {
            displayPriority = .defaultHigh
        } else if altFeet > 20000 {
            displayPriority = .required
        } else {
            displayPriority = .defaultLow
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Don't remove the hosting controller - just reset the tracking ID
        currentAircraftId = nil
    }
}
