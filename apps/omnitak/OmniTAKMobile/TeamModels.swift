//
//  TeamModels.swift
//  OmniTAKMobile
//
//  Team management data models for TAK team coordination
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - Team Color (ATAK Standard)

enum TeamColor: String, Codable, CaseIterable {
    case cyan = "Cyan"
    case green = "Green"
    case yellow = "Yellow"
    case orange = "Orange"
    case magenta = "Magenta"
    case red = "Red"
    case white = "White"
    case maroon = "Maroon"

    var hexColor: String {
        switch self {
        case .cyan: return "#00FFFF"
        case .green: return "#00FF00"
        case .yellow: return "#FFFF00"
        case .orange: return "#FF8000"
        case .magenta: return "#FF00FF"
        case .red: return "#FF0000"
        case .white: return "#FFFFFF"
        case .maroon: return "#800000"
        }
    }

    var color: Color {
        Color(hex: hexColor)
    }

    var swiftUIColor: Color {
        Color(hex: hexColor)
    }

    var uiColor: UIColor {
        switch self {
        case .cyan: return UIColor(red: 0, green: 1, blue: 1, alpha: 1)
        case .green: return UIColor(red: 0, green: 1, blue: 0, alpha: 1)
        case .yellow: return UIColor(red: 1, green: 1, blue: 0, alpha: 1)
        case .orange: return UIColor(red: 1, green: 0.5, blue: 0, alpha: 1)
        case .magenta: return UIColor(red: 1, green: 0, blue: 1, alpha: 1)
        case .red: return UIColor(red: 1, green: 0, blue: 0, alpha: 1)
        case .white: return UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        case .maroon: return UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
        }
    }

    var displayName: String {
        rawValue
    }

    var iconName: String {
        "circle.fill"
    }
}

// MARK: - Team Role

enum TeamRole: String, Codable, CaseIterable {
    case lead = "Team Lead"
    case member = "Team Member"
    case observer = "Observer"

    var shortName: String {
        switch self {
        case .lead: return "TL"
        case .member: return "TM"
        case .observer: return "OBS"
        }
    }

    var displayName: String {
        rawValue
    }

    var iconName: String {
        switch self {
        case .lead: return "star.fill"
        case .member: return "person.fill"
        case .observer: return "eye.fill"
        }
    }

    var priority: Int {
        switch self {
        case .lead: return 0
        case .member: return 1
        case .observer: return 2
        }
    }
}

// MARK: - Team Member

struct TeamMember: Identifiable, Codable, Equatable, Hashable {
    let uid: String
    var callsign: String
    var role: TeamRole
    var lastSeen: Date
    var coordinate: CodableCoordinate?
    var speed: Double?
    var course: Double?
    var isOnline: Bool

    var id: String { uid }

    init(
        uid: String,
        callsign: String,
        role: TeamRole = .member,
        lastSeen: Date = Date(),
        coordinate: CLLocationCoordinate2D? = nil,
        speed: Double? = nil,
        course: Double? = nil,
        isOnline: Bool = true
    ) {
        self.uid = uid
        self.callsign = callsign
        self.role = role
        self.lastSeen = lastSeen
        self.coordinate = coordinate.map { CodableCoordinate(coordinate: $0) }
        self.speed = speed
        self.course = course
        self.isOnline = isOnline
    }

    var clCoordinate: CLLocationCoordinate2D? {
        coordinate?.clCoordinate
    }

    var lastSeenString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSeen, relativeTo: Date())
    }

    var isStale: Bool {
        // Consider stale if not seen in last 5 minutes
        Date().timeIntervalSince(lastSeen) > 300
    }

    static func == (lhs: TeamMember, rhs: TeamMember) -> Bool {
        lhs.uid == rhs.uid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
}

// MARK: - Codable Coordinate Helper

struct CodableCoordinate: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double

    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Team

struct Team: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var color: TeamColor
    var members: [TeamMember]
    let createdAt: Date
    let ownerId: String
    var description: String?
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        color: TeamColor = .cyan,
        members: [TeamMember] = [],
        createdAt: Date = Date(),
        ownerId: String,
        description: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.members = members
        self.createdAt = createdAt
        self.ownerId = ownerId
        self.description = description
        self.isActive = isActive
    }

    var memberCount: Int {
        members.count
    }

    var onlineMemberCount: Int {
        members.filter { $0.isOnline }.count
    }

    var teamLead: TeamMember? {
        members.first { $0.role == .lead }
    }

    var sortedMembers: [TeamMember] {
        members.sorted { $0.role.priority < $1.role.priority }
    }

    var createdAtString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    func isMember(uid: String) -> Bool {
        members.contains { $0.uid == uid }
    }

    func getMember(uid: String) -> TeamMember? {
        members.first { $0.uid == uid }
    }

    func isOwner(uid: String) -> Bool {
        ownerId == uid
    }

    func isLead(uid: String) -> Bool {
        members.first { $0.uid == uid }?.role == .lead
    }
}

// MARK: - Team Invite

struct TeamInvite: Identifiable, Codable {
    let id: String
    let teamId: String
    let teamName: String
    let teamColor: TeamColor
    let inviterId: String
    let inviterCallsign: String
    let inviteeId: String
    let inviteeCallsign: String
    let timestamp: Date
    var status: InviteStatus

    init(
        id: String = UUID().uuidString,
        teamId: String,
        teamName: String,
        teamColor: TeamColor,
        inviterId: String,
        inviterCallsign: String,
        inviteeId: String,
        inviteeCallsign: String,
        timestamp: Date = Date(),
        status: InviteStatus = .pending
    ) {
        self.id = id
        self.teamId = teamId
        self.teamName = teamName
        self.teamColor = teamColor
        self.inviterId = inviterId
        self.inviterCallsign = inviterCallsign
        self.inviteeId = inviteeId
        self.inviteeCallsign = inviteeCallsign
        self.timestamp = timestamp
        self.status = status
    }

    var isExpired: Bool {
        // Invites expire after 24 hours
        Date().timeIntervalSince(timestamp) > 86400
    }

    var timestampString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Invite Status

enum InviteStatus: String, Codable {
    case pending
    case accepted
    case declined
    case expired
}

// MARK: - Team Broadcast

struct TeamBroadcast: Identifiable, Codable {
    let id: String
    let teamId: String
    let senderId: String
    let senderCallsign: String
    let message: String
    let timestamp: Date
    let coordinate: CodableCoordinate?
    var isAlert: Bool

    init(
        id: String = UUID().uuidString,
        teamId: String,
        senderId: String,
        senderCallsign: String,
        message: String,
        timestamp: Date = Date(),
        coordinate: CLLocationCoordinate2D? = nil,
        isAlert: Bool = false
    ) {
        self.id = id
        self.teamId = teamId
        self.senderId = senderId
        self.senderCallsign = senderCallsign
        self.message = message
        self.timestamp = timestamp
        self.coordinate = coordinate.map { CodableCoordinate(coordinate: $0) }
        self.isAlert = isAlert
    }

    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Team Statistics

struct TeamStatistics {
    let totalMembers: Int
    let onlineMembers: Int
    let totalBroadcasts: Int
    let averageDistance: Double?
    let teamSpread: Double?

    var onlinePercentage: Double {
        guard totalMembers > 0 else { return 0 }
        return Double(onlineMembers) / Double(totalMembers) * 100
    }

    var formattedAverageDistance: String {
        guard let distance = averageDistance else { return "N/A" }
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.2f km", distance / 1000)
        }
    }

    var formattedTeamSpread: String {
        guard let spread = teamSpread else { return "N/A" }
        if spread < 1000 {
            return String(format: "%.0f m", spread)
        } else {
            return String(format: "%.2f km", spread / 1000)
        }
    }
}
