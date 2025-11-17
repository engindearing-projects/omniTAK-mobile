import SwiftUI

struct MissionPackageSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var syncService = MissionPackageSyncService()

    @State private var showingSettings = false
    @State private var showingConflictResolution = false
    @State private var selectedConflict: SyncConflict?
    @State private var selectedPackage: MissionPackage?
    @State private var showingPackageDetails = false
    @State private var showingAddPackage = false

    private let backgroundColor = Color(hex: "#1E1E1E")
    private let accentColor = Color(hex: "#FFFC00")
    private let cardBackgroundColor = Color(hex: "#2A2A2A")
    private let textColor = Color.white
    private let secondaryTextColor = Color.gray

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    connectionStatusBar

                    if syncService.isSyncing {
                        syncProgressView
                    }

                    if !syncService.conflicts.isEmpty {
                        conflictsBanner
                    }

                    packagesList

                    statisticsFooter
                }
            }
            .navigationTitle("Mission Packages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showingAddPackage = true }) {
                            Image(systemName: "plus")
                                .foregroundColor(accentColor)
                        }

                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gear")
                                .foregroundColor(accentColor)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ServerSettingsView(syncService: syncService)
            }
            .sheet(isPresented: $showingConflictResolution) {
                if let conflict = selectedConflict {
                    ConflictResolutionView(conflict: conflict, syncService: syncService)
                }
            }
            .sheet(isPresented: $showingPackageDetails) {
                if let package = selectedPackage {
                    PackageDetailsView(package: package)
                }
            }
            .sheet(isPresented: $showingAddPackage) {
                AddPackageView(syncService: syncService)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Connection Status Bar

    private var connectionStatusBar: some View {
        HStack {
            Image(systemName: syncService.networkStatus.iconName)
                .foregroundColor(syncService.isConnected ? .green : .red)

            Text(syncService.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundColor(syncService.isConnected ? .green : .red)

            Spacer()

            if let lastSync = syncService.lastSyncTime {
                Text("Last sync: \(lastSync, formatter: relativeDateFormatter)")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }

            Image(systemName: syncService.networkStatus.iconName)
                .foregroundColor(accentColor)

            Text(syncService.networkStatus.rawValue)
                .font(.caption)
                .foregroundColor(secondaryTextColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(cardBackgroundColor)
    }

    // MARK: - Sync Progress View

    private var syncProgressView: some View {
        VStack(spacing: 8) {
            HStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                    .scaleEffect(0.8)

                Text("Syncing...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)

                Spacer()

                Text("\(Int(syncService.totalSyncProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(accentColor)
            }

            ProgressView(value: syncService.totalSyncProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: accentColor))
        }
        .padding()
        .background(cardBackgroundColor)
    }

    // MARK: - Conflicts Banner

    private var conflictsBanner: some View {
        Button(action: {
            if let conflict = syncService.conflicts.first {
                selectedConflict = conflict
                showingConflictResolution = true
            }
        }) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(accentColor)

                Text("\(syncService.conflicts.count) conflict\(syncService.conflicts.count == 1 ? "" : "s") require\(syncService.conflicts.count == 1 ? "s" : "") resolution")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(accentColor)
            }
            .padding()
            .background(Color.orange.opacity(0.2))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    // MARK: - Packages List

    private var packagesList: some View {
        List {
            if syncService.packages.isEmpty {
                emptyStateView
            } else {
                ForEach(syncService.packages) { package in
                    PackageRowView(package: package, accentColor: accentColor)
                        .listRowBackground(cardBackgroundColor)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPackage = package
                            showingPackageDetails = true
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                syncService.removePackage(package)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                Task {
                                    await syncService.syncPackage(package)
                                }
                            } label: {
                                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .tint(accentColor)
                        }
                }
            }
        }
        .listStyle(.plain)
        .background(backgroundColor)

        .refreshable {
            syncService.syncAllPackages()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundColor(secondaryTextColor)

            Text("No Mission Packages")
                .font(.headline)
                .foregroundColor(textColor)

            Text("Add packages or sync with server to get started")
                .font(.subheadline)
                .foregroundColor(secondaryTextColor)
                .multilineTextAlignment(.center)

            Button(action: syncService.syncAllPackages) {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(accentColor)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }

    // MARK: - Statistics Footer

    private var statisticsFooter: some View {
        HStack {
            StatisticView(
                title: "Total",
                value: "\(syncService.statistics.totalPackages)",
                color: textColor
            )

            Divider()
                .frame(height: 30)
                .background(secondaryTextColor)

            StatisticView(
                title: "Synced",
                value: "\(syncService.statistics.syncedPackages)",
                color: .green
            )

            Divider()
                .frame(height: 30)
                .background(secondaryTextColor)

            StatisticView(
                title: "Pending",
                value: "\(syncService.statistics.pendingPackages)",
                color: .orange
            )

            Divider()
                .frame(height: 30)
                .background(secondaryTextColor)

            StatisticView(
                title: "Conflicts",
                value: "\(syncService.statistics.conflictedPackages)",
                color: accentColor
            )
        }
        .padding(.vertical, 12)
        .background(cardBackgroundColor)
    }

    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }
}

// MARK: - Package Row View

struct PackageRowView: View {
    let package: MissionPackage
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(package.name)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(package.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    statusIndicator

                    Text("v\(package.version)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            HStack(spacing: 12) {
                ForEach(package.contents.prefix(4)) { content in
                    Label("\(content.itemCount)", systemImage: content.iconName)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(package.lastModified, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            if package.syncStatus == .syncing {
                ProgressView(value: 0.5)
                    .progressViewStyle(LinearProgressViewStyle(tint: accentColor))
            }
        }
        .padding(.vertical, 8)
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: package.syncStatus.iconName)
                .foregroundColor(Color(hex: package.syncStatus.color))
                .font(.caption)

            Text(package.syncStatus.displayName)
                .font(.caption)
                .foregroundColor(Color(hex: package.syncStatus.color))
        }
    }
}

// MARK: - Statistic View

struct StatisticView: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundColor(color)

            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Server Settings View

struct ServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var syncService: MissionPackageSyncService

    @State private var serverURL: String = ""
    @State private var port: String = ""
    @State private var useTLS: Bool = true
    @State private var username: String = ""
    @State private var apiKey: String = ""
    @State private var syncInterval: Double = 300
    @State private var enableAutoSync: Bool = true
    @State private var syncOnWiFiOnly: Bool = false
    @State private var defaultResolution: ConflictResolution = .serverWins

    private let backgroundColor = Color(hex: "#1E1E1E")
    private let accentColor = Color(hex: "#FFFC00")

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()

                Form {
                    Section(header: Text("Server Connection").foregroundColor(accentColor)) {
                        TextField("Server URL", text: $serverURL)
                            .autocapitalization(.none)
                            .keyboardType(.URL)

                        TextField("Port", text: $port)
                            .keyboardType(.numberPad)

                        Toggle("Use TLS", isOn: $useTLS)
                            .tint(accentColor)
                    }
                    .listRowBackground(Color(hex: "#2A2A2A"))

                    Section(header: Text("Authentication").foregroundColor(accentColor)) {
                        TextField("Username", text: $username)
                            .autocapitalization(.none)

                        SecureField("API Key", text: $apiKey)
                    }
                    .listRowBackground(Color(hex: "#2A2A2A"))

                    Section(header: Text("Sync Settings").foregroundColor(accentColor)) {
                        Toggle("Auto Sync", isOn: $enableAutoSync)
                            .tint(accentColor)

                        if enableAutoSync {
                            VStack(alignment: .leading) {
                                Text("Sync Interval: \(Int(syncInterval / 60)) min")
                                    .font(.caption)

                                Slider(value: $syncInterval, in: 60...3600, step: 60)
                                    .accentColor(accentColor)
                            }
                        }

                        Toggle("Sync on WiFi Only", isOn: $syncOnWiFiOnly)
                            .tint(accentColor)
                    }
                    .listRowBackground(Color(hex: "#2A2A2A"))

                    Section(header: Text("Conflict Resolution").foregroundColor(accentColor)) {
                        Picker("Default Resolution", selection: $defaultResolution) {
                            ForEach(ConflictResolution.allCases, id: \.self) { resolution in
                                Text(resolution.displayName).tag(resolution)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .listRowBackground(Color(hex: "#2A2A2A"))

                    Section {
                        Button(action: testConnection) {
                            HStack {
                                Spacer()
                                Text("Test Connection")
                                    .foregroundColor(.black)
                                Spacer()
                            }
                        }
                        .listRowBackground(accentColor)
                    }
                }

            }
            .navigationTitle("Server Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loadCurrentSettings() {
        serverURL = syncService.serverConfiguration.serverURL
        port = String(syncService.serverConfiguration.port)
        useTLS = syncService.serverConfiguration.useTLS
        username = syncService.serverConfiguration.username ?? ""
        apiKey = syncService.serverConfiguration.apiKey ?? ""
        syncInterval = Double(syncService.serverConfiguration.syncIntervalSeconds)
        enableAutoSync = syncService.serverConfiguration.enableAutoSync
        syncOnWiFiOnly = syncService.serverConfiguration.syncOnWiFiOnly
        defaultResolution = syncService.serverConfiguration.defaultConflictResolution
    }

    private func saveSettings() {
        syncService.serverConfiguration.serverURL = serverURL
        syncService.serverConfiguration.port = Int(port) ?? 8443
        syncService.serverConfiguration.useTLS = useTLS
        syncService.serverConfiguration.username = username.isEmpty ? nil : username
        syncService.serverConfiguration.apiKey = apiKey.isEmpty ? nil : apiKey
        syncService.serverConfiguration.syncIntervalSeconds = Int(syncInterval)
        syncService.serverConfiguration.enableAutoSync = enableAutoSync
        syncService.serverConfiguration.syncOnWiFiOnly = syncOnWiFiOnly
        syncService.serverConfiguration.defaultConflictResolution = defaultResolution
    }

    private func testConnection() {
        Task {
            _ = await syncService.connect()
        }
    }
}

// MARK: - Conflict Resolution View

struct ConflictResolutionView: View {
    @Environment(\.dismiss) private var dismiss
    let conflict: SyncConflict
    @ObservedObject var syncService: MissionPackageSyncService

    @State private var selectedResolution: ConflictResolution = .serverWins

    private let backgroundColor = Color(hex: "#1E1E1E")
    private let accentColor = Color(hex: "#FFFC00")

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 20) {
                    conflictInfoCard

                    resolutionOptions

                    Spacer()

                    resolveButton
                }
                .padding()
            }
            .navigationTitle("Resolve Conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var conflictInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(conflict.packageName)
                .font(.headline)
                .foregroundColor(.white)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server Version")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("v\(conflict.serverVersion)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text(conflict.serverModified, style: .date)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(accentColor)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Local Version")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("v\(conflict.clientVersion)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text(conflict.clientModified, style: .date)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            if !conflict.conflictingFields.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conflicting Fields:")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text(conflict.conflictingFields.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(accentColor)
                }
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(12)
    }

    private var resolutionOptions: some View {
        VStack(spacing: 12) {
            ForEach(ConflictResolution.allCases, id: \.self) { resolution in
                Button(action: { selectedResolution = resolution }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(resolution.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)

                            Text(resolution.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Image(systemName: selectedResolution == resolution ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedResolution == resolution ? accentColor : .gray)
                    }
                    .padding()
                    .background(Color(hex: "#2A2A2A"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedResolution == resolution ? accentColor : Color.clear, lineWidth: 2)
                    )
                }
            }
        }
    }

    private var resolveButton: some View {
        Button(action: {
            Task {
                await syncService.resolveConflict(conflict, resolution: selectedResolution)
                dismiss()
            }
        }) {
            Text("Apply Resolution")
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(accentColor)
                .cornerRadius(12)
        }
    }
}

// MARK: - Package Details View

struct PackageDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    let package: MissionPackage

    private let backgroundColor = Color(hex: "#1E1E1E")
    private let accentColor = Color(hex: "#FFFC00")

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        metadataSection
                        contentsSection
                        syncInfoSection
                    }
                    .padding()
                }
            }
            .navigationTitle(package.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
                .foregroundColor(accentColor)

            VStack(spacing: 8) {
                metadataRow("Creator", value: package.metadata.creator)
                metadataRow("Classification", value: package.metadata.classification)
                metadataRow("Priority", value: package.metadata.priority.displayName)
                metadataRow("Size", value: formatBytes(package.metadata.sizeBytes))
                metadataRow("Created", value: package.metadata.createdAt.formatted())

                if !package.metadata.tags.isEmpty {
                    HStack(alignment: .top) {
                        Text("Tags")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 100, alignment: .leading)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(package.metadata.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(accentColor.opacity(0.3))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(12)
        }
    }

    private var contentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contents")
                .font(.headline)
                .foregroundColor(accentColor)

            VStack(spacing: 8) {
                ForEach(package.contents) { content in
                    HStack {
                        Image(systemName: content.iconName)
                            .foregroundColor(accentColor)
                            .frame(width: 30)

                        Text(content.displayName)
                            .foregroundColor(.white)

                        Spacer()

                        Text("\(content.itemCount) item\(content.itemCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(12)
        }
    }

    private var syncInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Information")
                .font(.headline)
                .foregroundColor(accentColor)

            VStack(spacing: 8) {
                metadataRow("Status", value: package.syncStatus.displayName)
                metadataRow("Version", value: "v\(package.version)")
                metadataRow("Last Modified", value: package.lastModified.formatted())

                if let serverHash = package.serverHash {
                    metadataRow("Server Hash", value: String(serverHash.prefix(16)) + "...")
                }

                if let localHash = package.localHash {
                    metadataRow("Local Hash", value: String(localHash.prefix(16)) + "...")
                }
            }
            .padding()
            .background(Color(hex: "#2A2A2A"))
            .cornerRadius(12)
        }
    }

    private func metadataRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundColor(.white)

            Spacer()
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Add Package View

struct AddPackageView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var syncService: MissionPackageSyncService

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var classification: String = "UNCLASSIFIED"
    @State private var priority: PackagePriority = .normal
    @State private var tags: String = ""

    private let backgroundColor = Color(hex: "#1E1E1E")
    private let accentColor = Color(hex: "#FFFC00")

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()

                Form {
                    Section(header: Text("Package Info").foregroundColor(accentColor)) {
                        TextField("Name", text: $name)
                        TextField("Description", text: $description)
                    }
                    .listRowBackground(Color(hex: "#2A2A2A"))

                    Section(header: Text("Classification").foregroundColor(accentColor)) {
                        TextField("Classification", text: $classification)

                        Picker("Priority", selection: $priority) {
                            ForEach(PackagePriority.allCases, id: \.self) { level in
                                Text(level.displayName).tag(level)
                            }
                        }
                    }
                    .listRowBackground(Color(hex: "#2A2A2A"))

                    Section(header: Text("Tags").foregroundColor(accentColor)) {
                        TextField("Tags (comma separated)", text: $tags)
                    }
                    .listRowBackground(Color(hex: "#2A2A2A"))
                }

            }
            .navigationTitle("New Package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addPackage()
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                    .disabled(name.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func addPackage() {
        let tagArray = tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }

        let metadata = PackageMetadata(
            creator: "Current User",
            createdAt: Date(),
            classification: classification,
            tags: tagArray,
            priority: priority
        )

        let package = MissionPackage(
            name: name,
            description: description,
            metadata: metadata
        )

        syncService.addPackage(package)
    }
}

// MARK: - Flow Layout

@available(iOS 16.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            height = y + lineHeight
        }
    }
}

// Color extension with hex initializer is defined in SharedUIComponents.swift

// MARK: - Preview

#Preview {
    MissionPackageSyncView()
}
