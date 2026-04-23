package soy.engindearing.omnitak.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import soy.engindearing.omnitak.mobile.OmniTAKApp
import soy.engindearing.omnitak.mobile.data.ChatConversation
import soy.engindearing.omnitak.mobile.data.ChatMessage
import soy.engindearing.omnitak.mobile.data.ChatRoom
import soy.engindearing.omnitak.mobile.data.ChatStatus
import soy.engindearing.omnitak.mobile.data.ChatXml
import soy.engindearing.omnitak.mobile.data.UserPrefs
import soy.engindearing.omnitak.mobile.domain.ChatStore
import soy.engindearing.omnitak.mobile.domain.ServerManager
import soy.engindearing.omnitak.mobile.ui.theme.TacticalAccent
import soy.engindearing.omnitak.mobile.ui.theme.TacticalBackground
import soy.engindearing.omnitak.mobile.ui.theme.TacticalSurface
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen() {
    val app = LocalContext.current.applicationContext as OmniTAKApp
    val conversations by app.chatStore.conversations.collectAsState()
    val messagesByConvo by app.chatStore.messagesByConversation.collectAsState()
    val prefs by app.userPrefsStore.prefs.collectAsState(initial = UserPrefs())

    var selectedConversation by remember { mutableStateOf<String?>(null) }

    if (selectedConversation == null) {
        ConversationListView(
            conversations = conversations.values.sortedByDescending { it.lastActivityIso ?: "" },
            onSelect = { id ->
                app.chatStore.markRead(id)
                selectedConversation = id
            },
        )
    } else {
        val convo = conversations[selectedConversation]
        val messages = messagesByConvo[selectedConversation].orEmpty()
        if (convo == null) {
            selectedConversation = null
            return
        }
        ConversationDetailView(
            conversation = convo,
            messages = messages,
            selfUid = selfUidFor(prefs),
            selfCallsign = prefs.callsign,
            onBack = { selectedConversation = null },
            onSend = { text -> sendChat(app, convo, prefs, text) },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ConversationListView(
    conversations: List<ChatConversation>,
    onSelect: (String) -> Unit,
) {
    Scaffold(
        containerColor = TacticalBackground,
        topBar = {
            TopAppBar(
                title = { Text("Chat", color = MaterialTheme.colorScheme.onBackground) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = TacticalBackground,
                    titleContentColor = MaterialTheme.colorScheme.onBackground,
                ),
            )
        },
    ) { inner: PaddingValues ->
        if (conversations.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(inner),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "No chat traffic yet.",
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                )
            }
            return@Scaffold
        }
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
            items(conversations, key = { it.id }) { convo ->
                ConversationRow(convo = convo, onClick = { onSelect(convo.id) })
                HorizontalDivider(color = TacticalSurface)
            }
        }
    }
}

@Composable
private fun ConversationRow(convo: ChatConversation, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                convo.title,
                color = MaterialTheme.colorScheme.onBackground,
                fontWeight = FontWeight.SemiBold,
                style = MaterialTheme.typography.bodyLarge,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                convo.lastMessagePreview ?: if (convo.isGroup) "Broadcast chat" else "No messages yet",
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                style = MaterialTheme.typography.bodySmall,
                maxLines = 1,
            )
        }
        if (convo.unread > 0) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .background(TacticalAccent)
                    .padding(horizontal = 8.dp, vertical = 2.dp),
            ) {
                Text(
                    "${convo.unread}",
                    color = Color.Black,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ConversationDetailView(
    conversation: ChatConversation,
    messages: List<ChatMessage>,
    selfUid: String,
    selfCallsign: String,
    onBack: () -> Unit,
    onSend: (String) -> Unit,
) {
    var draft by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) listState.animateScrollToItem(messages.size - 1)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(TacticalBackground),
    ) {
        // Header row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(TacticalBackground)
                .padding(horizontal = 4.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = MaterialTheme.colorScheme.onBackground,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    conversation.title,
                    color = MaterialTheme.colorScheme.onBackground,
                    fontWeight = FontWeight.SemiBold,
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    if (conversation.isGroup) "Broadcast" else "Direct message",
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }
        HorizontalDivider(color = TacticalSurface)

        LazyColumn(
            state = listState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            items(messages, key = { it.id }) { msg ->
                MessageBubble(msg = msg, selfUid = selfUid)
            }
        }

        HorizontalDivider(color = TacticalSurface)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(TacticalBackground)
                .imePadding()
                .padding(horizontal = 8.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedTextField(
                value = draft,
                onValueChange = { draft = it },
                placeholder = { Text("Message", color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f)) },
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                maxLines = 4,
                modifier = Modifier.weight(1f),
                colors = TextFieldDefaults.colors(
                    focusedTextColor = MaterialTheme.colorScheme.onBackground,
                    unfocusedTextColor = MaterialTheme.colorScheme.onBackground,
                    focusedContainerColor = TacticalSurface,
                    unfocusedContainerColor = TacticalSurface,
                    focusedIndicatorColor = TacticalAccent,
                    unfocusedIndicatorColor = TacticalAccent.copy(alpha = 0.4f),
                    cursorColor = TacticalAccent,
                ),
            )
            Spacer(Modifier.width(6.dp))
            IconButton(
                onClick = {
                    val trimmed = draft.trim()
                    if (trimmed.isNotEmpty()) {
                        onSend(trimmed)
                        draft = ""
                    }
                },
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.Send,
                    contentDescription = "Send",
                    tint = TacticalAccent,
                )
            }
        }
    }
}

@Composable
private fun MessageBubble(msg: ChatMessage, selfUid: String) {
    val isFromSelf = msg.isFromSelf || msg.senderUid == selfUid
    val bubbleColor = if (isFromSelf) TacticalAccent.copy(alpha = 0.25f) else TacticalSurface
    val alignment = if (isFromSelf) Alignment.End else Alignment.Start

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = alignment,
    ) {
        if (!isFromSelf) {
            Text(
                msg.senderCallsign,
                color = TacticalAccent,
                style = MaterialTheme.typography.labelSmall,
                fontFamily = FontFamily.Monospace,
                modifier = Modifier.padding(start = 10.dp, bottom = 2.dp),
            )
        }
        Box(
            modifier = Modifier
                .widthIn(max = 280.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(bubbleColor)
                .padding(horizontal = 12.dp, vertical = 8.dp),
        ) {
            Column {
                Text(
                    msg.text,
                    color = MaterialTheme.colorScheme.onBackground,
                    style = MaterialTheme.typography.bodyMedium,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    formatTime(msg.timeIso) + statusSuffix(msg.status, isFromSelf),
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.5f),
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }
    }
}

private fun statusSuffix(status: ChatStatus, isFromSelf: Boolean): String {
    if (!isFromSelf) return ""
    return when (status) {
        ChatStatus.SENDING -> " · sending"
        ChatStatus.SENT -> " · sent"
        ChatStatus.FAILED -> " · failed"
        ChatStatus.RECEIVED -> ""
    }
}

private val LOCAL_TIME_FMT = DateTimeFormatter.ofPattern("HH:mm:ss").withZone(ZoneId.systemDefault())

private fun formatTime(iso: String): String = runCatching {
    LOCAL_TIME_FMT.format(Instant.parse(iso))
}.getOrElse { iso }

/**
 * Derive a stable self-UID from the operator's callsign + team so it
 * survives app restarts without needing a separate setting. Real
 * device UIDs come from the presence CoT once that lands in a later slice.
 */
private fun selfUidFor(prefs: UserPrefs): String =
    "OMNITAK-ANDROID-${prefs.callsign}-${prefs.team}"

private fun sendChat(
    app: OmniTAKApp,
    convo: ChatConversation,
    prefs: UserPrefs,
    text: String,
) {
    val senderUid = selfUidFor(prefs)
    val recipient = convo.participants.firstOrNull { it.uid != senderUid }
    val isGroup = convo.isGroup

    val generated = ChatXml.generateGeoChat(
        text = text,
        senderUid = senderUid,
        senderCallsign = prefs.callsign,
        isGroup = isGroup,
        recipientUid = recipient?.uid,
        recipientCallsign = recipient?.callsign,
        messageId = UUID.randomUUID().toString(),
    )
    val now = DateTimeFormatter.ISO_INSTANT.format(Instant.now())
    val message = ChatMessage(
        id = generated.messageId,
        conversationId = convo.id,
        senderUid = senderUid,
        senderCallsign = prefs.callsign,
        recipientUid = recipient?.uid,
        recipientCallsign = recipient?.callsign,
        text = text,
        timeIso = now,
        status = ChatStatus.SENDING,
        isFromSelf = true,
    )
    app.chatStore.markOutgoing(message)

    val sent = app.serverManager.sendCoT(generated.xml)
    app.chatStore.updateMessageStatus(
        conversationId = convo.id,
        messageId = generated.messageId,
        status = if (sent) ChatStatus.SENT else ChatStatus.FAILED,
    )
}
