# OmniTAK Mobile Unit Tests

Regression tests for OmniTAK Mobile networking and connection functionality.

## Test Coverage

### ServerValidatorTests
- Host validation (IPv4, IPv6, hostnames)
- Port validation and mismatch detection
- HTML response detection (regression for GitHub Issue #33)
- Error response analysis (401, 403, 404, 500 errors)
- TLS/SSL warnings

### CSREnrollmentTests
- Configuration URL generation
- CA configuration parsing
- Error handling
- Let's Encrypt vs self-signed certificate handling

### TAKServiceTests
- Connection state management
- Multi-server connection tracking
- CoT event model creation
- Statistics tracking
- Enhanced marker management

### CoTMessageParserTests
- Valid CoT message parsing
- Chat message parsing
- Waypoint parsing
- Fragment extraction from buffers
- Malformed input handling
- Performance benchmarks

### CertificateHandlingTests
- PEM format detection
- Certificate format conversion
- Certificate manager state
- TLS configuration

## Adding Test Target to Xcode

### Option 1: Using Xcode (Recommended)

1. Open `OmniTAKMobile.xcodeproj` in Xcode
2. Go to **File → New → Target**
3. Select **iOS → Unit Testing Bundle**
4. Name it `OmniTAKMobileTests`
5. Set the target to test as `OmniTAKMobile`
6. Delete the auto-generated test file
7. Add existing files from `OmniTAKMobileTests/` folder:
   - ServerValidatorTests.swift
   - CSREnrollmentTests.swift
   - TAKServiceTests.swift
   - CoTMessageParserTests.swift
   - CertificateHandlingTests.swift

### Option 2: Using Script

```bash
cd /Users/jwylie/Projects/omniTAK-Mobile/apps/omnitak
# The test files are already in OmniTAKMobileTests/
# Add them to Xcode project manually or using ruby-xcodeproj gem
```

## Running Tests

### From Xcode
1. Open the project in Xcode
2. Press `Cmd+U` to run all tests
3. Or use **Product → Test** menu

### From Command Line
```bash
cd /Users/jwylie/Projects/omniTAK-Mobile/apps/omnitak
xcodebuild test \
  -project OmniTAKMobile.xcodeproj \
  -scheme OmniTAKMobile \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Test Guidelines

### When to Add Tests

1. **Bug fixes**: Add a regression test that would have caught the bug
2. **New features**: Add tests for the new functionality
3. **Refactoring**: Ensure existing tests still pass

### Test Naming Convention

```swift
func test<Method>_<Scenario>_<ExpectedResult>() {
    // Example: testValidateServerConfig_InvalidPort_ReturnsFalse
}
```

### Regression Tests for Specific Issues

- **GitHub Issue #33**: `testPortMismatch_StreamingPortForEnrollment` - Ensures wrong port detection works
- **GitHub Issue #33**: `testAnalyzeErrorResponse_500ServerError` - Ensures 500 error provides helpful guidance

## Continuous Integration

These tests should be run:
1. On every pull request
2. Before each release
3. After any networking code changes

## Dependencies

Tests use:
- XCTest framework (built-in)
- @testable import OmniTAKMobile (requires debug build)
