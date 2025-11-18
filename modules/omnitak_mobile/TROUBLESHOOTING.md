# OmniTAK Mobile - Bazel Build Troubleshooting Guide

This guide covers common build issues and their solutions when working with the OmniTAK Mobile Bazel configuration.

## Table of Contents

1. [XCFramework Issues](#xcframework-issues)
2. [Swift Build Issues](#swift-build-issues)
3. [JNI/Android Issues](#jniandroid-issues)
4. [MapLibre Integration Issues](#maplibre-integration-issues)
5. [Dependency Resolution Issues](#dependency-resolution-issues)
6. [Performance Issues](#performance-issues)
7. [Platform-Specific Issues](#platform-specific-issues)

---

## XCFramework Issues

### Issue: "Cannot find XCFramework"

**Error Message:**
```
ERROR: .../modules/omnitak_mobile/BUILD.bazel:23:10: no such target '//modules/omnitak_mobile:ios/native/OmniTAKMobile.xcframework/ios-arm64/libomnitak_mobile.a'
```

**Cause**: The XCFramework hasn't been built yet or is in the wrong location.

**Solution 1**: Build the XCFramework
```bash
cd $OMNI_TAK_PATH/crates/omnitak-mobile
./build_ios.sh
```

**Solution 2**: Verify the XCFramework exists
```bash
ls -la $PROJECT_ROOT/modules/omnitak_mobile/ios/native/OmniTAKMobile.xcframework/
```

**Solution 3**: Check the path in BUILD.bazel
```python
cc_import(
    name = "omnitak_mobile_xcframework_device",
    static_library = "ios/native/OmniTAKMobile.xcframework/ios-arm64/libomnitak_mobile.a",
    # ↑ Ensure this path matches the actual file location
)
```

---

### Issue: "Architecture mismatch"

**Error Message:**
```
ld: warning: ignoring file .../libomnitak_mobile.a, building for iOS Simulator-arm64 but attempting to link with file built for iOS-arm64
```

**Cause**: Using device library for simulator or vice versa.

**Solution**: Use the correct platform selector
```python
alias(
    name = "omnitak_mobile_xcframework",
    actual = select({
        "@platforms//os:ios": ":omnitak_mobile_xcframework_device",
        "//conditions:default": ":omnitak_mobile_xcframework_simulator",
    }),
)
```

**Build Command**:
```bash
# For device
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --platforms=@build_bazel_rules_apple//apple:ios_arm64

# For simulator
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --platforms=@build_bazel_rules_apple//apple:ios_sim_arm64
```

---

### Issue: "Duplicate symbols"

**Error Message:**
```
duplicate symbol '_omnitak_connect_tak' in:
    .../libomnitak_mobile.a
    .../librust_ffi.a
```

**Cause**: The Rust library is being linked multiple times.

**Solution**: Use `alwayslink = False` and link only once
```python
cc_import(
    name = "omnitak_mobile_xcframework_device",
    static_library = "ios/native/OmniTAKMobile.xcframework/ios-arm64/libomnitak_mobile.a",
    alwayslink = False,  # ← Add this
)
```

---

## Swift Build Issues

### Issue: "Swift module not found"

**Error Message:**
```
error: no such module 'OmniTAKNativeBridge'
```

**Cause**: Module name mismatch or missing Swift rules.

**Solution 1**: Verify module name matches
```python
swift_library(
    name = "ios_native_bridge",
    module_name = "OmniTAKNativeBridge",  # ← Must match import statement
)
```

In Swift code:
```swift
import OmniTAKNativeBridge  // ← Must match module_name
```

**Solution 2**: Check WORKSPACE has Swift rules
```python
load("@build_bazel_rules_swift//swift:repositories.bzl", "swift_rules_dependencies")
swift_rules_dependencies()
```

**Solution 3**: Rebuild with clean cache
```bash
bazel clean --expunge
bazel build //modules/omnitak_mobile:ios_native_bridge
```

---

### Issue: "Cannot find type in scope"

**Error Message:**
```
error: cannot find type 'OmniTAKMobile' in scope
```

**Cause**: Missing C header bridging or incorrect import.

**Solution**: Ensure Swift can see C headers
```python
swift_library(
    name = "ios_native_bridge",
    srcs = ["ios/native/OmniTAKNativeBridge.swift"],
    deps = [
        ":omnitak_mobile_xcframework",  # ← C headers exposed via this dep
    ],
)
```

In Swift, use bridging:
```swift
// Create a module.modulemap if needed
import omnitak_mobile  // C module
```

---

### Issue: "Swift optimization failed"

**Error Message:**
```
error: Swift compilation failed with exit code 1
```

**Cause**: Optimization flags incompatible with code.

**Solution**: Adjust optimization flags
```python
swift_library(
    name = "ios_native_bridge",
    copts = [
        "-O",  # Instead of "-Osize"
        # Remove problematic flags
    ],
)
```

Or build in debug mode:
```bash
bazel build //modules/omnitak_mobile:ios_native_bridge --compilation_mode=dbg
```

---

## JNI/Android Issues

### Issue: "JNI symbols not found"

**Error Message:**
```
java.lang.UnsatisfiedLinkError: No implementation found for native method
```

**Cause**: JNI library not linked or symbols stripped.

**Solution 1**: Use `alwayslink = True`
```python
cc_library(
    name = "android_jni_bridge",
    srcs = ["android/native/omnitak_jni.cpp"],
    alwayslink = True,  # ← Prevents symbol stripping
)
```

**Solution 2**: Load library in Kotlin
```kotlin
companion object {
    init {
        System.loadLibrary("omnitak_jni")
    }
}
```

**Solution 3**: Check JNI function names
```cpp
// C++ JNI function
JNIEXPORT jstring JNICALL
Java_com_engindearing_omnitak_OmniTAKNativeBridge_parseCot(
    JNIEnv* env, jobject obj, jstring xml_string) {
    // ↑ Must match: package + class + method
}
```

Kotlin:
```kotlin
package com.engindearing.omnitak  // ← Must match JNI function

class OmniTAKNativeBridge {
    external fun parseCot(xmlString: String): String  // ← Must match
}
```

---

### Issue: "UnsatisfiedLinkError: dlopen failed"

**Error Message:**
```
java.lang.UnsatisfiedLinkError: dlopen failed: cannot locate symbol "rust_function"
```

**Cause**: Missing Rust static library linkage.

**Solution**: Link Rust library in JNI build
```python
cc_library(
    name = "android_jni_bridge",
    srcs = ["android/native/omnitak_jni.cpp"],
    deps = [
        "//path/to/rust:libomnitak_mobile",  # ← Add Rust library
    ],
)
```

Or build Rust library separately and link:
```bash
cd $OMNI_TAK_PATH/crates/omnitak-mobile
./build_android.sh

# Copy .so files to jniLibs
cp target/aarch64-linux-android/release/libomnitak_mobile.so \
   $PROJECT_ROOT/modules/omnitak_mobile/android/jniLibs/arm64-v8a/
```

---

### Issue: "Kotlin version mismatch"

**Error Message:**
```
Kotlin: Language version 1.9 is not supported
```

**Cause**: Incompatible Kotlin versions.

**Solution 1**: Check WORKSPACE Kotlin version
```python
load("@rules_kotlin//kotlin:repositories.bzl", "kotlin_repositories")
kotlin_repositories(kotlin_compiler_version = "1.8.0")
```

**Solution 2**: Update module Kotlin version
```python
kt_android_library(
    name = "android_native_bridge",
    kotlinc_opts = [
        "-language-version", "1.8",
        "-api-version", "1.8",
    ],
)
```

---

### Issue: "Android SDK not found"

**Error Message:**
```
ERROR: Could not find Android SDK
```

**Cause**: Android SDK path not configured.

**Solution**: Set Android SDK environment variables
```bash
export ANDROID_HOME=/path/to/android-sdk
export ANDROID_NDK_HOME=/path/to/android-ndk

# Add to ~/.bashrc or ~/.zshrc
echo 'export ANDROID_HOME=/path/to/android-sdk' >> ~/.bashrc
echo 'export ANDROID_NDK_HOME=/path/to/android-ndk' >> ~/.bashrc
```

Or configure in `.bazelrc`:
```
build --android_sdk=/path/to/android-sdk
build --android_ndk=/path/to/android-ndk
```

---

## MapLibre Integration Issues

### Issue: "MapLibre framework not found (iOS)"

**Error Message:**
```
error: no such module 'MapLibre'
```

**Cause**: MapLibre framework not available during build.

**Solution 1**: Add framework import (if using manual framework)
```python
objc_import(
    name = "maplibre_ios",
    framework_imports = glob(["ios/Frameworks/MapLibre.framework/**"]),
)

client_objc_library(
    name = "ios_maplibre_wrapper",
    deps = [
        ":maplibre_ios",
        "@valdi//valdi_core:valdi_core_objc",
    ],
)
```

**Solution 2**: Use CocoaPods (if supported)
```ruby
# ios/Podfile
pod 'MapLibre', '~> 6.0'
```

**Solution 3**: Temporary workaround - comment out MapLibre imports
```objc
// SCMapLibreMapView.m
// #import <MapLibre/MapLibre.h>  // ← Comment during Bazel build
```

---

### Issue: "MapLibre SDK not found (Android)"

**Error Message:**
```
error: package org.maplibre.gl.maps does not exist
```

**Cause**: MapLibre Maven dependency not configured.

**Solution**: Add to WORKSPACE
```python
load("@rules_jvm_external//:defs.bzl", "maven_install")

maven_install(
    name = "maven",
    artifacts = [
        "org.maplibre.gl:android-sdk:11.8.0",
        "org.maplibre.gl:android-plugin-annotation-v9:3.0.0",
    ],
    repositories = [
        "https://maven.google.com",
        "https://repo1.maven.org/maven2",
    ],
)
```

Use in BUILD.bazel:
```python
kt_android_library(
    name = "android_maplibre_wrapper",
    deps = [
        "@maven//:org_maplibre_gl_android_sdk",
        "@maven//:org_maplibre_gl_android_plugin_annotation_v9",
    ],
)
```

---

### Issue: "MapLibre delegate methods not called"

**Symptom**: Map loads but callbacks don't fire.

**Cause**: Delegate not properly set or retained.

**Solution**: Ensure delegate is set and retained
```objc
@interface SCMapLibreMapView : SCValdiView <MLNMapViewDelegate>
@property (nonatomic, strong, readonly) MLNMapView *mapView;
@end

@implementation SCMapLibreMapView

- (void)setupMapView {
    _mapView = [[MLNMapView alloc] initWithFrame:self.bounds];
    _mapView.delegate = self;  // ← Set delegate
    [self addSubview:_mapView];
}

- (void)mapView:(MLNMapView *)mapView didFinishLoadingStyle:(MLNStyle *)style {
    // This should now be called
    [self fireCallback:@"onMapReady" withData:@{}];
}

@end
```

---

## Dependency Resolution Issues

### Issue: "Circular dependency detected"

**Error Message:**
```
ERROR: Circular dependency between //modules/omnitak_mobile:ios_native_bridge and //modules/omnitak_mobile:omnitak_mobile
```

**Cause**: Targets depend on each other.

**Solution**: Break circular dependency
```python
# WRONG:
valdi_module(
    name = "omnitak_mobile",
    ios_deps = [":ios_native_bridge"],
)

swift_library(
    name = "ios_native_bridge",
    deps = [":omnitak_mobile"],  # ← Circular!
)

# CORRECT:
valdi_module(
    name = "omnitak_mobile",
    ios_deps = [":ios_native_bridge"],
)

swift_library(
    name = "ios_native_bridge",
    deps = [
        "@valdi//valdi_core:valdi_core_swift_marshaller",  # ← Use core, not module
    ],
)
```

---

### Issue: "Dependency not found"

**Error Message:**
```
ERROR: no such target '@@valdi//valdi_core:valdi_core_objc'
```

**Cause**: Workspace name or target path incorrect.

**Solution**: Verify workspace name and path
```bash
# Check workspace name
grep workspace WORKSPACE
# Should be: workspace(name = "valdi")

# Verify target exists
bazel query @valdi//valdi_core:valdi_core_objc
```

Fix reference:
```python
deps = [
    "@valdi//valdi_core:valdi_core_objc",  # ← Single @ for external workspace
]
```

---

### Issue: "Version conflict"

**Error Message:**
```
ERROR: Multiple conflicting versions of org.jetbrains.kotlin:kotlin-stdlib
```

**Cause**: Different dependencies require different versions.

**Solution**: Use version resolution
```python
maven_install(
    name = "maven",
    artifacts = [
        "org.jetbrains.kotlin:kotlin-stdlib:1.8.0",
    ],
    version_conflict_policy = "pinned",  # ← Pin to specific version
)
```

---

## Performance Issues

### Issue: "Build is very slow"

**Cause**: No caching, too many parallel jobs, or large dependency tree.

**Solution 1**: Enable disk cache
```bash
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --disk_cache=~/.cache/bazel
```

**Solution 2**: Limit parallel jobs
```bash
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --jobs=4
```

**Solution 3**: Use remote cache (if available)
```bash
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --remote_cache=grpc://your-cache-server:8980
```

**Solution 4**: Profile the build
```bash
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --profile=/tmp/profile.json

bazel analyze-profile /tmp/profile.json
```

---

### Issue: "Out of memory"

**Error Message:**
```
java.lang.OutOfMemoryError: Java heap space
```

**Cause**: Bazel or build tools running out of memory.

**Solution 1**: Increase Java heap size
```bash
export BAZEL_OPTS="-Xmx4g"
```

**Solution 2**: Limit parallel jobs
```bash
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --jobs=2
```

**Solution 3**: Use smaller action cache
```bash
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --experimental_action_cache_store_output_metadata=false
```

---

### Issue: "Sandbox errors"

**Error Message:**
```
ERROR: Sandboxing failed with exit code 1
```

**Cause**: Sandbox restrictions preventing file access.

**Solution 1**: Disable sandbox for specific target
```python
cc_library(
    name = "android_jni_bridge",
    tags = ["no-sandbox"],  # ← Disable sandbox
)
```

**Solution 2**: Use local execution
```bash
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --spawn_strategy=local
```

**Solution 3**: Debug sandbox
```bash
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --sandbox_debug
```

---

## Platform-Specific Issues

### Issue: "Code signing error (iOS)"

**Error Message:**
```
error: Code signing failed
```

**Cause**: Missing or invalid code signing certificate.

**Solution**: Disable code signing for Bazel builds
```python
valdi_module(
    name = "omnitak_mobile",
    ios_output_target = "release",
    # Bazel doesn't sign - signing happens in Xcode
)
```

Or configure provisioning profile:
```bash
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --ios_signing_cert_name="Apple Development: Your Name"
```

---

### Issue: "R8/ProGuard errors (Android)"

**Error Message:**
```
ERROR: R8: Missing class org.maplibre.gl.maps.MapView
```

**Cause**: ProGuard rules stripping required classes.

**Solution**: Add ProGuard rules
```
# android/proguard-rules.pro
-keep class org.maplibre.gl.** { *; }
-keep class com.mapbox.** { *; }
-keep class com.engindearing.omnitak.** { *; }

# Keep JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
}
```

Reference in BUILD.bazel:
```python
kt_android_library(
    name = "android_maplibre_wrapper",
    proguard_specs = ["//modules/omnitak_mobile/android:proguard_rules"],
)
```

---

### Issue: "Bitcode errors (iOS)"

**Error Message:**
```
ld: bitcode bundle could not be generated
```

**Cause**: Bitcode enabled but not supported by all libraries.

**Solution**: Disable bitcode
```bash
bazel build //modules/omnitak_mobile:omnitak_mobile \
  --features=-apple.bitcode
```

---

## Getting Help

If you're still experiencing issues:

1. **Check build logs**: `bazel build --verbose_failures`
2. **Clean and rebuild**: `bazel clean --expunge && bazel build ...`
3. **Check documentation**: See `BUILD_CONFIGURATION.md` and `BAZEL_QUICK_REFERENCE.md`
4. **Ask for help**: Include:
   - Bazel version (`bazel version`)
   - Platform (iOS/Android)
   - Full error message
   - Build command used
   - Relevant BUILD.bazel snippet

## Common Error Patterns

### Pattern 1: "Error: no such package"
→ Check path is correct in BUILD file
→ Verify package has a BUILD file

### Pattern 2: "Error: undefined symbol"
→ Check library is linked
→ Verify `alwayslink = True` for JNI/FFI libraries

### Pattern 3: "Error: module not found"
→ Check module name matches import
→ Verify workspace is loaded in WORKSPACE

### Pattern 4: "Error: platform not supported"
→ Check `--platforms` flag
→ Verify platform toolchain is configured

---

This troubleshooting guide should help you resolve most common build issues with the OmniTAK Mobile Bazel configuration.
