//
//  ServerValidator.swift
//  OmniTAKMobile
//
//  Validates TAK server configurations and detects common connection issues
//  Provides helpful diagnostics and troubleshooting guidance
//

import Foundation
import Network

// MARK: - Validation Result

struct ServerValidationResult {
    let isValid: Bool
    let issues: [ValidationIssue]
    let warnings: [ValidationWarning]

    var hasErrors: Bool { !issues.isEmpty }
    var hasWarnings: Bool { !warnings.isEmpty }

    var primaryIssue: ValidationIssue? { issues.first }
}

struct ValidationIssue {
    let code: IssueCode
    let message: String
    let troubleshooting: [String]

    enum IssueCode {
        case invalidHost
        case invalidPort
        case portMismatch
        case missingCredentials
        case htmlResponseDetected
        case sslRequired
        case unreachable
    }
}

struct ValidationWarning {
    let message: String
    let suggestion: String
}

// MARK: - Server Validator

class ServerValidator {

    static let shared = ServerValidator()

    // Standard TAK server ports
    private let standardPorts = StandardTAKPorts()

    private init() {}

    // MARK: - Validation Methods

    /// Validate server configuration before connection attempt
    func validateServerConfig(
        host: String,
        port: Int,
        useTLS: Bool,
        isEnrollment: Bool,
        username: String? = nil,
        password: String? = nil
    ) -> ServerValidationResult {
        var issues: [ValidationIssue] = []
        var warnings: [ValidationWarning] = []

        // 1. Validate host
        if !isValidHost(host) {
            issues.append(ValidationIssue(
                code: .invalidHost,
                message: "Invalid server address",
                troubleshooting: [
                    "Enter a valid hostname or IP address",
                    "Examples: 192.168.1.100, tak.example.com",
                    "Do not include http:// or https:// prefix"
                ]
            ))
        }

        // 2. Validate port
        if !isValidPort(port) {
            issues.append(ValidationIssue(
                code: .invalidPort,
                message: "Invalid port number",
                troubleshooting: [
                    "Port must be between 1 and 65535",
                    "Common TAK ports: 8089 (streaming), 8446 (enrollment)"
                ]
            ))
        }

        // 3. Check for port/purpose mismatch
        if let mismatch = detectPortMismatch(port: port, isEnrollment: isEnrollment, useTLS: useTLS) {
            issues.append(mismatch)
        }

        // 4. Check credentials for enrollment
        if isEnrollment {
            if username?.isEmpty ?? true || password?.isEmpty ?? true {
                issues.append(ValidationIssue(
                    code: .missingCredentials,
                    message: "Username and password required",
                    troubleshooting: [
                        "Certificate enrollment requires authentication",
                        "Enter your TAK server username and password",
                        "Contact your server administrator if you don't have credentials"
                    ]
                ))
            }
        }

        // 5. SSL/TLS recommendations
        if !useTLS && port == standardPorts.streamingTLS {
            warnings.append(ValidationWarning(
                message: "Port 8089 typically requires TLS",
                suggestion: "Enable TLS/SSL for this connection"
            ))
        }

        if useTLS && port == standardPorts.streamingTCP {
            warnings.append(ValidationWarning(
                message: "Port 8087 is typically unencrypted",
                suggestion: "Disable TLS or use port 8089"
            ))
        }

        return ServerValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }

    /// Detect if server returned HTML instead of expected protocol
    func detectHTMLResponse(data: Data) -> ValidationIssue? {
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        // Check for HTML markers
        let htmlIndicators = [
            "<!DOCTYPE html",
            "<html",
            "<head>",
            "<body>",
            "text/html"
        ]

        let isHTML = htmlIndicators.contains { text.contains($0) }

        if isHTML {
            // Try to extract error message from HTML title tag
            var pageTitle: String? = nil

            // Use NSRegularExpression for reliable extraction
            if let regex = try? NSRegularExpression(pattern: "<title[^>]*>([^<]+)</title>", options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let titleRange = Range(match.range(at: 1), in: text) {
                let extractedTitle = String(text[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !extractedTitle.isEmpty && extractedTitle.count < 100 {
                    pageTitle = extractedTitle
                }
            }

            let errorMessage: String
            if let title = pageTitle {
                errorMessage = "Server returned web page: \"\(title)\""
            } else {
                errorMessage = "Server returned a web page instead of expected data"
            }

            return ValidationIssue(
                code: .htmlResponseDetected,
                message: errorMessage,
                troubleshooting: [
                    "This usually means you're connecting to the wrong port.",
                    "",
                    "TAK Server Ports:",
                    "• Port 8089 - CoT Streaming (TLS) - use for connections",
                    "• Port 8446 - Certificate Enrollment API",
                    "• Port 8443 - Web Interface (browsers only, not for apps)",
                    "",
                    "Common fixes:",
                    "1. For enrollment: ensure you're using port 8446",
                    "2. For streaming: use port 8089 with TLS enabled",
                    "3. Verify with your server administrator"
                ]
            )
        }

        return nil
    }

    /// Validate error response and provide guidance
    func analyzeErrorResponse(statusCode: Int, data: Data, context: ErrorContext) -> ValidationIssue {
        // Check if it's an HTML response
        if let htmlIssue = detectHTMLResponse(data: data) {
            return htmlIssue
        }

        // Analyze HTTP status codes
        switch statusCode {
        case 401:
            return ValidationIssue(
                code: .missingCredentials,
                message: "Authentication failed (401)",
                troubleshooting: [
                    "Possible causes:",
                    "• Username or password is incorrect",
                    "• Account is not active or not authorized for enrollment",
                    "• Server requires different authentication method",
                    "",
                    "Try these steps:",
                    "1. Double-check your username and password",
                    "2. Verify your account is active on the TAK server",
                    "3. Ask your admin if your account has enrollment permissions",
                    "4. Try scanning a QR code or importing a Data Package instead"
                ]
            )

        case 403:
            return ValidationIssue(
                code: .missingCredentials,
                message: "Access forbidden",
                troubleshooting: [
                    "Your account doesn't have permission for this operation",
                    "Contact the server administrator to enable enrollment permissions",
                    "You may need to be added to a specific group"
                ]
            )

        case 404:
            return ValidationIssue(
                code: .portMismatch,
                message: "Enrollment endpoint not found",
                troubleshooting: [
                    "The server doesn't have the enrollment API at this address",
                    "Verify you're using the correct port (usually 8446)",
                    "The server may not support CSR-based enrollment",
                    "You may need to use a Data Package instead",
                    "Contact your administrator for the correct enrollment method"
                ]
            )

        case 500:
            let responseText = String(data: data, encoding: .utf8) ?? ""
            var troubleshooting = [
                "The server encountered an internal error",
                "This could indicate:"
            ]

            if responseText.contains("unavailable") || responseText.contains("not allowed") {
                troubleshooting.append("• The enrollment API is disabled on this server")
                troubleshooting.append("• Your account lacks required permissions")
            }

            troubleshooting.append("• Server misconfiguration")
            troubleshooting.append("")
            troubleshooting.append("Try these steps:")
            troubleshooting.append("1. Contact your server administrator")
            troubleshooting.append("2. Ask if certificate enrollment is enabled")
            troubleshooting.append("3. Request a Data Package (.zip) instead")
            troubleshooting.append("4. Verify the server is properly configured")

            return ValidationIssue(
                code: .htmlResponseDetected,
                message: "Server error (500)",
                troubleshooting: troubleshooting
            )

        case 502, 503, 504:
            return ValidationIssue(
                code: .unreachable,
                message: "Server unavailable",
                troubleshooting: [
                    "The server is not responding",
                    "Check if the server is online",
                    "Verify your network connection",
                    "The server may be undergoing maintenance"
                ]
            )

        default:
            return ValidationIssue(
                code: .htmlResponseDetected,
                message: "Server error (\(statusCode))",
                troubleshooting: [
                    "Unexpected server response",
                    "Contact your server administrator",
                    "Provide them with error code: \(statusCode)"
                ]
            )
        }
    }

    // MARK: - Private Validation Helpers

    private func isValidHost(_ host: String) -> Bool {
        if host.isEmpty {
            return false
        }

        // Check if it's a valid IP address
        if IPv4Address(host) != nil || IPv6Address(host) != nil {
            return true
        }

        // Check if it's a valid hostname
        let hostnameRegex = "^([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.)*[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?$"
        let hostnamePredicate = NSPredicate(format: "SELF MATCHES %@", hostnameRegex)

        // Also reject URLs (common mistake)
        if host.contains("://") || host.contains("/") {
            return false
        }

        return hostnamePredicate.evaluate(with: host)
    }

    private func isValidPort(_ port: Int) -> Bool {
        return port > 0 && port <= 65535
    }

    private func detectPortMismatch(port: Int, isEnrollment: Bool, useTLS: Bool) -> ValidationIssue? {
        // Check for obvious mismatches
        if isEnrollment {
            // Enrollment should use API ports (8446, 8443)
            if port == standardPorts.streamingTLS || port == standardPorts.streamingTCP {
                return ValidationIssue(
                    code: .portMismatch,
                    message: "Wrong port for enrollment",
                    troubleshooting: [
                        "Port \(port) is for streaming connections, not enrollment",
                        "Certificate enrollment typically uses port 8446",
                        "Change the enrollment port to 8446",
                        "If unsure, contact your server administrator"
                    ]
                )
            }
        } else {
            // Streaming should use CoT ports (8089, 8087)
            if port == standardPorts.enrollmentAPI || port == standardPorts.webInterface {
                return ValidationIssue(
                    code: .portMismatch,
                    message: "Wrong port for streaming",
                    troubleshooting: [
                        "Port \(port) is for web/API access, not streaming",
                        "Streaming connections typically use port 8089",
                        "Make sure TLS is enabled for port 8089",
                        "If unsure, contact your server administrator"
                    ]
                )
            }
        }

        // Check for web interface port
        if port == standardPorts.webInterface {
            return ValidationIssue(
                code: .portMismatch,
                message: "Cannot connect to web interface",
                troubleshooting: [
                    "Port 8443 is the web interface (for browsers)",
                    "Mobile apps cannot connect to this port",
                    "Use port 8089 for streaming (TLS required)",
                    "Use port 8446 for certificate enrollment"
                ]
            )
        }

        return nil
    }
}

// MARK: - Standard TAK Ports

struct StandardTAKPorts {
    let streamingTCP = 8087      // Unencrypted CoT streaming
    let streamingTLS = 8089      // TLS-encrypted CoT streaming (most common)
    let webInterface = 8443      // HTTPS web interface
    let enrollmentAPI = 8446     // Certificate enrollment API
}

// MARK: - Error Context

enum ErrorContext {
    case enrollment
    case connection
    case dataSync
}

// MARK: - User-Friendly Error Formatter

class ErrorMessageFormatter {

    static func format(issue: ValidationIssue) -> (title: String, message: String, steps: String) {
        let title = issue.message

        var message = ""
        var steps = ""

        switch issue.code {
        case .htmlResponseDetected:
            message = "The server returned a web page instead of the expected response. This usually means you're connecting to the wrong port."

        case .portMismatch:
            message = "The port you're using doesn't match the type of connection you're trying to make."

        case .missingCredentials:
            message = "This operation requires authentication."

        case .unreachable:
            message = "Cannot reach the server at this address."

        case .invalidHost:
            message = "The server address format is invalid."

        case .invalidPort:
            message = "The port number is outside the valid range."

        case .sslRequired:
            message = "This connection requires TLS/SSL encryption."
        }

        if !issue.troubleshooting.isEmpty {
            steps = issue.troubleshooting.joined(separator: "\n")
        }

        return (title, message, steps)
    }
}
