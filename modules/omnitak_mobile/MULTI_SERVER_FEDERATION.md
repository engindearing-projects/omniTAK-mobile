# Multi-Server Federation for OmniTAK

## Overview

OmniTAK now supports simultaneous connections to multiple TAK servers with intelligent data federation and selective sharing capabilities. This allows operators to:

- **Connect to multiple TAK servers simultaneously** instead of switching between them
- **Federate data from all connected servers** into a single operational picture
- **Selectively share data** based on configurable policies
- **Control blue team sharing** to automatically filter sensitive data
- **Deduplicate events** across multiple servers using UID tracking

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────┐
│              Multi-Server Federation Manager                 │
│  - Connection Management                                     │
│  - Data Federation & Deduplication                          │
│  - Policy Enforcement                                        │
│  - Event Distribution                                        │
└─────────────────────────────────────────────────────────────┘
                        │
                        │ Manages
                        ▼
┌──────────────┬──────────────┬──────────────┬──────────────┐
│  Server 1    │  Server 2    │  Server 3    │  Server N    │
│  (TCP)       │  (TLS)       │  (UDP)       │  (WebSocket) │
│              │              │              │              │
│  Policy:     │  Policy:     │  Policy:     │  Policy:     │
│  - Blue Team │  - Full      │  - Sensors   │  - Read Only │
│  - Auto-share│  - Bidir     │  - One-way   │  - Monitor   │
└──────────────┴──────────────┴──────────────┴──────────────┘
```

### Data Flow

```
1. Incoming CoT Event
   │
   ▼
2. Policy Check (Should Receive?)
   │
   ├─ No ──> Filtered (logged)
   │
   ▼ Yes
3. Deduplication (UID check)
   │
   ▼
4. Store in Federation Cache
   │
   ▼
5. Notify UI/Subscribers
   │
   ▼
6. Auto-Share Policy Check
   │
   ├─ Not enabled ──> Stop
   │
   ▼ Enabled
7. For Each Other Server:
   │
   ├─ Already shared? ──> Skip
   ├─ Connected? ──> No ──> Skip
   ├─ Should Send? (Policy) ──> No ──> Skip
   │
   ▼ Yes
8. Generate CoT XML
   │
   ▼
9. Send to Server
   │
   ▼
10. Mark as Shared
```

## Data Sharing Policies

### Data Types

Each server connection can be configured to selectively receive and send specific data types:

| Data Type  | CoT Type Prefix | Description                    |
|------------|-----------------|--------------------------------|
| `friendly` | `a-f-*`        | Friendly forces (blue team)    |
| `hostile`  | `a-h-*`        | Hostile forces (red team)      |
| `unknown`  | `a-u-*`        | Unknown/unidentified forces    |
| `neutral`  | `a-n-*`        | Neutral entities               |
| `sensor`   | `b-*`          | Sensor data and readings       |
| `geofence` | `u-d-f`        | Geofences and boundaries       |
| `route`    | `b-m-p-c`      | Route planning data            |
| `casevac`  | `b-r-f-h-c`    | CASEVAC/MEDEVAC requests       |
| `target`   | `u-d-c-c`      | Target designations            |
| `all`      | `*`            | All data types                 |

### Policy Configuration

Each server has a `DataSharingPolicy` with the following fields:

```typescript
interface DataSharingPolicy {
  // Which data types to receive from this server
  receiveTypes: DataType[];

  // Which data types to send to this server
  sendTypes: DataType[];

  // Automatically share received data to other servers
  autoShare: boolean;

  // Blue team mode: only share friendly data
  blueTeamOnly: boolean;

  // Bidirectional: both send and receive
  bidirectional: boolean;
}
```

### Default Policy

```typescript
{
  receiveTypes: ['all'],        // Receive all data types
  sendTypes: ['friendly'],      // Only send friendly data
  autoShare: true,             // Auto-share to other servers
  blueTeamOnly: true,          // Blue team mode enabled
  bidirectional: true          // Two-way communication
}
```

## Usage Examples

### Example 1: Blue Team Operations

**Scenario**: Connect to multiple friendly force networks, share only friendly positions.

```typescript
// Add primary tactical network
federation.addServer('primary', 'Primary TAK', {
  host: '192.168.1.10',
  port: 8087,
  protocol: 'TCP',
  useTls: true,
}, {
  receiveTypes: ['all'],
  sendTypes: ['friendly'],
  blueTeamOnly: true,
  autoShare: true,
  bidirectional: true,
});

// Add secondary network (read-only monitoring)
federation.addServer('secondary', 'Secondary Network', {
  host: '192.168.2.10',
  port: 8087,
  protocol: 'TCP',
  useTls: true,
}, {
  receiveTypes: ['all'],
  sendTypes: [],              // Don't send anything
  blueTeamOnly: false,
  autoShare: false,           // Don't share to others
  bidirectional: false,       // One-way receive
});

// Connect to both
await federation.connectAll();
```

**Result**:
- Friendly positions from Primary are shared to Secondary (if policy allows)
- All data from Secondary is received but not shared elsewhere
- Blue team mode ensures no hostile data leaks

### Example 2: Intelligence Fusion Center

**Scenario**: Aggregate intelligence from multiple sources, controlled distribution.

```typescript
// Sensor network (receive sensor data only)
federation.addServer('sensors', 'Sensor Network', {
  host: 'sensors.mil',
  port: 8089,
  protocol: 'TLS',
  useTls: true,
}, {
  receiveTypes: ['sensor', 'target'],
  sendTypes: [],              // Don't send back
  blueTeamOnly: false,
  autoShare: false,
  bidirectional: false,
});

// Operational network (full data sharing)
federation.addServer('operations', 'Operations Center', {
  host: 'ops.mil',
  port: 8089,
  protocol: 'TLS',
  useTls: true,
}, {
  receiveTypes: ['all'],
  sendTypes: ['all'],
  blueTeamOnly: false,
  autoShare: true,
  bidirectional: true,
});

await federation.connectAll();
```

**Result**:
- Sensor data flows from Sensor Network → Operations
- Operations shares data with other connected servers
- Fusion center aggregates all data sources

### Example 3: Coalition Operations

**Scenario**: Share only specific data with coalition partners.

```typescript
// US Forces
federation.addServer('us', 'US TAK Network', {
  host: 'us.tak.mil',
  port: 8089,
  protocol: 'TLS',
  useTls: true,
}, {
  receiveTypes: ['friendly', 'hostile', 'target'],
  sendTypes: ['friendly'],
  blueTeamOnly: true,
  autoShare: true,
  bidirectional: true,
});

// Coalition Partner
federation.addServer('coalition', 'Coalition Network', {
  host: 'coalition.tak.net',
  port: 8089,
  protocol: 'TLS',
  useTls: true,
}, {
  receiveTypes: ['friendly'],    // Only receive friendly
  sendTypes: ['friendly'],        // Only send friendly
  blueTeamOnly: true,
  autoShare: false,              // Don't auto-share their data
  bidirectional: true,
});

await federation.connectAll();
```

**Result**:
- US and Coalition share friendly positions with each other
- US hostile/target data is NOT shared with Coalition
- Coalition data stays isolated (not auto-shared to US)

## API Reference

### TypeScript/Valdi API

```typescript
import { multiServerFederation } from './services/MultiServerFederation';

// Add a server
multiServerFederation.addServer(
  id: string,
  name: string,
  config: ServerConfig,
  policy?: Partial<DataSharingPolicy>
);

// Remove a server
await multiServerFederation.removeServer(id: string);

// Update policy
multiServerFederation.updatePolicy(id: string, policy: Partial<DataSharingPolicy>);

// Connect/Disconnect
await multiServerFederation.connectServer(id: string);
await multiServerFederation.disconnectServer(id: string);
await multiServerFederation.connectAll();
await multiServerFederation.disconnectAll();

// Manual sending
await multiServerFederation.sendToServers(event: CoTEvent, serverIds: string[]);
await multiServerFederation.broadcast(event: CoTEvent);

// Subscribe to events
const unsubscribe = multiServerFederation.onFederatedEvent(
  (event: FederatedCoTEvent) => {
    console.log('Received from:', event.sourceServerName);
    console.log('Event:', event.event);
  }
);

// Get servers and events
const servers = multiServerFederation.getServers();
const events = multiServerFederation.getFederatedEvents();
const connectedCount = multiServerFederation.getConnectedCount();
```

### iOS/Swift API

```swift
let federation = MultiServerFederation()

// Add a server
federation.addServer(
    id: "primary",
    name: "Primary TAK",
    host: "192.168.1.10",
    port: 8087,
    protocolType: "TCP",
    useTLS: true,
    policy: .default
)

// Connect
federation.connectServer(id: "primary")
federation.connectAll()

// Update policy
var policy = DataSharingPolicy.default
policy.blueTeamOnly = true
federation.updatePolicy(id: "primary", policy: policy)

// Manual sending
federation.sendToServers(event: cotEvent, serverIds: ["primary", "secondary"])
federation.broadcast(event: cotEvent)

// Access federated data
let events = federation.federatedEvents
let servers = federation.servers
let connectedCount = federation.getConnectedCount()
```

## UI Components

### Federated Server Management Screen

Location: `/modules/omnitak_mobile/src/valdi/omnitak/screens/FederatedServerScreen.tsx`

**Features:**
- Visual server connection management
- LED status indicators per server
- Quick actions: Connect All, Disconnect All
- Per-server policy configuration
- Blue team mode toggle
- Auto-share toggle
- Data type filtering

**UI Elements:**
- Server cards with expandable details
- Connection status LEDs (Green=Connected, Orange=Connecting, Red=Error, Gray=Disconnected)
- Policy editor with toggle switches
- Data type chips showing active filters
- Action buttons for connect/disconnect/edit/remove

## Security Considerations

### Blue Team Mode

When `blueTeamOnly` is enabled:
- Only friendly (`a-f-*`) data is sent to the server
- Prevents accidental leakage of hostile or unknown force positions
- Recommended for coalition operations and untrusted networks

### Policy Enforcement

Policies are enforced at multiple levels:
1. **Receive Filter**: Before adding to federation cache
2. **Send Filter**: Before transmitting to each server
3. **Blue Team Check**: Additional filter on sends if enabled
4. **Auto-Share Check**: Only if policy allows

### Certificate Pinning

For TLS connections, support certificate pinning:
```typescript
const certId = await takService.importCertificate(certPem, keyPem, caPem);

config.certificateId = certId;
config.useTls = true;
```

## Performance Optimization

### Deduplication

Events are deduplicated by UID to prevent:
- Duplicate markers on the map
- Redundant data processing
- Network bandwidth waste

### Event Cache

- Uses `Map<string, FederatedCoTEvent>` for O(1) lookups
- Events tracked by UID
- Includes source server and share history

### Connection Pooling

- Each server maintains its own TAKService instance
- Independent connection health monitoring
- Automatic reconnection (if configured)

## Troubleshooting

### Problem: Events not being shared

**Check:**
1. Is `autoShare` enabled in policy?
2. Is the target server connected?
3. Does the data type match `sendTypes`?
4. Is `blueTeamOnly` blocking non-friendly data?
5. Check console logs for "Not sharing event to..." messages

### Problem: Duplicate markers

**This should not happen** due to deduplication, but if it does:
1. Check that UIDs are unique per entity
2. Verify deduplication logic is working
3. Clear event cache: `multiServerFederation.clearCache()`

### Problem: Connection failures

**Check:**
1. Network connectivity to server
2. Firewall rules for ports
3. TLS certificate validity (if using TLS)
4. Server protocol compatibility
5. Server logs for connection attempts

## Future Enhancements

1. **Priority Routing**: Route high-priority data through fastest servers
2. **Load Balancing**: Distribute sends across multiple servers
3. **Bandwidth Management**: Throttle data rates per connection
4. **Conflict Resolution**: Handle conflicting data from different sources
5. **Time Sync**: Synchronize event timestamps across servers
6. **Encryption**: End-to-end encryption for sensitive data
7. **Compression**: Compress CoT messages for bandwidth efficiency

## References

- [ATAK Server Documentation](https://tak.gov)
- [CoT Message Format](https://www.mitre.org/news/features/cursor-on-target)
- [TAK Protocol Specification](https://tak.gov/products/tak-protocol)

---

**Version**: 1.0.0
**Last Updated**: 2025-11-09
**Status**: Production Ready
