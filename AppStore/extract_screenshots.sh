#!/bin/bash
# Extract screenshots from xcresult bundle
# Usage: ./extract_screenshots.sh [result_bundle_path]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULT_BUNDLE="${1:-$SCRIPT_DIR/TestResults.xcresult}"
OUTPUT_DIR="$SCRIPT_DIR/Screenshots/6.7-inch"

if [ ! -d "$RESULT_BUNDLE" ]; then
    echo "❌ No result bundle found at: $RESULT_BUNDLE"
    exit 1
fi

echo "📦 Extracting screenshots from: $RESULT_BUNDLE"
echo ""

mkdir -p "$OUTPUT_DIR"

# Extract PNG files > 1MB from the Data directory
cd "$RESULT_BUNDLE/Data"
i=1
for f in $(ls -S); do
    size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
    if [ "$size" -gt 1000000 ]; then
        # Check if it's a PNG
        if file "$f" | grep -q "PNG image"; then
            cp "$f" "$OUTPUT_DIR/screenshot_$(printf %02d $i).png"
            echo "   ✓ screenshot_$(printf %02d $i).png ($(echo $size | awk '{printf "%.1f MB", $1/1024/1024}'))"
            i=$((i+1))
        fi
    fi
done

echo ""
echo "✅ Extracted $((i-1)) screenshots to: $OUTPUT_DIR"
echo ""

# Show dimensions
echo "📐 Dimensions:"
for f in "$OUTPUT_DIR"/screenshot_*.png; do
    if [ -f "$f" ]; then
        dims=$(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | grep pixel | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
        echo "   $(basename "$f"): $dims"
    fi
done
