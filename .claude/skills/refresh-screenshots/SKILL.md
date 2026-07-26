---
name: refresh-screenshots
description: Refresh StarHubTH's release screenshots (README + Nexus listing) against the maintainer's own real, populated app state — captures every Core-tier screen from scripts/screenshot_manifest.json, reports what changed, never auto-commits. Use when the maintainer asks to update/refresh screenshots before a release, or after adding a feature that should be documented visually.
---

# Refresh release screenshots

Manual, pre-release step — same posture as running the `Integration`/`UI`/`UILive` test plans locally: deliberate, human-triggered, never automatic, never wired into CI. See `docs/RELEASE_SCREENSHOTS_PLAN.md` for the full rationale (or `docs/RELEASING.md` if that plan doc has since been retired).

## Precondition — check this first, don't skip it

This drives the **real** `StarHubTH.app` against the **real** `gameDir` already configured on this machine (not the isolated `UITestFixture` state every other UI test uses). If the maintainer hasn't got a real, populated setup — actual installed mods, at least one save, ideally a profile and an imported Nexus collection — stop and say so. Capturing against an empty/default app state produces empty, unconvincing screenshots, which is worse than not running this at all.

## Steps

1. **Confirm/create the targets file.** `scripts/screenshot_targets.local.json` (gitignored — see `scripts/screenshot_targets.example.json` for the shape) names which of the maintainer's real saves/mods/profiles/Thai mods to open for entries that need one (`saveFolderName`, `modFolderName`, `groupFolderName`, `profileId`, `modName`). If it doesn't exist yet, ask the maintainer which real entities to use rather than guessing — a wrong guess means captured screenshots of the wrong mod/save.

2. **Build the app fresh:**
   ```bash
   xcodebuild build -project StarHubTH.xcodeproj -scheme StarHubTH -configuration Debug
   ```

3. **Run the capture tool**, once per language (the tool captures whatever language the app is currently set to — flip it via the real Settings screen or `defaults write com.appleboiy.StarHubTH currentLanguage en|th` between runs):
   ```bash
   mkdir -p /tmp/starhubth-screenshots/en
   STARHUB_SCREENSHOT_OUTPUT_DIR=/tmp/starhubth-screenshots/en \
   STARHUB_SCREENSHOT_TARGETS_PATH="$(pwd)/scripts/screenshot_targets.local.json" \
   STARHUB_SCREENSHOT_MANIFEST_PATH="$(pwd)/scripts/screenshot_manifest.json" \
   xcodebuild test -project StarHubTH.xcodeproj -scheme StarHubTH -configuration Debug \
     -destination 'platform=macOS' -testPlan ScreenshotCapture
   ```
   Repeat with `currentLanguage th` and a `/th` output dir. Check the test log for `[ScreenshotCaptureTool]` failure lines — a missing target/precondition shows up there, not as a hard test failure (the test only fails if *every* Core screen failed).

4. **Run the coverage check** — catches any screen the manifest doesn't know about yet:
   ```bash
   python3 scripts/check_screenshot_coverage.py
   ```
   If it warns about a missing tab, that's a real gap — add an entry to `scripts/screenshot_manifest.json` before continuing, don't just ignore the warning.

5. **Run the diff report** against the checked-in screenshots, per language:
   ```bash
   python3 scripts/screenshot_diff_report.py --new /tmp/starhubth-screenshots/en --existing screenshots/en
   python3 scripts/screenshot_diff_report.py --new /tmp/starhubth-screenshots/th --existing screenshots/th
   ```

6. **Show the maintainer the report.** Never copy new PNGs into `screenshots/en`/`screenshots/th` or touch the README yourself without asking — same rule as any other file this assistant doesn't own the content of. Let the maintainer decide which `+`/`~` entries are worth keeping, then copy those specific files in and update `README.md`/`README_EN.md`'s `<img>` references if new slugs were added.

## If something breaks

- **Element not found / capture fails for one screen**: usually a stale `screenshot_targets.local.json` entry (renamed/deleted save or mod) or a precondition not met (e.g. `updates` needs a real out-of-date mod present). Check the `precondition` field on that entry in `scripts/screenshot_manifest.json`.
- **Unresolved placeholder error**: `scripts/screenshot_targets.local.json` is missing a key a manifest entry's `placeholders` list requires.
- **The whole tool skips immediately**: `STARHUB_SCREENSHOT_OUTPUT_DIR` wasn't set — required, on purpose, so this can never fire as part of a normal test run.
