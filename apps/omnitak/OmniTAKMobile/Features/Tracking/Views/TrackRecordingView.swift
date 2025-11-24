//
//  TrackRecordingView.swift
//  OmniTAKMobile
//
//  SwiftUI control panel for GPS track recording
//

import SwiftUI
import CoreLocation

// MARK: - Track Recording View

struct TrackRecordingView: View {
    @ObservedObject var recordingService: TrackRecordingService
    @State private var showingNameDialog = false
    @State private var showingDiscardAlert = false
    @State private var trackName = ""
    @State private var selectedColor = "#FF0000"
    @State private var showingColorPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Recording indicator
            if recordingService.isRecording {
                recordingIndicator
            }

            // Live statistics
            if recordingService.isRecording || recordingService.currentTrack != nil {
                liveStatisticsView
            }

            // Control buttons
            controlButtonsView

            // Configuration section
            if !recordingService.isRecording {
                configurationSection
            }
        }
        .background(Color(hex: "#1E1E1E"))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 10)
        .alert("Name Your Track", isPresented: $showingNameDialog) {
            TextField("Track Name", text: $trackName)
            Button("Start Recording") {
                startRecordingWithName()
            }
            Button("Cancel", role: .cancel) {
                trackName = ""
            }
        } message: {
            Text("Enter a name for your track or leave blank for automatic naming.")
        }
        .alert("Discard Recording?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                recordingService.discardRecording()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently discard the current recording.")
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Image(systemName: "location.north.line.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#FFFC00"))

            Text("Track Recording")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            if recordingService.isRecording {
                Text(recordingService.formattedElapsedTime)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#FFFC00"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#2A2A2A"))
    }

    // MARK: - Recording Indicator

    private var recordingIndicator: some View {
        HStack {
            Circle()
                .fill(recordingService.isPaused ? Color.orange : Color.red)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .scaleEffect(recordingService.isPaused ? 1 : 1.5)
                        .opacity(recordingService.isPaused ? 0 : 0.5)
                        .animation(
                            recordingService.isPaused ? .none :
                            Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: recordingService.isRecording
                        )
                )

            Text(recordingService.isPaused ? "PAUSED" : "RECORDING")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(recordingService.isPaused ? .orange : .red)

            Spacer()

            Text("\(recordingService.livePointCount) points")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#CCCCCC"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: "#2A2A2A").opacity(0.8))
    }

    // MARK: - Live Statistics View

    private var liveStatisticsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                StatisticItem(
                    icon: "ruler",
                    label: "Distance",
                    value: recordingService.formattedLiveDistance
                )

                StatisticItem(
                    icon: "speedometer",
                    label: "Speed",
                    value: recordingService.formattedLiveSpeed
                )
            }

            HStack(spacing: 20) {
                StatisticItem(
                    icon: "gauge",
                    label: "Avg Speed",
                    value: recordingService.formattedLiveAverageSpeed
                )

                StatisticItem(
                    icon: "arrow.up.right",
                    label: "Elevation",
                    value: String(format: "+%.0f m", recordingService.liveElevationGain)
                )
            }
        }
        .padding(16)
    }

    // MARK: - Control Buttons View

    private var controlButtonsView: some View {
        VStack(spacing: 12) {
            if recordingService.isRecording {
                // Recording controls
                HStack(spacing: 12) {
                    // Pause/Resume button
                    Button(action: {
                        if recordingService.isPaused {
                            recordingService.resumeRecording()
                        } else {
                            recordingService.pauseRecording()
                        }
                    }) {
                        HStack {
                            Image(systemName: recordingService.isPaused ? "play.fill" : "pause.fill")
                            Text(recordingService.isPaused ? "Resume" : "Pause")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(8)
                    }

                    // Stop button
                    Button(action: {
                        _ = recordingService.stopRecording()
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(8)
                    }
                }

                // Discard button
                Button(action: {
                    showingDiscardAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Discard")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(8)
                }
            } else {
                // Start recording button
                Button(action: {
                    showingNameDialog = true
                }) {
                    HStack {
                        Image(systemName: "record.circle")
                        Text("Start Recording")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#FFFC00"))
                    .cornerRadius(8)
                }

                // Quick start button (auto-named)
                Button(action: {
                    recordingService.startRecording(color: selectedColor)
                }) {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Quick Start")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#FFFC00").opacity(0.15))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Configuration Section

    private var configurationSection: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color(hex: "#3A3A3A"))

            // Color picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Track Color")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#CCCCCC"))

                TrackColorPicker(selectedColor: $selectedColor)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Helper Methods

    private func startRecordingWithName() {
        let name = trackName.isEmpty ? "" : trackName
        recordingService.startRecording(name: name, color: selectedColor)
        trackName = ""
    }
}

// MARK: - Statistic Item Component

struct StatisticItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#FFFC00"))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#888888"))

                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compact Recording Panel

struct CompactRecordingPanel: View {
    @ObservedObject var recordingService: TrackRecordingService

    var body: some View {
        HStack(spacing: 12) {
            // Recording indicator
            Circle()
                .fill(recordingService.isPaused ? Color.orange : Color.red)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .scaleEffect(recordingService.isPaused ? 1 : 1.5)
                        .opacity(recordingService.isPaused ? 0 : 0.5)
                        .animation(
                            recordingService.isPaused ? .none :
                            Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: recordingService.isRecording
                        )
                )

            // Time
            Text(recordingService.formattedElapsedTime)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)

            Divider()
                .frame(height: 20)

            // Distance
            HStack(spacing: 4) {
                Image(systemName: "ruler")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FFFC00"))
                Text(recordingService.formattedLiveDistance)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }

            Divider()
                .frame(height: 20)

            // Speed
            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#FFFC00"))
                Text(recordingService.formattedLiveSpeed)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "#1E1E1E").opacity(0.95))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 8)
    }
}

// MARK: - Recording Configuration View

struct TrackRecordingConfigurationView: View {
    @ObservedObject var recordingService: TrackRecordingService
    @State private var distanceThreshold: Double = 5.0
    @State private var accuracyMode: TrackRecordingConfiguration.AccuracyMode = .best
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Distance Threshold")) {
                    VStack(alignment: .leading) {
                        Text("Minimum distance: \(Int(distanceThreshold)) meters")
                        Slider(value: $distanceThreshold, in: 1...50, step: 1)
                    }
                }

                Section(header: Text("Location Accuracy")) {
                    Picker("Accuracy Mode", selection: $accuracyMode) {
                        Text("Best Accuracy").tag(TrackRecordingConfiguration.AccuracyMode.best)
                        Text("10m Accuracy").tag(TrackRecordingConfiguration.AccuracyMode.tenMeters)
                        Text("100m Accuracy").tag(TrackRecordingConfiguration.AccuracyMode.hundredMeters)
                        Text("Navigation Mode").tag(TrackRecordingConfiguration.AccuracyMode.navigation)
                    }
                }

                Section(footer: Text("Higher accuracy uses more battery. Lower distance threshold records more points but increases file size.")) {
                    Button("Apply Settings") {
                        recordingService.setMinimumDistanceThreshold(distanceThreshold)
                        recordingService.setAccuracyMode(accuracyMode)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Recording Settings")
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

// MARK: - Preview

struct TrackRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        TrackRecordingView(recordingService: TrackRecordingService.shared)
            .frame(width: 350)
            .previewLayout(.sizeThatFits)
            .background(Color.gray.opacity(0.3))
    }
}
