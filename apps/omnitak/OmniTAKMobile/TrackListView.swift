//
//  TrackListView.swift
//  OmniTAKMobile
//
//  SwiftUI view for listing and managing saved tracks
//

import SwiftUI
import MapKit

// MARK: - Track List View

struct TrackListView: View {
    @ObservedObject var recordingService: TrackRecordingService
    @State private var selectedTrack: Track?
    @State private var showingTrackDetail = false
    @State private var showingExportOptions = false
    @State private var trackToExport: Track?
    @State private var searchText = ""

    var filteredTracks: [Track] {
        if searchText.isEmpty {
            return recordingService.savedTracks
        } else {
            return recordingService.savedTracks.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E").ignoresSafeArea()

                if recordingService.savedTracks.isEmpty {
                    emptyStateView
                } else {
                    trackListContent
                }
            }
            .navigationTitle("Saved Tracks")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search tracks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        recordingService.loadSavedTracks()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .sheet(item: $selectedTrack) { track in
            TrackDetailView(track: track, recordingService: recordingService)
        }
        .confirmationDialog("Export Format", isPresented: $showingExportOptions) {
            if let track = trackToExport {
                Button("Export as GPX") {
                    shareGPX(track)
                }
                Button("Export as KML") {
                    shareKML(track)
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.north.line.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#FFFC00").opacity(0.5))

            Text("No Tracks Recorded")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("Start recording your first track to see it here.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#888888"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Track List Content

    private var trackListContent: some View {
        List {
            ForEach(filteredTracks) { track in
                TrackRowView(track: track)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTrack = track
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            recordingService.deleteTrack(track)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            trackToExport = track
                            showingExportOptions = true
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
                    .listRowBackground(Color(hex: "#2A2A2A"))
            }
        }
        .listStyle(.plain)
        .background(Color(hex: "#1E1E1E"))
    }

    // MARK: - Export Functions

    private func shareGPX(_ track: Track) {
        guard let url = recordingService.getGPXFileURL(for: track) else { return }
        shareFile(url: url)
    }

    private func shareKML(_ track: Track) {
        guard let url = recordingService.getKMLFileURL(for: track) else { return }
        shareFile(url: url)
    }

    private func shareFile(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Track Row View

struct TrackRowView: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Rectangle()
                .fill(Color(hex: track.color))
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 6) {
                // Track name
                Text(track.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                // Date
                Text(track.formattedDate)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#888888"))

                // Statistics row
                HStack(spacing: 16) {
                    StatBadge(icon: "ruler", value: track.formattedDistance)
                    StatBadge(icon: "clock", value: track.formattedDuration)
                    StatBadge(icon: "location.circle", value: "\(track.points.count) pts")
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#666666"))
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#FFFC00"))

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#CCCCCC"))
        }
    }
}

// MARK: - Track Detail View

struct TrackDetailView: View {
    let track: Track
    @ObservedObject var recordingService: TrackRecordingService
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedNotes: String = ""
    @State private var showingExportOptions = false
    @State private var showingMap = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Map preview
                        mapPreviewSection

                        // Statistics
                        statisticsSection

                        // Details
                        detailsSection

                        // Actions
                        actionsSection
                    }
                    .padding()
                }
            }
            .navigationTitle(track.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            saveEdits()
                        } else {
                            editedName = track.name
                            editedNotes = track.notes ?? ""
                        }
                        isEditing.toggle()
                    }
                }
            }
            .confirmationDialog("Export Format", isPresented: $showingExportOptions) {
                Button("Export as GPX") {
                    shareGPX()
                }
                Button("Export as KML") {
                    shareKML()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    // MARK: - Map Preview Section

    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Track Preview")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#CCCCCC"))

            if let region = track.boundingRegion {
                TrackMapPreview(track: track, region: region)
                    .frame(height: 200)
                    .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color(hex: "#2A2A2A"))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        Text("No track data available")
                            .foregroundColor(Color(hex: "#888888"))
                    )
            }
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#CCCCCC"))

            VStack(spacing: 0) {
                DetailRow(
                    icon: "ruler",
                    label: "Total Distance",
                    value: track.formattedDistance
                )

                Divider().background(Color(hex: "#3A3A3A"))

                DetailRow(
                    icon: "clock",
                    label: "Duration",
                    value: track.formattedDuration
                )

                Divider().background(Color(hex: "#3A3A3A"))

                DetailRow(
                    icon: "gauge",
                    label: "Average Speed",
                    value: track.formattedAverageSpeed
                )

                Divider().background(Color(hex: "#3A3A3A"))

                DetailRow(
                    icon: "speedometer",
                    label: "Max Speed",
                    value: track.formattedMaxSpeed
                )

                Divider().background(Color(hex: "#3A3A3A"))

                DetailRow(
                    icon: "arrow.up.right",
                    label: "Elevation Gain",
                    value: track.formattedElevationGain
                )

                Divider().background(Color(hex: "#3A3A3A"))

                DetailRow(
                    icon: "arrow.down.right",
                    label: "Elevation Loss",
                    value: track.formattedElevationLoss
                )

                Divider().background(Color(hex: "#3A3A3A"))

                DetailRow(
                    icon: "location.circle",
                    label: "Track Points",
                    value: "\(track.points.count)"
                )
            }
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(12)
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#CCCCCC"))

            VStack(spacing: 0) {
                if isEditing {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Track Name")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#888888"))

                        TextField("Track Name", text: $editedName)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(16)
                } else {
                    DetailRow(
                        icon: "tag",
                        label: "Name",
                        value: track.name
                    )
                }

                Divider().background(Color(hex: "#3A3A3A"))

                DetailRow(
                    icon: "calendar",
                    label: "Date",
                    value: track.formattedDate
                )

                Divider().background(Color(hex: "#3A3A3A"))

                if isEditing {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#888888"))

                        TextEditor(text: $editedNotes)
                            .frame(height: 100)
                            .cornerRadius(8)
                    }
                    .padding(16)
                } else if let notes = track.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "note.text")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#FFFC00"))
                                .frame(width: 24)

                            Text("Notes")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#CCCCCC"))

                            Spacer()
                        }

                        Text(notes)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.leading, 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(12)
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingExportOptions = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Track")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "#FFFC00"))
                .cornerRadius(8)
            }

            Button(action: {
                recordingService.deleteTrack(track)
                dismiss()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Track")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.15))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Helper Methods

    private func saveEdits() {
        if !editedName.isEmpty && editedName != track.name {
            recordingService.renameTrack(track, newName: editedName)
        }
        recordingService.updateTrackNotes(track, notes: editedNotes.isEmpty ? nil : editedNotes)
    }

    private func shareGPX() {
        guard let url = recordingService.getGPXFileURL(for: track) else { return }
        shareFile(url: url)
    }

    private func shareKML() {
        guard let url = recordingService.getKMLFileURL(for: track) else { return }
        shareFile(url: url)
    }

    private func shareFile(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Track Map Preview

struct TrackMapPreview: UIViewRepresentable {
    let track: Track
    let region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.mapType = .standard

        // Add polyline
        var coordinates = track.points.map { $0.coordinate }
        let polyline = TrackPolyline(coordinates: &coordinates, count: coordinates.count)
        polyline.trackColor = track.uiColor
        mapView.addOverlay(polyline)

        // Set region
        mapView.setRegion(region, animated: false)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? TrackPolyline {
                let renderer = TrackPolylineRenderer(polyline: polyline)
                renderer.trackColor = polyline.trackColor
                renderer.showDirectionIndicators = false
                renderer.showBreadcrumbDots = false
                return renderer
            }

            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .red
                renderer.lineWidth = 3
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Preview

struct TrackListView_Previews: PreviewProvider {
    static var previews: some View {
        TrackListView(recordingService: TrackRecordingService.shared)
    }
}
