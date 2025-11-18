# OmniTAK iOS - Deployment Guide

##  Deploy to Real iPhone

### Prerequisites
- Mac with Xcode installed
- iPhone (iOS 15.0+)
- USB cable or WiFi network
- Apple Developer account (free or paid)

### Step 1: Connect iPhone
```bash
# Connect iPhone via USB
# Unlock iPhone and tap "Trust This Computer" if prompted
```

### Step 2: Select Device in Xcode
```bash
# Open the project
cd apps/omnitak_ios_test
open OmniTAKTest.xcodeproj

# In Xcode:
# 1. Click the device selector (top toolbar)
# 2. Select your connected iPhone
# 3. If device doesn't appear, check cable connection
```

### Step 3: Configure Signing
```
1. Select "OmniTAKTest" project in navigator
2. Select "OmniTAKTest" target
3. Go to "Signing & Capabilities" tab
4. Check "Automatically manage signing"
5. Select your Team (personal or organization)
6. Xcode will automatically create provisioning profile
```

### Step 4: Build and Run
```bash
# In Xcode: Press ⌘R or click Run button
# Wait for build to complete (~30 seconds)
# App will install and launch on iPhone
```

### Step 5: Trust Developer (First Time Only)
```
If you see "Untrusted Developer" on iPhone:
1. Go to Settings → General → VPN & Device Management
2. Tap your developer profile
3. Tap "Trust [Your Name]"
4. Confirm with "Trust"
5. Return to home screen and launch OmniTAK
```

### Step 6: Grant Location Permissions
```
When prompted:
1. Tap "Allow While Using App" or "Allow Once"
2. For best experience, tap "Allow While Using App"
3. Blue GPS dot will appear on map
```

##  Connect to TAK Server

### Default Server
- Host: `204.48.30.216`
- Port: `8087`
- Protocol: TCP
- Auto-connects on app launch

### Change Server
```
1. Tap the TAK indicator in top status bar (green/red dot)
2. Enter new Host and Port
3. Toggle TLS if needed
4. Tap "Connect"
5. Watch for green indicator
```

### Test Connectivity
```
1. Wait for green TAK indicator
2. Tap "Broadcast" button (paper plane icon)
3. Watch TX counter increment
4. If other TAK clients are connected, you'll see:
   - RX counter increment when they send positions
   - Their icons appear on map
```

##  Using the Map

### Navigation
- **Pan**: Drag with one finger
- **Zoom**: Pinch with two fingers
- **Rotate**: Twist with two fingers

### Toolbar Buttons
- **GPS** (): Center map on your location, zoom to tactical view
- **Broadcast** (): Send your position to TAK server
- **Zoom +** (+): Zoom in (more detail)
- **Zoom -** (-): Zoom out (wider view)
- **Measure** (): Distance measurement (coming soon)
- **Route** (): Route planning (coming soon)

### Layers Panel
```
1. Tap "Layers" button (left side)
2. Select map type:
   - Satellite: Aerial imagery
   - Hybrid: Satellite + roads/labels
   - Standard: Street map
3. Toggle overlays:
   - Friendly: Cyan units
   - Hostile: Red units
   - Unknown: Yellow units
```

##  Tactical Features

### Self-Position Broadcast
Your CoT message includes:
- GPS coordinates (lat/lon)
- Altitude (HAE)
- Accuracy (CE/LE)
- Speed and course
- Callsign: "OmniTAK-iOS"
- Team: Cyan (friendly)
- Device info: iPhone, iOS version

### Receiving Team Positions
When teammates send positions:
- Icons appear on map at their location
- Callsign displays below icon
- Color indicates team (cyan/red/yellow)
- Updates automatically as they move

### Connection Status
Top status bar shows:
- **Green dot**: Connected to TAK server
- **Red dot**: Disconnected
- **RX counter**: Messages received
- **TX counter**: Messages sent
- **GPS accuracy**: ±Xm (lower is better)

##  Troubleshooting

### "Unable to install"
```
Solution: Delete old version of app from iPhone
1. Long-press OmniTAK icon on home screen
2. Tap "Remove App"
3. Rebuild and install from Xcode
```

### "Code Signing Error"
```
Solution: Select your development team
1. In Xcode → Signing & Capabilities
2. Change Team to your Apple ID
3. Clean build folder (⌘⇧K)
4. Build again (⌘B)
```

### GPS not working
```
Solution: Check location permissions
1. Settings → OmniTAK → Location
2. Set to "While Using the App" or "Always"
3. Relaunch app
```

### TAK connection fails
```
Solution: Check network and firewall
1. Verify iPhone has internet (WiFi or cellular)
2. Check server is reachable:
   - On Mac: nc -zv 204.48.30.216 8087
3. Try different protocol (TCP → TLS)
4. Check firewall rules on TAK server
```

### No messages received
```
Solution: Verify server is sending
1. Check RX counter in status bar
2. Ensure other TAK clients are broadcasting
3. Tap status bar to see last message
4. Check console logs in Xcode
```

##  Performance Tips

### Battery Life
- Use "While Using App" location permission (not "Always")
- Lower screen brightness
- Close other apps
- Enable Low Power Mode for extended ops

### Network Usage
- TAK connection uses minimal data (~10-50 KB/min)
- Works on both WiFi and cellular
- Use WiFi when available for best reliability

### GPS Accuracy
- Best: Clear sky, outdoor, stationary
- Good: Outdoor, moving
- Fair: Near windows, slow movement
- Poor: Indoor, dense urban

##  Field Deployment

### Pre-Mission Checklist
- [ ] iPhone fully charged
- [ ] Location permissions granted
- [ ] TAK server configured
- [ ] Test broadcast working
- [ ] Team members connected
- [ ] Backup power bank available

### During Mission
- Monitor GPS accuracy (keep <10m)
- Broadcast position regularly (every 30-60s)
- Watch for team member updates
- Note any connection issues

### Post-Mission
- Review message logs
- Report any bugs or issues
- Charge devices
- Update server config if needed

##  Emergency Use

### Lost Connection
1. Check TAK indicator (should be green)
2. Tap status bar to reconnect
3. Try toggling airplane mode
4. Restart app if needed

### GPS Lost
1. Check GPS accuracy in status bar
2. Move to clearer area
3. Wait for signal acquisition
4. Use last known position

### Critical Comms
- TAK messages are NOT encrypted by default
- Use TLS for sensitive operations
- Coordinate with team on protocol
- Have backup comms plan (radio, phone)

##  Additional Info

### System Requirements
- iPhone: 6S or newer
- iOS: 15.0 or later
- Storage: ~50 MB
- RAM: Works on all models

### Supported Protocols
-  TCP (default)
-  TLS/SSL
-  WebSocket
-  UDP (ready, not tested)

### Supported CoT Types
-  Point (position) events
-  Friendly (a-f-*)
-  Hostile (a-h-*)
-  Unknown (a-u-*)
-  Shape events (coming soon)
-  Route events (coming soon)

##  Success Criteria

Your deployment is successful when:
-  Green TAK indicator shows
-  Your position appears on teammate's maps
-  Teammate positions appear on your map
-  Message counters increment
-  GPS accuracy <10m

##  Support

For issues or questions:
1. Check FEATURE_VERIFICATION.md
2. Review console logs in Xcode
3. Test on simulator first
4. File issue on GitHub

---

**You're ready to deploy! Good luck in the field! **
