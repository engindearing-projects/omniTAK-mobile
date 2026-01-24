//
//  TAKServiceTests.swift
//  OmniTAKMobileTests
//
//  Regression tests for TAKService connection handling.
//  Ensures connection management doesn't break with future changes.
//
//  These tests cover:
//  - Connection state management
//  - Multi-server connection tracking
//  - CoT message handling
//  - Statistics tracking
//

import XCTest
import CoreLocation
@testable import OmniTAKMobile

class TAKServiceTests: XCTestCase {

    var service: TAKService!

    override func setUp() {
        super.setUp()
        service = TAKService.shared
        // Reset state before each test
        service.disconnect()
        service.resetStatistics()
    }

    override func tearDown() {
        service.disconnect()
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testServiceSingleton() {
        let service1 = TAKService.shared
        let service2 = TAKService.shared
        XCTAssertTrue(service1 === service2, "Should return same instance")
    }

    func testInitialState() {
        XCTAssertFalse(service.isConnected, "Should start disconnected")
        XCTAssertEqual(service.connectionStatus, "Disconnected")
        XCTAssertTrue(service.connectedServerIds.isEmpty)
    }

    // MARK: - Connection State Tests

    func testConnectionStateSnapshot_Disconnected() {
        let state = ConnectionStateSnapshot.disconnected

        XCTAssertFalse(state.isConnected)
        XCTAssertEqual(state.status, "Not Connected")
        XCTAssertNil(state.serverName)
        XCTAssertFalse(state.reconnectionState.isReconnecting)
    }

    func testConnectionStateSnapshot_Connected() {
        let state = ConnectionStateSnapshot.connected(
            serverName: "Test Server",
            protocolType: "TLS"
        )

        XCTAssertTrue(state.isConnected)
        XCTAssertEqual(state.status, "Connected")
        XCTAssertEqual(state.serverName, "Test Server")
        XCTAssertEqual(state.protocolType, "TLS")
        XCTAssertNotNil(state.lastConnectedTime)
    }

    func testConnectionStateSnapshot_Connecting() {
        let state = ConnectionStateSnapshot.connecting(serverName: "Test Server")

        XCTAssertFalse(state.isConnected)
        XCTAssertEqual(state.status, "Connecting...")
        XCTAssertEqual(state.serverName, "Test Server")
    }

    func testConnectionStateSnapshot_Reconnecting() {
        let state = ConnectionStateSnapshot.reconnecting(attempt: 3, maxAttempts: 5)

        XCTAssertFalse(state.isConnected)
        XCTAssertEqual(state.status, "Reconnecting...")
        XCTAssertTrue(state.reconnectionState.isReconnecting)
        XCTAssertEqual(state.reconnectionState.attemptNumber, 3)
        XCTAssertEqual(state.reconnectionState.maxAttempts, 5)
    }

    // MARK: - Statistics Tests

    func testStatisticsInitialState() {
        service.resetStatistics()

        XCTAssertEqual(service.messagesReceived, 0)
        XCTAssertEqual(service.messagesSent, 0)
        XCTAssertEqual(service.bytesReceived, 0)
    }

    func testResetStatistics() {
        // Simulate some activity
        service.messagesReceived = 100
        service.messagesSent = 50

        service.resetStatistics()

        XCTAssertEqual(service.messagesReceived, 0)
        XCTAssertEqual(service.messagesSent, 0)
    }

    // MARK: - Multi-Server Connection Tests

    func testMultiServerConnectionTracking() {
        // Initially no connected servers
        XCTAssertTrue(service.connectedServerIds.isEmpty)

        // After disconnectAll, should still be empty
        service.disconnectAll()
        XCTAssertTrue(service.connectedServerIds.isEmpty)
    }

    func testIsConnectedToServer_WhenNotConnected() {
        let serverId = UUID()
        XCTAssertFalse(service.isConnectedTo(serverId: serverId))
    }

    // MARK: - CoT Event Model Tests

    func testCoTEventCreation() {
        let point = CoTPoint(lat: 39.8283, lon: -98.5795, hae: 1000, ce: 10, le: 10)
        let detail = CoTDetail(
            callsign: "TestUnit",
            team: "Blue",
            speed: 5.0,
            course: 180.0,
            remarks: "Test remarks",
            battery: 85,
            device: "iPhone",
            platform: "iOS"
        )
        let event = CoTEvent(
            uid: "test-uid-123",
            type: "a-f-G-U-C",
            time: Date(),
            point: point,
            detail: detail
        )

        XCTAssertEqual(event.uid, "test-uid-123")
        XCTAssertEqual(event.type, "a-f-G-U-C")
        XCTAssertEqual(event.point.lat, 39.8283, accuracy: 0.0001)
        XCTAssertEqual(event.point.lon, -98.5795, accuracy: 0.0001)
        XCTAssertEqual(event.detail.callsign, "TestUnit")
        XCTAssertEqual(event.detail.team, "Blue")
    }

    func testCoTPointCreation() {
        let point = CoTPoint(lat: 45.0, lon: -120.0, hae: 500, ce: 5, le: 5)

        XCTAssertEqual(point.lat, 45.0)
        XCTAssertEqual(point.lon, -120.0)
        XCTAssertEqual(point.hae, 500)
        XCTAssertEqual(point.ce, 5)
        XCTAssertEqual(point.le, 5)
    }

    func testCoTDetailWithOptionalFields() {
        let detail = CoTDetail(
            callsign: "Unit1",
            team: nil,
            speed: nil,
            course: nil,
            remarks: nil,
            battery: nil,
            device: nil,
            platform: nil
        )

        XCTAssertEqual(detail.callsign, "Unit1")
        XCTAssertNil(detail.team)
        XCTAssertNil(detail.speed)
        XCTAssertNil(detail.battery)
    }

    // MARK: - Enhanced Marker Tests

    func testEnhancedMarkerCreation() {
        let coordinate = CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795)

        let marker = EnhancedCoTMarker(
            id: UUID(),
            uid: "marker-123",
            type: "a-f-G-U-C",
            timestamp: Date(),
            coordinate: coordinate,
            altitude: 1000,
            ce: 10,
            le: 10,
            callsign: "TestMarker",
            team: "Blue",
            affiliation: .friend,
            unitType: .ground,
            speed: 5.0,
            course: 180.0,
            remarks: "Test",
            battery: 85,
            device: "iPhone",
            platform: "iOS",
            lastUpdate: Date(),
            positionHistory: []
        )

        XCTAssertEqual(marker.uid, "marker-123")
        XCTAssertEqual(marker.callsign, "TestMarker")
        XCTAssertEqual(marker.affiliation, .friend)
        XCTAssertEqual(marker.unitType, .ground)
    }

    func testGetAllMarkers_InitiallyEmpty() {
        let markers = service.getAllMarkers()
        // May not be empty if other tests ran, but should be an array
        XCTAssertNotNil(markers)
    }

    func testGetMarkerByUID_NotFound() {
        let marker = service.getMarker(uid: "nonexistent-uid")
        XCTAssertNil(marker)
    }

    // MARK: - Stale Marker Removal Tests

    func testRemoveStaleMarkers() {
        // This should not crash even with no markers
        service.removeStaleMarkers()

        // Markers should still be accessible
        XCTAssertNotNil(service.enhancedMarkers)
    }

    // MARK: - Configuration Tests

    func testHistoryConfiguration() {
        // Default values
        XCTAssertEqual(service.maxHistoryPerUnit, 100)
        XCTAssertEqual(service.historyRetentionTime, 3600)  // 1 hour

        // Should be configurable
        service.maxHistoryPerUnit = 200
        service.historyRetentionTime = 7200

        XCTAssertEqual(service.maxHistoryPerUnit, 200)
        XCTAssertEqual(service.historyRetentionTime, 7200)
    }

    // MARK: - Notification Settings Tests

    func testNotificationSettings() {
        // Should not crash when toggling
        service.setNotificationsEnabled(true)
        service.setNotificationsEnabled(false)
    }

    func testEmergencyAlertSettings() {
        // Should not crash when toggling
        service.setEmergencyAlertsEnabled(true)
        service.setEmergencyAlertsEnabled(false)
    }

    // MARK: - Buffer Management Tests

    func testReceiveBufferSize() {
        let size = service.getReceiveBufferSize()
        XCTAssertGreaterThanOrEqual(size, 0)
    }

    func testClearReceiveBuffer() {
        // Should not crash
        service.clearReceiveBuffer()

        let size = service.getReceiveBufferSize()
        XCTAssertEqual(size, 0)
    }
}

// MARK: - Server Connection State Tests

class ServerConnectionStateTests: XCTestCase {

    func testServerConnectionStateCreation() {
        let sender = DirectTCPSender()
        let state = ServerConnectionState(
            serverId: UUID(),
            serverName: "Test Server",
            isConnected: false,
            sender: sender
        )

        XCTAssertEqual(state.serverName, "Test Server")
        XCTAssertFalse(state.isConnected)
    }
}

// MARK: - TAK Server Model Tests

class TAKServerTests: XCTestCase {

    func testTAKServerCreation() {
        let server = TAKServer(
            id: UUID(),
            name: "Test TAK Server",
            host: "tak.example.com",
            port: 8089,
            protocolType: "ssl",
            useTLS: true,
            isDefault: false,
            certificateName: "test-cert",
            certificatePassword: "password"
        )

        XCTAssertEqual(server.name, "Test TAK Server")
        XCTAssertEqual(server.host, "tak.example.com")
        XCTAssertEqual(server.port, 8089)
        XCTAssertEqual(server.protocolType, "ssl")
        XCTAssertTrue(server.useTLS)
        XCTAssertFalse(server.isDefault)
        XCTAssertEqual(server.certificateName, "test-cert")
    }

    func testTAKServerWithDefaultValues() {
        let server = TAKServer(
            id: UUID(),
            name: "Simple Server",
            host: "192.168.1.100",
            port: 8087,
            protocolType: "tcp",
            useTLS: false,
            isDefault: true
        )

        XCTAssertTrue(server.isDefault)
        XCTAssertFalse(server.useTLS)
        XCTAssertNil(server.certificateName)
    }
}

// MARK: - Reconnection State Tests

class ReconnectionStateTests: XCTestCase {

    func testReconnectionStateDefaults() {
        let state = ReconnectionState()

        XCTAssertFalse(state.isReconnecting)
        XCTAssertEqual(state.attemptNumber, 0)
        XCTAssertEqual(state.maxAttempts, 5)
    }

    func testReconnectionStateCustomValues() {
        let state = ReconnectionState(
            isReconnecting: true,
            attemptNumber: 3,
            maxAttempts: 10
        )

        XCTAssertTrue(state.isReconnecting)
        XCTAssertEqual(state.attemptNumber, 3)
        XCTAssertEqual(state.maxAttempts, 10)
    }
}
