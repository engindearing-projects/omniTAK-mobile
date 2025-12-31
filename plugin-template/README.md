# OmniTAK Plugin Template

This is the official template for creating OmniTAK plugins. Use this template to build secure, signed plugins that extend the functionality of the OmniTAK mobile application.

## Two Ways to Develop

###  Local Development (Your Own Signing)
- Use your own Apple Developer account (free or paid)
- Build and test on your own iPhone/iPad
- Perfect for learning and experimentation
- See [Local Development Setup](../docs/LOCAL_DEVELOPMENT_SETUP.md)

###  Official Distribution (OmniTAK Signing)
- Submit your plugin for official distribution
- Signed with OmniTAK's certificate via GitLab CI/CD
- Published to official plugin registry
- Available to all OmniTAK users

## Quick Start - Local Development

### 1. Clone this repository

```bash
git clone https://github.com/engindearing-projects/omniTAK-mobile.git
cd omniTAK-mobile/plugin-template
```

### 2. Customize your plugin

Edit `plugin.json` with your plugin details:

```json
{
  "id": "com.yourcompany.yourplugin",
  "name": "Your Plugin Name",
  "version": "1.0.0",
  "description": "What your plugin does",
  "author": "Your Name",
  "license": "MIT",
  "omnitak_version": ">=1.0.0",
  "type": "ui",
  "platforms": ["ios"],
  "permissions": [
    "cot.read",
    "ui.create"
  ],
  "entry_points": {
    "ios": "YourPlugin"
  }
}
```

### 3. Implement your plugin

Edit `ios/Sources/PluginMain.swift` and implement your plugin logic:

```swift
public class PluginMain: NSObject, OmniTAKPlugin {
    // Implement initialize, activate, deactivate, cleanup
}
```

### 4. Configure local signing (first time only)

```bash
# Copy example configuration
cp .bazelrc.local.example .bazelrc.local

# Edit with your Team ID (find at developer.apple.com)
# Change TEAM123456 to your actual Team ID
nano .bazelrc.local
```

### 5. Build and test locally

```bash
# Build for simulator (no signing needed)
./scripts/build_plugin_ios.sh simulator debug

# Build for your iPhone (uses your Apple Developer certificate)
./scripts/build_plugin_ios.sh device debug

# Run tests
./scripts/test_plugin_ios.sh
```

### 6. Test on your device

Integrate the plugin into the OmniTAK test app and install on your iPhone.

## Quick Start - Official Distribution

Want to publish your plugin to all OmniTAK users?

### 1. Fork the repository

Fork on GitLab to your account.

### 2. Develop your plugin

Follow the local development steps above.

### 3. Create a merge request

```bash
git add .
git commit -m "Add awesome plugin feature"
git push origin your-branch
```

Create a merge request to the main repository.

### 4. Code review

The OmniTAK team will review your plugin for:
- Security (no malicious code)
- Quality (follows best practices)
- Functionality (works as described)

### 5. Automated signing and publishing

Once approved and merged:
- GitLab CI/CD automatically builds with the **official OmniTAK certificate**
- Plugin is signed with `com.engindearing.omnitak.plugin.*` bundle ID
- Published to the official plugin registry

### 6. Create a release tag

```bash
git tag v1.0.0
git push origin v1.0.0
```

Your plugin is now available to all OmniTAK users.
## Plugin Structure

```
my-plugin/
├── plugin.json              # Plugin manifest
├── .gitlab-ci.yml           # CI/CD pipeline (do not modify)
├── ios/                     # iOS implementation
│   ├── BUILD.bazel         # Bazel build config
│   ├── Info.plist          # iOS framework info
│   └── Sources/
│       └── PluginMain.swift # Main plugin class
├── scripts/                 # Build scripts
└── README.md
```

## Permissions

Request only the permissions your plugin needs:

- `network.access` - Make network requests
- `location.read` - Access device location
- `location.write` - Update location data
- `cot.read` - Read CoT messages
- `cot.write` - Send CoT messages
- `map.read` - Access map data
- `map.write` - Add map layers/markers
- `storage.read` - Read local storage
- `storage.write` - Write local storage
- `ui.create` - Create UI components

## Plugin API

### Accessing CoT Messages

```swift
func activate() throws {
    let cotManager = try context.cotManager
    try cotManager?.registerHandler(self)
}

func handleCoTMessage(_ message: CoTMessage) -> CoTHandlerResult {
    // Process CoT message
    return .passthrough
}
```

### Adding Map Markers

```swift
func activate() throws {
    let mapManager = try context.mapManager

    let marker = MapMarker(
        id: "my-marker",
        coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        title: "My Marker"
    )

    try mapManager?.addMarker(marker)
}
```

### Creating UI

```swift
func createPanel() -> UIViewController? {
    let viewController = UIViewController()
    viewController.title = "My Plugin"
    // Add your UI here
    return viewController
}
```

### Making Network Requests

```swift
func activate() async throws {
    let networkManager = try context.networkManager

    let url = URL(string: "https://api.example.com/data").    let (data, response) = try await networkManager?.request(url: url)

    // Process response
}
```

## Development Modes Comparison

| Aspect | Local Development | Official Distribution |
|--------|------------------|----------------------|
| **Signing** | Your Apple Developer cert | OmniTAK official cert |
| **Bundle ID** | `com.yourname.*` | `com.engindearing.omnitak.plugin.*` |
| **Devices** | Only your devices | All OmniTAK users |
| **Distribution** | Manual sharing | Official plugin registry |
| **Approval** | None needed | Code review required |
| **Certificate** | Your account | OmniTAK account |

## Local Development Commands

See [Local Development Setup Guide](../docs/LOCAL_DEVELOPMENT_SETUP.md) for detailed instructions.

### Build Commands

```bash
# Build for simulator (fastest, no signing)
./scripts/build_plugin_ios.sh simulator debug

# Build for your iPhone
./scripts/build_plugin_ios.sh device debug

# Release build
./scripts/build_plugin_ios.sh device release

# Run tests
./scripts/test_plugin_ios.sh

# Validate plugin
./scripts/validate_plugin.py
```

## CI/CD Pipeline

The GitLab CI/CD pipeline automatically:

1. **Validates** - Checks manifest and structure
2. **Builds** - Compiles plugin for iOS
3. **Tests** - Runs unit tests
4. **Signs** - Code signs with OmniTAK developer keys
5. **Packages** - Creates .omniplugin bundle
6. **Publishes** - Uploads to plugin registry (on tags)

### Required CI/CD Variables

These are configured at the GitLab group/project level:

- `IOS_SIGNING_CERT` - Base64-encoded Apple Developer certificate
- `IOS_SIGNING_CERT_PASSWORD` - Certificate password
- `IOS_PROVISIONING_PROFILE` - Base64-encoded provisioning profile
- `PLUGIN_REGISTRY_TOKEN` - Token for publishing to registry

### Pipeline Stages

- **validate** - Runs on all branches
- **build** - Runs on all branches
- **test** - Runs on all branches
- **sign** - Runs on main branch and tags only
- **package** - Runs on main branch and tags only
- **publish** - Runs on tags only

## Code Signing

All plugins are signed with the same Apple Developer certificate as the main OmniTAK app. This ensures:

- Trust chain with the main app
- Consistent bundle ID pattern: `com.engindearing.omnitak.plugin.*`
- App Store compatibility (if applicable)

## Publishing

### Development Builds

Merge to `main` branch to create a development build:

```bash
git checkout main
git merge feature-branch
git push origin main
```

### Release Builds

Create a git tag to publish a release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The plugin will be published to the OmniTAK Plugin Registry and available for installation.

## Support

- Documentation: https://docs.omnitak.io/plugins
- Issues: https://gitlab.com/omnitak/plugin-template/issues
- Community: https://discord.gg/VSUjDddRt3

## License

This template is licensed under MIT. Your plugin can use any license you choose.
