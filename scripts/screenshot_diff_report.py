#!/usr/bin/env python3
"""Reports how newly-captured screenshots differ from the checked-in ones — never overwrites
or commits anything itself (docs/RELEASE_SCREENSHOTS_PLAN.md's stated caution level: a human
reviews and pastes/commits, same as every other release step in this repo).

Perceptual, not pixel-exact: resizes both images to a small thumbnail and compares average
pixel difference, so a moved cursor or a single animation frame doesn't register as "changed"
the way a byte-for-byte diff would. This is a coarse signal for "should a human look at this,"
not a precision tool — a low score can still hide a real, small UI regression; always eyeball
anything the report calls DIFFERENT before trusting it.

Run standalone from the repo root, after ScreenshotCaptureTool has written new PNGs somewhere
(e.g. a temp output dir, never directly into screenshots/en or screenshots/th):
    python3 scripts/screenshot_diff_report.py --new screenshots_captured/en --existing screenshots/en
"""
import argparse
import os
import sys

try:
    from PIL import Image, ImageChops
except ImportError:
    Image = None
    ImageChops = None

THUMBNAIL_SIZE = (256, 256)
DIFFERENCE_THRESHOLD = 0.02  # fraction of average pixel-value difference, 0..1


def perceptual_difference(existing_path, new_path):
    with Image.open(existing_path) as existing_image, Image.open(new_path) as new_image:
        existing_thumb = existing_image.convert("RGB").resize(THUMBNAIL_SIZE)
        new_thumb = new_image.convert("RGB").resize(THUMBNAIL_SIZE)
        diff = ImageChops.difference(existing_thumb, new_thumb)
        histogram = diff.histogram()
        channels = 3
        pixel_count = THUMBNAIL_SIZE[0] * THUMBNAIL_SIZE[1] * channels
        weighted_sum = sum(value * (index % 256) for index, value in enumerate(histogram))
        return weighted_sum / (pixel_count * 255)


def generate_report(new_dir, existing_dir):
    if Image is None:
        print("[ERROR] Pillow is required for screenshot_diff_report.py (pip install Pillow).")
        return 1

    new_files = {f for f in os.listdir(new_dir) if f.lower().endswith(".png")} if os.path.isdir(new_dir) else set()
    existing_files = {f for f in os.listdir(existing_dir) if f.lower().endswith(".png")} if os.path.isdir(existing_dir) else set()

    added = sorted(new_files - existing_files)
    removed = sorted(existing_files - new_files)
    shared = sorted(new_files & existing_files)

    changed = []
    unchanged = []
    for filename in shared:
        difference = perceptual_difference(
            os.path.join(existing_dir, filename),
            os.path.join(new_dir, filename),
        )
        (changed if difference > DIFFERENCE_THRESHOLD else unchanged).append((filename, difference))

    print(f"[REPORT] {new_dir} vs {existing_dir}")
    print(f"  New (not in {existing_dir} yet): {len(added)}")
    for filename in added:
        print(f"    + {filename}")
    print(f"  Removed (in {existing_dir}, missing from {new_dir}): {len(removed)}")
    for filename in removed:
        print(f"    - {filename}")
    print(f"  Changed ({DIFFERENCE_THRESHOLD:.0%}+ perceptual difference): {len(changed)}")
    for filename, difference in sorted(changed, key=lambda item: -item[1]):
        print(f"    ~ {filename} ({difference:.1%} different)")
    print(f"  Unchanged: {len(unchanged)}")

    print()
    print("Nothing was overwritten or committed — review the '+'/'~' entries above, then copy")
    print(f"the ones worth keeping from {new_dir} into {existing_dir} yourself.")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Report differences between newly-captured and checked-in screenshots.")
    parser.add_argument("--new", required=True, help="Directory of freshly-captured PNGs (e.g. from ScreenshotCaptureTool).")
    parser.add_argument("--existing", required=True, help="Directory of checked-in PNGs to compare against (e.g. screenshots/en).")
    args = parser.parse_args()
    sys.exit(generate_report(args.new, args.existing))
