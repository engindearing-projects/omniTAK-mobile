# Omni TAK Secure Plugin Architecture

## Overview

The Omni TAK plugin system allows third-party developers to extend the application's functionality while maintaining security and code signing consistency with the main application. Plugins are built, signed, and distributed through a secure GitLab CI/CD pipeline.

## Architecture Goals

1. **Security First**: All plugins are validated, sandboxed, and signed with the same developer keys as the main app
2. **iOS Priority**: Initial implementation focuses on iOS with Android support planned
3. **Developer Friendly**: Simple clone-and-customize workflow with automated build pipeline
4. **Code Signing**: Plugins signed with same certificates as main Omni TAK app for trust chain
5. **Isolation**: Plugins run in isolated contexts with defined API boundaries

## Plugin Architecture

### Plugin Types

1. **UI Plugins**: Extend the user interface with new panels, tools, or visualizations
2. **Data Plugins**: Process CoT messages, add data sources, or transform data
3. **Protocol Plugins**: Add support for new network protocols or data formats
4. **Map Plugins**: Add custom map layers, overlays, or rendering features

### Plugin Structure

Each plugin is a separate repository based on a template:

```
omnitak-plugin-template/
├── .gitlab-ci.yml              # CI/CD pipeline configuration
├── plugin.json                 # Plugin manifest
├── ios/                        # iOS-specific plugin code
│   ├── BUILD.bazel            # Bazel build configuration
│   ├── Sources/               # Swift/Objective-C source
│   │   └── PluginMain.swift   # Plugin entry point
│   ├── Resources/             # Assets, strings, etc.
│   └── Info.plist             # iOS plugin info
├── shared/                     # Shared Rust code (optional)
│   ├── Cargo.toml
│   └── src/
│       └── lib.rs
├── typescript/                 # Valdi UI components (optional)
│   ├── package.json
│   └── src/
│       └── PluginUI.tsx
└── README.md
```

### Plugin Manifest (plugin.json)

```json
{
  "id": "com.example.myplugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "description": "Plugin description",
  "author": "Author Name",
  "license": "MIT",
  "omnitak_version": ">=1.0.0",
  "type": "ui",
  "platforms": ["ios", "android"],
  "permissions": [
    "network.access",
    "location.read",
    "cot.read",
    "cot.write"
  ],
  "entry_points": {
    "ios": "PluginMain",
    "android": "com.example.myplugin.PluginMain"
  },
  "dependencies": []
}
```

## Security Model

### Code Signing

1. **Developer Keys**: Plugins are signed with the same Apple Development/Distribution certificates as the main app
2. **Bundle ID Pattern**: Plugins use `com.engindearing.omnitak.plugin.<plugin-id>` pattern
3. **Entitlements**: Plugins inherit a subset of main app entitlements based on requested permissions
4. **Provisioning**: GitLab CI/CD has access to provisioning profiles for plugin signing

### Permission System

Plugins must declare required permissions in `plugin.json`:

- `network.access`: Make network requests
- `location.read`: Access device location
- `location.write`: Update location data
- `cot.read`: Read CoT messages
- `cot.write`: Send CoT messages
- `map.read`: Access map data
- `map.write`: Add map layers/markers
- `storage.read`: Read local storage
- `storage.write`: Write local storage
- `ui.create`: Create UI components

### Sandboxing

1. **API Boundary**: Plugins interact with the app only through defined APIs
2. **Resource Limits**: CPU, memory, and network usage monitored and limited
3. **Data Isolation**: Plugins have isolated storage containers
4. **Thread Safety**: Plugin code runs on dedicated threads with main thread callbacks

## Plugin API

### Swift API (iOS)

```swift
// Plugin protocol that all plugins must implement
public protocol OmniTAKPlugin {
    var manifest: PluginManifest { get }

    func initialize(context: PluginContext) throws
    func activate() throws
    func deactivate() throws
    func cleanup() throws
}

// Plugin context provides access to app APIs
public class PluginContext {
    public let permissions: Set<PluginPermission>
    public let storage: PluginStorage
    public let logger: PluginLogger

    // Available only with appropriate permissions
    public var cotManager: CoTManager? { get }
    public var mapManager: MapManager? { get }
    public var networkManager: NetworkManager? { get }
    public var locationManager: LocationManager? { get }
}

// CoT message handling
public protocol CoTHandler {
    func handleCoTMessage(_ message: CoTMessage) -> CoTHandlerResult
}

// UI extension points
public protocol UIProvider {
    func createToolbarItem() -> UIView?
    func createPanel() -> UIViewController?
    func createMapOverlay() -> MapOverlay?
}
```

### TypeScript API (Valdi)

```typescript
// Plugin UI definition using Valdi
export interface OmniTAKPluginUI {
  manifest: PluginManifest;

  // Create UI components
  createPanel?(): VNode;
  createToolbarButton?(): VNode;
  createMapLayer?(): MapLayer;

  // Lifecycle hooks
  onActivate?(): Promise<void>;
  onDeactivate?(): Promise<void>;

  // Event handlers
  onCoTMessage?(message: CoTMessage): void;
  onMapEvent?(event: MapEvent): void;
}
```

### Rust FFI API (Optional for performance-critical code)

```rust
// Rust plugin interface for native performance
#[repr(C)]
pub struct PluginFFI {
    pub initialize: extern "C" fn(*mut PluginContext) -> i32,
    pub process_cot: extern "C" fn(*const u8, usize) -> i32,
    pub cleanup: extern "C" fn() -> i32,
}
```

## GitLab CI/CD Pipeline

### Pipeline Stages

1. **Validate**: Verify plugin.json, check permissions, validate code
2. **Build**: Compile plugin for iOS (and Android in future)
3. **Test**: Run unit tests and integration tests
4. **Sign**: Code sign with main app's developer certificates
5. **Package**: Create distributable plugin bundle
6. **Publish**: Upload to plugin registry (internal GitLab package registry)

### GitLab CI Template (.gitlab-ci.yml)

```yaml
include:
  - project: 'omnitak/plugin-build-template'
    file: '/ios-plugin-build.yml'

variables:
  PLUGIN_ID: "com.example.myplugin"
  IOS_MIN_VERSION: "14.0"

stages:
  - validate
  - build
  - test
  - sign
  - package
  - publish

validate:
  extends: .plugin-validate-base
  script:
    - ./scripts/validate_plugin.sh

build_ios:
  extends: .plugin-build-ios-base
  script:
    - ./scripts/build_plugin_ios.sh

test_ios:
  extends: .plugin-test-ios-base
  script:
    - ./scripts/test_plugin_ios.sh

sign_ios:
  extends: .plugin-sign-ios-base
  script:
    - ./scripts/sign_plugin_ios.sh
  only:
    - main
    - tags

package:
  extends: .plugin-package-base
  script:
    - ./scripts/package_plugin.sh
  artifacts:
    paths:
      - dist/*.omniplugin

publish:
  extends: .plugin-publish-base
  script:
    - ./scripts/publish_plugin.sh
  only:
    - tags
```

### Secure Variables (GitLab CI/CD Settings)

These are configured at the GitLab project/group level:

- `IOS_SIGNING_CERT`: Base64-encoded Apple Developer certificate
- `IOS_SIGNING_CERT_PASSWORD`: Certificate password
- `IOS_PROVISIONING_PROFILE`: Base64-encoded provisioning profile
- `PLUGIN_REGISTRY_TOKEN`: Token for publishing to plugin registry
- `CODE_SIGNING_IDENTITY`: "Apple Development" or "Apple Distribution"

## Plugin Distribution

### Plugin Bundle Format (.omniplugin)

A plugin bundle is a ZIP archive with this structure:

```
MyPlugin.omniplugin/
├── manifest.json              # Plugin manifest
├── ios/
│   ├── MyPlugin.framework     # Signed iOS framework
│   └── entitlements.plist     # Plugin entitlements
├── android/                   # (Future)
│   └── plugin.aar
├── assets/                    # Icons, images, etc.
│   └── icon.png
└── signature.json             # Cryptographic signature
```

### Plugin Registry

- **Location**: Private GitLab Package Registry
- **Authentication**: Token-based access
- **Versioning**: Semantic versioning (1.0.0, 1.0.1, etc.)
- **Metadata**: Searchable by name, author, category, tags

### Plugin Installation

1. User browses plugin registry in-app
2. User selects plugin to install
3. App downloads .omniplugin bundle
4. App validates signature and manifest
5. App checks permissions and prompts user
6. App installs plugin to isolated container
7. User can enable/disable plugin in settings

## Plugin Development Workflow

### 1. Clone Template

```bash
git clone https://github.com/engindearing-projects/omniTAK-mobile/tree/main/plugin-template.git my-plugin
cd my-plugin
```

### 2. Customize Plugin

- Edit `plugin.json` with plugin details
- Implement plugin code in `ios/Sources/PluginMain.swift`
- Add UI components in `typescript/src/` if needed
- Add Rust code in `shared/src/` if needed

### 3. Test Locally

```bash
# Build plugin
./scripts/build_plugin.sh ios debug

# Run tests
./scripts/test_plugin.sh ios

# Install to test app
./scripts/install_plugin.sh ios
```

### 4. Push to GitLab

```bash
git add .
git commit -m "Initial plugin implementation"
git push origin main
```

### 5. CI/CD Builds and Signs

- GitLab CI/CD automatically builds plugin
- Plugin is signed with Omni TAK developer keys
- Signed plugin is available as artifact

### 6. Publish Release

```bash
git tag v1.0.0
git push origin v1.0.0
```

- CI/CD publishes to plugin registry
- Plugin is now available for installation

## Implementation Phases

### Phase 1: iOS Foundation (Current)

- [ ] Create plugin template repository
- [ ] Implement Swift plugin API
- [ ] Build plugin loader and validator
- [ ] Set up GitLab CI/CD template
- [ ] Configure code signing in CI/CD
- [ ] Create example plugin

### Phase 2: Plugin Registry

- [ ] Set up GitLab Package Registry
- [ ] Implement plugin submission workflow
- [ ] Create plugin browser UI
- [ ] Implement plugin installation
- [ ] Add plugin management settings

### Phase 3: Advanced Features

- [ ] Valdi TypeScript UI support
- [ ] Rust FFI plugin support
- [ ] Plugin update mechanism
- [ ] Plugin marketplace UI
- [ ] Plugin analytics and monitoring

### Phase 4: Android Support

- [ ] Port plugin API to Android
- [ ] Create Android build pipeline
- [ ] Add Android code signing
- [ ] Cross-platform plugin support

## Security Considerations

1. **Code Review**: All plugins should be reviewed before signing
2. **Sandboxing**: Plugins cannot access arbitrary system resources
3. **Permissions**: Principle of least privilege - request minimum permissions
4. **Updates**: Plugins can be remotely disabled if security issues found
5. **Validation**: Plugin signatures verified on every launch
6. **Audit Logging**: All plugin actions logged for security audit

## References

- Bazel iOS build: `/path/to/omniTAK-mobile/.bazelrc.ios`
- Main app bundle ID: `com.engindearing.omnitak.mobile`
- Build scripts: `/path/to/omniTAK-mobile/scripts/build_ios.sh`
- Native bridge: `/path/to/omniTAK-mobile/modules/omnitak_mobile/ios/native/`
