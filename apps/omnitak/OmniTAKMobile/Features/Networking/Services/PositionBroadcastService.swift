//
//  PositionBroadcastService.swift
//  OmniTAKMobile
//
//  Automatic Position Location Information (PLI) broadcasting service
//  Core TAK feature for situational awareness
//

import Foundation
import CoreLocation
import Combine
import UIKit

// MARK: - Position Broadcast Service

class PositionBroadcastService: ObservableObject {
    static let shared = PositionBroadcastService()

    // MARK: - Published Properties

    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startBroadcasting()
            } else {
                stopBroadcasting()
            }
            saveBroadcastSettings()
        }
    }

    @Published var updateInterval: TimeInterval = 30.0 {
        didSet {
            if isEnabled {
                restartTimer()
            }
            saveBroadcastSettings()
        }
    }

    @Published var staleTime: TimeInterval = 180.0 {
        didSet {
            saveBroadcastSettings()
        }
    }

    @Published var lastBroadcastTime: Date?
    @Published var broadcastCount: Int = 0
    @Published var lastError: String?
    @Published var batteryLevel: Float = 1.0
    @Published var deviceStatus: String = "Operational"

    // User identity
    @Published var userCallsign: String = "ALPHA-1" {
        didSet {
            saveBroadcastSettings()
        }
    }

    @Published var userUID: String
    @Published var teamColor: String = "Cyan" {
        didSet {
            saveBroadcastSettings()
        }
    }

    @Published var teamRole: String = "Team Member" {
        didSet {
            saveBroadcastSettings()
        }
    }

    // MARK: - Private Properties

    private var broadcastTimer: Timer?
    private var takService: TAKService?
    private var locationManager: LocationManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Generate or load UID
        if let savedUID = UserDefaults.standard.string(forKey: "selfPositionUID") {
            self.userUID = savedUID
        } else {
            let newUID = "ANDROID-\(UUID().uuidString)"
            self.userUID = newUID
            UserDefaults.standard.set(newUID, forKey: "selfPositionUID")
        }

        loadBroadcastSettings()
        startBatteryMonitoring()

        print("PositionBroadcastService initialized with UID: \(userUID)")
    }

    // MARK: - Configuration

    func configure(takService: TAKService, locationManager: LocationManager) {
        self.takService = takService
        self.locationManager = locationManager

        // Auto-start if enabled
        if isEnabled && broadcastTimer == nil {
            startBroadcasting()
        }
    }

    // MARK: - Broadcasting Control

    func startBroadcasting() {
        guard takService != nil, locationManager != nil else {
            print("Cannot start broadcasting: services not configured")
            lastError = "Services not configured"
            return
        }

        stopBroadcasting()

        // Initial broadcast
        broadcastPosition()

        // Start timer
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.broadcastPosition()
        }

        print("Position broadcasting started with interval: \(updateInterval)s")
    }

    func stopBroadcasting() {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        print("Position broadcasting stopped")
    }

    private func restartTimer() {
        if isEnabled {
            startBroadcasting()
        }
    }

    // MARK: - Position Broadcast

    func broadcastPosition() {
        guard let takService = takService,
              let location = locationManager?.location else {
            lastError = "No location available"
            return
        }

        let cotXML = generateSelfSACoT(location: location)
        let success = takService.sendCoT(xml: cotXML)

        if success {
            lastBroadcastTime = Date()
            broadcastCount += 1
            lastError = nil
            print("Position broadcast #\(broadcastCount) at \(location.coordinate)")
        } else {
            lastError = "Failed to send position"
            print("Failed to broadcast position")
        }
    }

    // MARK: - CoT Message Generation

    private func generateSelfSACoT(location: CLLocation) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(staleTime)

        let timeStr = dateFormatter.string(from: now)
        let startStr = dateFormatter.string(from: now)
        let staleStr = dateFormatter.string(from: stale)

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let hae = location.altitude
        let ce = location.horizontalAccuracy
        let le = location.verticalAccuracy

        // Speed in m/s, course in degrees
        let speed = location.speed >= 0 ? location.speed : 0
        let course = location.course >= 0 ? location.course : 0

        // CoT type: a-f-G-U-C (friendly ground unit combat)
        let cotType = "a-f-G-U-C"

        // Generate XML
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(userUID)" type="\(cotType)" time="\(timeStr)" start="\(startStr)" stale="\(staleStr)" how="m-g">
            <point lat="\(lat)" lon="\(lon)" hae="\(hae)" ce="\(ce)" le="\(le)"/>
            <detail>
                <contact callsign="\(escapeXML(userCallsign))" endpoint="*:-1:stcp"/>
                <__group name="\(teamColor)" role="\(teamRole)"/>
                <status battery="\(Int(batteryLevel * 100))"/>
                <takv device="\(deviceModel)" platform="OmniTAK-iOS" os="iOS \(iosVersion)" version="1.0.0"/>
                <track speed="\(String(format: "%.2f", speed))" course="\(String(format: "%.2f", course))"/>
                <precisionlocation altsrc="GPS" geopointsrc="GPS"/>
                <uid Droid="\(escapeXML(userCallsign))"/>
            </detail>
        </event>
        """

        return xml
    }

    // MARK: - Battery Monitoring

    private func startBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBatteryLevel()

        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateBatteryLevel()
            }
            .store(in: &cancellables)
    }

    private func updateBatteryLevel() {
        let level = UIDevice.current.batteryLevel
        if level >= 0 {
            batteryLevel = level
        }

        // Update device status based on battery
        if batteryLevel < 0.1 {
            deviceStatus = "Low Battery"
        } else if batteryLevel < 0.2 {
            deviceStatus = "Battery Warning"
        } else {
            deviceStatus = "Operational"
        }
    }

    // MARK: - Device Info

    private var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    private var iosVersion: String {
        UIDevice.current.systemVersion
    }

    // MARK: - Persistence

    private func saveBroadcastSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "positionBroadcastEnabled")
        UserDefaults.standard.set(updateInterval, forKey: "positionUpdateInterval")
        UserDefaults.standard.set(staleTime, forKey: "positionStaleTime")
        UserDefaults.standard.set(userCallsign, forKey: "userCallsign")
        UserDefaults.standard.set(teamColor, forKey: "teamColor")
        UserDefaults.standard.set(teamRole, forKey: "teamRole")
    }

    private func loadBroadcastSettings() {
        if UserDefaults.standard.object(forKey: "positionBroadcastEnabled") != nil {
            isEnabled = UserDefaults.standard.bool(forKey: "positionBroadcastEnabled")
        }

        let savedInterval = UserDefaults.standard.double(forKey: "positionUpdateInterval")
        if savedInterval > 0 {
            updateInterval = savedInterval
        }

        let savedStale = UserDefaults.standard.double(forKey: "positionStaleTime")
        if savedStale > 0 {
            staleTime = savedStale
        }

        if let savedCallsign = UserDefaults.standard.string(forKey: "userCallsign") {
            userCallsign = savedCallsign
        }

        if let savedTeamColor = UserDefaults.standard.string(forKey: "teamColor") {
            teamColor = savedTeamColor
        }

        if let savedTeamRole = UserDefaults.standard.string(forKey: "teamRole") {
            teamRole = savedTeamRole
        }
    }

    // MARK: - Helpers

    private func escapeXML(_ string: String) -> String {
        var escaped = string
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }

    // MARK: - Manual Broadcast

    func forceBroadcast() {
        broadcastPosition()
    }

    // MARK: - Statistics

    var timeSinceLastBroadcast: String {
        guard let lastTime = lastBroadcastTime else {
            return "Never"
        }

        let interval = Date().timeIntervalSince(lastTime)
        if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }

    var nextBroadcastIn: String {
        guard let lastTime = lastBroadcastTime, isEnabled else {
            return "N/A"
        }

        let nextTime = lastTime.addingTimeInterval(updateInterval)
        let remaining = nextTime.timeIntervalSince(Date())

        if remaining <= 0 {
            return "Now"
        } else if remaining < 60 {
            return "\(Int(remaining))s"
        } else {
            return "\(Int(remaining / 60))m \(Int(remaining.truncatingRemainder(dividingBy: 60)))s"
        }
    }

    deinit {
        stopBroadcasting()
    }
}
