#!/bin/bash
# Resize App Previews to App Store dimensions
# 6.5" display: 886 × 1920px (portrait) or 1920 × 886px (landscape)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT_DIR="$SCRIPT_DIR/Previews/6.5-inch"
OUTPUT_DIR="$SCRIPT_DIR/Previews/6.5-inch-resized"

# App Store required dimensions (landscape for our videos)
TARGET_WIDTH=1920
TARGET_HEIGHT=886

echo "🎬 Resizing App Previews to ${TARGET_WIDTH}x${TARGET_HEIGHT}"
echo ""

if ! command -v ffmpeg &> /dev/null; then
    echo "❌ ffmpeg not found. Install with: brew install ffmpeg"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

for f in "$INPUT_DIR"/*demo*.mp4; do
    if [ -f "$f" ]; then
        filename=$(basename "$f")
        echo "   Processing: $filename"

        # Scale to exact target dimensions
        ffmpeg -i "$f" \
            -vf "scale=${TARGET_WIDTH}:${TARGET_HEIGHT}" \
            -c:v h264 \
            -b:v 8M \
            -c:a aac \
            -y \
            "$OUTPUT_DIR/$filename" 2>/dev/null

        if [ -f "$OUTPUT_DIR/$filename" ]; then
            size=$(ls -lh "$OUTPUT_DIR/$filename" | awk '{print $5}')
            echo "      ✓ ${TARGET_WIDTH}x${TARGET_HEIGHT} | ${size}"
        fi
    fi
done

echo ""
echo "✅ Resized previews saved to: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"
