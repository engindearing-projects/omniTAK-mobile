#!/bin/bash
set -e

echo "Building OmniTAK Mobile for iOS..."

# Navigate to omnitak-mobile crate
cd "$(dirname "$0")/omnitak-mobile"

# Build for all iOS targets
echo "Building for aarch64-apple-ios (device)..."
cargo build --release --target aarch64-apple-ios

echo "Building for aarch64-apple-ios-sim (M1 simulator)..."
cargo build --release --target aarch64-apple-ios-sim

echo "Building for x86_64-apple-ios (Intel simulator)..."
cargo build --release --target x86_64-apple-ios

# Create universal binary for simulator
echo "Creating universal simulator binary..."
mkdir -p ../../target/universal-sim
lipo -create \
    ../../target/aarch64-apple-ios-sim/release/libomnitak_mobile.a \
    ../../target/x86_64-apple-ios/release/libomnitak_mobile.a \
    -output ../../target/universal-sim/libomnitak_mobile.a

# Create XCFramework
echo "Creating XCFramework..."
cd ../..
rm -rf target/OmniTAKMobile.xcframework

xcodebuild -create-xcframework \
    -library target/aarch64-apple-ios/release/libomnitak_mobile.a \
    -headers crates/omnitak-mobile/include \
    -library target/universal-sim/libomnitak_mobile.a \
    -headers crates/omnitak-mobile/include \
    -output target/OmniTAKMobile.xcframework

echo "XCFramework created at target/OmniTAKMobile.xcframework"

# Copy to module location
echo "Copying to module location..."
rm -rf modules/omnitak_mobile/ios/native/OmniTAKMobile.xcframework
cp -R target/OmniTAKMobile.xcframework modules/omnitak_mobile/ios/native/

echo "Build complete!"
