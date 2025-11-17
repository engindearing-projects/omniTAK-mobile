//
//  CASRequestView.swift
//  OmniTAKMobile
//
//  9-Line CAS (Close Air Support) Request Form Interface
//

import SwiftUI
import CoreLocation

struct CASRequestView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager()

    // Form data
    @State private var initialPoint = ""
    @State private var headingMagnetic = ""
    @State private var distanceNM = ""
    @State private var targetElevationFeet = ""
    @State private var targetDescription = ""
    @State private var targetType: TargetType = .troops
    @State private var targetLocationGrid = ""
    @State private var markType: MarkType = .none
    @State private var laserCode = ""
    @State private var markDetails = ""
    @State private var friendlyPosition = ""
    @State private var friendlyDistance = ""
    @State private var friendlyDirection: CardinalDirection = .north
    @State private var friendlyMark: FriendlyMarkType = .none
    @State private var egressDirection = ""
    @State private var controlPoint = ""
    @State private var dangerClose: DangerCloseStatus = .notDangerClose
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
                            Image(systemName: "airplane")
                                .foregroundColor(.orange)
                            Text("9-LINE CAS REQUEST")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)

                        // Danger Close Warning
                        if dangerClose == .dangerClose {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("DANGER CLOSE - FRIENDLIES AT RISK")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.red)
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.3))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red, lineWidth: 2)
                            )
                        }

                        // Line 1 - IP/BP
                        FormSection(title: "LINE 1 - IP/BP (INITIAL POINT)", lineNumber: "1") {
                            TextField("Initial Point/Battle Position", text: $initialPoint)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.allCharacters)
                        }

                        // Line 2 - Heading
                        FormSection(title: "LINE 2 - HEADING (MAGNETIC)", lineNumber: "2") {
                            HStack {
                                TextField("Heading", text: $headingMagnetic)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                                Text("° MAG")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: "#FFFC00"))
                            }
                        }

                        // Line 3 - Distance
                        FormSection(title: "LINE 3 - DISTANCE FROM IP/BP", lineNumber: "3") {
                            HStack {
                                TextField("Distance", text: $distanceNM)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.decimalPad)
                                Text("NM")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: "#FFFC00"))
                            }
                        }

                        // Line 4 - Target Elevation
                        FormSection(title: "LINE 4 - TARGET ELEVATION", lineNumber: "4") {
                            HStack {
                                TextField("Elevation", text: $targetElevationFeet)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                                Text("FT MSL")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: "#FFFC00"))
                            }
                        }

                        // Line 5 - Target Description
                        FormSection(title: "LINE 5 - TARGET DESCRIPTION", lineNumber: "5") {
                            VStack(spacing: 12) {
                                Picker("Target Type", selection: $targetType) {
                                    ForEach(TargetType.allCases, id: \.self) { type in
                                        Text(type.displayName).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(Color(hex: "#FFFC00"))

                                TextField("Additional Description", text: $targetDescription)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        // Line 6 - Target Location
                        FormSection(title: "LINE 6 - TARGET LOCATION", lineNumber: "6") {
                            VStack(spacing: 12) {
                                TextField("Grid Coordinates (MGRS)", text: $targetLocationGrid)
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

                        // Line 7 - Type Mark
                        FormSection(title: "LINE 7 - TYPE MARK", lineNumber: "7") {
                            VStack(spacing: 12) {
                                Picker("Mark Type", selection: $markType) {
                                    ForEach(MarkType.allCases, id: \.self) { type in
                                        Text(type.displayName).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(Color(hex: "#FFFC00"))

                                if markType == .laser {
                                    TextField("Laser Code (4 digits)", text: $laserCode)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.numberPad)
                                } else if markType != .none {
                                    TextField("Mark Details", text: $markDetails)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        }

                        // Line 8 - Location of Friendlies
                        FormSection(title: "LINE 8 - LOCATION OF FRIENDLIES", lineNumber: "8") {
                            VStack(spacing: 12) {
                                HStack {
                                    Picker("Direction", selection: $friendlyDirection) {
                                        ForEach(CardinalDirection.allCases, id: \.self) { dir in
                                            Text(dir.rawValue).tag(dir)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .accentColor(Color(hex: "#FFFC00"))

                                    TextField("Distance", text: $friendlyDistance)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.numberPad)
                                        .frame(width: 100)

                                    Text("m")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: "#FFFC00"))
                                }

                                TextField("Position Description", text: $friendlyPosition)
                                    .textFieldStyle(.roundedBorder)

                                Picker("Friendly Mark", selection: $friendlyMark) {
                                    ForEach(FriendlyMarkType.allCases, id: \.self) { type in
                                        Text(type.displayName).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(Color(hex: "#FFFC00"))

                                // Danger Close Toggle
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("DANGER CLOSE:")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Toggle("", isOn: Binding(
                                            get: { dangerClose == .dangerClose },
                                            set: { dangerClose = $0 ? .dangerClose : .notDangerClose }
                                        ))
                                        .toggleStyle(SwitchToggleStyle(tint: .red))
                                    }

                                    if dangerClose == .dangerClose {
                                        Text("WARNING: Increased risk of friendly casualties")
                                            .font(.system(size: 11))
                                            .foregroundColor(.red)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }

                        // Line 9 - Egress
                        FormSection(title: "LINE 9 - EGRESS/CONTROL POINT", lineNumber: "9") {
                            VStack(spacing: 12) {
                                TextField("Egress Direction", text: $egressDirection)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.allCharacters)

                                TextField("Control Point", text: $controlPoint)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.allCharacters)
                            }
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
                                    Text("SEND CAS REQUEST")
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("CAS Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPreview) {
                CASPreviewView(request: createRequest())
            }
            .alert("Copied to Clipboard", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("CAS request copied to clipboard")
            }
        }
    }

    private func useCurrentLocation() {
        if let location = locationManager.location {
            currentLocation = location.coordinate
            // Convert to MGRS grid (simplified - would need proper MGRS library)
            targetLocationGrid = String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
        }
    }

    private func createRequest() -> CASRequest {
        CASRequest(
            initialPoint: initialPoint,
            headingMagnetic: Int(headingMagnetic) ?? 0,
            distanceNM: Double(distanceNM) ?? 0.0,
            targetElevationFeet: Int(targetElevationFeet) ?? 0,
            targetDescription: targetDescription,
            targetType: targetType,
            targetLocationGrid: targetLocationGrid,
            targetLat: currentLocation?.latitude,
            targetLon: currentLocation?.longitude,
            markType: markType,
            laserCode: laserCode,
            markDetails: markDetails,
            friendlyPosition: friendlyPosition,
            friendlyDistance: Int(friendlyDistance) ?? 0,
            friendlyDirection: friendlyDirection.rawValue,
            friendlyMark: friendlyMark,
            egressDirection: egressDirection,
            controlPoint: controlPoint,
            dangerClose: dangerClose,
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

        // Generate CoT and send
        let cotXML = generateCASCoT(request: request)
        print("Generated CAS CoT: \(cotXML)")

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func generateCASCoT(request: CASRequest) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(3600)

        let timeStr = dateFormatter.string(from: now)
        let staleStr = dateFormatter.string(from: stale)

        let uid = "CAS-\(request.id)"
        let lat = request.targetLat ?? 0.0
        let lon = request.targetLon ?? 0.0

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="b-r-f-h-c" time="\(timeStr)" start="\(timeStr)" stale="\(staleStr)" how="h-g-i-g-o">
            <point lat="\(lat)" lon="\(lon)" hae="0.0" ce="9999999" le="9999999"/>
            <detail>
                <contact callsign="\(request.senderCallsign)"/>
                <cas>
                    <line1>\(request.initialPoint)</line1>
                    <line2>\(request.headingMagnetic)</line2>
                    <line3>\(request.distanceNM)</line3>
                    <line4>\(request.targetElevationFeet)</line4>
                    <line5_type>\(request.targetType.rawValue)</line5_type>
                    <line5_desc>\(request.targetDescription)</line5_desc>
                    <line6>\(request.targetLocationGrid)</line6>
                    <line7_type>\(request.markType.code)</line7_type>
                    <line7_code>\(request.laserCode)</line7_code>
                    <line7_details>\(request.markDetails)</line7_details>
                    <line8_direction>\(request.friendlyDirection)</line8_direction>
                    <line8_distance>\(request.friendlyDistance)</line8_distance>
                    <line8_position>\(request.friendlyPosition)</line8_position>
                    <line8_mark>\(request.friendlyMark.code)</line8_mark>
                    <line9_egress>\(request.egressDirection)</line9_egress>
                    <line9_control>\(request.controlPoint)</line9_control>
                    <danger_close>\(request.dangerClose.rawValue)</danger_close>
                </cas>
                <remarks>\(request.remarks)</remarks>
            </detail>
        </event>
        """
    }
}

// MARK: - CAS Preview View

struct CASPreviewView: View {
    @Environment(\.dismiss) var dismiss
    let request: CASRequest
    @State private var showCopiedAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if request.isDangerClose {
                            HStack {
                                Spacer()
                                Text("*** DANGER CLOSE ***")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding()
                            .background(Color.red.opacity(0.3))
                            .cornerRadius(8)
                            .padding(.bottom, 12)
                        }

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
                        showCopiedAlert = true
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
            .alert("Copied", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("CAS request copied to clipboard")
            }
        }
    }
}
