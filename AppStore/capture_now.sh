#!/bin/bash
# Quick screenshot capture from simulator
# Usage: ./capture_now.sh [name]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="${1:-screenshot}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="$SCRIPT_DIR/Screenshots/6.7-inch"
OUTPUT_FILE="$OUTPUT_DIR/${NAME}_${TIMESTAMP}.png"

mkdir -p "$OUTPUT_DIR"

# Set clean status bar
xcrun simctl status_bar booted override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularMode active \
    --cellularBars 4 \
    --wifiBars 3 \
    --operatorName "" 2>/dev/null

# Capture
xcrun simctl io booted screenshot "$OUTPUT_FILE"

if [ -f "$OUTPUT_FILE" ]; then
    # Get dimensions
    DIMS=$(sips -g pixelWidth -g pixelHeight "$OUTPUT_FILE" 2>/dev/null | grep pixel | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
    SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
    echo "✓ $OUTPUT_FILE"
    echo "  ${DIMS} | ${SIZE}"
fi
