package soy.engindearing.omnitak.mobile.data

import java.util.UUID

enum class ChatStatus { SENDING, SENT, FAILED, RECEIVED }

/**
 * TAK GeoChat message. Mirrors the iOS ChatMessage minus image
 * attachments — image fileshare lands in a later slice alongside
 * the photo capture flow. conversationId is either [ChatRoom.ALL_USERS]
 * for broadcast traffic or a deterministic DM-{uidA}-{uidB} string.
 */
data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val conversationId: String,
    val senderUid: String,
    val senderCallsign: String,
    val recipientUid: String? = null,
    val recipientCallsign: String? = null,
    val text: String,
    val timeIso: String,
    val status: ChatStatus = ChatStatus.RECEIVED,
    val isFromSelf: Boolean = false,
)

data class ChatParticipant(
    val uid: String,
    val callsign: String,
)

data class ChatConversation(
    val id: String,
    val title: String,
    val isGroup: Boolean,
    val participants: List<ChatParticipant> = emptyList(),
    val lastMessagePreview: String? = null,
    val lastActivityIso: String? = null,
    val unread: Int = 0,
)

object ChatRoom {
    // ATAK's canonical broadcast chatroom name — interop with ATAK/iTAK.
    const val ATAK_CHATROOM = "All Chat Rooms"
    const val ALL_USERS = "All Chat Users"
    const val BROADCAST = "BROADCAST"

    fun directConversationId(uidA: String, uidB: String): String {
        val sorted = listOf(uidA, uidB).sorted()
        return "DM-${sorted[0]}-${sorted[1]}"
    }
}
