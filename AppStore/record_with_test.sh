#!/bin/bash
# Record App Preview video while running UI test
# Usage: ./record_with_test.sh [test_name]
#
# Examples:
#   ./record_with_test.sh testCorePreview      # Core functionality preview
#   ./record_with_test.sh testTeamPreview      # Team coordination preview
#   ./record_with_test.sh testTacticalPreview  # Tactical features preview

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../apps/omnitak"
PROJECT="$PROJECT_DIR/OmniTAKMobile.xcodeproj"
SCHEME="OmniTAKMobileUITests"
DEVICE="iPhone 16 Pro Max"
TEST_CLASS="AppPreviewRecordingTests"
TEST_NAME="${1:-testCorePreview}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="$SCRIPT_DIR/Previews/6.7-inch"
OUTPUT_FILE="$OUTPUT_DIR/${TEST_NAME}_${TIMESTAMP}.mp4"

echo "🎬 OmniTAK App Preview Recording"
echo "================================="
echo ""
echo "Test: $TEST_CLASS/$TEST_NAME"
echo "Output: $OUTPUT_FILE"
echo ""

mkdir -p "$OUTPUT_DIR"

# Ensure simulator is booted
echo "🔄 Checking simulator..."
BOOTED=$(xcrun simctl list devices | grep "iPhone 16 Pro Max" | grep "Booted")
if [ -z "$BOOTED" ]; then
    echo "   Booting iPhone 16 Pro Max..."
    xcrun simctl boot "iPhone 16 Pro Max" 2>/dev/null || true
    sleep 3
fi

# Set clean status bar
echo "🎨 Setting clean status bar..."
xcrun simctl status_bar booted override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularMode active \
    --cellularBars 4 \
    --wifiBars 3 \
    --operatorName ""

echo ""
echo "🎥 Starting recording..."

# Start recording in background
xcrun simctl io booted recordVideo --codec=h264 "$OUTPUT_FILE" &
RECORD_PID=$!
sleep 1

echo "🧪 Running test: $TEST_NAME"
echo ""

# Run the UI test
xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -only-testing:"OmniTAKMobileUITests/$TEST_CLASS/$TEST_NAME" \
    2>&1 | grep -E "(Test Case|passed|failed)"

# Stop recording
echo ""
echo "⏹️  Stopping recording..."
kill -INT $RECORD_PID 2>/dev/null
wait $RECORD_PID 2>/dev/null

# Reset status bar
xcrun simctl status_bar booted clear

echo ""
if [ -f "$OUTPUT_FILE" ]; then
    # Get video info
    DURATION=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_FILE" 2>/dev/null | xargs printf "%.1f")
    SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')

    echo "✅ App Preview recorded!"
    echo ""
    echo "   File: $OUTPUT_FILE"
    echo "   Duration: ${DURATION}s"
    echo "   Size: $SIZE"
    echo ""
    echo "   App Store requirement: 15-30 seconds"

    if command -v open &> /dev/null; then
        echo ""
        read -p "Open video in QuickTime? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open "$OUTPUT_FILE"
        fi
    fi
else
    echo "❌ Recording failed"
fi
