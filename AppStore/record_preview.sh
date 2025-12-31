#!/bin/bash
# OmniTAK App Store Preview (Video) Recorder
# Usage: ./record_preview.sh [name] [device_size]
# Press Ctrl+C to stop recording
#
# App Store Preview Requirements:
# - Format: H.264, 30fps
# - Duration: 15-30 seconds recommended
# - 6.5": 1242 × 2688 or 2688 × 1242
# - 6.7": 1284 × 2778 or 2778 × 1284

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="${1:-preview}"
SIZE="${2:-6.7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ "$SIZE" = "6.5" ]; then
    OUTPUT_DIR="$SCRIPT_DIR/Previews/6.5-inch"
elif [ "$SIZE" = "6.7" ]; then
    OUTPUT_DIR="$SCRIPT_DIR/Previews/6.7-inch"
else
    echo "Invalid size. Use 6.5 or 6.7"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
FILENAME="${NAME}_${TIMESTAMP}.mp4"

echo "🎬 Recording App Preview..."
echo "   Output: $OUTPUT_DIR/$FILENAME"
echo "   Press Ctrl+C to stop recording"
echo ""

# Record video from simulator
xcrun simctl io booted recordVideo --codec=h264 "$OUTPUT_DIR/$FILENAME"

if [ $? -eq 0 ] || [ $? -eq 130 ]; then  # 130 = Ctrl+C
    echo ""
    echo "✓ Preview saved: $OUTPUT_DIR/$FILENAME"
    # Show video info
    if command -v ffprobe &> /dev/null; then
        ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_DIR/$FILENAME" 2>/dev/null | xargs printf "   Duration: %.1f seconds\n"
    fi
else
    echo "✗ Failed to record preview"
    exit 1
fi
