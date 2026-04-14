import SwiftUI
import os

extension Logger {
    static let takNetwork = Logger(subsystem: "com.omnitak.mobile", category: "tak.network")
    static let takCoT = Logger(subsystem: "com.omnitak.mobile", category: "tak.cot")
    static let authEnrollment = Logger(subsystem: "com.omnitak.mobile", category: "auth.enrollment")
    static let map = Logger(subsystem: "com.omnitak.mobile", category: "map")
    static let adsb = Logger(subsystem: "com.omnitak.mobile", category: "adsb")
    static let military = Logger(subsystem: "com.omnitak.mobile", category: "military")
    static let meshtastic = Logger(subsystem: "com.omnitak.mobile", category: "meshtastic")
    static let ui = Logger(subsystem: "com.omnitak.mobile", category: "ui")
}

@main
struct OmniTAKMobileApp: App {
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        // Eagerly initialize the Meshtastic manager so its COT bridge is wired
        // into TAKService at launch. Without this, mesh nodes would only
        // appear on the map after a Meshtastic view is opened.
        _ = MeshtasticManager.shared
        Logger.meshtastic.info("MeshtasticManager + CoT bridge initialized at launch")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ATAKMapView()
                // Main map view with ATAK-style interface
                // All features integrated: Chat, Filters, Drawing, Offline Maps, Enhanced Markers

                // NEW FEATURES (2025-11):
                // - Certificate Enrollment: QR code scanning for TAK server certificates
                // - CoT Receiving: Complete incoming message handling
                // - Emergency Beacon: SOS/Panic functionality
                // - KML/KMZ Import: Geographic data file support
                // - Photo Sharing: Image attachments in chat
                // - Deep Link Enrollment: tak:// URLs for OpenTAKServer QR codes

                // Enrollment overlay
                if deepLinkHandler.isProcessing {
                    DeepLinkEnrollmentOverlay(isProcessing: true, message: "Enrolling with server...")
                }

                if deepLinkHandler.showEnrollmentSuccess {
                    DeepLinkEnrollmentOverlay(
                        isProcessing: false,
                        message: "Connected to \(deepLinkHandler.enrolledServerName ?? "server")!",
                        isSuccess: true
                    )
                    .onAppear {
                        // Auto-dismiss after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            deepLinkHandler.showEnrollmentSuccess = false
                        }
                    }
                }

                if let error = deepLinkHandler.lastError {
                    DeepLinkEnrollmentOverlay(isProcessing: false, message: error, isError: true)
                        .onTapGesture {
                            deepLinkHandler.lastError = nil
                        }
                }
            }
            .onOpenURL { url in
                // Handle tak:// deep links (QR code enrollment)
                deepLinkHandler.handleURL(url)
            }
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { newValue in if !newValue { hasCompletedOnboarding = true } }
            )) {
                FirstTimeOnboarding(onComplete: {
                    hasCompletedOnboarding = true
                })
            }
        }
    }
}

// MARK: - Deep Link Enrollment Overlay

struct DeepLinkEnrollmentOverlay: View {
    let isProcessing: Bool
    let message: String
    var isSuccess: Bool = false
    var isError: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            if isProcessing {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if isSuccess {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
            } else if isError {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
            }

            Text(message)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if isError {
                Text("Tap to dismiss")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.85))
        )
        .shadow(radius: 20)
    }
}
