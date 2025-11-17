//
//  Map3DSettingsView.swift
//  OmniTAKMobile
//
//  SwiftUI settings panel for 3D view controls
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Main Settings View

struct Map3DSettingsView: View {
    @ObservedObject var terrainService: TerrainVisualizationService
    @Environment(\.dismiss) var dismiss
    @State private var showPresetNameAlert = false
    @State private var newPresetName = ""
    @State private var showDeleteConfirmation = false
    @State private var presetToDelete: CameraPreset?

    var body: some View {
        NavigationView {
            List {
                // View Mode Section
                Section("VIEW MODE") {
                    ForEach(Map3DViewMode.allCases) { mode in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                terrainService.currentMode = mode
                            }
                        }) {
                            HStack {
                                Image(systemName: mode.icon)
                                    .foregroundColor(terrainService.currentMode == mode ? .green : .gray)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.rawValue)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)

                                    Text(mode.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                if terrainService.currentMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.6))
                    }
                }

                // Camera Controls Section
                Section("CAMERA CONTROLS") {
                    // Pitch Control
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Pitch (Tilt)", systemImage: "arrow.up.and.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            Text(TerrainVisualizationService.formatPitch(terrainService.cameraState.pitch))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(terrainService.cameraState.pitch) },
                                set: { terrainService.setPitch(CGFloat($0)) }
                            ),
                            in: Double(terrainService.minPitch)...Double(terrainService.maxPitch),
                            step: 1.0
                        )
                        .accentColor(.green)

                        HStack {
                            Text("Overhead")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("Horizon")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.6))

                    // Heading Control (Compass Wheel)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Heading (Rotation)", systemImage: "location.north.circle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            Text(TerrainVisualizationService.formatHeading(terrainService.cameraState.heading))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }

                        HeadingWheelView(heading: Binding(
                            get: { terrainService.cameraState.heading },
                            set: { terrainService.setHeading($0) }
                        ))
                        .frame(height: 80)

                        Button(action: {
                            withAnimation {
                                terrainService.resetToNorth()
                            }
                        }) {
                            HStack {
                                Image(systemName: "location.north.fill")
                                Text("Reset to North")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.6))

                    // Altitude/Distance Control
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Altitude", systemImage: "arrow.up.to.line")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            Text(TerrainVisualizationService.formatDistance(terrainService.cameraState.distance))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }

                        // Logarithmic slider for altitude
                        Slider(
                            value: Binding(
                                get: { log10(terrainService.cameraState.distance) },
                                set: { terrainService.setDistance(pow(10, $0)) }
                            ),
                            in: log10(terrainService.minDistance)...log10(terrainService.maxDistance)
                        )
                        .accentColor(.green)

                        HStack {
                            Text("Close")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("Far")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.6))
                }

                // Terrain Settings Section
                Section("TERRAIN") {
                    Picker("Exaggeration", selection: $terrainService.terrainExaggeration) {
                        ForEach(TerrainExaggeration.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .listRowBackground(Color.black.opacity(0.6))

                    Toggle(isOn: $terrainService.showElevationAwareness) {
                        HStack {
                            Image(systemName: "mountain.2.fill")
                                .foregroundColor(.green)
                            Text("Elevation Awareness")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .listRowBackground(Color.black.opacity(0.6))

                    HStack {
                        Text("Current Terrain Elevation")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.0f m", terrainService.currentTerrainElevation))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    .listRowBackground(Color.black.opacity(0.6))
                }

                // Quick Actions Section
                Section("QUICK ACTIONS") {
                    Button(action: {
                        withAnimation {
                            terrainService.transitionTo2D()
                        }
                    }) {
                        QuickActionRow(
                            icon: "map",
                            title: "Switch to 2D",
                            subtitle: "Overhead view with no tilt"
                        )
                    }
                    .listRowBackground(Color.black.opacity(0.6))

                    Button(action: {
                        withAnimation {
                            terrainService.transitionTo3D()
                        }
                    }) {
                        QuickActionRow(
                            icon: "view.3d",
                            title: "Switch to 3D",
                            subtitle: "Perspective view at 45 degree tilt"
                        )
                    }
                    .listRowBackground(Color.black.opacity(0.6))

                    Button(action: {
                        withAnimation {
                            terrainService.resetCamera()
                        }
                    }) {
                        QuickActionRow(
                            icon: "arrow.counterclockwise",
                            title: "Reset Camera",
                            subtitle: "Return to default 2D north-up view"
                        )
                    }
                    .listRowBackground(Color.black.opacity(0.6))

                    Button(action: {
                        Task {
                            await terrainService.positionCameraAtGroundLevel(
                                coordinate: terrainService.cameraState.centerCoordinate
                            )
                        }
                    }) {
                        QuickActionRow(
                            icon: "figure.stand",
                            title: "Ground Level View",
                            subtitle: "Camera at 2m above terrain"
                        )
                    }
                    .listRowBackground(Color.black.opacity(0.6))

                    Button(action: {
                        Task {
                            await terrainService.positionCameraElevated(
                                coordinate: terrainService.cameraState.centerCoordinate,
                                heightAboveGround: 100
                            )
                        }
                    }) {
                        QuickActionRow(
                            icon: "airplane",
                            title: "Elevated View",
                            subtitle: "Camera at 100m above terrain"
                        )
                    }
                    .listRowBackground(Color.black.opacity(0.6))
                }

                // Camera Presets Section
                Section("CAMERA PRESETS") {
                    Button(action: {
                        showPresetNameAlert = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Save Current View")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color.black.opacity(0.6))

                    if terrainService.savedPresets.isEmpty {
                        Text("No saved presets")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .italic()
                            .listRowBackground(Color.black.opacity(0.6))
                    } else {
                        ForEach(terrainService.savedPresets) { preset in
                            PresetRow(
                                preset: preset,
                                onApply: {
                                    withAnimation {
                                        terrainService.applyPreset(preset)
                                    }
                                },
                                onDelete: {
                                    presetToDelete = preset
                                    showDeleteConfirmation = true
                                }
                            )
                            .listRowBackground(Color.black.opacity(0.6))
                        }
                    }

                    if !terrainService.savedPresets.isEmpty {
                        Button(action: {
                            terrainService.clearAllPresets()
                        }) {
                            Text("Clear All Presets")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        .listRowBackground(Color.black.opacity(0.6))
                    }
                }

                // Flyover Section
                if terrainService.isFlyoverActive {
                    Section("FLYOVER") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Progress")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(terrainService.flyoverProgress * 100))%")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.orange)
                            }

                            ProgressView(value: terrainService.flyoverProgress)
                                .accentColor(.orange)
                        }
                        .listRowBackground(Color.black.opacity(0.6))

                        HStack {
                            Button(action: {
                                terrainService.pauseFlyover()
                            }) {
                                Image(systemName: "pause.fill")
                                    .foregroundColor(.yellow)
                            }

                            Button(action: {
                                terrainService.resumeFlyover()
                            }) {
                                Image(systemName: "play.fill")
                                    .foregroundColor(.green)
                            }

                            Button(action: {
                                terrainService.stopFlyover()
                            }) {
                                Image(systemName: "stop.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .listRowBackground(Color.black.opacity(0.6))
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .background(Color(red: 0.05, green: 0.05, blue: 0.1))
            .navigationTitle("3D View Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.green)
                }
            }
        }
        .alert("Save Camera Preset", isPresented: $showPresetNameAlert) {
            TextField("Preset Name", text: $newPresetName)
            Button("Cancel", role: .cancel) {
                newPresetName = ""
            }
            Button("Save") {
                if !newPresetName.isEmpty {
                    terrainService.saveCurrentAsPreset(name: newPresetName)
                    newPresetName = ""
                }
            }
        } message: {
            Text("Enter a name for this camera position")
        }
        .alert("Delete Preset?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let preset = presetToDelete {
                    terrainService.deletePreset(preset)
                }
                presetToDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Supporting Views

struct QuickActionRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 12))
        }
    }
}

struct PresetRow: View {
    let preset: CameraPreset
    let onApply: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    Text("P: \(String(format: "%.0f", preset.pitch))°")
                    Text("H: \(String(format: "%.0f", preset.heading))°")
                    Text("D: \(TerrainVisualizationService.formatDistance(preset.distance))")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.cyan)
            }

            Spacer()

            Button(action: onApply) {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
            }
            .buttonStyle(BorderlessButtonStyle())

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
}

// MARK: - Heading Wheel View

struct HeadingWheelView: View {
    @Binding var heading: CLLocationDirection
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 10

            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)

                // Direction markers
                ForEach(0..<8) { index in
                    let angle = Double(index) * 45.0 - 90.0
                    let direction = directionLabel(for: index)
                    let isCardinal = index % 2 == 0

                    Text(direction)
                        .font(.system(size: isCardinal ? 12 : 10, weight: isCardinal ? .bold : .regular))
                        .foregroundColor(isCardinal ? .white : .gray)
                        .position(
                            x: center.x + CGFloat(cos(angle * .pi / 180)) * (radius - 15),
                            y: center.y + CGFloat(sin(angle * .pi / 180)) * (radius - 15)
                        )
                }

                // Current heading indicator
                let indicatorAngle = heading - 90
                Path { path in
                    path.move(to: center)
                    path.addLine(to: CGPoint(
                        x: center.x + CGFloat(cos(indicatorAngle * .pi / 180)) * radius,
                        y: center.y + CGFloat(sin(indicatorAngle * .pi / 180)) * radius
                    ))
                }
                .stroke(Color.green, lineWidth: 3)

                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .position(
                        x: center.x + CGFloat(cos(indicatorAngle * .pi / 180)) * radius,
                        y: center.y + CGFloat(sin(indicatorAngle * .pi / 180)) * radius
                    )

                // Center point
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 8, height: 8)
                    .position(center)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        var angle = atan2(dy, dx) * 180 / .pi + 90

                        if angle < 0 {
                            angle += 360
                        }

                        heading = angle.truncatingRemainder(dividingBy: 360)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }

    private func directionLabel(for index: Int) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return directions[index]
    }
}

// MARK: - Compact 3D Controls Overlay

struct Map3DControlsOverlay: View {
    @ObservedObject var terrainService: TerrainVisualizationService
    @Binding var showFullSettings: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Mode toggle button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if terrainService.currentMode == .standard2D {
                        terrainService.transitionTo3D()
                    } else {
                        terrainService.transitionTo2D()
                    }
                }
            }) {
                VStack(spacing: 2) {
                    Image(systemName: terrainService.currentMode == .standard2D ? "view.3d" : "map")
                        .font(.system(size: 18, weight: .semibold))

                    Text(terrainService.currentMode == .standard2D ? "3D" : "2D")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    terrainService.currentMode == .perspective3D ?
                    Color.blue.opacity(0.8) : Color.black.opacity(0.7)
                )
                .cornerRadius(8)
            }

            // Reset north button
            Button(action: {
                withAnimation {
                    terrainService.resetToNorth()
                }
            }) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
            }

            // Settings button
            Button(action: {
                showFullSettings = true
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - Pitch/Heading Mini Display

struct CameraStatusMiniView: View {
    @ObservedObject var terrainService: TerrainVisualizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 10))
                    .foregroundColor(.green)

                Text(TerrainVisualizationService.formatPitch(terrainService.cameraState.pitch))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }

            HStack(spacing: 6) {
                Image(systemName: "location.north.circle")
                    .font(.system(size: 10))
                    .foregroundColor(.green)

                Text(TerrainVisualizationService.formatHeading(terrainService.cameraState.heading))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.up.to.line")
                    .font(.system(size: 10))
                    .foregroundColor(.green)

                Text(TerrainVisualizationService.formatDistance(terrainService.cameraState.distance))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
    }
}

// MARK: - Look At Coordinate View

struct LookAtCoordinateView: View {
    @ObservedObject var terrainService: TerrainVisualizationService
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var distanceText = "5000"
    @State private var showError = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("TARGET COORDINATES") {
                    TextField("Latitude", text: $latitudeText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 14, design: .monospaced))

                    TextField("Longitude", text: $longitudeText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 14, design: .monospaced))
                }

                Section("CAMERA DISTANCE") {
                    TextField("Distance (meters)", text: $distanceText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 14, design: .monospaced))
                }

                Section {
                    Button(action: lookAtTarget) {
                        HStack {
                            Image(systemName: "scope")
                            Text("Look At Target")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Look At Coordinate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Invalid Input", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enter valid latitude and longitude values.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func lookAtTarget() {
        guard let lat = Double(latitudeText),
              let lon = Double(longitudeText),
              let distance = Double(distanceText),
              lat >= -90 && lat <= 90,
              lon >= -180 && lon <= 180 else {
            showError = true
            return
        }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        terrainService.lookAt(coordinate: coordinate, fromDistance: distance)
        dismiss()
    }
}

// MARK: - Preview

struct Map3DSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Map3DSettingsView(terrainService: TerrainVisualizationService())
            .preferredColorScheme(.dark)
    }
}
