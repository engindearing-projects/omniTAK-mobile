import SwiftUI
import MapKit

// MARK: - Region Selection View

struct RegionSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var offlineMapManager = OfflineMapManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared

    @State private var regionName: String = ""
    @State private var selectedRegion: MKCoordinateRegion
    @State private var minZoom: Int = 10
    @State private var maxZoom: Int = 15
    @State private var isDrawing: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    private let availableZoomLevels = Array(0...19)

    init(initialRegion: MKCoordinateRegion? = nil) {
        _selectedRegion = State(initialValue: initialRegion ?? MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        ))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Map View
                RegionDrawingMapView(region: $selectedRegion)
                    .frame(maxHeight: .infinity)
                    .overlay(
                        RegionOverlay(region: selectedRegion)
                    )

                // Configuration Panel
                VStack(spacing: 16) {
                    // Region Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Region Name")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("e.g., Downtown DC", text: $regionName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    // Zoom Level Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Zoom Levels")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Min: \(minZoom)")
                                    .font(.system(size: 12))
                                Stepper("", value: $minZoom, in: 0...maxZoom)
                                    .labelsHidden()
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Max: \(maxZoom)")
                                    .font(.system(size: 12))
                                Stepper("", value: $maxZoom, in: minZoom...19)
                                    .labelsHidden()
                            }
                        }

                        // Zoom level info
                        Text(zoomLevelDescription)
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }

                    // Size Estimation
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Estimated Size")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(estimatedSize)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(estimatedTiles > 50000 ? .red : .primary)
                        }

                        HStack {
                            Text("Tiles")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(estimatedTiles)")
                                .font(.system(size: 15, weight: .bold))
                        }

                        HStack {
                            Text("Est. Time")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(estimatedTime)
                                .font(.system(size: 15, weight: .bold))
                        }

                        if estimatedTiles > 10000 {
                            Text("Warning: Large download may take significant time and storage")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)

                    // Network Status Warning
                    if networkMonitor.isExpensive {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Using cellular data - download may incur charges")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }

                    // Download Button
                    Button(action: startDownload) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Region")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canDownload ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!canDownload)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
            }
            .navigationTitle("Select Region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Region Selection", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Computed Properties

    private var estimatedTiles: Int {
        TileCalculator.calculateTileCount(
            region: selectedRegion,
            minZoom: minZoom,
            maxZoom: maxZoom
        )
    }

    private var estimatedSize: String {
        let bytes = Int64(estimatedTiles) * 25_000 // Average 25KB per tile
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var estimatedTime: String {
        let seconds = Double(estimatedTiles) * 0.25 // 250ms per tile with rate limiting
        let minutes = Int(seconds / 60)
        let hours = minutes / 60

        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(Int(seconds))s"
        }
    }

    private var zoomLevelDescription: String {
        switch maxZoom {
        case 0...5:
            return "Very low detail - Country/continent level"
        case 6...9:
            return "Low detail - State/region level"
        case 10...12:
            return "Medium detail - City level"
        case 13...15:
            return "High detail - Neighborhood level"
        case 16...17:
            return "Very high detail - Street level"
        default:
            return "Extreme detail - Building level (very large)"
        }
    }

    private var canDownload: Bool {
        !regionName.isEmpty &&
        estimatedTiles > 0 &&
        estimatedTiles <= 100000 && // Reasonable limit
        networkMonitor.isConnected
    }

    // MARK: - Actions

    private func startDownload() {
        // Validate
        guard !regionName.isEmpty else {
            alertMessage = "Please enter a region name"
            showAlert = true
            return
        }

        guard networkMonitor.isConnected else {
            alertMessage = "No internet connection available"
            showAlert = true
            return
        }

        // Create region
        let region = OfflineMapRegion(
            name: regionName,
            center: selectedRegion.center,
            span: selectedRegion.span,
            minZoom: minZoom,
            maxZoom: maxZoom
        )

        // Add and start download
        offlineMapManager.addRegion(region)
        offlineMapManager.startDownload(region: region)

        // Dismiss
        dismiss()
    }
}

// MARK: - Region Drawing Map View

struct RegionDrawingMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .satellite
        mapView.setRegion(region, animated: false)

        // Add pinch gesture recognizer for region selection
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        mapView.addGestureRecognizer(pinchGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if changed externally
        if !context.coordinator.isUserInteracting {
            mapView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RegionDrawingMapView
        var isUserInteracting = false

        init(_ parent: RegionDrawingMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            isUserInteracting = true
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isUserInteracting = false
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            // Handle pinch for region selection
            if gesture.state == .ended {
                isUserInteracting = false
            }
        }
    }
}

// MARK: - Region Overlay

struct RegionOverlay: View {
    let region: MKCoordinateRegion

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .strokeBorder(Color.blue, lineWidth: 3)
                .background(Color.blue.opacity(0.1))
                .frame(width: geometry.size.width * 0.7, height: geometry.size.height * 0.5)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview {
    RegionSelectionView()
}
