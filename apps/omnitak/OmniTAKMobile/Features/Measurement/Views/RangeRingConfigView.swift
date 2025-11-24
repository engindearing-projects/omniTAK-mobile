//
//  RangeRingConfigView.swift
//  OmniTAKMobile
//
//  Configuration panel for range ring distances and appearance
//

import SwiftUI

struct RangeRingConfigView: View {
    @ObservedObject var manager: MeasurementManager
    @Environment(\.dismiss) var dismiss

    @State private var newDistanceText: String = ""
    @State private var selectedUnit: DistanceUnit = .meters
    @State private var showingPresets = false

    // Preset distance options
    let presets: [(name: String, distances: [Double])] = [
        ("Close Range", [50, 100, 200, 500]),
        ("Medium Range", [100, 500, 1000, 2000]),
        ("Long Range", [500, 1000, 2000, 5000, 10000]),
        ("Tactical", [100, 300, 500, 1000, 2000]),
        ("Artillery", [1000, 2000, 5000, 10000, 20000])
    ]

    var body: some View {
        NavigationView {
            Form {
                // Current Distances Section
                Section(header: Text("CONFIGURED DISTANCES")) {
                    ForEach(manager.rangeRingConfiguration.distances, id: \.self) { distance in
                        HStack {
                            Text(formatDistance(distance))
                                .font(.system(size: 15))

                            Spacer()

                            Text(MeasurementCalculator.formatDistance(distance))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            let distance = manager.rangeRingConfiguration.distances[index]
                            manager.removeRangeRingDistance(distance)
                        }
                    }

                    if manager.rangeRingConfiguration.distances.isEmpty {
                        Text("No distances configured")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }

                // Add Custom Distance Section
                Section(header: Text("ADD CUSTOM DISTANCE")) {
                    HStack {
                        TextField("Distance", text: $newDistanceText)
                            .keyboardType(.decimalPad)

                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(DistanceUnit.allCases, id: \.self) { unit in
                                Text(unit.abbreviation).tag(unit)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 80)
                    }

                    Button(action: addCustomDistance) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Distance")
                        }
                    }
                    .disabled(newDistanceText.isEmpty)
                }

                // Presets Section
                Section(header: Text("PRESET CONFIGURATIONS")) {
                    ForEach(presets, id: \.name) { preset in
                        Button(action: { applyPreset(preset.distances) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)

                                Text(preset.distances.map { MeasurementCalculator.formatDistance($0) }.joined(separator: ", "))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }

                // Appearance Section
                Section(header: Text("APPEARANCE")) {
                    HStack {
                        Text("Line Width")
                        Spacer()
                        Text(String(format: "%.1f pt", manager.rangeRingConfiguration.lineWidth))
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(manager.rangeRingConfiguration.lineWidth) },
                            set: { updateLineWidth(CGFloat($0)) }
                        ),
                        in: 1...5,
                        step: 0.5
                    )

                    Toggle("Show Labels", isOn: Binding(
                        get: { manager.rangeRingConfiguration.showLabels },
                        set: { updateShowLabels($0) }
                    ))

                    Toggle("Dashed Lines", isOn: Binding(
                        get: { manager.rangeRingConfiguration.lineDashPattern != nil },
                        set: { updateDashedLines($0) }
                    ))
                }

                // Quick Actions Section
                Section {
                    Button(action: resetToDefault) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Default")
                        }
                    }

                    Button(action: clearAllDistances) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Distances")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Range Ring Config")
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

    // MARK: - Helper Methods

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000.0)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    private func addCustomDistance() {
        guard let value = Double(newDistanceText) else { return }

        // Convert to meters
        let distanceInMeters: Double
        switch selectedUnit {
        case .meters:
            distanceInMeters = value
        case .kilometers:
            distanceInMeters = value * 1000.0
        case .feet:
            distanceInMeters = value / 3.28084
        case .miles:
            distanceInMeters = value * 1609.344
        case .nauticalMiles:
            distanceInMeters = value * 1852.0
        case .yards:
            distanceInMeters = value / 1.09361
        }

        manager.addCustomRangeRingDistance(distanceInMeters)
        newDistanceText = ""
    }

    private func applyPreset(_ distances: [Double]) {
        var config = manager.rangeRingConfiguration
        config.distances = distances
        manager.updateRangeRingConfiguration(config)
    }

    private func updateLineWidth(_ width: CGFloat) {
        var config = manager.rangeRingConfiguration
        config.lineWidth = width
        manager.updateRangeRingConfiguration(config)
    }

    private func updateShowLabels(_ show: Bool) {
        var config = manager.rangeRingConfiguration
        config.showLabels = show
        manager.updateRangeRingConfiguration(config)
    }

    private func updateDashedLines(_ dashed: Bool) {
        var config = manager.rangeRingConfiguration
        config.lineDashPattern = dashed ? [5, 5] : nil
        manager.updateRangeRingConfiguration(config)
    }

    private func resetToDefault() {
        manager.updateRangeRingConfiguration(.defaultConfiguration())
    }

    private func clearAllDistances() {
        var config = manager.rangeRingConfiguration
        config.distances = []
        manager.updateRangeRingConfiguration(config)
    }
}

// MARK: - Range Ring Quick Select View

struct RangeRingQuickSelectView: View {
    @ObservedObject var manager: MeasurementManager
    let onSelect: () -> Void

    let quickDistances: [Double] = [100, 250, 500, 1000, 2000, 5000]

    var body: some View {
        VStack(spacing: 12) {
            Text("Quick Add Distances")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(quickDistances, id: \.self) { distance in
                    Button(action: {
                        manager.addCustomRangeRingDistance(distance)
                    }) {
                        Text(MeasurementCalculator.formatDistance(distance))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSelected(distance) ? Color(hex: "#1E1E1E") : Color(hex: "#FFFC00"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected(distance) ? Color(hex: "#FFFC00") : Color(hex: "#2A2A2A"))
                            .cornerRadius(6)
                    }
                }
            }

            Button(action: onSelect) {
                Text("Confirm")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#1E1E1E"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#FFFC00"))
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(hex: "#1E1E1E"))
        .cornerRadius(12)
    }

    private func isSelected(_ distance: Double) -> Bool {
        manager.rangeRingConfiguration.distances.contains(distance)
    }
}
