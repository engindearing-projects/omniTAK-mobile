//
//  CSRGenerator.swift
//  OmniTAKMobile
//
//  Certificate Signing Request (CSR) generation for TAK server enrollment
//  Generates RSA key pair locally and creates X.509 CSR for server signing
//

import Foundation
import Security
import CryptoKit

// MARK: - CSR Generation Errors

enum CSRGenerationError: LocalizedError {
    case keyGenerationFailed
    case csrCreationFailed(String)
    case keychainStorageError(OSStatus)
    case invalidParameters(String)

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate RSA key pair"
        case .csrCreationFailed(let details):
            return "Failed to create CSR: \(details)"
        case .keychainStorageError(let status):
            return "Failed to store key in keychain: \(status)"
        case .invalidParameters(let details):
            return "Invalid parameters: \(details)"
        }
    }
}

// MARK: - CSR Configuration

struct CSRConfiguration {
    let commonName: String              // CN - typically username
    let organization: String            // O - organization name
    let organizationalUnit: String      // OU - unit/department
    let country: String                 // C - two-letter country code
    let email: String?                  // Optional email
    let domainComponents: [String]      // DC - domain components (from TAK server)

    // Key specifications
    let keySize: Int = 2048             // RSA key size (2048 or 4096)
    let keyTag: String                  // Unique tag for keychain storage

    init(
        commonName: String,
        organization: String = "OmniTAK",
        organizationalUnit: String = "Mobile",
        country: String = "US",
        email: String? = nil,
        domainComponents: [String] = [],
        keyTag: String? = nil
    ) {
        self.commonName = commonName
        self.organization = organization
        self.organizationalUnit = organizationalUnit
        self.country = country
        self.email = email
        self.domainComponents = domainComponents
        self.keyTag = keyTag ?? "com.engindearing.omnitak.csr.\(commonName)"
    }
}

// MARK: - CSR Result

struct CSRResult {
    let csrData: Data                   // DER-encoded CSR
    let csrBase64: String               // Base64-encoded CSR for transmission
    let privateKeyTag: String           // Keychain tag for retrieving private key
    let publicKey: SecKey               // Public key reference
}

// MARK: - CSR Generator

class CSRGenerator {

    // MARK: - Main CSR Generation

    /// Generate a Certificate Signing Request with RSA key pair
    /// - Parameter config: CSR configuration with subject DN attributes
    /// - Returns: CSR result with encoded CSR and key references
    func generateCSR(config: CSRConfiguration) throws -> CSRResult {
        print("[CSR] Generating CSR for CN=\(config.commonName)")

        // Step 1: Generate RSA key pair
        print("[CSR] Generating \(config.keySize)-bit RSA key pair...")
        let (privateKey, publicKey) = try generateRSAKeyPair(
            keySize: config.keySize,
            tag: config.keyTag
        )

        // Step 2: Create CSR with subject DN
        print("[CSR] Creating CSR with subject DN...")
        let csrData = try createCSRData(
            publicKey: publicKey,
            privateKey: privateKey,
            config: config
        )

        // Step 3: Encode CSR as base64 for transmission
        let csrBase64 = csrData.base64EncodedString()
        print("[CSR] CSR generated successfully (\(csrData.count) bytes)")

        return CSRResult(
            csrData: csrData,
            csrBase64: csrBase64,
            privateKeyTag: config.keyTag,
            publicKey: publicKey
        )
    }

    // MARK: - RSA Key Pair Generation

    private func generateRSAKeyPair(keySize: Int, tag: String) throws -> (SecKey, SecKey) {
        // Delete any existing key with this tag
        deleteKeyFromKeychain(tag: tag)

        // Key generation parameters
        // TAKaware approach: Use both kSecAttrLabel and kSecAttrApplicationTag
        // The label is what iOS uses to match the certificate with the private key
        let privateKeyAttrs: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrLabel as String: tag,  // Add label for identity matching
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let parameters: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: keySize,
            kSecPrivateKeyAttrs as String: privateKeyAttrs
        ]

        // Generate key pair
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(parameters as CFDictionary, &error) else {
            if let error = error?.takeRetainedValue() {
                print("[CSR] Key generation failed: \(error)")
            }
            throw CSRGenerationError.keyGenerationFailed
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CSRGenerationError.keyGenerationFailed
        }

        print("[CSR] RSA key pair generated and stored in keychain")
        return (privateKey, publicKey)
    }

    // MARK: - CSR Data Creation

    private func createCSRData(
        publicKey: SecKey,
        privateKey: SecKey,
        config: CSRConfiguration
    ) throws -> Data {
        // Build subject Distinguished Name (DN)
        let subjectDN = buildSubjectDN(config: config)
        print("[CSR] Subject DN: \(subjectDN)")
        if !config.domainComponents.isEmpty {
            print("[CSR] Domain Components: \(config.domainComponents)")
        }

        // Get public key data
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            if let error = error?.takeRetainedValue() {
                throw CSRGenerationError.csrCreationFailed("Failed to export public key: \(error)")
            }
            throw CSRGenerationError.csrCreationFailed("Failed to export public key")
        }

        // Build CSR in PKCS#10 format (RFC 2986)
        let csrData = try buildPKCS10CSR(
            publicKeyData: publicKeyData,
            privateKey: privateKey,
            subjectDN: subjectDN,
            domainComponents: config.domainComponents
        )

        return csrData
    }

    // MARK: - Subject DN Building

    private func buildSubjectDN(config: CSRConfiguration) -> [String: String] {
        var dn: [String: String] = [
            "CN": config.commonName,
            "O": config.organization,
            "OU": config.organizationalUnit,
            "C": config.country
        ]

        if let email = config.email {
            dn["emailAddress"] = email
        }

        return dn
    }

    // MARK: - PKCS#10 CSR Construction

    private func buildPKCS10CSR(
        publicKeyData: Data,
        privateKey: SecKey,
        subjectDN: [String: String],
        domainComponents: [String] = []
    ) throws -> Data {
        // Build CSR ASN.1 structure manually
        // PKCS#10 CSR structure:
        // CertificationRequest ::= SEQUENCE {
        //   certificationRequestInfo CertificationRequestInfo,
        //   signatureAlgorithm AlgorithmIdentifier,
        //   signature BIT STRING
        // }

        // For now, we'll use a simplified approach that creates the basic structure
        // In production, you might want to use a proper ASN.1 library

        // Build CertificationRequestInfo
        let requestInfo = try buildCertificationRequestInfo(
            publicKeyData: publicKeyData,
            subjectDN: subjectDN,
            domainComponents: domainComponents
        )

        // Sign the request info with private key
        let signature = try signData(requestInfo, with: privateKey)

        // Combine into final CSR structure
        let csr = try assemblePKCS10CSR(
            requestInfo: requestInfo,
            signature: signature
        )

        return csr
    }

    private func buildCertificationRequestInfo(
        publicKeyData: Data,
        subjectDN: [String: String],
        domainComponents: [String] = []
    ) throws -> Data {
        // This is a simplified implementation
        // A full implementation would properly encode ASN.1 structures

        var requestInfo = Data()

        // Version (INTEGER 0)
        requestInfo.append(contentsOf: [0x02, 0x01, 0x00])

        // Subject DN (SEQUENCE)
        let encodedDN = try encodeSubjectDN(subjectDN, domainComponents: domainComponents)
        requestInfo.append(encodedDN)

        // SubjectPublicKeyInfo
        let encodedPublicKey = try encodePublicKeyInfo(publicKeyData)
        requestInfo.append(encodedPublicKey)

        // Attributes (CONTEXT SPECIFIC [0])
        // Empty for basic CSR
        requestInfo.append(contentsOf: [0xA0, 0x00])

        // Wrap in SEQUENCE
        return wrapInSequence(requestInfo)
    }

    private func encodeSubjectDN(_ dn: [String: String], domainComponents: [String] = []) throws -> Data {
        // Encode DN as ASN.1 SEQUENCE of SETs of SEQUENCEs
        // This is simplified - production code should use proper ASN.1 encoding

        var dnData = Data()

        // Domain components come first (in reverse order - most specific first)
        // TAK servers may return DC entries like ["tak", "flighttactics", "com"]
        for dc in domainComponents.reversed() {
            guard let oid = getOIDForAttribute("DC") else { continue }

            var attrSeq = Data()
            attrSeq.append(encodeOID(oid))
            attrSeq.append(encodeIA5String(dc))  // DC uses IA5String, not UTF8String
            let attrSeqWrapped = wrapInSequence(attrSeq)
            let attrSet = wrapInSet(attrSeqWrapped)
            dnData.append(attrSet)
        }

        // Standard order for DN components
        let order = ["C", "O", "OU", "CN", "emailAddress"]

        for key in order {
            guard let value = dn[key] else { continue }

            // Get OID for this attribute
            guard let oid = getOIDForAttribute(key) else { continue }

            // Build attribute: SEQUENCE { OID, UTF8String value }
            var attrSeq = Data()
            attrSeq.append(encodeOID(oid))
            attrSeq.append(encodeUTF8String(value))
            let attrSeqWrapped = wrapInSequence(attrSeq)

            // Wrap in SET
            let attrSet = wrapInSet(attrSeqWrapped)
            dnData.append(attrSet)
        }

        return wrapInSequence(dnData)
    }

    private func getOIDForAttribute(_ attribute: String) -> [UInt8]? {
        // Common OIDs for certificate attributes
        switch attribute {
        case "DC": // Domain Component (0.9.2342.19200300.100.1.25)
            return [0x09, 0x92, 0x26, 0x89, 0x93, 0xF2, 0x2C, 0x64, 0x01, 0x19]
        case "C":  // Country
            return [0x55, 0x04, 0x06]
        case "O":  // Organization
            return [0x55, 0x04, 0x0A]
        case "OU": // Organizational Unit
            return [0x55, 0x04, 0x0B]
        case "CN": // Common Name
            return [0x55, 0x04, 0x03]
        case "emailAddress":
            return [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x09, 0x01]
        default:
            return nil
        }
    }

    private func encodeOID(_ oid: [UInt8]) -> Data {
        var data = Data([0x06]) // OID tag
        data.append(UInt8(oid.count))
        data.append(contentsOf: oid)
        return data
    }

    private func encodeUTF8String(_ string: String) -> Data {
        guard let stringData = string.data(using: .utf8) else {
            return Data()
        }
        var data = Data([0x0C]) // UTF8String tag
        data.append(UInt8(stringData.count))
        data.append(stringData)
        return data
    }

    private func encodeIA5String(_ string: String) -> Data {
        guard let stringData = string.data(using: .ascii) else {
            return Data()
        }
        var data = Data([0x16]) // IA5String tag
        data.append(UInt8(stringData.count))
        data.append(stringData)
        return data
    }

    private func encodePublicKeyInfo(_ publicKeyData: Data) throws -> Data {
        // SubjectPublicKeyInfo ::= SEQUENCE {
        //   algorithm AlgorithmIdentifier,
        //   subjectPublicKey BIT STRING
        // }

        // RSA algorithm identifier
        let rsaOID: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]
        let algorithmId = wrapInSequence(
            encodeOID(rsaOID) + Data([0x05, 0x00]) // NULL parameter
        )

        // Public key as BIT STRING
        var bitString = Data([0x03]) // BIT STRING tag
        var keyWithPadding = Data([0x00]) // No unused bits
        keyWithPadding.append(publicKeyData)
        bitString.append(encodeLengthBytes(keyWithPadding.count))
        bitString.append(keyWithPadding)

        return wrapInSequence(algorithmId + bitString)
    }

    private func signData(_ data: Data, with privateKey: SecKey) throws -> Data {
        // Sign using SHA256 with RSA
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            data as CFData,
            &error
        ) as Data? else {
            if let error = error?.takeRetainedValue() {
                throw CSRGenerationError.csrCreationFailed("Signature failed: \(error)")
            }
            throw CSRGenerationError.csrCreationFailed("Signature failed")
        }

        return signature
    }

    private func assemblePKCS10CSR(requestInfo: Data, signature: Data) throws -> Data {
        // CertificationRequest ::= SEQUENCE {
        //   certificationRequestInfo,
        //   signatureAlgorithm,
        //   signature BIT STRING
        // }

        var csr = Data()

        // Add request info
        csr.append(requestInfo)

        // Add signature algorithm (SHA256 with RSA)
        let sha256RsaOID: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B]
        let signatureAlgorithm = wrapInSequence(
            encodeOID(sha256RsaOID) + Data([0x05, 0x00]) // NULL parameter
        )
        csr.append(signatureAlgorithm)

        // Add signature as BIT STRING
        var bitString = Data([0x03]) // BIT STRING tag
        var sigWithPadding = Data([0x00]) // No unused bits
        sigWithPadding.append(signature)
        bitString.append(encodeLengthBytes(sigWithPadding.count))
        bitString.append(sigWithPadding)
        csr.append(bitString)

        // Wrap entire CSR in SEQUENCE
        return wrapInSequence(csr)
    }

    // MARK: - ASN.1 Encoding Helpers

    private func wrapInSequence(_ data: Data) -> Data {
        var result = Data([0x30]) // SEQUENCE tag
        result.append(encodeLengthBytes(data.count))
        result.append(data)
        return result
    }

    private func wrapInSet(_ data: Data) -> Data {
        var result = Data([0x31]) // SET tag
        result.append(encodeLengthBytes(data.count))
        result.append(data)
        return result
    }

    private func encodeLengthBytes(_ length: Int) -> Data {
        if length < 128 {
            return Data([UInt8(length)])
        } else if length < 256 {
            return Data([0x81, UInt8(length)])
        } else if length < 65536 {
            return Data([0x82, UInt8(length >> 8), UInt8(length & 0xFF)])
        } else {
            // For larger lengths, use 3 bytes
            return Data([0x83, UInt8(length >> 16), UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF)])
        }
    }

    // MARK: - Keychain Management

    /// Retrieve private key from keychain by tag
    func retrievePrivateKey(tag: String) -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            print("[CSR] Failed to retrieve private key: \(status)")
            return nil
        }

        return (item as! SecKey)
    }

    /// Delete key from keychain
    func deleteKeyFromKeychain(tag: String) {
        // Delete by application tag
        let tagQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA
        ]
        let tagStatus = SecItemDelete(tagQuery as CFDictionary)
        if tagStatus == errSecSuccess {
            print("[CSR] Deleted existing key with tag: \(tag)")
        }

        // Also delete by label (TAKaware approach)
        let labelQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrLabel as String: tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA
        ]
        let labelStatus = SecItemDelete(labelQuery as CFDictionary)
        if labelStatus == errSecSuccess {
            print("[CSR] Deleted existing key with label: \(tag)")
        }
    }

    // MARK: - Validation

    /// Validate CSR configuration
    func validateConfiguration(_ config: CSRConfiguration) throws {
        guard !config.commonName.isEmpty else {
            throw CSRGenerationError.invalidParameters("Common Name (CN) is required")
        }

        guard !config.organization.isEmpty else {
            throw CSRGenerationError.invalidParameters("Organization (O) is required")
        }

        guard config.country.count == 2 else {
            throw CSRGenerationError.invalidParameters("Country (C) must be 2-letter code")
        }

        guard [2048, 4096].contains(config.keySize) else {
            throw CSRGenerationError.invalidParameters("Key size must be 2048 or 4096")
        }
    }
}

// MARK: - Convenience Extensions

extension CSRGenerator {

    /// Generate CSR with minimal configuration (username only)
    func generateCSR(username: String) throws -> CSRResult {
        let config = CSRConfiguration(
            commonName: username,
            organization: "OmniTAK",
            organizationalUnit: "Mobile Client",
            country: "US"
        )

        try validateConfiguration(config)
        return try generateCSR(config: config)
    }

    /// Generate CSR with CA configuration from server
    /// - Parameters:
    ///   - username: The username (CN) for the certificate
    ///   - caConfig: CA configuration from server with DN components
    ///   - keyTag: Optional custom key tag (defaults to standard format if nil)
    func generateCSR(username: String, caConfig: CAConfiguration, keyTag: String? = nil) throws -> CSRResult {
        // Use DN components from server, or defaults if not provided
        let organization = caConfig.organizationNames.first ?? "TAK"
        let organizationalUnit = caConfig.organizationalUnitNames.first ?? "TAK"

        let config = CSRConfiguration(
            commonName: username,
            organization: organization,
            organizationalUnit: organizationalUnit,
            country: "US",
            domainComponents: caConfig.domainComponents,
            keyTag: keyTag  // Pass through custom key tag
        )

        try validateConfiguration(config)
        return try generateCSR(config: config)
    }
}
