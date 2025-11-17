#!/bin/bash
set -e

echo "Building omnitak-mobile for iOS targets..."

# Install Rust iOS targets if not already installed
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add x86_64-apple-ios

# Build for different iOS architectures
echo "Building for iOS device (ARM64)..."
cargo build --release --target aarch64-apple-ios

echo "Building for iOS simulator (ARM64)..."
cargo build --release --target aarch64-apple-ios-sim

echo "Building for iOS simulator (x86_64)..."
cargo build --release --target x86_64-apple-ios

# Create universal library for simulator
echo "Creating universal simulator library..."
mkdir -p ../../target/universal-ios-sim/release
lipo -create \
    ../../target/aarch64-apple-ios-sim/release/libomnitak_mobile.a \
    ../../target/x86_64-apple-ios/release/libomnitak_mobile.a \
    -output ../../target/universal-ios-sim/release/libomnitak_mobile.a

# Create XCFramework
echo "Creating XCFramework..."
rm -rf ../../target/OmniTAKMobile.xcframework

xcodebuild -create-xcframework \
    -library ../../target/aarch64-apple-ios/release/libomnitak_mobile.a \
    -headers ./ \
    -library ../../target/universal-ios-sim/release/libomnitak_mobile.a \
    -headers ./ \
    -output ../../target/OmniTAKMobile.xcframework

echo "✅ iOS build complete!"
echo "XCFramework: ../../target/OmniTAKMobile.xcframework"
echo ""
echo "To use in Xcode:"
echo "  1. Drag OmniTAKMobile.xcframework into your project"
echo "  2. Add to 'Frameworks, Libraries, and Embedded Content'"
echo "  3. Import in Swift: import omnitak_mobile"
