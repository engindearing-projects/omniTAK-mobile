//
//  ServerValidatorTests.swift
//  OmniTAKMobileTests
//
//  Regression tests for ServerValidator to ensure connection validation
//  doesn't break with future changes.
//
//  These tests cover:
//  - Port validation and mismatch detection
//  - HTML response detection (common connection issue)
//  - Error response analysis
//  - Host validation
//

import XCTest
@testable import OmniTAKMobile

class ServerValidatorTests: XCTestCase {

    var validator: ServerValidator!

    override func setUp() {
        super.setUp()
        validator = ServerValidator.shared
    }

    // MARK: - Host Validation Tests

    func testValidIPv4Host() {
        let result = validator.validateServerConfig(
            host: "192.168.1.100",
            port: 8089,
            useTLS: true,
            isEnrollment: false
        )
        XCTAssertTrue(result.isValid, "Valid IPv4 address should pass validation")
        XCTAssertFalse(result.hasErrors, "No errors expected for valid IPv4")
    }

    func testValidHostname() {
        let result = validator.validateServerConfig(
            host: "tak-server.example.com",
            port: 8089,
            useTLS: true,
            isEnrollment: false
        )
        XCTAssertTrue(result.isValid, "Valid hostname should pass validation")
    }

    func testValidLocalhostHost() {
        let result = validator.validateServerConfig(
            host: "localhost",
            port: 8089,
            useTLS: false,
            isEnrollment: false
        )
        XCTAssertTrue(result.isValid, "localhost should be valid")
    }

    func testInvalidEmptyHost() {
        let result = validator.validateServerConfig(
            host: "",
            port: 8089,
            useTLS: true,
            isEnrollment: false
        )
        XCTAssertFalse(result.isValid, "Empty host should fail validation")
        XCTAssertEqual(result.primaryIssue?.code, .invalidHost)
    }

    func testInvalidHostWithProtocol() {
        let result = validator.validateServerConfig(
            host: "https://tak-server.example.com",
            port: 8089,
            useTLS: true,
            isEnrollment: false
        )
        XCTAssertFalse(result.isValid, "Host with protocol prefix should fail")
        XCTAssertEqual(result.primaryIssue?.code, .invalidHost)
    }

    func testInvalidHostWithPath() {
        let result = validator.validateServerConfig(
            host: "tak-server.example.com/api",
            port: 8089,
            useTLS: true,
            isEnrollment: false
        )
        XCTAssertFalse(result.isValid, "Host with path should fail")
        XCTAssertEqual(result.primaryIssue?.code, .invalidHost)
    }

    // MARK: - Port Validation Tests

    func testValidPort8089() {
        let result = validator.validateServerConfig(
            host: "tak.example.com",
            port: 8089,
            useTLS: true,
            isEnrollment: false
        )
        XCTAssertTrue(result.isValid, "Port 8089 should be valid for streaming")
    }

    func testValidPort8446() {
        let result = validator.validateServerConfig(
            host: "tak.example.com",
            port: 8446,
            useTLS: true,
            isEnrollment: true,
            username: "user",
            password: "pass"
        )
        XCTAssertTrue(result.isValid, "Port 8446 should be valid for enrollment")
    }

    func testInvalidPortZero() {
        let result = validator.validateServerConfig(
            host: "tak.example.com",
            port: 0,
            useTLS: true,
            isEnrollment: false
        )
        XCTAssertFalse(result.isValid, "Port 0 should be invalid")
        XCTAssertEqual(result.primaryIssue?.code, .invalidPort)
    }

    func testInvalidPortTooHigh() {
        let result = validator.validateServerConfig(
            host: "tak.example.com",
            port: 70000,
            useTLS: true,
            isEnrollment: false
        )
        XCTAssertFalse(result.isValid, "Port above 65535 should be invalid")
        XCTAssertEqual(result.primaryIssue?.code, .invalidPort)
    }

    // MARK: - Port Mismatch Detection Tests (Regression for GitHub Issue #33)

    func testPortMismatch_StreamingPortForEnrollment() {
        // This is the exact scenario from GitHub Issue #33
        // User tries to enroll using port 8089 (streaming) instead of 8446 (enrollment)
        let result = validator.validateServerConfig(
            host: "tak.example.com",
            port: 8089,
            useTLS: true,
            isEnrollment: true,
            username: "user",
            password: "pass"
        )
        XCTAssertFalse(result.isValid, "Using streaming port for enrollment should fail")
        XCTAssertEqual(result.primaryIssue?.code, .portMismatch)
        XCTAssertTrue(result.primaryIssue?.troubleshooting.contains { $0.contains("8446") } ?? false,
                      "Should suggest using port 8446 for enrollment")
    }

    func testPortMismatch_EnrollmentPortForStreaming() {
        let result = validator.validateServerConfig(
            host: "tak.example.com",
            port: 8446,
            useTLS: true,
            isEnrollment: false
        )
        XCTAssertFalse(result.isValid, "Using enrollment port for streaming should fail")
        XCTAssertEqual(result.primaryIssue?.code, .portMismatch)
    }

    func testPortMismatch_WebInterfacePort() {
        // Port 8443 is web interface only - should fail for both streaming and enrollment
        let streamingResult = validator.validateServerConfig(
            host: "tak.example.com",
            port: 8443,
            useTLS: true,
            isEnrollment: false
        )
        XCTAssertFalse(streamingResult.isValid, "Port 8443 should not be valid for streaming")
        XCTAssertEqual(streamingResult.primaryIssue?.code, .portMismatch)

        let enrollmentResult = validator.validateServerConfig(
            host: "tak.example.com",
            port: 8443,
            useTLS: true,
            isEnrollment: true,
            username: "user",
            password: "pass"
        )
        XCTAssertFalse(enrollmentResult.isValid, "Port 8443 should not be valid for enrollment")
    }

    // MARK: - TLS/SSL Warning Tests

    func testWarning_Port8089WithoutTLS() {
        let result = validator.validateServerConfig(
            host: "tak.example.com",
            port: 8089,
            useTLS: false,
            isEnrollment: false
        )
        // This should pass but with a warning
        XCTAssertTrue(result.hasWarnings, "Should warn about TLS for port 8089")
        XCTAssertTrue(result.warnings.first?.message.contains("TLS") ?? false)
    }

    func testWarning_Port8087WithTLS() {
        let result = validator.validateServerConfig(
            host: "tak.example.com",
            port: 8087,
            useTLS: true,
            isEnrollment: false
        )
        // Port 8087 is typically unencrypted
        XCTAssertTrue(result.hasWarnings, "Should warn about TLS on port 8087")
    }

    // MARK: - Credential Validation Tests

    func testEnrollmentRequiresCredentials() {
        let result = validator.validateServerConfig(
            host: "tak.example.com",
            port: 8446,
            useTLS: true,
            isEnrollment: true,
            username: nil,
            password: nil
        )
        XCTAssertFalse(result.isValid, "Enrollment without credentials should fail")
        XCTAssertEqual(result.primaryIssue?.code, .missingCredentials)
    }

    func testEnrollmentRequiresBothUsernameAndPassword() {
        let result = validator.validateServerConfig(
            host: "tak.example.com",
            port: 8446,
            useTLS: true,
            isEnrollment: true,
            username: "user",
            password: ""  // Empty password
        )
        XCTAssertFalse(result.isValid, "Enrollment with empty password should fail")
        XCTAssertEqual(result.primaryIssue?.code, .missingCredentials)
    }

    func testStreamingDoesNotRequireCredentials() {
        let result = validator.validateServerConfig(
            host: "tak.example.com",
            port: 8089,
            useTLS: true,
            isEnrollment: false,
            username: nil,
            password: nil
        )
        // Streaming connections can work without username/password
        // (they use certificates instead)
        let credentialIssue = result.issues.first { $0.code == .missingCredentials }
        XCTAssertNil(credentialIssue, "Streaming should not require credentials")
    }

    // MARK: - HTML Response Detection Tests (Regression for GitHub Issue #33)

    func testDetectHTMLResponse_FullHTMLPage() {
        let htmlData = """
        <!DOCTYPE html>
        <html>
        <head><title>TAK Server</title></head>
        <body>
        <h1>Welcome to TAK Server</h1>
        </body>
        </html>
        """.data(using: .utf8)!

        let issue = validator.detectHTMLResponse(data: htmlData)
        XCTAssertNotNil(issue, "Should detect HTML response")
        XCTAssertEqual(issue?.code, .htmlResponseDetected)
        XCTAssertTrue(issue?.troubleshooting.contains { $0.contains("wrong port") } ?? false,
                      "Should mention wrong port in troubleshooting")
    }

    func testDetectHTMLResponse_ErrorPage() {
        let errorPageData = """
        <html>
        <head><title>500 Internal Server Error</title></head>
        <body><h1>Internal Server Error</h1></body>
        </html>
        """.data(using: .utf8)!

        let issue = validator.detectHTMLResponse(data: errorPageData)
        XCTAssertNotNil(issue, "Should detect HTML error page")
        XCTAssertTrue(issue?.message.contains("500") ?? false,
                      "Should extract error code from title")
    }

    func testDetectHTMLResponse_ValidXMLNotHTML() {
        let xmlData = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event uid="test" type="a-f-G"/>
        """.data(using: .utf8)!

        let issue = validator.detectHTMLResponse(data: xmlData)
        XCTAssertNil(issue, "Should not flag valid XML as HTML")
    }

    func testDetectHTMLResponse_ValidJSONNotHTML() {
        let jsonData = """
        {"signedCert": "-----BEGIN CERTIFICATE-----..."}
        """.data(using: .utf8)!

        let issue = validator.detectHTMLResponse(data: jsonData)
        XCTAssertNil(issue, "Should not flag valid JSON as HTML")
    }

    // MARK: - Error Response Analysis Tests

    func testAnalyzeErrorResponse_401Unauthorized() {
        let data = "Unauthorized".data(using: .utf8)!
        let issue = validator.analyzeErrorResponse(statusCode: 401, data: data, context: .enrollment)

        XCTAssertEqual(issue.code, .missingCredentials)
        XCTAssertTrue(issue.message.lowercased().contains("authentication"))
    }

    func testAnalyzeErrorResponse_403Forbidden() {
        let data = "Forbidden".data(using: .utf8)!
        let issue = validator.analyzeErrorResponse(statusCode: 403, data: data, context: .enrollment)

        XCTAssertEqual(issue.code, .missingCredentials)
        XCTAssertTrue(issue.message.lowercased().contains("forbidden"))
    }

    func testAnalyzeErrorResponse_404NotFound() {
        let data = "Not Found".data(using: .utf8)!
        let issue = validator.analyzeErrorResponse(statusCode: 404, data: data, context: .enrollment)

        XCTAssertEqual(issue.code, .portMismatch)
        XCTAssertTrue(issue.troubleshooting.contains { $0.contains("endpoint") })
    }

    func testAnalyzeErrorResponse_500ServerError() {
        // This is the exact error from GitHub Issue #33
        let data = "TAK Server resource unavailable or not allowed".data(using: .utf8)!
        let issue = validator.analyzeErrorResponse(statusCode: 500, data: data, context: .enrollment)

        XCTAssertTrue(issue.troubleshooting.contains { $0.contains("enrollment API") } ||
                      issue.troubleshooting.contains { $0.contains("disabled") },
                      "Should mention enrollment API might be disabled")
    }

    func testAnalyzeErrorResponse_500WithHTMLPage() {
        let htmlErrorData = """
        <!DOCTYPE html>
        <html><head><title>Error</title></head>
        <body><h1>500 Internal Server Error</h1></body>
        </html>
        """.data(using: .utf8)!

        let issue = validator.analyzeErrorResponse(statusCode: 500, data: htmlErrorData, context: .enrollment)

        // Should detect HTML and provide appropriate guidance
        XCTAssertEqual(issue.code, .htmlResponseDetected)
    }

    func testAnalyzeErrorResponse_502BadGateway() {
        let data = "Bad Gateway".data(using: .utf8)!
        let issue = validator.analyzeErrorResponse(statusCode: 502, data: data, context: .enrollment)

        XCTAssertEqual(issue.code, .unreachable)
    }

    func testAnalyzeErrorResponse_503ServiceUnavailable() {
        let data = "Service Unavailable".data(using: .utf8)!
        let issue = validator.analyzeErrorResponse(statusCode: 503, data: data, context: .enrollment)

        XCTAssertEqual(issue.code, .unreachable)
    }

    // MARK: - Edge Cases

    func testValidationWithSpecialCharactersInHost() {
        let result = validator.validateServerConfig(
            host: "tak-server_01.example.com",
            port: 8089,
            useTLS: true,
            isEnrollment: false
        )
        // Underscores are technically not valid in hostnames per RFC
        // but many systems accept them
        XCTAssertNotNil(result, "Should handle special characters")
    }

    func testValidationWithIPv6Address() {
        let result = validator.validateServerConfig(
            host: "::1",  // IPv6 localhost
            port: 8089,
            useTLS: false,
            isEnrollment: false
        )
        XCTAssertTrue(result.isValid, "Should accept IPv6 addresses")
    }
}

// MARK: - Error Message Formatter Tests

class ErrorMessageFormatterTests: XCTestCase {

    func testFormatHTMLResponseIssue() {
        let issue = ValidationIssue(
            code: .htmlResponseDetected,
            message: "Server returned web page",
            troubleshooting: ["Check port", "Try 8446"]
        )

        let formatted = ErrorMessageFormatter.format(issue: issue)

        XCTAssertFalse(formatted.title.isEmpty)
        XCTAssertFalse(formatted.message.isEmpty)
        XCTAssertTrue(formatted.message.contains("web page"))
        XCTAssertFalse(formatted.steps.isEmpty)
    }

    func testFormatPortMismatchIssue() {
        let issue = ValidationIssue(
            code: .portMismatch,
            message: "Wrong port",
            troubleshooting: ["Use 8446 for enrollment", "Use 8089 for streaming"]
        )

        let formatted = ErrorMessageFormatter.format(issue: issue)

        XCTAssertTrue(formatted.steps.contains("8446"))
        XCTAssertTrue(formatted.steps.contains("8089"))
    }
}
