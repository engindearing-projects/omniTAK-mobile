# OmniTAK Mobile Dependencies

This document lists all external dependencies for OmniTAK Mobile, their versions, and upgrade instructions.

## Table of Contents

- [Overview](#overview)
- [Android Dependencies](#android-dependencies)
- [iOS Dependencies](#ios-dependencies)
- [JavaScript/TypeScript Dependencies](#javascripttypescript-dependencies)
- [C++ Libraries](#c-libraries)
- [Version Management](#version-management)
- [Upgrade Instructions](#upgrade-instructions)
- [Troubleshooting](#troubleshooting)

## Overview

OmniTAK Mobile uses the following external dependencies:

- **MapLibre** for mobile mapping capabilities
- **milsymbol** for military symbology rendering
- **Geospatial libraries** for coordinate transformations and spatial operations
- **Storage libraries** for offline map tile caching

All dependencies are managed through Bazel's MODULE.bazel and WORKSPACE files, with platform-specific configurations.

## Android Dependencies

### MapLibre Android SDK

**Version:** 11.5.2
**Repository:** Maven Central
**License:** BSD-2-Clause

MapLibre Android SDK provides native Android mapping functionality.

```gradle
org.maplibre.gl:android-sdk:11.5.2
org.maplibre.gl:android-sdk-turf:11.5.2
```

**Features:**
- Vector and raster map rendering
- Custom marker support
- Gesture handling
- Offline map tiles
- Style customization

**Documentation:** https://maplibre.org/maplibre-native/android/

### Geospatial Libraries

#### JTS Topology Suite
**Version:** 1.19.0
**Repository:** Maven Central
**License:** EPL-2.0

Provides geometry operations and spatial predicates.

```gradle
org.locationtech.jts:jts-core:1.19.0
```

#### GeoPackage Android
**Version:** 6.7.4
**Repository:** Maven Central
**License:** MIT

OGC GeoPackage support for offline geospatial data.

```gradle
mil.nga.geopackage:geopackage-android:6.7.4
```

### Network and Caching

#### OkHttp
**Version:** 4.12.0
**Repository:** Maven Central
**License:** Apache 2.0

HTTP client for network requests and caching.

```gradle
com.squareup.okhttp3:okhttp:4.12.0
com.squareup.okio:okio:3.6.0
```

### Image Loading

#### Glide
**Version:** 4.16.0
**Repository:** Maven Central
**License:** BSD, MIT, Apache 2.0

Image loading and caching library for marker icons.

```gradle
com.github.bumptech.glide:glide:4.16.0
```

### Kotlin Support

#### Kotlin Coroutines
**Version:** 1.7.3
**Repository:** Maven Central
**License:** Apache 2.0

Asynchronous programming support.

```gradle
org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3
org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3
```

### Location Services

#### Google Play Services Location
**Version:** 21.0.1
**Repository:** Google Maven
**License:** Android Software Development Kit License

GPS and location tracking.

```gradle
com.google.android.gms:play-services-location:21.0.1
```

## iOS Dependencies

### MapLibre GL Native

**Version:** 6.8.0
**Repository:** GitHub
**License:** BSD-2-Clause

MapLibre GL Native provides iOS mapping functionality.

**Integration Methods:**

1. **Source Build** (via http_archive):
   ```python
   http_archive(
       name = "maplibre_gl_native_ios",
       url = "https://github.com/maplibre/maplibre-gl-native/archive/refs/tags/ios-v6.8.0.tar.gz",
   )
   ```

2. **XCFramework** (pre-built binary):
   ```python
   http_archive(
       name = "maplibre_gl_native_ios_xcframework",
       url = "https://github.com/maplibre/maplibre-native-distribution/releases/download/ios-v6.8.0/Mapbox-6.8.0.zip",
   )
   ```

**Features:**
- Vector map rendering using Metal
- Custom annotations
- Offline map support
- Camera animations
- GeoJSON support

**Documentation:** https://maplibre.org/maplibre-native/ios/

**Minimum Requirements:**
- iOS 12.0+
- Xcode 14.0+
- Swift 5.5+

## JavaScript/TypeScript Dependencies

### milsymbol

**Version:** 2.2.0
**Package:** npm
**License:** MIT

Military symbol rendering library supporting MIL-STD-2525 and APP-6.

```json
{
  "dependencies": {
    "milsymbol": "^2.2.0"
  }
}
```

**Features:**
- MIL-STD-2525C/D support
- APP-6B/C/D support
- SVG and Canvas rendering
- Modifiers and text labels

**Documentation:** https://github.com/spatialillusions/milsymbol

### maplibre-gl

**Version:** 4.7.1
**Package:** npm
**License:** BSD-3-Clause

JavaScript mapping library for web components and TypeScript bindings.

```json
{
  "dependencies": {
    "maplibre-gl": "^4.7.1"
  }
}
```

**Documentation:** https://maplibre.org/maplibre-gl-js/docs/

### Turf.js

**Version:** 7.1.0
**Package:** npm
**License:** MIT

Geospatial analysis library for JavaScript.

```json
{
  "dependencies": {
    "@turf/turf": "^7.1.0"
  }
}
```

**Features:**
- Distance calculations
- Buffer operations
- Spatial analysis
- Coordinate transformations

**Documentation:** https://turfjs.org/

### Vector Tiles

**Packages:**
- `@mapbox/vector-tile` (2.0.3) - Vector tile parsing
- `pbf` (4.0.1) - Protocol buffer encoding/decoding
- `geojson` (0.5.0) - GeoJSON utilities

```json
{
  "dependencies": {
    "@mapbox/vector-tile": "^2.0.3",
    "pbf": "^4.0.1",
    "geojson": "^0.5.0"
  }
}
```

## C++ Libraries

### RapidJSON

**Version:** 1.1.0
**Repository:** GitHub
**License:** MIT

Fast JSON parsing and generation for GeoJSON processing.

```python
http_archive(
    name = "rapidjson",
    url = "https://github.com/Tencent/rapidjson/archive/refs/tags/v1.1.0.tar.gz",
)
```

**Documentation:** https://rapidjson.org/

### Mapbox Geometry

**Version:** 2.0.3
**Repository:** GitHub
**License:** ISC

Header-only C++ library for geospatial primitives.

```python
http_archive(
    name = "mapbox_geometry",
    url = "https://github.com/mapbox/geometry.hpp/archive/refs/tags/v2.0.3.tar.gz",
)
```

**Features:**
- Point, LineString, Polygon types
- MultiGeometry support
- GeoJSON compatibility

### Mapbox Variant

**Version:** 2.0.0
**Repository:** GitHub
**License:** BSD

Type-safe variant implementation (required by Mapbox Geometry).

```python
http_archive(
    name = "mapbox_variant",
    url = "https://github.com/mapbox/variant/archive/refs/tags/v2.0.0.tar.gz",
)
```

### Earcut

**Version:** 2.2.4
**Repository:** GitHub
**License:** ISC

Polygon triangulation library for rendering.

```python
http_archive(
    name = "earcut",
    url = "https://github.com/mapbox/earcut.hpp/archive/refs/tags/v2.2.4.tar.gz",
)
```

**Features:**
- Fast polygon triangulation
- Supports holes
- Header-only implementation

### SQLite

**Version:** 3.45.1
**Repository:** sqlite.org
**License:** Public Domain

Database engine for offline map tile storage.

```python
http_archive(
    name = "sqlite",
    url = "https://www.sqlite.org/2024/sqlite-amalgamation-3450100.zip",
)
```

**Documentation:** https://www.sqlite.org/docs.html

## Version Management

### Semantic Versioning

All dependencies follow semantic versioning where possible:
- **Major version:** Breaking changes
- **Minor version:** New features, backward compatible
- **Patch version:** Bug fixes

### Version Pinning

Dependencies are pinned to specific versions in:
- `MODULE.bazel` for Bazel modules and Maven artifacts
- `package.json` for NPM packages
- `bzl/omnitak_dependencies.bzl` for custom http_archive dependencies

### Version Conflict Resolution

Maven dependencies use `version_conflict_policy = "pinned"` to ensure consistent versions across the dependency tree.

## Upgrade Instructions

### Prerequisites

1. Review release notes for breaking changes
2. Update local development environment
3. Run full test suite after upgrade

### Upgrading Android Dependencies

1. **Update MODULE.bazel:**
   ```python
   maven.install(
       name = "omnitak_android_mvn",
       artifacts = [
           "org.maplibre.gl:android-sdk:NEW_VERSION",
           # ... other dependencies
       ],
   )
   ```

2. **Verify compatibility:**
   ```bash
   bazel query "deps(//modules/omnitak_mobile/android:omnitak_android)" | grep maplibre
   ```

3. **Clean build:**
   ```bash
   ./scripts/clean_build.sh --all //modules/omnitak_mobile/android:omnitak_android
   ```

### Upgrading iOS Dependencies

1. **Update version in MODULE.bazel:**
   ```python
   MAPLIBRE_GL_NATIVE_VERSION = "NEW_VERSION"
   ```

2. **Update SHA256 checksum:**
   ```bash
   # Download new version
   curl -L https://github.com/maplibre/maplibre-gl-native/archive/refs/tags/ios-vNEW_VERSION.tar.gz -o maplibre.tar.gz

   # Calculate checksum
   shasum -a 256 maplibre.tar.gz
   ```

3. **Update http_archive:**
   ```python
   http_archive(
       name = "maplibre_gl_native_ios",
       url = "...",
       integrity = "sha256-NEW_CHECKSUM_HERE",
   )
   ```

4. **Clean build:**
   ```bash
   ./scripts/clean_build.sh --all //modules/omnitak_mobile/ios:omnitak_ios
   ```

### Upgrading NPM Dependencies

1. **Update package.json:**
   ```json
   {
     "dependencies": {
       "milsymbol": "^NEW_VERSION"
     }
   }
   ```

2. **Update package-lock.json:**
   ```bash
   npm update milsymbol
   ```

3. **Verify build:**
   ```bash
   npm install
   bazel build //modules/omnitak_mobile:omnitak_mobile
   ```

### Upgrading C++ Libraries

1. **Update bzl/omnitak_dependencies.bzl:**
   ```python
   http_archive(
       name = "rapidjson",
       url = "https://github.com/Tencent/rapidjson/archive/refs/tags/vNEW_VERSION.tar.gz",
       strip_prefix = "rapidjson-NEW_VERSION",
       integrity = "sha256-NEW_CHECKSUM",
   )
   ```

2. **Update MODULE.bazel if referenced there**

3. **Verify BUILD files are compatible**

4. **Clean build:**
   ```bash
   ./scripts/clean_build.sh --external
   ```

## Troubleshooting

### Dependency Resolution Failures

**Problem:** Maven dependency conflicts

**Solution:**
```bash
# Check dependency tree
bazel query "deps(//modules/omnitak_mobile:omnitak_mobile)" --output=graph

# Force resolution with pinned versions
# Update MODULE.bazel with explicit version_conflict_policy
```

### Missing Build Files

**Problem:** `BUILD file not found for external dependency`

**Solution:**
1. Check `third-party/` directory for custom BUILD files
2. Create BUILD file if needed:
   ```bash
   mkdir -p third-party/library_name
   # Create library_name.BUILD with cc_library rules
   ```

### Checksum Mismatches

**Problem:** `Checksum mismatch for downloaded file`

**Solution:**
```bash
# Recalculate checksum
curl -L DOWNLOAD_URL -o file.tar.gz
shasum -a 256 file.tar.gz

# Update integrity in MODULE.bazel or dependencies.bzl
```

### iOS Build Errors

**Problem:** `framework not found MapLibre`

**Solution:**
1. Verify Xcode command line tools:
   ```bash
   xcode-select --install
   ```

2. Clean and rebuild:
   ```bash
   ./scripts/clean_build.sh --all //modules/omnitak_mobile/ios:omnitak_ios
   ```

3. Check XCFramework path in BUILD file

### Android Build Errors

**Problem:** `Could not resolve org.maplibre.gl:android-sdk`

**Solution:**
1. Verify Maven repositories are accessible:
   ```bash
   curl -I https://repo1.maven.org/maven2/
   curl -I https://maven.google.com/
   ```

2. Clear Maven cache:
   ```bash
   rm -rf ~/.m2/repository/org/maplibre
   ```

3. Rebuild with external cache clean:
   ```bash
   ./scripts/clean_build.sh --external
   ```

### NPM Install Failures

**Problem:** `npm ERR! Could not resolve dependency`

**Solution:**
```bash
# Clear NPM cache
npm cache clean --force

# Remove node_modules and package-lock.json
rm -rf node_modules package-lock.json

# Reinstall
npm install
```

## Verification Commands

### Verify All Dependencies

```bash
# Setup and verify dependencies
./scripts/setup_dependencies.sh

# Build all targets
bazel build //modules/omnitak_mobile/...

# Run tests
bazel test //modules/omnitak_mobile/...
```

### Check Dependency Versions

```bash
# Maven dependencies
bazel query --output=build //modules/omnitak_mobile:omnitak_mobile | grep maven

# NPM packages
npm list --depth=0

# Bazel external repositories
bazel query @... 2>/dev/null | grep -E "(maplibre|milsymbol|rapidjson)"
```

### Verify Platform Requirements

```bash
# Android
echo $ANDROID_HOME
ls $ANDROID_HOME/platforms/android-35
ls $ANDROID_HOME/build-tools/34.0.0

# iOS (macOS only)
xcodebuild -version
xcode-select -p
```

## References

- [Bazel External Dependencies](https://bazel.build/external/overview)
- [rules_jvm_external](https://github.com/bazelbuild/rules_jvm_external)
- [MapLibre Documentation](https://maplibre.org/projects/)
- [OmniTAK Mobile BUILD_GUIDE.md](/modules/omnitak_mobile/BUILD_GUIDE.md)

## License Information

See individual dependency links above for specific license information. All dependencies are compatible with OmniTAK Mobile's licensing requirements.

## Support

For dependency-related issues:
1. Check this documentation
2. Review build logs: `bazel build --verbose_failures ...`
3. Consult the [BUILD_GUIDE.md](/modules/omnitak_mobile/BUILD_GUIDE.md)
4. File an issue with dependency version, platform, and error message
