#!/bin/bash
# Resize screenshots to exact App Store dimensions
# Usage: ./resize_screenshots.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT_DIR="$SCRIPT_DIR/Screenshots/6.7-inch"
OUTPUT_DIR="$SCRIPT_DIR/Screenshots/6.7-inch-resized"

# App Store required dimensions for 6.7" display
TARGET_WIDTH=1284
TARGET_HEIGHT=2778

echo "📐 Resizing screenshots to ${TARGET_WIDTH}x${TARGET_HEIGHT}"
echo ""

mkdir -p "$OUTPUT_DIR"

for f in "$INPUT_DIR"/*.png; do
    if [ -f "$f" ]; then
        filename=$(basename "$f")
        echo "   Processing: $filename"

        # Resize using sips (macOS built-in)
        sips -z $TARGET_HEIGHT $TARGET_WIDTH "$f" --out "$OUTPUT_DIR/$filename" 2>/dev/null

        # Verify
        new_dims=$(sips -g pixelWidth -g pixelHeight "$OUTPUT_DIR/$filename" 2>/dev/null | grep pixel | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
        echo "      ✓ Resized to: $new_dims"
    fi
done

echo ""
echo "✅ Resized screenshots saved to: $OUTPUT_DIR"
echo ""
ls -lh "$OUTPUT_DIR"
