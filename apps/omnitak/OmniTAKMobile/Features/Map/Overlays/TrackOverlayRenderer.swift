//
//  TrackOverlayRenderer.swift
//  OmniTAKMobile
//
//  MKPolyline overlay renderer for displaying recorded tracks on the map
//

import MapKit
import SwiftUI

// MARK: - Track Polyline

/// Custom MKPolyline subclass to store track metadata
class TrackPolyline: MKPolyline {
    var trackId: UUID?
    var trackColor: UIColor = .red
    var trackName: String = ""
}

// MARK: - Track Overlay

/// Wrapper class for track overlay management
class TrackOverlay: NSObject {
    let track: Track
    let polyline: TrackPolyline
    var isVisible: Bool = true

    init(track: Track) {
        self.track = track

        // Create polyline from track points
        var coordinates = track.points.map { $0.coordinate }
        let polyline = TrackPolyline(coordinates: &coordinates, count: coordinates.count)
        polyline.trackId = track.id
        polyline.trackColor = track.uiColor
        polyline.trackName = track.name

        self.polyline = polyline

        super.init()
    }

    /// Update polyline with new track data (for live recording)
    func updatePolyline(with newTrack: Track) -> TrackPolyline {
        var coordinates = newTrack.points.map { $0.coordinate }
        let newPolyline = TrackPolyline(coordinates: &coordinates, count: coordinates.count)
        newPolyline.trackId = newTrack.id
        newPolyline.trackColor = newTrack.uiColor
        newPolyline.trackName = newTrack.name
        return newPolyline
    }
}

// MARK: - Track Polyline Renderer

/// Custom renderer for track polylines with enhanced visualization
class TrackPolylineRenderer: MKPolylineRenderer {
    var trackColor: UIColor = .red
    var trackWidth: CGFloat = 4.0
    var showDirectionIndicators: Bool = true
    var showBreadcrumbDots: Bool = false

    override init(polyline: MKPolyline) {
        super.init(polyline: polyline)

        // Apply track color if available
        if let trackPolyline = polyline as? TrackPolyline {
            trackColor = trackPolyline.trackColor
        }

        setupRenderer()
    }

    private func setupRenderer() {
        strokeColor = trackColor.withAlphaComponent(0.8)
        lineWidth = trackWidth
        lineCap = .round
        lineJoin = .round
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // Draw the base polyline
        super.draw(mapRect, zoomScale: zoomScale, in: context)

        // Draw additional features
        if showDirectionIndicators {
            drawDirectionIndicators(in: context, zoomScale: zoomScale)
        }

        if showBreadcrumbDots {
            drawBreadcrumbDots(in: context, zoomScale: zoomScale)
        }

        // Draw start and end markers
        drawStartEndMarkers(in: context, zoomScale: zoomScale)
    }

    private func drawDirectionIndicators(in context: CGContext, zoomScale: MKZoomScale) {
        guard polyline.pointCount >= 2 else { return }

        let points = polyline.points()
        let pointCount = polyline.pointCount

        // Draw arrows every N points based on zoom
        let arrowInterval = max(5, Int(15.0 / zoomScale))
        let arrowSize = CGFloat(6.0) / zoomScale

        context.saveGState()
        context.setFillColor(trackColor.cgColor)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(0.5 / zoomScale)

        for i in stride(from: 0, to: pointCount - 1, by: arrowInterval) {
            let p1 = points[i]
            let p2 = points[min(i + 1, pointCount - 1)]

            let point1 = point(for: p1)
            let point2 = point(for: p2)

            // Calculate angle
            let dx = point2.x - point1.x
            let dy = point2.y - point1.y
            let angle = atan2(dy, dx)

            // Draw arrow at midpoint
            let midX = (point1.x + point2.x) / 2
            let midY = (point1.y + point2.y) / 2

            context.saveGState()
            context.translateBy(x: midX, y: midY)
            context.rotate(by: angle)

            // Draw arrow triangle
            let arrowPath = UIBezierPath()
            arrowPath.move(to: CGPoint(x: arrowSize, y: 0))
            arrowPath.addLine(to: CGPoint(x: -arrowSize / 2, y: arrowSize / 2))
            arrowPath.addLine(to: CGPoint(x: -arrowSize / 2, y: -arrowSize / 2))
            arrowPath.close()

            context.addPath(arrowPath.cgPath)
            context.fillPath()

            context.addPath(arrowPath.cgPath)
            context.strokePath()

            context.restoreGState()
        }

        context.restoreGState()
    }

    private func drawBreadcrumbDots(in context: CGContext, zoomScale: MKZoomScale) {
        let points = polyline.points()
        let pointCount = polyline.pointCount
        let dotSize = CGFloat(3.0) / zoomScale

        // Draw dots every N points based on zoom
        let dotInterval = max(3, Int(10.0 / zoomScale))

        context.saveGState()
        context.setFillColor(UIColor.white.cgColor)

        for i in stride(from: 0, to: pointCount, by: dotInterval) {
            let mapPoint = points[i]
            let screenPoint = point(for: mapPoint)

            let rect = CGRect(
                x: screenPoint.x - dotSize,
                y: screenPoint.y - dotSize,
                width: dotSize * 2,
                height: dotSize * 2
            )
            context.fillEllipse(in: rect)
        }

        context.restoreGState()
    }

    private func drawStartEndMarkers(in context: CGContext, zoomScale: MKZoomScale) {
        guard polyline.pointCount >= 2 else { return }

        let points = polyline.points()
        let markerSize = CGFloat(8.0) / zoomScale

        // Start marker (green circle with white border)
        let startPoint = point(for: points[0])
        drawCircleMarker(
            at: startPoint,
            size: markerSize,
            fillColor: UIColor.systemGreen,
            strokeColor: UIColor.white,
            in: context,
            zoomScale: zoomScale
        )

        // End marker (track color with white border, larger)
        let endPoint = point(for: points[polyline.pointCount - 1])
        drawCircleMarker(
            at: endPoint,
            size: markerSize * 1.3,
            fillColor: trackColor,
            strokeColor: UIColor.white,
            in: context,
            zoomScale: zoomScale
        )
    }

    private func drawCircleMarker(
        at point: CGPoint,
        size: CGFloat,
        fillColor: UIColor,
        strokeColor: UIColor,
        in context: CGContext,
        zoomScale: MKZoomScale
    ) {
        context.saveGState()

        let rect = CGRect(
            x: point.x - size,
            y: point.y - size,
            width: size * 2,
            height: size * 2
        )

        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: rect)

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(2.0 / zoomScale)
        context.strokeEllipse(in: rect)

        context.restoreGState()
    }
}

// MARK: - Track Overlay Manager

/// Manager for handling multiple track overlays on the map
class TrackOverlayManager: ObservableObject {
    @Published var trackOverlays: [UUID: TrackOverlay] = [:]
    @Published var activeRecordingOverlay: TrackOverlay?

    /// Configuration
    var showDirectionIndicators: Bool = true
    var showBreadcrumbDots: Bool = false
    var defaultTrackWidth: CGFloat = 4.0

    // MARK: - Add/Remove Tracks

    /// Add a track overlay
    func addTrackOverlay(for track: Track) -> TrackOverlay {
        let overlay = TrackOverlay(track: track)
        trackOverlays[track.id] = overlay
        return overlay
    }

    /// Remove a track overlay
    func removeTrackOverlay(for trackId: UUID) {
        trackOverlays.removeValue(forKey: trackId)
    }

    /// Clear all track overlays
    func clearAllOverlays() {
        trackOverlays.removeAll()
        activeRecordingOverlay = nil
    }

    /// Get all polylines for adding to map
    func getAllPolylines() -> [MKPolyline] {
        var polylines: [MKPolyline] = []

        for overlay in trackOverlays.values where overlay.isVisible {
            polylines.append(overlay.polyline)
        }

        if let activeOverlay = activeRecordingOverlay {
            polylines.append(activeOverlay.polyline)
        }

        return polylines
    }

    // MARK: - Active Recording Management

    /// Update the active recording overlay
    func updateActiveRecording(with track: Track) {
        if activeRecordingOverlay == nil {
            activeRecordingOverlay = TrackOverlay(track: track)
        } else {
            activeRecordingOverlay = TrackOverlay(track: track)
        }
    }

    /// Clear the active recording overlay
    func clearActiveRecording() {
        activeRecordingOverlay = nil
    }

    // MARK: - Visibility Control

    /// Toggle visibility of a track
    func toggleTrackVisibility(trackId: UUID) {
        trackOverlays[trackId]?.isVisible.toggle()
    }

    /// Show all tracks
    func showAllTracks() {
        for key in trackOverlays.keys {
            trackOverlays[key]?.isVisible = true
        }
    }

    /// Hide all tracks
    func hideAllTracks() {
        for key in trackOverlays.keys {
            trackOverlays[key]?.isVisible = false
        }
    }

    // MARK: - Renderer Configuration

    /// Create a renderer for a polyline
    func createRenderer(for overlay: MKOverlay) -> MKOverlayRenderer? {
        guard let polyline = overlay as? TrackPolyline else {
            if let polyline = overlay as? MKPolyline {
                let renderer = TrackPolylineRenderer(polyline: polyline)
                renderer.showDirectionIndicators = showDirectionIndicators
                renderer.showBreadcrumbDots = showBreadcrumbDots
                renderer.trackWidth = defaultTrackWidth
                return renderer
            }
            return nil
        }

        let renderer = TrackPolylineRenderer(polyline: polyline)
        renderer.trackColor = polyline.trackColor
        renderer.showDirectionIndicators = showDirectionIndicators
        renderer.showBreadcrumbDots = showBreadcrumbDots
        renderer.trackWidth = defaultTrackWidth

        return renderer
    }
}

// MARK: - SwiftUI View Helpers

/// SwiftUI color preview for track color selection
struct TrackColorPreview: View {
    let color: String
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(Color(hex: color))
            .frame(width: 30, height: 30)
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
            )
            .shadow(color: Color(hex: color).opacity(0.5), radius: isSelected ? 4 : 0)
    }
}

/// Track color picker view
struct TrackColorPicker: View {
    @Binding var selectedColor: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TrackColorPreset.allCases, id: \.rawValue) { preset in
                    TrackColorPreview(
                        color: preset.rawValue,
                        isSelected: selectedColor == preset.rawValue
                    )
                    .onTapGesture {
                        selectedColor = preset.rawValue
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
