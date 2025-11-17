//
//  TrackRecordingButton.swift
//  OmniTAKMobile
//
//  Compact recording button for main map UI with pulsing indicator
//

import SwiftUI

// MARK: - Track Recording Button

struct TrackRecordingButton: View {
    @ObservedObject var recordingService: TrackRecordingService
    var onTap: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                Circle()
                    .fill(Color(hex: "#1E1E1E").opacity(0.95))
                    .frame(width: 50, height: 50)

                // Pulsing ring when recording
                if recordingService.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 3)
                        .frame(width: 50, height: 50)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                }

                // Icon
                if recordingService.isRecording {
                    Circle()
                        .fill(recordingService.isPaused ? Color.orange : Color.red)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "record.circle")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
            .shadow(color: Color.black.opacity(0.3), radius: 4)
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Expanded Recording Button

struct ExpandedRecordingButton: View {
    @ObservedObject var recordingService: TrackRecordingService
    var onTap: () -> Void
    var onStopTap: () -> Void

    @State private var isPulsing = false

    var body: some View {
        if recordingService.isRecording {
            HStack(spacing: 12) {
                // Recording indicator
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .scaleEffect(isPulsing ? 1.2 : 1.0)
                        .opacity(isPulsing ? 0.5 : 1)
                        .animation(
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true),
                            value: isPulsing
                        )

                    Circle()
                        .fill(recordingService.isPaused ? Color.orange : Color.red)
                        .frame(width: 16, height: 16)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(recordingService.isPaused ? "PAUSED" : "RECORDING")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(recordingService.isPaused ? .orange : .red)

                    Text(recordingService.formattedElapsedTime)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }

                Spacer()

                // Quick stats
                VStack(alignment: .trailing, spacing: 2) {
                    Text(recordingService.formattedLiveDistance)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#FFFC00"))

                    Text("\(recordingService.livePointCount) pts")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#888888"))
                }

                // Stop button
                Button(action: onStopTap) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.red)
                        .clipShape(Circle())
                }

                // Expand/Menu button
                Button(action: onTap) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                        .frame(width: 36, height: 36)
                        .background(Color(hex: "#3A3A3A"))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "#1E1E1E").opacity(0.95))
            .cornerRadius(25)
            .shadow(color: Color.black.opacity(0.3), radius: 8)
            .onAppear {
                isPulsing = true
            }
        } else {
            // Not recording - show simple button
            TrackRecordingButton(recordingService: recordingService, onTap: onTap)
        }
    }
}

// MARK: - Floating Recording Button

struct FloatingRecordingButton: View {
    @ObservedObject var recordingService: TrackRecordingService
    @State private var showingRecordingPanel = false
    @State private var showingTrackList = false
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 12) {
            if recordingService.isRecording {
                // Compact recording status
                compactRecordingStatus
            }

            HStack(spacing: 8) {
                // Recording button
                Button(action: {
                    showingRecordingPanel = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#1E1E1E").opacity(0.95))
                            .frame(width: 44, height: 44)

                        if recordingService.isRecording {
                            // Pulsing effect
                            Circle()
                                .stroke(Color.red.opacity(0.4), lineWidth: 2)
                                .frame(width: 44, height: 44)
                                .scaleEffect(isPulsing ? 1.4 : 1.0)
                                .opacity(isPulsing ? 0 : 0.8)
                                .animation(
                                    Animation.easeOut(duration: 1.2)
                                        .repeatForever(autoreverses: false),
                                    value: isPulsing
                                )

                            Circle()
                                .fill(recordingService.isPaused ? Color.orange : Color.red)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "record.circle")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#FFFC00"))
                        }
                    }
                    .shadow(color: Color.black.opacity(0.3), radius: 4)
                }

                // Track list button
                Button(action: {
                    showingTrackList = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#1E1E1E").opacity(0.95))
                            .frame(width: 44, height: 44)

                        Image(systemName: "list.bullet")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                    }
                    .shadow(color: Color.black.opacity(0.3), radius: 4)
                }
            }
        }
        .onAppear {
            isPulsing = true
        }
        .sheet(isPresented: $showingRecordingPanel) {
            RecordingPanelSheet(recordingService: recordingService)
        }
        .sheet(isPresented: $showingTrackList) {
            TrackListView(recordingService: recordingService)
        }
    }

    private var compactRecordingStatus: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(recordingService.isPaused ? Color.orange : Color.red)
                .frame(width: 8, height: 8)

            Text(recordingService.formattedElapsedTime)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white)

            Text(recordingService.formattedLiveDistance)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#FFFC00"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: "#1E1E1E").opacity(0.95))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 4)
    }
}

// MARK: - Recording Panel Sheet

struct RecordingPanelSheet: View {
    @ObservedObject var recordingService: TrackRecordingService
    @Environment(\.dismiss) private var dismiss
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E").ignoresSafeArea()

                VStack(spacing: 20) {
                    TrackRecordingView(recordingService: recordingService)
                        .padding()

                    Spacer()
                }
            }
            .navigationTitle("Track Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                TrackRecordingConfigurationView(recordingService: recordingService)
            }
        }
    }
}

// MARK: - Quick Record Button

struct QuickRecordButton: View {
    @ObservedObject var recordingService: TrackRecordingService
    @State private var isPulsing = false

    var body: some View {
        Button(action: {
            if recordingService.isRecording {
                _ = recordingService.stopRecording()
            } else {
                recordingService.startRecording()
            }
        }) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#1E1E1E").opacity(0.95))
                    .frame(width: 60, height: 60)

                // Pulsing border when recording
                if recordingService.isRecording {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .frame(width: 60, height: 60)
                        .scaleEffect(isPulsing ? 1.1 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                        .animation(
                            Animation.easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                }

                // Icon
                VStack(spacing: 4) {
                    if recordingService.isRecording {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "record.circle")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "#FFFC00"))
                    }

                    if recordingService.isRecording {
                        Text(recordingService.formattedElapsedTime)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    } else {
                        Text("REC")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "#888888"))
                    }
                }
            }
            .shadow(color: Color.black.opacity(0.3), radius: 4)
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Preview

struct TrackRecordingButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            TrackRecordingButton(
                recordingService: TrackRecordingService.shared,
                onTap: { }
            )

            ExpandedRecordingButton(
                recordingService: TrackRecordingService.shared,
                onTap: { },
                onStopTap: { }
            )
            .frame(width: 350)

            FloatingRecordingButton(
                recordingService: TrackRecordingService.shared
            )

            QuickRecordButton(
                recordingService: TrackRecordingService.shared
            )
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .previewLayout(.sizeThatFits)
    }
}
