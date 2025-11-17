//
//  GeofenceManagementView.swift
//  OmniTAKMobile
//
//  Geofence management UI for creating and monitoring geofences
//

import SwiftUI
import CoreLocation

// MARK: - Geofence List View

struct GeofenceListView: View {
    @ObservedObject var geofenceService = GeofenceService.shared
    @State private var showCreateGeofence = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Active Alerts Banner
                    if !geofenceService.activeAlerts.isEmpty {
                        alertsBanner
                    }

                    if geofenceService.geofences.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(geofenceService.geofences) { geofence in
                                    GeofenceCard(geofence: geofence)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Geofences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateGeofence = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hex: "#FFFC00"))
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateGeofence) {
            GeofenceCreatorView()
        }
    }

    private var alertsBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)

            Text("\(geofenceService.activeAlerts.count) Active Alert(s)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button("Clear") {
                geofenceService.clearAlerts()
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.yellow)
        }
        .padding()
        .background(Color.yellow.opacity(0.2))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.dashed")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Geofences")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Create geofences to monitor area entry and exit")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button(action: { showCreateGeofence = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Geofence")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#FFFC00"))
                .padding()
                .background(Color(hex: "#FFFC00").opacity(0.2))
                .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Geofence Card

struct GeofenceCard: View {
    let geofence: Geofence
    @ObservedObject var geofenceService = GeofenceService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(geofence.color.swiftUIColor)
                    .frame(width: 12, height: 12)

                Text(geofence.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { geofence.isActive },
                    set: { _ in geofenceService.toggleGeofence(geofence) }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#FFFC00")))
            }

            HStack(spacing: 16) {
                // Type
                VStack(alignment: .leading, spacing: 2) {
                    Text("Type")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(geofence.type.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Alerts
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alerts")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    HStack(spacing: 4) {
                        if geofence.alertOnEntry {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                        }
                        if geofence.alertOnExit {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 12))
                        }
                    }
                }

                // Dwell Time
                if geofence.dwellTimeThreshold > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dwell Alert")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text("\(Int(geofence.dwellTimeThreshold / 60))min")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                // Status
                if geofence.isActive {
                    Text("MONITORING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#FFFC00"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#FFFC00").opacity(0.2))
                        .cornerRadius(4)
                } else {
                    Text("INACTIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            // Delete Button
            HStack {
                Spacer()
                Button(action: { geofenceService.deleteGeofence(geofence) }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(geofence.isActive ? geofence.color.swiftUIColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Geofence Creator View

struct GeofenceCreatorView: View {
    @ObservedObject var geofenceService = GeofenceService.shared
    @State private var name = ""
    @State private var selectedType: GeofenceType = .circle
    @State private var alertOnEntry = true
    @State private var alertOnExit = true
    @State private var enableDwellAlert = false
    @State private var dwellTimeMinutes = 5
    @State private var selectedColor: GeofenceColor = .yellow
    @State private var radius: Double = 100
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NAME")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)

                            TextField("Geofence name", text: $name)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding()
                                .background(Color(hex: "#333333"))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }

                        // Type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TYPE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)

                            HStack(spacing: 12) {
                                TypeButton(type: .circle, selected: selectedType == .circle) {
                                    selectedType = .circle
                                }
                                TypeButton(type: .polygon, selected: selectedType == .polygon) {
                                    selectedType = .polygon
                                }
                            }
                        }

                        // Radius (for circle)
                        if selectedType == .circle {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("RADIUS: \(Int(radius))m")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.gray)

                                Slider(value: $radius, in: 10...1000, step: 10)
                                    .accentColor(Color(hex: "#FFFC00"))
                            }
                        }

                        // Alert Settings
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ALERTS")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)

                            Toggle("Alert on Entry", isOn: $alertOnEntry)
                                .foregroundColor(.white)
                                .toggleStyle(SwitchToggleStyle(tint: Color.green))

                            Toggle("Alert on Exit", isOn: $alertOnExit)
                                .foregroundColor(.white)
                                .toggleStyle(SwitchToggleStyle(tint: Color.red))

                            Toggle("Dwell Time Alert", isOn: $enableDwellAlert)
                                .foregroundColor(.white)
                                .toggleStyle(SwitchToggleStyle(tint: Color.orange))

                            if enableDwellAlert {
                                HStack {
                                    Text("Alert after:")
                                        .foregroundColor(.gray)
                                    Picker("", selection: $dwellTimeMinutes) {
                                        Text("1 min").tag(1)
                                        Text("5 min").tag(5)
                                        Text("10 min").tag(10)
                                        Text("30 min").tag(30)
                                        Text("60 min").tag(60)
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .accentColor(Color(hex: "#FFFC00"))
                                }
                            }
                        }
                        .padding()
                        .background(Color(hex: "#2A2A2A"))
                        .cornerRadius(12)

                        // Color
                        VStack(alignment: .leading, spacing: 8) {
                            Text("COLOR")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                                ForEach(GeofenceColor.allCases, id: \.self) { color in
                                    Button(action: { selectedColor = color }) {
                                        Circle()
                                            .fill(color.swiftUIColor)
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                        }

                        Spacer()

                        // Create Button
                        Button(action: createGeofence) {
                            Text("Create Geofence")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(name.isEmpty ? Color.gray : Color(hex: "#FFFC00"))
                                .cornerRadius(10)
                        }
                        .disabled(name.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Geofence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.gray)
                }
            }
        }
    }

    private func createGeofence() {
        let geofence = Geofence(
            name: name,
            type: selectedType,
            color: selectedColor,
            alertOnEntry: alertOnEntry,
            alertOnExit: alertOnExit,
            dwellTimeThreshold: enableDwellAlert ? Double(dwellTimeMinutes * 60) : 0,
            center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365), // Default location
            radius: radius,
            polygonCoordinates: nil
        )

        geofenceService.addGeofence(geofence)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Type Button

private struct TypeButton: View {
    let type: GeofenceType
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type == .circle ? "circle" : "pentagon")
                    .font(.system(size: 24))
                Text(type.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(selected ? Color(hex: "#FFFC00") : .gray)
            .frame(maxWidth: .infinity)
            .padding()
            .background(selected ? Color(hex: "#FFFC00").opacity(0.2) : Color(hex: "#333333"))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color(hex: "#FFFC00") : Color.clear, lineWidth: 1)
            )
        }
    }
}

// MARK: - Geofence Alert Popup

struct GeofenceAlertPopup: View {
    let alert: GeofenceAlert
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: alert.eventType == .entry ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(alert.eventType == .entry ? .green : .red)

            Text(alert.eventType == .entry ? "ENTERED GEOFENCE" : "EXITED GEOFENCE")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text(alert.geofenceName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "#FFFC00"))

            Text(alert.formattedTimestamp)
                .font(.system(size: 14))
                .foregroundColor(.gray)

            Button("Dismiss") {
                isPresented = false
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(hex: "#FFFC00"))
            .cornerRadius(10)
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.5), radius: 20)
        .padding(40)
    }
}

// MARK: - Geofence Button

struct GeofenceButton: View {
    @ObservedObject var geofenceService = GeofenceService.shared
    @State private var showGeofenceList = false

    var body: some View {
        Button(action: { showGeofenceList = true }) {
            ZStack {
                Circle()
                    .fill(geofenceService.activeAlerts.isEmpty ? Color.black.opacity(0.6) : Color.yellow.opacity(0.3))
                    .frame(width: 56, height: 56)

                Image(systemName: "square.dashed")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(geofenceService.activeAlerts.isEmpty ? .white : .yellow)

                // Alert badge
                if !geofenceService.activeAlerts.isEmpty {
                    Text("\(geofenceService.activeAlerts.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 20, height: 20)
                        .background(Color.yellow)
                        .cornerRadius(10)
                        .offset(x: 18, y: -18)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showGeofenceList) {
            GeofenceListView()
        }
    }
}
