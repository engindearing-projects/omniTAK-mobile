//
//  VideoStreamButton.swift
//  OmniTAKMobile
//
//  Compact button for main map UI to access video streams
//

import SwiftUI

// MARK: - Video Stream Button

struct VideoStreamButton: View {
    @ObservedObject var streamService = VideoStreamService.shared
    @State private var showVideoList = false
    @State private var isPulsing = false

    private let accentColor = Color(red: 1, green: 252/255, blue: 0) // #FFFC00

    var body: some View {
        Button(action: {
            showVideoList = true
        }) {
            ZStack {
                // Background
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                // Icon
                Image(systemName: "video.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accentColor)

                // Badge for feed count
                if !streamService.feeds.isEmpty {
                    Text("\(streamService.feeds.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(accentColor)
                        .clipShape(Circle())
                        .offset(x: 14, y: -14)
                }
            }
        }
        .sheet(isPresented: $showVideoList) {
            VideoFeedListView()
        }
    }
}

// MARK: - Compact Video Button (Alternative Style)

struct CompactVideoButton: View {
    @ObservedObject var streamService = VideoStreamService.shared
    @State private var showVideoList = false

    private let accentColor = Color(red: 1, green: 252/255, blue: 0)

    var body: some View {
        Button(action: {
            showVideoList = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "video.fill")
                    .font(.system(size: 14))

                if !streamService.feeds.isEmpty {
                    Text("\(streamService.feeds.count)")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundColor(accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.15))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .sheet(isPresented: $showVideoList) {
            VideoFeedListView()
        }
    }
}

// MARK: - Video Stream Toolbar Item

struct VideoStreamToolbarButton: View {
    @State private var showVideoList = false

    private let accentColor = Color(red: 1, green: 252/255, blue: 0)

    var body: some View {
        Button(action: {
            showVideoList = true
        }) {
            Image(systemName: "video.fill")
                .foregroundColor(accentColor)
        }
        .sheet(isPresented: $showVideoList) {
            VideoFeedListView()
        }
    }
}

// MARK: - Active Stream Indicator

struct ActiveStreamIndicator: View {
    @ObservedObject var streamService = VideoStreamService.shared

    var body: some View {
        if streamService.activeStreamCount > 0 {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.5)
                    )

                Text("LIVE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red)

                Text("(\(streamService.activeStreamCount))")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
        }
    }
}

// MARK: - Quick Access Video Menu

struct QuickAccessVideoMenu: View {
    @ObservedObject var streamService = VideoStreamService.shared
    @State private var showFullList = false
    @State private var selectedFeed: VideoFeed?

    private let accentColor = Color(red: 1, green: 252/255, blue: 0)

    var body: some View {
        Menu {
            // Recent feeds
            if !streamService.recentFeeds.isEmpty {
                Section("Recent Streams") {
                    ForEach(streamService.recentFeeds.prefix(5)) { feed in
                        Button(action: {
                            selectedFeed = feed
                        }) {
                            Label(feed.name, systemImage: feed.streamProtocol.iconName)
                        }
                    }
                }
            }

            // Favorites
            if !streamService.favoriteFeeds.isEmpty {
                Section("Favorites") {
                    ForEach(streamService.favoriteFeeds.prefix(5)) { feed in
                        Button(action: {
                            selectedFeed = feed
                        }) {
                            Label(feed.name, systemImage: "star.fill")
                        }
                    }
                }
            }

            Divider()

            Button(action: {
                showFullList = true
            }) {
                Label("Manage Streams", systemImage: "list.bullet")
            }

        } label: {
            ZStack {
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                Image(systemName: "video.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accentColor)
            }
        }
        .sheet(isPresented: $showFullList) {
            VideoFeedListView()
        }
        .sheet(item: $selectedFeed) { feed in
            VideoPlayerView(feed: feed)
        }
    }
}

// MARK: - Preview Provider

struct VideoStreamButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                VideoStreamButton()

                CompactVideoButton()

                QuickAccessVideoMenu()

                ActiveStreamIndicator()
            }
        }
    }
}
