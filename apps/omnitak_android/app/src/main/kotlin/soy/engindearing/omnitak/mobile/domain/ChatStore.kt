package soy.engindearing.omnitak.mobile.domain

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import soy.engindearing.omnitak.mobile.data.ChatConversation
import soy.engindearing.omnitak.mobile.data.ChatMessage
import soy.engindearing.omnitak.mobile.data.ChatParticipant
import soy.engindearing.omnitak.mobile.data.ChatRoom
import soy.engindearing.omnitak.mobile.data.ChatStatus

/**
 * In-memory chat log. Keyed by conversationId → ordered list of messages,
 * plus a parallel map of conversation metadata. Everything sits behind
 * StateFlows so Compose screens observe reactively.
 *
 * A broadcast conversation ([ChatRoom.ALL_USERS]) is seeded on creation
 * so the "team chat" tab has a sensible landing target before any
 * contacts are discovered.
 */
class ChatStore {

    private val _conversations = MutableStateFlow<Map<String, ChatConversation>>(
        mapOf(
            ChatRoom.ALL_USERS to ChatConversation(
                id = ChatRoom.ALL_USERS,
                title = ChatRoom.ALL_USERS,
                isGroup = true,
            )
        )
    )
    val conversations: StateFlow<Map<String, ChatConversation>> = _conversations.asStateFlow()

    private val _messagesByConversation = MutableStateFlow<Map<String, List<ChatMessage>>>(emptyMap())
    val messagesByConversation: StateFlow<Map<String, List<ChatMessage>>> = _messagesByConversation.asStateFlow()

    fun ingest(message: ChatMessage) {
        val existing = _messagesByConversation.value[message.conversationId].orEmpty()
        if (existing.any { it.id == message.id }) return
        _messagesByConversation.value = _messagesByConversation.value +
            (message.conversationId to (existing + message).sortedBy { it.timeIso })
        upsertConversation(message, incrementUnread = !message.isFromSelf)
    }

    fun markOutgoing(message: ChatMessage) {
        val existing = _messagesByConversation.value[message.conversationId].orEmpty()
        _messagesByConversation.value = _messagesByConversation.value +
            (message.conversationId to (existing + message).sortedBy { it.timeIso })
        upsertConversation(message, incrementUnread = false)
    }

    fun updateMessageStatus(conversationId: String, messageId: String, status: ChatStatus) {
        val list = _messagesByConversation.value[conversationId].orEmpty()
        val idx = list.indexOfFirst { it.id == messageId }
        if (idx < 0) return
        val updated = list.toMutableList()
        updated[idx] = updated[idx].copy(status = status)
        _messagesByConversation.value = _messagesByConversation.value + (conversationId to updated)
    }

    fun markRead(conversationId: String) {
        val convo = _conversations.value[conversationId] ?: return
        if (convo.unread == 0) return
        _conversations.value = _conversations.value + (conversationId to convo.copy(unread = 0))
    }

    private fun upsertConversation(message: ChatMessage, incrementUnread: Boolean) {
        val current = _conversations.value[message.conversationId]
        val isGroup = message.conversationId == ChatRoom.ALL_USERS
        val title = current?.title
            ?: if (isGroup) ChatRoom.ALL_USERS else message.senderCallsign

        val participants = (current?.participants.orEmpty() + ChatParticipant(
            uid = message.senderUid,
            callsign = message.senderCallsign,
        )).distinctBy { it.uid }

        val next = (current ?: ChatConversation(
            id = message.conversationId,
            title = title,
            isGroup = isGroup,
        )).copy(
            title = title,
            participants = participants,
            lastMessagePreview = message.text,
            lastActivityIso = message.timeIso,
            unread = (current?.unread ?: 0) + if (incrementUnread) 1 else 0,
        )
        _conversations.value = _conversations.value + (message.conversationId to next)
    }
}
