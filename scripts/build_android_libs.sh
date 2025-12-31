#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Building Android Native Libraries${NC}"

# NDK paths
NDK_PATH="/Users/iesouskurios/Library/Android/sdk/ndk/27.1.12297006"
TOOLCHAIN_PATH="$NDK_PATH/toolchains/llvm/prebuilt/darwin-x86_64/bin"

# Navigate to crates directory
cd ~/omniTAK-mobile/crates/omnitak-mobile

echo -e "${YELLOW}Building for aarch64-linux-android...${NC}"
CC_aarch64_linux_android="$TOOLCHAIN_PATH/aarch64-linux-android21-clang" \
AR_aarch64_linux_android="$TOOLCHAIN_PATH/llvm-ar" \
cargo build --release --target aarch64-linux-android

echo -e "${YELLOW}Building for armv7-linux-androideabi...${NC}"
CC_armv7_linux_androideabi="$TOOLCHAIN_PATH/armv7a-linux-androideabi21-clang" \
AR_armv7_linux_androideabi="$TOOLCHAIN_PATH/llvm-ar" \
cargo build --release --target armv7-linux-androideabi

echo -e "${YELLOW}Building for x86_64-linux-android...${NC}"
CC_x86_64_linux_android="$TOOLCHAIN_PATH/x86_64-linux-android21-clang" \
AR_x86_64_linux_android="$TOOLCHAIN_PATH/llvm-ar" \
cargo build --release --target x86_64-linux-android

echo -e "${YELLOW}Building for i686-linux-android...${NC}"
CC_i686_linux_android="$TOOLCHAIN_PATH/i686-linux-android21-clang" \
AR_i686_linux_android="$TOOLCHAIN_PATH/llvm-ar" \
cargo build --release --target i686-linux-android

# Copy libraries
echo -e "${YELLOW}Copying libraries...${NC}"
OUTPUT_DIR="~/omniTAK-mobile/modules/omnitak_mobile/android/native/lib"
mkdir -p "$OUTPUT_DIR"/{arm64-v8a,armeabi-v7a,x86_64,x86}

cp ~/omniTAK-mobile/crates/target/aarch64-linux-android/release/libomnitak_mobile.a "$OUTPUT_DIR/arm64-v8a/"
cp ~/omniTAK-mobile/crates/target/armv7-linux-androideabi/release/libomnitak_mobile.a "$OUTPUT_DIR/armeabi-v7a/"
cp ~/omniTAK-mobile/crates/target/x86_64-linux-android/release/libomnitak_mobile.a "$OUTPUT_DIR/x86_64/"
cp ~/omniTAK-mobile/crates/target/i686-linux-android/release/libomnitak_mobile.a "$OUTPUT_DIR/x86/"

echo -e "${GREEN}✓ Android libraries built successfully!${NC}"
