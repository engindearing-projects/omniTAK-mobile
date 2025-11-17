#!/usr/bin/env python3
"""
Resize screenshots to Apple's required dimensions for TestFlight
Target: 1284 × 2778px (6.7" iPhone portrait - iPhone 12/13/14 Pro Max)
"""

from PIL import Image
import os

# Required dimensions for 6.7" iPhone (Pro Max models)
TARGET_WIDTH = 1284
TARGET_HEIGHT = 2778

def resize_screenshot(input_path, output_path):
    """Resize screenshot to exact Apple requirements"""
    print(f"Processing: {input_path}")

    # Open image
    img = Image.open(input_path)
    original_size = img.size
    print(f"  Original size: {original_size[0]} × {original_size[1]}px")

    # Calculate aspect ratios
    original_ratio = original_size[0] / original_size[1]
    target_ratio = TARGET_WIDTH / TARGET_HEIGHT

    print(f"  Original ratio: {original_ratio:.4f}")
    print(f"  Target ratio: {target_ratio:.4f}")

    # Resize maintaining aspect ratio, then crop/pad to exact dimensions
    if abs(original_ratio - target_ratio) < 0.001:
        # Aspect ratios match, simple resize
        resized = img.resize((TARGET_WIDTH, TARGET_HEIGHT), Image.Resampling.LANCZOS)
    else:
        # Need to scale and crop
        # Scale to fit height
        scale = TARGET_HEIGHT / original_size[1]
        new_width = int(original_size[0] * scale)
        new_height = TARGET_HEIGHT

        # Resize
        resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

        # Crop to target width (center crop)
        left = (new_width - TARGET_WIDTH) // 2
        resized = resized.crop((left, 0, left + TARGET_WIDTH, TARGET_HEIGHT))

    # Save
    resized.save(output_path, 'PNG', optimize=True)
    final_size = resized.size
    print(f"  ✅ Saved: {output_path}")
    print(f"  Final size: {final_size[0]} × {final_size[1]}px\n")

def main():
    # Create output directory
    output_dir = "screenshots/testflight"
    os.makedirs(output_dir, exist_ok=True)

    print(f"Resizing screenshots to {TARGET_WIDTH} × {TARGET_HEIGHT}px for TestFlight\n")

    screenshots = [
        ("screenshots/hamburger_menu_tools.png", f"{output_dir}/01_hamburger_menu_tools.png"),
        ("screenshots/landscape_main_view.png", f"{output_dir}/02_main_view.png"),
    ]

    for input_path, output_path in screenshots:
        if os.path.exists(input_path):
            resize_screenshot(input_path, output_path)
        else:
            print(f"⚠️  Not found: {input_path}\n")

    print("=" * 60)
    print("✅ Screenshot resizing complete!")
    print(f"📁 Output directory: {output_dir}")
    print(f"📱 Dimensions: {TARGET_WIDTH} × {TARGET_HEIGHT}px (6.7\" iPhone)")
    print("\nThese screenshots are ready for TestFlight upload!")
    print("\nAccepted dimensions:")
    print("  • 1284 × 2778px (6.7\" portrait) ✅ USED")
    print("  • 2778 × 1284px (6.7\" landscape)")
    print("  • 1242 × 2688px (6.5\" portrait)")
    print("  • 2688 × 1242px (6.5\" landscape)")

if __name__ == "__main__":
    main()
