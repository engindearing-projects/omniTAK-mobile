import SwiftUI
import CoreLocation

// MARK: - Drawing Properties View

struct DrawingPropertiesView: View {
    @ObservedObject var drawingStore: DrawingStore
    let drawingID: UUID
    @Binding var isPresented: Bool

    @State private var editedName: String = ""
    @State private var editedColor: DrawingColor = .red
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section("PROPERTIES") {
                    // Name
                    HStack {
                        Text("Name")
                            .font(.system(size: 14))
                        Spacer()
                        TextField("Drawing Name", text: $editedName)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 14))
                    }

                    // Color
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.system(size: 14))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(DrawingColor.allCases, id: \.self) { color in
                                    Button(action: {
                                        editedColor = color
                                    }) {
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(color.swiftUIColor)
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: editedColor == color ? 3 : 0)
                                                )
                                            Text(color.rawValue)
                                                .font(.system(size: 10))
                                                .foregroundColor(editedColor == color ? .primary : .secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)

                    // Type and Created Date
                    if let info = getDrawingInfo() {
                        HStack {
                            Text("Type")
                                .font(.system(size: 14))
                            Spacer()
                            Text(info.type)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Created")
                                .font(.system(size: 14))
                            Spacer()
                            Text(info.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        if let details = info.details {
                            HStack {
                                Text("Details")
                                    .font(.system(size: 14))
                                Spacer()
                                Text(details)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button(action: {
                        saveChanges()
                        isPresented = false
                    }) {
                        HStack {
                            Spacer()
                            Text("Save Changes")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                    }
                    .disabled(editedName.isEmpty)

                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Delete Drawing")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Drawing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert("Delete Drawing", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteDrawing()
                    isPresented = false
                }
            } message: {
                Text("Are you sure you want to delete this drawing? This action cannot be undone.")
            }
        }
        .onAppear {
            loadDrawing()
        }
    }

    // MARK: - Helper Methods

    private func loadDrawing() {
        if let marker = drawingStore.markers.first(where: { $0.id == drawingID }) {
            editedName = marker.label
            editedColor = marker.color
        } else if let line = drawingStore.lines.first(where: { $0.id == drawingID }) {
            editedName = line.label
            editedColor = line.color
        } else if let circle = drawingStore.circles.first(where: { $0.id == drawingID }) {
            editedName = circle.label
            editedColor = circle.color
        } else if let polygon = drawingStore.polygons.first(where: { $0.id == drawingID }) {
            editedName = polygon.label
            editedColor = polygon.color
        }
    }

    private func saveChanges() {
        if var marker = drawingStore.markers.first(where: { $0.id == drawingID }) {
            marker.label = editedName
            marker.color = editedColor
            drawingStore.updateMarker(marker)
        } else if var line = drawingStore.lines.first(where: { $0.id == drawingID }) {
            line.label = editedName
            line.color = editedColor
            drawingStore.updateLine(line)
        } else if var circle = drawingStore.circles.first(where: { $0.id == drawingID }) {
            circle.label = editedName
            circle.color = editedColor
            drawingStore.updateCircle(circle)
        } else if var polygon = drawingStore.polygons.first(where: { $0.id == drawingID }) {
            polygon.label = editedName
            polygon.color = editedColor
            drawingStore.updatePolygon(polygon)
        }
    }

    private func deleteDrawing() {
        if let marker = drawingStore.markers.first(where: { $0.id == drawingID }) {
            drawingStore.deleteMarker(marker)
        } else if let line = drawingStore.lines.first(where: { $0.id == drawingID }) {
            drawingStore.deleteLine(line)
        } else if let circle = drawingStore.circles.first(where: { $0.id == drawingID }) {
            drawingStore.deleteCircle(circle)
        } else if let polygon = drawingStore.polygons.first(where: { $0.id == drawingID }) {
            drawingStore.deletePolygon(polygon)
        }
    }

    private func getDrawingInfo() -> DrawingInfo? {
        if let marker = drawingStore.markers.first(where: { $0.id == drawingID }) {
            return DrawingInfo(
                type: "Marker",
                createdAt: marker.createdAt,
                details: String(format: "%.6f, %.6f", marker.coordinate.latitude, marker.coordinate.longitude)
            )
        } else if let line = drawingStore.lines.first(where: { $0.id == drawingID }) {
            let distance = calculateRouteDistance(line.coordinates)
            return DrawingInfo(
                type: "Line",
                createdAt: line.createdAt,
                details: "\(line.coordinates.count) points, \(formatDistance(distance))"
            )
        } else if let circle = drawingStore.circles.first(where: { $0.id == drawingID }) {
            return DrawingInfo(
                type: "Circle",
                createdAt: circle.createdAt,
                details: "Radius: \(formatDistance(circle.radius))"
            )
        } else if let polygon = drawingStore.polygons.first(where: { $0.id == drawingID }) {
            return DrawingInfo(
                type: "Polygon",
                createdAt: polygon.createdAt,
                details: "\(polygon.coordinates.count) points"
            )
        }
        return nil
    }

    private func calculateRouteDistance(_ coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance {
        var totalDistance: CLLocationDistance = 0
        for i in 0..<(coordinates.count - 1) {
            totalDistance += coordinates[i].distance(to: coordinates[i + 1])
        }
        return totalDistance
    }

    private func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.2f km", distance / 1000)
        }
    }
}

// MARK: - Drawing Info

struct DrawingInfo {
    let type: String
    let createdAt: Date
    let details: String?
}

// MARK: - Preview

#if DEBUG
struct DrawingPropertiesView_Previews: PreviewProvider {
    static var previews: some View {
        DrawingPropertiesView(
            drawingStore: DrawingStore(),
            drawingID: UUID(),
            isPresented: .constant(true)
        )
    }
}
#endif
