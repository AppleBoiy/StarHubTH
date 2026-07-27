#!/usr/bin/env python3
"""Runs ScreenshotCaptureTool (StarHubTHUITests) with dynamic, per-invocation environment
variables — output dir, manifest path, targets path.

`xcodebuild test` does not inherit the invoking shell's environment into the test process;
it uses the scheme/test-plan's own configured environment instead (the same gap
docs/SWIFT_STANDARDS.md documents for STARHUB_SKIP_LIVE_TESTS — plain shell `KEY=value
xcodebuild test ...` silently does nothing). Fast/Unit/Integration bake a fixed value into
TestPlans/*.xctestplan's `environmentVariableEntries` for exactly this reason, but this
tool's values (output dir, targets file) are genuinely different per run, not something to
hardcode into a committed plan file. This script patches TestPlans/ScreenshotCapture.xctestplan
in place with the requested values, runs the test, then restores the plan file's original
committed content — so the repo tree is clean again afterward regardless of outcome.

Run from the repo root — output into screenshots_captured/ (gitignored, see .gitignore), not
/tmp: a temp dir means a killed/crashed run leaves nothing to inspect or resume a diff report
against, and the checked-in scripts/screenshot_diff_report.py already defaults its examples to
this same path.
    python3 scripts/run_screenshot_capture.py --output-dir screenshots_captured/en
    python3 scripts/run_screenshot_capture.py --output-dir screenshots_captured/th \
        --targets scripts/screenshot_targets.local.json
"""
import argparse
import json
import os
import subprocess
import sys

TEST_PLAN_PATH = os.path.join("TestPlans", "ScreenshotCapture.xctestplan")


def run_capture(output_dir, manifest_path, targets_path):
    with open(TEST_PLAN_PATH, encoding="utf-8") as f:
        original_text = f.read()
    plan = json.loads(original_text)

    entries = [
        {"key": "STARHUB_SCREENSHOT_OUTPUT_DIR", "value": os.path.abspath(output_dir)},
        {"key": "STARHUB_SCREENSHOT_MANIFEST_PATH", "value": os.path.abspath(manifest_path)},
    ]
    if targets_path:
        entries.append({"key": "STARHUB_SCREENSHOT_TARGETS_PATH", "value": os.path.abspath(targets_path)})
    plan.setdefault("defaultOptions", {})["environmentVariableEntries"] = entries

    os.makedirs(output_dir, exist_ok=True)

    try:
        with open(TEST_PLAN_PATH, "w", encoding="utf-8") as f:
            json.dump(plan, f, indent=2)
            f.write("\n")

        result = subprocess.run([
            "xcodebuild", "test",
            "-project", "StarHubTH.xcodeproj",
            "-scheme", "StarHubTH",
            "-configuration", "Debug",
            "-destination", "platform=macOS",
            "-testPlan", "ScreenshotCapture",
        ])
    finally:
        with open(TEST_PLAN_PATH, "w", encoding="utf-8") as f:
            f.write(original_text)

    captured = [f for f in os.listdir(output_dir) if f.lower().endswith(".png")] if os.path.isdir(output_dir) else []
    print(f"[INFO] {len(captured)} screenshot(s) written to {output_dir}")
    return result.returncode


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run ScreenshotCaptureTool with dynamic env vars xcodebuild won't otherwise pass through.")
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--manifest", default=os.path.join("scripts", "screenshot_manifest.json"))
    parser.add_argument("--targets", default=None, help="Path to a local targets file (see scripts/screenshot_targets.example.json). Omit to skip entries with placeholders.")
    args = parser.parse_args()
    sys.exit(run_capture(args.output_dir, args.manifest, args.targets))
