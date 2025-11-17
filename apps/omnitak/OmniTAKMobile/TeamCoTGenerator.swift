//
//  TeamCoTGenerator.swift
//  OmniTAKMobile
//
//  Generate CoT messages for team coordination
//

import Foundation
import CoreLocation

class TeamCoTGenerator {

    static func generateTeamMembershipCoT(team: Team, member: TeamMember, callsign: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(3600) // 1 hour stale

        let timeStr = dateFormatter.string(from: now)
        let staleStr = dateFormatter.string(from: stale)

        let uid = "TEAM-\(team.id)-\(member.uid)"

        let lat = member.clCoordinate?.latitude ?? 0.0
        let lon = member.clCoordinate?.longitude ?? 0.0

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="a-f-G-U-C" time="\(timeStr)" start="\(timeStr)" stale="\(staleStr)" how="h-g-i-g-o">
            <point lat="\(lat)" lon="\(lon)" hae="0.0" ce="9999999" le="9999999"/>
            <detail>
                <contact callsign="\(escapeXML(callsign))"/>
                <__group name="\(escapeXML(team.name))" role="\(member.role.rawValue)"/>
                <__team id="\(team.id)" name="\(escapeXML(team.name))" color="\(team.color.hexColor)"/>
                <__member uid="\(member.uid)" callsign="\(escapeXML(member.callsign))" role="\(member.role.shortName)" online="\(member.isOnline)"/>
                <status readiness="true"/>
            </detail>
        </event>
        """

        return xml
    }

    static func generateTeamBroadcastCoT(broadcast: TeamBroadcast, team: Team, callsign: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(3600) // 1 hour stale

        let timeStr = dateFormatter.string(from: now)
        let startStr = dateFormatter.string(from: broadcast.timestamp)
        let staleStr = dateFormatter.string(from: stale)

        let uid = "TEAM-BROADCAST-\(broadcast.id)"

        let lat = broadcast.coordinate?.clCoordinate.latitude ?? 0.0
        let lon = broadcast.coordinate?.clCoordinate.longitude ?? 0.0

        let typeCode = broadcast.isAlert ? "b-a-o-tbl" : "b-t-f"

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="\(typeCode)" time="\(timeStr)" start="\(startStr)" stale="\(staleStr)" how="h-g-i-g-o">
            <point lat="\(lat)" lon="\(lon)" hae="0.0" ce="9999999" le="9999999"/>
            <detail>
                <contact callsign="\(escapeXML(callsign))"/>
                <remarks source="\(broadcast.senderId)" time="\(startStr)">\(escapeXML(broadcast.message))</remarks>
                <__team id="\(team.id)" name="\(escapeXML(team.name))"/>
                <__broadcast id="\(broadcast.id)" sender="\(broadcast.senderId)" senderCallsign="\(escapeXML(broadcast.senderCallsign))" alert="\(broadcast.isAlert)"/>
            </detail>
        </event>
        """

        return xml
    }

    static func generateTeamInviteCoT(invite: TeamInvite) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(86400) // 24 hour stale

        let timeStr = dateFormatter.string(from: now)
        let staleStr = dateFormatter.string(from: stale)

        let uid = "TEAM-INVITE-\(invite.id)"

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="b-t-f" time="\(timeStr)" start="\(timeStr)" stale="\(staleStr)" how="h-g-i-g-o">
            <point lat="0.0" lon="0.0" hae="0.0" ce="9999999" le="9999999"/>
            <detail>
                <contact callsign="\(escapeXML(invite.inviterCallsign))"/>
                <remarks>Team Invite: Join \(escapeXML(invite.teamName))</remarks>
                <__team_invite id="\(invite.id)" teamId="\(invite.teamId)" teamName="\(escapeXML(invite.teamName))" teamColor="\(invite.teamColor.hexColor)" inviterId="\(invite.inviterId)" inviterCallsign="\(escapeXML(invite.inviterCallsign))" inviteeId="\(invite.inviteeId)" inviteeCallsign="\(escapeXML(invite.inviteeCallsign))" status="\(invite.status.rawValue)"/>
            </detail>
        </event>
        """

        return xml
    }

    private static func escapeXML(_ string: String) -> String {
        var escaped = string
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
}
