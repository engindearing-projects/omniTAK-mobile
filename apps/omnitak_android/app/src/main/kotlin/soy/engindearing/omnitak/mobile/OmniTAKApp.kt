package soy.engindearing.omnitak.mobile

import android.app.Application
import soy.engindearing.omnitak.mobile.data.TAKServerStore
import soy.engindearing.omnitak.mobile.data.UserPrefsStore
import soy.engindearing.omnitak.mobile.domain.ChatStore
import soy.engindearing.omnitak.mobile.domain.ContactStore
import soy.engindearing.omnitak.mobile.domain.DrawingStore
import soy.engindearing.omnitak.mobile.domain.MeshtasticManager
import soy.engindearing.omnitak.mobile.domain.ServerManager

class OmniTAKApp : Application() {
    // Application-scoped singletons. Screens reach these via
    // LocalContext.current.applicationContext as OmniTAKApp.
    val contactStore: ContactStore by lazy { ContactStore() }
    val drawingStore: DrawingStore by lazy { DrawingStore() }
    val chatStore: ChatStore by lazy { ChatStore() }
    val meshtastic: MeshtasticManager by lazy { MeshtasticManager() }
    val userPrefsStore: UserPrefsStore by lazy { UserPrefsStore(this) }
    val serverManager: ServerManager by lazy {
        ServerManager(TAKServerStore(this), contactStore, chatStore)
    }
}
