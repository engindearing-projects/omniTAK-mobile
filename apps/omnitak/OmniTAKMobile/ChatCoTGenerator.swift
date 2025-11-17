//
//  ChatCoTGenerator.swift
//  OmniTAKMobile
//
//  Generate and parse GeoChat CoT messages
//

import Foundation
import CoreLocation

// MARK: - Chat CoT Generator

class ChatCoTGenerator {

    // MARK: - Generate GeoChat CoT

    static func generateGeoChatCoT(message: ChatMessage, conversation: Conversation) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(3600) // 1 hour stale

        let timeStr = dateFormatter.string(from: now)
        let startStr = dateFormatter.string(from: message.timestamp)
        let staleStr = dateFormatter.string(from: stale)

        // Generate UID for chat message
        let uid = "GeoChat.\(message.senderId).\(conversation.id).\(message.id)"

        let chatType = "b-t-f"
        let chatRoom = conversation.title

        // Build XML
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="\(chatType)" time="\(timeStr)" start="\(startStr)" stale="\(staleStr)" how="h-g-i-g-o">
            <point lat="0.0" lon="0.0" hae="0.0" ce="9999999" le="9999999"/>
            <detail>
                <__chat id="\(conversation.id)" chatroom="\(chatRoom)" senderCallsign="\(message.senderCallsign)">
                    <chatgrp uid0="\(message.senderId)" uid1="\(conversation.id)" id="\(conversation.id)"/>
                </__chat>
                <link uid="\(message.senderId)" type="a-f-G" relation="p-p"/>
                <remarks source="\(message.senderId)" time="\(startStr)">\(escapeXML(message.messageText))</remarks>
                <__serverdestination destinations="\(conversation.id)"/>
            </detail>
        </event>
        """

        return xml
    }

    // MARK: - Parse GeoChat CoT

    static func parseGeoChatCoT(xml: String) -> ChatMessage? {
        guard let data = xml.data(using: .utf8) else { return nil }

        let parser = GeoChatXMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser

        if xmlParser.parse() {
            return parser.message
        }

        return nil
    }

    // MARK: - Helper

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

// MARK: - XML Parser

private class GeoChatXMLParser: NSObject, XMLParserDelegate {
    var message: ChatMessage?

    private var currentElement = ""
    private var currentText = ""

    private var uid = ""
    private var senderId = ""
    private var senderCallsign = ""
    private var conversationId = ""
    private var content = ""
    private var timestamp = Date()

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""

        switch elementName {
        case "event":
            uid = attributeDict["uid"] ?? ""
            if let timeStr = attributeDict["time"] {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                timestamp = formatter.date(from: timeStr) ?? Date()
            }

        case "__chat":
            conversationId = attributeDict["id"] ?? ""
            senderCallsign = attributeDict["senderCallsign"] ?? "Unknown"

        case "chatgrp":
            senderId = attributeDict["uid0"] ?? ""

        case "remarks":
            if let source = attributeDict["source"] {
                senderId = source
            }

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "remarks" {
            content = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if elementName == "event" && !content.isEmpty {
            message = ChatMessage(
                id: uid,
                conversationId: conversationId,
                senderId: senderId,
                senderCallsign: senderCallsign,
                messageText: content,
                timestamp: timestamp,
                status: .sent,
                isFromSelf: false
            )
        }
    }
}
