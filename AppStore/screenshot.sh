#!/bin/bash
# OmniTAK App Store Screenshot Helper
# Usage: ./screenshot.sh [name] [device_size]
# Example: ./screenshot.sh map_view 6.7

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="${1:-screenshot}"
SIZE="${2:-6.7}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ "$SIZE" = "6.5" ]; then
    OUTPUT_DIR="$SCRIPT_DIR/Screenshots/6.5-inch"
elif [ "$SIZE" = "6.7" ]; then
    OUTPUT_DIR="$SCRIPT_DIR/Screenshots/6.7-inch"
else
    echo "Invalid size. Use 6.5 or 6.7"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
FILENAME="${NAME}_${TIMESTAMP}.png"

xcrun simctl io booted screenshot "$OUTPUT_DIR/$FILENAME"

if [ $? -eq 0 ]; then
    echo "✓ Screenshot saved: $OUTPUT_DIR/$FILENAME"
    # Get dimensions
    sips -g pixelWidth -g pixelHeight "$OUTPUT_DIR/$FILENAME" 2>/dev/null | tail -2
else
    echo "✗ Failed to capture screenshot"
    exit 1
fi
