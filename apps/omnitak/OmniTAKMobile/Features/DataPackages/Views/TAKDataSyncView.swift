//
//  TAKDataSyncView.swift
//  OmniTAKMobile
//
//  TAK server data synchronization view
//  Displays missions, data packages, and sync status
//

import SwiftUI

// MARK: - Main Data Sync View

struct TAKDataSyncView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var missionManager = TAKMissionSyncManager.shared
    @StateObject private var packageService = TAKDataPackageService.shared
    @StateObject private var serverManager = ServerManager.shared

    @State private var selectedTab: DataSyncTab = .missions
    @State private var showingServerConfig = false
    @State private var showingMissionPassword = false
    @State private var selectedMission: SyncedMission?
    @State private var missionPassword = ""

    enum DataSyncTab: String, CaseIterable {
        case missions = "Missions"
        case packages = "Packages"
        case subscribed = "Subscribed"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Status Banner
                connectionStatusBanner

                // Tab Picker
                Picker("Tab", selection: $selectedTab) {
                    ForEach(DataSyncTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                switch selectedTab {
                case .missions:
                    missionsListView
                case .packages:
                    packagesListView
                case .subscribed:
                    subscribedMissionsView
                }
            }
            .navigationTitle("Data Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                await refreshData()
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }

                        Button {
                            showingServerConfig = true
                        } label: {
                            Label("Server Settings", systemImage: "server.rack")
                        }

                        Divider()

                        Button(role: .destructive) {
                            missionManager.clearAll()
                            packageService.clearAll()
                        } label: {
                            Label("Clear All Data", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingServerConfig) {
                ServerConfigurationView()
            }
            .alert("Enter Mission Password", isPresented: $showingMissionPassword) {
                SecureField("Password", text: $missionPassword)
                Button("Cancel", role: .cancel) {
                    missionPassword = ""
                    selectedMission = nil
                }
                Button("Subscribe") {
                    if let mission = selectedMission {
                        Task {
                            try? await missionManager.subscribe(to: mission.name, password: missionPassword)
                            missionPassword = ""
                            selectedMission = nil
                        }
                    }
                }
            } message: {
                Text("This mission requires a password to subscribe.")
            }
        }
    }

    // MARK: - Connection Status Banner

    private var connectionStatusBanner: some View {
        Group {
            if let activeServer = serverManager.activeServer {
                HStack {
                    Image(systemName: missionManager.status == .completed ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(missionManager.status == .completed ? .green : .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(activeServer.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(missionManager.status.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if missionManager.isLoading || packageService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }

                    if let lastSync = missionManager.lastSyncTime {
                        Text("Synced \(lastSync, style: .relative) ago")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("No server configured")
                        .font(.subheadline)
                    Spacer()
                    Button("Configure") {
                        showingServerConfig = true
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }
        }
    }

    // MARK: - Missions List

    private var missionsListView: some View {
        List {
            if missionManager.missions.isEmpty {
                ContentUnavailableView {
                    Label("No Missions", systemImage: "folder")
                } description: {
                    Text("Pull to refresh or tap the refresh button to load missions from the server.")
                }
            } else {
                ForEach(missionManager.missions) { mission in
                    MissionRowView(
                        mission: mission,
                        onSubscribe: {
                            if mission.isPasswordProtected {
                                selectedMission = mission
                                showingMissionPassword = true
                            } else {
                                Task {
                                    try? await missionManager.subscribe(to: mission.name)
                                }
                            }
                        },
                        onUnsubscribe: {
                            Task {
                                try? await missionManager.unsubscribe(from: mission.name)
                            }
                        }
                    )
                }
            }
        }
        .refreshable {
            await refreshMissions()
        }
    }

    // MARK: - Packages List

    private var packagesListView: some View {
        List {
            if packageService.remotePackages.isEmpty {
                ContentUnavailableView {
                    Label("No Packages", systemImage: "shippingbox")
                } description: {
                    Text("Pull to refresh or tap the refresh button to load data packages from the server.")
                }
            } else {
                ForEach(packageService.remotePackages) { package in
                    DataPackageRowView(
                        package: package,
                        onDownload: {
                            Task {
                                do {
                                    let url = try await packageService.downloadPackage(package)
                                    try await packageService.importDownloadedPackage(package)
                                    print("Downloaded and imported package to: \(url)")
                                } catch {
                                    print("Download error: \(error)")
                                }
                            }
                        },
                        onDelete: {
                            packageService.deleteLocalPackage(package)
                        }
                    )
                }
            }
        }
        .refreshable {
            await refreshPackages()
        }
    }

    // MARK: - Subscribed Missions

    private var subscribedMissionsView: some View {
        List {
            if missionManager.subscribedMissions.isEmpty {
                ContentUnavailableView {
                    Label("No Subscriptions", systemImage: "star")
                } description: {
                    Text("Subscribe to missions from the Missions tab to see them here.")
                }
            } else {
                ForEach(missionManager.subscribedMissions) { mission in
                    SubscribedMissionDetailView(mission: mission)
                }
            }

            if !missionManager.subscribedMissions.isEmpty {
                Section {
                    Button {
                        Task {
                            await missionManager.syncAllSubscribed()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync All Subscribed Missions")
                        }
                    }
                    .disabled(missionManager.isLoading)
                }
            }
        }
        .refreshable {
            await missionManager.syncAllSubscribed()
        }
    }

    // MARK: - Actions

    private func refreshData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await refreshMissions() }
            group.addTask { await refreshPackages() }
        }
    }

    private func refreshMissions() async {
        guard serverManager.activeServer != nil else { return }

        do {
            try await missionManager.connect(to: serverManager.activeServer!)
            _ = try await missionManager.fetchMissions()
        } catch {
            print("Failed to refresh missions: \(error)")
        }
    }

    private func refreshPackages() async {
        guard serverManager.activeServer != nil else { return }

        do {
            _ = try await packageService.fetchDataPackages()
        } catch {
            print("Failed to refresh packages: \(error)")
        }
    }
}

// MARK: - Mission Row View

struct MissionRowView: View {
    let mission: SyncedMission
    let onSubscribe: () -> Void
    let onUnsubscribe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(mission.name)
                            .font(.headline)

                        if mission.isPasswordProtected {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        if mission.isSubscribed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }

                    if let description = mission.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button {
                    if mission.isSubscribed {
                        onUnsubscribe()
                    } else {
                        onSubscribe()
                    }
                } label: {
                    Text(mission.isSubscribed ? "Unsubscribe" : "Subscribe")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(mission.isSubscribed ? .red : .blue)
            }

            HStack(spacing: 16) {
                Label("\(mission.uidCount) markers", systemImage: "mappin.circle")
                Label("\(mission.contentCount) files", systemImage: "doc")

                if let creator = mission.creatorUid {
                    Label(creator, systemImage: "person")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data Package Row View

struct DataPackageRowView: View {
    let package: RemoteDataPackage
    let onDownload: () -> Void
    let onDelete: () -> Void

    @StateObject private var packageService = TAKDataPackageService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(package.name)
                            .font(.headline)

                        if package.isDownloaded {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        if package.isExpired {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(package.formattedSize)
                        Text(package.mimeType)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                if package.isDownloaded {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        onDownload()
                    } label: {
                        if case .downloading(let progress) = packageService.downloadStatus,
                           progress > 0 && progress < 1 {
                            ProgressView(value: progress)
                                .frame(width: 60)
                        } else {
                            Label("Download", systemImage: "arrow.down.circle")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 16) {
                if let submitter = package.submitter {
                    Label(submitter, systemImage: "person")
                }

                if let time = package.submissionTime {
                    Label(time, style: .relative)
                }

                if !package.keywords.isEmpty {
                    Label(package.keywords.joined(separator: ", "), systemImage: "tag")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Subscribed Mission Detail View

struct SubscribedMissionDetailView: View {
    let mission: SyncedMission

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                // UIDs/Markers
                if !mission.localUids.isEmpty {
                    Section {
                        ForEach(mission.localUids) { uid in
                            HStack {
                                Image(systemName: "mappin")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading) {
                                    Text(uid.callsign ?? uid.uid)
                                        .font(.subheadline)
                                    if let type = uid.type {
                                        Text(type)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if let location = uid.location {
                                    Text("\(location.latitude, specifier: "%.4f"), \(location.longitude, specifier: "%.4f")")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Markers (\(mission.localUids.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Contents/Files
                if !mission.localContents.isEmpty {
                    Section {
                        ForEach(mission.localContents) { content in
                            HStack {
                                Image(systemName: content.isDownloaded ? "doc.fill" : "doc")
                                    .foregroundColor(content.isDownloaded ? .green : .secondary)
                                VStack(alignment: .leading) {
                                    Text(content.name)
                                        .font(.subheadline)
                                    if let mimeType = content.mimeType {
                                        Text(mimeType)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: content.size, countStyle: .file))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Files (\(mission.localContents.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mission.name)
                        .font(.headline)

                    HStack(spacing: 12) {
                        Label("\(mission.uidCount)", systemImage: "mappin")
                        Label("\(mission.contentCount)", systemImage: "doc")

                        if let syncTime = mission.lastSyncTime {
                            Label(syncTime, style: .relative)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TAKDataSyncView_Previews: PreviewProvider {
    static var previews: some View {
        TAKDataSyncView()
    }
}
#endif
