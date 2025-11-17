import SwiftUI

// MARK: - Drawing Tools Panel

struct DrawingToolsPanel: View {
    @ObservedObject var drawingManager: DrawingToolsManager
    @Binding var isVisible: Bool
    let onComplete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if drawingManager.isDrawingActive {
                // Active Drawing Mode
                activeDrawingView
            } else {
                // Tool Selection Mode
                toolSelectionView
            }
        }
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 10)
    }

    // MARK: - Tool Selection View

    private var toolSelectionView: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("DRAWING TOOLS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    isVisible = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()
                .background(Color.white.opacity(0.3))

            // Tool Buttons
            VStack(spacing: 8) {
                DrawingToolButton(
                    icon: "mappin.circle.fill",
                    label: "Marker",
                    color: .cyan
                ) {
                    drawingManager.startDrawing(mode: .marker)
                }

                DrawingToolButton(
                    icon: "line.diagonal",
                    label: "Line",
                    color: Color(red: 1.0, green: 0.988, blue: 0.0)
                ) {
                    drawingManager.startDrawing(mode: .line)
                }

                DrawingToolButton(
                    icon: "circle",
                    label: "Circle",
                    color: .green
                ) {
                    drawingManager.startDrawing(mode: .circle)
                }

                DrawingToolButton(
                    icon: "pentagon",
                    label: "Polygon",
                    color: .purple
                ) {
                    drawingManager.startDrawing(mode: .polygon)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 200)
    }

    // MARK: - Active Drawing View

    private var activeDrawingView: some View {
        VStack(spacing: 12) {
            // Header with mode indicator
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DRAWING: \(drawingManager.currentMode?.rawValue.uppercased() ?? "")")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("\(drawingManager.temporaryPoints.count) points")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Instructions
            Text(drawingManager.getInstructions())
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
                .padding(.horizontal, 12)

            // Color Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DrawingColor.allCases, id: \.self) { color in
                        Button(action: {
                            drawingManager.currentColor = color
                        }) {
                            Circle()
                                .fill(color.swiftUIColor)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: drawingManager.currentColor == color ? 3 : 0)
                                )
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 40)

            Divider()
                .background(Color.white.opacity(0.3))

            // Action Buttons
            HStack(spacing: 12) {
                // Cancel Button
                Button(action: {
                    drawingManager.cancelDrawing()
                    onCancel()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                        Text("Cancel")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
                }

                // Undo Button
                Button(action: {
                    drawingManager.undoLastPoint()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 24))
                        Text("Undo")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.yellow)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(8)
                }
                .disabled(drawingManager.temporaryPoints.isEmpty && drawingManager.currentMode != .circle)
                .opacity((drawingManager.temporaryPoints.isEmpty && drawingManager.currentMode != .circle) ? 0.5 : 1.0)

                // Complete Button
                Button(action: {
                    drawingManager.completeDrawing()
                    onComplete()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                        Text("Done")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                }
                .disabled(!drawingManager.canComplete())
                .opacity(drawingManager.canComplete() ? 1.0 : 0.5)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 280)
    }
}

// MARK: - Drawing Tool Button

struct DrawingToolButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 30)

                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Drawing List Panel

struct DrawingListPanel: View {
    @ObservedObject var drawingStore: DrawingStore
    @Binding var isVisible: Bool
    @State private var selectedDrawingID: UUID?
    @State private var showingProperties: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("DRAWINGS (\(drawingStore.totalDrawingCount()))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    isVisible = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .background(Color.white.opacity(0.3))

            // Drawing List
            ScrollView {
                VStack(spacing: 8) {
                    // Markers
                    if !drawingStore.markers.isEmpty {
                        DrawingSection(title: "MARKERS", count: drawingStore.markers.count)
                        ForEach(drawingStore.markers) { marker in
                            DrawingListItem(
                                name: marker.label,
                                icon: "mappin.circle.fill",
                                color: marker.color.swiftUIColor
                            ) {
                                selectedDrawingID = marker.id
                                showingProperties = true
                            }
                        }
                    }

                    // Lines
                    if !drawingStore.lines.isEmpty {
                        DrawingSection(title: "LINES", count: drawingStore.lines.count)
                        ForEach(drawingStore.lines) { line in
                            DrawingListItem(
                                name: line.label,
                                icon: "line.diagonal",
                                color: line.color.swiftUIColor
                            ) {
                                selectedDrawingID = line.id
                                showingProperties = true
                            }
                        }
                    }

                    // Circles
                    if !drawingStore.circles.isEmpty {
                        DrawingSection(title: "CIRCLES", count: drawingStore.circles.count)
                        ForEach(drawingStore.circles) { circle in
                            DrawingListItem(
                                name: circle.label,
                                icon: "circle",
                                color: circle.color.swiftUIColor
                            ) {
                                selectedDrawingID = circle.id
                                showingProperties = true
                            }
                        }
                    }

                    // Polygons
                    if !drawingStore.polygons.isEmpty {
                        DrawingSection(title: "POLYGONS", count: drawingStore.polygons.count)
                        ForEach(drawingStore.polygons) { polygon in
                            DrawingListItem(
                                name: polygon.label,
                                icon: "pentagon",
                                color: polygon.color.swiftUIColor
                            ) {
                                selectedDrawingID = polygon.id
                                showingProperties = true
                            }
                        }
                    }

                    if drawingStore.totalDrawingCount() == 0 {
                        Text("No drawings yet")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.vertical, 20)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider()
                .background(Color.white.opacity(0.3))

            // Clear All Button
            if drawingStore.totalDrawingCount() > 0 {
                Button(action: {
                    drawingStore.clearAllDrawings()
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Clear All Drawings")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 240)
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

// MARK: - Drawing Section Header

struct DrawingSection: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}

// MARK: - Drawing List Item

struct DrawingListItem: View {
    let name: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(name)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)
        }
    }
}
