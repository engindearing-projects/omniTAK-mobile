//
//  PointMarkerEditView.swift
//  OmniTAKMobile
//
//  Edit form for PointMarker — invoked from the radial menu Edit action.
//

import SwiftUI
import CoreLocation

struct PointMarkerEditView: View {
    @ObservedObject var pointDropperService: PointDropperService
    let markerID: UUID
    @Binding var isPresented: Bool

    @State private var editedName: String = ""
    @State private var editedAffiliation: MarkerAffiliation = .hostile
    @State private var editedRemarks: String = ""
    @State private var editedAltitude: String = ""
    @State private var editedBroadcast: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section("MARKER") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Marker Name", text: $editedName)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("Affiliation", selection: $editedAffiliation) {
                        ForEach(MarkerAffiliation.allCases, id: \.self) { affiliation in
                            Label(affiliation.displayName, systemImage: affiliation.iconName)
                                .tag(affiliation)
                        }
                    }
                }

                Section("DETAILS") {
                    HStack {
                        Text("Altitude (m)")
                        Spacer()
                        TextField("Optional", text: $editedAltitude)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Remarks")
                        TextEditor(text: $editedRemarks)
                            .frame(minHeight: 80)
                    }
                }

                Section("SHARING") {
                    Toggle("Broadcast to TAK Server", isOn: $editedBroadcast)
                }

                if let marker = currentMarker {
                    Section("LOCATION") {
                        HStack {
                            Text("Coordinates")
                            Spacer()
                            Text(String(format: "%.6f, %.6f",
                                        marker.coordinate.latitude,
                                        marker.coordinate.longitude))
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        isPresented = false
                    }
                    .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var currentMarker: PointMarker? {
        pointDropperService.markers.first(where: { $0.id == markerID })
    }

    private func load() {
        guard let marker = currentMarker else { return }
        editedName = marker.name
        editedAffiliation = marker.affiliation
        editedRemarks = marker.remarks ?? ""
        editedAltitude = marker.altitude.map { String(format: "%.1f", $0) } ?? ""
        editedBroadcast = marker.isBroadcast
    }

    private func save() {
        guard var marker = currentMarker else { return }
        marker.name = editedName.trimmingCharacters(in: .whitespaces)
        marker.affiliation = editedAffiliation
        marker.cotType = editedAffiliation.cotType
        marker.iconName = editedAffiliation.iconName
        marker.remarks = editedRemarks.isEmpty ? nil : editedRemarks
        marker.altitude = Double(editedAltitude.trimmingCharacters(in: .whitespaces))
        marker.isBroadcast = editedBroadcast
        pointDropperService.updateMarker(marker)
    }
}
