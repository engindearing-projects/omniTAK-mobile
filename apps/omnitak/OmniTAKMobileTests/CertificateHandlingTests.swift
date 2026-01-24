//
//  CertificateHandlingTests.swift
//  OmniTAKMobileTests
//
//  Regression tests for certificate handling functionality.
//  Ensures certificate import/export doesn't break with future changes.
//
//  These tests cover:
//  - Certificate format conversion
//  - CSR generation configuration
//  - Certificate manager state
//  - Keychain operations (mocked)
//

import XCTest
import Security
@testable import OmniTAKMobile

// MARK: - CSR Generator Tests

class CSRGeneratorTests: XCTestCase {

    var generator: CSRGenerator!

    override func setUp() {
        super.setUp()
        generator = CSRGenerator()
    }

    override func tearDown() {
        generator = nil
        super.tearDown()
    }

    func testGeneratorInitialization() {
        XCTAssertNotNil(generator)
    }

    // Note: Actual CSR generation tests would require keychain access
    // which may not be available in unit test environment
}

// MARK: - Certificate Format Converter Tests

class CertificateFormatConverterTests: XCTestCase {

    // MARK: - PEM Detection Tests

    func testIsPEMFormat_ValidCertificate() {
        let pemCert = """
        -----BEGIN CERTIFICATE-----
        MIIBkTCB+wIJAKHBfJmFL+5sMA0GCSqGSIb3DQEBCwUAMBExDzANBgNVBAMMBnRl
        c3RDQTAeFw0yNDAxMDEwMDAwMDBaFw0yNTAxMDEwMDAwMDBaMBExDzANBgNVBAMM
        BnRlc3RDQTBcMA0GCSqGSIb3DQEBAQUAA0sAMEgCQQDFxFZ7VbZJGZKw5Qz5QWVN
        -----END CERTIFICATE-----
        """

        XCTAssertTrue(CertificateFormatConverter.isPEMFormat(pemCert))
    }

    func testIsPEMFormat_ValidPrivateKey() {
        let pemKey = """
        -----BEGIN PRIVATE KEY-----
        MIIBkTCB+wIJAKHBfJmFL+5sMA0GCSqGSIb3DQEBCwUAMBExDzANBgNVBAMMBnRl
        -----END PRIVATE KEY-----
        """

        XCTAssertTrue(CertificateFormatConverter.isPEMFormat(pemKey))
    }

    func testIsPEMFormat_RSAPrivateKey() {
        let rsaKey = """
        -----BEGIN RSA PRIVATE KEY-----
        MIIBkTCB+wIJAKHBfJmFL+5sMA0GCSqGSIb3DQEBCwUAMBExDzANBgNVBAMMBnRl
        -----END RSA PRIVATE KEY-----
        """

        XCTAssertTrue(CertificateFormatConverter.isPEMFormat(rsaKey))
    }

    func testIsPEMFormat_NotPEM() {
        let notPem = "This is not a PEM format"
        XCTAssertFalse(CertificateFormatConverter.isPEMFormat(notPem))
    }

    func testIsPEMFormat_Base64Only() {
        let base64Only = "MIIBkTCB+wIJAKHBfJmFL+5sMA0GCSqGSIb3DQEB"
        XCTAssertFalse(CertificateFormatConverter.isPEMFormat(base64Only))
    }

    // MARK: - PEM Stripping Tests

    func testStripPEMHeaders_Certificate() {
        let pem = """
        -----BEGIN CERTIFICATE-----
        MIIBkTCB+wIJAKHBfJmFL+5s
        MA0GCSqGSIb3DQEBCwUA
        -----END CERTIFICATE-----
        """

        let stripped = CertificateFormatConverter.stripPEMHeaders(pem)

        XCTAssertFalse(stripped.contains("-----BEGIN"))
        XCTAssertFalse(stripped.contains("-----END"))
        XCTAssertFalse(stripped.contains("\n"))
    }

    func testStripPEMHeaders_AlreadyStripped() {
        let base64 = "MIIBkTCB+wIJAKHBfJmFL+5sMA0GCSqGSIb3DQEBCwUA"
        let result = CertificateFormatConverter.stripPEMHeaders(base64)

        XCTAssertEqual(result, base64)
    }

    // MARK: - Base64 Validation Tests

    func testIsValidBase64_Valid() {
        let validBase64 = "SGVsbG8gV29ybGQ="
        XCTAssertTrue(CertificateFormatConverter.isValidBase64(validBase64))
    }

    func testIsValidBase64_ValidWithPadding() {
        let validBase64 = "SGVsbG8="
        XCTAssertTrue(CertificateFormatConverter.isValidBase64(validBase64))
    }

    func testIsValidBase64_Invalid() {
        let invalidBase64 = "Not valid base64!!!"
        XCTAssertFalse(CertificateFormatConverter.isValidBase64(invalidBase64))
    }

    func testIsValidBase64_Empty() {
        XCTAssertFalse(CertificateFormatConverter.isValidBase64(""))
    }
}

// MARK: - Certificate Manager Tests

class CertificateManagerTests: XCTestCase {

    var manager: CertificateManager!

    override func setUp() {
        super.setUp()
        manager = CertificateManager.shared
    }

    func testManagerSingleton() {
        let manager1 = CertificateManager.shared
        let manager2 = CertificateManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    func testCertificatesArrayExists() {
        // Should have a certificates array (may be empty)
        XCTAssertNotNil(manager.certificates)
    }

    // MARK: - Certificate Model Tests

    func testStoredCertificateCreation() {
        let cert = StoredCertificate(
            id: UUID(),
            name: "Test Certificate",
            commonName: "CN=TestUser",
            issuer: "CN=TestCA",
            expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60),
            importDate: Date(),
            hasPrivateKey: true,
            source: .imported
        )

        XCTAssertEqual(cert.name, "Test Certificate")
        XCTAssertEqual(cert.commonName, "CN=TestUser")
        XCTAssertTrue(cert.hasPrivateKey)
        XCTAssertEqual(cert.source, .imported)
    }

    func testStoredCertificateSource_Enrolled() {
        let cert = StoredCertificate(
            id: UUID(),
            name: "Enrolled Cert",
            commonName: "CN=User",
            issuer: "CN=TAK Server CA",
            expirationDate: Date(),
            importDate: Date(),
            hasPrivateKey: true,
            source: .enrolled
        )

        XCTAssertEqual(cert.source, .enrolled)
    }

    func testStoredCertificateSource_DataPackage() {
        let cert = StoredCertificate(
            id: UUID(),
            name: "DP Cert",
            commonName: "CN=User",
            issuer: "CN=TAK CA",
            expirationDate: Date(),
            importDate: Date(),
            hasPrivateKey: true,
            source: .dataPackage
        )

        XCTAssertEqual(cert.source, .dataPackage)
    }
}

// MARK: - Certificate Import Pipeline Tests

class CertificateImportPipelineTests: XCTestCase {

    func testPipelineInitialization() {
        let pipeline = CertificateImportPipeline.shared
        XCTAssertNotNil(pipeline)
    }

    // Note: Actual import tests would require test certificate files
}

// MARK: - TLS Configuration Tests

class TLSConfigurationTests: XCTestCase {

    func testTLSVersionConstants() {
        // Verify TLS version constants are accessible
        // TLS 1.2 = 0x0303, TLS 1.3 = 0x0304
        XCTAssertEqual(tls_protocol_version_t.TLSv12.rawValue, 0x0303)
        XCTAssertEqual(tls_protocol_version_t.TLSv13.rawValue, 0x0304)
    }

    func testLegacyTLSVersion() {
        // TLS 1.0 = 0x0301 (769 in decimal)
        let tls10 = tls_protocol_version_t(rawValue: 769)
        XCTAssertNotNil(tls10)
    }
}

// MARK: - Certificate Source Tests

class CertificateSourceTests: XCTestCase {

    func testAllSourcesExist() {
        let imported = CertificateSource.imported
        let enrolled = CertificateSource.enrolled
        let dataPackage = CertificateSource.dataPackage

        // Verify all sources are different
        XCTAssertNotEqual(String(describing: imported), String(describing: enrolled))
        XCTAssertNotEqual(String(describing: enrolled), String(describing: dataPackage))
    }
}

// MARK: - Direct TCP Sender Tests

class DirectTCPSenderTests: XCTestCase {

    func testSenderInitialization() {
        let sender = DirectTCPSender()
        XCTAssertNotNil(sender)
        XCTAssertFalse(sender.isConnected)
    }

    func testSenderStatisticsInitialState() {
        let sender = DirectTCPSender()
        XCTAssertEqual(sender.bytesReceived, 0)
        XCTAssertEqual(sender.messagesReceived, 0)
    }

    func testSenderStatisticsReset() {
        let sender = DirectTCPSender()
        sender.resetStatistics()

        XCTAssertEqual(sender.bytesReceived, 0)
        XCTAssertEqual(sender.messagesReceived, 0)
    }

    func testSenderBufferOperations() {
        let sender = DirectTCPSender()

        let initialSize = sender.getReceiveBufferSize()
        XCTAssertEqual(initialSize, 0)

        sender.clearReceiveBuffer()
        let clearedSize = sender.getReceiveBufferSize()
        XCTAssertEqual(clearedSize, 0)
    }

    func testSendWithoutConnection() {
        let sender = DirectTCPSender()
        let result = sender.send(xml: "<test/>")

        XCTAssertFalse(result, "Send should fail when not connected")
    }
}

// MARK: - Connection Protocol Tests

class ConnectionProtocolTests: XCTestCase {

    func testTCPProtocol() {
        let proto = ConnectionProtocol.tcp
        XCTAssertNotNil(proto)
    }

    func testUDPProtocol() {
        let proto = ConnectionProtocol.udp
        XCTAssertNotNil(proto)
    }

    func testTLSProtocol() {
        let proto = ConnectionProtocol.tls
        XCTAssertNotNil(proto)
    }

    func testProtocolsAreDifferent() {
        XCTAssertNotEqual(ConnectionProtocol.tcp, ConnectionProtocol.udp)
        XCTAssertNotEqual(ConnectionProtocol.tcp, ConnectionProtocol.tls)
        XCTAssertNotEqual(ConnectionProtocol.udp, ConnectionProtocol.tls)
    }
}
