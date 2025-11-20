/**
 * MeshtasticService.ts
 *
 * High-level TypeScript service for Meshtastic mesh network connectivity
 * Provides a reactive, type-safe interface for web and React Native apps
 */

import { EventEmitter } from 'events';

// MARK: - Type Definitions

export enum MeshtasticConnectionType {
    SERIAL = 0,
    BLUETOOTH = 1,
    TCP = 2,
}

export interface MeshtasticConfig {
    connectionType: MeshtasticConnectionType;
    devicePath: string;        // Serial path, BT address, or hostname
    port?: number;              // For TCP connections
    nodeId?: number;            // Target node (undefined = broadcast)
    deviceName?: string;        // Display name
}

export interface MeshtasticDevice {
    id: string;
    name: string;
    connectionType: MeshtasticConnectionType;
    devicePath: string;
    nodeId?: number;
    signalStrength?: number;    // RSSI in dBm
    batteryLevel?: number;      // 0-100%
    isConnected: boolean;
    lastSeen?: Date;
    snr?: number;               // Signal-to-Noise Ratio
    hopCount?: number;
    channelUtilization?: number;
    airtime?: number;
}

export interface MeshNode {
    id: number;                 // Node ID
    shortName: string;
    longName: string;
    position?: MeshPosition;
    lastHeard?: Date;
    snr?: number;
    hopDistance?: number;
    batteryLevel?: number;
}

export interface MeshPosition {
    latitude: number;
    longitude: number;
    altitude?: number;
    time?: Date;
}

export interface MeshNetworkStats {
    connectedNodes: number;
    totalNodes: number;
    averageHops: number;
    packetSuccessRate: number;
    networkUtilization: number;
    lastUpdate: Date;
}

export enum SignalQuality {
    EXCELLENT = 'excellent',
    GOOD = 'good',
    FAIR = 'fair',
    POOR = 'poor',
    NONE = 'none',
}

export interface SignalStrengthReading {
    timestamp: Date;
    rssi: number;
    snr: number;
}

export enum NetworkHealth {
    DISCONNECTED = 'disconnected',
    POOR = 'poor',
    FAIR = 'fair',
    GOOD = 'good',
    EXCELLENT = 'excellent',
}

// MARK: - Meshtastic Service

export class MeshtasticService extends EventEmitter {
    private native: any; // OmniTAKNativeModule
    private connectedDevice: MeshtasticDevice | null = null;
    private connectionId: number = 0;
    private devices: MeshtasticDevice[] = [];
    private meshNodes: MeshNode[] = [];
    private networkStats: MeshNetworkStats = {
        connectedNodes: 0,
        totalNodes: 0,
        averageHops: 0,
        packetSuccessRate: 0,
        networkUtilization: 0,
        lastUpdate: new Date(),
    };
    private signalHistory: SignalStrengthReading[] = [];
    private isScanning: boolean = false;

    constructor(nativeModule?: any) {
        super();
        this.native = nativeModule;
    }

    // MARK: - Device Discovery

    /**
     * Scan for available Meshtastic devices
     */
    async scanForDevices(): Promise<void> {
        this.isScanning = true;
        this.emit('scanningChanged', this.isScanning);

        try {
            // Discover Serial/USB devices
            await this.discoverSerialDevices();

            // Discover Bluetooth devices
            await this.discoverBluetoothDevices();

            // Discover TCP-enabled devices
            await this.discoverTCPDevices();

            this.emit('devicesUpdated', this.devices);
        } finally {
            setTimeout(() => {
                this.isScanning = false;
                this.emit('scanningChanged', this.isScanning);
            }, 10000);
        }
    }

    private async discoverSerialDevices(): Promise<void> {
        // Platform-specific serial discovery
        if (typeof navigator !== 'undefined' && 'serial' in navigator) {
            // Web Serial API
            try {
                const ports = await (navigator as any).serial.getPorts();
                ports.forEach((port: any, index: number) => {
                    const device: MeshtasticDevice = {
                        id: `serial-${index}`,
                        name: `Meshtastic USB ${index + 1}`,
                        connectionType: MeshtasticConnectionType.SERIAL,
                        devicePath: `/dev/ttyUSB${index}`,
                        isConnected: false,
                        lastSeen: new Date(),
                    };

                    if (!this.devices.find(d => d.id === device.id)) {
                        this.devices.push(device);
                    }
                });
            } catch (error) {
                console.error('Serial discovery error:', error);
            }
        }
    }

    private async discoverBluetoothDevices(): Promise<void> {
        // Add placeholder for Bluetooth discovery
        const btDevice: MeshtasticDevice = {
            id: 'bluetooth-manual',
            name: 'Bluetooth Meshtastic (Manual)',
            connectionType: MeshtasticConnectionType.BLUETOOTH,
            devicePath: '00:00:00:00:00:00',
            isConnected: false,
        };

        if (!this.devices.find(d => d.id === btDevice.id)) {
            this.devices.push(btDevice);
        }
    }

    private async discoverTCPDevices(): Promise<void> {
        // Add common TCP device entry
        const tcpDevice: MeshtasticDevice = {
            id: 'tcp-local',
            name: 'TCP Meshtastic (192.168.x.x)',
            connectionType: MeshtasticConnectionType.TCP,
            devicePath: '192.168.1.100',
            isConnected: false,
        };

        if (!this.devices.find(d => d.id === tcpDevice.id)) {
            this.devices.push(tcpDevice);
        }
    }

    // MARK: - Connection Management

    /**
     * Connect to a Meshtastic device
     */
    async connect(device: MeshtasticDevice): Promise<boolean> {
        if (!this.native) {
            throw new Error('Native module not available');
        }

        try {
            const config: MeshtasticConfig = {
                connectionType: device.connectionType,
                devicePath: device.devicePath,
                port: device.connectionType === MeshtasticConnectionType.TCP ? 4403 : undefined,
                nodeId: device.nodeId,
                deviceName: device.name,
            };

            this.connectionId = await this.native.connectMeshtastic(
                config.connectionType,
                config.devicePath,
                config.port || 0,
                config.nodeId || 0,
                config.deviceName || ''
            );

            if (this.connectionId > 0) {
                device.isConnected = true;
                device.lastSeen = new Date();
                this.connectedDevice = device;

                // Update device in list
                const index = this.devices.findIndex(d => d.id === device.id);
                if (index >= 0) {
                    this.devices[index] = device;
                }

                // Start monitoring
                this.startSignalMonitoring();
                this.startNodeDiscovery();

                this.emit('connected', device);
                this.emit('devicesUpdated', this.devices);

                console.log('✅ Connected to Meshtastic:', device.name);
                return true;
            }

            console.error('❌ Failed to connect to Meshtastic device');
            return false;
        } catch (error) {
            console.error('Connection error:', error);
            this.emit('error', error);
            return false;
        }
    }

    /**
     * Disconnect from current device
     */
    async disconnect(): Promise<void> {
        if (!this.native || this.connectionId === 0) {
            return;
        }

        try {
            await this.native.disconnect(this.connectionId);

            if (this.connectedDevice) {
                this.connectedDevice.isConnected = false;
                const index = this.devices.findIndex(d => d.id === this.connectedDevice!.id);
                if (index >= 0) {
                    this.devices[index] = this.connectedDevice;
                }
            }

            this.connectedDevice = null;
            this.connectionId = 0;

            this.stopSignalMonitoring();
            this.stopNodeDiscovery();

            this.emit('disconnected');
            this.emit('devicesUpdated', this.devices);

            console.log('⚡ Disconnected from Meshtastic');
        } catch (error) {
            console.error('Disconnect error:', error);
            this.emit('error', error);
        }
    }

    // MARK: - Signal Monitoring

    private signalMonitorInterval?: NodeJS.Timeout;

    private startSignalMonitoring(): void {
        this.signalMonitorInterval = setInterval(() => {
            this.updateSignalStrength();
        }, 2000);
    }

    private stopSignalMonitoring(): void {
        if (this.signalMonitorInterval) {
            clearInterval(this.signalMonitorInterval);
            this.signalMonitorInterval = undefined;
        }
    }

    private updateSignalStrength(): void {
        if (!this.connectedDevice) return;

        // Simulate signal readings (real implementation would query device)
        const rssi = Math.floor(Math.random() * 60) - 100;
        const snr = Math.random() * 30 - 10;

        this.connectedDevice.signalStrength = rssi;
        this.connectedDevice.snr = snr;

        const reading: SignalStrengthReading = {
            timestamp: new Date(),
            rssi,
            snr,
        };

        this.signalHistory.push(reading);

        // Keep only last 100 readings
        if (this.signalHistory.length > 100) {
            this.signalHistory.shift();
        }

        this.emit('signalUpdated', reading);
        this.emit('devicesUpdated', this.devices);
    }

    // MARK: - Node Discovery

    private nodeDiscoveryInterval?: NodeJS.Timeout;

    private startNodeDiscovery(): void {
        this.nodeDiscoveryInterval = setInterval(() => {
            this.discoverMeshNodes();
        }, 5000);

        // Immediate first discovery
        this.discoverMeshNodes();
    }

    private stopNodeDiscovery(): void {
        if (this.nodeDiscoveryInterval) {
            clearInterval(this.nodeDiscoveryInterval);
            this.nodeDiscoveryInterval = undefined;
        }
    }

    private discoverMeshNodes(): void {
        // Simulate mesh node discovery
        const sampleNodes: MeshNode[] = [
            {
                id: 0x12345678,
                shortName: 'MESH-A',
                longName: 'Alpha Node',
                position: { latitude: 37.7749, longitude: -122.4194 },
                lastHeard: new Date(),
                snr: 12.5,
                hopDistance: 1,
                batteryLevel: 85,
            },
            {
                id: 0x23456789,
                shortName: 'MESH-B',
                longName: 'Bravo Node',
                position: { latitude: 37.7849, longitude: -122.4094 },
                lastHeard: new Date(Date.now() - 30000),
                snr: 8.2,
                hopDistance: 2,
                batteryLevel: 60,
            },
            {
                id: 0x34567890,
                shortName: 'MESH-C',
                longName: 'Charlie Node',
                position: { latitude: 37.7649, longitude: -122.4294 },
                lastHeard: new Date(Date.now() - 60000),
                snr: 5.1,
                hopDistance: 3,
                batteryLevel: 40,
            },
        ];

        if (this.connectedDevice) {
            this.meshNodes = sampleNodes;

            // Update network stats
            this.networkStats = {
                connectedNodes: sampleNodes.filter(n => (n.hopDistance || 999) <= 3).length,
                totalNodes: sampleNodes.length,
                averageHops: sampleNodes.reduce((sum, n) => sum + (n.hopDistance || 0), 0) / Math.max(sampleNodes.length, 1),
                packetSuccessRate: 0.92,
                networkUtilization: 0.35,
                lastUpdate: new Date(),
            };

            this.emit('nodesUpdated', this.meshNodes);
            this.emit('statsUpdated', this.networkStats);
        }
    }

    // MARK: - Messaging

    /**
     * Send a CoT message through the mesh
     */
    async sendCoT(cotXML: string): Promise<boolean> {
        if (!this.native || this.connectionId === 0) {
            throw new Error('Not connected to Meshtastic device');
        }

        try {
            const result = await this.native.sendCot(this.connectionId, cotXML);

            if (result === 0) {
                console.log('📡 Sent CoT through mesh network');
                this.emit('cotSent', cotXML);
                return true;
            }

            console.error('❌ Failed to send CoT message');
            return false;
        } catch (error) {
            console.error('Send error:', error);
            this.emit('error', error);
            return false;
        }
    }

    // MARK: - Getters

    get isConnected(): boolean {
        return this.connectedDevice?.isConnected || false;
    }

    get signalQuality(): SignalQuality {
        return this.getSignalQuality(this.connectedDevice?.signalStrength);
    }

    get networkHealth(): NetworkHealth {
        if (!this.isConnected) {
            return NetworkHealth.DISCONNECTED;
        }

        const connectedRatio = this.networkStats.connectedNodes / Math.max(this.networkStats.totalNodes, 1);

        if (connectedRatio > 0.8 && this.networkStats.packetSuccessRate > 0.9) {
            return NetworkHealth.EXCELLENT;
        } else if (connectedRatio > 0.6 && this.networkStats.packetSuccessRate > 0.7) {
            return NetworkHealth.GOOD;
        } else if (connectedRatio > 0.4) {
            return NetworkHealth.FAIR;
        } else {
            return NetworkHealth.POOR;
        }
    }

    getDevices(): MeshtasticDevice[] {
        return this.devices;
    }

    getMeshNodes(): MeshNode[] {
        return this.meshNodes;
    }

    getNetworkStats(): MeshNetworkStats {
        return this.networkStats;
    }

    getSignalHistory(): SignalStrengthReading[] {
        return this.signalHistory;
    }

    getConnectedDevice(): MeshtasticDevice | null {
        return this.connectedDevice;
    }

    // MARK: - Helpers

    private getSignalQuality(rssi?: number): SignalQuality {
        if (!rssi) return SignalQuality.NONE;

        if (rssi >= -50) return SignalQuality.EXCELLENT;
        if (rssi >= -70) return SignalQuality.GOOD;
        if (rssi >= -90) return SignalQuality.FAIR;
        if (rssi < -90) return SignalQuality.POOR;

        return SignalQuality.NONE;
    }

    getSignalQualityColor(quality: SignalQuality): string {
        switch (quality) {
            case SignalQuality.EXCELLENT: return '#10b981';
            case SignalQuality.GOOD: return '#3b82f6';
            case SignalQuality.FAIR: return '#f59e0b';
            case SignalQuality.POOR: return '#ef4444';
            case SignalQuality.NONE: return '#6b7280';
        }
    }

    getNetworkHealthColor(health: NetworkHealth): string {
        switch (health) {
            case NetworkHealth.EXCELLENT: return '#10b981';
            case NetworkHealth.GOOD: return '#3b82f6';
            case NetworkHealth.FAIR: return '#f59e0b';
            case NetworkHealth.POOR: return '#ef4444';
            case NetworkHealth.DISCONNECTED: return '#6b7280';
        }
    }
}
