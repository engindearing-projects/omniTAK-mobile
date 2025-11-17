//
//  TeamStorageManager.swift
//  OmniTAKMobile
//
//  Persistence layer for team management data
//

import Foundation

class TeamStorageManager {
    static let shared = TeamStorageManager()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // Storage keys
    private let currentTeamKey = "com.omnitak.team.current"
    private let availableTeamsKey = "com.omnitak.team.available"
    private let pendingInvitesKey = "com.omnitak.team.invites"
    private let teamBroadcastsKey = "com.omnitak.team.broadcasts"

    private init() {}

    // MARK: - Current Team

    func loadCurrentTeam() -> Team? {
        guard let data = defaults.data(forKey: currentTeamKey) else { return nil }
        return try? decoder.decode(Team.self, from: data)
    }

    func saveCurrentTeam(_ team: Team?) {
        guard let team = team else {
            defaults.removeObject(forKey: currentTeamKey)
            return
        }
        if let data = try? encoder.encode(team) {
            defaults.set(data, forKey: currentTeamKey)
        }
    }

    // MARK: - Available Teams

    func loadAvailableTeams() -> [Team] {
        guard let data = defaults.data(forKey: availableTeamsKey) else { return [] }
        return (try? decoder.decode([Team].self, from: data)) ?? []
    }

    func saveAvailableTeams(_ teams: [Team]) {
        if let data = try? encoder.encode(teams) {
            defaults.set(data, forKey: availableTeamsKey)
        }
    }

    // MARK: - Pending Invites

    func loadPendingInvites() -> [TeamInvite] {
        guard let data = defaults.data(forKey: pendingInvitesKey) else { return [] }
        return (try? decoder.decode([TeamInvite].self, from: data)) ?? []
    }

    func savePendingInvites(_ invites: [TeamInvite]) {
        if let data = try? encoder.encode(invites) {
            defaults.set(data, forKey: pendingInvitesKey)
        }
    }

    // MARK: - Team Broadcasts

    func loadTeamBroadcasts() -> [TeamBroadcast] {
        guard let data = defaults.data(forKey: teamBroadcastsKey) else { return [] }
        return (try? decoder.decode([TeamBroadcast].self, from: data)) ?? []
    }

    func saveTeamBroadcasts(_ broadcasts: [TeamBroadcast]) {
        if let data = try? encoder.encode(broadcasts) {
            defaults.set(data, forKey: teamBroadcastsKey)
        }
    }

    // MARK: - Clear All

    func clearAllData() {
        defaults.removeObject(forKey: currentTeamKey)
        defaults.removeObject(forKey: availableTeamsKey)
        defaults.removeObject(forKey: pendingInvitesKey)
        defaults.removeObject(forKey: teamBroadcastsKey)
    }
}
