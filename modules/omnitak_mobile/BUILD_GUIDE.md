# OmniTAK Mobile - Build Guide

This guide provides step-by-step instructions for building the OmniTAK Mobile native libraries and integrating them with the Valdi polyglot system.

## Prerequisites

### Required Tools

**For iOS:**
- macOS 12.0+ (Monterey or later)
- Xcode 14.0+
- Command Line Tools: `xcode-select --install`
- Rust toolchain: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`

**For Android:**
- Android Studio Arctic Fox or later
- Android NDK r21 or later
- CMake 3.18.1+
- Rust toolchain (same as above)

**For Both:**
- Rust 1.70+
- cargo-lipo (iOS): `cargo install cargo-lipo`
- cbindgen: `cargo install cbindgen`

### Environment Setup

```bash
# Add Rust to PATH (if not already done)
source $HOME/.cargo/env

# Install iOS targets
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add x86_64-apple-ios

# Install Android targets
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add x86_64-linux-android
rustup target add i686-linux-android

# Set Android NDK path
export ANDROID_NDK_HOME=$HOME/Library/Android/sdk/ndk/25.1.8937393
# Or wherever your NDK is installed
```

## Building for iOS

### Step 1: Build Rust Library

Navigate to the OmniTAK Rust project:

```bash
cd $OMNI_TAK_PATH/crates/omnitak-mobile
```

Build for all iOS architectures:

```bash
# Device (arm64)
cargo build --release --target aarch64-apple-ios

# Simulator (arm64 for M1/M2 Macs)
cargo build --release --target aarch64-apple-ios-sim

# Simulator (x86_64 for Intel Macs)
cargo build --release --target x86_64-apple-ios
```

Build output locations:
- `../../target/aarch64-apple-ios/release/libomnitak_mobile.a`
- `../../target/aarch64-apple-ios-sim/release/libomnitak_mobile.a`
- `../../target/x86_64-apple-ios/release/libomnitak_mobile.a`

### Step 2: Create XCFramework

An XCFramework bundles multiple architecture variants:

```bash
cd $OMNI_TAK_PATH

# Create XCFramework
xcodebuild -create-xcframework \
  -library target/aarch64-apple-ios/release/libomnitak_mobile.a \
  -library target/aarch64-apple-ios-sim/release/libomnitak_mobile.a \
  -library target/x86_64-apple-ios/release/libomnitak_mobile.a \
  -output target/OmniTAKMobile.xcframework
```

### Step 3: Copy to Valdi Module

```bash
# Copy XCFramework
cp -R target/OmniTAKMobile.xcframework \
  $PROJECT_ROOT/modules/omnitak_mobile/ios/native/

# Copy header (should already be there)
cp crates/omnitak-mobile/omnitak_mobile.h \
  $PROJECT_ROOT/modules/omnitak_mobile/ios/native/
```

### Step 4: Verify iOS Build

Check that files are in place:

```bash
ls -la $PROJECT_ROOT/modules/omnitak_mobile/ios/native/

# Should see:
# OmniTAKMobile.xcframework/
# OmniTAKNativeBridge.swift
# omnitak_mobile.h
```

## Building for Android

### Step 1: Configure NDK

Create or update `~/.cargo/config.toml`:

```toml
[target.aarch64-linux-android]
ar = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-ar"
linker = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android30-clang"

[target.armv7-linux-androideabi]
ar = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-ar"
linker = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/armv7a-linux-androideabi30-clang"

[target.x86_64-linux-android]
ar = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-ar"
linker = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/x86_64-linux-android30-clang"

[target.i686-linux-android]
ar = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-ar"
linker = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/i686-linux-android30-clang"
```

**Note:** Replace `darwin-x86_64` with your platform (e.g., `linux-x86_64` on Linux) and adjust NDK version as needed.

### Step 2: Build Rust Library

```bash
cd $OMNI_TAK_PATH/crates/omnitak-mobile

# arm64-v8a (64-bit ARM)
cargo build --release --target aarch64-linux-android

# armeabi-v7a (32-bit ARM)
cargo build --release --target armv7-linux-androideabi

# x86_64 (64-bit Intel - emulator)
cargo build --release --target x86_64-linux-android

# x86 (32-bit Intel - legacy)
cargo build --release --target i686-linux-android
```

### Step 3: Copy Libraries to Android Module

```bash
cd $OMNI_TAK_PATH

# Create lib directories
mkdir -p $PROJECT_ROOT/modules/omnitak_mobile/android/native/lib/{arm64-v8a,armeabi-v7a,x86_64,x86}

# Copy arm64-v8a
cp target/aarch64-linux-android/release/libomnitak_mobile.a \
   $PROJECT_ROOT/modules/omnitak_mobile/android/native/lib/arm64-v8a/

# Copy armeabi-v7a
cp target/armv7-linux-androideabi/release/libomnitak_mobile.a \
   $PROJECT_ROOT/modules/omnitak_mobile/android/native/lib/armeabi-v7a/

# Copy x86_64
cp target/x86_64-linux-android/release/libomnitak_mobile.a \
   $PROJECT_ROOT/modules/omnitak_mobile/android/native/lib/x86_64/

# Copy x86
cp target/i686-linux-android/release/libomnitak_mobile.a \
   $PROJECT_ROOT/modules/omnitak_mobile/android/native/lib/x86/
```

### Step 4: Verify Android Build

```bash
ls -la $PROJECT_ROOT/modules/omnitak_mobile/android/native/

# Should see:
# lib/
#   arm64-v8a/libomnitak_mobile.a
#   armeabi-v7a/libomnitak_mobile.a
#   x86_64/libomnitak_mobile.a
#   x86/libomnitak_mobile.a
# include/omnitak_mobile.h
# OmniTAKNativeBridge.kt
# omnitak_jni.cpp
# CMakeLists.txt
```

## Automated Build Script

Create `build_all.sh` in the omni-TAK root:

```bash
#!/bin/bash
set -e

echo "========================================="
echo "Building OmniTAK Mobile for all platforms"
echo "========================================="

OMNI_TAK_DIR="/Users/iesouskurios/Downloads/omni-TAK"
OMNI_BASE_DIR="/Users/iesouskurios/Downloads/omni-BASE"
MODULE_DIR="$OMNI_BASE_DIR/modules/omnitak_mobile"

cd "$OMNI_TAK_DIR/crates/omnitak-mobile"

# iOS Builds
echo "Building for iOS..."
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target x86_64-apple-ios

# Create XCFramework
echo "Creating XCFramework..."
cd "$OMNI_TAK_DIR"
rm -rf target/OmniTAKMobile.xcframework
xcodebuild -create-xcframework \
  -library target/aarch64-apple-ios/release/libomnitak_mobile.a \
  -library target/aarch64-apple-ios-sim/release/libomnitak_mobile.a \
  -library target/x86_64-apple-ios/release/libomnitak_mobile.a \
  -output target/OmniTAKMobile.xcframework

# Copy to module
echo "Copying iOS framework..."
rm -rf "$MODULE_DIR/ios/native/OmniTAKMobile.xcframework"
cp -R target/OmniTAKMobile.xcframework "$MODULE_DIR/ios/native/"

# Android Builds
echo "Building for Android..."
cd "$OMNI_TAK_DIR/crates/omnitak-mobile"

cargo build --release --target aarch64-linux-android
cargo build --release --target armv7-linux-androideabi
cargo build --release --target x86_64-linux-android
cargo build --release --target i686-linux-android

# Copy to module
echo "Copying Android libraries..."
mkdir -p "$MODULE_DIR/android/native/lib"/{arm64-v8a,armeabi-v7a,x86_64,x86}

cp "$OMNI_TAK_DIR/target/aarch64-linux-android/release/libomnitak_mobile.a" \
   "$MODULE_DIR/android/native/lib/arm64-v8a/"

cp "$OMNI_TAK_DIR/target/armv7-linux-androideabi/release/libomnitak_mobile.a" \
   "$MODULE_DIR/android/native/lib/armeabi-v7a/"

cp "$OMNI_TAK_DIR/target/x86_64-linux-android/release/libomnitak_mobile.a" \
   "$MODULE_DIR/android/native/lib/x86_64/"

cp "$OMNI_TAK_DIR/target/i686-linux-android/release/libomnitak_mobile.a" \
   "$MODULE_DIR/android/native/lib/x86/"

echo "========================================="
echo "Build complete!"
echo "========================================="
echo "iOS framework: $MODULE_DIR/ios/native/OmniTAKMobile.xcframework"
echo "Android libs: $MODULE_DIR/android/native/lib/"
```

Make executable and run:

```bash
chmod +x build_all.sh
./build_all.sh
```

## Xcode Integration

### Adding to Xcode Project

1. Open your Xcode project
2. In Project Navigator, right-click → Add Files
3. Navigate to `modules/omnitak_mobile/ios/native/`
4. Select `OmniTAKMobile.xcframework` and `OmniTAKNativeBridge.swift`
5. Ensure "Copy items if needed" is **unchecked**
6. Click "Add"

### Link Framework

1. Select project in Navigator
2. Select your app target
3. Go to "General" tab
4. Under "Frameworks, Libraries, and Embedded Content":
   - Verify `OmniTAKMobile.xcframework` is listed
   - Set to "Do Not Embed" (it's a static library)

### Build Settings

1. Select project → Build Settings
2. Search for "Swift Compiler - Language"
3. Set "Swift Language Version" to "Swift 5"
4. Search for "Runpath Search Paths"
5. Add: `@executable_path/Frameworks`

### Bridging Header (if needed)

If mixing Objective-C, create bridging header:

**ProjectName-Bridging-Header.h:**
```objc
#import "omnitak_mobile.h"
```

Add to Build Settings → "Objective-C Bridging Header"

## Android Gradle Integration

### Update app/build.gradle

```gradle
android {
    compileSdk 34

    defaultConfig {
        applicationId "com.engindearing.omnitak"
        minSdk 21
        targetSdk 34

        ndk {
            // Specify supported ABIs
            abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'
        }

        externalNativeBuild {
            cmake {
                cppFlags "-std=c++17"
                arguments "-DANDROID_STL=c++_shared"
            }
        }
    }

    externalNativeBuild {
        cmake {
            path "../../modules/omnitak_mobile/android/native/CMakeLists.txt"
            version "3.18.1"
        }
    }

    sourceSets {
        main {
            // Add Kotlin source
            java.srcDirs += '../../modules/omnitak_mobile/android/native'
        }
    }
}

dependencies {
    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3"
}
```

### Sync and Build

1. In Android Studio: File → Sync Project with Gradle Files
2. Build → Make Project
3. Verify in Build Output that CMake runs successfully
4. Check that `libomnitak_mobile.so` is in APK:
   ```bash
   unzip -l app/build/outputs/apk/debug/app-debug.apk | grep libomnitak_mobile.so
   ```

## Troubleshooting

### iOS Build Errors

**Error: `ld: framework not found OmniTAKMobile`**

Solution:
- Check XCFramework is in correct location
- Verify framework is added to target
- Clean build folder: Product → Clean Build Folder

**Error: `Undefined symbol: _omnitak_init`**

Solution:
- Ensure XCFramework contains static library
- Check that library is linked in Build Phases
- Verify correct architecture is being built

### Android Build Errors

**Error: `CMake Error: Could not find CMAKE_MAKE_PROGRAM`**

Solution:
```bash
# In Android Studio: Tools → SDK Manager → SDK Tools
# Check "CMake" and "NDK"
```

**Error: `ld: cannot find -lomnitak_rust`**

Solution:
- Verify Rust libraries are in `android/native/lib/${ABI}/`
- Check file is named `libomnitak_mobile.a` (not `.so`)
- Clean and rebuild

**Error: `A problem occurred configuring project ':app'`**

Solution:
- Check CMakeLists.txt path in build.gradle
- Ensure path is relative to app module
- Sync Gradle files

### Rust Build Errors

**Error: `error: linker 'aarch64-linux-android30-clang' not found`**

Solution:
- Verify `ANDROID_NDK_HOME` is set correctly
- Check `~/.cargo/config.toml` has correct paths
- Update NDK version in config to match installed version

**Error: `failed to run custom build command for openssl-sys`**

Solution (if using TLS):
```bash
# Install OpenSSL for cross-compilation
brew install openssl@3

# Set environment variables
export OPENSSL_DIR=$(brew --prefix openssl@3)
```

## CI/CD Integration

### GitHub Actions Example

`.github/workflows/build-native.yml`:

```yaml
name: Build Native Libraries

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-ios:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v3

      - name: Install Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          targets: aarch64-apple-ios,aarch64-apple-ios-sim,x86_64-apple-ios

      - name: Build iOS
        run: |
          cd crates/omnitak-mobile
          cargo build --release --target aarch64-apple-ios
          cargo build --release --target aarch64-apple-ios-sim
          cargo build --release --target x86_64-apple-ios

      - name: Create XCFramework
        run: |
          xcodebuild -create-xcframework \
            -library target/aarch64-apple-ios/release/libomnitak_mobile.a \
            -library target/aarch64-apple-ios-sim/release/libomnitak_mobile.a \
            -library target/x86_64-apple-ios/release/libomnitak_mobile.a \
            -output target/OmniTAKMobile.xcframework

      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: ios-framework
          path: target/OmniTAKMobile.xcframework

  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Android NDK
        uses: nttld/setup-ndk@v1
        with:
          ndk-version: r25c

      - name: Install Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          targets: aarch64-linux-android,armv7-linux-androideabi,x86_64-linux-android,i686-linux-android

      - name: Build Android
        run: |
          cd crates/omnitak-mobile
          cargo build --release --target aarch64-linux-android
          cargo build --release --target armv7-linux-androideabi
          cargo build --release --target x86_64-linux-android
          cargo build --release --target i686-linux-android

      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: android-libraries
          path: |
            target/aarch64-linux-android/release/libomnitak_mobile.a
            target/armv7-linux-androideabi/release/libomnitak_mobile.a
            target/x86_64-linux-android/release/libomnitak_mobile.a
            target/i686-linux-android/release/libomnitak_mobile.a
```

## Verification

### Test iOS Build

Create a simple test in Xcode:

```swift
import XCTest

class OmniTAKTests: XCTestCase {
    func testNativeInit() {
        let bridge = OmniTAKNativeBridge()
        let version = bridge.getVersion()
        XCTAssertFalse(version.isEmpty)
        print("OmniTAK version: \(version)")
    }
}
```

### Test Android Build

Create instrumented test:

```kotlin
@RunWith(AndroidJUnit4::class)
class OmniTAKNativeTest {
    @Test
    fun testNativeInit() {
        val bridge = OmniTAKNativeBridge.getInstance()
        val version = bridge.getVersion()
        assertTrue(version.isNotEmpty())
        Log.d("Test", "OmniTAK version: $version")
    }
}
```

## Next Steps

After successful build:

1. Review [INTEGRATION.md](INTEGRATION.md) for usage patterns
2. Implement Valdi polyglot annotations in TypeScript
3. Test with real TAK server connection
4. Set up CI/CD for automated builds
5. Create example app demonstrating features

## Additional Resources

- [Rust Cross-Compilation Guide](https://rust-lang.github.io/rustup/cross-compilation.html)
- [XCFramework Documentation](https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle)
- [Android NDK Guide](https://developer.android.com/ndk/guides)
- [CMake Android Build](https://developer.android.com/ndk/guides/cmake)
