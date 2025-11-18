# Local Development Setup for OmniTAK Plugins

This guide helps you set up your Mac for local OmniTAK plugin development, allowing you to build and install plugins on your own iPhone.

## Prerequisites

### Required Software

1. **macOS** 13.0 or later
2. **Xcode** 15.0 or later (from Mac App Store)
3. **Bazel** 7.0 or later
4. **Git**
5. **Apple Developer Account** (free or paid)

### Install Xcode

```bash
# Install from Mac App Store, then:
sudo xcode-select --install
sudo xcodebuild -license accept
```

### Install Bazel

```bash
# Using Homebrew (recommended)
brew install bazel

# Verify installation
bazel --version
```

### Install Git

```bash
# Using Homebrew
brew install git

# Or use Xcode's git
git --version
```

## Apple Developer Setup

### Option 1: Free Apple Developer Account

You can develop and test on your own devices for FREE:

1. Go to https://developer.apple.com
2. Sign in with your Apple ID
3. Agree to developer agreement
4. You're ready.
**Limitations:**
- 7-day certificate expiration (need to rebuild weekly)
- Limited to 3 devices
- Can't distribute via App Store

**Good for:** Personal development and testing

### Option 2: Paid Apple Developer Program ($99/year)

For serious development or distribution:

1. Enroll at https://developer.apple.com/programs/
2. Pay $99 annual fee
3. Get 1-year certificates
4. Can distribute via App Store

**Good for:** Professional plugin development

## Local Development Configuration

### 1. Clone the Repository

```bash
# Clone the main repo
git clone https://gitlab.com/engindearing/omni-BASE.git
cd omni-BASE

# Or clone just the plugin template
git clone https://gitlab.com/engindearing/omni-BASE.git
cd omni-BASE/plugin-template
```

### 2. Configure Code Signing

Create a local configuration file that won't be committed to git:

```bash
# In the plugin-template directory
cat > .bazelrc.local <<EOF
# Local development code signing
# This file is gitignored and specific to your machine

# Your Apple Developer Team ID (find at developer.apple.com)
build:ios_device --ios_signing_cert_name="Apple Development"
build:ios_device --ios_development_team=YOUR_TEAM_ID_HERE

# Your specific signing identity (optional)
# build:ios_device --ios_signing_cert_name="Apple Development: Your Name (TEAMID)"
EOF
```

### 3. Find Your Team ID

```bash
# List your signing identities
security find-identity -v -p codesigning

# Output will look like:
# 1) ABC123... "Apple Development: Your Name (XXXXXXXXXX)"
#              The XXXXXXXXXX is your Team ID

# Or find it at: https://developer.apple.com/account
# Membership → Team ID
```

### 4. Update Bundle ID (First Time Only)

Edit `plugin.json` to use your own bundle ID:

```json
{
  "id": "com.yourname.myplugin",
  "entry_points": {
    "ios": "MyPlugin"
  }
}
```

Edit `ios/BUILD.bazel`:

```python
ios_framework(
    name = "MyPlugin",
    bundle_id = "com.yourname.myplugin",  # Must match your provisioning
    # ...
)
```

## Building for Local Development

### Build for Simulator (Easiest - No Signing Needed)

```bash
# Build and run in simulator
./scripts/build_plugin_ios.sh simulator debug

# Run in simulator
open -a Simulator
# Then drag the .app to simulator
```

### Build for Physical Device

```bash
# Build for your iPhone/iPad
./scripts/build_plugin_ios.sh device debug

# This uses YOUR Apple Developer certificate
```

### Troubleshooting Signing Errors

#### Error: "No signing identity found"

**Solution:** Make sure you have a valid signing certificate:

```bash
# Open Xcode
open -a Xcode

# Xcode → Settings → Accounts
# Add your Apple ID
# Download Manual Profiles
```

#### Error: "No provisioning profile found"

**Solution:** Create an automatic provisioning profile:

1. Open Xcode
2. Create a new iOS App project
3. Set bundle ID to match your plugin (e.g., `com.yourname.myplugin`)
4. Select your Team
5. Xcode will automatically create provisioning profile
6. Close Xcode
7. Try building again

#### Error: "Bundle ID doesn't match"

**Solution:** Make sure bundle IDs match:

```bash
# Check plugin.json
grep '"id"' plugin.json

# Check ios/BUILD.bazel
grep 'bundle_id' ios/BUILD.bazel

# They should match.```

## Installing on Your iPhone

### Method 1: Using Xcode (Easiest)

```bash
# 1. Build the framework
./scripts/build_plugin_ios.sh device debug

# 2. Create a test app wrapper (we'll create a script for this)
./scripts/install_on_device.sh
```

### Method 2: Manual Installation

For now, you need to integrate the plugin into the main OmniTAK app:

1. Build the plugin framework
2. Copy to OmniTAK app's plugin directory
3. Build and install OmniTAK app with plugin included

We're working on making this easier.
## Local Development Workflow

### 1. Make Changes

Edit your plugin code in `ios/Sources/PluginMain.swift`

### 2. Build and Test

```bash
# Quick iteration: simulator
./scripts/build_plugin_ios.sh simulator debug

# Test on real device
./scripts/build_plugin_ios.sh device debug
```

### 3. Validate

```bash
# Check manifest and structure
./scripts/validate_plugin.py

# Should output:
#  Plugin validation successful.```

### 4. Run Tests

```bash
./scripts/test_plugin_ios.sh
```

### 5. Debug

Use Xcode for debugging:

```bash
# Open in Xcode
open ios/BUILD.bazel

# Or create Xcode project from Bazel
bazel run @rules_xcodeproj//tools/generator -- \
  --workspace_root . \
  --output_path MyPlugin.xcodeproj
```

## Project Structure

```
plugin-template/
├── .bazelrc              # Shared Bazel config
├── .bazelrc.local        # YOUR local config (gitignored)
├── plugin.json           # Plugin manifest
├── ios/
│   ├── BUILD.bazel      # Build configuration
│   ├── Info.plist       # iOS metadata
│   └── Sources/
│       └── PluginMain.swift  # Your plugin code
└── scripts/
    ├── build_plugin_ios.sh   # Build script
    ├── test_plugin_ios.sh    # Test script
    └── validate_plugin.py    # Validation
```

## Git Configuration

The repository is configured to ignore local settings:

```bash
# These files are gitignored:
.bazelrc.local          # Your signing config
bazel-*                 # Build outputs
*.xcodeproj            # Generated Xcode projects
*.xcworkspace          # Generated workspaces
dist/                  # Built artifacts
```

You can commit your plugin code without worrying about your personal signing configuration being shared.

## Sharing Your Plugin

### For Local Testing

Share the built framework:

```bash
# Package your plugin
./scripts/package_plugin.sh

# Share the .omniplugin file
# Other developers can install it on their devices
```

### For Official Distribution

Submit to the official OmniTAK plugin registry:

1. **Fork the repository** on GitLab
2. **Develop your plugin** in your fork
3. **Create a merge request** to the main repository
4. **Code review** by OmniTAK team
5. **Automated signing** with official certificate (via CI/CD)
6. **Published** to official registry

The CI/CD pipeline uses the official OmniTAK signing certificate (stored securely in GitLab CI/CD variables), ensuring all published plugins are signed consistently.

## Development vs Production

| Aspect | Local Development | Official Distribution |
|--------|------------------|----------------------|
| **Signing** | Your Apple Developer cert | OmniTAK official cert |
| **Bundle ID** | `com.yourname.*` | `com.engindearing.omnitak.plugin.*` |
| **Devices** | Only your devices | All OmniTAK users |
| **Distribution** | Manual sharing | Official plugin registry |
| **Updates** | Rebuild yourself | Automatic via registry |
| **Certificate** | Your account | OmniTAK account |
| **Trust** | Self-signed | Official chain of trust |

## Common Issues

### "App Cannot Be Installed"

**Cause:** Certificate mismatch or expired

**Solution:**
```bash
# Check certificate validity
security find-identity -v -p codesigning

# Rebuild with fresh certificate
./scripts/build_plugin_ios.sh device debug
```

### "Untrusted Developer"

**Cause:** First time installing app from your certificate

**Solution:**
1. Go to iPhone Settings
2. General → VPN & Device Management
3. Trust your developer certificate

### "No Space on Device"

**Cause:** Too many builds installed

**Solution:**
```bash
# Clean old builds
bazel clean

# Free up device space
# Delete old versions from iPhone
```

## Next Steps

1. **Tutorial**: Follow the [Plugin Development Guide](../docs/PLUGIN_DEVELOPMENT_GUIDE.md)
2. **Examples**: Check `examples/` directory for sample plugins
3. **API Docs**: Read the [Plugin Architecture](../docs/PLUGIN_ARCHITECTURE.md)
4. **Community**: Join our Discord for help

## Support

- **Documentation**: https://docs.omnitak.io
- **Issues**: https://gitlab.com/engindearing/omni-BASE/issues
- **Discord**: https://discord.gg/omnitak
- **Email**: plugins@omnitak.io

## Security Note

 **Your signing certificate is yours alone.** Never share your:
- Apple Developer certificate (.p12 file)
- Certificate password
- Provisioning profiles
- Team ID (it's okay in public code, but keep account access private)

The official CI/CD signing certificate is separate and managed by the OmniTAK team.
