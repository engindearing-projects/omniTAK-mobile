import SwiftUI
import MapKit

// MARK: - Offline Maps Management View

struct OfflineMapsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var offlineMapManager = OfflineMapManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared

    @State private var showRegionSelection = false
    @State private var regionToDelete: OfflineMapRegion?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationView {
            List {
                // Status Section
                Section {
                    StatusRow(
                        icon: "network",
                        title: "Network",
                        value: networkMonitor.statusDescription,
                        color: networkMonitor.isConnected ? .green : .red
                    )

                    StatusRow(
                        icon: "internaldrive",
                        title: "Storage Used",
                        value: formattedTotalStorage,
                        color: .blue
                    )

                    StatusRow(
                        icon: "map",
                        title: "Regions",
                        value: "\(offlineMapManager.regions.count)",
                        color: .purple
                    )
                } header: {
                    Text("STATUS")
                }

                // Active Download Section
                if offlineMapManager.isDownloading, let download = offlineMapManager.currentDownload {
                    Section {
                        DownloadProgressRow(
                            region: download,
                            progress: offlineMapManager.downloadProgress,
                            onPause: {
                                offlineMapManager.pauseDownload()
                            },
                            onResume: {
                                offlineMapManager.resumeDownload()
                            },
                            onCancel: {
                                offlineMapManager.cancelDownload()
                            }
                        )
                    } header: {
                        Text("DOWNLOADING")
                    }
                }

                // Error Section
                if let error = offlineMapManager.downloadError {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                    } header: {
                        Text("ERROR")
                    }
                }

                // Downloaded Regions Section
                if !offlineMapManager.regions.isEmpty {
                    Section {
                        ForEach(offlineMapManager.regions) { region in
                            RegionRow(
                                region: region,
                                onDelete: {
                                    regionToDelete = region
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                    } header: {
                        Text("DOWNLOADED REGIONS")
                    }
                } else if !offlineMapManager.isDownloading {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No Offline Maps")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Tap the + button to download a region")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
            }
            .navigationTitle("Offline Maps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showRegionSelection = true }) {
                        Image(systemName: "plus")
                    }
                    .disabled(!networkMonitor.isConnected || offlineMapManager.isDownloading)
                }
            }
            .sheet(isPresented: $showRegionSelection) {
                RegionSelectionView()
            }
            .confirmationDialog(
                "Delete Region",
                isPresented: $showDeleteConfirmation,
                presenting: regionToDelete
            ) { region in
                Button("Delete", role: .destructive) {
                    offlineMapManager.deleteRegion(region)
                }
                Button("Cancel", role: .cancel) { }
            } message: { region in
                Text("Delete '\(region.name)'? This will remove all downloaded tiles (\(region.formattedSize)).")
            }
        }
    }

    private var formattedTotalStorage: String {
        let total = offlineMapManager.getTotalStorageUsed()
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
}

// MARK: - Status Row

struct StatusRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 15))

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Download Progress Row

struct DownloadProgressRow: View {
    let region: OfflineMapRegion
    let progress: Double
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void

    @StateObject private var manager = OfflineMapManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(region.name)
                        .font(.system(size: 16, weight: .semibold))

                    Text("\(Int(progress * 100))% Complete")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Control Buttons
                HStack(spacing: 12) {
                    if manager.isDownloading {
                        Button(action: onPause) {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.orange)
                        }
                    } else {
                        Button(action: onResume) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.green)
                        }
                    }

                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.red)
                    }
                }
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)

            // Stats
            HStack {
                Label("\(region.downloadedTiles) / \(region.totalTiles) tiles", systemImage: "square.grid.3x3")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Text(region.formattedSize)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Region Row

struct RegionRow: View {
    let region: OfflineMapRegion
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Map Preview Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: region.isComplete ? "map.fill" : "arrow.down.circle")
                    .font(.system(size: 24))
                    .foregroundColor(region.isComplete ? .blue : .orange)
            }

            // Region Info
            VStack(alignment: .leading, spacing: 4) {
                Text(region.name)
                    .font(.system(size: 16, weight: .semibold))

                HStack(spacing: 8) {
                    Text("Z\(region.minZoom)-\(region.maxZoom)")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)

                    Text(region.formattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    if !region.isComplete {
                        Text("\(Int(region.progress * 100))%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }

                Text(region.dateCreated.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Region Detail View

struct RegionDetailView: View {
    let region: OfflineMapRegion
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("INFORMATION") {
                    DetailRow(icon: "map", label: "Name", value: region.name)
                    DetailRow(icon: "clock", label: "Created", value: region.dateCreated.formatted(date: .long, time: .shortened))
                    DetailRow(icon: "externaldrive", label: "Size", value: region.formattedSize)
                    DetailRow(icon: "square.grid.3x3", label: "Tiles", value: "\(region.downloadedTiles) / \(region.totalTiles)")
                    DetailRow(icon: "chart.bar", label: "Progress", value: "\(Int(region.progress * 100))%")
                }

                Section("COVERAGE") {
                    DetailRow(icon: "location", label: "Center", value: String(format: "%.4f, %.4f", region.centerLatitude, region.centerLongitude))
                    DetailRow(icon: "magnifyingglass", label: "Zoom Levels", value: "\(region.minZoom) - \(region.maxZoom)")
                }

                Section {
                    MapPreview(region: region.region)
                        .frame(height: 200)
                        .cornerRadius(8)
                }
            }
            .navigationTitle("Region Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MapPreview: UIViewRepresentable {
    let region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isUserInteractionEnabled = false
        mapView.mapType = .satellite
        mapView.setRegion(region, animated: false)

        // Add overlay
        let overlay = MKCircle(center: region.center, radius: 1000)
        mapView.addOverlay(overlay)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: false)
    }
}

// MARK: - Preview

#Preview {
    OfflineMapsView()
}
