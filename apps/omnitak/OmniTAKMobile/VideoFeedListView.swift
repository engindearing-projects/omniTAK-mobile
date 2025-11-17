//
//  VideoFeedListView.swift
//  OmniTAKMobile
//
//  Video feed management UI with dark theme
//

import SwiftUI
import CoreLocation

// MARK: - Video Feed List View

struct VideoFeedListView: View {
    @ObservedObject var streamService = VideoStreamService.shared
    @Environment(\.dismiss) var dismiss
    @State private var showAddFeed = false
    @State private var selectedFeed: VideoFeed?
    @State private var searchText = ""
    @State private var sortOption: FeedSortOption = .recentlyAccessed
    @State private var showSortPicker = false
    @State private var feedToEdit: VideoFeed?

    private let accentColor = Color(red: 1, green: 252/255, blue: 0) // #FFFC00
    private let backgroundColor = Color(red: 30/255, green: 30/255, blue: 30/255) // #1E1E1E

    var filteredFeeds: [VideoFeed] {
        let sorted = streamService.sortedFeeds(by: sortOption)

        if searchText.isEmpty {
            return sorted
        } else {
            return sorted.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.url.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()

                if streamService.feeds.isEmpty {
                    emptyStateView
                } else {
                    feedListContent
                }
            }
            .navigationTitle("Video Streams")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search feeds")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(accentColor)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showAddFeed = true }) {
                            Label("Add Stream", systemImage: "plus")
                        }

                        Button(action: { showSortPicker = true }) {
                            Label("Sort By", systemImage: "arrow.up.arrow.down")
                        }

                        if !streamService.feeds.isEmpty {
                            Button(action: { streamService.addSampleFeeds() }) {
                                Label("Add Sample Streams", systemImage: "wand.and.stars")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(accentColor)
                    }
                }
            }
            .sheet(isPresented: $showAddFeed) {
                AddVideoFeedView()
            }
            .sheet(item: $selectedFeed) { feed in
                VideoPlayerView(feed: feed)
            }
            .sheet(item: $feedToEdit) { feed in
                EditVideoFeedView(feed: feed)
            }
            .confirmationDialog("Sort By", isPresented: $showSortPicker) {
                ForEach(FeedSortOption.allCases, id: \.self) { option in
                    Button(option.rawValue) {
                        sortOption = option
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("No Video Streams")
                .font(.title2)
                .foregroundColor(.white)

            Text("Add video stream URLs to watch live feeds")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button(action: { showAddFeed = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Stream")
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(accentColor)
                .cornerRadius(10)
            }

            Button(action: { streamService.addSampleFeeds() }) {
                Text("Add Sample Streams")
                    .font(.subheadline)
                    .foregroundColor(accentColor)
            }
        }
        .padding()
    }

    // MARK: - Feed List Content

    private var feedListContent: some View {
        List {
            // Recent feeds section
            if !streamService.recentFeeds.isEmpty {
                Section {
                    ForEach(streamService.recentFeeds.prefix(3)) { feed in
                        RecentFeedRow(feed: feed)
                            .onTapGesture {
                                selectedFeed = feed
                            }
                    }
                } header: {
                    Text("RECENT")
                        .foregroundColor(.gray)
                }
                .listRowBackground(Color(white: 0.15))
            }

            // All feeds section
            Section {
                ForEach(filteredFeeds) { feed in
                    VideoFeedRow(feed: feed)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFeed = feed
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                streamService.deleteFeed(feed)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                feedToEdit = feed
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                streamService.toggleFavorite(feed)
                            } label: {
                                Label(
                                    feed.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: feed.isFavorite ? "star.slash" : "star.fill"
                                )
                            }
                            .tint(.orange)
                        }
                }
            } header: {
                HStack {
                    Text("ALL STREAMS (\(filteredFeeds.count))")
                        .foregroundColor(.gray)

                    Spacer()

                    Text("Sorted by: \(sortOption.rawValue)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .listRowBackground(Color(white: 0.15))
        }
        .listStyle(.insetGrouped)
        .background(Color(hex: "#1E1E1E"))
    }
}

// MARK: - Video Feed Row

struct VideoFeedRow: View {
    let feed: VideoFeed

    var body: some View {
        HStack(spacing: 12) {
            // Protocol Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(protocolColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: feed.streamProtocol.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(protocolColor)
            }

            // Feed Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(feed.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if feed.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    if !feed.streamProtocol.isNativelySupported {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }

                Text(feed.url)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(feed.streamProtocol.displayName)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(protocolColor.opacity(0.3))
                        .cornerRadius(4)

                    if feed.hasLocation {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    Text(feed.lastAccessed.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            // Chevron
            Image(systemName: "play.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(Color(red: 1, green: 252/255, blue: 0))
        }
        .padding(.vertical, 4)
    }

    private var protocolColor: Color {
        switch feed.streamProtocol {
        case .http: return .blue
        case .rtsp: return .orange
        case .hls: return .green
        }
    }
}

// MARK: - Recent Feed Row

struct RecentFeedRow: View {
    let feed: VideoFeed

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 2) {
                Text(feed.name)
                    .font(.subheadline)
                    .foregroundColor(.white)

                Text(feed.lastAccessed.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "play.fill")
                .foregroundColor(Color(red: 1, green: 252/255, blue: 0))
        }
    }
}

// MARK: - Add Video Feed View

struct AddVideoFeedView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var streamService = VideoStreamService.shared

    @State private var name = ""
    @State private var url = ""
    @State private var selectedProtocol: VideoProtocol = .http
    @State private var notes = ""
    @State private var addLocation = false
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var showValidationError = false
    @State private var validationMessage = ""

    private let accentColor = Color(red: 1, green: 252/255, blue: 0)

    var body: some View {
        NavigationView {
            Form {
                Section("Stream Details") {
                    TextField("Stream Name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Stream URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .onChange(of: url) { newValue in
                            autoDetectProtocol(from: newValue)
                        }

                    Picker("Protocol", selection: $selectedProtocol) {
                        ForEach(VideoProtocol.allCases, id: \.self) { proto in
                            HStack {
                                Image(systemName: proto.iconName)
                                Text(proto.displayName)
                            }
                            .tag(proto)
                        }
                    }

                    if !selectedProtocol.isNativelySupported {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text("RTSP requires external player")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }

                Section {
                    Toggle("Add Location", isOn: $addLocation)

                    if addLocation {
                        TextField("Latitude", text: $latitude)
                            .keyboardType(.decimalPad)

                        TextField("Longitude", text: $longitude)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Map Correlation (Optional)")
                } footer: {
                    Text("Location allows the video feed to be shown on the map")
                }
            }
            .navigationTitle("Add Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addFeed()
                    }
                    .font(.system(size: 17, weight: .bold))
                    .disabled(name.isEmpty || url.isEmpty)
                }
            })
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func autoDetectProtocol(from urlString: String) {
        let detected = streamService.detectProtocol(from: urlString)
        selectedProtocol = detected
    }

    private func addFeed() {
        // Validate URL
        let validation = streamService.validateStreamURL(url)
        if !validation.isValid {
            validationMessage = validation.error ?? "Invalid URL"
            showValidationError = true
            return
        }

        // Parse location if provided
        var location: CLLocationCoordinate2D?
        if addLocation {
            if let lat = Double(latitude), let lon = Double(longitude) {
                location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            } else if !latitude.isEmpty || !longitude.isEmpty {
                validationMessage = "Invalid coordinates"
                showValidationError = true
                return
            }
        }

        // Create feed
        let feed = VideoFeed(
            name: name,
            url: url,
            streamProtocol: selectedProtocol,
            location: location,
            notes: notes.isEmpty ? nil : notes
        )

        streamService.addFeed(feed)
        dismiss()
    }
}

// MARK: - Edit Video Feed View

struct EditVideoFeedView: View {
    let feed: VideoFeed
    @Environment(\.dismiss) var dismiss
    @ObservedObject var streamService = VideoStreamService.shared

    @State private var name: String
    @State private var url: String
    @State private var selectedProtocol: VideoProtocol
    @State private var notes: String
    @State private var hasLocation: Bool
    @State private var latitude: String
    @State private var longitude: String
    @State private var showValidationError = false
    @State private var validationMessage = ""

    init(feed: VideoFeed) {
        self.feed = feed
        _name = State(initialValue: feed.name)
        _url = State(initialValue: feed.url)
        _selectedProtocol = State(initialValue: feed.streamProtocol)
        _notes = State(initialValue: feed.notes ?? "")
        _hasLocation = State(initialValue: feed.hasLocation)
        if let coord = feed.coordinate {
            _latitude = State(initialValue: String(format: "%.6f", coord.latitude))
            _longitude = State(initialValue: String(format: "%.6f", coord.longitude))
        } else {
            _latitude = State(initialValue: "")
            _longitude = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Stream Details") {
                    TextField("Stream Name", text: $name)

                    TextField("Stream URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    Picker("Protocol", selection: $selectedProtocol) {
                        ForEach(VideoProtocol.allCases, id: \.self) { proto in
                            Text(proto.displayName).tag(proto)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }

                Section("Location") {
                    Toggle("Has Location", isOn: $hasLocation)

                    if hasLocation {
                        TextField("Latitude", text: $latitude)
                            .keyboardType(.decimalPad)

                        TextField("Longitude", text: $longitude)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Edit Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFeed()
                    }
                    .font(.system(size: 17, weight: .bold))
                    .disabled(name.isEmpty || url.isEmpty)
                }
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveFeed() {
        let validation = streamService.validateStreamURL(url)
        if !validation.isValid {
            validationMessage = validation.error ?? "Invalid URL"
            showValidationError = true
            return
        }

        var updatedFeed = feed
        updatedFeed.name = name
        updatedFeed.url = url
        updatedFeed.streamProtocol = selectedProtocol
        updatedFeed.notes = notes.isEmpty ? nil : notes

        if hasLocation {
            if let lat = Double(latitude), let lon = Double(longitude) {
                updatedFeed.setLocation(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            } else if !latitude.isEmpty || !longitude.isEmpty {
                validationMessage = "Invalid coordinates"
                showValidationError = true
                return
            }
        } else {
            updatedFeed.setLocation(nil)
        }

        streamService.updateFeed(updatedFeed)
        dismiss()
    }
}
