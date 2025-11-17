//
//  ArcGISPortalView.swift
//  OmniTAKMobile
//
//  SwiftUI interface for ArcGIS Portal login and content browsing
//

import SwiftUI

// MARK: - Main Portal View

struct ArcGISPortalView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var portalService = ArcGISPortalService.shared
    @ObservedObject private var featureService = ArcGISFeatureService.shared
    @ObservedObject private var tileManager = ArcGISTileManager.shared

    @State private var showLoginSheet = false
    @State private var selectedItem: ArcGISPortalItem?
    @State private var showItemDetail = false
    @State private var searchText = ""
    @State private var selectedFilter: ArcGISItemType?
    @State private var showBasemapGallery = false
    @State private var showLayerConfigs = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Status Header
                connectionStatusHeader

                if portalService.isAuthenticated {
                    // Search and Filter Bar
                    searchAndFilterBar

                    // Content Area
                    if portalService.isLoading && portalService.portalItems.isEmpty {
                        loadingView
                    } else if portalService.portalItems.isEmpty {
                        emptyStateView
                    } else {
                        portalItemsList
                    }
                } else {
                    notAuthenticatedView
                }
            }
            .navigationTitle("ArcGIS Portal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if portalService.isAuthenticated {
                            Button(action: { showBasemapGallery = true }) {
                                Label("Basemap Gallery", systemImage: "map.fill")
                            }

                            Button(action: { showLayerConfigs = true }) {
                                Label("Active Layers", systemImage: "square.3.layers.3d")
                            }

                            Divider()

                            Button(action: { refreshContent() }) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }

                            Button(role: .destructive, action: { portalService.signOut() }) {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } else {
                            Button(action: { showLoginSheet = true }) {
                                Label("Sign In", systemImage: "person.crop.circle.badge.plus")
                            }

                            Button(action: { showBasemapGallery = true }) {
                                Label("Public Basemaps", systemImage: "map.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showLoginSheet) {
                ArcGISLoginView()
            }
            .sheet(item: $selectedItem) { item in
                ArcGISItemDetailView(item: item)
            }
            .sheet(isPresented: $showBasemapGallery) {
                ArcGISBasemapGalleryView()
            }
            .sheet(isPresented: $showLayerConfigs) {
                ArcGISLayerConfigView()
            }
        }
    }

    // MARK: - View Components

    private var connectionStatusHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Circle()
                    .fill(portalService.isAuthenticated ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    if portalService.isAuthenticated {
                        Text(portalService.credentials?.username ?? "Connected")
                            .font(.system(size: 15, weight: .semibold))
                        Text(portalService.credentials?.portalURL ?? "")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Not Connected")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Sign in to access your portal content")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if portalService.isAuthenticated {
                    if let expiration = portalService.credentials?.tokenExpiration {
                        let timeRemaining = expiration.timeIntervalSinceNow
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Token Expires")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(formatTimeRemaining(timeRemaining))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(timeRemaining < 3600 ? .orange : .green)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
        }
    }

    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search portal content...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        performSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)

            // Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ArcGISFilterChip(title: "All", isSelected: selectedFilter == nil) {
                        selectedFilter = nil
                        performSearch()
                    }

                    ForEach([ArcGISItemType.webMap, .featureService, .mapService, .tileService], id: \.self) { type in
                        ArcGISFilterChip(title: type.rawValue, isSelected: selectedFilter == type) {
                            selectedFilter = type
                            performSearch()
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    private var portalItemsList: some View {
        List {
            if !portalService.lastError.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(portalService.lastError)
                            .font(.system(size: 13))
                    }
                }
            }

            Section {
                Text("\(portalService.totalResults) results")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Section {
                ForEach(portalService.portalItems) { item in
                    PortalItemRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                        }
                }

                if portalService.hasMoreResults {
                    Button(action: {
                        loadMoreResults()
                    }) {
                        HStack {
                            Spacer()
                            if portalService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Load More")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .disabled(portalService.isLoading)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading content...")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No Results")
                .font(.system(size: 18, weight: .semibold))
            Text("Try adjusting your search or filters")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { performSearch() }) {
                Text("Search Again")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 72))
                .foregroundColor(.blue.opacity(0.7))

            VStack(spacing: 8) {
                Text("ArcGIS Portal")
                    .font(.system(size: 24, weight: .bold))
                Text("Connect to your ArcGIS Online or Enterprise Portal to access maps, layers, and data.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: { showLoginSheet = true }) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text("Sign In")
                }
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Text("Or explore public content:")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Button(action: { showBasemapGallery = true }) {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("Browse Basemaps")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func performSearch() {
        Task {
            try? await portalService.searchContent(
                query: searchText,
                itemType: selectedFilter
            )
        }
    }

    private func loadMoreResults() {
        Task {
            try? await portalService.loadMoreResults()
        }
    }

    private func refreshContent() {
        Task {
            try? await portalService.searchContent(
                query: portalService.searchQuery,
                itemType: portalService.selectedItemType,
                page: 1
            )
        }
    }

    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        if seconds < 0 {
            return "Expired"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else if seconds < 86400 {
            return "\(Int(seconds / 3600))h"
        } else {
            return "\(Int(seconds / 86400))d"
        }
    }
}

// MARK: - Portal Item Row

struct PortalItemRow: View {
    let item: ArcGISPortalItem

    var body: some View {
        HStack(spacing: 12) {
            // Type Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: item.parsedItemType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }

            // Item Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(item.itemType)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)

                    Text("by \(item.owner)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                if let snippet = item.snippet, !snippet.isEmpty {
                    Text(snippet)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Chip

struct ArcGISFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Login View

struct ArcGISLoginView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var portalService = ArcGISPortalService.shared

    @State private var portalURL = ArcGISPortalService.arcGISOnlineURL
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var useCustomPortal = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("PORTAL")) {
                    Toggle("Enterprise Portal", isOn: $useCustomPortal)

                    if useCustomPortal {
                        TextField("Portal URL", text: $portalURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        HStack {
                            Text("ArcGIS Online")
                            Spacer()
                            Text("arcgis.com")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("CREDENTIALS")) {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    SecureField("Password", text: $password)
                }

                if !errorMessage.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                    }
                }

                Section {
                    Button(action: signIn) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("Sign In")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Spacer()
                        }
                    }
                    .disabled(username.isEmpty || password.isEmpty || isLoading)
                }

                Section(footer: Text("Your credentials are used only to generate an authentication token. Passwords are not stored.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func signIn() {
        isLoading = true
        errorMessage = ""

        Task {
            do {
                let url = useCustomPortal ? portalURL : ArcGISPortalService.arcGISOnlineURL
                try await portalService.authenticate(
                    portalURL: url,
                    username: username,
                    password: password
                )

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Item Detail View

struct ArcGISItemDetailView: View {
    @Environment(\.dismiss) var dismiss
    let item: ArcGISPortalItem

    @ObservedObject private var featureService = ArcGISFeatureService.shared
    @State private var layers: [ArcGISLayerInfo] = []
    @State private var isLoadingLayers = false
    @State private var selectedLayer: ArcGISLayerInfo?

    var body: some View {
        NavigationView {
            List {
                // Basic Info
                Section(header: Text("INFORMATION")) {
                    ArcGISDetailRow(icon: "textformat", label: "Title", value: item.title)
                    ArcGISDetailRow(icon: "person", label: "Owner", value: item.owner)
                    ArcGISDetailRow(icon: "square.stack.3d.up", label: "Type", value: item.itemType)
                    ArcGISDetailRow(icon: "externaldrive", label: "Size", value: item.formattedSize)
                    ArcGISDetailRow(icon: "eye", label: "Views", value: "\(item.numViews)")

                    if let created = item.created {
                        ArcGISDetailRow(icon: "calendar", label: "Created", value: created.formatted(date: .abbreviated, time: .omitted))
                    }

                    if let modified = item.modified {
                        ArcGISDetailRow(icon: "clock", label: "Modified", value: modified.formatted(date: .abbreviated, time: .omitted))
                    }
                }

                // Description
                if let description = item.description, !description.isEmpty {
                    Section(header: Text("DESCRIPTION")) {
                        Text(description)
                            .font(.system(size: 14))
                    }
                }

                // Tags
                if !item.tags.isEmpty {
                    Section(header: Text("TAGS")) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                            ForEach(item.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }

                // URL
                if let url = item.url {
                    Section(header: Text("SERVICE URL")) {
                        Text(url)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.blue)
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = url
                                }) {
                                    Label("Copy URL", systemImage: "doc.on.doc")
                                }
                            }
                    }
                }

                // Layers (for Feature Services)
                if item.parsedItemType == .featureService, let url = item.url {
                    Section(header: Text("LAYERS")) {
                        if isLoadingLayers {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else if layers.isEmpty {
                            Button(action: {
                                loadLayers(from: url)
                            }) {
                                Label("Load Layers", systemImage: "arrow.down.circle")
                            }
                        } else {
                            ForEach(layers, id: \.id) { layer in
                                LayerInfoRow(layer: layer) {
                                    addLayerConfiguration(serviceURL: url, layer: layer)
                                }
                            }
                        }
                    }
                }

                // Actions
                Section {
                    if item.parsedItemType == .featureService, let url = item.url {
                        Button(action: {
                            addAllLayers(serviceURL: url)
                        }) {
                            Label("Add All Layers to Map", systemImage: "plus.square.on.square")
                        }
                    }

                    if item.parsedItemType == .mapService || item.parsedItemType == .tileService {
                        Button(action: {
                            // Add as tile overlay
                            if let url = item.url {
                                let overlay = ArcGISTileOverlay(
                                    serviceURL: url,
                                    serviceType: .mapServer
                                )
                                ArcGISTileManager.shared.addTileOverlay(name: item.title, overlay: overlay)
                            }
                        }) {
                            Label("Add as Basemap", systemImage: "map.fill")
                        }
                    }
                }
            }
            .navigationTitle("Item Details")
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

    private func loadLayers(from url: String) {
        isLoadingLayers = true

        Task {
            do {
                let loadedLayers = try await ArcGISPortalService.shared.getFeatureServiceInfo(serviceURL: url)
                await MainActor.run {
                    layers = loadedLayers
                    isLoadingLayers = false
                }
            } catch {
                await MainActor.run {
                    isLoadingLayers = false
                }
            }
        }
    }

    private func addLayerConfiguration(serviceURL: String, layer: ArcGISLayerInfo) {
        let config = ArcGISServiceConfiguration(
            serviceURL: serviceURL,
            layerId: layer.id,
            displayField: layer.fields?.first?.name
        )
        featureService.addLayerConfiguration(config)
    }

    private func addAllLayers(serviceURL: String) {
        for layer in layers {
            addLayerConfiguration(serviceURL: serviceURL, layer: layer)
        }
    }
}

// MARK: - Layer Info Row

struct LayerInfoRow: View {
    let layer: ArcGISLayerInfo
    let onAdd: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(layer.displayName)
                    .font(.system(size: 14, weight: .medium))

                HStack(spacing: 8) {
                    Image(systemName: layer.parsedGeometryType.icon)
                        .font(.system(size: 11))
                    Text(layer.parsedGeometryType.displayName)
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Basemap Gallery View

struct ArcGISBasemapGalleryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var tileManager = ArcGISTileManager.shared

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("AVAILABLE BASEMAPS")) {
                    ForEach(tileManager.availableBasemaps) { basemap in
                        BasemapRow(basemap: basemap) {
                            let overlay = basemap.createOverlay()
                            tileManager.addTileOverlay(name: basemap.name, overlay: overlay)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Basemap Gallery")
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

struct BasemapRow: View {
    let basemap: BasemapInfo
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "map.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(basemap.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(basemap.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Layer Configuration View

struct ArcGISLayerConfigView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var featureService = ArcGISFeatureService.shared

    var body: some View {
        NavigationView {
            List {
                if featureService.layerConfigurations.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "square.3.layers.3d")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No Active Layers")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add feature layers from portal content")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                } else {
                    Section(header: Text("ACTIVE FEATURE LAYERS")) {
                        ForEach(featureService.layerConfigurations, id: \.serviceURL) { config in
                            LayerConfigRow(config: config) {
                                featureService.removeLayerConfiguration(
                                    serviceURL: config.serviceURL,
                                    layerId: config.layerId
                                )
                            }
                        }
                    }
                }

                Section(header: Text("STATISTICS")) {
                    ArcGISDetailRow(icon: "number", label: "Total Queries", value: "\(featureService.queryStatistics.totalQueries)")
                    ArcGISDetailRow(icon: "square.3.layers.3d.down.left", label: "Features Loaded", value: "\(featureService.queryStatistics.featuresLoaded)")
                    ArcGISDetailRow(icon: "arrow.triangle.2.circlepath", label: "Cache Hit Rate", value: String(format: "%.1f%%", featureService.queryStatistics.cacheHitRate * 100))
                }

                Section {
                    Button(action: {
                        Task {
                            try? await featureService.refreshAllLayers()
                        }
                    }) {
                        Label("Refresh All Layers", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive, action: {
                        featureService.clearCache()
                    }) {
                        Label("Clear Cache", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Active Layers")
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

struct LayerConfigRow: View {
    let config: ArcGISServiceConfiguration
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Layer \(config.layerId)")
                    .font(.system(size: 14, weight: .semibold))

                Text(config.serviceURL)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Supporting Views

struct ArcGISDetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
        .font(.system(size: 14))
    }
}

@available(iOS 16.0, *)
struct ArcGISFlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            height = y + rowHeight
        }
    }
}

// MARK: - Preview

#Preview {
    ArcGISPortalView()
}
