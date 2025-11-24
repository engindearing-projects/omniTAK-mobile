//
//  MEDEVACRequestView.swift
//  OmniTAKMobile
//
//  9-Line MEDEVAC Request Form Interface
//

import SwiftUI
import CoreLocation

struct MEDEVACRequestView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager()

    // Form data
    @State private var locationGrid = ""
    @State private var radioFrequency = ""
    @State private var callSign = ""
    @State private var callSignSuffix = ""

    @State private var urgentPatients = 0
    @State private var priorityPatients = 0
    @State private var routinePatients = 0
    @State private var conveniencePatients = 0

    @State private var specialEquipment: SpecialEquipment = .none
    @State private var litterPatients = 0
    @State private var ambulatoryPatients = 0
    @State private var pickupSiteSecurity: PickupSiteSecurity = .noEnemy
    @State private var markingMethod: MarkingMethod = .none
    @State private var patientNationality: PatientNationality = .usMilitary
    @State private var cbrnContamination: CBRNContamination = .none
    @State private var remarks = ""

    @State private var showPreview = false
    @State private var showCopiedAlert = false
    @State private var currentLocation: CLLocationCoordinate2D?

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Warning Banner
                        HStack {
                            Image(systemName: "cross.case.fill")
                                .foregroundColor(.red)
                            Text("9-LINE MEDEVAC REQUEST")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(8)

                        // Line 1 - Location
                        FormSection(title: "LINE 1 - LOCATION", lineNumber: "1") {
                            VStack(spacing: 12) {
                                TextField("Grid Coordinates (MGRS)", text: $locationGrid)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.allCharacters)

                                Button(action: useCurrentLocation) {
                                    HStack {
                                        Image(systemName: "location.fill")
                                        Text("Use Current Location")
                                    }
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#FFFC00"))
                                }
                            }
                        }

                        // Line 2 - Radio frequency and callsign
                        FormSection(title: "LINE 2 - FREQUENCY/CALLSIGN", lineNumber: "2") {
                            VStack(spacing: 12) {
                                TextField("Radio Frequency", text: $radioFrequency)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.decimalPad)

                                HStack(spacing: 8) {
                                    TextField("Call Sign", text: $callSign)
                                        .textFieldStyle(.roundedBorder)
                                        .autocapitalization(.allCharacters)

                                    TextField("Suffix", text: $callSignSuffix)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                        .autocapitalization(.allCharacters)
                                }
                            }
                        }

                        // Line 3 - Patients by precedence
                        FormSection(title: "LINE 3 - PATIENTS BY PRECEDENCE", lineNumber: "3") {
                            VStack(spacing: 12) {
                                PatientCountRow(label: "A - URGENT (Surgical)", count: $urgentPatients, color: .red)
                                PatientCountRow(label: "B - PRIORITY", count: $priorityPatients, color: .orange)
                                PatientCountRow(label: "C - ROUTINE", count: $routinePatients, color: .yellow)
                                PatientCountRow(label: "D - CONVENIENCE", count: $conveniencePatients, color: .green)
                            }
                        }

                        // Line 4 - Special equipment
                        FormSection(title: "LINE 4 - SPECIAL EQUIPMENT", lineNumber: "4") {
                            Picker("Equipment", selection: $specialEquipment) {
                                ForEach(SpecialEquipment.allCases, id: \.self) { equipment in
                                    Text("\(equipment.code) - \(equipment.displayName)").tag(equipment)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(Color(hex: "#FFFC00"))
                        }

                        // Line 5 - Patients by type
                        FormSection(title: "LINE 5 - PATIENTS BY TYPE", lineNumber: "5") {
                            VStack(spacing: 12) {
                                PatientCountRow(label: "L - LITTER", count: $litterPatients, color: .orange)
                                PatientCountRow(label: "A - AMBULATORY", count: $ambulatoryPatients, color: .green)
                            }
                        }

                        // Line 6 - Security
                        FormSection(title: "LINE 6 - SECURITY AT PICKUP SITE", lineNumber: "6") {
                            Picker("Security", selection: $pickupSiteSecurity) {
                                ForEach(PickupSiteSecurity.allCases, id: \.self) { security in
                                    Text("\(security.code) - \(security.displayName)").tag(security)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(Color(hex: "#FFFC00"))
                        }

                        // Line 7 - Marking method
                        FormSection(title: "LINE 7 - METHOD OF MARKING", lineNumber: "7") {
                            Picker("Marking", selection: $markingMethod) {
                                ForEach(MarkingMethod.allCases, id: \.self) { method in
                                    Text("\(method.code) - \(method.displayName)").tag(method)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(Color(hex: "#FFFC00"))
                        }

                        // Line 8 - Patient nationality
                        FormSection(title: "LINE 8 - PATIENT NATIONALITY", lineNumber: "8") {
                            Picker("Nationality", selection: $patientNationality) {
                                ForEach(PatientNationality.allCases, id: \.self) { nationality in
                                    Text("\(nationality.code) - \(nationality.displayName)").tag(nationality)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(Color(hex: "#FFFC00"))
                        }

                        // Line 9 - CBRN
                        FormSection(title: "LINE 9 - NBC CONTAMINATION", lineNumber: "9") {
                            Picker("Contamination", selection: $cbrnContamination) {
                                ForEach(CBRNContamination.allCases, id: \.self) { contamination in
                                    Text("\(contamination.code) - \(contamination.displayName)").tag(contamination)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(Color(hex: "#FFFC00"))
                        }

                        // Remarks
                        FormSection(title: "REMARKS (Optional)", lineNumber: nil) {
                            TextEditor(text: $remarks)
                                .frame(height: 80)
                                .padding(4)
                                .background(Color(hex: "#333333"))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }

                        // Summary
                        VStack(spacing: 8) {
                            HStack {
                                Text("Total Patients:")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(totalPatients)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color(hex: "#FFFC00"))
                            }

                            if totalPatients != (litterPatients + ambulatoryPatients) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Patient counts don't match (Line 3 vs Line 5)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange)
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(Color(hex: "#2A2A2A"))
                        .cornerRadius(8)

                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: { showPreview = true }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                    Text("Preview Request")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "#333333"))
                                .cornerRadius(10)
                            }

                            Button(action: sendRequest) {
                                HStack {
                                    Image(systemName: "paperplane.fill")
                                    Text("SEND MEDEVAC REQUEST")
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("MEDEVAC Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPreview) {
                MEDEVACPreviewView(request: createRequest())
            }
            .alert("Copied to Clipboard", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("MEDEVAC request copied to clipboard")
            }
        }
    }

    private var totalPatients: Int {
        urgentPatients + priorityPatients + routinePatients + conveniencePatients
    }

    private func useCurrentLocation() {
        if let location = locationManager.location {
            currentLocation = location.coordinate
            // Convert to MGRS grid (simplified - would need proper MGRS library)
            locationGrid = String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
        }
    }

    private func createRequest() -> MEDEVACRequest {
        MEDEVACRequest(
            locationGrid: locationGrid,
            locationLat: currentLocation?.latitude,
            locationLon: currentLocation?.longitude,
            radioFrequency: radioFrequency,
            callSign: callSign,
            callSignSuffix: callSignSuffix,
            urgentPatients: urgentPatients,
            priorityPatients: priorityPatients,
            routinePatients: routinePatients,
            conveniencePatients: conveniencePatients,
            specialEquipment: specialEquipment,
            litterPatients: litterPatients,
            ambulatoryPatients: ambulatoryPatients,
            pickupSiteSecurity: pickupSiteSecurity,
            markingMethod: markingMethod,
            patientNationality: patientNationality,
            cbrnContamination: cbrnContamination,
            remarks: remarks,
            senderUID: PositionBroadcastService.shared.userUID,
            senderCallsign: PositionBroadcastService.shared.userCallsign
        )
    }

    private func sendRequest() {
        let request = createRequest()

        // Copy to clipboard
        UIPasteboard.general.string = request.nineLineText
        showCopiedAlert = true

        // Generate CoT and send (would need TAKService integration)
        let cotXML = generateMEDEVACCoT(request: request)
        print("Generated MEDEVAC CoT: \(cotXML)")

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func generateMEDEVACCoT(request: MEDEVACRequest) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(3600)

        let timeStr = dateFormatter.string(from: now)
        let staleStr = dateFormatter.string(from: stale)

        let uid = "MEDEVAC-\(request.id)"
        let lat = request.locationLat ?? 0.0
        let lon = request.locationLon ?? 0.0

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="b-r-f-h-c" time="\(timeStr)" start="\(timeStr)" stale="\(staleStr)" how="h-g-i-g-o">
            <point lat="\(lat)" lon="\(lon)" hae="0.0" ce="9999999" le="9999999"/>
            <detail>
                <contact callsign="\(request.senderCallsign)"/>
                <medevac>
                    <line1>\(request.locationGrid)</line1>
                    <line2>\(request.radioFrequency)/\(request.callSign)-\(request.callSignSuffix)</line2>
                    <line3_urgent>\(request.urgentPatients)</line3_urgent>
                    <line3_priority>\(request.priorityPatients)</line3_priority>
                    <line3_routine>\(request.routinePatients)</line3_routine>
                    <line3_convenience>\(request.conveniencePatients)</line3_convenience>
                    <line4>\(request.specialEquipment.code)</line4>
                    <line5_litter>\(request.litterPatients)</line5_litter>
                    <line5_ambulatory>\(request.ambulatoryPatients)</line5_ambulatory>
                    <line6>\(request.pickupSiteSecurity.code)</line6>
                    <line7>\(request.markingMethod.code)</line7>
                    <line8>\(request.patientNationality.code)</line8>
                    <line9>\(request.cbrnContamination.code)</line9>
                </medevac>
                <remarks>\(request.remarks)</remarks>
            </detail>
        </event>
        """
    }
}

// MARK: - Form Section

struct FormSection<Content: View>: View {
    let title: String
    let lineNumber: String?
    let content: Content

    init(title: String, lineNumber: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.lineNumber = lineNumber
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let line = lineNumber {
                    Text(line)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#FFFC00"))
                        .cornerRadius(4)
                }

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)

                Spacer()
            }

            content
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }
}

// MARK: - Patient Count Row

struct PatientCountRow: View {
    let label: String
    @Binding var count: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 12) {
                Button(action: { if count > 0 { count -= 1 } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }

                Text("\(count)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 40)

                Button(action: { count += 1 }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
    }
}

// MARK: - MEDEVAC Preview View

struct MEDEVACPreviewView: View {
    @Environment(\.dismiss) var dismiss
    let request: MEDEVACRequest

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(request.nineLineText)
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
                        UIPasteboard.general.string = request.nineLineText
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}
