//
//  SignalHistoryView.swift
//  OmniTAK Mobile
//
//  Beautiful real-time signal strength monitoring and history
//

import SwiftUI
import Charts

struct SignalHistoryView: View {
    @ObservedObject var manager: MeshtasticManager
    @Environment(\.dismiss) var dismiss

    @State private var timeRange: TimeRange = .last5Minutes
    @State private var showingSNR = false

    enum TimeRange: String, CaseIterable {
        case last1Minute = "1m"
        case last5Minutes = "5m"
        case last15Minutes = "15m"
        case last30Minutes = "30m"
        case last1Hour = "1h"

        var seconds: TimeInterval {
            switch self {
            case .last1Minute: return 60
            case .last5Minutes: return 300
            case .last15Minutes: return 900
            case .last30Minutes: return 1800
            case .last1Hour: return 3600
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Signal Card
                    currentSignalCard

                    // Time Range Picker
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Signal Strength Chart
                    signalStrengthChart

                    // Signal Quality Distribution
                    signalQualityDistribution

                    // Statistics Summary
                    statisticsSummary
                }
                .padding(.vertical)
            }
            .navigationTitle("Signal History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle(isOn: $showingSNR) {
                        Image(systemName: "waveform.path.ecg")
                    }
                }
            }
        }
    }

    // MARK: - Current Signal Card

    private var currentSignalCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Signal")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if let device = manager.connectedDevice,
                       let rssi = device.signalStrength {
                        Text("\(rssi) dBm")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(Color(manager.signalQuality.color))
                    } else {
                        Text("--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                    }

                    Text(manager.signalQuality.displayText)
                        .font(.caption)
                        .foregroundColor(Color(manager.signalQuality.color))
                }

                Spacer()

                // Signal strength visual indicator
                SignalStrengthGauge(quality: manager.signalQuality)
            }

            if let device = manager.connectedDevice,
               let snr = device.snr {
                Divider()

                HStack {
                    VStack(alignment: .leading) {
                        Text("SNR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f dB", snr))
                            .font(.title3)
                            .bold()
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("Hop Count")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(device.hopCount ?? 0)")
                            .font(.title3)
                            .bold()
                    }

                    Spacer()

                    if let battery = device.batteryLevel {
                        VStack(alignment: .leading) {
                            Text("Battery")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(battery)%")
                                .font(.title3)
                                .bold()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }

    // MARK: - Signal Strength Chart

    private var signalStrengthChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(showingSNR ? "SNR History" : "RSSI History")
                .font(.headline)
                .padding(.horizontal)

            Chart(filteredReadings) { reading in
                if showingSNR {
                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("SNR", reading.snr)
                    )
                    .foregroundStyle(Color.blue)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("SNR", reading.snr)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                } else {
                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("RSSI", reading.rssi)
                    )
                    .foregroundStyle(colorForRSSI(reading.rssi))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("RSSI", reading.rssi)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [colorForRSSI(reading.rssi).opacity(0.3), colorForRSSI(reading.rssi).opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(formatTime(date))
                                .font(.caption2)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Signal Quality Distribution

    private var signalQualityDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Signal Quality Distribution")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 12) {
                ForEach([SignalQuality.excellent, .good, .fair, .poor], id: \.self) { quality in
                    VStack(spacing: 8) {
                        let percentage = qualityPercentage(for: quality)

                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                            Circle()
                                .trim(from: 0, to: percentage / 100)
                                .stroke(
                                    Color(quality.color),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))

                            Text("\(Int(percentage))%")
                                .font(.caption)
                                .bold()
                        }
                        .frame(width: 60, height: 60)

                        Text(quality.displayText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Statistics Summary

    private var statisticsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Average RSSI",
                    value: String(format: "%.0f dBm", averageRSSI),
                    icon: "waveform"
                )

                StatCard(
                    title: "Peak RSSI",
                    value: String(format: "%.0f dBm", peakRSSI),
                    icon: "arrow.up.circle.fill"
                )

                StatCard(
                    title: "Lowest RSSI",
                    value: String(format: "%.0f dBm", lowestRSSI),
                    icon: "arrow.down.circle.fill"
                )

                StatCard(
                    title: "Readings",
                    value: "\(filteredReadings.count)",
                    icon: "chart.line.uptrend.xyaxis"
                )

                if showingSNR {
                    StatCard(
                        title: "Avg SNR",
                        value: String(format: "%.1f dB", averageSNR),
                        icon: "waveform.path.ecg"
                    )

                    StatCard(
                        title: "Peak SNR",
                        value: String(format: "%.1f dB", peakSNR),
                        icon: "arrow.up.circle.fill"
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Helper Functions

    private var filteredReadings: [SignalStrengthReading] {
        let cutoff = Date().addingTimeInterval(-timeRange.seconds)
        return manager.signalHistory.filter { $0.timestamp >= cutoff }
    }

    private func colorForRSSI(_ rssi: Int) -> Color {
        return Color(SignalQuality.from(rssi: rssi).color)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func qualityPercentage(for quality: SignalQuality) -> Double {
        let total = Double(filteredReadings.count)
        guard total > 0 else { return 0 }

        let count = Double(filteredReadings.filter { SignalQuality.from(rssi: $0.rssi) == quality }.count)
        return (count / total) * 100
    }

    private var averageRSSI: Double {
        guard !filteredReadings.isEmpty else { return 0 }
        let sum = filteredReadings.map { Double($0.rssi) }.reduce(0, +)
        return sum / Double(filteredReadings.count)
    }

    private var peakRSSI: Double {
        guard !filteredReadings.isEmpty else { return 0 }
        return Double(filteredReadings.map { $0.rssi }.max() ?? 0)
    }

    private var lowestRSSI: Double {
        guard !filteredReadings.isEmpty else { return 0 }
        return Double(filteredReadings.map { $0.rssi }.min() ?? 0)
    }

    private var averageSNR: Double {
        guard !filteredReadings.isEmpty else { return 0 }
        let sum = filteredReadings.map { $0.snr }.reduce(0, +)
        return sum / Double(filteredReadings.count)
    }

    private var peakSNR: Double {
        guard !filteredReadings.isEmpty else { return 0 }
        return filteredReadings.map { $0.snr }.max() ?? 0
    }
}

// MARK: - Signal Strength Gauge

struct SignalStrengthGauge: View {
    let quality: SignalQuality

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                .frame(width: 100, height: 100)

            Circle()
                .trim(from: 0, to: qualityPercentage)
                .stroke(
                    AngularGradient(
                        colors: [.red, .orange, .yellow, .green],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))

            Image(systemName: quality.iconName)
                .font(.title)
                .foregroundColor(Color(quality.color))
        }
    }

    private var qualityPercentage: CGFloat {
        switch quality {
        case .excellent: return 1.0
        case .good: return 0.75
        case .fair: return 0.5
        case .poor: return 0.25
        case .none: return 0.0
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title3)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

// MARK: - Preview

struct SignalHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        SignalHistoryView(manager: MeshtasticManager())
    }
}
