# MapViewController.swift Required Changes

## Quick Reference Guide

This document shows exactly what to change in MapViewController.swift to add chat functionality.

---

## CHANGE 1: Add showChat State Variable

**Find this section (around line 16-23):**
```swift
@State private var showServerConfig = false
@State private var showLayersPanel = false
@State private var showDrawingPanel = false
@State private var showDrawingList = false
@State private var mapType: MKMapType = .satellite
```

**Add this line:**
```swift
@State private var showServerConfig = false
@State private var showLayersPanel = false
@State private var showDrawingPanel = false
@State private var showDrawingList = false
@State private var showChat = false  // ADD THIS LINE
@State private var mapType: MKMapType = .satellite
```

---

## CHANGE 2: Update ATAKBottomToolbar Call

**Find this section (around line 108-117):**
```swift
ATAKBottomToolbar(
    mapType: $mapType,
    showLayersPanel: $showLayersPanel,
    showDrawingPanel: $showDrawingPanel,
    showDrawingList: $showDrawingList,
    onCenterUser: centerOnUser,
    onSendCoT: sendSelfPosition,
    onZoomIn: zoomIn,
    onZoomOut: zoomOut
)
```

**Change to:**
```swift
ATAKBottomToolbar(
    mapType: $mapType,
    showLayersPanel: $showLayersPanel,
    showDrawingPanel: $showDrawingPanel,
    showDrawingList: $showDrawingList,
    showChat: $showChat,  // ADD THIS LINE
    onCenterUser: centerOnUser,
    onSendCoT: sendSelfPosition,
    onZoomIn: zoomIn,
    onZoomOut: zoomOut
)
```

---

## CHANGE 3: Add Chat Sheet

**Find this section (around line 184-187):**
```swift
.sheet(isPresented: $showServerConfig) {
    ServerConfigView(takService: takService)
}
.onAppear {
```

**Change to:**
```swift
.sheet(isPresented: $showServerConfig) {
    ServerConfigView(takService: takService)
}
.sheet(isPresented: $showChat) {  // ADD THIS BLOCK
    ChatView(chatManager: ChatManager.shared)
}
.onAppear {
```

---

## CHANGE 4: Add setupChatIntegration Call

**Find this section (around line 187-190):**
```swift
.onAppear {
    setupTAKConnection()
    startLocationUpdates()
}
```

**Change to:**
```swift
.onAppear {
    setupTAKConnection()
    startLocationUpdates()
    setupChatIntegration()  // ADD THIS LINE
}
```

---

## CHANGE 5: Add setupChatIntegration Method

**Find the startLocationUpdates() method (around line 207-209):**
```swift
private func startLocationUpdates() {
    locationManager.startUpdating()
}
```

**Add this method right after it:**
```swift
private func startLocationUpdates() {
    locationManager.startUpdating()
}

// ADD THIS ENTIRE METHOD:
private func setupChatIntegration() {
    // Configure ChatManager with TAKService and LocationManager
    ChatManager.shared.configure(takService: takService, locationManager: locationManager)

    // Register callback for incoming chat messages
    takService.onChatMessageReceived = { chatMessage in
        ChatManager.shared.receiveMessage(chatMessage)
    }
}
```

---

## CHANGE 6: Update ATAKBottomToolbar Struct

**Find the ATAKBottomToolbar struct (around line 336-390):**

Replace the entire struct with this:

```swift
struct ATAKBottomToolbar: View {
    @Binding var mapType: MKMapType
    @Binding var showLayersPanel: Bool
    @Binding var showDrawingPanel: Bool
    @Binding var showDrawingList: Bool
    @Binding var showChat: Bool  // ADD THIS LINE
    let onCenterUser: () -> Void
    let onSendCoT: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    // ADD THIS COMPUTED PROPERTY:
    var totalUnreadCount: Int {
        ChatManager.shared.conversations.reduce(0) { $0 + $1.unreadCount }
    }

    var body: some View {
        HStack(spacing: 20) {
            // Layers
            ToolButton(icon: "square.stack.3d.up.fill", label: "Layers") {
                showLayersPanel.toggle()
            }

            Spacer()

            // Center on User
            ToolButton(icon: "location.fill", label: "GPS") {
                onCenterUser()
            }

            // Send Position
            ToolButton(icon: "paperplane.fill", label: "Broadcast") {
                onSendCoT()
            }

            // Zoom Controls
            VStack(spacing: 8) {
                ToolButton(icon: "plus", label: "", compact: true) {
                    onZoomIn()
                }
                ToolButton(icon: "minus", label: "", compact: true) {
                    onZoomOut()
                }
            }

            Spacer()

            // ADD THIS ENTIRE CHAT BUTTON BLOCK:
            ZStack(alignment: .topTrailing) {
                ToolButton(icon: "message.fill", label: "Chat") {
                    showChat.toggle()
                }

                if totalUnreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                        Text("\(totalUnreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 8, y: -8)
                }
            }
            // END CHAT BUTTON BLOCK

            // Drawing Tools
            ToolButton(icon: "pencil.tip.crop.circle", label: "Draw") {
                showDrawingPanel.toggle()
            }

            // Drawing List
            ToolButton(icon: "list.bullet", label: "Shapes") {
                showDrawingList.toggle()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
```

---

## Summary of Changes

1. ✓ Add `@State private var showChat = false` state variable
2. ✓ Pass `showChat: $showChat` to ATAKBottomToolbar
3. ✓ Add `.sheet(isPresented: $showChat)` for ChatView
4. ✓ Call `setupChatIntegration()` in `.onAppear`
5. ✓ Add `setupChatIntegration()` method implementation
6. ✓ Update ATAKBottomToolbar to include:
   - `@Binding var showChat: Bool` parameter
   - `totalUnreadCount` computed property
   - Chat button with unread badge in body

---

## Testing After Changes

1. Build the app (Cmd+B)
2. Run the app (Cmd+R)
3. Look for chat button (message icon) in bottom toolbar
4. Tap chat button to open chat interface
5. Verify "All Chat Users" conversation exists
6. Send a test message
7. Verify unread badge appears when messages arrive

---

## Troubleshooting

**Build Error: "Cannot find 'ChatView' in scope"**
- Make sure all chat files are added to the Xcode project
- Check that ChatView.swift is in the target membership

**Build Error: "Cannot find 'ChatManager' in scope"**
- Make sure ChatManager.swift is added to the Xcode project
- Check that it's in the target membership

**Runtime Error: Crash when opening chat**
- Check that ChatManager.shared is initialized
- Verify TAKService integration is set up correctly

**Messages not sending**
- Verify TAK server connection is active
- Check that setupChatIntegration() is being called
- Ensure location services are enabled
