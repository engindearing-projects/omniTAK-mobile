//
//  VideoPlayerView.swift
//  OmniTAKMobile
//
//  Video player view using AVFoundation for HTTP/HLS streams
//

import SwiftUI
import AVKit
import AVFoundation
import Combine

// MARK: - Video Player View

struct VideoPlayerView: View {
    let feed: VideoFeed
    @Environment(\.dismiss) var dismiss
    @StateObject private var playerController = VideoPlayerController()
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var isLandscape = false
    @State private var showInfo = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                // Video Content
                if feed.streamProtocol == .rtsp && !feed.streamProtocol.isNativelySupported {
                    rtspUnsupportedView
                } else {
                    videoPlayerContent(geometry: geometry)
                }

                // Controls Overlay
                if showControls {
                    controlsOverlay
                }
            }
            .onTapGesture {
                toggleControls()
            }
            .onAppear {
                setupPlayer()
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                cleanup()
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .statusBarHidden(!showControls)
        }
        .ignoresSafeArea()
    }

    // MARK: - Video Player Content

    @ViewBuilder
    private func videoPlayerContent(geometry: GeometryProxy) -> some View {
        VStack {
            if let player = playerController.player {
                VideoPlayerRepresentable(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if playerController.isLoading {
                loadingView
            } else if let error = playerController.errorMessage {
                errorView(error)
            } else {
                loadingView
            }
        }
    }

    // MARK: - RTSP Unsupported View

    private var rtspUnsupportedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text("RTSP Not Supported")
                .font(.title2)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)

            Text("Native iOS does not support RTSP streams.\nRTSP playback requires third-party libraries (FFmpeg, VLCKit, etc.).")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("Stream URL:")
                .font(.caption)
                .foregroundColor(.gray)

            Text(feed.url)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal)
                .lineLimit(3)
                .multilineTextAlignment(.center)

            Button(action: {
                UIPasteboard.general.string = feed.url
            }) {
                Label("Copy URL", systemImage: "doc.on.clipboard")
                    .foregroundColor(Color(red: 1, green: 252/255, blue: 0))
            }
            .padding(.top, 10)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .tint(.gray)
            .padding(.top, 20)
        }
        .padding()
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)

            Text("Connecting to stream...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text("Playback Error")
                .font(.headline)
                .foregroundColor(.white)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                playerController.retryPlayback()
            }
            .buttonStyle(.bordered)
            .tint(Color(red: 1, green: 252/255, blue: 0))

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        VStack {
            // Top Bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .center) {
                    Text(feed.name)
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Image(systemName: feed.streamProtocol.iconName)
                            .font(.caption)
                        Text(feed.streamProtocol.displayName)
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }

                Spacer()

                Button(action: { showInfo.toggle() }) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            .padding(.top, 50)

            Spacer()

            // Center Controls
            HStack(spacing: 40) {
                Button(action: { playerController.seekBackward() }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }

                Button(action: { playerController.togglePlayPause() }) {
                    Image(systemName: playerController.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }

                Button(action: { playerController.seekForward() }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Bottom Bar - Progress and Status
            VStack(spacing: 8) {
                // Status indicator
                HStack {
                    if playerController.isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.red)
                        }
                    } else {
                        Text(playerController.currentTimeString)
                            .font(.caption)
                            .foregroundColor(.white)

                        Spacer()

                        Text(playerController.durationString)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }

                // Progress bar (if not live)
                if !playerController.isLive && playerController.duration > 0 {
                    Slider(
                        value: Binding(
                            get: { playerController.currentTime },
                            set: { playerController.seek(to: $0) }
                        ),
                        in: 0...playerController.duration
                    )
                    .accentColor(Color(red: 1, green: 252/255, blue: 0))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.7)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .sheet(isPresented: $showInfo) {
            FeedInfoSheet(feed: feed)
        }
    }

    // MARK: - Helper Methods

    private func setupPlayer() {
        playerController.setupPlayer(for: feed)
        startControlsTimer()
    }

    private func cleanup() {
        playerController.cleanup()
        controlsTimer?.invalidate()
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls.toggle()
        }
        if showControls {
            startControlsTimer()
        } else {
            controlsTimer?.invalidate()
        }
    }

    private func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
            withAnimation {
                showControls = false
            }
        }
    }
}

// MARK: - Video Player Controller

class VideoPlayerController: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLive = true

    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var currentFeed: VideoFeed?

    var currentTimeString: String {
        formatTime(currentTime)
    }

    var durationString: String {
        duration > 0 ? formatTime(duration) : "--:--"
    }

    func setupPlayer(for feed: VideoFeed) {
        currentFeed = feed

        guard let url = feed.urlObject else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        // Check if protocol is supported
        guard feed.streamProtocol.isNativelySupported else {
            errorMessage = VideoStreamError.unsupportedProtocol.localizedDescription
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        setupObservers()
        player?.play()
        isPlaying = true

        // Mark feed as accessed
        VideoStreamService.shared.markFeedAccessed(feed)
    }

    private func setupObservers() {
        guard let player = player else { return }

        // Observe player status
        player.currentItem?.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    self?.isLoading = false
                    self?.updateDuration()
                case .failed:
                    self?.isLoading = false
                    self?.errorMessage = player.currentItem?.error?.localizedDescription ?? "Playback failed"
                default:
                    break
                }
            }
            .store(in: &cancellables)

        // Observe playback time
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }

        // Observe buffering
        player.currentItem?.publisher(for: \.isPlaybackBufferEmpty)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEmpty in
                if isEmpty {
                    self?.isLoading = true
                } else {
                    self?.isLoading = false
                }
            }
            .store(in: &cancellables)

        // Observe for errors
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    self?.errorMessage = error.localizedDescription
                }
            }
            .store(in: &cancellables)
    }

    private func updateDuration() {
        guard let item = player?.currentItem else { return }

        let itemDuration = item.duration
        if itemDuration.isIndefinite {
            isLive = true
            duration = 0
        } else {
            isLive = false
            duration = itemDuration.seconds
        }
    }

    func togglePlayPause() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime)
    }

    func seekForward() {
        let newTime = min(currentTime + 10, duration > 0 ? duration : currentTime + 10)
        seek(to: newTime)
    }

    func seekBackward() {
        let newTime = max(currentTime - 10, 0)
        seek(to: newTime)
    }

    func retryPlayback() {
        guard let feed = currentFeed else { return }
        cleanup()
        setupPlayer(for: feed)
    }

    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
        cancellables.removeAll()
        timeObserver = nil
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Video Player Representable (UIKit Bridge)

struct VideoPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = true

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

// MARK: - Feed Info Sheet

struct FeedInfoSheet: View {
    let feed: VideoFeed
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Stream Details") {
                    HStack { Text("Name"); Spacer(); Text(feed.name).foregroundColor(.gray) }
                    HStack { Text("Protocol"); Spacer(); Text(feed.streamProtocol.displayName).foregroundColor(.gray) }
                    HStack { Text("Created"); Spacer(); Text(feed.createdAt.formatted()).foregroundColor(.gray) }
                    HStack { Text("Last Accessed"); Spacer(); Text(feed.lastAccessed.formatted()).foregroundColor(.gray) }
                }

                Section("URL") {
                    Text(feed.url)
                        .font(.caption)
                }

                if let notes = feed.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                    }
                }

                if feed.hasLocation, let coord = feed.coordinate {
                    Section("Location") {
                        HStack { Text("Latitude"); Spacer(); Text(String(format: "%.6f", coord.latitude)).foregroundColor(.gray) }
                        HStack { Text("Longitude"); Spacer(); Text(String(format: "%.6f", coord.longitude)).foregroundColor(.gray) }
                    }
                }
            }
            .navigationTitle("Stream Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
