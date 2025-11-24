//
//  SPOTREPView.swift
//  OmniTAKMobile
//
//  Quick-fill SPOTREP (Spot Report) Form Interface
//

import SwiftUI
import CoreLocation

struct SPOTREPView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager()

    // Form data
    @State private var unitIdentification = ""
    @State private var enemyUnitSize: EnemyUnitSize = .unknown
    @State private var activityObserved: ActivityType = .unknown
    @State private var locationGrid = ""
    @State private var uniformDescription = ""
    @State private var timeOfObservation = Date()
    @State private var equipmentObserved = ""
    @State private var remarks = ""

    @State private var currentLocation: CLLocationCoordinate2D?
    @State private var showPreview = false
    @State private var showCopiedAlert = false
    @State private var showSentAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Header Banner
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundColor(Color(hex: "#FFFC00"))
                            Text("SPOTREP - SPOT REPORT")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "#FFFC00"))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#FFFC00").opacity(0.2))
                        .cornerRadius(8)

                        // Quick Size Selection
                        sizeQuickSelect

                        // Quick Activity Selection
                        activityQuickSelect

                        // Location Section
                        locationSection

                        // Unit Identification
                        unitIdSection

                        // Uniforms/ID
                        uniformSection

                        // Equipment
                        equipmentSection

                        // Time of Observation
                        timeSection

                        // Remarks
                        remarksSection

                        // Action Buttons
                        actionButtons
                    }
                    .padding()
                }
            }
            .navigationTitle("SPOTREP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .sheet(isPresented: $showPreview) {
                SPOTREPPreviewView(report: createReport())
            }
            .alert("Copied to Clipboard", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("SPOTREP copied to clipboard")
            }
            .alert("SPOTREP Sent", isPresented: $showSentAlert) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("SPOTREP transmitted via CoT")
            }
            .onAppear {
                locationManager.startUpdating()
            }
        }
    }

    // MARK: - Quick Size Selection

    private var sizeQuickSelect: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ENEMY SIZE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            // Common sizes as quick buttons
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach([EnemyUnitSize.individual, .team, .squad, .platoon, .company, .battalion, .unknown], id: \.self) { size in
                    Button(action: { enemyUnitSize = size }) {
                        Text(size.shortName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(enemyUnitSize == size ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(enemyUnitSize == size ? Color(hex: "#FFFC00") : Color(hex: "#333333"))
                            .cornerRadius(6)
                    }
                }
            }

            // Current selection display
            Text("Selected: \(enemyUnitSize.displayName)")
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Quick Activity Selection

    private var activityQuickSelect: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIVITY")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            // Common activities as quick buttons
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach([ActivityType.attacking, .defending, .moving, .stationary, .patrolling, .reconnoitering], id: \.self) { activity in
                    Button(action: { activityObserved = activity }) {
                        Text(activity.shortName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(activityObserved == activity ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(activityObserved == activity ? Color(hex: "#FFFC00") : Color(hex: "#333333"))
                            .cornerRadius(6)
                    }
                }
            }

            // Current selection display
            Text("Selected: \(activityObserved.displayName)")
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOCATION (Grid Coordinates)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            TextField("MGRS or Lat/Lon", text: $locationGrid)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.allCharacters)

            Button(action: useCurrentLocation) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("Use Current Location")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#FFFC00"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(hex: "#333333"))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Unit ID Section

    private var unitIdSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UNIT IDENTIFICATION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            TextField("Unit name, markings, insignia", text: $unitIdentification)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Uniform Section

    private var uniformSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UNIFORMS/IDENTIFICATION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            TextField("Uniform color, type, distinctive features", text: $uniformDescription)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Equipment Section

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EQUIPMENT OBSERVED")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            TextEditor(text: $equipmentObserved)
                .frame(height: 60)
                .padding(4)
                .background(Color(hex: "#333333"))
                .cornerRadius(8)
                .foregroundColor(.white)

            Text("Weapons, vehicles, radios, etc.")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TIME OF OBSERVATION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            DatePicker("", selection: $timeOfObservation)
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
                .accentColor(Color(hex: "#FFFC00"))

            let formatter = DateFormatter()
            let _ = formatter.dateFormat = "ddHHmmZMMMyy"
            let _ = formatter.timeZone = TimeZone(identifier: "UTC")

            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                Text(formatter.string(from: timeOfObservation).uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Remarks Section

    private var remarksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ASSESSMENT/REMARKS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            TextEditor(text: $remarks)
                .frame(height: 60)
                .padding(4)
                .background(Color(hex: "#333333"))
                .cornerRadius(8)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { showPreview = true }) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Preview Report")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "#333333"))
                .cornerRadius(10)
            }

            Button(action: sendReport) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("SEND SPOTREP")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "#FFFC00"))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Actions

    private func useCurrentLocation() {
        if let location = locationManager.location {
            currentLocation = location.coordinate
            locationGrid = String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
        }
    }

    private func createReport() -> SPOTREPReport {
        SPOTREPReport(
            dateTimeGroup: Date(),
            unitIdentification: unitIdentification,
            enemyUnitSize: enemyUnitSize,
            activityObserved: activityObserved,
            locationGrid: locationGrid,
            locationLat: currentLocation?.latitude,
            locationLon: currentLocation?.longitude,
            uniformDescription: uniformDescription,
            timeOfObservation: timeOfObservation,
            equipmentObserved: equipmentObserved,
            remarks: remarks,
            senderUID: PositionBroadcastService.shared.userUID,
            senderCallsign: PositionBroadcastService.shared.userCallsign
        )
    }

    private func sendReport() {
        let report = createReport()

        // Copy to clipboard
        UIPasteboard.general.string = report.formattedReportText

        // Generate and send CoT
        let cotXML = generateSPOTREPCoT(report: report)
        print("Generated SPOTREP CoT: \(cotXML)")

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        showSentAlert = true
    }

    private func generateSPOTREPCoT(report: SPOTREPReport) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(3600)

        let timeStr = dateFormatter.string(from: now)
        let staleStr = dateFormatter.string(from: stale)

        let uid = "SPOTREP-\(report.id)"
        let lat = report.locationLat ?? 0.0
        let lon = report.locationLon ?? 0.0

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="b-r-f-h-c" time="\(timeStr)" start="\(timeStr)" stale="\(staleStr)" how="h-g-i-g-o">
            <point lat="\(lat)" lon="\(lon)" hae="0.0" ce="9999999" le="9999999"/>
            <detail>
                <contact callsign="\(escapeXML(report.senderCallsign))"/>
                <spotrep>
                    <dtg>\(report.formattedDTG)</dtg>
                    <unitId>\(escapeXML(report.unitIdentification))</unitId>
                    <size>\(report.enemyUnitSize.code)</size>
                    <activity>\(report.activityObserved.code)</activity>
                    <location>\(escapeXML(report.locationGrid))</location>
                    <uniform>\(escapeXML(report.uniformDescription))</uniform>
                    <timeObserved>\(report.formattedObservationTime)</timeObserved>
                    <equipment>\(escapeXML(report.equipmentObserved))</equipment>
                </spotrep>
                <remarks>\(escapeXML(report.remarks))</remarks>
            </detail>
        </event>
        """
    }

    private func escapeXML(_ string: String) -> String {
        var escaped = string
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
}

// MARK: - SPOTREP Preview View

struct SPOTREPPreviewView: View {
    @Environment(\.dismiss) var dismiss
    let report: SPOTREPReport

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(report.formattedReportText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .padding()
                    }
                    .background(Color(hex: "#2A2A2A"))
                    .cornerRadius(12)
                    .padding()
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        UIPasteboard.general.string = report.formattedReportText
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SPOTREPView()
}
