//
//  ElevationProfileView.swift
//  OmniTAKMobile
//
//  SwiftUI view for displaying elevation profile analysis
//

import SwiftUI
import CoreLocation
import MapKit
import Charts

// MARK: - Elevation Profile View

struct ElevationProfileView: View {
    @StateObject private var service = ElevationProfileService()
    @Environment(\.dismiss) var dismiss

    @State private var selectedPathMode: PathSelectionMode = .manual
    @State private var manualCoordinates: [CLLocationCoordinate2D] = []
    @State private var coordinateInput: String = ""
    @State private var profileName: String = "New Profile"
    @State private var samplingInterval: Double = 50
    @State private var selectedUnit: ElevationUnit = .meters
    @State private var showExportSheet = false
    @State private var selectedExportFormat: ElevationExportFormat = .json
    @State private var showSavedProfiles = false
    @State private var showError = false
    @State private var selectedPointIndex: Int?

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Path Selection
                        pathSelectionSection

                        // Profile Options
                        profileOptionsSection

                        // Generate Button
                        if !manualCoordinates.isEmpty || selectedPathMode != .manual {
                            generateButton
                        }

                        // Progress Indicator
                        if service.isCalculating {
                            progressSection
                        }

                        // Profile Display
                        if let profile = service.currentProfile {
                            profileDisplaySection(profile)
                        }

                        // Saved Profiles
                        if !service.savedProfiles.isEmpty {
                            savedProfilesSection
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Elevation Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if service.currentProfile != nil {
                        Button(action: { showExportSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(Color(hex: "#FFFC00"))
                        }
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                exportSheet
            }
            .sheet(isPresented: $showSavedProfiles) {
                savedProfilesSheet
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(service.errorMessage ?? "An unknown error occurred")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Path Selection Section

    private var pathSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PATH SELECTION")

            Picker("Mode", selection: $selectedPathMode) {
                ForEach(PathSelectionMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)

            if selectedPathMode == .manual {
                manualCoordinateInput
            } else if selectedPathMode == .demo {
                demoPathSection
            }

            // Display added coordinates
            if !manualCoordinates.isEmpty {
                coordinatesList
            }
        }
    }

    private var manualCoordinateInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter coordinates (lat,lon format):")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#888888"))

            HStack {
                TextField("e.g., 37.7749,-122.4194", text: $coordinateInput)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(Color(hex: "#2A2A2A"))
                    .cornerRadius(8)
                    .foregroundColor(.white)

                Button(action: addCoordinate) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
    }

    private var demoPathSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Demo paths for testing:")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#888888"))

            VStack(spacing: 8) {
                ForEach(DemoPath.allCases, id: \.self) { path in
                    Button(action: { loadDemoPath(path) }) {
                        HStack {
                            Image(systemName: path.icon)
                                .foregroundColor(Color(hex: "#FFFC00"))
                            Text(path.displayName)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(path.coordinates.count) pts")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#888888"))
                        }
                        .padding(10)
                        .background(Color(hex: "#2A2A2A"))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var coordinatesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Points (\(manualCoordinates.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#888888"))

                Spacer()

                Button(action: { manualCoordinates.removeAll() }) {
                    Text("Clear All")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FF4444"))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(manualCoordinates.enumerated()), id: \.offset) { index, coord in
                        coordinateChip(index: index, coordinate: coord)
                    }
                }
            }
        }
    }

    private func coordinateChip(index: Int, coordinate: CLLocationCoordinate2D) -> some View {
        HStack(spacing: 4) {
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: "#1E1E1E"))
                .frame(width: 16, height: 16)
                .background(Color(hex: "#FFFC00"))
                .clipShape(Circle())

            Text(String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude))
                .font(.system(size: 11))
                .foregroundColor(.white)

            Button(action: { manualCoordinates.remove(at: index) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#666666"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Profile Options Section

    private var profileOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("OPTIONS")

            VStack(spacing: 12) {
                // Profile Name
                HStack {
                    Text("Name")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Spacer()
                    TextField("Profile Name", text: $profileName)
                        .textFieldStyle(PlainTextFieldStyle())
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(Color(hex: "#FFFC00"))
                }

                Divider().background(Color(hex: "#333333"))

                // Sampling Interval
                HStack {
                    Text("Sampling")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(samplingInterval))m")
                        .foregroundColor(Color(hex: "#FFFC00"))
                }

                Slider(value: $samplingInterval, in: 10...200, step: 10)
                    .accentColor(Color(hex: "#FFFC00"))

                Divider().background(Color(hex: "#333333"))

                // Elevation Unit
                HStack {
                    Text("Unit")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Spacer()
                    Picker("Unit", selection: $selectedUnit) {
                        ForEach(ElevationUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 150)
                }
            }
            .padding(12)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button(action: generateProfile) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Generate Elevation Profile")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(Color(hex: "#1E1E1E"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "#FFFC00"))
            .cornerRadius(12)
        }
        .disabled(service.isCalculating)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 8) {
            ProgressView(value: service.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#FFFC00")))

            Text("Calculating elevation profile... \(Int(service.progress * 100))%")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#888888"))
        }
        .padding(12)
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(8)
    }

    // MARK: - Profile Display Section

    private func profileDisplaySection(_ profile: ElevationProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart
            elevationChartSection(profile)

            // Statistics
            statisticsSection(profile)

            // Gradient Analysis
            gradientAnalysisSection(profile)

            // Save Button
            saveProfileButton(profile)
        }
    }

    @ViewBuilder
    private func elevationChartSection(_ profile: ElevationProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ELEVATION CHART")

            if #available(iOS 16.0, *) {
                swiftUIChart(profile)
            } else {
                legacyChart(profile)
            }

            // Selected point info
            if let index = selectedPointIndex, index < profile.points.count {
                let point = profile.points[index]
                selectedPointInfo(point)
            }
        }
    }

    @available(iOS 16.0, *)
    private func swiftUIChart(_ profile: ElevationProfile) -> some View {
        Chart {
            ForEach(profile.points) { point in
                LineMark(
                    x: .value("Distance", point.distance),
                    y: .value("Elevation", selectedUnit.convert(fromMeters: point.elevation))
                )
                .foregroundStyle(Color(hex: "#FFFC00"))
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            ForEach(profile.points) { point in
                AreaMark(
                    x: .value("Distance", point.distance),
                    y: .value("Elevation", selectedUnit.convert(fromMeters: point.elevation))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#FFFC00").opacity(0.3), Color(hex: "#FFFC00").opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Highlight steep sections
            ForEach(profile.gradientSegments.filter { abs($0.grade) > 15 }) { segment in
                RectangleMark(
                    xStart: .value("Start", segment.startDistance),
                    xEnd: .value("End", segment.endDistance)
                )
                .foregroundStyle(Color(hex: segment.steepnessCategory.color).opacity(0.3))
            }
        }
        .chartXAxisLabel("Distance (\(ElevationProfileService.formatDistance(profile.statistics.totalDistance)))")
        .chartYAxisLabel("Elevation (\(selectedUnit.abbreviation))")
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(hex: "#333333"))
                AxisValueLabel()
                    .foregroundStyle(Color(hex: "#888888"))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color(hex: "#333333"))
                AxisValueLabel()
                    .foregroundStyle(Color(hex: "#888888"))
            }
        }
        .frame(height: 200)
        .padding(12)
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(8)
    }

    private func legacyChart(_ profile: ElevationProfile) -> some View {
        // Fallback chart for iOS < 16
        GeometryReader { geometry in
            let width = geometry.size.width - 24
            let height: CGFloat = 180

            ZStack(alignment: .bottomLeading) {
                // Grid lines
                Path { path in
                    for i in 0...4 {
                        let y = height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color(hex: "#333333"), lineWidth: 0.5)

                // Elevation line
                Path { path in
                    guard !profile.points.isEmpty else { return }

                    let maxDist = profile.statistics.totalDistance
                    let minElev = profile.statistics.minElevation
                    let maxElev = profile.statistics.maxElevation
                    let elevRange = maxElev - minElev

                    for (index, point) in profile.points.enumerated() {
                        let x = (point.distance / maxDist) * Double(width)
                        let normalizedElev = elevRange > 0 ? (point.elevation - minElev) / elevRange : 0.5
                        let y = Double(height) * (1 - normalizedElev)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color(hex: "#FFFC00"), lineWidth: 2)
            }
            .padding(12)
        }
        .frame(height: 200)
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(8)
    }

    private func selectedPointInfo(_ point: ElevationPoint) -> some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(Color(hex: "#FFFC00"))

            Text("Distance: \(ElevationProfileService.formatDistance(point.distance))")
                .font(.system(size: 12))
                .foregroundColor(.white)

            Spacer()

            Text("Elevation: \(selectedUnit.format(point.elevation))")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#FFFC00"))
        }
        .padding(8)
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(6)
    }

    // MARK: - Statistics Section

    private func statisticsSection(_ profile: ElevationProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("STATISTICS")

            VStack(spacing: 10) {
                // Primary stats row
                HStack(spacing: 12) {
                    statCard(
                        icon: "arrow.down.to.line",
                        label: "Min",
                        value: selectedUnit.format(profile.statistics.minElevation)
                    )

                    statCard(
                        icon: "arrow.up.to.line",
                        label: "Max",
                        value: selectedUnit.format(profile.statistics.maxElevation)
                    )
                }

                // Climb/Descent row
                HStack(spacing: 12) {
                    statCard(
                        icon: "arrow.up.right",
                        label: "Total Climb",
                        value: selectedUnit.format(profile.statistics.totalClimb),
                        color: "#4CAF50"
                    )

                    statCard(
                        icon: "arrow.down.right",
                        label: "Total Descent",
                        value: selectedUnit.format(profile.statistics.totalDescent),
                        color: "#F44336"
                    )
                }

                // Grade stats row
                HStack(spacing: 12) {
                    statCard(
                        icon: "chart.line.uptrend.xyaxis",
                        label: "Max Grade",
                        value: ElevationProfileService.formatGrade(profile.statistics.maxGrade)
                    )

                    statCard(
                        icon: "chart.line.flattrend.xyaxis",
                        label: "Avg Grade",
                        value: ElevationProfileService.formatGrade(profile.statistics.averageGrade)
                    )
                }

                // Distance and difficulty
                HStack(spacing: 12) {
                    statCard(
                        icon: "ruler",
                        label: "Distance",
                        value: ElevationProfileService.formatDistance(profile.statistics.totalDistance)
                    )

                    statCard(
                        icon: "exclamationmark.triangle",
                        label: "Difficulty",
                        value: profile.statistics.difficultyRating,
                        color: difficultyColor(profile.statistics.difficultyRating)
                    )
                }
            }
            .padding(12)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)
        }
    }

    private func statCard(icon: String, label: String, value: String, color: String = "#FFFC00") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: color))

                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#888888"))
            }

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(hex: "#1E1E1E"))
        .cornerRadius(6)
    }

    private func difficultyColor(_ rating: String) -> String {
        switch rating {
        case "Easy": return "#4CAF50"
        case "Moderate": return "#FFEB3B"
        case "Difficult": return "#FF9800"
        default: return "#F44336"
        }
    }

    // MARK: - Gradient Analysis Section

    private func gradientAnalysisSection(_ profile: ElevationProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("GRADIENT ANALYSIS")

            VStack(spacing: 8) {
                // Steepness distribution
                let categories = Dictionary(grouping: profile.gradientSegments) { $0.steepnessCategory }

                ForEach(SteepnessCategory.allCases, id: \.self) { category in
                    let count = categories[category]?.count ?? 0
                    let percentage = profile.gradientSegments.isEmpty ? 0 : (Double(count) / Double(profile.gradientSegments.count)) * 100

                    HStack {
                        Circle()
                            .fill(Color(hex: category.color))
                            .frame(width: 12, height: 12)

                        Text(category.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(.white)

                        Spacer()

                        Text("\(Int(percentage))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: category.color))
                    }
                }

                if profile.statistics.steepSectionCount > 0 {
                    Divider().background(Color(hex: "#333333"))

                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color(hex: "#FF9800"))

                        Text("Steepest Section")
                            .font(.system(size: 12))
                            .foregroundColor(.white)

                        Spacer()

                        Text("\(ElevationProfileService.formatGrade(profile.statistics.steepestSectionGrade)) at \(ElevationProfileService.formatDistance(profile.statistics.steepestSectionDistance))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#FF9800"))
                    }
                }
            }
            .padding(12)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)
        }
    }

    // MARK: - Save Profile Button

    private func saveProfileButton(_ profile: ElevationProfile) -> some View {
        Button(action: { service.saveProfile(profile) }) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                Text("Save Profile")
                    .font(.system(size: 14, weight: .medium))
            }
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

    // MARK: - Saved Profiles Section

    private var savedProfilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("SAVED PROFILES")

                Spacer()

                Button(action: { showSavedProfiles = true }) {
                    Text("View All (\(service.savedProfiles.count))")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }

            ForEach(service.savedProfiles.prefix(3)) { profile in
                savedProfileRow(profile)
            }
        }
    }

    private func savedProfileRow(_ profile: ElevationProfile) -> some View {
        Button(action: { service.currentProfile = profile }) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(Color(hex: "#FFFC00"))

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)

                    Text("\(ElevationProfileService.formatDistance(profile.statistics.totalDistance)) | \(profile.points.count) points")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#888888"))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#666666"))
            }
            .padding(12)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)
        }
    }

    // MARK: - Export Sheet

    private var exportSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Export Format")
                    .font(.headline)

                ForEach(ElevationExportFormat.allCases, id: \.self) { format in
                    Button(action: { exportProfile(format: format) }) {
                        HStack {
                            Image(systemName: iconForFormat(format))
                            Text(format.rawValue)
                            Spacer()
                            Text(".\(format.fileExtension)")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Export Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showExportSheet = false
                    }
                }
            }
        }
    }

    private var savedProfilesSheet: some View {
        NavigationView {
            List {
                ForEach(service.savedProfiles) { profile in
                    Button(action: {
                        service.currentProfile = profile
                        showSavedProfiles = false
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.headline)

                            Text("Distance: \(ElevationProfileService.formatDistance(profile.statistics.totalDistance))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("Created: \(profile.createdAt, style: .relative)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        service.deleteProfile(service.savedProfiles[index])
                    }
                }
            }
            .navigationTitle("Saved Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        service.clearAllProfiles()
                    }
                    .foregroundColor(.red)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showSavedProfiles = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color(hex: "#888888"))
    }

    private func iconForFormat(_ format: ElevationExportFormat) -> String {
        switch format {
        case .json: return "doc.text"
        case .csv: return "tablecells"
        case .gpx: return "map"
        }
    }

    // MARK: - Actions

    private func addCoordinate() {
        let components = coordinateInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
            service.errorMessage = "Invalid coordinate format. Use: lat,lon"
            showError = true
            return
        }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        manualCoordinates.append(coordinate)
        coordinateInput = ""
    }

    private func loadDemoPath(_ path: DemoPath) {
        manualCoordinates = path.coordinates
        profileName = path.displayName
    }

    private func generateProfile() {
        guard !manualCoordinates.isEmpty else { return }

        let request = ElevationProfileRequest(
            coordinates: manualCoordinates,
            samplingInterval: samplingInterval,
            name: profileName
        )

        Task {
            do {
                _ = try await service.generateProfile(for: request)
            } catch {
                await MainActor.run {
                    service.errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func exportProfile(format: ElevationExportFormat) {
        guard let profile = service.currentProfile,
              let data = service.exportProfile(profile, format: format) else {
            return
        }

        let filename = "\(profile.name.replacingOccurrences(of: " ", with: "_")).\(format.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: tempURL)

            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            service.errorMessage = "Failed to export: \(error.localizedDescription)"
            showError = true
        }

        showExportSheet = false
    }
}

// MARK: - Supporting Types

enum PathSelectionMode: String, CaseIterable {
    case manual = "manual"
    case demo = "demo"

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .demo: return "Demo Paths"
        }
    }
}

enum DemoPath: String, CaseIterable {
    case mountain = "mountain"
    case valley = "valley"
    case coastal = "coastal"
    case flatland = "flatland"

    var displayName: String {
        switch self {
        case .mountain: return "Mountain Pass"
        case .valley: return "Valley Trail"
        case .coastal: return "Coastal Route"
        case .flatland: return "Flat Terrain"
        }
    }

    var icon: String {
        switch self {
        case .mountain: return "mountain.2"
        case .valley: return "arrow.down.forward.and.arrow.up.backward"
        case .coastal: return "water.waves"
        case .flatland: return "arrow.left.and.right"
        }
    }

    var coordinates: [CLLocationCoordinate2D] {
        switch self {
        case .mountain:
            // Mountain pass route
            return [
                CLLocationCoordinate2D(latitude: 39.7392, longitude: -105.9903), // Denver area
                CLLocationCoordinate2D(latitude: 39.7500, longitude: -105.9950),
                CLLocationCoordinate2D(latitude: 39.7600, longitude: -106.0000),
                CLLocationCoordinate2D(latitude: 39.7700, longitude: -106.0100),
                CLLocationCoordinate2D(latitude: 39.7800, longitude: -106.0200)
            ]

        case .valley:
            // Valley trail
            return [
                CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // SF area
                CLLocationCoordinate2D(latitude: 37.7800, longitude: -122.4250),
                CLLocationCoordinate2D(latitude: 37.7850, longitude: -122.4300),
                CLLocationCoordinate2D(latitude: 37.7900, longitude: -122.4350),
                CLLocationCoordinate2D(latitude: 37.7950, longitude: -122.4400)
            ]

        case .coastal:
            // Coastal route
            return [
                CLLocationCoordinate2D(latitude: 34.0195, longitude: -118.4912), // LA coast
                CLLocationCoordinate2D(latitude: 34.0250, longitude: -118.4950),
                CLLocationCoordinate2D(latitude: 34.0300, longitude: -118.5000),
                CLLocationCoordinate2D(latitude: 34.0350, longitude: -118.5050),
                CLLocationCoordinate2D(latitude: 34.0400, longitude: -118.5100)
            ]

        case .flatland:
            // Flat terrain
            return [
                CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298), // Chicago area
                CLLocationCoordinate2D(latitude: 41.8850, longitude: -87.6350),
                CLLocationCoordinate2D(latitude: 41.8900, longitude: -87.6400),
                CLLocationCoordinate2D(latitude: 41.8950, longitude: -87.6450),
                CLLocationCoordinate2D(latitude: 41.9000, longitude: -87.6500)
            ]
        }
    }
}

// MARK: - Steepness Category Extension

extension SteepnessCategory: CaseIterable {
    static var allCases: [SteepnessCategory] {
        [.flat, .gentle, .moderate, .steep, .verysteep, .extreme]
    }
}

// MARK: - Preview

struct ElevationProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ElevationProfileView()
    }
}
