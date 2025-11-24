//
//  SALUTEReportView.swift
//  OmniTAKMobile
//
//  Form interface for creating and editing SALUTE reports
//

import SwiftUI
import CoreLocation

// MARK: - SALUTE Report View

struct SALUTEReportView: View {
    let marker: PointMarker
    let onSave: (SALUTEReport) -> Void
    let onCancel: () -> Void

    @State private var size: String
    @State private var activity: String
    @State private var location: String
    @State private var unit: String
    @State private var time: Date
    @State private var equipment: String

    @State private var showSizeOptions = false
    @State private var showActivityOptions = false
    @State private var showUnitOptions = false

    init(marker: PointMarker, onSave: @escaping (SALUTEReport) -> Void, onCancel: @escaping () -> Void) {
        self.marker = marker
        self.onSave = onSave
        self.onCancel = onCancel

        // Initialize from existing report or defaults
        if let existingReport = marker.saluteReport {
            _size = State(initialValue: existingReport.size)
            _activity = State(initialValue: existingReport.activity)
            _location = State(initialValue: existingReport.location)
            _unit = State(initialValue: existingReport.unit)
            _time = State(initialValue: existingReport.time)
            _equipment = State(initialValue: existingReport.equipment)
        } else {
            _size = State(initialValue: "")
            _activity = State(initialValue: "")
            _location = State(initialValue: marker.mgrsString)
            _unit = State(initialValue: "")
            _time = State(initialValue: Date())
            _equipment = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        headerSection

                        // Size Section
                        sizeSection

                        // Activity Section
                        activitySection

                        // Location Section
                        locationSection

                        // Unit Section
                        unitSection

                        // Time Section
                        timeSection

                        // Equipment Section
                        equipmentSection

                        // Preview Section
                        previewSection

                        // Action Buttons
                        actionButtons
                    }
                    .padding()
                }
            }
            .navigationTitle("SALUTE Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.red)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveReport()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .disabled(!isValid)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: marker.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(marker.affiliation.color)

                Text(marker.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text(marker.affiliation.shortCode)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(marker.affiliation.color.opacity(0.3))
                    .cornerRadius(6)
            }

            Text("Generate tactical intelligence report")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(10)
    }

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SIZE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            Button(action: { showSizeOptions.toggle() }) {
                HStack {
                    Text(size.isEmpty ? "Select unit size..." : size)
                        .foregroundColor(size.isEmpty ? .gray : .white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }

            if showSizeOptions {
                VStack(spacing: 0) {
                    ForEach(SALUTESize.allCases, id: \.self) { option in
                        Button(action: {
                            size = option.rawValue
                            showSizeOptions = false
                        }) {
                            HStack {
                                Text(option.rawValue)
                                    .foregroundColor(.white)
                                Spacer()
                                if size == option.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                }
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIVITY")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            Button(action: { showActivityOptions.toggle() }) {
                HStack {
                    Text(activity.isEmpty ? "Select activity..." : activity)
                        .foregroundColor(activity.isEmpty ? .gray : .white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }

            if showActivityOptions {
                VStack(spacing: 0) {
                    ForEach(SALUTEActivity.allCases, id: \.self) { option in
                        Button(action: {
                            activity = option.rawValue
                            showActivityOptions = false
                        }) {
                            HStack {
                                Text(option.rawValue)
                                    .foregroundColor(.white)
                                Spacer()
                                if activity == option.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                }
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOCATION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            TextField("Grid reference or description", text: $location)
                .textFieldStyle(SALUTETextFieldStyle())

            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.cyan)
                    .font(.system(size: 12))
                Text("Auto-filled from marker coordinates")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }

    private var unitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UNIT TYPE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            Button(action: { showUnitOptions.toggle() }) {
                HStack {
                    Text(unit.isEmpty ? "Select unit type..." : unit)
                        .foregroundColor(unit.isEmpty ? .gray : .white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }

            if showUnitOptions {
                VStack(spacing: 0) {
                    ForEach(SALUTEUnit.allCases, id: \.self) { option in
                        Button(action: {
                            unit = option.rawValue
                            showUnitOptions = false
                        }) {
                            HStack {
                                Text(option.rawValue)
                                    .foregroundColor(.white)
                                Spacer()
                                if unit == option.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                }
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TIME OF OBSERVATION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            DatePicker("", selection: $time)
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
                .accentColor(Color(hex: "#FFFC00"))

            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                Text(formattedTime)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EQUIPMENT")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            TextEditor(text: $equipment)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .foregroundColor(.white)

            Text("Weapons, vehicles, equipment observed")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("REPORT PREVIEW")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#FFFC00"))

                Spacer()

                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                        Text("Copy")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.cyan)
                }
            }

            Text(previewText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: onCancel) {
                HStack {
                    Image(systemName: "xmark")
                    Text("Cancel")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.3))
                .foregroundColor(.red)
                .cornerRadius(10)
            }

            Button(action: saveReport) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Save Report")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValid ? Color(hex: "#FFFC00") : Color.gray)
                .foregroundColor(.black)
                .cornerRadius(10)
            }
            .disabled(!isValid)
        }
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        !size.isEmpty && !activity.isEmpty && !location.isEmpty && !unit.isEmpty
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddHHmm'Z' MMM yy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: time).uppercased()
    }

    private var previewText: String {
        SALUTEReport(
            size: size,
            activity: activity,
            location: location,
            unit: unit,
            time: time,
            equipment: equipment
        ).formattedReport
    }

    // MARK: - Actions

    private func saveReport() {
        let report = SALUTEReport(
            size: size,
            activity: activity,
            location: location,
            unit: unit,
            time: time,
            equipment: equipment
        )
        onSave(report)
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = previewText
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Dark Text Field Style

struct SALUTETextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .foregroundColor(.white)
    }
}

// MARK: - Preview

struct SALUTEReportView_Previews: PreviewProvider {
    static var previews: some View {
        let marker = PointMarker(
            name: "HOS-1-1430",
            affiliation: .hostile,
            coordinate: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365)
        )

        SALUTEReportView(
            marker: marker,
            onSave: { _ in },
            onCancel: { }
        )
    }
}
