//
//  MapSourcesView.swift
//  OmniTAKMobile
//
//  Custom map sources management view
//  Allows importing, configuring, and managing tile sources
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Map Sources View

struct MapSourcesView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var mapSourceManager = MapSourceManager.shared

    @State private var showingImportPicker = false
    @State private var showingAddSource = false
    @State private var showingBuiltInSources = false
    @State private var editingSource: CustomMapSource?
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            List {
                // Active Sources Section
                Section {
                    if mapSourceManager.mapSources.isEmpty {
                        ContentUnavailableView {
                            Label("No Map Sources", systemImage: "map")
                        } description: {
                            Text("Add custom map tile sources to use offline or online maps.")
                        }
                    } else {
                        ForEach(mapSourceManager.mapSources) { source in
                            MapSourceRowView(
                                source: source,
                                onToggle: {
                                    mapSourceManager.toggleVisibility(for: source.id)
                                },
                                onEdit: {
                                    editingSource = source
                                }
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                mapSourceManager.deleteSource(mapSourceManager.mapSources[index].id)
                            }
                        }
                        .onMove { from, to in
                            mapSourceManager.moveSource(from: from, to: to)
                        }
                    }
                } header: {
                    Text("Map Sources")
                } footer: {
                    Text("Toggle sources on/off. Drag to reorder (top sources appear above others).")
                }

                // Add Sources Section
                Section {
                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import from File", systemImage: "doc.badge.plus")
                    }

                    Button {
                        showingAddSource = true
                    } label: {
                        Label("Add Custom URL", systemImage: "link.badge.plus")
                    }

                    Button {
                        showingBuiltInSources = true
                    } label: {
                        Label("Add Built-in Source", systemImage: "square.grid.2x2")
                    }
                } header: {
                    Text("Add Source")
                }
            }
            .navigationTitle("Map Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.xml, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showingAddSource) {
                AddMapSourceView()
            }
            .sheet(isPresented: $showingBuiltInSources) {
                BuiltInMapSourcesView()
            }
            .sheet(item: $editingSource) { source in
                EditMapSourceView(source: source)
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                _ = try mapSourceManager.importFromFile(url: url)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Map Source Row View

struct MapSourceRowView: View {
    let source: CustomMapSource
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { source.isVisible },
                set: { _ in onToggle() }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.name)
                        .font(.headline)

                    Text("Zoom: \(source.minZoom)-\(source.maxZoom)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if source.opacity < 1.0 {
                        Text("Opacity: \(Int(source.opacity * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Button {
                onEdit()
            } label: {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Add Map Source View

struct AddMapSourceView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var mapSourceManager = MapSourceManager.shared

    @State private var name = ""
    @State private var url = ""
    @State private var minZoom = 0
    @State private var maxZoom = 19
    @State private var tileType = "png"

    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Source Name", text: $name)

                    TextField("Tile URL Template", text: $url)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                } header: {
                    Text("Source Details")
                } footer: {
                    Text("Use {z}, {x}, {y} for zoom level and tile coordinates.\nExample: https://tiles.example.com/{z}/{x}/{y}.png")
                }

                Section {
                    Stepper("Min Zoom: \(minZoom)", value: $minZoom, in: 0...maxZoom)
                    Stepper("Max Zoom: \(maxZoom)", value: $maxZoom, in: minZoom...22)

                    Picker("Tile Format", selection: $tileType) {
                        Text("PNG").tag("png")
                        Text("JPG").tag("jpg")
                        Text("WebP").tag("webp")
                    }
                } header: {
                    Text("Settings")
                }

                Section {
                    Button {
                        addSource()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Add Source")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
            .navigationTitle("Add Map Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func addSource() {
        let source = CustomMapSource(
            name: name,
            url: url,
            minZoom: minZoom,
            maxZoom: maxZoom,
            tileType: tileType
        )

        mapSourceManager.addSource(source)
        dismiss()
    }
}

// MARK: - Edit Map Source View

struct EditMapSourceView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var mapSourceManager = MapSourceManager.shared

    let source: CustomMapSource

    @State private var name: String = ""
    @State private var opacity: Double = 1.0
    @State private var minZoom: Int = 0
    @State private var maxZoom: Int = 19

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $name)

                    VStack(alignment: .leading) {
                        Text("URL Template")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(source.url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Source Info")
                }

                Section {
                    VStack {
                        Text("Opacity: \(Int(opacity * 100))%")
                        Slider(value: $opacity, in: 0.1...1.0, step: 0.1)
                    }

                    Stepper("Min Zoom: \(minZoom)", value: $minZoom, in: 0...maxZoom)
                    Stepper("Max Zoom: \(maxZoom)", value: $maxZoom, in: minZoom...22)
                } header: {
                    Text("Display Settings")
                }

                Section {
                    HStack {
                        Text("Tile Type")
                        Spacer()
                        Text(source.tileType.uppercased())
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Imported")
                        Spacer()
                        Text(source.importDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Details")
                }

                Section {
                    Button(role: .destructive) {
                        mapSourceManager.deleteSource(source.id)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Source")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .onAppear {
                loadSource()
            }
        }
    }

    private func loadSource() {
        name = source.name
        opacity = source.opacity
        minZoom = source.minZoom
        maxZoom = source.maxZoom
    }

    private func saveChanges() {
        var updated = source
        updated.name = name
        updated.opacity = opacity
        updated.minZoom = minZoom
        updated.maxZoom = maxZoom

        mapSourceManager.addSource(updated)
        mapSourceManager.setOpacity(for: source.id, opacity: opacity)
        dismiss()
    }
}

// MARK: - Built-in Map Sources View

struct BuiltInMapSourcesView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var mapSourceManager = MapSourceManager.shared

    var body: some View {
        NavigationView {
            List {
                ForEach(MapSourceManager.builtInSources) { source in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.name)
                                .font(.headline)

                            Text("Zoom: \(source.minZoom)-\(source.maxZoom)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if mapSourceManager.mapSources.contains(where: { $0.url == source.url }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Button("Add") {
                                mapSourceManager.addBuiltInSource(source)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("Built-in Sources")
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

#if DEBUG
struct MapSourcesView_Previews: PreviewProvider {
    static var previews: some View {
        MapSourcesView()
    }
}
#endif
