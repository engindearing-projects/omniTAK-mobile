//
//  TeamService.swift
//  OmniTAKMobile
//
//  Core service for team management operations
//

import Foundation
import Combine
import CoreLocation
import UIKit

class TeamService: ObservableObject {
    static let shared = TeamService()

    // MARK: - Published Properties

    @Published var currentTeam: Team?
    @Published var teamMembers: [TeamMember] = []
    @Published var availableTeams: [Team] = []
    @Published var pendingInvites: [TeamInvite] = []
    @Published var teamBroadcasts: [TeamBroadcast] = []
    @Published var currentUserId: String = "SELF-\(UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString)"
    @Published var currentUserCallsign: String = "OmniTAK-iOS"

    // MARK: - Computed Properties

    var currentRole: TeamRole? {
        currentTeam?.members.first { $0.uid == currentUserId }?.role
    }

    // MARK: - Private Properties

    private let storage = TeamStorageManager.shared
    private var takService: TAKService?
    private var locationManager: LocationManager?
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadStoredData()
        startMemberUpdateTimer()
    }

    // MARK: - Configuration

    func configure(takService: TAKService, locationManager: LocationManager) {
        self.takService = takService
        self.locationManager = locationManager
        print("TeamService configured with TAKService and LocationManager")
    }

    func updateCallsign(_ callsign: String) {
        currentUserCallsign = callsign

        // Update self in current team if member
        if var team = currentTeam,
           let memberIndex = team.members.firstIndex(where: { $0.uid == currentUserId }) {
            team.members[memberIndex].callsign = callsign
            currentTeam = team
            teamMembers = team.members
            saveCurrentTeam()
        }
    }

    // MARK: - Team Creation

    func createTeam(name: String, color: TeamColor, description: String? = nil) -> Team {
        let selfMember = TeamMember(
            uid: currentUserId,
            callsign: currentUserCallsign,
            role: .lead,
            lastSeen: Date(),
            coordinate: locationManager?.location?.coordinate,
            isOnline: true
        )

        let team = Team(
            id: UUID().uuidString,
            name: name,
            color: color,
            members: [selfMember],
            createdAt: Date(),
            ownerId: currentUserId,
            description: description,
            isActive: true
        )

        // Set as current team
        currentTeam = team
        teamMembers = team.members

        // Add to available teams
        if !availableTeams.contains(where: { $0.id == team.id }) {
            availableTeams.append(team)
        }

        // Save to storage
        saveCurrentTeam()
        saveAvailableTeams()

        // Broadcast team creation
        broadcastTeamMembership()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        print("Created team: \(team.name) with color: \(team.color.rawValue)")
        return team
    }

    // MARK: - Team Joining

    func joinTeam(_ team: Team) -> Bool {
        guard !team.isMember(uid: currentUserId) else {
            print("Already a member of team: \(team.name)")
            return false
        }

        let selfMember = TeamMember(
            uid: currentUserId,
            callsign: currentUserCallsign,
            role: .member,
            lastSeen: Date(),
            coordinate: locationManager?.location?.coordinate,
            isOnline: true
        )

        var updatedTeam = team
        updatedTeam.members.append(selfMember)

        // Update current team
        currentTeam = updatedTeam
        teamMembers = updatedTeam.members

        // Update in available teams
        if let index = availableTeams.firstIndex(where: { $0.id == team.id }) {
            availableTeams[index] = updatedTeam
        } else {
            availableTeams.append(updatedTeam)
        }

        // Save
        saveCurrentTeam()
        saveAvailableTeams()

        // Broadcast join
        broadcastTeamMembership()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        print("Joined team: \(team.name)")
        return true
    }

    // MARK: - Team Leaving

    func leaveTeam() {
        leaveCurrentTeam()
    }

    func leaveCurrentTeam() {
        guard let team = currentTeam else {
            print("Not currently in a team")
            return
        }

        var updatedTeam = team
        updatedTeam.members.removeAll { $0.uid == currentUserId }

        // Update available teams
        if let index = availableTeams.firstIndex(where: { $0.id == team.id }) {
            if updatedTeam.members.isEmpty {
                availableTeams.remove(at: index)
            } else {
                availableTeams[index] = updatedTeam
            }
        }

        // Clear current team
        currentTeam = nil
        teamMembers = []

        // Save
        saveCurrentTeam()
        saveAvailableTeams()

        // Broadcast leave (send empty team info)
        broadcastTeamMembership()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        print("Left team: \(team.name)")
    }

    // MARK: - Member Management

    func updateMemberRole(uid: String, newRole: TeamRole) -> Bool {
        guard var team = currentTeam,
              team.isLead(uid: currentUserId) || team.isOwner(uid: currentUserId) else {
            print("Not authorized to change roles")
            return false
        }

        guard let memberIndex = team.members.firstIndex(where: { $0.uid == uid }) else {
            print("Member not found: \(uid)")
            return false
        }

        team.members[memberIndex].role = newRole
        currentTeam = team
        teamMembers = team.members

        // Update in available teams
        if let index = availableTeams.firstIndex(where: { $0.id == team.id }) {
            availableTeams[index] = team
        }

        saveCurrentTeam()
        saveAvailableTeams()

        // Broadcast update
        broadcastTeamMembership()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        print("Updated role for \(uid) to \(newRole.rawValue)")
        return true
    }

    func removeMember(uid: String) -> Bool {
        guard var team = currentTeam,
              team.isLead(uid: currentUserId) || team.isOwner(uid: currentUserId) else {
            print("Not authorized to remove members")
            return false
        }

        guard uid != currentUserId else {
            print("Cannot remove self, use leaveCurrentTeam()")
            return false
        }

        team.members.removeAll { $0.uid == uid }
        currentTeam = team
        teamMembers = team.members

        // Update in available teams
        if let index = availableTeams.firstIndex(where: { $0.id == team.id }) {
            availableTeams[index] = team
        }

        saveCurrentTeam()
        saveAvailableTeams()

        print("Removed member: \(uid)")
        return true
    }

    // MARK: - Position Updates

    func updateMemberPosition(uid: String, coordinate: CLLocationCoordinate2D, speed: Double? = nil, course: Double? = nil) {
        guard var team = currentTeam else { return }

        if let memberIndex = team.members.firstIndex(where: { $0.uid == uid }) {
            team.members[memberIndex].coordinate = CodableCoordinate(coordinate: coordinate)
            team.members[memberIndex].speed = speed
            team.members[memberIndex].course = course
            team.members[memberIndex].lastSeen = Date()
            team.members[memberIndex].isOnline = true

            currentTeam = team
            teamMembers = team.members
            saveCurrentTeam()
        }
    }

    func updateSelfPosition() {
        guard let location = locationManager?.location else { return }

        updateMemberPosition(
            uid: currentUserId,
            coordinate: location.coordinate,
            speed: location.speed >= 0 ? location.speed : nil,
            course: location.course >= 0 ? location.course : nil
        )

        // Broadcast updated position
        broadcastTeamMembership()
    }

    // MARK: - Team Broadcasting

    func broadcastTeamMembership() {
        guard let team = currentTeam,
              let takService = takService else { return }

        let xml = TeamCoTGenerator.generateTeamMembershipCoT(
            team: team,
            member: team.getMember(uid: currentUserId) ?? TeamMember(uid: currentUserId, callsign: currentUserCallsign),
            callsign: currentUserCallsign
        )

        let success = takService.sendCoT(xml: xml)
        if success {
            print("Broadcast team membership for \(team.name)")
        } else {
            print("Failed to broadcast team membership")
        }
    }

    func sendTeamBroadcast(message: String, isAlert: Bool = false) {
        guard let team = currentTeam,
              let takService = takService else { return }

        let broadcast = TeamBroadcast(
            teamId: team.id,
            senderId: currentUserId,
            senderCallsign: currentUserCallsign,
            message: message,
            coordinate: locationManager?.location?.coordinate,
            isAlert: isAlert
        )

        teamBroadcasts.append(broadcast)
        saveBroadcasts()

        let xml = TeamCoTGenerator.generateTeamBroadcastCoT(
            broadcast: broadcast,
            team: team,
            callsign: currentUserCallsign
        )

        let success = takService.sendCoT(xml: xml)
        if success {
            print("Sent team broadcast: \(message)")

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }

    // MARK: - Team Info Parsing

    func processIncomingTeamCoT(teamId: String, teamName: String, teamColor: TeamColor, memberUid: String, memberCallsign: String, memberRole: TeamRole, coordinate: CLLocationCoordinate2D?, speed: Double?, course: Double?) {
        // Check if this is for current team
        if let team = currentTeam, team.id == teamId {
            // Update existing member or add new
            if let memberIndex = teamMembers.firstIndex(where: { $0.uid == memberUid }) {
                teamMembers[memberIndex].callsign = memberCallsign
                teamMembers[memberIndex].role = memberRole
                teamMembers[memberIndex].lastSeen = Date()
                teamMembers[memberIndex].isOnline = true
                if let coord = coordinate {
                    teamMembers[memberIndex].coordinate = CodableCoordinate(coordinate: coord)
                }
                teamMembers[memberIndex].speed = speed
                teamMembers[memberIndex].course = course
            } else {
                let newMember = TeamMember(
                    uid: memberUid,
                    callsign: memberCallsign,
                    role: memberRole,
                    lastSeen: Date(),
                    coordinate: coordinate,
                    speed: speed,
                    course: course,
                    isOnline: true
                )
                teamMembers.append(newMember)
            }

            // Update current team
            var updatedTeam = team
            updatedTeam.members = teamMembers
            currentTeam = updatedTeam
            saveCurrentTeam()
        }

        // Add/update team in available teams
        if let teamIndex = availableTeams.firstIndex(where: { $0.id == teamId }) {
            var team = availableTeams[teamIndex]

            if let memberIndex = team.members.firstIndex(where: { $0.uid == memberUid }) {
                team.members[memberIndex].callsign = memberCallsign
                team.members[memberIndex].role = memberRole
                team.members[memberIndex].lastSeen = Date()
                team.members[memberIndex].isOnline = true
                if let coord = coordinate {
                    team.members[memberIndex].coordinate = CodableCoordinate(coordinate: coord)
                }
                team.members[memberIndex].speed = speed
                team.members[memberIndex].course = course
            } else {
                let newMember = TeamMember(
                    uid: memberUid,
                    callsign: memberCallsign,
                    role: memberRole,
                    lastSeen: Date(),
                    coordinate: coordinate,
                    speed: speed,
                    course: course,
                    isOnline: true
                )
                team.members.append(newMember)
            }

            availableTeams[teamIndex] = team
            saveAvailableTeams()
        } else {
            // Create new team entry
            let newMember = TeamMember(
                uid: memberUid,
                callsign: memberCallsign,
                role: memberRole,
                lastSeen: Date(),
                coordinate: coordinate,
                speed: speed,
                course: course,
                isOnline: true
            )

            let newTeam = Team(
                id: teamId,
                name: teamName,
                color: teamColor,
                members: [newMember],
                createdAt: Date(),
                ownerId: memberUid,
                isActive: true
            )

            availableTeams.append(newTeam)
            saveAvailableTeams()
        }
    }

    // MARK: - Team Statistics

    func getTeamStatistics() -> TeamStatistics? {
        guard let team = currentTeam else { return nil }

        let onlineMembers = team.members.filter { $0.isOnline }.count

        // Calculate average distance and spread
        var totalDistance: Double = 0
        var distanceCount = 0
        var maxDistance: Double = 0

        let membersWithLocation = team.members.compactMap { member -> (TeamMember, CLLocation)? in
            guard let coord = member.clCoordinate else { return nil }
            return (member, CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        }

        for i in 0..<membersWithLocation.count {
            for j in (i+1)..<membersWithLocation.count {
                let distance = membersWithLocation[i].1.distance(from: membersWithLocation[j].1)
                totalDistance += distance
                distanceCount += 1
                maxDistance = max(maxDistance, distance)
            }
        }

        let averageDistance = distanceCount > 0 ? totalDistance / Double(distanceCount) : nil

        return TeamStatistics(
            totalMembers: team.members.count,
            onlineMembers: onlineMembers,
            totalBroadcasts: teamBroadcasts.filter { $0.teamId == team.id }.count,
            averageDistance: averageDistance,
            teamSpread: maxDistance > 0 ? maxDistance : nil
        )
    }

    // MARK: - Timer Management

    private func startMemberUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkMemberStatus()
            self?.cleanupOldBroadcasts()
        }
    }

    private func checkMemberStatus() {
        guard var team = currentTeam else { return }

        let now = Date()
        let staleThreshold: TimeInterval = 300 // 5 minutes

        var updated = false
        for index in team.members.indices {
            let timeSinceSeen = now.timeIntervalSince(team.members[index].lastSeen)
            let shouldBeOnline = timeSinceSeen < staleThreshold

            if team.members[index].isOnline != shouldBeOnline {
                team.members[index].isOnline = shouldBeOnline
                updated = true
            }
        }

        if updated {
            currentTeam = team
            teamMembers = team.members
            saveCurrentTeam()
        }
    }

    private func cleanupOldBroadcasts() {
        // Keep only last 100 broadcasts
        if teamBroadcasts.count > 100 {
            teamBroadcasts = Array(teamBroadcasts.suffix(100))
            saveBroadcasts()
        }
    }

    // MARK: - Storage

    private func loadStoredData() {
        currentTeam = storage.loadCurrentTeam()
        availableTeams = storage.loadAvailableTeams()
        pendingInvites = storage.loadPendingInvites()
        teamBroadcasts = storage.loadTeamBroadcasts()

        if let team = currentTeam {
            teamMembers = team.members
        }

        print("TeamService loaded: current team = \(currentTeam?.name ?? "none"), available teams = \(availableTeams.count)")
    }

    private func saveCurrentTeam() {
        storage.saveCurrentTeam(currentTeam)
    }

    private func saveAvailableTeams() {
        storage.saveAvailableTeams(availableTeams)
    }

    private func saveBroadcasts() {
        storage.saveTeamBroadcasts(teamBroadcasts)
    }

    // MARK: - Cleanup

    func clearAllTeamData() {
        currentTeam = nil
        teamMembers = []
        availableTeams = []
        pendingInvites = []
        teamBroadcasts = []

        storage.clearAllData()
        print("Cleared all team data")
    }

    deinit {
        updateTimer?.invalidate()
    }
}
