//
//  GeofenceService.swift
//  OmniTAKMobile
//
//  Core monitoring service for geofencing
//  Handles location monitoring, entry/exit detection, and dwell time tracking
//

import Foundation
import CoreLocation
import Combine
import UserNotifications
import UIKit
import AudioToolbox

// MARK: - Geofence Service

class GeofenceService: NSObject, ObservableObject {
    static let shared = GeofenceService()

    // Published properties
    @Published var activeAlerts: [GeofenceAlert] = []
    @Published var recentEvents: [GeofenceEvent] = []
    @Published var isMonitoring: Bool = false
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var monitoringStatus: String = "Not Monitoring"

    // Configuration
    private let maxRecentEvents: Int = 100
    private let maxActiveAlerts: Int = 50
    private let locationUpdateInterval: TimeInterval = 5.0
    private let dwellCheckInterval: TimeInterval = 10.0

    // Location management
    private var locationManager: CLLocationManager!
    private var dwellTimer: Timer?

    // Persistence keys
    private let alertsKey = "com.omnitak.geofence.alerts"
    private let eventsKey = "com.omnitak.geofence.events"

    // User info
    private var userId: String = "OmniTAK-iOS"
    private var userCallsign: String = "OmniTAK-iOS"

    // Services
    private var takService: TAKService?
    private var geofenceManager: GeofenceManager?

    private override init() {
        super.init()
        setupLocationManager()
        loadPersistentData()
        requestNotificationPermissions()
        // Auto-configure with shared GeofenceManager
        geofenceManager = GeofenceManager.shared
    }

    // MARK: - Geofence Proxy Properties

    var geofences: [Geofence] {
        geofenceManager?.geofences ?? []
    }

    // MARK: - Geofence Management

    func addGeofence(_ geofence: Geofence) {
        geofenceManager?.addGeofence(geofence)
    }

    func deleteGeofence(_ geofence: Geofence) {
        geofenceManager?.deleteGeofence(geofence)
    }

    func toggleGeofence(_ geofence: Geofence) {
        geofenceManager?.toggleGeofence(geofence)
    }

    func clearAlerts() {
        clearAllAlerts()
    }

    // MARK: - Configuration

    func configure(takService: TAKService, userId: String, callsign: String) {
        self.takService = takService
        self.userId = userId
        self.userCallsign = callsign
    }

    func setGeofenceManager(_ manager: GeofenceManager) {
        self.geofenceManager = manager
    }

    // MARK: - Location Manager Setup

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
    }

    // MARK: - Monitoring Control

    func startMonitoring() {
        guard !isMonitoring else { return }

        let authStatus = locationManager.authorizationStatus

        switch authStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()
            startDwellTimer()
            isMonitoring = true
            monitoringStatus = "Monitoring (When In Use)"
        case .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
            startDwellTimer()
            isMonitoring = true
            monitoringStatus = "Monitoring (Always)"
        case .denied, .restricted:
            monitoringStatus = "Location Access Denied"
            print("Geofence: Location access denied")
        @unknown default:
            monitoringStatus = "Unknown Authorization Status"
        }

        print("Geofence monitoring started: \(monitoringStatus)")
    }

    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        stopDwellTimer()
        isMonitoring = false
        monitoringStatus = "Not Monitoring"
        print("Geofence monitoring stopped")
    }

    // MARK: - Dwell Time Tracking

    private func startDwellTimer() {
        stopDwellTimer()
        dwellTimer = Timer.scheduledTimer(withTimeInterval: dwellCheckInterval, repeats: true) { [weak self] _ in
            self?.checkDwellTimes()
        }
    }

    private func stopDwellTimer() {
        dwellTimer?.invalidate()
        dwellTimer = nil
    }

    private func checkDwellTimes() {
        guard let manager = geofenceManager else { return }

        for geofence in manager.geofences where geofence.isActive {
            if geofence.userInsideGeofence,
               let entryTime = geofence.entryTime,
               geofence.dwellTimeThreshold > 0 {

                let currentDwellTime = Date().timeIntervalSince(entryTime)

                if currentDwellTime >= geofence.dwellTimeThreshold {
                    // Check if we've already alerted for this dwell period
                    let hasRecentDwellAlert = recentEvents.contains { event in
                        event.geofenceId == geofence.id &&
                        event.eventType == .dwell &&
                        abs(event.timestamp.timeIntervalSince(entryTime)) < 60
                    }

                    if !hasRecentDwellAlert {
                        triggerDwellAlert(for: geofence, duration: currentDwellTime)
                    }
                }
            }
        }
    }

    // MARK: - Geofence Checking

    func checkGeofences(for location: CLLocationCoordinate2D) {
        guard let manager = geofenceManager else { return }

        currentLocation = location

        for i in 0..<manager.geofences.count {
            let geofence = manager.geofences[i]
            guard geofence.isActive else { continue }

            let isInside = geofence.containsPoint(location)
            let wasInside = geofence.userInsideGeofence

            if isInside && !wasInside {
                // Entry event
                manager.updateGeofenceEntryState(geofence.id, isInside: true)

                if geofence.alertOnEntry {
                    triggerEntryAlert(for: geofence, at: location)
                }
            } else if !isInside && wasInside {
                // Exit event
                let dwellDuration = geofence.entryTime != nil ?
                    Date().timeIntervalSince(geofence.entryTime!) : 0

                manager.updateGeofenceEntryState(geofence.id, isInside: false)

                if geofence.alertOnExit {
                    triggerExitAlert(for: geofence, at: location, dwellDuration: dwellDuration)
                }
            }
        }
    }

    // MARK: - Alert Triggering

    private func triggerEntryAlert(for geofence: Geofence, at location: CLLocationCoordinate2D) {
        let message = "Entered geofence '\(geofence.name)'"

        let event = GeofenceEvent(
            geofenceId: geofence.id,
            geofenceName: geofence.name,
            eventType: .entry,
            coordinate: location,
            userId: userId
        )

        let alert = GeofenceAlert(
            geofenceId: geofence.id,
            geofenceName: geofence.name,
            eventType: .entry,
            message: message
        )

        addEvent(event)
        addAlert(alert)
        provideHapticFeedback(.heavy)
        sendLocalNotification(title: "Geofence Entry", body: message)

        // Send CoT event
        if let takService = takService {
            let cotXML = GeofenceCoTGenerator.generateEventCoT(for: event, callsign: userCallsign)
            _ = takService.sendCoT(xml: cotXML)
        }

        // Update last triggered
        geofenceManager?.updateLastTriggered(geofence.id)

        print("GEOFENCE ENTRY: \(geofence.name)")
    }

    private func triggerExitAlert(for geofence: Geofence, at location: CLLocationCoordinate2D, dwellDuration: TimeInterval) {
        let durationStr = formatDuration(dwellDuration)
        let message = "Exited geofence '\(geofence.name)' after \(durationStr)"

        let event = GeofenceEvent(
            geofenceId: geofence.id,
            geofenceName: geofence.name,
            eventType: .exit,
            coordinate: location,
            userId: userId,
            dwellDuration: dwellDuration
        )

        let alert = GeofenceAlert(
            geofenceId: geofence.id,
            geofenceName: geofence.name,
            eventType: .exit,
            message: message
        )

        addEvent(event)
        addAlert(alert)
        provideHapticFeedback(.medium)
        sendLocalNotification(title: "Geofence Exit", body: message)

        // Send CoT event
        if let takService = takService {
            let cotXML = GeofenceCoTGenerator.generateEventCoT(for: event, callsign: userCallsign)
            _ = takService.sendCoT(xml: cotXML)
        }

        // Update last triggered
        geofenceManager?.updateLastTriggered(geofence.id)

        print("GEOFENCE EXIT: \(geofence.name) (dwell: \(durationStr))")
    }

    private func triggerDwellAlert(for geofence: Geofence, duration: TimeInterval) {
        guard let location = currentLocation else { return }

        let durationStr = formatDuration(duration)
        let thresholdStr = formatDuration(geofence.dwellTimeThreshold)
        let message = "Dwell threshold of \(thresholdStr) exceeded in '\(geofence.name)' (current: \(durationStr))"

        let event = GeofenceEvent(
            geofenceId: geofence.id,
            geofenceName: geofence.name,
            eventType: .dwell,
            coordinate: location,
            userId: userId,
            dwellDuration: duration
        )

        let alert = GeofenceAlert(
            geofenceId: geofence.id,
            geofenceName: geofence.name,
            eventType: .dwell,
            message: message
        )

        addEvent(event)
        addAlert(alert)
        provideHapticFeedback(.warning)
        sendLocalNotification(title: "Geofence Dwell Alert", body: message)

        // Send CoT event
        if let takService = takService {
            let cotXML = GeofenceCoTGenerator.generateEventCoT(for: event, callsign: userCallsign)
            _ = takService.sendCoT(xml: cotXML)
        }

        print("GEOFENCE DWELL: \(geofence.name) - \(durationStr)")
    }

    // MARK: - Event & Alert Management

    private func addEvent(_ event: GeofenceEvent) {
        recentEvents.insert(event, at: 0)
        if recentEvents.count > maxRecentEvents {
            recentEvents = Array(recentEvents.prefix(maxRecentEvents))
        }
        savePersistentData()
    }

    private func addAlert(_ alert: GeofenceAlert) {
        activeAlerts.insert(alert, at: 0)
        if activeAlerts.count > maxActiveAlerts {
            activeAlerts = Array(activeAlerts.prefix(maxActiveAlerts))
        }
        savePersistentData()
    }

    func dismissAlert(_ alert: GeofenceAlert) {
        if let index = activeAlerts.firstIndex(where: { $0.id == alert.id }) {
            activeAlerts[index].isDismissed = true
            activeAlerts[index].isRead = true
        }
        savePersistentData()
    }

    func markAlertAsRead(_ alert: GeofenceAlert) {
        if let index = activeAlerts.firstIndex(where: { $0.id == alert.id }) {
            activeAlerts[index].isRead = true
        }
        savePersistentData()
    }

    func clearDismissedAlerts() {
        activeAlerts.removeAll { $0.isDismissed }
        savePersistentData()
    }

    func clearAllAlerts() {
        activeAlerts.removeAll()
        savePersistentData()
    }

    var unreadAlertCount: Int {
        activeAlerts.filter { !$0.isRead && !$0.isDismissed }.count
    }

    var pendingAlerts: [GeofenceAlert] {
        activeAlerts.filter { !$0.isDismissed }
    }

    // MARK: - Notifications

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else if granted {
                print("Notification permissions granted")
            }
        }
    }

    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "GEOFENCE_ALERT"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    // MARK: - Haptic Feedback

    private func provideHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Persistence

    private func savePersistentData() {
        // Save alerts
        if let alertsData = try? JSONEncoder().encode(activeAlerts) {
            UserDefaults.standard.set(alertsData, forKey: alertsKey)
        }

        // Save events
        if let eventsData = try? JSONEncoder().encode(recentEvents) {
            UserDefaults.standard.set(eventsData, forKey: eventsKey)
        }
    }

    private func loadPersistentData() {
        // Load alerts
        if let alertsData = UserDefaults.standard.data(forKey: alertsKey),
           let alerts = try? JSONDecoder().decode([GeofenceAlert].self, from: alertsData) {
            activeAlerts = alerts
        }

        // Load events
        if let eventsData = UserDefaults.standard.data(forKey: eventsKey),
           let events = try? JSONDecoder().decode([GeofenceEvent].self, from: eventsData) {
            recentEvents = events
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))

        if minutes > 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    // MARK: - Statistics

    func getStatistics(for geofenceId: UUID) -> GeofenceStatistics {
        let relevantEvents = recentEvents.filter { $0.geofenceId == geofenceId }

        let entries = relevantEvents.filter { $0.eventType == .entry }.count
        let exits = relevantEvents.filter { $0.eventType == .exit }.count

        let totalDwell = relevantEvents
            .filter { $0.eventType == .exit }
            .compactMap { $0.dwellDuration }
            .reduce(0, +)

        let avgDwell = exits > 0 ? totalDwell / Double(exits) : 0

        return GeofenceStatistics(
            totalEntries: entries,
            totalExits: exits,
            totalDwellTime: totalDwell,
            averageDwellTime: avgDwell,
            lastEvent: relevantEvents.first
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension GeofenceService: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let coordinate = location.coordinate
        checkGeofences(for: coordinate)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            if isMonitoring {
                locationManager.startMonitoringSignificantLocationChanges()
                monitoringStatus = "Monitoring (Always)"
            }
        case .authorizedWhenInUse:
            if isMonitoring {
                monitoringStatus = "Monitoring (When In Use)"
            }
        case .denied, .restricted:
            stopMonitoring()
            monitoringStatus = "Location Access Denied"
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        monitoringStatus = "Error: \(error.localizedDescription)"
    }
}

// MARK: - UIImpactFeedbackGenerator Extension

extension UIImpactFeedbackGenerator.FeedbackStyle {
    static var warning: UIImpactFeedbackGenerator.FeedbackStyle {
        return .rigid
    }
}
