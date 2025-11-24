//
//  LineOfSightView.swift
//  OmniTAKMobile
//
//  SwiftUI view for Line of Sight analysis with terrain profile visualization
//

import SwiftUI
import CoreLocation
import MapKit

// MARK: - Line of Sight View

struct LineOfSightView: View {
    @StateObject private var service = LineOfSightService()
    @Environment(\.dismiss) var dismiss

    @State private var observerLat: String = "38.8977"
    @State private var observerLon: String = "-77.0365"
    @State private var targetLat: String = "38.9072"
    @State private var targetLon: String = "-77.0369"
    @State private var observerHeight: String = "2.0"
    @State private var targetHeight: String = "2.0"
    @State private var selectedFrequencyBand: RadioFrequencyBand = .vhf
    @State private var customFrequency: String = "150.0"
    @State private var showFrequencyPicker: Bool = false
    @State private var showObstructionDetails: Bool = false
    @State private var copiedReport: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Observer Section
                    observerInputSection

                    // Target Section
                    targetInputSection

                    // Radio Configuration
                    radioConfigSection

                    // Analyze Button
                    analyzeButton

                    // Results Section
                    if let analysis = service.currentAnalysis {
                        resultsSection(analysis: analysis)

                        // Terrain Profile
                        terrainProfileSection(analysis: analysis)

                        // Obstructions
                        if !analysis.obstructions.isEmpty {
                            obstructionsSection(analysis: analysis)
                        }

                        // Radio Propagation
                        if analysis.frequencyMHz != nil {
                            radioPropagationSection(analysis: analysis)
                        }

                        // Export Button
                        exportButton(analysis: analysis)
                    }
                }
                .padding(16)
            }
            .background(Color(hex: "#1E1E1E"))
            .navigationTitle("Line of Sight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Observer Input Section

    private var observerInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(Color(hex: "#FFFC00"))

                Text("OBSERVER")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#888888"))
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    coordinateField(label: "Latitude", text: $observerLat)
                    coordinateField(label: "Longitude", text: $observerLon)
                }

                heightField(label: "Height (m AGL)", text: $observerHeight)
            }
            .padding(12)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)
        }
    }

    // MARK: - Target Input Section

    private var targetInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(Color(hex: "#FFFC00"))

                Text("TARGET")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#888888"))
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    coordinateField(label: "Latitude", text: $targetLat)
                    coordinateField(label: "Longitude", text: $targetLon)
                }

                heightField(label: "Height (m AGL)", text: $targetHeight)
            }
            .padding(12)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)
        }
    }

    // MARK: - Radio Configuration Section

    private var radioConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(Color(hex: "#FFFC00"))

                Text("RADIO PROPAGATION")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#888888"))

                Spacer()

                Toggle("", isOn: $showFrequencyPicker)
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#FFFC00")))
                    .labelsHidden()
            }

            if showFrequencyPicker {
                VStack(spacing: 8) {
                    // Frequency Band Selector
                    HStack {
                        Text("Band")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#CCCCCC"))

                        Spacer()

                        Picker("Band", selection: $selectedFrequencyBand) {
                            ForEach(RadioFrequencyBand.allCases, id: \.self) { band in
                                Text(band.rawValue).tag(band)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(Color(hex: "#FFFC00"))
                    }

                    // Custom Frequency Input
                    HStack {
                        Text("Frequency (MHz)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#CCCCCC"))

                        Spacer()

                        TextField("MHz", text: $customFrequency)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#FFFC00"))
                            .frame(width: 100)
                    }

                    Text(selectedFrequencyBand.fresnelZoneImportance)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#888888"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color(hex: "#2A2A2A"))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Analyze Button

    private var analyzeButton: some View {
        Button(action: performAnalysis) {
            HStack {
                if service.isAnalyzing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#1E1E1E")))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                }

                Text(service.isAnalyzing ? "Analyzing..." : "Analyze Line of Sight")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(Color(hex: "#1E1E1E"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "#FFFC00"))
            .cornerRadius(10)
        }
        .disabled(service.isAnalyzing)
    }

    // MARK: - Results Section

    private func resultsSection(analysis: LOSAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "#FFFC00"))

                Text("ANALYSIS RESULTS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#888888"))
            }

            VStack(spacing: 12) {
                // Status Badge
                HStack {
                    Image(systemName: analysis.result.icon)
                        .font(.system(size: 24))

                    Text(analysis.result.rawValue.uppercased())
                        .font(.system(size: 18, weight: .bold))

                    Spacer()
                }
                .foregroundColor(Color(hex: analysis.result.color))
                .padding(12)
                .background(Color(hex: analysis.result.color).opacity(0.15))
                .cornerRadius(8)

                // Key Metrics
                resultRow(label: "Total Distance", value: formatDistance(analysis.totalDistance))
                resultRow(label: "Min Clearance", value: String(format: "%.1f m", analysis.minClearance))
                resultRow(label: "Max Terrain Elevation", value: String(format: "%.1f m", analysis.maxTerrainElevation))
                resultRow(label: "Obstructions", value: "\(analysis.obstructions.count)")

                // Bearing Information
                let bearing = service.calculateBearing(from: analysis.startPoint, to: analysis.endPoint)
                resultRow(label: "Bearing", value: String(format: "%.1f\u{00B0}", bearing))
            }
            .padding(12)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)
        }
    }

    // MARK: - Terrain Profile Section

    private func terrainProfileSection(analysis: LOSAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Color(hex: "#FFFC00"))

                Text("TERRAIN PROFILE")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#888888"))
            }

            TerrainProfileView(profile: analysis.terrainProfile, analysis: analysis)
                .frame(height: 200)
                .background(Color(hex: "#2A2A2A"))
                .cornerRadius(8)
        }
    }

    // MARK: - Obstructions Section

    private func obstructionsSection(analysis: LOSAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color(hex: "#FF4444"))

                Text("OBSTRUCTIONS (\(analysis.obstructions.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#888888"))

                Spacer()

                Button(action: { showObstructionDetails.toggle() }) {
                    Text(showObstructionDetails ? "Hide" : "Show")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }

            if showObstructionDetails {
                VStack(spacing: 8) {
                    ForEach(Array(analysis.obstructions.prefix(5))) { obstruction in
                        obstructionRow(obstruction)
                    }

                    if analysis.obstructions.count > 5 {
                        Text("+ \(analysis.obstructions.count - 5) more obstructions")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#888888"))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(12)
                .background(Color(hex: "#2A2A2A"))
                .cornerRadius(8)
            }
        }
    }

    private func obstructionRow(_ obstruction: LOSObstruction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: obstruction.type.icon)
                    .foregroundColor(Color(hex: "#FF4444"))

                Text(obstruction.type.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text(String(format: "%.0f%% along path", obstruction.percentageAlongPath * 100))
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#888888"))
            }

            HStack {
                Text("Distance: \(formatDistance(obstruction.distanceFromObserver))")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#CCCCCC"))

                Spacer()

                Text("Deficit: \(String(format: "%.1f m", -obstruction.clearanceAvailable))")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#FF4444"))
            }
        }
        .padding(8)
        .background(Color(hex: "#333333"))
        .cornerRadius(6)
    }

    // MARK: - Radio Propagation Section

    private func radioPropagationSection(analysis: LOSAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(Color(hex: "#FFFC00"))

                Text("RADIO PROPAGATION")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#888888"))
            }

            VStack(spacing: 8) {
                if let freq = analysis.frequencyMHz {
                    resultRow(label: "Frequency", value: String(format: "%.1f MHz", freq))
                }

                if let fresnelClearance = analysis.fresnelZoneClearance {
                    let fresnelColor = fresnelClearance >= 60 ? "#4CAF50" : (fresnelClearance >= 40 ? "#FFA500" : "#FF4444")
                    HStack {
                        Text("Fresnel Zone Clearance")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#CCCCCC"))

                        Spacer()

                        Text(String(format: "%.1f%%", fresnelClearance))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: fresnelColor))
                    }

                    // Fresnel zone indicator
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(hex: "#333333"))

                            Rectangle()
                                .fill(Color(hex: fresnelColor))
                                .frame(width: geometry.size.width * min(fresnelClearance / 100, 1.0))
                        }
                    }
                    .frame(height: 8)
                    .cornerRadius(4)

                    Text("60% clearance recommended for reliable communications")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#888888"))
                }

                if let pathLoss = analysis.pathLossDB {
                    resultRow(label: "Path Loss", value: String(format: "%.1f dB", pathLoss))
                }

                if let range = analysis.estimatedRangeMeters {
                    resultRow(label: "Radio Horizon", value: formatDistance(range))
                }
            }
            .padding(12)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)
        }
    }

    // MARK: - Export Button

    private func exportButton(analysis: LOSAnalysis) -> some View {
        Button(action: { copyReport(analysis) }) {
            HStack {
                Image(systemName: copiedReport ? "checkmark.circle.fill" : "doc.on.doc")
                Text(copiedReport ? "Copied to Clipboard" : "Copy Report")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color(hex: "#FFFC00"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#FFFC00"), lineWidth: 1)
            )
        }
    }

    // MARK: - Helper Views

    private func coordinateField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#888888"))

            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#FFFC00"))
                .padding(8)
                .background(Color(hex: "#333333"))
                .cornerRadius(6)
        }
    }

    private func heightField(label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#CCCCCC"))

            Spacer()

            TextField("0.0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#FFFC00"))
                .frame(width: 80)
                .padding(8)
                .background(Color(hex: "#333333"))
                .cornerRadius(6)
        }
    }

    private func resultRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#CCCCCC"))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#FFFC00"))
        }
    }

    // MARK: - Helper Functions

    private func performAnalysis() {
        guard let obsLat = Double(observerLat),
              let obsLon = Double(observerLon),
              let tgtLat = Double(targetLat),
              let tgtLon = Double(targetLon),
              let obsHeight = Double(observerHeight),
              let tgtHeight = Double(targetHeight) else {
            return
        }

        let observer = CLLocationCoordinate2D(latitude: obsLat, longitude: obsLon)
        let target = CLLocationCoordinate2D(latitude: tgtLat, longitude: tgtLon)

        let frequency: Double? = showFrequencyPicker ? Double(customFrequency) : nil

        _ = service.analyzeLOS(
            from: observer,
            to: target,
            observerHeight: obsHeight,
            targetHeight: tgtHeight,
            frequencyMHz: frequency
        )
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    private func copyReport(_ analysis: LOSAnalysis) {
        let report = service.exportAnalysis(analysis)
        UIPasteboard.general.string = report
        copiedReport = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedReport = false
        }
    }
}

// MARK: - Terrain Profile View

struct TerrainProfileView: View {
    let profile: [TerrainProfilePoint]
    let analysis: LOSAnalysis

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - 32
            let height = geometry.size.height - 48

            ZStack {
                // Background grid
                gridLines(width: width, height: height)

                // Terrain fill
                terrainPath(width: width, height: height)
                    .fill(Color(hex: "#4A3520").opacity(0.6))

                // Terrain outline
                terrainPath(width: width, height: height)
                    .stroke(Color(hex: "#8B7355"), lineWidth: 2)

                // LOS Line
                losLinePath(width: width, height: height)
                    .stroke(
                        profile.contains(where: { $0.clearance < 0 }) ?
                        Color(hex: "#FF4444") : Color(hex: "#4CAF50"),
                        style: StrokeStyle(lineWidth: 2, dash: [5, 3])
                    )

                // Obstruction markers
                ForEach(Array(profile.enumerated()), id: \.offset) { index, point in
                    if point.clearance < 0 {
                        Circle()
                            .fill(Color(hex: "#FF4444"))
                            .frame(width: 6, height: 6)
                            .position(
                                x: 16 + (CGFloat(index) / CGFloat(profile.count - 1)) * width,
                                y: 24 + height - normalizeElevation(point.elevation, height: height)
                            )
                    }
                }

                // Observer marker
                Circle()
                    .fill(Color(hex: "#FFFC00"))
                    .frame(width: 10, height: 10)
                    .position(
                        x: 16,
                        y: 24 + height - normalizeElevation((profile.first?.elevation ?? 0) + analysis.observerHeight, height: height)
                    )

                // Target marker
                Circle()
                    .fill(Color(hex: "#FFFC00"))
                    .frame(width: 10, height: 10)
                    .position(
                        x: 16 + width,
                        y: 24 + height - normalizeElevation((profile.last?.elevation ?? 0) + analysis.targetHeight, height: height)
                    )

                // Labels
                VStack {
                    HStack {
                        Text("Observer")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#FFFC00"))

                        Spacer()

                        Text("Target")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#FFFC00"))
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    HStack {
                        Text("0 m")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#888888"))

                        Spacer()

                        Text(formatDistance(analysis.totalDistance))
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#888888"))
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(8)
    }

    private func gridLines(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            // Horizontal lines
            for i in 0...4 {
                let y = 24 + (CGFloat(i) / 4) * height
                path.move(to: CGPoint(x: 16, y: y))
                path.addLine(to: CGPoint(x: 16 + width, y: y))
            }

            // Vertical lines
            for i in 0...4 {
                let x = 16 + (CGFloat(i) / 4) * width
                path.move(to: CGPoint(x: x, y: 24))
                path.addLine(to: CGPoint(x: x, y: 24 + height))
            }
        }
        .stroke(Color(hex: "#333333"), lineWidth: 0.5)
    }

    private func terrainPath(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            guard !profile.isEmpty else { return }

            path.move(to: CGPoint(x: 16, y: 24 + height))

            for (index, point) in profile.enumerated() {
                let x = 16 + (CGFloat(index) / CGFloat(profile.count - 1)) * width
                let y = 24 + height - normalizeElevation(point.elevation, height: height)

                if index == 0 {
                    path.addLine(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            path.addLine(to: CGPoint(x: 16 + width, y: 24 + height))
            path.closeSubpath()
        }
    }

    private func losLinePath(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            guard !profile.isEmpty else { return }

            let startY = 24 + height - normalizeElevation(
                (profile.first?.elevation ?? 0) + analysis.observerHeight,
                height: height
            )
            let endY = 24 + height - normalizeElevation(
                (profile.last?.elevation ?? 0) + analysis.targetHeight,
                height: height
            )

            path.move(to: CGPoint(x: 16, y: startY))
            path.addLine(to: CGPoint(x: 16 + width, y: endY))
        }
    }

    private func normalizeElevation(_ elevation: Double, height: CGFloat) -> CGFloat {
        let minElev = profile.map { $0.elevation }.min() ?? 0
        let maxElev = max(
            profile.map { $0.elevation }.max() ?? 100,
            (profile.first?.elevation ?? 0) + analysis.observerHeight,
            (profile.last?.elevation ?? 0) + analysis.targetHeight
        )

        let range = maxElev - minElev
        guard range > 0 else { return 0 }

        return CGFloat((elevation - minElev) / range) * height
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }
}

// MARK: - Preview

struct LineOfSightView_Previews: PreviewProvider {
    static var previews: some View {
        LineOfSightView()
            .preferredColorScheme(.dark)
    }
}
