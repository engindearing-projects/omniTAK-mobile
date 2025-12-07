//
//  MeshTopologyView.swift
//  OmniTAK Mobile
//
//  Mesh network node visualization
//

import SwiftUI

struct MeshTopologyView: View {
    @ObservedObject var manager: MeshtasticManager = MeshtasticManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var viewMode: ViewMode = .list
    @State private var showingCoTPublishAlert = false

    enum ViewMode: String, CaseIterable {
        case graph = "Graph"
        case list = "List"

        var icon: String {
            switch self {
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

                if manager.meshNodes.isEmpty {
                    emptyStateView
                } else {
                    // Content based on view mode
                    switch viewMode {
                    case .graph:
                        meshGraphView
                    case .list:
                        meshListView
                    }
                }
            }
            .navigationTitle("Mesh Nodes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !manager.nodesWithPositions.isEmpty {
                        Button {
                            manager.publishMeshNodesToMap()
                            showingCoTPublishAlert = true
                        } label: {
                            Label("Show on Map", systemImage: "map")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Published to Map", isPresented: $showingCoTPublishAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(manager.nodesWithPositions.count) mesh nodes with positions have been published to the TAK map.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Nodes Discovered")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Mesh nodes will appear here as they are discovered on the network.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Graph View

    private var meshGraphView: some View {
        ScrollView {
            VStack(spacing: 20) {
                MeshNetworkGraph(nodes: manager.meshNodes)
                    .frame(height: 350)
                    .padding()

                nodeStatsCard
            }
        }
    }

    // MARK: - List View

    private var meshListView: some View {
        List {
            Section {
                nodeStatsCard
            }

            Section("Mesh Nodes (\(manager.meshNodes.count))") {
                ForEach(sortedNodes) { node in
                    MeshNodeDetailRow(node: node, isOwnNode: node.id == manager.myNodeNum)
                }
            }
        }
    }

    // MARK: - Node Stats Card

    private var nodeStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Network Summary", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline)
                Spacer()
            }

            Divider()

            HStack(spacing: 20) {
                VStack {
                    Text("\(manager.meshNodes.count)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Total Nodes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    let directNodes = manager.meshNodes.filter { ($0.hopDistance ?? 0) <= 1 }.count
                    Text("\(directNodes)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Direct")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    let avgHops = manager.meshNodes.isEmpty ? 0 :
                        manager.meshNodes.compactMap { $0.hopDistance }.reduce(0, +) / max(manager.meshNodes.count, 1)
                    Text("\(avgHops)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Avg Hops")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var sortedNodes: [MeshNode] {
        manager.meshNodes.sorted { (lhs, rhs) in
            // Own node first, then by hop distance
            if lhs.id == manager.myNodeNum { return true }
            if rhs.id == manager.myNodeNum { return false }
            return (lhs.hopDistance ?? 999) < (rhs.hopDistance ?? 999)
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
        let count = max(nodes.count, 1)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.35
        let angle = (2 * .pi / CGFloat(count)) * CGFloat(index) - .pi / 2

        return CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }

    private func shouldDrawConnection(from: MeshNode, to: MeshNode) -> Bool {
        let fromHops = from.hopDistance ?? 0
        let toHops = to.hopDistance ?? 0
        return abs(fromHops - toHops) <= 1
    }

    private func connectionStrength(from: MeshNode, to: MeshNode) -> Double {
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
        case 0: return .green
        case 1: return .blue
        case 2: return .orange
        default: return .red
        }
    }
}

// MARK: - Mesh Node Detail Row

struct MeshNodeDetailRow: View {
    let node: MeshNode
    var isOwnNode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
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

                    Text("!\(String(format: "%08x", node.id))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let hops = node.hopDistance {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption)
                        Text("\(hops) hop\(hops == 1 ? "" : "s")")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(hopColor.opacity(0.2))
                    .foregroundColor(hopColor)
                    .cornerRadius(8)
                }
            }

            // Position row
            if let position = node.position {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                        .font(.caption)

                    Text(formatCoordinate(lat: position.latitude, lon: position.longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let alt = position.altitude {
                        Text("\(alt)m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack(spacing: 16) {
                if let snr = node.snr {
                    Label(String(format: "%.1f dB", snr), systemImage: "waveform")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let battery = node.batteryLevel {
                    Label("\(battery)%", systemImage: "battery.100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(timeAgo(from: node.lastHeard))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCoordinate(lat: Double, lon: Double) -> String {
        let latDir = lat >= 0 ? "N" : "S"
        let lonDir = lon >= 0 ? "E" : "W"
        return String(format: "%.5f%@ %.5f%@", abs(lat), latDir, abs(lon), lonDir)
    }

    private var hopColor: Color {
        guard let hops = node.hopDistance else { return .gray }

        switch hops {
        case 0: return .green
        case 1: return .blue
        case 2: return .orange
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

// MARK: - Preview

struct MeshTopologyView_Previews: PreviewProvider {
    static var previews: some View {
        MeshTopologyView()
    }
}
