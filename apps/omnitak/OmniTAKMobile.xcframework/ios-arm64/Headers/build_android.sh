#!/bin/bash
set -e

echo "Building omnitak-mobile for Android targets..."

# Install Rust Android targets if not already installed
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add x86_64-linux-android
rustup target add i686-linux-android

# Set up Android NDK environment
if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "ERROR: ANDROID_NDK_HOME not set!"
    echo "Please set it to your Android NDK path, e.g.:"
    echo "  export ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/27.0.12077973"
    exit 1
fi

# Install cargo-ndk if not already installed
if ! command -v cargo-ndk &> /dev/null; then
    echo "Installing cargo-ndk..."
    cargo install cargo-ndk
fi

# Build for different Android architectures
echo "Building for Android ARM64..."
cargo ndk --target aarch64-linux-android --platform 21 -- build --release

echo "Building for Android ARMv7..."
cargo ndk --target armv7-linux-androideabi --platform 21 -- build --release

echo "Building for Android x86_64..."
cargo ndk --target x86_64-linux-android --platform 21 -- build --release

echo "Building for Android x86..."
cargo ndk --target i686-linux-android --platform 21 -- build --release

# Create JNI library directory structure
echo "Organizing libraries for Android..."
mkdir -p ../../target/android-jniLibs/{arm64-v8a,armeabi-v7a,x86_64,x86}

cp ../../target/aarch64-linux-android/release/libomnitak_mobile.so \
   ../../target/android-jniLibs/arm64-v8a/

cp ../../target/armv7-linux-androideabi/release/libomnitak_mobile.so \
   ../../target/android-jniLibs/armeabi-v7a/

cp ../../target/x86_64-linux-android/release/libomnitak_mobile.so \
   ../../target/android-jniLibs/x86_64/

cp ../../target/i686-linux-android/release/libomnitak_mobile.so \
   ../../target/android-jniLibs/x86/

echo "✅ Android build complete!"
echo "JNI libraries: ../../target/android-jniLibs/"
echo ""
echo "To use in Android Studio:"
echo "  1. Copy jniLibs folder to your app/src/main/ directory"
echo "  2. Add to build.gradle: implementation files('libs/omnitak_mobile.jar')"
echo "  3. Load in Java: System.loadLibrary(\"omnitak_mobile\")"
