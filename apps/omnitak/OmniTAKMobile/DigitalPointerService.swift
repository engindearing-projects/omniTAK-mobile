//
//  DigitalPointerService.swift
//  OmniTAKMobile
//
//  Digital Pointer service for sharing temporary map cursor positions
//  Enables real-time tactical coordination through temporary visual markers
//

import Foundation
import Combine
import CoreLocation
import UIKit

// MARK: - Digital Pointer Event

/// Represents a single digital pointer event from a team member
struct DigitalPointerEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let senderCallsign: String
    let senderUID: String
    let coordinate: PointerCodableCoordinate
    let timestamp: Date
    let message: String?
    let color: String
    let expiresAt: Date

    /// Convenience initializer with CLLocationCoordinate2D
    init(
        id: UUID = UUID(),
        senderCallsign: String,
        senderUID: String,
        coordinate: CLLocationCoordinate2D,
        timestamp: Date = Date(),
        message: String? = nil,
        color: String = "#FF6600",
        expiresAt: Date
    ) {
        self.id = id
        self.senderCallsign = senderCallsign
        self.senderUID = senderUID
        self.coordinate = PointerCodableCoordinate(coordinate: coordinate)
        self.timestamp = timestamp
        self.message = message
        self.color = color
        self.expiresAt = expiresAt
    }

    /// Get CLLocationCoordinate2D from the codable coordinate
    var clCoordinate: CLLocationCoordinate2D {
        coordinate.clCoordinate
    }

    /// Check if the pointer has expired
    var isExpired: Bool {
        Date() > expiresAt
    }

    /// Time remaining before expiration in seconds
    var timeRemaining: TimeInterval {
        max(0, expiresAt.timeIntervalSince(Date()))
    }

    static func == (lhs: DigitalPointerEvent, rhs: DigitalPointerEvent) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Codable Coordinate (if not already defined elsewhere)

/// Codable wrapper for CLLocationCoordinate2D
struct PointerCodableCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Digital Pointer Service

/// Service for managing and broadcasting digital pointers
/// Allows team members to share temporary cursor positions in real-time
class DigitalPointerService: ObservableObject {

    // MARK: - Singleton

    static let shared = DigitalPointerService()

    // MARK: - Published Properties

    /// Whether the local pointer is currently active
    @Published var isActive: Bool = false

    /// Current local pointer location
    @Published var currentPointerLocation: CLLocationCoordinate2D?

    /// Color for the local pointer (hex string)
    @Published var pointerColor: String = "#FF6600"

    /// Optional message/annotation for the local pointer
    @Published var pointerMessage: String = ""

    /// Array of pointers received from team members
    @Published var teamPointers: [DigitalPointerEvent] = []

    /// Last broadcast status message
    @Published var lastBroadcastStatus: String = ""

    /// Number of broadcasts sent in current session
    @Published var broadcastCount: Int = 0

    /// Time when pointer was activated
    @Published var activatedAt: Date?

    // MARK: - Configuration

    /// Interval between broadcasts (in seconds)
    var broadcastInterval: TimeInterval = 1.0

    /// Time after which pointers expire (in seconds)
    var pointerTimeout: TimeInterval = 30.0

    /// Stale time for CoT messages (in seconds)
    private let cotStaleTime: TimeInterval = 60.0

    // MARK: - Private Properties

    private var broadcastTimer: Timer?
    private var cleanupTimer: Timer?
    private var takService: TAKService?
    private var cancellables = Set<AnyCancellable>()

    private var userCallsign: String = "OmniTAK-iOS"
    private var userUID: String = ""

    // Notification names
    static let pointerReceivedNotification = Notification.Name("DigitalPointerReceived")
    static let pointerExpiredNotification = Notification.Name("DigitalPointerExpired")

    // MARK: - Initialization

    private init() {
        generateUserUID()
        startCleanupTimer()
        loadSettings()

        print("DigitalPointerService initialized with UID: \(userUID)")
    }

    // MARK: - Configuration

    /// Configure the service with required dependencies
    /// - Parameters:
    ///   - takService: The TAK service for sending CoT messages
    ///   - callsign: The user's callsign
    func configure(takService: TAKService, callsign: String) {
        self.takService = takService
        self.userCallsign = callsign

        print("DigitalPointerService configured with callsign: \(callsign)")
    }

    /// Update the user's callsign
    /// - Parameter callsign: New callsign
    func updateCallsign(_ callsign: String) {
        self.userCallsign = callsign
    }

    private func generateUserUID() {
        if let savedUID = UserDefaults.standard.string(forKey: "digitalPointerUID") {
            userUID = savedUID
        } else {
            userUID = "POINTER-\(UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString)"
            UserDefaults.standard.set(userUID, forKey: "digitalPointerUID")
        }
    }

    // MARK: - Pointer Activation

    /// Activate the digital pointer
    /// Starts broadcasting the pointer location at the configured interval
    func activatePointer() {
        guard !isActive else {
            print("Digital pointer is already active")
            return
        }

        isActive = true
        activatedAt = Date()
        broadcastCount = 0

        startBroadcasting()

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()

        print("Digital pointer activated")
    }

    /// Deactivate the digital pointer
    /// Stops broadcasting and clears the current pointer location
    func deactivatePointer() {
        guard isActive else {
            print("Digital pointer is not active")
            return
        }

        stopBroadcasting()

        isActive = false
        currentPointerLocation = nil
        activatedAt = nil
        pointerMessage = ""

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()

        print("Digital pointer deactivated")
    }

    /// Toggle the pointer active state
    func togglePointer() {
        if isActive {
            deactivatePointer()
        } else {
            activatePointer()
        }
    }

    // MARK: - Pointer Location Updates

    /// Update the current pointer location
    /// - Parameter coordinate: New coordinate for the pointer
    func updatePointerLocation(coordinate: CLLocationCoordinate2D) {
        currentPointerLocation = coordinate

        // If active and location changed, broadcast immediately
        if isActive {
            broadcastPointer()
        }
    }

    /// Set an optional message/annotation for the pointer
    /// - Parameter message: The message to attach to the pointer
    func setPointerMessage(_ message: String) {
        pointerMessage = message

        // If active, broadcast the updated message
        if isActive {
            broadcastPointer()
        }
    }

    /// Set the pointer color
    /// - Parameter hexColor: Hex color string (e.g., "#FF6600")
    func setPointerColor(_ hexColor: String) {
        pointerColor = hexColor
        saveSettings()
    }

    // MARK: - Broadcasting

    private func startBroadcasting() {
        guard broadcastTimer == nil else { return }

        // Initial broadcast
        broadcastPointer()

        // Schedule periodic broadcasts
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: broadcastInterval, repeats: true) { [weak self] _ in
            self?.broadcastPointer()
        }

        print("Started digital pointer broadcasting (interval: \(broadcastInterval)s)")
    }

    private func stopBroadcasting() {
        broadcastTimer?.invalidate()
        broadcastTimer = nil

        print("Stopped digital pointer broadcasting")
    }

    /// Broadcast the current pointer to team members
    func broadcastPointer() {
        guard isActive else {
            lastBroadcastStatus = "Pointer not active"
            return
        }

        guard let location = currentPointerLocation else {
            lastBroadcastStatus = "No pointer location set"
            return
        }

        guard let takService = takService else {
            lastBroadcastStatus = "TAKService not configured"
            print("Cannot broadcast pointer: TAKService not configured")
            return
        }

        let xml = generatePointerCoT()

        if takService.sendCoT(xml: xml) {
            broadcastCount += 1
            lastBroadcastStatus = "Broadcast #\(broadcastCount) sent at \(formattedTime(Date()))"
            print("Digital pointer broadcast #\(broadcastCount) at \(location)")
        } else {
            lastBroadcastStatus = "Failed to send broadcast"
            print("Failed to broadcast digital pointer")
        }
    }

    // MARK: - CoT Generation

    /// Generate CoT XML for the current pointer
    /// - Returns: CoT XML string
    func generatePointerCoT() -> String {
        guard let location = currentPointerLocation else {
            return ""
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let timeStr = formatter.string(from: now)
        let startStr = formatter.string(from: now)
        let staleStr = formatter.string(from: now.addingTimeInterval(cotStaleTime))

        let uid = "\(userUID)-\(Int(now.timeIntervalSince1970))"

        // Generate digital pointer CoT XML
        // Type: b-m-p-c (broadcast-marker-pointer-cursor)
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="b-m-p-c" how="h-g-i-g-o" time="\(timeStr)" start="\(startStr)" stale="\(staleStr)">
            <point lat="\(location.latitude)" lon="\(location.longitude)" hae="0" ce="9999" le="9999"/>
            <detail>
                <contact callsign="\(escapeXML(userCallsign))"/>
                <__digitalpointer
                    color="\(escapeXML(pointerColor))"
                    message="\(escapeXML(pointerMessage))"
                    senderUID="\(escapeXML(userUID))"
                    expiresIn="\(Int(pointerTimeout))"
                />
                <remarks>\(escapeXML(pointerMessage.isEmpty ? "Digital pointer from \(userCallsign)" : pointerMessage))</remarks>
                <takv device="\(UIDevice.current.model)" platform="OmniTAK-iOS" os="\(UIDevice.current.systemVersion)" version="1.0.0"/>
                <__group name="Digital Pointer" role="Team Member"/>
            </detail>
        </event>
        """

        return xml
    }

    // MARK: - Incoming Pointer Parsing

    /// Parse an incoming CoT XML message for digital pointer data
    /// - Parameter xmlString: The CoT XML string to parse
    /// - Returns: A DigitalPointerEvent if the XML contains valid pointer data, nil otherwise
    func parseIncomingPointer(xmlString: String) -> DigitalPointerEvent? {
        // Check if this is a digital pointer message
        guard xmlString.contains("b-m-p-c") || xmlString.contains("__digitalpointer") else {
            return nil
        }

        // Parse XML
        guard let data = xmlString.data(using: .utf8) else {
            print("Failed to convert XML string to data")
            return nil
        }

        let parser = DigitalPointerXMLParser()
        let success = parser.parse(data: data)

        guard success, let event = parser.pointerEvent else {
            print("Failed to parse digital pointer XML")
            return nil
        }

        return event
    }

    /// Process a received digital pointer event
    /// - Parameter event: The pointer event to process
    func processReceivedPointer(_ event: DigitalPointerEvent) {
        // Don't add our own pointers
        guard event.senderUID != userUID else {
            return
        }

        // Remove any existing pointer from the same sender
        teamPointers.removeAll { $0.senderUID == event.senderUID }

        // Add the new pointer
        teamPointers.append(event)

        // Sort by timestamp (newest first)
        teamPointers.sort { $0.timestamp > $1.timestamp }

        // Notify observers
        NotificationCenter.default.post(
            name: DigitalPointerService.pointerReceivedNotification,
            object: event
        )

        print("Received digital pointer from \(event.senderCallsign) at \(event.clCoordinate)")

        // Provide subtle haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    // MARK: - Pointer Management

    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.removeExpiredPointers()
        }
    }

    /// Remove all expired pointers from the team pointers array
    func removeExpiredPointers() {
        let expiredPointers = teamPointers.filter { $0.isExpired }

        if !expiredPointers.isEmpty {
            teamPointers.removeAll { $0.isExpired }

            // Notify about each expired pointer
            for pointer in expiredPointers {
                NotificationCenter.default.post(
                    name: DigitalPointerService.pointerExpiredNotification,
                    object: pointer
                )
                print("Removed expired pointer from \(pointer.senderCallsign)")
            }
        }
    }

    /// Get a specific pointer by sender UID
    /// - Parameter uid: The sender's UID
    /// - Returns: The pointer event if found
    func getPointer(forSenderUID uid: String) -> DigitalPointerEvent? {
        teamPointers.first { $0.senderUID == uid }
    }

    /// Get all active (non-expired) pointers
    /// - Returns: Array of active pointer events
    func getActivePointers() -> [DigitalPointerEvent] {
        teamPointers.filter { !$0.isExpired }
    }

    /// Clear all team pointers
    func clearAllTeamPointers() {
        teamPointers.removeAll()
        print("Cleared all team pointers")
    }

    /// Get the count of active team pointers
    var activePointerCount: Int {
        teamPointers.filter { !$0.isExpired }.count
    }

    // MARK: - Statistics

    /// Time since pointer was activated
    var timeSinceActivation: String {
        guard let activatedAt = activatedAt else { return "N/A" }
        let elapsed = Date().timeIntervalSince(activatedAt)
        let minutes = Int(elapsed / 60)
        let seconds = Int(elapsed.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Get formatted summary of pointer status
    var statusSummary: String {
        if isActive {
            return "Active - \(broadcastCount) broadcasts"
        } else {
            return "Inactive"
        }
    }

    // MARK: - Persistence

    private func saveSettings() {
        UserDefaults.standard.set(pointerColor, forKey: "digitalPointerColor")
        UserDefaults.standard.set(broadcastInterval, forKey: "digitalPointerInterval")
        UserDefaults.standard.set(pointerTimeout, forKey: "digitalPointerTimeout")
    }

    private func loadSettings() {
        if let savedColor = UserDefaults.standard.string(forKey: "digitalPointerColor") {
            pointerColor = savedColor
        }

        let savedInterval = UserDefaults.standard.double(forKey: "digitalPointerInterval")
        if savedInterval > 0 {
            broadcastInterval = savedInterval
        }

        let savedTimeout = UserDefaults.standard.double(forKey: "digitalPointerTimeout")
        if savedTimeout > 0 {
            pointerTimeout = savedTimeout
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

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    deinit {
        stopBroadcasting()
        cleanupTimer?.invalidate()
    }
}

// MARK: - XML Parser for Digital Pointer

/// XML parser specifically for parsing digital pointer CoT messages
private class DigitalPointerXMLParser: NSObject, XMLParserDelegate {
    var pointerEvent: DigitalPointerEvent?

    private var currentEventUID: String = ""
    private var currentEventType: String = ""
    private var currentTime: Date = Date()
    private var currentStale: Date = Date()

    private var latitude: Double = 0
    private var longitude: Double = 0

    private var callsign: String = ""
    private var senderUID: String = ""
    private var color: String = "#FF6600"
    private var message: String = ""
    private var expiresIn: TimeInterval = 30

    private var currentElement: String = ""
    private var remarksContent: String = ""

    func parse(data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName

        switch elementName {
        case "event":
            if let uid = attributeDict["uid"] {
                currentEventUID = uid
            }
            if let type = attributeDict["type"] {
                currentEventType = type
            }
            if let timeStr = attributeDict["time"] {
                currentTime = parseISO8601Date(timeStr) ?? Date()
            }
            if let staleStr = attributeDict["stale"] {
                currentStale = parseISO8601Date(staleStr) ?? Date().addingTimeInterval(60)
            }

        case "point":
            if let latStr = attributeDict["lat"], let lat = Double(latStr) {
                latitude = lat
            }
            if let lonStr = attributeDict["lon"], let lon = Double(lonStr) {
                longitude = lon
            }

        case "contact":
            if let cs = attributeDict["callsign"] {
                callsign = cs
            }

        case "__digitalpointer":
            if let c = attributeDict["color"] {
                color = c
            }
            if let msg = attributeDict["message"] {
                message = msg
            }
            if let uid = attributeDict["senderUID"] {
                senderUID = uid
            }
            if let expires = attributeDict["expiresIn"], let exp = Double(expires) {
                expiresIn = exp
            }

        case "remarks":
            remarksContent = ""

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement == "remarks" {
            remarksContent += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "event" {
            // Only create pointer event if this is a digital pointer message
            if currentEventType == "b-m-p-c" {
                // Use remarks as message if __digitalpointer message is empty
                if message.isEmpty && !remarksContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    message = remarksContent.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                // If senderUID wasn't in __digitalpointer, derive from event UID
                if senderUID.isEmpty {
                    senderUID = currentEventUID.components(separatedBy: "-").dropLast().joined(separator: "-")
                }

                pointerEvent = DigitalPointerEvent(
                    id: UUID(),
                    senderCallsign: callsign,
                    senderUID: senderUID,
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    timestamp: currentTime,
                    message: message.isEmpty ? nil : message,
                    color: color,
                    expiresAt: currentTime.addingTimeInterval(expiresIn)
                )
            }
        }

        currentElement = ""
    }

    private func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - Predefined Pointer Colors

extension DigitalPointerService {
    /// Predefined colors for digital pointers
    enum PointerColor: String, CaseIterable {
        case orange = "#FF6600"
        case red = "#FF0000"
        case yellow = "#FFFF00"
        case green = "#00FF00"
        case blue = "#0000FF"
        case purple = "#800080"
        case cyan = "#00FFFF"
        case magenta = "#FF00FF"
        case white = "#FFFFFF"

        var displayName: String {
            switch self {
            case .orange: return "Orange"
            case .red: return "Red"
            case .yellow: return "Yellow"
            case .green: return "Green"
            case .blue: return "Blue"
            case .purple: return "Purple"
            case .cyan: return "Cyan"
            case .magenta: return "Magenta"
            case .white: return "White"
            }
        }
    }

    /// Set pointer color using predefined color
    /// - Parameter color: Predefined pointer color
    func setPointerColor(_ color: PointerColor) {
        setPointerColor(color.rawValue)
    }
}
