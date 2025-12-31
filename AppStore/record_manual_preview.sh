#!/bin/bash
# Manual App Preview Recording
# Usage: ./record_manual_preview.sh [preview_name]
#
# This script starts recording, then you manually interact with the app.
# Press Ctrl+C when done (15-30 seconds recommended).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="${1:-app_preview}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="$SCRIPT_DIR/Previews/6.7-inch"
OUTPUT_FILE="$OUTPUT_DIR/${NAME}_${TIMESTAMP}.mp4"

mkdir -p "$OUTPUT_DIR"

echo "🎬 OmniTAK App Preview Recording"
echo "================================="
echo ""
echo "Output: $OUTPUT_FILE"
echo ""

# Set clean status bar
echo "🎨 Setting clean status bar..."
xcrun simctl status_bar booted override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularMode active \
    --cellularBars 4 \
    --wifiBars 3 \
    --operatorName "" 2>/dev/null

echo ""
echo "📱 Instructions:"
echo "   1. The simulator should be open with OmniTAK running"
echo "   2. Recording will start in 3 seconds..."
echo "   3. Demonstrate the features (15-30 seconds)"
echo "   4. Press Ctrl+C to stop recording"
echo ""

# Countdown
for i in 3 2 1; do
    echo "   Starting in $i..."
    sleep 1
done

echo ""
echo "🔴 RECORDING... (Press Ctrl+C to stop)"
echo ""

# Record
xcrun simctl io booted recordVideo --codec=h264 "$OUTPUT_FILE"

# Cleanup
xcrun simctl status_bar booted clear 2>/dev/null

echo ""
if [ -f "$OUTPUT_FILE" ]; then
    DURATION=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_FILE" 2>/dev/null | xargs printf "%.1f" 2>/dev/null)
    SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')

    echo "✅ Preview recorded!"
    echo ""
    echo "   File: $OUTPUT_FILE"
    echo "   Duration: ${DURATION:-?}s (target: 15-30s)"
    echo "   Size: $SIZE"
    echo ""

    # Check duration
    if command -v bc &> /dev/null && [ -n "$DURATION" ]; then
        if (( $(echo "$DURATION < 15" | bc -l) )); then
            echo "   ⚠️  Video may be too short (< 15s)"
        elif (( $(echo "$DURATION > 30" | bc -l) )); then
            echo "   ⚠️  Video may be too long (> 30s)"
        else
            echo "   ✓ Duration is within App Store requirements"
        fi
    fi
else
    echo "❌ Recording failed"
fi
