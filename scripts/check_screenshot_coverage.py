#!/usr/bin/env python3
"""Warns when a top-level `sidebar-tab-*` screen exists in source but scripts/screenshot_manifest.json
doesn't know about it yet — the actual fix for "features get added and nobody remembers to add
a matching screenshot" (docs/RELEASE_SCREENSHOTS_PLAN.md's stated goal).

Scoped deliberately to top-level tabs, not every sub-state the manifest lists — that catches
the main failure mode (a whole new tab shipped with no screenshot at all) without needing this
script to understand every feature's internal navigation. Advisory only (exit 0 always, same as
scripts/check_standards.py) — a stale manifest entry pointing at a renamed/removed identifier is
also reported, since that's just as much a drift signal as a missing one.

Run standalone from the repo root:
    python3 scripts/check_screenshot_coverage.py
"""
import json
import os
import re
import sys

SOURCE_ROOT = "StarHubTH"
MANIFEST_PATH = os.path.join("scripts", "screenshot_manifest.json")

# Two distinct sources of top-level tab identifiers in this codebase:
#   1. Home/Updates (MainSidebarView.swift) carry a literal `.accessibilityIdentifier("sidebar-tab-X")`.
#   2. Every other tab goes through `SidebarNavItem(tab: "X", ...)`, whose identifier
#      (`SidebarNavItem.swift:38`, `.accessibilityIdentifier("sidebar-tab-\(tab)")`) is built at
#      runtime from that `tab:` argument — a plain grep for the interpolated string finds nothing,
#      so this has to match the `tab:` literal at each call site instead.
LITERAL_IDENTIFIER_PATTERN = re.compile(r'\.accessibilityIdentifier\("(sidebar-tab-[A-Za-z]+)"\)')
SIDEBAR_NAV_ITEM_TAB_PATTERN = re.compile(r'tab:\s*"([A-Za-z]+)"')


def find_tab_identifiers_in_source():
    found = {}
    for root, _dirs, files in os.walk(SOURCE_ROOT):
        for filename in files:
            if not filename.endswith(".swift"):
                continue
            path = os.path.join(root, filename)
            with open(path, encoding="utf-8") as file:
                for lineno, line in enumerate(file, start=1):
                    literal_match = LITERAL_IDENTIFIER_PATTERN.search(line)
                    if literal_match:
                        found[literal_match.group(1)] = f"{path}:{lineno}"
                        continue
                    nav_item_match = SIDEBAR_NAV_ITEM_TAB_PATTERN.search(line)
                    if nav_item_match:
                        found[f"sidebar-tab-{nav_item_match.group(1)}"] = f"{path}:{lineno}"
    return found


def find_tab_identifiers_in_manifest():
    with open(MANIFEST_PATH, encoding="utf-8") as file:
        manifest = json.load(file)
    referenced = set()
    for screen in manifest["screens"]:
        for step in screen["navigation"]:
            identifier = step.get("identifier", "")
            if identifier.startswith("sidebar-tab-"):
                referenced.add(identifier)
    return referenced


def check_screenshot_coverage():
    in_source = find_tab_identifiers_in_source()
    in_manifest = find_tab_identifiers_in_manifest()

    missing_from_manifest = sorted(set(in_source) - in_manifest)
    stale_in_manifest = sorted(in_manifest - set(in_source))

    findings = []
    for identifier in missing_from_manifest:
        findings.append(
            f"{in_source[identifier]}: '{identifier}' exists in source but no entry in "
            f"{MANIFEST_PATH} references it — a screen with no screenshot coverage plan."
        )
    for identifier in stale_in_manifest:
        findings.append(
            f"{MANIFEST_PATH}: references '{identifier}', which no longer exists in {SOURCE_ROOT}/ "
            f"— stale manifest entry, the screen it pointed to was renamed or removed."
        )

    if findings:
        print(f"[WARN] check_screenshot_coverage: {len(findings)} finding(s):")
        for finding in findings:
            print(f"  - {finding}")
    else:
        print("[OK] check_screenshot_coverage: every sidebar-tab-* identifier is covered.")
    return 0


if __name__ == "__main__":
    sys.exit(check_screenshot_coverage())
