//
//  VideoMapOverlay.swift
//  OmniTAKMobile
//
//  Map overlay components for video feed location correlation
//

import SwiftUI
import MapKit

// MARK: - Video Feed Map Annotation

class VideoFeedAnnotation: NSObject, MKAnnotation {
    let feed: VideoFeed

    var coordinate: CLLocationCoordinate2D {
        feed.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }

    var title: String? {
        feed.name
    }

    var subtitle: String? {
        feed.streamProtocol.displayName
    }

    init(feed: VideoFeed) {
        self.feed = feed
        super.init()
    }
}

// MARK: - Video Feed Annotation View

class VideoFeedAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "VideoFeedAnnotation"

    private let accentColor = UIColor(red: 1, green: 252/255, blue: 0, alpha: 1)
    private let iconSize: CGFloat = 32

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
        calloutOffset = CGPoint(x: 0, y: -5)

        let button = UIButton(type: .detailDisclosure)
        button.tintColor = accentColor
        rightCalloutAccessoryView = button

        // Create custom marker image
        let markerView = createMarkerView()
        image = markerView

        frame.size = CGSize(width: iconSize + 8, height: iconSize + 8)
        centerOffset = CGPoint(x: 0, y: -iconSize/2)
    }

    private func createMarkerView() -> UIImage? {
        let size = CGSize(width: iconSize + 8, height: iconSize + 8)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            // Draw shadow
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.3).cgColor)

            // Draw circle background
            let circlePath = UIBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4))
            UIColor.black.setFill()
            circlePath.fill()

            // Draw border
            accentColor.setStroke()
            circlePath.lineWidth = 2
            circlePath.stroke()

            // Draw video icon
            let config = UIImage.SymbolConfiguration(pointSize: iconSize * 0.5, weight: .semibold)
            if let videoIcon = UIImage(systemName: "video.fill", withConfiguration: config) {
                let iconRect = CGRect(
                    x: (size.width - videoIcon.size.width) / 2,
                    y: (size.height - videoIcon.size.height) / 2,
                    width: videoIcon.size.width,
                    height: videoIcon.size.height
                )
                videoIcon.withTintColor(accentColor).draw(in: iconRect)
            }
        }
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()

        if let videoAnnotation = annotation as? VideoFeedAnnotation {
            // Update appearance based on protocol
            displayPriority = .required
            clusteringIdentifier = "VideoFeeds"

            // Add protocol indicator to callout
            let label = UILabel()
            label.text = videoAnnotation.feed.streamProtocol.displayName
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = .gray
            leftCalloutAccessoryView = label
        }
    }
}

// MARK: - Video Feeds Map Overlay Manager

class VideoFeedsMapOverlayManager: NSObject, ObservableObject {
    @Published var videoAnnotations: [VideoFeedAnnotation] = []
    private var streamService = VideoStreamService.shared

    weak var mapView: MKMapView?
    var onFeedSelected: ((VideoFeed) -> Void)?

    override init() {
        super.init()
    }

    func attachToMapView(_ mapView: MKMapView) {
        self.mapView = mapView
        mapView.register(
            VideoFeedAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: VideoFeedAnnotationView.reuseIdentifier
        )
        updateAnnotations()
    }

    func updateAnnotations() {
        guard let mapView = mapView else { return }

        // Remove existing video annotations
        let existingAnnotations = mapView.annotations.compactMap { $0 as? VideoFeedAnnotation }
        mapView.removeAnnotations(existingAnnotations)

        // Add annotations for feeds with locations
        let feedsWithLocation = streamService.feedsWithLocation
        videoAnnotations = feedsWithLocation.map { VideoFeedAnnotation(feed: $0) }

        mapView.addAnnotations(videoAnnotations)
    }

    func centerOnFeed(_ feed: VideoFeed) {
        guard let mapView = mapView, let coordinate = feed.coordinate else { return }

        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: true)
    }

    func showAllVideoFeeds() {
        guard let mapView = mapView, !videoAnnotations.isEmpty else { return }

        let coordinates = videoAnnotations.map { $0.coordinate }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )

        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: true)
    }
}

// MARK: - SwiftUI Video Feed Map Marker

struct VideoFeedMapMarker: View {
    let feed: VideoFeed
    var onTap: (() -> Void)?

    private let accentColor = Color(red: 1, green: 252/255, blue: 0)

    var body: some View {
        Button(action: {
            onTap?()
        }) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(accentColor, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                    Image(systemName: "video.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                // Callout arrow
                VideoTriangle()
                    .fill(Color.black)
                    .frame(width: 12, height: 8)
                    .rotationEffect(.degrees(180))
            }
        }
    }
}

// MARK: - Triangle Shape

struct VideoTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Video Feed Callout View

struct VideoFeedCalloutView: View {
    let feed: VideoFeed
    var onPlay: (() -> Void)?
    var onShowOnMap: (() -> Void)?

    private let accentColor = Color(red: 1, green: 252/255, blue: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: feed.streamProtocol.iconName)
                    .foregroundColor(accentColor)

                Text(feed.name)
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                if !feed.streamProtocol.isNativelySupported {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }

            Text(feed.url)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)

            if let coord = feed.coordinate {
                Text("Location: \(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 12) {
                Button(action: { onPlay?() }) {
                    Label("Play", systemImage: "play.fill")
                        .font(.caption)
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(accentColor)
                        .cornerRadius(6)
                }

                if feed.hasLocation {
                    Button(action: { onShowOnMap?() }) {
                        Label("Center", systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(white: 0.2))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Map Integration Helper

struct VideoFeedsMapIntegration {
    /// Create annotations for all feeds with locations
    static func createAnnotations(from service: VideoStreamService) -> [VideoFeedAnnotation] {
        service.feedsWithLocation.map { VideoFeedAnnotation(feed: $0) }
    }

    /// View factory for annotation views
    static func viewForAnnotation(_ annotation: MKAnnotation, mapView: MKMapView) -> MKAnnotationView? {
        guard annotation is VideoFeedAnnotation else { return nil }

        let identifier = VideoFeedAnnotationView.reuseIdentifier
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

        if annotationView == nil {
            annotationView = VideoFeedAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        } else {
            annotationView?.annotation = annotation
        }

        return annotationView
    }

    /// Handle annotation callout accessory tap
    static func handleCalloutTap(_ annotation: MKAnnotation) -> VideoFeed? {
        guard let videoAnnotation = annotation as? VideoFeedAnnotation else { return nil }
        return videoAnnotation.feed
    }
}

// MARK: - Video Feeds Layer Toggle

struct VideoFeedsLayerToggle: View {
    @Binding var showVideoFeeds: Bool
    @ObservedObject var streamService = VideoStreamService.shared

    private let accentColor = Color(red: 1, green: 252/255, blue: 0)

    var body: some View {
        Button(action: {
            showVideoFeeds.toggle()
        }) {
            HStack(spacing: 6) {
                Image(systemName: showVideoFeeds ? "video.fill" : "video")
                    .font(.system(size: 14))

                Text("Video Feeds")
                    .font(.caption)

                if showVideoFeeds && !streamService.feedsWithLocation.isEmpty {
                    Text("(\(streamService.feedsWithLocation.count))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .foregroundColor(showVideoFeeds ? accentColor : .gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.15))
            .cornerRadius(8)
        }
    }
}
