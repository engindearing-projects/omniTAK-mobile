//
//  MeasurementToolView.swift
//  OmniTAKMobile
//
//  SwiftUI panel for measurement tool selection and results display
//

import SwiftUI
import CoreLocation

// MARK: - Measurement Tool View

struct MeasurementToolView: View {
    @ObservedObject var manager: MeasurementManager
    @Binding var isPresented: Bool
    @State private var showingRangeRingConfig = false
    @State private var showingMeasurementsList = false
    @State private var copiedToClipboard = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Color(hex: "#333333"))

            ScrollView {
                VStack(spacing: 16) {
                    // Tool Selection
                    toolSelectionView

                    // Active Measurement Controls
                    if manager.isActive {
                        activeMeasurementView
                    }

                    // Live Results
                    if manager.isActive && hasResults {
                        liveResultsView
                    }

                    // Saved Measurements
                    if !manager.savedMeasurements.isEmpty || !manager.rangeRings.isEmpty {
                        savedMeasurementsSection
                    }
                }
                .padding(16)
            }
        }
        .background(Color(hex: "#1E1E1E"))
        .cornerRadius(16)
        .sheet(isPresented: $showingRangeRingConfig) {
            RangeRingConfigView(manager: manager)
        }
        .sheet(isPresented: $showingMeasurementsList) {
            MeasurementListView(manager: manager)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Image(systemName: "ruler")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#FFFC00"))

            Text("Measurement Tools")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#666666"))
            }
        }
        .padding(16)
    }

    // MARK: - Tool Selection View

    private var toolSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SELECT TOOL")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#888888"))

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(MeasurementType.allCases, id: \.self) { type in
                    toolButton(for: type)
                }
            }
        }
    }

    private func toolButton(for type: MeasurementType) -> some View {
        let isSelected = manager.currentMeasurementType == type && manager.isActive

        return Button(action: {
            if isSelected {
                manager.cancelMeasurement()
            } else {
                manager.startMeasurement(type: type)
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? Color(hex: "#1E1E1E") : Color(hex: "#FFFC00"))

                Text(type.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "#1E1E1E") : .white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color(hex: "#FFFC00") : Color(hex: "#2A2A2A"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color(hex: "#333333"), lineWidth: 1)
            )
        }
    }

    // MARK: - Active Measurement View

    private var activeMeasurementView: some View {
        VStack(spacing: 12) {
            // Instructions
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Color(hex: "#FFFC00"))

                Text(manager.getInstructions())
                    .font(.system(size: 14))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(12)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)

            // Control Buttons
            HStack(spacing: 12) {
                // Undo Button
                if !manager.temporaryPoints.isEmpty {
                    Button(action: { manager.undoLastPoint() }) {
                        HStack {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#444444"))
                        .cornerRadius(8)
                    }
                }

                // Complete Button
                if manager.canComplete() {
                    Button(action: { manager.completeMeasurement() }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Complete")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#1E1E1E"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#FFFC00"))
                        .cornerRadius(8)
                    }
                }

                // Cancel Button
                Button(action: { manager.cancelMeasurement() }) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Cancel")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#FF4444"))
                    .cornerRadius(8)
                }
            }

            // Range Ring Config Button
            if manager.currentMeasurementType == .rangeRing {
                Button(action: { showingRangeRingConfig = true }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Configure Distances")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#2A2A2A"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#FFFC00"), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Live Results View

    private var liveResultsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("LIVE RESULTS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#888888"))

                Spacer()

                Button(action: copyResults) {
                    HStack(spacing: 4) {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                        Text(copiedToClipboard ? "Copied" : "Copy")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }

            VStack(spacing: 8) {
                if let type = manager.currentMeasurementType {
                    switch type {
                    case .distance:
                        distanceResultsView

                    case .bearing:
                        bearingResultsView

                    case .area:
                        areaResultsView

                    case .rangeRing:
                        rangeRingResultsView
                    }
                }
            }
            .padding(12)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)
        }
    }

    private var distanceResultsView: some View {
        VStack(spacing: 6) {
            if let meters = manager.liveResult.distanceMeters {
                resultRow(label: "Distance", value: MeasurementCalculator.formatDistance(meters))
                resultRow(label: "Miles", value: String(format: "%.3f mi", manager.liveResult.distanceMiles ?? 0))
                resultRow(label: "Nautical Miles", value: String(format: "%.3f NM", manager.liveResult.distanceNauticalMiles ?? 0))
                resultRow(label: "Feet", value: String(format: "%.1f ft", manager.liveResult.distanceFeet ?? 0))
            }

            if let segments = manager.liveResult.segmentDistances, segments.count > 1 {
                Divider()
                    .background(Color(hex: "#444444"))

                Text("Segments: \(segments.count)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#888888"))
            }
        }
    }

    private var bearingResultsView: some View {
        VStack(spacing: 6) {
            if let degrees = manager.liveResult.bearingDegrees {
                resultRow(label: "Bearing", value: MeasurementCalculator.formatBearing(degrees))
                resultRow(label: "Mils (NATO)", value: String(format: "%.0f mil", manager.liveResult.bearingMils ?? 0))
                resultRow(label: "Back Bearing", value: String(format: "%.1f\u{00B0}", manager.liveResult.backBearingDegrees ?? 0))
            }

            if let meters = manager.liveResult.distanceMeters {
                Divider()
                    .background(Color(hex: "#444444"))

                resultRow(label: "Distance", value: MeasurementCalculator.formatDistance(meters))
            }
        }
    }

    private var areaResultsView: some View {
        VStack(spacing: 6) {
            if let sqMeters = manager.liveResult.areaSquareMeters {
                resultRow(label: "Area", value: MeasurementCalculator.formatArea(sqMeters))
                resultRow(label: "Acres", value: String(format: "%.3f ac", manager.liveResult.areaAcres ?? 0))
                resultRow(label: "Hectares", value: String(format: "%.3f ha", manager.liveResult.areaHectares ?? 0))
                resultRow(label: "Square Miles", value: String(format: "%.6f mi\u{00B2}", manager.liveResult.areaSquareMiles ?? 0))
            }

            if let perimeter = manager.liveResult.perimeterMeters {
                Divider()
                    .background(Color(hex: "#444444"))

                resultRow(label: "Perimeter", value: MeasurementCalculator.formatDistance(perimeter))
            }
        }
    }

    private var rangeRingResultsView: some View {
        VStack(spacing: 6) {
            if let center = manager.temporaryPoints.first {
                Text("Center: \(String(format: "%.6f, %.6f", center.latitude, center.longitude))")
                    .font(.system(size: 12))
                    .foregroundColor(.white)

                Divider()
                    .background(Color(hex: "#444444"))

                Text("Configured Rings:")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#888888"))

                ForEach(manager.rangeRingConfiguration.distances, id: \.self) { distance in
                    Text(MeasurementCalculator.formatDistance(distance))
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
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

    // MARK: - Saved Measurements Section

    private var savedMeasurementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SAVED")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#888888"))

                Spacer()

                Button(action: { showingMeasurementsList = true }) {
                    Text("View All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }

            VStack(spacing: 8) {
                if !manager.savedMeasurements.isEmpty {
                    Text("\(manager.savedMeasurements.count) Measurement(s)")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }

                if !manager.rangeRings.isEmpty {
                    Text("\(manager.rangeRings.count) Range Ring(s)")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }

                HStack(spacing: 12) {
                    if !manager.savedMeasurements.isEmpty {
                        Button(action: { manager.clearAllMeasurements() }) {
                            Text("Clear Measurements")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#FF4444"))
                                .cornerRadius(6)
                        }
                    }

                    if !manager.rangeRings.isEmpty {
                        Button(action: { manager.clearAllRangeRings() }) {
                            Text("Clear Rings")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#FF4444"))
                                .cornerRadius(6)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(8)
        }
    }

    // MARK: - Helper Properties

    private var hasResults: Bool {
        switch manager.currentMeasurementType {
        case .distance:
            return manager.liveResult.distanceMeters != nil

        case .bearing:
            return manager.liveResult.bearingDegrees != nil

        case .area:
            return manager.liveResult.areaSquareMeters != nil

        case .rangeRing:
            return !manager.temporaryPoints.isEmpty

        case .none:
            return false
        }
    }

    // MARK: - Actions

    private func copyResults() {
        let text = manager.copyResultToClipboard()
        UIPasteboard.general.string = text
        copiedToClipboard = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }
}

// MARK: - Measurement List View

struct MeasurementListView: View {
    @ObservedObject var manager: MeasurementManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                if !manager.savedMeasurements.isEmpty {
                    Section(header: Text("Measurements")) {
                        ForEach(manager.savedMeasurements) { measurement in
                            measurementRow(measurement)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                manager.removeMeasurement(manager.savedMeasurements[index])
                            }
                        }
                    }
                }

                if !manager.rangeRings.isEmpty {
                    Section(header: Text("Range Rings")) {
                        ForEach(manager.rangeRings) { ring in
                            rangeRingRow(ring)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                manager.removeRangeRing(manager.rangeRings[index])
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Saved Measurements")
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

    private func measurementRow(_ measurement: Measurement) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: measurement.type.icon)
                    .foregroundColor(.accentColor)

                Text(measurement.name)
                    .font(.headline)
            }

            switch measurement.type {
            case .distance:
                if let meters = measurement.result.distanceMeters {
                    Text(MeasurementCalculator.formatDistance(meters))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

            case .bearing:
                if let degrees = measurement.result.bearingDegrees {
                    Text(MeasurementCalculator.formatBearing(degrees))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

            case .area:
                if let area = measurement.result.areaSquareMeters {
                    Text(MeasurementCalculator.formatArea(area))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

            case .rangeRing:
                Text("Range Ring")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(measurement.createdAt, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func rangeRingRow(_ ring: RangeRing) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "circle.dashed")
                    .foregroundColor(.accentColor)

                Text(ring.label)
                    .font(.headline)
            }

            Text("Radius: \(MeasurementCalculator.formatDistance(ring.radiusMeters))")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Center: \(String(format: "%.4f, %.4f", ring.center.latitude, ring.center.longitude))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
