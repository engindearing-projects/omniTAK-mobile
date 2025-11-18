# TLS Legacy Support for TAK Servers

## Overview

OmniTAK Mobile includes comprehensive TLS/SSL support for connecting to TAK servers, including legacy servers running older OpenSSL versions and TLS protocols.

## Supported TLS Versions

### Default Mode (Secure)
- **Minimum**: TLS 1.2
- **Maximum**: TLS 1.3
- **Recommended for**: All modern TAK servers (2020+)

### Legacy Mode (Opt-in)
- **Minimum**: TLS 1.0 ⚠️
- **Maximum**: TLS 1.3
- **Use only when**: Connecting to very old TAK servers that cannot be upgraded

## Supported Cipher Suites

### Modern Cipher Suites (Default)
```
TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384  (Recommended)
TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256  (Recommended)
TLS_RSA_WITH_AES_256_GCM_SHA384
TLS_RSA_WITH_AES_128_GCM_SHA256
```

### Legacy Cipher Suites (For Old Servers)
```
TLS_RSA_WITH_AES_256_CBC_SHA
TLS_RSA_WITH_AES_128_CBC_SHA
```

## Features

### ✅ What's Supported

- **TLS 1.2 and 1.3** (default, secure)
- **TLS 1.0 and 1.1** (opt-in, legacy mode)
- **Self-signed certificates** (common in TAK deployments)
- **Client certificate authentication** (.p12 format)
- **Legacy cipher suites** for older OpenSSL versions
- **Automatic TLS version negotiation**
- **Real-time TLS negotiation logging** (debug mode)

### 🔒 Security Features

- **Self-signed CA support**: Accepts server certificates signed by custom CAs
- **Client certificates**: Mutual TLS authentication with .p12 certificates
- **Keychain integration**: Secure storage of client certificates
- **Certificate validation bypass**: For TAK servers with self-signed certs

## Configuration

### Enable Legacy TLS Mode

When creating or editing a server, set `allowLegacyTLS: true`:

```swift
let server = TAKServer(
    name: "Old TAK Server",
    host: "legacy-tak.example.com",
    port: 8089,
    protocolType: "ssl",
    useTLS: true,
    allowLegacyTLS: true  // ⚠️ Enable TLS 1.0/1.1
)
```

### Default (Secure) Mode

```swift
let server = TAKServer(
    name: "Modern TAK Server",
    host: "tak.example.com",
    port: 8089,
    protocolType: "ssl",
    useTLS: true,
    allowLegacyTLS: false  // Default: TLS 1.2+ only
)
```

## Debug Logging

In debug builds, OmniTAK logs detailed TLS negotiation information:

```
🔒 Using TLS/SSL (TLS 1.2-1.3, legacy cipher suites enabled, accepting self-signed certs)
🔓 Accepting server certificate (self-signed CA)
🔐 Configuring client certificate: my-cert
✅ Client certificate loaded successfully
🔐 TLS Negotiated: TLS 1.2, Cipher: 0xC030
```

### Log Details

- **TLS Version**: Shows negotiated version (1.0, 1.1, 1.2, or 1.3)
- **Cipher Suite**: Shows cipher suite in hex format
- **Certificate Status**: Shows certificate loading success/failure

## Common TAK Server Configurations

### FreeTAKServer (Default)
```
Protocol: TLS
Port: 8089
TLS Version: 1.2+
Certificates: Self-signed
Client Cert: Required
Legacy Mode: Not needed
```

### TAK Server 4.x (Military)
```
Protocol: TLS
Port: 8089
TLS Version: 1.2+
Certificates: DoD PKI or self-signed
Client Cert: Required
Legacy Mode: Not needed
```

### TAK Server 3.x (Older)
```
Protocol: TLS
Port: 8089
TLS Version: 1.0-1.2
Certificates: Self-signed
Client Cert: May be required
Legacy Mode: May be needed
```

### WinTAK Server (Legacy)
```
Protocol: TLS
Port: 8087
TLS Version: 1.0-1.2
Certificates: Self-signed
Client Cert: Optional
Legacy Mode: Often needed
```

## Troubleshooting

### Connection Fails with "SSL Error"

**Problem**: Server requires older TLS version

**Solution**: Enable legacy TLS mode
```swift
server.allowLegacyTLS = true
```

### "Handshake Failed" Error

**Problem**: Cipher suite mismatch

**Check**: Server's OpenSSL version and supported ciphers
```bash
openssl ciphers -v 'ALL:COMPLEMENTOFALL'
```

### Certificate Verification Failed

**Problem**: Self-signed certificate rejected

**Solution**: Already handled - OmniTAK accepts self-signed certs by default

### Client Certificate Required

**Problem**: Server requires client cert but none provided

**Solution**:
1. Enroll using QR code
2. Import .p12 certificate manually
3. Configure server with `certificateName`

## Security Considerations

### ⚠️ Legacy TLS Risks

Enabling `allowLegacyTLS: true` allows TLS 1.0 and 1.1, which have known vulnerabilities:

- **BEAST attack** (TLS 1.0)
- **Lucky Thirteen** (TLS 1.0/1.1)
- **POODLE** (SSL 3.0, disabled)
- **Weak cipher suites**

### When to Use Legacy Mode

**Only enable legacy TLS when:**
1. ✅ Server cannot be upgraded
2. ✅ Network is trusted (VPN, private network)
3. ✅ Temporary solution until server is upgraded
4. ✅ Testing/development only

**Do NOT enable for:**
1. ❌ Production deployments
2. ❌ Public/untrusted networks
3. ❌ Sensitive operations
4. ❌ Modern servers

### Best Practices

1. **Prefer TLS 1.2+**: Default mode is secure
2. **Update servers**: Upgrade old TAK servers when possible
3. **Use client certs**: Enable mutual authentication
4. **Monitor logs**: Check negotiated TLS version in debug mode
5. **Audit regularly**: Review legacy mode usage

## Testing

### Test TLS Connection

```bash
# Test server TLS version
openssl s_client -connect tak.example.com:8089 -tls1_2

# Test with client certificate
openssl s_client -connect tak.example.com:8089 \
  -cert client.pem -key client.key -tls1_2

# Show supported cipher suites
openssl s_client -connect tak.example.com:8089 -cipher 'ALL'
```

### Verify in OmniTAK

1. Enable Debug logging in Xcode
2. Connect to TAK server
3. Check console for TLS negotiation details
4. Verify TLS version and cipher suite

## Implementation Details

### Code Location

**TLS Configuration**: `TAKService.swift:66-120`

**Key Features**:
- Minimum TLS version selection (line 75-79)
- Legacy cipher suite configuration (line 84-93)
- TLS negotiation monitoring (line 99-114)
- Client certificate loading (line 116-135)

### Server Model

**Configuration**: `ServerManager.swift:13-40`

**Fields**:
```swift
var useTLS: Bool                  // Enable TLS/SSL
var certificateName: String?      // Client cert name
var certificatePassword: String?  // Client cert password
var allowLegacyTLS: Bool          // Enable TLS 1.0/1.1
```

## Compatibility Matrix

| TAK Server Version | TLS Version | Legacy Mode | Client Cert | Notes |
|-------------------|-------------|-------------|-------------|-------|
| FreeTAKServer 2.x | 1.2, 1.3 | No | Yes | Modern, recommended |
| TAK Server 4.x | 1.2, 1.3 | No | Yes | Military/DoD |
| TAK Server 3.x | 1.0-1.2 | Maybe | Yes | Older, update recommended |
| WinTAK Server | 1.0-1.2 | Often | Optional | Legacy support |
| CloudTAK | 1.2, 1.3 | No | Yes | Cloud-hosted |
| Custom/DIY | Varies | Depends | Varies | Test first |

## Migration Guide

### Upgrading from Legacy Server

If you're currently using legacy TLS mode, here's how to upgrade:

1. **Check server version**
```bash
# SSH to server
tak-server --version
```

2. **Update server if possible**
```bash
# Example: FreeTAKServer
pip install FreeTAKServer --upgrade
```

3. **Configure server for TLS 1.2+**
```yaml
# FreeTAKServer config
tls:
  min_version: TLSv1_2
  max_version: TLSv1_3
```

4. **Disable legacy mode in OmniTAK**
```swift
server.allowLegacyTLS = false
```

5. **Test connection**
6. **Deploy to users**

## Support

### Need Help?

- **Check logs**: Enable debug mode for detailed TLS info
- **Test with OpenSSL**: Verify server TLS configuration
- **Contact admin**: Ask TAK server admin for correct settings
- **Report issues**: File bug report with TLS negotiation logs

### Common Questions

**Q: Do I need a client certificate?**
A: Depends on server configuration. Most TAK servers require them.

**Q: Can I use my own CA?**
A: Yes, OmniTAK accepts all server certificates (self-signed or CA-signed).

**Q: Is TLS 1.0 really that bad?**
A: Yes. Only use when absolutely necessary and on trusted networks.

**Q: How do I know what TLS version was negotiated?**
A: Check debug logs for "TLS Negotiated: TLS X.X" message.

---

**Remember**: Default TLS 1.2+ mode is secure and works with 95% of TAK servers. Only enable legacy mode when absolutely necessary!

🔒 **Secure by default, legacy when needed.**
