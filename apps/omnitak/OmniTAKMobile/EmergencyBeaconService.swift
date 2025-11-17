//
//  EmergencyBeaconService.swift
//  OmniTAKMobile
//
//  Emergency beacon/SOS service for safety-critical situations
//  Generates and broadcasts emergency CoT messages following ATAK standards
//

import Foundation
import Combine
import CoreLocation
import UIKit
import AudioToolbox

// MARK: - Emergency Types

enum EmergencyType: String, CaseIterable {
    case alert911 = "911 Alert"
    case inContact = "In Contact"
    case alert = "Alert"
    case cancel = "Cancel"

    var cotType: String {
        switch self {
        case .alert911:
            return "b-a-o-tbl"
        case .inContact:
            return "a-f-G-U-C-I"
        case .alert:
            return "b-a-o-tbl"
        case .cancel:
            return "b-a-o-can"
        }
    }

    var displayName: String {
        switch self {
        case .alert911:
            return "911 Emergency"
        case .inContact:
            return "In Contact"
        case .alert:
            return "Alert"
        case .cancel:
            return "Cancel Emergency"
        }
    }

    var icon: String {
        switch self {
        case .alert911:
            return "phone.fill"
        case .inContact:
            return "person.wave.2.fill"
        case .alert:
            return "exclamationmark.triangle.fill"
        case .cancel:
            return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .alert911:
            return "#FF0000"
        case .inContact:
            return "#FFA500"
        case .alert:
            return "#FF6600"
        case .cancel:
            return "#00FF00"
        }
    }

    var defaultMessage: String {
        switch self {
        case .alert911:
            return "EMERGENCY - NEED 911"
        case .inContact:
            return "IN CONTACT - NEED ASSISTANCE"
        case .alert:
            return "ALERT - ATTENTION NEEDED"
        case .cancel:
            return "EMERGENCY CANCELLED"
        }
    }
}

// MARK: - Emergency State

struct EmergencyState: Codable {
    var isActive: Bool
    var type: String
    var message: String
    var activatedAt: Date?
    var lastBroadcast: Date?
    var broadcastCount: Int

    static var inactive: EmergencyState {
        EmergencyState(
            isActive: false,
            type: "",
            message: "",
            activatedAt: nil,
            lastBroadcast: nil,
            broadcastCount: 0
        )
    }
}

// MARK: - Emergency Beacon Service

class EmergencyBeaconService: ObservableObject {
    static let shared = EmergencyBeaconService()

    // Published state
    @Published var emergencyState: EmergencyState = .inactive
    @Published var isBroadcasting: Bool = false
    @Published var lastBroadcastStatus: String = ""

    // Configuration
    private let broadcastInterval: TimeInterval = 30 // Broadcast every 30 seconds
    private let staleTime: TimeInterval = 120 // Message stale after 2 minutes
    private let userDefaultsKey = "com.omnitak.emergencyState"

    // Services
    private var takService: TAKService?
    private var locationManager: BeaconLocationManager?
    private var broadcastTimer: Timer?

    // User info
    private var userCallsign: String = "OmniTAK-iOS"
    private var userUID: String = ""

    private init() {
        loadState()
        generateUserUID()
    }

    // MARK: - Configuration

    func configure(takService: TAKService, locationManager: BeaconLocationManager, callsign: String) {
        self.takService = takService
        self.locationManager = locationManager
        self.userCallsign = callsign

        // Resume broadcasting if emergency was active
        if emergencyState.isActive {
            startBroadcasting()
        }
    }

    func updateCallsign(_ callsign: String) {
        self.userCallsign = callsign
    }

    private func generateUserUID() {
        userUID = "EMERGENCY-\(UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString)"
    }

    // MARK: - Emergency Activation

    func activateEmergency(type: EmergencyType, message: String? = nil) {
        let finalMessage = message ?? type.defaultMessage

        emergencyState = EmergencyState(
            isActive: true,
            type: type.rawValue,
            message: finalMessage,
            activatedAt: Date(),
            lastBroadcast: nil,
            broadcastCount: 0
        )

        saveState()
        startBroadcasting()

        // Provide haptic feedback
        provideHapticFeedback(.heavy)
        playAlertSound()

        // Send initial broadcast immediately
        sendEmergencyBroadcast()

        print("EMERGENCY ACTIVATED: \(type.displayName) - \(finalMessage)")
    }

    func cancelEmergency() {
        guard emergencyState.isActive else { return }

        // Send cancellation message
        sendCancellationBroadcast()

        stopBroadcasting()

        emergencyState = .inactive
        saveState()

        // Provide feedback
        provideHapticFeedback(.medium)

        print("EMERGENCY CANCELLED")
    }

    // MARK: - Broadcasting

    private func startBroadcasting() {
        guard broadcastTimer == nil else { return }

        isBroadcasting = true

        // Schedule periodic broadcasts
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: broadcastInterval, repeats: true) { [weak self] _ in
            self?.sendEmergencyBroadcast()
        }

        print("Started emergency broadcasting (interval: \(broadcastInterval)s)")
    }

    private func stopBroadcasting() {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        isBroadcasting = false

        print("Stopped emergency broadcasting")
    }

    private func sendEmergencyBroadcast() {
        guard emergencyState.isActive else { return }
        guard let takService = takService else {
            lastBroadcastStatus = "Error: TAKService not configured"
            print("Cannot broadcast emergency: TAKService not configured")
            return
        }

        // Get current location
        let location = locationManager?.location
        let latitude = location?.latitude ?? 0.0
        let longitude = location?.longitude ?? 0.0
        let altitude = locationManager?.altitude ?? 0.0

        // Generate CoT XML
        let xml = generateEmergencyCoT(
            type: EmergencyType(rawValue: emergencyState.type) ?? .alert,
            message: emergencyState.message,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude
        )

        // Send via TAKService
        if takService.sendCoT(xml: xml) {
            emergencyState.lastBroadcast = Date()
            emergencyState.broadcastCount += 1
            saveState()

            lastBroadcastStatus = "Broadcast #\(emergencyState.broadcastCount) sent at \(formattedTime(Date()))"
            print("Emergency broadcast #\(emergencyState.broadcastCount) sent")

            // Provide subtle haptic feedback for each broadcast
            provideHapticFeedback(.light)
        } else {
            lastBroadcastStatus = "Failed to send broadcast"
            print("Failed to send emergency broadcast")
        }
    }

    private func sendCancellationBroadcast() {
        guard let takService = takService else { return }

        let location = locationManager?.location
        let latitude = location?.latitude ?? 0.0
        let longitude = location?.longitude ?? 0.0
        let altitude = locationManager?.altitude ?? 0.0

        let xml = generateEmergencyCoT(
            type: .cancel,
            message: "EMERGENCY CANCELLED",
            latitude: latitude,
            longitude: longitude,
            altitude: altitude
        )

        _ = takService.sendCoT(xml: xml)
        print("Cancellation broadcast sent")
    }

    // MARK: - CoT XML Generation

    private func generateEmergencyCoT(
        type: EmergencyType,
        message: String,
        latitude: Double,
        longitude: Double,
        altitude: Double
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let timeStr = formatter.string(from: now)
        let startStr = formatter.string(from: now)
        let staleStr = formatter.string(from: now.addingTimeInterval(staleTime))

        let uid = "\(userUID)-\(Int(now.timeIntervalSince1970))"

        // Generate emergency CoT XML following ATAK standards
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="\(type.cotType)" how="h-g-i-g-o" time="\(timeStr)" start="\(startStr)" stale="\(staleStr)">
            <point lat="\(latitude)" lon="\(longitude)" hae="\(altitude)" ce="9999" le="9999"/>
            <detail>
                <contact callsign="\(userCallsign)"/>
                <emergency type="\(type.rawValue)">\(escapeXML(message))</emergency>
                <remarks>\(escapeXML(message))</remarks>
                <status readiness="true"/>
                <takv device="\(UIDevice.current.model)" platform="OmniTAK-iOS" os="\(UIDevice.current.systemVersion)" version="1.0.0"/>
                <__group name="Emergency" role="Team Member"/>
            </detail>
        </event>
        """

        return xml
    }

    private func escapeXML(_ string: String) -> String {
        var escaped = string
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }

    // MARK: - Persistence

    private func saveState() {
        if let encoded = try? JSONEncoder().encode(emergencyState) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadState() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let state = try? JSONDecoder().decode(EmergencyState.self, from: data) {
            emergencyState = state
            print("Loaded emergency state: active=\(state.isActive)")
        }
    }

    // MARK: - Feedback

    private func provideHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func playAlertSound() {
        // Play system alert sound
        AudioServicesPlaySystemSound(SystemSoundID(1005)) // SMS tone

        // Vibrate for emphasis
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }

    // MARK: - Helpers

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    var timeSinceActivation: String {
        guard let activatedAt = emergencyState.activatedAt else { return "N/A" }
        let elapsed = Date().timeIntervalSince(activatedAt)
        let minutes = Int(elapsed / 60)
        let seconds = Int(elapsed.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var currentEmergencyType: EmergencyType? {
        guard emergencyState.isActive else { return nil }
        return EmergencyType(rawValue: emergencyState.type)
    }
}

// MARK: - Location Manager Protocol (if not already defined)

protocol LocationManagerProtocol {
    var location: CLLocationCoordinate2D? { get }
}

// Simple location wrapper for compatibility
class BeaconLocationManager: ObservableObject {
    @Published var location: CLLocationCoordinate2D?
    @Published var altitude: Double = 0.0

    private let clLocationManager = CLLocationManager()

    init() {
        clLocationManager.desiredAccuracy = kCLLocationAccuracyBest
        clLocationManager.requestWhenInUseAuthorization()
        clLocationManager.startUpdatingLocation()

        // Update location periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if let clLocation = self?.clLocationManager.location {
                self?.location = clLocation.coordinate
                self?.altitude = clLocation.altitude
            }
        }
    }
}
