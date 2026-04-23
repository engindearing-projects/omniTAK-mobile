package soy.engindearing.omnitak.mobile

import android.app.Application
import soy.engindearing.omnitak.mobile.data.TAKServerStore
import soy.engindearing.omnitak.mobile.domain.ServerManager

class OmniTAKApp : Application() {
    // Application-scoped singletons. Screens reach these via
    // LocalContext.current.applicationContext as OmniTAKApp.
    val serverManager: ServerManager by lazy { ServerManager(TAKServerStore(this)) }
}
