//
//  MeshNodeMapView.swift
//  OmniTAK Mobile
//
//  Displays Meshtastic mesh nodes on a map view
//

import SwiftUI
import MapKit

// MARK: - Mesh Node Map View

struct MeshNodeMapView: View {
    @ObservedObject var manager: MeshtasticManager
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var selectedNode: MeshNode?

    var body: some View {
        ZStack {
            // Map
            Map(coordinateRegion: $region, annotationItems: manager.nodesWithPositions) { node in
                MapAnnotation(coordinate: node.coordinate) {
                    MeshNodeAnnotation(
                        node: node,
                        isOwnNode: node.id == manager.myNodeNum,
                        isSelected: selectedNode?.id == node.id,
                        onTap: {
                            withAnimation {
                                selectedNode = (selectedNode?.id == node.id) ? nil : node
                            }
                        }
                    )
                }
            }
            .edgesIgnoringSafeArea(.all)

            // Info overlay
            VStack {
                // Top bar with node count
                HStack {
                    Label("\(manager.nodesWithPositions.count) nodes", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)

                    Spacer()

                    // Center on nodes button
                    Button {
                        centerOnNodes()
                    } label: {
                        Image(systemName: "location.viewfinder")
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                }
                .padding()

                Spacer()

                // Selected node detail card
                if let node = selectedNode {
                    MeshNodeDetailCard(node: node, isOwnNode: node.id == manager.myNodeNum)
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            centerOnNodes()
        }
        .onChange(of: manager.meshNodes) { _ in
            // Re-center if no selection
            if selectedNode == nil && !manager.nodesWithPositions.isEmpty {
                centerOnNodes()
            }
        }
    }

    private func centerOnNodes() {
        let nodesWithPos = manager.nodesWithPositions
        guard !nodesWithPos.isEmpty else { return }

        if nodesWithPos.count == 1 {
            // Single node - center on it
            if let pos = nodesWithPos.first?.position {
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: pos.latitude, longitude: pos.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        } else {
            // Multiple nodes - fit them all
            let lats = nodesWithPos.compactMap { $0.position?.latitude }
            let lons = nodesWithPos.compactMap { $0.position?.longitude }

            guard let minLat = lats.min(), let maxLat = lats.max(),
                  let minLon = lons.min(), let maxLon = lons.max() else { return }

            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )

            let latDelta = max(0.01, (maxLat - minLat) * 1.5)
            let lonDelta = max(0.01, (maxLon - minLon) * 1.5)

            region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        }
    }
}

// MARK: - Mesh Node Annotation

struct MeshNodeAnnotation: View {
    let node: MeshNode
    let isOwnNode: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                // Node icon
                ZStack {
                    Circle()
                        .fill(nodeColor)
                        .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                        .shadow(color: nodeColor.opacity(0.5), radius: isSelected ? 6 : 3)

                    if isOwnNode {
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                            .font(.system(size: isSelected ? 18 : 14))
                    } else {
                        Text(node.shortName.prefix(2))
                            .font(.system(size: isSelected ? 14 : 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }

                // Label when selected
                if isSelected {
                    Text(node.shortName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var nodeColor: Color {
        if isOwnNode {
            return .green
        }
        guard let hops = node.hopDistance else { return .gray }
        switch hops {
        case 0: return .blue
        case 1: return .cyan
        case 2: return .orange
        default: return .red
        }
    }
}

// MARK: - Mesh Node Detail Card

struct MeshNodeDetailCard: View {
    let node: MeshNode
    let isOwnNode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(node.longName)
                            .font(.headline)

                        if isOwnNode {
                            Text("YOU")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }

                    Text(node.formattedNodeId)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let hops = node.hopDistance {
                    VStack(alignment: .trailing) {
                        Text("\(hops)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(hopColor(hops))
                        Text("hops")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            // Stats
            HStack(spacing: 16) {
                if let pos = node.position {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Position", systemImage: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.5f, %.5f", pos.latitude, pos.longitude))
                            .font(.system(.caption, design: .monospaced))
                        if let alt = pos.altitude {
                            Text("\(alt)m altitude")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let snr = node.snr {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                            Text(String(format: "%.1f dB", snr))
                        }
                        .font(.caption)
                    }

                    if let battery = node.batteryLevel {
                        HStack(spacing: 4) {
                            Image(systemName: batteryIcon(battery))
                            Text("\(battery)%")
                        }
                        .font(.caption)
                        .foregroundColor(batteryColor(battery))
                    }

                    Text(timeAgo(from: node.lastHeard))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private func hopColor(_ hops: Int) -> Color {
        switch hops {
        case 0: return .green
        case 1: return .blue
        case 2: return .orange
        default: return .red
        }
    }

    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case 76...100: return "battery.100"
        case 51...75: return "battery.75"
        case 26...50: return "battery.50"
        case 1...25: return "battery.25"
        default: return "battery.0"
        }
    }

    private func batteryColor(_ level: Int) -> Color {
        switch level {
        case 51...100: return .green
        case 21...50: return .orange
        default: return .red
        }
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}

// MARK: - MeshNode Coordinate Extension

extension MeshNode {
    var coordinate: CLLocationCoordinate2D {
        guard let pos = position else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        return CLLocationCoordinate2D(latitude: pos.latitude, longitude: pos.longitude)
    }
}

// MARK: - Preview

struct MeshNodeMapView_Previews: PreviewProvider {
    static var previews: some View {
        MeshNodeMapView(manager: MeshtasticManager())
    }
}
