package soy.engindearing.omnitak.mobile.data

import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.io.StringReader
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.UUID

/**
 * GeoChat (b-t-f) XML parse + generate. Matches the iOS
 * ChatXMLGenerator/ChatXMLParser shape so round-trips with
 * ATAK/iTAK servers stay interoperable.
 *
 * Non-goals for this slice:
 *  - fileshare/photo attachments (need the photo pipeline first)
 *  - MARTI destination routing beyond simple single-recipient DMs
 */
object ChatXml {

    data class Generated(val xml: String, val messageId: String)

    fun generateGeoChat(
        text: String,
        senderUid: String,
        senderCallsign: String,
        isGroup: Boolean,
        recipientUid: String? = null,
        recipientCallsign: String? = null,
        lat: Double = 0.0,
        lon: Double = 0.0,
        hae: Double = 0.0,
        messageId: String = UUID.randomUUID().toString(),
    ): Generated {
        val now = DateTimeFormatter.ISO_INSTANT.format(Instant.now())
        val stale = DateTimeFormatter.ISO_INSTANT.format(Instant.now().plusSeconds(3600))

        val chatroom: String
        val marti: String
        if (isGroup) {
            chatroom = ChatRoom.ATAK_CHATROOM
            marti = ""
        } else {
            chatroom = recipientCallsign ?: ChatRoom.ATAK_CHATROOM
            marti = if (recipientCallsign != null) {
                "<marti><dest callsign=\"${escape(recipientCallsign)}\"/></marti>"
            } else {
                ""
            }
        }
        val chatgrpUid1 = if (isGroup) chatroom else (recipientUid ?: chatroom)

        val xml = buildString {
            append("""<?xml version="1.0" encoding="UTF-8"?>""")
            append(
                "<event version=\"2.0\" uid=\"GeoChat.${escape(senderUid)}.${escape(chatroom)}.${escape(messageId)}\" " +
                    "type=\"b-t-f\" time=\"$now\" start=\"$now\" stale=\"$stale\" how=\"h-g-i-g-o\">"
            )
            append("<point lat=\"$lat\" lon=\"$lon\" hae=\"$hae\" ce=\"9999999\" le=\"9999999\"/>")
            append("<detail>")
            append(
                "<__chat id=\"${escape(chatroom)}\" chatroom=\"${escape(chatroom)}\" " +
                    "senderCallsign=\"${escape(senderCallsign)}\" groupOwner=\"false\">"
            )
            append(
                "<chatgrp uid0=\"${escape(senderUid)}\" uid1=\"${escape(chatgrpUid1)}\" " +
                    "id=\"${escape(chatroom)}\"/>"
            )
            append("</__chat>")
            append(
                "<link uid=\"${escape(senderUid)}\" production_time=\"$now\" type=\"a-f-G-U-C\" " +
                    "parent_callsign=\"${escape(senderCallsign)}\" relation=\"p-p\"/>"
            )
            append(
                "<remarks source=\"BAO.F.OMNITAK.${escape(senderUid)}\" to=\"${escape(chatroom)}\" time=\"$now\">" +
                    escape(text) + "</remarks>"
            )
            append(marti)
            append("</detail>")
            append("</event>")
        }
        return Generated(xml, messageId)
    }

    /**
     * Parse a GeoChat (b-t-f) CoT event. Returns null if the XML is
     * not a chat message or is malformed. Direct-message detection
     * uses the chatroom name against ATAK's canonical broadcast label.
     */
    fun parse(xml: String, selfUid: String? = null): ChatMessage? {
        val factory = XmlPullParserFactory.newInstance().apply { isNamespaceAware = false }
        val parser = factory.newPullParser()
        parser.setInput(StringReader(xml))

        var type: String? = null
        var eventUid: String? = null
        var eventTime: String? = null
        var senderCallsign: String? = null
        var senderUid: String? = null
        var chatroom: String? = null
        var recipientUid: String? = null
        var recipientCallsign: String? = null
        var remarks: String? = null

        var event = parser.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            if (event == XmlPullParser.START_TAG) {
                when (parser.name) {
                    "event" -> {
                        type = parser.getAttributeValue(null, "type")
                        eventUid = parser.getAttributeValue(null, "uid")
                        eventTime = parser.getAttributeValue(null, "time")
                    }
                    "__chat", "_chat" -> {
                        senderCallsign = parser.getAttributeValue(null, "senderCallsign") ?: senderCallsign
                        chatroom = parser.getAttributeValue(null, "chatroom")
                            ?: parser.getAttributeValue(null, "id")
                            ?: chatroom
                    }
                    "chatgrp" -> {
                        senderUid = parser.getAttributeValue(null, "uid0") ?: senderUid
                        val uid1 = parser.getAttributeValue(null, "uid1")
                        if (uid1 != null && uid1 != chatroom) recipientUid = uid1
                    }
                    "link" -> {
                        if (senderUid == null) senderUid = parser.getAttributeValue(null, "uid")
                        if (senderCallsign == null) {
                            senderCallsign = parser.getAttributeValue(null, "parent_callsign")
                        }
                    }
                    "dest" -> {
                        recipientCallsign = parser.getAttributeValue(null, "callsign") ?: recipientCallsign
                    }
                    "remarks" -> {
                        val text = parser.nextText()
                        remarks = text
                    }
                }
            }
            event = parser.next()
        }

        if (type != "b-t-f") return null
        val finalSenderUid = senderUid ?: inferSenderUidFromEventUid(eventUid) ?: return null
        val finalSenderCallsign = senderCallsign ?: return null
        val finalText = remarks ?: return null

        val isGroup = chatroom == null ||
            chatroom.equals(ChatRoom.ATAK_CHATROOM, ignoreCase = true) ||
            chatroom.equals(ChatRoom.ALL_USERS, ignoreCase = true) ||
            chatroom.equals(ChatRoom.BROADCAST, ignoreCase = true) ||
            chatroom.lowercase().contains("all chat")

        val conversationId = if (isGroup) {
            ChatRoom.ALL_USERS
        } else if (selfUid != null) {
            ChatRoom.directConversationId(finalSenderUid, selfUid)
        } else {
            // Without a self-uid, fall back to grouping by peer.
            "DM-${finalSenderUid}"
        }

        return ChatMessage(
            id = eventUid ?: UUID.randomUUID().toString(),
            conversationId = conversationId,
            senderUid = finalSenderUid,
            senderCallsign = finalSenderCallsign,
            recipientUid = recipientUid,
            recipientCallsign = recipientCallsign,
            text = finalText,
            timeIso = eventTime ?: DateTimeFormatter.ISO_INSTANT.format(Instant.now()),
            status = ChatStatus.RECEIVED,
            isFromSelf = selfUid != null && finalSenderUid == selfUid,
        )
    }

    private fun inferSenderUidFromEventUid(eventUid: String?): String? {
        // ATAK/iTAK encode sender uid as the second dotted segment:
        //   GeoChat.<senderUid>.<chatroom>.<messageId>
        if (eventUid == null || !eventUid.startsWith("GeoChat.")) return null
        val parts = eventUid.split('.')
        return if (parts.size >= 2) parts[1] else null
    }

    private fun escape(raw: String): String =
        raw.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
            .replace("'", "&apos;")
}
