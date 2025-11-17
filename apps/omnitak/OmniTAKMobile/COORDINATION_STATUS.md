# OmniTAK iOS Emergency Feature Implementation - Coordination Status

**Last Updated:** 2025-11-15
**Project Coordinator:** Multi-Agent Implementation System
**Base Directory:** `/Users/iesouskurios/omni-BASE/apps/omnitak_ios_test/OmniTAKMobile/`

---

## Agent Tracking Table

| Agent ID | Feature | Status | Files Created/Modified | Dependencies | Blockers |
|----------|---------|--------|------------------------|--------------|----------|
| **Agent 1** | Certificate Enrollment (QR Code) | PENDING | TBD | ServerManager.swift, TAKService.swift | None |
| **Agent 2** | CoT Receiving (Incoming Messages) | PENDING | TBD | TAKService.swift, ChatXMLParser.swift | None |
| **Agent 3** | Emergency Beacon (SOS/Panic) | PENDING | TBD | TAKService.swift, LocationManager | None |
| **Agent 4** | KML/KMZ Import | PENDING | TBD | MapViewController.swift, WaypointManager.swift | None |
| **Agent 5** | Photo Sharing (Image Attachments) | PENDING | TBD | ChatManager.swift, ChatModels.swift | None |

---

## Critical Shared Resources

### 1. TAKService.swift (HIGH CONTENTION)
**Used by:** Agent 2 (CoT Receiving), Agent 3 (Emergency Beacon), Agent 5 (Photo Sharing)

**Conflict Prevention:**
- Agent 2: Extend `cotCallback()` parsing logic - ADD new message type handlers
- Agent 3: ADD new method `sendEmergencyBeacon()` - do NOT modify existing `sendCoT()`
- Agent 5: ADD new method for binary data transmission

**Safe Modification Zones:**
- Line 241+: Add new callback handlers (onEmergencyReceived, onImageReceived)
- Line 360+: Add new send methods (separate from existing sendCoT, sendChatMessage)
- Line 570+: Extend cotCallback parsing with new type detection

### 2. ChatManager.swift (MEDIUM CONTENTION)
**Used by:** Agent 5 (Photo Sharing)

**Safe Modification Zones:**
- Add new message types for image attachments
- Extend ChatMessage model (in ChatModels.swift)
- Add image storage/retrieval methods

### 3. ServerManager.swift (MEDIUM CONTENTION)
**Used by:** Agent 1 (Certificate Enrollment)

**Safe Modification Zones:**
- Add certificate import/export methods
- Extend TAKServer struct for certificate metadata
- Add QR code parsing functionality

### 4. MapViewController.swift (LOW CONTENTION)
**Used by:** Agent 3 (Emergency Beacon - UI), Agent 4 (KML Import)

**Safe Modification Zones:**
- Agent 3: Add emergency button to toolbar
- Agent 4: Add KML layer rendering support

---

## Shared Interfaces Required

### EmergencyFeatureProtocol
```swift
protocol EmergencyFeatureProtocol {
    var isActive: Bool { get }
    func activate()
    func deactivate()
    func sendAlert()
}
```

### FileImportProtocol
```swift
protocol FileImportProtocol {
    static var supportedExtensions: [String] { get }
    func importFile(from url: URL) -> Bool
    func parseContents() throws
}
```

### MediaAttachmentProtocol
```swift
protocol MediaAttachmentProtocol {
    var attachmentType: AttachmentType { get }
    var data: Data { get }
    func toCoTXML() -> String
}
```

### CertificateManagerProtocol
```swift
protocol CertificateManagerProtocol {
    func importFromQRCode(data: String) -> Bool
    func validateCertificate() -> Bool
    func storeCertificate(name: String, password: String) -> Bool
}
```

---

## Integration Checkpoints

### Checkpoint 1: Foundation Layer (Before Implementation)
- [ ] All agents review SHARED_INTERFACES.swift
- [ ] Confirm no duplicate protocol definitions
- [ ] Establish notification naming conventions

### Checkpoint 2: File Conflict Resolution
- [ ] Agent 2 & 3: Coordinate TAKService.swift modifications
- [ ] Agent 5: Verify ChatModels.swift extensions don't conflict
- [ ] Agent 1: Ensure ServerManager changes are additive

### Checkpoint 3: UI Integration
- [ ] Agent 3 & 4: Coordinate MapViewController toolbar additions
- [ ] Establish consistent UI patterns (icons, colors, alerts)
- [ ] Test navigation flow between features

### Checkpoint 4: CoT Protocol Compliance
- [ ] Agent 2: Document all new CoT message types being handled
- [ ] Agent 3: Emergency beacon XML format validation
- [ ] Agent 5: Binary attachment protocol specification

### Checkpoint 5: Data Persistence
- [ ] Agent 4: KML import storage location
- [ ] Agent 5: Image attachment storage (file system vs. database)
- [ ] Agent 1: Certificate secure storage (Keychain)

---

## Potential Conflict Areas

### HIGH RISK - TAKService Callback System
**Issue:** Multiple agents extending `cotCallback()` function
**Solution:** Use message type routing pattern:
```swift
// Agent 2: Standard CoT
if message.contains("type=\"a-") { /* position update */ }

// Agent 3: Emergency
if message.contains("type=\"b-a-") { /* emergency alert */ }

// Agent 5: Photo
if message.contains("type=\"b-i-") { /* image data */ }
```

### MEDIUM RISK - ChatMessage Type Extensions
**Issue:** Agent 5 adding image type may conflict with existing message handling
**Solution:** Extend enum, don't replace:
```swift
enum ChatMessageType: String, Codable {
    case text
    case geochat
    case system
    case image      // Agent 5 adds this
    case emergency  // Agent 3 may need this
}
```

### MEDIUM RISK - App Entry Point Modifications
**Issue:** Multiple agents may try to initialize services in OmniTAKMobileApp.swift
**Solution:** Use centralized FeatureRegistry (provided in SHARED_INTERFACES.swift)

### LOW RISK - Notification Name Collisions
**Issue:** Different agents using same notification names
**Solution:** Use namespaced notification names:
```swift
Notification.Name("OmniTAK.Emergency.Activated")
Notification.Name("OmniTAK.Certificate.Imported")
Notification.Name("OmniTAK.KML.Imported")
Notification.Name("OmniTAK.Photo.Attached")
```

---

## Testing Requirements

### Unit Tests (Per Agent)
- **Agent 1:** QR code parsing, certificate validation, keychain storage
- **Agent 2:** XML parsing for all CoT types, message routing
- **Agent 3:** Emergency CoT generation, beacon timing, location accuracy
- **Agent 4:** KML/KMZ file parsing, coordinate conversion, layer rendering
- **Agent 5:** Image compression, attachment encoding, file size limits

### Integration Tests (Cross-Agent)
1. **Certificate + Connection:** Import cert via QR, then connect with TLS
2. **Emergency + Map:** Trigger beacon, verify marker appears on map
3. **Photo + Chat:** Send image, verify delivery via CoT receiving
4. **KML + Emergency:** Import KML with emergency zones, test geofence alerts

### End-to-End Tests
1. Full connection flow with new certificate
2. Emergency beacon broadcast and team notification
3. Multi-format import (KML + photos in single session)
4. Offline capabilities for each feature

---

## Recommended Implementation Sequence

**Phase 1: Foundation (Parallel)**
- Agent 1: Certificate manager skeleton
- Agent 2: CoT parsing infrastructure
- Agent 4: File import handler

**Phase 2: Core Features (Parallel with caution)**
- Agent 3: Emergency beacon logic (after Agent 2 completes parsing)
- Agent 5: Photo attachment model (after Agent 2 completes)

**Phase 3: UI Integration (Sequential)**
- All agents integrate with main UI
- Coordinate changes to MapViewController.swift
- Test cross-feature interactions

**Phase 4: Testing & Polish**
- Integration testing
- Error handling
- Performance optimization

---

## Communication Protocol

### File Locking Convention
When modifying shared files, agents should:
1. Add comment header: `// AGENT {N} MODIFICATION START - {Feature}`
2. Keep modifications in clearly bounded sections
3. Add comment footer: `// AGENT {N} MODIFICATION END`

### Conflict Resolution
If two agents need to modify the same function:
1. First agent creates extension protocol
2. Second agent implements via protocol conformance
3. Coordinator reviews for consistency

### Progress Reporting
Agents update this file with:
- Files created/modified
- New dependencies introduced
- Any blockers encountered
- Testing status

---

## File Ownership Matrix

| File | Primary Owner | Can Modify | Read Only |
|------|--------------|------------|-----------|
| TAKService.swift | Shared | Agent 2, 3 | Agent 1, 4, 5 |
| ChatManager.swift | Agent 5 | Agent 5 | All others |
| ServerManager.swift | Agent 1 | Agent 1 | All others |
| MapViewController.swift | Shared | Agent 3, 4 | Agent 1, 2, 5 |
| ChatModels.swift | Agent 5 | Agent 5 | Agent 2, 3 |
| SHARED_INTERFACES.swift | Coordinator | All (additive) | - |
| OmniTAKMobileApp.swift | Coordinator | Agent 3 (hooks) | All others |

---

## Success Criteria

1. **No Merge Conflicts:** All agent code compiles together without conflicts
2. **Feature Independence:** Each feature can be enabled/disabled independently
3. **Consistent UX:** All new features follow existing ATAK-style patterns
4. **Protocol Compliance:** All CoT messages validate against TAK specifications
5. **Performance:** No degradation in app startup or map rendering
6. **Security:** Certificate handling follows iOS security best practices

---

## Contact Points

- **Integration Issues:** Raise in this document under "Blockers" column
- **Protocol Questions:** Reference TAK specifications or existing implementations
- **UI Consistency:** Follow patterns in SharedUIComponents.swift
- **Build Failures:** Check Info.plist for required permissions (Camera, Location, Files)

---

**Next Update:** After all agents complete Phase 1 (Foundation)
