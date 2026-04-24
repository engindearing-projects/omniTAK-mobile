//
//  VLCPlayerView.swift
//  OmniTAKMobile
//
//  RTSP and SRT playback via MobileVLCKit. Falls back to an unsupported-protocol
//  view when VLCKit is not linked, so the project still builds without the SPM
//  package. Uses LGPL v2.1+ VLCKit; acknowledgement shown on the Feed Info sheet.
//

import SwiftUI

#if canImport(MobileVLCKit)
import MobileVLCKit

// MARK: - VLC Player View (real implementation)

struct VLCPlayerView: View {
    let feed: VideoFeed
    @StateObject private var controller = VLCPlayerController()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let error = controller.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text("Playback error")
                        .foregroundColor(.white)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") { controller.retry() }
                        .buttonStyle(.bordered)
                        .tint(Color(red: 1, green: 252/255, blue: 0))
                }
            } else {
                VLCVideoViewRepresentable(controller: controller)
                    .ignoresSafeArea()

                if controller.isBuffering {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        }
        .onAppear { controller.start(with: feed) }
        .onDisappear { controller.stop() }
    }
}

// MARK: - VLC Controller

final class VLCPlayerController: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    @Published var isBuffering = true
    @Published var isPlaying = false
    @Published var errorMessage: String?

    let mediaPlayer = VLCMediaPlayer()
    private var currentFeed: VideoFeed?

    override init() {
        super.init()
        mediaPlayer.delegate = self
    }

    func start(with feed: VideoFeed) {
        currentFeed = feed
        errorMessage = nil
        isBuffering = true

        guard let url = feed.urlObject else {
            errorMessage = "Invalid URL"
            isBuffering = false
            return
        }

        let media = VLCMedia(url: url)
        // Low-latency live tuning: drop network cache and frame skipping for lag reduction.
        // Values in ms; 150 is the sweet spot for RTSP IP cameras and SRT listeners.
        media.addOption(":network-caching=150")
        media.addOption(":live-caching=150")
        media.addOption(":clock-jitter=0")
        media.addOption(":clock-synchro=0")
        mediaPlayer.media = media
        mediaPlayer.play()
        isPlaying = true
        VideoStreamService.shared.markFeedAccessed(feed)
    }

    func stop() {
        mediaPlayer.stop()
        isPlaying = false
    }

    func retry() {
        guard let feed = currentFeed else { return }
        stop()
        start(with: feed)
    }

    // MARK: VLCMediaPlayerDelegate

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch self.mediaPlayer.state {
            case .opening, .buffering:
                self.isBuffering = true
                self.errorMessage = nil
            case .playing:
                self.isBuffering = false
                self.isPlaying = true
                self.errorMessage = nil
            case .paused, .stopped, .ended:
                self.isBuffering = false
                self.isPlaying = false
            case .error:
                self.isBuffering = false
                self.isPlaying = false
                self.errorMessage = "Stream failed to open. Check URL, credentials, and network."
            @unknown default:
                break
            }
        }
    }
}

// MARK: - UIKit bridge

struct VLCVideoViewRepresentable: UIViewRepresentable {
    let controller: VLCPlayerController

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        controller.mediaPlayer.drawable = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        controller.mediaPlayer.drawable = uiView
    }
}

#else

// MARK: - Fallback when MobileVLCKit is not linked

struct VLCPlayerView: View {
    let feed: VideoFeed
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text("VLCKit Not Linked")
                .font(.title2).bold()
                .foregroundColor(.white)

            Text("RTSP and SRT playback require MobileVLCKit. Add the Swift package to the Xcode project and rebuild.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text(feed.url)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(3)
                .padding(.horizontal)

            Button(action: { UIPasteboard.general.string = feed.url }) {
                Label("Copy URL", systemImage: "doc.on.clipboard")
                    .foregroundColor(Color(red: 1, green: 252/255, blue: 0))
            }

            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
                .tint(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

#endif
