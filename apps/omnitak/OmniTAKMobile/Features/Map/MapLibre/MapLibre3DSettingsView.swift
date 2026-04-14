//
//  MapLibre3DSettingsView.swift
//  OmniTAKMobile
//
//  Settings panel for MapLibre 3D terrain controls
//

import SwiftUI
import CoreLocation

// MARK: - MapLibre 3D Settings View

struct MapLibre3DSettingsView: View {
    @ObservedObject var service: MapLibreService
    @Environment(\.dismiss) var dismiss

    @State private var camera: MapLibreCamera = .terrain3DCamera
    @State private var showStylePicker = false

    var body: some View {
        NavigationView {
            ZStack {
                // Map View - only ignore safe area at bottom/sides, not top
                MapLibre3DView(service: service, camera: $camera)
                    .ignoresSafeArea(edges: [.bottom, .leading, .trailing])

                // Controls Overlay
                VStack {
                    Spacer()

                    controlsPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                }

                // Style picker sheet
                if showStylePicker {
                    stylePickerOverlay
                }
            }
            .navigationTitle("3D Terrain")
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
        .navigationViewStyle(.stack)
    }

    // MARK: - Controls Panel

    private var controlsPanel: some View {
        VStack(spacing: 16) {
            // 3D Toggle and Style
            HStack(spacing: 12) {
                // 3D Toggle Button
                Button(action: {
                    service.set3DMode(enabled: !service.is3DEnabled)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: service.is3DEnabled ? "view.3d" : "view.2d")
                            .font(.system(size: 16))
                        Text(service.is3DEnabled ? "3D" : "2D")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(service.is3DEnabled ? .black : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(service.is3DEnabled ? Color(hex: "#FFFC00") : Color(white: 0.2))
                    .cornerRadius(8)
                }

                // Style Button
                Button(action: { showStylePicker.toggle() }) {
                    HStack(spacing: 8) {
                        Image(systemName: service.currentStyle.icon)
                            .font(.system(size: 16))
                        Text(service.currentStyle.rawValue)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.2))
                    .cornerRadius(8)
                }

                Spacer()

                // Reset Camera
                Button(action: { service.resetCamera() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color(white: 0.2))
                        .cornerRadius(8)
                }
            }

            // Terrain Controls (only show when 3D enabled)
            if service.is3DEnabled {
                VStack(spacing: 12) {
                    // Pitch Control
                    controlRow(
                        label: "Tilt",
                        value: camera.pitch,
                        range: 0...85,
                        format: "%.0f°"
                    ) { newValue in
                        camera.pitch = newValue
                        service.setCameraPitch(newValue)
                    }

                    // Bearing Control
                    controlRow(
                        label: "Heading",
                        value: camera.bearing,
                        range: 0...360,
                        format: "%.0f°"
                    ) { newValue in
                        camera.bearing = newValue
                        service.setCameraBearing(newValue)
                    }

                    // Terrain Exaggeration
                    controlRow(
                        label: "Exaggeration",
                        value: service.terrainExaggeration,
                        range: 0.5...3.0,
                        format: "%.1fx"
                    ) { newValue in
                        service.setTerrainExaggeration(newValue)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
            }

            // Quick Actions
            HStack(spacing: 12) {
                quickActionButton(icon: "arrow.up.left.and.arrow.down.right", label: "Fit") {
                    // Fit to markers
                }

                quickActionButton(icon: "location.fill", label: "My Location") {
                    // Center on user location
                }

                quickActionButton(icon: "mountain.2.fill", label: "Ground") {
                    camera.pitch = 75
                    service.setCameraPitch(75)
                }

                quickActionButton(icon: "airplane", label: "Flyover") {
                    // Start flyover demo
                    startDemoFlyover()
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.7))
        .cornerRadius(16)
    }

    // MARK: - Control Row

    private func controlRow(
        label: String,
        value: Double,
        range: ClosedRange<Double>,
        format: String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)

            Slider(value: Binding(
                get: { value },
                set: { onChange($0) }
            ), in: range)
            .tint(Color(hex: "#FFFC00"))

            Text(String(format: format, value))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "#FFFC00"))
                .frame(width: 50, alignment: .trailing)
        }
    }

    // MARK: - Quick Action Button

    private func quickActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(white: 0.15))
            .cornerRadius(8)
        }
    }

    // MARK: - Style Picker Overlay

    private var stylePickerOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 0) {
                HStack {
                    Text("Map Style")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { showStylePicker = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                .padding()

                Divider()
                    .background(Color.gray.opacity(0.3))

                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(MapLibreStyle.allCases) { style in
                            styleButton(style)
                        }
                    }
                    .padding()
                }
                .frame(height: 200)
            }
            .background(Color(white: 0.1))
            .cornerRadius(16)
            .padding()
        }
        .background(Color.black.opacity(0.5))
        .onTapGesture {
            showStylePicker = false
        }
    }

    private func styleButton(_ style: MapLibreStyle) -> some View {
        Button(action: {
            service.setStyle(style)
            showStylePicker = false
        }) {
            VStack(spacing: 8) {
                Image(systemName: style.icon)
                    .font(.system(size: 28))
                    .foregroundColor(service.currentStyle == style ? Color(hex: "#FFFC00") : .white)

                Text(style.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(service.currentStyle == style ? Color(hex: "#FFFC00") : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(service.currentStyle == style ? Color(hex: "#FFFC00").opacity(0.2) : Color(white: 0.15))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(service.currentStyle == style ? Color(hex: "#FFFC00") : Color.clear, lineWidth: 2)
            )
        }
    }

    // MARK: - Demo Flyover

    private func startDemoFlyover() {
        // Demo route around Washington DC monuments
        let demoRoute: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 38.8893, longitude: -77.0502), // Lincoln Memorial
            CLLocationCoordinate2D(latitude: 38.8895, longitude: -77.0353), // Washington Monument
            CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365), // White House
            CLLocationCoordinate2D(latitude: 38.8899, longitude: -77.0091), // Capitol
            CLLocationCoordinate2D(latitude: 38.8814, longitude: -77.0365), // Jefferson Memorial
        ]

        service.startFlyover(along: demoRoute, altitude: 300, duration: 20)
    }
}

// MARK: - Compact 3D Toggle (for main map)

struct MapLibre3DToggle: View {
    @ObservedObject var service: MapLibreService
    @Binding var showFullSettings: Bool

    var body: some View {
        HStack(spacing: 8) {
            // 3D Toggle
            Button(action: {
                service.set3DMode(enabled: !service.is3DEnabled)
            }) {
                Image(systemName: service.is3DEnabled ? "view.3d" : "view.2d")
                    .font(.system(size: 16))
                    .foregroundColor(service.is3DEnabled ? .black : .white)
                    .frame(width: 36, height: 36)
                    .background(service.is3DEnabled ? Color(hex: "#FFFC00") : Color.black.opacity(0.7))
                    .cornerRadius(8)
            }

            // Settings
            Button(action: { showFullSettings = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

struct MapLibre3DSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MapLibre3DSettingsView(service: MapLibreService())
    }
}
