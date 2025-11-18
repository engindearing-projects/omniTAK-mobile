# OmniTAK Mobile - Bazel Build Configuration Guide

## Overview

This document explains the Bazel build configuration for the OmniTAK Mobile module, which integrates native iOS (Swift + Objective-C) and Android (Kotlin + JNI) code with the Valdi framework.

## Architecture

The OmniTAK Mobile module consists of multiple layers:

```
┌─────────────────────────────────────────┐
│     TypeScript (src/valdi/omnitak/)     │  ← Valdi Module
├─────────────────────────────────────────┤
│  iOS (Swift/ObjC)  │  Android (Kotlin)  │  ← Platform Bridges
├────────────────────┼────────────────────┤
│   MapLibre ObjC    │   MapLibre Kotlin  │  ← Map Rendering
├────────────────────┼────────────────────┤
│   XCFramework      │      JNI C++       │  ← FFI Layer
├────────────────────┴────────────────────┤
│        Rust Core (libomnitak_mobile)    │  ← Business Logic
└─────────────────────────────────────────┘
```

## BUILD.bazel Structure

### 1. iOS Native Libraries

#### XCFramework Import

```python
cc_import(
    name = "omnitak_mobile_xcframework_device",
    static_library = "ios/native/OmniTAKMobile.xcframework/ios-arm64/libomnitak_mobile.a",
)

cc_import(
    name = "omnitak_mobile_xcframework_simulator",
    static_library = "ios/native/OmniTAKMobile.xcframework/ios-arm64_x86_64-simulator/libomnitak_mobile.a",
)

alias(
    name = "omnitak_mobile_xcframework",
    actual = select({
        "@platforms//os:ios": ":omnitak_mobile_xcframework_device",
        "//conditions:default": ":omnitak_mobile_xcframework_simulator",
    }),
)
```

**Purpose**: Import the pre-built Rust static library compiled for iOS architectures.

**Architectures Supported**:
- `ios-arm64`: Physical iPhone/iPad devices
- `ios-arm64_x86_64-simulator`: Xcode simulator (both Intel and Apple Silicon Macs)

**How to Rebuild**:
```bash
cd /Users/iesouskurios/Downloads/omni-TAK/crates/omnitak-mobile
./build_ios.sh
```

#### Swift Native Bridge

```python
swift_library(
    name = "ios_native_bridge",
    srcs = ["ios/native/OmniTAKNativeBridge.swift"],
    module_name = "OmniTAKNativeBridge",
    deps = [
        ":omnitak_mobile_xcframework",
        "@valdi//valdi_core:valdi_core_swift_marshaller",
    ],
)
```

**Purpose**: Provides Swift wrapper around Rust FFI functions.

**Key Functions**:
- `OmniTAKNativeBridge.parseCot(xmlString:)` → Parse CoT XML
- `OmniTAKNativeBridge.connectTAK(host:port:)` → Connect to TAK server
- `OmniTAKNativeBridge.sendCot(cotData:)` → Send CoT message

**File**: `ios/native/OmniTAKNativeBridge.swift`

#### Objective-C MapLibre Wrapper

```python
client_objc_library(
    name = "ios_maplibre_wrapper",
    srcs = ["ios/maplibre/SCMapLibreMapView.m"],
    hdrs = ["ios/maplibre/SCMapLibreMapView.h"],
    sdk_frameworks = [
        "UIKit",
        "CoreLocation",
        "QuartzCore",
    ],
    deps = [
        "@valdi//valdi_core:valdi_core_objc",
    ],
)
```

**Purpose**: Integrates MapLibre GL Native with Valdi's custom view system.

**Custom View**: `SCMapLibreMapView` extends `SCValdiView`

**Valdi Attributes**:
- `options`: Map configuration (style URL, initial position)
- `markers`: Array of marker data (coordinates, icons, labels)
- `camera`: Camera position (center, zoom, bearing, pitch)
- Callbacks: `onMapReady`, `onMarkerTap`, `onMapTap`, `onCameraChanged`

**Files**:
- `ios/maplibre/SCMapLibreMapView.h`
- `ios/maplibre/SCMapLibreMapView.m`

### 2. Android Native Libraries

#### JNI C++ Bridge

```python
cc_library(
    name = "android_jni_bridge",
    srcs = ["android/native/omnitak_jni.cpp"],
    hdrs = glob(["android/native/include/**/*.h"]),
    copts = [
        "-fno-exceptions",
        "-DANDROID",
        "-Os",
    ],
    linkopts = [
        "-llog",      # Android logging
        "-landroid",  # Android API
    ],
    alwayslink = True,
)
```

**Purpose**: JNI bridge between Kotlin and Rust FFI.

**Key JNI Functions**:
- `Java_com_engindearing_omnitak_OmniTAKNativeBridge_parseCot`
- `Java_com_engindearing_omnitak_OmniTAKNativeBridge_connectTAK`
- `Java_com_engindearing_omnitak_OmniTAKNativeBridge_sendCot`

**Features**:
- Thread-safe callback management
- JNI string conversion utilities
- Android logging integration

**Files**:
- `android/native/omnitak_jni.cpp`
- `android/native/include/omnitak_jni.h`

#### Kotlin Native Bridge

```python
kt_android_library(
    name = "android_native_bridge",
    srcs = ["android/native/OmniTAKNativeBridge.kt"],
    deps = [
        "@maven//:androidx_core_core_ktx",
        "@maven//:org_jetbrains_kotlin_kotlin_stdlib",
    ],
)
```

**Purpose**: Kotlin wrapper for JNI functions, provides high-level API.

**Key Classes**:
- `OmniTAKNativeBridge`: Main bridge interface
- `CoTMessage`: Data class for CoT messages
- `TAKConnection`: Connection state management

**File**: `android/native/OmniTAKNativeBridge.kt`

#### Kotlin MapLibre Wrapper

```python
kt_android_library(
    name = "android_maplibre_wrapper",
    srcs = glob(["android/maplibre/**/*.kt"]),
    deps = [
        "@maven//:androidx_core_core_ktx",
        "@maven//:androidx_appcompat_appcompat",
        "@maven//:org_jetbrains_kotlin_kotlin_stdlib",
    ],
)
```

**Purpose**: Integrates MapLibre GL Native with Valdi's custom view system.

**Custom View**: `MapLibreMapView` extends `ValdiView`

**Files**:
- `android/maplibre/MapLibreMapView.kt`
- `android/maplibre/MapLibreMapViewAttributesBinder.kt`

### 3. Main Valdi Module

```python
valdi_module(
    name = "omnitak_mobile",
    srcs = glob(["src/**/*.ts", "src/**/*.tsx"]) + ["tsconfig.json"],

    # Platform configurations
    ios_module_name = "SCCOmniTAKMobile",
    ios_output_target = "release",
    android_output_target = "release",

    # Dependencies
    deps = [
        "//src/valdi_modules/src/valdi/valdi_core",
        "//src/valdi_modules/src/valdi/valdi_tsx",
    ],

    # iOS-specific native dependencies
    ios_deps = [
        ":ios_maplibre_wrapper",
        ":ios_native_bridge",
    ],

    # Android-specific native dependencies
    android_deps = [
        ":android_native_bridge",
        ":android_maplibre_wrapper",
        ":android_jni_bridge",
    ],

    # Enable both Objective-C and Swift codegen
    ios_language = "objc, swift",
)
```

**Purpose**: Main entry point that compiles TypeScript and links all native code.

**Generated Targets**:
- `omnitak_mobile` - Main module target
- `omnitak_mobile_kt` - Android Kotlin library
- `omnitak_mobile_objc` - iOS Objective-C library
- `omnitak_mobile_swift` - iOS Swift library
- `SCCOmniTAKMobile` - iOS module alias
- `SCCOmniTAKMobileTypes` - iOS API types

## Build Commands

### Build for iOS

```bash
# Build the entire module for iOS
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --platforms=@build_bazel_rules_apple//apple:ios_arm64

# Build just the iOS libraries
bazel build //modules/omnitak_mobile:ios_maplibre_wrapper \
  --platforms=@build_bazel_rules_apple//apple:ios_arm64

# Build for iOS Simulator
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --platforms=@build_bazel_rules_apple//apple:ios_sim_arm64
```

### Build for Android

```bash
# Build the entire module for Android
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --platforms=@snap_platforms//platforms:android_arm64

# Build just the Android libraries
bazel build //modules/omnitak_mobile:android_jni_bridge
bazel build //modules/omnitak_mobile:android_native_bridge
bazel build //modules/omnitak_mobile:android_maplibre_wrapper
```

### Query Targets

```bash
# List all targets in the module
bazel query //modules/omnitak_mobile:all

# Show dependency graph
bazel query --output=graph //modules/omnitak_mobile:omnitak_mobile

# Show dependencies of iOS native bridge
bazel query 'deps(//modules/omnitak_mobile:ios_native_bridge)'
```

## Adding New Native Dependencies

### iOS

1. **Add Swift/Objective-C source files**:
   ```bash
   # Place files in appropriate directory
   ios/native/      # Swift bridges
   ios/maplibre/    # MapLibre wrappers
   ```

2. **Update BUILD.bazel**:
   ```python
   client_objc_library(
       name = "new_ios_lib",
       srcs = ["ios/path/MyFile.m"],
       hdrs = ["ios/path/MyFile.h"],
       deps = [
           "@valdi//valdi_core:valdi_core_objc",
       ],
   )
   ```

3. **Add to `ios_deps`**:
   ```python
   valdi_module(
       name = "omnitak_mobile",
       ios_deps = [
           ":ios_maplibre_wrapper",
           ":ios_native_bridge",
           ":new_ios_lib",  # ← Add here
       ],
   )
   ```

### Android

1. **Add Kotlin/Java source files**:
   ```bash
   # Place files in appropriate directory
   android/native/     # Kotlin bridges
   android/maplibre/   # MapLibre wrappers
   ```

2. **Update BUILD.bazel**:
   ```python
   kt_android_library(
       name = "new_android_lib",
       srcs = ["android/path/MyClass.kt"],
       deps = [
           "@maven//:androidx_core_core_ktx",
       ],
   )
   ```

3. **Add to `android_deps`**:
   ```python
   valdi_module(
       name = "omnitak_mobile",
       android_deps = [
           ":android_native_bridge",
           ":android_maplibre_wrapper",
           ":new_android_lib",  # ← Add here
       ],
   )
   ```

### Adding C++ JNI Code

1. **Create `.cpp` and `.h` files**:
   ```bash
   android/native/my_feature_jni.cpp
   android/native/include/my_feature_jni.h
   ```

2. **Add to JNI bridge**:
   ```python
   cc_library(
       name = "android_jni_bridge",
       srcs = [
           "android/native/omnitak_jni.cpp",
           "android/native/my_feature_jni.cpp",  # ← Add here
       ],
       hdrs = glob(["android/native/include/**/*.h"]),
   )
   ```

## Linking External Frameworks

### iOS: MapLibre via CocoaPods

**Option 1: Manual Framework Import**
```python
objc_import(
    name = "maplibre_framework",
    framework_imports = glob(["ios/Frameworks/MapLibre.framework/**"]),
)

client_objc_library(
    name = "ios_maplibre_wrapper",
    deps = [
        ":maplibre_framework",
        "@valdi//valdi_core:valdi_core_objc",
    ],
)
```

**Option 2: CocoaPods Integration** (if supported by Valdi)
```python
# In WORKSPACE or MODULE.bazel
load("@rules_pods//pods:defs.bzl", "pods")

pods(
    name = "ios_pods",
    podfile = "//modules/omnitak_mobile/ios:Podfile",
)
```

### Android: MapLibre via Maven

**Update WORKSPACE**:
```python
load("@rules_jvm_external//:defs.bzl", "maven_install")

maven_install(
    name = "maven",
    artifacts = [
        "androidx.core:core-ktx:1.12.0",
        "org.maplibre.gl:android-sdk:11.8.0",
        "org.maplibre.gl:android-plugin-annotation-v9:3.0.0",
    ],
    repositories = [
        "https://maven.google.com",
        "https://repo1.maven.org/maven2",
    ],
)
```

**Use in BUILD.bazel**:
```python
kt_android_library(
    name = "android_maplibre_wrapper",
    deps = [
        "@maven//:org_maplibre_gl_android_sdk",
        "@maven//:org_maplibre_gl_android_plugin_annotation_v9",
    ],
)
```

## Troubleshooting

### Issue: "Cannot find XCFramework"

**Problem**: `cc_import` cannot locate the XCFramework file.

**Solution**:
1. Verify the XCFramework exists:
   ```bash
   ls -la modules/omnitak_mobile/ios/native/OmniTAKMobile.xcframework/
   ```

2. Rebuild the XCFramework:
   ```bash
   cd /Users/iesouskurios/Downloads/omni-TAK/crates/omnitak-mobile
   ./build_ios.sh
   ```

3. Check the path in BUILD.bazel matches the actual file structure.

### Issue: "Swift module not found"

**Problem**: `swift_library` cannot find dependencies.

**Solution**:
1. Ensure `@build_bazel_rules_swift` is properly loaded in WORKSPACE
2. Check module name matches:
   ```python
   swift_library(
       name = "ios_native_bridge",
       module_name = "OmniTAKNativeBridge",  # Must match import statements
   )
   ```

### Issue: "JNI symbols not found"

**Problem**: Android build cannot find JNI functions.

**Solution**:
1. Use `alwayslink = True` on the JNI cc_library:
   ```python
   cc_library(
       name = "android_jni_bridge",
       alwayslink = True,  # ← Ensures JNI symbols are linked
   )
   ```

2. Load the library in Kotlin:
   ```kotlin
   companion object {
       init {
           System.loadLibrary("omnitak_jni")
       }
   }
   ```

### Issue: "MapLibre framework not found (iOS)"

**Problem**: `@import MapLibre;` fails in Objective-C code.

**Solution**:
1. **Temporary workaround**: Comment out MapLibre code during initial Bazel build
2. **Long-term solution**: Add MapLibre framework import:
   ```python
   objc_import(
       name = "maplibre_ios",
       framework_imports = glob(["ios/Frameworks/MapLibre.framework/**"]),
   )

   client_objc_library(
       name = "ios_maplibre_wrapper",
       deps = [":maplibre_ios"],
   )
   ```

### Issue: "Kotlin version mismatch"

**Problem**: Different Kotlin versions in dependencies.

**Solution**:
1. Check Kotlin version in WORKSPACE:
   ```python
   load("@rules_kotlin//kotlin:repositories.bzl", "kotlin_repositories")
   kotlin_repositories(kotlin_compiler_version = "1.8.0")
   ```

2. Ensure all Kotlin libraries use compatible versions.

### Issue: "Build too slow"

**Problem**: Bazel builds are taking too long.

**Solution**:
1. Enable remote caching:
   ```bash
   bazel build --remote_cache=https://your-cache-server //modules/omnitak_mobile:omnitak_mobile
   ```

2. Use incremental builds:
   ```bash
   # Build only changed targets
   bazel build //modules/omnitak_mobile:omnitak_mobile
   ```

3. Check for unnecessary dependencies:
   ```bash
   bazel query 'somepath(//modules/omnitak_mobile:omnitak_mobile, @valdi//...)'
   ```

## Build Flags Reference

### Common Flags

```bash
# Build for specific platform
--platforms=@build_bazel_rules_apple//apple:ios_arm64
--platforms=@snap_platforms//platforms:android_arm64

# Optimization level
--compilation_mode=opt         # Optimized
--compilation_mode=dbg         # Debug symbols
--compilation_mode=fastbuild   # Fast, minimal optimization

# Enable/disable features
--features=dead_strip          # Remove unused code (iOS)
--copt="-Os"                   # Optimize for size

# Debugging
--verbose_failures             # Show detailed error messages
--sandbox_debug                # Debug sandbox issues
```

### iOS-Specific Flags

```bash
# Target iOS device
--platforms=@build_bazel_rules_apple//apple:ios_arm64

# Target iOS simulator
--platforms=@build_bazel_rules_apple//apple:ios_sim_arm64

# Set minimum iOS version
--ios_minimum_os=14.0

# Enable bitcode
--features=apple.arm64_bitcode
```

### Android-Specific Flags

```bash
# Target Android ARM64
--platforms=@snap_platforms//platforms:android_arm64

# Target Android x86_64 (emulator)
--platforms=@snap_platforms//platforms:android_x86_64

# Set minimum SDK version
--android_min_sdk=21

# Enable ProGuard
--proguard_top=//path/to/proguard.cfg
```

## Integration with Valdi Applications

To use OmniTAK Mobile in a Valdi application:

1. **Add dependency to your app's BUILD.bazel**:
   ```python
   valdi_application(
       name = "my_app",
       deps = [
           "//modules/omnitak_mobile:omnitak_mobile",
       ],
   )
   ```

2. **Import in TypeScript**:
   ```typescript
   import { OmniTAKModule } from '@valdi/omnitak/OmniTAKModule';
   ```

3. **Build the application**:
   ```bash
   # iOS
   bazel build //apps/my_app:my_app_ios --platforms=@build_bazel_rules_apple//apple:ios_arm64

   # Android
   bazel build //apps/my_app:my_app_android --platforms=@snap_platforms//platforms:android_arm64
   ```

## Directory Structure

```
modules/omnitak_mobile/
├── BUILD.bazel                    # Main build configuration
├── module.yaml                    # Valdi module metadata
├── tsconfig.json                  # TypeScript configuration
│
├── src/valdi/omnitak/            # TypeScript sources
│   ├── OmniTAKModule.tsx
│   ├── components/
│   └── utils/
│
├── ios/
│   ├── native/                    # iOS native code
│   │   ├── OmniTAKMobile.xcframework/
│   │   │   ├── ios-arm64/
│   │   │   │   └── libomnitak_mobile.a
│   │   │   └── ios-arm64_x86_64-simulator/
│   │   │       └── libomnitak_mobile.a
│   │   ├── OmniTAKNativeBridge.swift
│   │   └── omnitak_mobile.h
│   │
│   └── maplibre/                  # MapLibre wrapper
│       ├── SCMapLibreMapView.h
│       └── SCMapLibreMapView.m
│
└── android/
    ├── native/                    # Android native code
    │   ├── include/
    │   │   └── omnitak_jni.h
    │   ├── omnitak_jni.cpp
    │   └── OmniTAKNativeBridge.kt
    │
    └── maplibre/                  # MapLibre wrapper
        ├── MapLibreMapView.kt
        └── MapLibreMapViewAttributesBinder.kt
```

## Further Reading

- [Bazel iOS Rules](https://github.com/bazelbuild/rules_apple)
- [Bazel Kotlin Rules](https://github.com/bazelbuild/rules_kotlin)
- [Bazel Swift Rules](https://github.com/bazelbuild/rules_swift)
- [Valdi Framework Documentation](https://valdi.snapchat.com)
- [MapLibre GL Native](https://maplibre.org)

## Support

For build issues specific to:
- **Valdi framework**: Check internal Valdi documentation
- **OmniTAK Mobile**: See `modules/omnitak_mobile/README.md`
- **Rust FFI**: See the omni-TAK repository
