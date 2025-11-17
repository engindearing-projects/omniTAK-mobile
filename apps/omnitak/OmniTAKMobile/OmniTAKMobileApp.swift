import SwiftUI

@main
struct OmniTAKMobileApp: App {
    var body: some Scene {
        WindowGroup {
            ATAKMapView()
            // Main map view with ATAK-style interface
            // All features integrated: Chat, Filters, Drawing, Offline Maps, Enhanced Markers

            // NEW FEATURES (2025-11):
            // - Certificate Enrollment: QR code scanning for TAK server certificates
            // - CoT Receiving: Complete incoming message handling
            // - Emergency Beacon: SOS/Panic functionality
            // - KML/KMZ Import: Geographic data file support
            // - Photo Sharing: Image attachments in chat
        }
    }
}
