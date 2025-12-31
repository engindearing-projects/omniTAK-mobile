#!/bin/bash
# Run automated App Store screenshot tests
# Usage: ./run_screenshot_tests.sh [test_name]
#
# Examples:
#   ./run_screenshot_tests.sh                    # Run all screenshots
#   ./run_screenshot_tests.sh testMapOnly        # Run specific test
#   ./run_screenshot_tests.sh testMilitaryFeatures

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/../apps/omnitak"
PROJECT="$PROJECT_DIR/OmniTAKMobile.xcodeproj"
SCHEME="OmniTAKMobileUITests"
DEVICE="iPhone 16 Pro Max"
TEST_CLASS="AppStoreScreenshotTests"
TEST_NAME="${1:-testCaptureAllScreenshots}"
RESULT_BUNDLE="$SCRIPT_DIR/TestResults.xcresult"
OUTPUT_DIR="$SCRIPT_DIR/Screenshots/6.7-inch"

echo "📱 OmniTAK App Store Screenshot Automation"
echo "==========================================="
echo ""
echo "Project: $PROJECT"
echo "Device:  $DEVICE"
echo "Test:    $TEST_CLASS/$TEST_NAME"
echo ""

# Clean previous results
rm -rf "$RESULT_BUNDLE"

# Ensure simulator is booted
echo "🔄 Checking simulator..."
BOOTED=$(xcrun simctl list devices | grep "iPhone 16 Pro Max" | grep "Booted")
if [ -z "$BOOTED" ]; then
    echo "   Booting iPhone 16 Pro Max..."
    xcrun simctl boot "iPhone 16 Pro Max" 2>/dev/null || true
    sleep 3
fi
echo "   ✓ Simulator ready"

# Set status bar for clean screenshots
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
echo "🧪 Running screenshot tests..."
echo ""

# Run the UI tests
xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -only-testing:"OmniTAKMobileUITests/$TEST_CLASS/$TEST_NAME" \
    -resultBundlePath "$RESULT_BUNDLE" \
    2>&1 | grep -E "(Test Case|✓|✗|📸|error:|passed|failed)"

TEST_RESULT=${PIPESTATUS[0]}

# Reset status bar
xcrun simctl status_bar booted clear

# Extract screenshots from xcresult bundle
if [ -d "$RESULT_BUNDLE" ]; then
    echo ""
    echo "📦 Extracting screenshots from test results..."
    mkdir -p "$OUTPUT_DIR"

    # Get all attachment IDs
    xcrun xcresulttool get --path "$RESULT_BUNDLE" --format json 2>/dev/null | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    def find_attachments(obj, path=''):
        if isinstance(obj, dict):
            if obj.get('_type', {}).get('_name') == 'ActionTestAttachment':
                filename = obj.get('filename', {}).get('_value', 'screenshot')
                payload_ref = obj.get('payloadRef', {}).get('id', {}).get('_value')
                if payload_ref and 'png' in filename.lower():
                    print(f'{payload_ref}|{filename}')
            for k, v in obj.items():
                find_attachments(v, f'{path}.{k}')
        elif isinstance(obj, list):
            for i, item in enumerate(obj):
                find_attachments(item, f'{path}[{i}]')
    find_attachments(data)
except Exception as e:
    pass
" | while IFS='|' read -r ref_id filename; do
        if [ -n "$ref_id" ]; then
            # Export attachment
            xcrun xcresulttool get --path "$RESULT_BUNDLE" --id "$ref_id" --format raw > "$OUTPUT_DIR/$filename" 2>/dev/null
            if [ -s "$OUTPUT_DIR/$filename" ]; then
                echo "   ✓ $filename"
            fi
        fi
    done
fi

echo ""
if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ Screenshot tests completed!"
    echo ""
    echo "Screenshots saved to: $OUTPUT_DIR"
    ls -la "$OUTPUT_DIR"/*.png 2>/dev/null | head -15
else
    echo "⚠️  Tests finished with issues."
    echo ""
    echo "Check $RESULT_BUNDLE for details."
    echo "Open with: open $RESULT_BUNDLE"
fi
