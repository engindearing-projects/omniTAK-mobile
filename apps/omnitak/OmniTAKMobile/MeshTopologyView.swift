//
//  MeshTopologyView.swift
//  OmniTAK Mobile
//
//  Beautiful mesh network topology visualization
//

import SwiftUI
import MapKit

struct MeshTopologyView: View {
    @ObservedObject var manager: MeshtasticManager
    @Environment(\.dismiss) var dismiss

    @State private var viewMode: ViewMode = .map
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    enum ViewMode: String, CaseIterable {
        case map = "Map"
        case graph = "Graph"
        case list = "List"

        var icon: String {
            switch self {
            case .map: return "map"
            case .graph: return "circle.hexagongrid"
            case .list: return "list.bullet"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // View Mode Picker
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on view mode
                switch viewMode {
                case .map:
                    meshMapView
                case .graph:
                    meshGraphView
                case .list:
                    meshListView
                }
            }
            .navigationTitle("Mesh Topology")
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

    // MARK: - Map View

    private var meshMapView: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: manager.meshNodes) { node in
                MapAnnotation(coordinate: CLLocationCoordinate2D(
                    latitude: node.position?.latitude ?? 0,
                    longitude: node.position?.longitude ?? 0
                )) {
                    MeshNodeMapMarker(node: node)
                }
            }
            .edgesIgnoringSafeArea(.bottom)

            VStack {
                Spacer()

                networkStatsOverlay
                    .padding()
            }
        }
    }

    // MARK: - Graph View

    private var meshGraphView: some View {
        ScrollView {
            VStack(spacing: 20) {
                MeshNetworkGraph(nodes: manager.meshNodes)
                    .frame(height: 400)
                    .padding()

                networkStatsCard
            }
        }
    }

    // MARK: - List View

    private var meshListView: some View {
        List {
            Section {
                networkStatsCard
            }

            Section("Mesh Nodes (\(manager.meshNodes.count))") {
                ForEach(sortedNodes) { node in
                    MeshNodeDetailRow(node: node)
                }
            }
        }
    }

    // MARK: - Supporting Views

    private var networkStatsOverlay: some View {
        VStack(spacing: 12) {
            HStack {
                StatPill(title: "Nodes", value: "\(manager.meshNodes.count)", color: .blue)
                StatPill(title: "Hops", value: String(format: "%.1f", manager.networkStats.averageHops), color: .green)
                StatPill(title: "Success", value: String(format: "%.0f%%", manager.networkStats.packetSuccessRate * 100), color: .orange)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private var networkStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Network Health", systemImage: "waveform.path.ecg")
                    .font(.headline)

                Spacer()

                Circle()
                    .fill(Color(manager.networkHealth.color))
                    .frame(width: 12, height: 12)

                Text(manager.networkHealth.displayText)
                    .font(.caption)
                    .foregroundColor(Color(manager.networkHealth.color))
            }

            Divider()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NetworkStatItem(
                    icon: "circle.hexagongrid.fill",
                    title: "Total Nodes",
                    value: "\(manager.networkStats.totalNodes)"
                )

                NetworkStatItem(
                    icon: "link",
                    title: "Connected",
                    value: "\(manager.networkStats.connectedNodes)"
                )

                NetworkStatItem(
                    icon: "arrow.triangle.branch",
                    title: "Avg Hops",
                    value: String(format: "%.1f", manager.networkStats.averageHops)
                )

                NetworkStatItem(
                    icon: "checkmark.circle",
                    title: "Success Rate",
                    value: String(format: "%.0f%%", manager.networkStats.packetSuccessRate * 100)
                )

                NetworkStatItem(
                    icon: "chart.bar",
                    title: "Utilization",
                    value: String(format: "%.0f%%", manager.networkStats.networkUtilization * 100)
                )

                NetworkStatItem(
                    icon: "clock",
                    title: "Last Update",
                    value: timeAgo(from: manager.networkStats.lastUpdate)
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var sortedNodes: [MeshNode] {
        manager.meshNodes.sorted { (lhs, rhs) in
            (lhs.hopDistance ?? 999) < (rhs.hopDistance ?? 999)
        }
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
}

// MARK: - Mesh Node Map Marker

struct MeshNodeMapMarker: View {
    let node: MeshNode

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(hopColor)
                    .frame(width: 40, height: 40)
                    .shadow(radius: 3)

                Text("\(node.hopDistance ?? 0)")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
            }

            Text(node.shortName)
                .font(.caption2)
                .bold()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white)
                .cornerRadius(4)
                .shadow(radius: 1)
        }
    }

    private var hopColor: Color {
        guard let hops = node.hopDistance else { return .gray }

        switch hops {
        case 0...1: return .green
        case 2: return .blue
        case 3: return .orange
        default: return .red
        }
    }
}

// MARK: - Mesh Network Graph

struct MeshNetworkGraph: View {
    let nodes: [MeshNode]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw connection lines
                ForEach(nodes.indices, id: \.self) { index in
                    ForEach((index + 1)..<nodes.count, id: \.self) { otherIndex in
                        if shouldDrawConnection(from: nodes[index], to: nodes[otherIndex]) {
                            ConnectionLine(
                                from: nodePosition(for: index, in: geometry.size),
                                to: nodePosition(for: otherIndex, in: geometry.size),
                                strength: connectionStrength(from: nodes[index], to: nodes[otherIndex])
                            )
                        }
                    }
                }

                // Draw nodes
                ForEach(nodes.indices, id: \.self) { index in
                    NetworkGraphNode(
                        node: nodes[index],
                        position: nodePosition(for: index, in: geometry.size)
                    )
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func nodePosition(for index: Int, in size: CGSize) -> CGPoint {
        // Arrange nodes in a circle
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.35
        let angle = (2 * .pi / CGFloat(nodes.count)) * CGFloat(index)

        return CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }

    private func shouldDrawConnection(from: MeshNode, to: MeshNode) -> Bool {
        // Draw connection if nodes are within 2 hops of each other
        let fromHops = from.hopDistance ?? 0
        let toHops = to.hopDistance ?? 0
        return abs(fromHops - toHops) <= 1
    }

    private func connectionStrength(from: MeshNode, to: MeshNode) -> Double {
        // Strength based on hop distance
        let avgHops = Double((from.hopDistance ?? 0) + (to.hopDistance ?? 0)) / 2.0
        return max(0.2, 1.0 - (avgHops / 5.0))
    }
}

struct ConnectionLine: View {
    let from: CGPoint
    let to: CGPoint
    let strength: Double

    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(
            Color.blue.opacity(strength),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: strength < 0.5 ? [5, 5] : [])
        )
    }
}

struct NetworkGraphNode: View {
    let node: MeshNode
    let position: CGPoint

    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(hopColor)
                .frame(width: 50, height: 50)
                .overlay(
                    VStack(spacing: 0) {
                        Text(node.shortName)
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.white)

                        if let hops = node.hopDistance {
                            Text("\(hops)h")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                )
                .shadow(radius: 3)
        }
        .position(position)
    }

    private var hopColor: Color {
        guard let hops = node.hopDistance else { return .gray }

        switch hops {
        case 0...1: return .green
        case 2: return .blue
        case 3: return .orange
        default: return .red
        }
    }
}

// MARK: - Mesh Node Detail Row

struct MeshNodeDetailRow: View {
    let node: MeshNode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.longName)
                        .font(.headline)

                    Text("ID: \(String(format: "%08X", node.id))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let hops = node.hopDistance {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption)
                        Text("\(hops) hops")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(hopColor.opacity(0.2))
                    .foregroundColor(hopColor)
                    .cornerRadius(8)
                }
            }

            HStack(spacing: 16) {
                if let snr = node.snr {
                    DetailBadge(icon: "waveform", text: String(format: "%.1f dB", snr))
                }

                if let battery = node.batteryLevel {
                    DetailBadge(icon: "battery.100", text: "\(battery)%")
                }

                if let lastHeard = node.lastHeard {
                    DetailBadge(icon: "clock", text: timeAgo(from: lastHeard))
                }
            }

            if let position = node.position {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(String(format: "%.4f, %.4f", position.latitude, position.longitude))
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var hopColor: Color {
        guard let hops = node.hopDistance else { return .gray }

        switch hops {
        case 0...1: return .green
        case 2: return .blue
        case 3: return .orange
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

struct DetailBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }
}

// MARK: - Network Stat Item

struct NetworkStatItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.body)
                    .bold()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .bold()

            Text(title)
                .font(.caption2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(12)
    }
}

// MARK: - Preview

struct MeshTopologyView_Previews: PreviewProvider {
    static var previews: some View {
        MeshTopologyView(manager: MeshtasticManager())
    }
}
