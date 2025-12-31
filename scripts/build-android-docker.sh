#!/bin/bash
set -e

# OmniTAK Android Docker Build Script
# Builds the Android APK using Docker on macOS

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  OmniTAK Android - Docker Build${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    echo "Please start Docker Desktop and try again"
    exit 1
fi

echo -e "${GREEN}✓ Docker is running${NC}"

# Build Docker image if needed
echo -e "\n${YELLOW}Building Docker image...${NC}"
docker-compose build android-builder

# Run the build
echo -e "\n${YELLOW}Building Rust native libraries...${NC}"
docker-compose run --rm android-builder bash -c "
    cd /workspace/crates/omnitak-mobile && \
    export NDK_PATH=/opt/android-sdk/ndk-bundle && \
    export TOOLCHAIN_PATH=\$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin && \
    echo 'Building for aarch64-linux-android...' && \
    CC_aarch64_linux_android=\$TOOLCHAIN_PATH/aarch64-linux-android21-clang \
    AR_aarch64_linux_android=\$TOOLCHAIN_PATH/llvm-ar \
    cargo build --release --target aarch64-linux-android && \
    echo 'Building for armv7-linux-androideabi...' && \
    CC_armv7_linux_androideabi=\$TOOLCHAIN_PATH/armv7a-linux-androideabi21-clang \
    AR_armv7_linux_androideabi=\$TOOLCHAIN_PATH/llvm-ar \
    cargo build --release --target armv7-linux-androideabi && \
    echo 'Building for x86_64-linux-android...' && \
    CC_x86_64_linux_android=\$TOOLCHAIN_PATH/x86_64-linux-android21-clang \
    AR_x86_64_linux_android=\$TOOLCHAIN_PATH/llvm-ar \
    cargo build --release --target x86_64-linux-android && \
    echo 'Building for i686-linux-android...' && \
    CC_i686_linux_android=\$TOOLCHAIN_PATH/i686-linux-android21-clang \
    AR_i686_linux_android=\$TOOLCHAIN_PATH/llvm-ar \
    cargo build --release --target i686-linux-android
"

echo -e "\n${YELLOW}Copying native libraries...${NC}"
docker-compose run --rm android-builder bash -c "
    mkdir -p /workspace/modules/omnitak_mobile/android/native/lib/{arm64-v8a,armeabi-v7a,x86_64,x86} && \
    cp /workspace/crates/target/aarch64-linux-android/release/libomnitak_mobile.a /workspace/modules/omnitak_mobile/android/native/lib/arm64-v8a/ && \
    cp /workspace/crates/target/armv7-linux-androideabi/release/libomnitak_mobile.a /workspace/modules/omnitak_mobile/android/native/lib/armeabi-v7a/ && \
    cp /workspace/crates/target/x86_64-linux-android/release/libomnitak_mobile.a /workspace/modules/omnitak_mobile/android/native/lib/x86_64/ && \
    cp /workspace/crates/target/i686-linux-android/release/libomnitak_mobile.a /workspace/modules/omnitak_mobile/android/native/lib/x86/ && \
    echo '✓ Native libraries copied'
"

echo -e "\n${YELLOW}Building Android APK with Bazel...${NC}"
docker-compose run --rm android-builder bash -c "
    cd /workspace && \
    bazel build //apps/omnitak_android
"

# Check if APK was created
if docker-compose run --rm android-builder test -f /workspace/bazel-bin/apps/omnitak_android/omnitak_android.apk; then
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  BUILD SUCCESSFUL!${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"

    # Copy APK to output directory
    mkdir -p build-output
    docker-compose run --rm android-builder cp /workspace/bazel-bin/apps/omnitak_android/omnitak_android.apk /workspace/build-output/

    echo -e "\n${GREEN}✓ APK location: build-output/omnitak_android.apk${NC}"
    ls -lh build-output/omnitak_android.apk
else
    echo -e "\n${RED}✗ Build failed - APK not found${NC}"
    exit 1
fi
