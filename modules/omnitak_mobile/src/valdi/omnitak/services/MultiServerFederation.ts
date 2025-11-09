/**
 * Multi-Server Federation Manager
 *
 * Manages multiple simultaneous TAK server connections with:
 * - Federated data collection from all servers
 * - Selective data sharing to blue team (friendly forces)
 * - Deduplication of CoT events across servers
 * - Per-server data sharing policies
 */

import { takService, ServerConfig, ConnectionInfo } from './TakService';
import { parseCotXml, CoTEvent } from './CotParser';

/**
 * Data types that can be selectively shared
 */
export type DataType =
  | 'friendly'      // a-f-* - Friendly forces
  | 'hostile'       // a-h-* - Hostile forces
  | 'unknown'       // a-u-* - Unknown forces
  | 'neutral'       // a-n-* - Neutral forces
  | 'sensor'        // b-* - Sensor data
  | 'geofence'      // u-d-f - Geofence/boundaries
  | 'route'         // b-m-p-c - Route planning
  | 'casevac'       // b-r-f-h-c - CASEVAC requests
  | 'target'        // u-d-c-c - Target designation
  | 'all';          // All data types

/**
 * @ExportModel({
 *   ios: 'DataSharingPolicy',
 *   android: 'com.engindearing.omnitak.DataSharingPolicy'
 * })
 */
export interface DataSharingPolicy {
  // Which data types to receive from this server
  receiveTypes: DataType[];

  // Which data types to send to this server
  sendTypes: DataType[];

  // Auto-share mode: automatically share received data to other servers
  autoShare: boolean;

  // Blue team mode: only share friendly data
  blueTeamOnly: boolean;

  // Bidirectional: both send and receive (typical)
  bidirectional: boolean;
}

/**
 * @ExportModel({
 *   ios: 'FederatedServer',
 *   android: 'com.engindearing.omnitak.FederatedServer'
 * })
 */
export interface FederatedServer {
  id: string;
  name: string;
  connectionId: number | null;
  config: ServerConfig;
  policy: DataSharingPolicy;
  status: 'connected' | 'connecting' | 'disconnected' | 'error';
  lastError?: string;
}

/**
 * @ExportModel({
 *   ios: 'FederatedCoTEvent',
 *   android: 'com.engindearing.omnitak.FederatedCoTEvent'
 * })
 */
export interface FederatedCoTEvent {
  event: CoTEvent;
  sourceServerId: string;
  sourceServerName: string;
  receivedAt: Date;
  sharedTo: string[]; // Server IDs this event has been shared to
}

/**
 * Multi-Server Federation Manager
 */
export class MultiServerFederation {
  private servers: Map<string, FederatedServer> = new Map();
  private eventCache: Map<string, FederatedCoTEvent> = new Map(); // UID -> Event
  private eventCallbacks: Set<(event: FederatedCoTEvent) => void> = new Set();
  private statusCallbacks: Set<() => void> = new Set();
  private cotUnsubscribers: Map<number, () => void> = new Map();

  constructor() {
    console.log('MultiServerFederation initialized');
  }

  /**
   * Add a server to the federation
   */
  addServer(
    id: string,
    name: string,
    config: ServerConfig,
    policy?: Partial<DataSharingPolicy>
  ): void {
    const defaultPolicy: DataSharingPolicy = {
      receiveTypes: ['all'],
      sendTypes: ['friendly'], // Default: only send friendly data
      autoShare: true,
      blueTeamOnly: true, // Default: blue team mode on
      bidirectional: true,
    };

    const server: FederatedServer = {
      id,
      name,
      connectionId: null,
      config,
      policy: { ...defaultPolicy, ...policy },
      status: 'disconnected',
    };

    this.servers.set(id, server);
    console.log(`Added server to federation: ${name} (${id})`);
    this.notifyStatusChange();
  }

  /**
   * Remove a server from the federation
   */
  async removeServer(id: string): Promise<void> {
    const server = this.servers.get(id);
    if (server && server.connectionId !== null) {
      await this.disconnectServer(id);
    }
    this.servers.delete(id);
    console.log(`Removed server from federation: ${id}`);
    this.notifyStatusChange();
  }

  /**
   * Update server sharing policy
   */
  updatePolicy(id: string, policy: Partial<DataSharingPolicy>): void {
    const server = this.servers.get(id);
    if (server) {
      server.policy = { ...server.policy, ...policy };
      console.log(`Updated policy for server: ${id}`, policy);
      this.notifyStatusChange();
    }
  }

  /**
   * Connect to a server
   */
  async connectServer(id: string): Promise<boolean> {
    const server = this.servers.get(id);
    if (!server) {
      console.error(`Server not found: ${id}`);
      return false;
    }

    if (server.connectionId !== null) {
      console.warn(`Server already connected: ${id}`);
      return true;
    }

    server.status = 'connecting';
    this.notifyStatusChange();

    try {
      const connectionId = await takService.connect(server.config);
      if (connectionId === null) {
        server.status = 'error';
        server.lastError = 'Failed to connect';
        this.notifyStatusChange();
        return false;
      }

      server.connectionId = connectionId;
      server.status = 'connected';

      // Subscribe to CoT messages from this server
      const unsubscribe = takService.onCotReceived(connectionId, (xml: string) => {
        this.handleIncomingCot(id, xml);
      });
      this.cotUnsubscribers.set(connectionId, unsubscribe);

      console.log(`Connected to server: ${server.name} (${id})`);
      this.notifyStatusChange();
      return true;
    } catch (error) {
      server.status = 'error';
      server.lastError = String(error);
      console.error(`Error connecting to server ${id}:`, error);
      this.notifyStatusChange();
      return false;
    }
  }

  /**
   * Disconnect from a server
   */
  async disconnectServer(id: string): Promise<void> {
    const server = this.servers.get(id);
    if (!server || server.connectionId === null) {
      return;
    }

    const connectionId = server.connectionId;

    // Unsubscribe from CoT messages
    const unsubscribe = this.cotUnsubscribers.get(connectionId);
    if (unsubscribe) {
      unsubscribe();
      this.cotUnsubscribers.delete(connectionId);
    }

    await takService.disconnect(connectionId);
    server.connectionId = null;
    server.status = 'disconnected';

    console.log(`Disconnected from server: ${server.name} (${id})`);
    this.notifyStatusChange();
  }

  /**
   * Connect to all servers in the federation
   */
  async connectAll(): Promise<void> {
    const promises = Array.from(this.servers.keys()).map((id) =>
      this.connectServer(id)
    );
    await Promise.all(promises);
  }

  /**
   * Disconnect from all servers
   */
  async disconnectAll(): Promise<void> {
    const promises = Array.from(this.servers.keys()).map((id) =>
      this.disconnectServer(id)
    );
    await Promise.all(promises);
  }

  /**
   * Handle incoming CoT message from a server
   */
  private handleIncomingCot(serverId: string, xml: string): void {
    const server = this.servers.get(serverId);
    if (!server) return;

    const event = parseCotXml(xml);
    if (!event) return;

    // Check if this data type should be received from this server
    if (!this.shouldReceive(server, event)) {
      console.log(`Filtered incoming event from ${server.name}: ${event.type}`);
      return;
    }

    // Create or update federated event
    const existingEvent = this.eventCache.get(event.uid);
    const federatedEvent: FederatedCoTEvent = existingEvent || {
      event,
      sourceServerId: serverId,
      sourceServerName: server.name,
      receivedAt: new Date(),
      sharedTo: [],
    };

    // Update event data if newer
    federatedEvent.event = event;

    this.eventCache.set(event.uid, federatedEvent);

    // Notify subscribers
    this.eventCallbacks.forEach((callback) => {
      try {
        callback(federatedEvent);
      } catch (error) {
        console.error('Error in event callback:', error);
      }
    });

    // Auto-share to other servers if policy allows
    if (server.policy.autoShare) {
      this.shareEventToOtherServers(federatedEvent, serverId);
    }
  }

  /**
   * Check if data should be received from this server based on policy
   */
  private shouldReceive(server: FederatedServer, event: CoTEvent): boolean {
    const { receiveTypes } = server.policy;

    if (receiveTypes.includes('all')) {
      return true;
    }

    const dataType = this.getDataType(event.type);
    return receiveTypes.includes(dataType);
  }

  /**
   * Check if data should be sent to this server based on policy
   */
  private shouldSend(server: FederatedServer, event: CoTEvent): boolean {
    const { sendTypes, blueTeamOnly } = server.policy;

    // Blue team only mode: only send friendly data
    if (blueTeamOnly && !event.type.includes('a-f-')) {
      return false;
    }

    if (sendTypes.includes('all')) {
      return true;
    }

    const dataType = this.getDataType(event.type);
    return sendTypes.includes(dataType);
  }

  /**
   * Share event to other servers based on their policies
   */
  private async shareEventToOtherServers(
    federatedEvent: FederatedCoTEvent,
    sourceServerId: string
  ): Promise<void> {
    const { event, sharedTo } = federatedEvent;

    for (const [id, server] of this.servers) {
      // Skip source server and already shared servers
      if (id === sourceServerId || sharedTo.includes(id)) {
        continue;
      }

      // Skip if not connected
      if (server.status !== 'connected' || server.connectionId === null) {
        continue;
      }

      // Check if this server should receive this data
      if (!this.shouldSend(server, event)) {
        console.log(`Not sharing event to ${server.name}: policy restriction`);
        continue;
      }

      // Generate CoT XML and send
      const cotXml = this.generateCotXml(event);
      const success = await takService.sendCot(server.connectionId, cotXml);

      if (success) {
        sharedTo.push(id);
        console.log(`Shared event ${event.uid} to ${server.name}`);
      }
    }
  }

  /**
   * Manually send CoT event to specific servers
   */
  async sendToServers(event: CoTEvent, serverIds: string[]): Promise<void> {
    const cotXml = this.generateCotXml(event);

    for (const id of serverIds) {
      const server = this.servers.get(id);
      if (!server || server.connectionId === null) {
        console.warn(`Cannot send to server ${id}: not connected`);
        continue;
      }

      if (!this.shouldSend(server, event)) {
        console.warn(`Cannot send to server ${id}: policy restriction`);
        continue;
      }

      await takService.sendCot(server.connectionId, cotXml);
    }
  }

  /**
   * Broadcast CoT event to all connected servers (respecting policies)
   */
  async broadcast(event: CoTEvent): Promise<void> {
    const serverIds = Array.from(this.servers.keys());
    await this.sendToServers(event, serverIds);
  }

  /**
   * Get federated data type from CoT type string
   */
  private getDataType(cotType: string): DataType {
    if (cotType.startsWith('a-f-')) return 'friendly';
    if (cotType.startsWith('a-h-')) return 'hostile';
    if (cotType.startsWith('a-u-')) return 'unknown';
    if (cotType.startsWith('a-n-')) return 'neutral';
    if (cotType.startsWith('b-m-p-c')) return 'route';
    if (cotType.startsWith('b-r-f-h-c')) return 'casevac';
    if (cotType.startsWith('u-d-f')) return 'geofence';
    if (cotType.startsWith('u-d-c-c')) return 'target';
    if (cotType.startsWith('b-')) return 'sensor';
    return 'unknown';
  }

  /**
   * Generate CoT XML from event
   */
  private generateCotXml(event: CoTEvent): string {
    // Generate CoT XML - simplified version
    const callsign = event.detail.callsign || event.uid;
    const team = event.detail.team || 'Cyan';

    return `<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="${event.uid}" type="${event.type}" time="${event.time}" start="${event.start}" stale="${event.stale}" how="h-e">
  <point lat="${event.point.lat}" lon="${event.point.lon}" hae="${event.point.hae}" ce="9999999" le="9999999"/>
  <detail>
    <contact callsign="${callsign}"/>
    <__group name="${team}" role="Team Member"/>
  </detail>
</event>`;
  }

  /**
   * Subscribe to federated events
   */
  onFederatedEvent(callback: (event: FederatedCoTEvent) => void): () => void {
    this.eventCallbacks.add(callback);
    return () => this.eventCallbacks.delete(callback);
  }

  /**
   * Subscribe to status changes
   */
  onStatusChange(callback: () => void): () => void {
    this.statusCallbacks.add(callback);
    return () => this.statusCallbacks.delete(callback);
  }

  /**
   * Get all federated events
   */
  getFederatedEvents(): FederatedCoTEvent[] {
    return Array.from(this.eventCache.values());
  }

  /**
   * Get all servers
   */
  getServers(): FederatedServer[] {
    return Array.from(this.servers.values());
  }

  /**
   * Get server by ID
   */
  getServer(id: string): FederatedServer | undefined {
    return this.servers.get(id);
  }

  /**
   * Get connected servers count
   */
  getConnectedCount(): number {
    return Array.from(this.servers.values()).filter(
      (s) => s.status === 'connected'
    ).length;
  }

  /**
   * Clear event cache
   */
  clearCache(): void {
    this.eventCache.clear();
    console.log('Event cache cleared');
  }

  /**
   * Notify status change subscribers
   */
  private notifyStatusChange(): void {
    this.statusCallbacks.forEach((callback) => {
      try {
        callback();
      } catch (error) {
        console.error('Error in status callback:', error);
      }
    });
  }
}

// Singleton instance
export const multiServerFederation = new MultiServerFederation();
