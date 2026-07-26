#!/usr/bin/env python3
"""Bump StarHubTH's release version per docs/RELEASING.md.

Updates Info.plist (CFBundleShortVersionString + CFBundleVersion) and rolls
CHANGELOG.md's [Unreleased] section into a dated version heading. Does not
commit, tag, or push — review the diff yourself, then:

    git add Info.plist CHANGELOG.md
    git commit -m "release: vX.Y.Z"
    git tag vX.Y.Z
    git push && git push --tags

Usage:
    python3 scripts/bump_version.py patch
    python3 scripts/bump_version.py minor
    python3 scripts/bump_version.py major
    python3 scripts/bump_version.py minor --preview   # 1.1.3 -> 1.2.0-preview.1
    python3 scripts/bump_version.py preview           # 1.2.0-preview.1 -> 1.2.0-preview.2
    python3 scripts/bump_version.py release           # 1.2.0-preview.2 -> 1.2.0
"""
import argparse
import datetime
import plistlib
import re
import sys

INFO_PLIST = "Info.plist"
CHANGELOG = "CHANGELOG.md"

VERSION_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-preview\.(\d+))?$")


def parse_version(version_string):
    match = VERSION_RE.match(version_string)
    if not match:
        sys.exit(
            f"[ERROR] {INFO_PLIST} CFBundleShortVersionString {version_string!r} "
            "is not MAJOR.MINOR.PATCH[-preview.N]"
        )
    major, minor, patch, preview = match.groups()
    return int(major), int(minor), int(patch), (int(preview) if preview else None)


def format_version(major, minor, patch, preview=None):
    base = f"{major}.{minor}.{patch}"
    return f"{base}-preview.{preview}" if preview else base


def next_version(current, kind, want_preview):
    major, minor, patch, preview = parse_version(current)

    if kind == "preview":
        if preview is None:
            sys.exit(
                "[ERROR] 'preview' only advances an existing -preview.N version. "
                "Use patch/minor/major (optionally with --preview) to start a new one."
            )
        return format_version(major, minor, patch, preview + 1)

    if kind == "release":
        if preview is None:
            sys.exit(f"[ERROR] {current} is already a stable release, nothing to finalize.")
        return format_version(major, minor, patch)

    if kind == "patch":
        major, minor, patch = major, minor, patch + 1
    elif kind == "minor":
        major, minor, patch = major, minor + 1, 0
    elif kind == "major":
        major, minor, patch = major + 1, 0, 0
    else:
        raise ValueError(kind)

    return format_version(major, minor, patch, 1 if want_preview else None)


def replace_plist_value(text, key, new_value):
    """Substitute one <string> value in place, byte-for-byte elsewhere.

    Deliberately not a plistlib.load/dump round trip: plistlib re-serializes
    the whole file (alphabetizes keys, rewrites indentation as tabs), which
    would turn every version bump into a full-file diff.
    """
    pattern = re.compile(rf"(<key>{re.escape(key)}</key>\s*\n\s*<string>)([^<]*)(</string>)")
    new_text, count = pattern.subn(lambda m: m.group(1) + new_value + m.group(3), text, count=1)
    if count != 1:
        sys.exit(f"[ERROR] Couldn't find <key>{key}</key> in {INFO_PLIST}")
    return new_text


def bump_plist(new_version):
    with open(INFO_PLIST, "r", encoding="utf-8") as f:
        text = f.read()

    version_match = re.search(r"<key>CFBundleShortVersionString</key>\s*\n\s*<string>([^<]*)</string>", text)
    build_match = re.search(r"<key>CFBundleVersion</key>\s*\n\s*<string>([^<]*)</string>", text)
    if not version_match or not build_match:
        sys.exit(f"[ERROR] Couldn't find CFBundleShortVersionString/CFBundleVersion in {INFO_PLIST}")

    old_version = version_match.group(1)
    old_build = int(build_match.group(1))
    new_build = str(old_build + 1)

    text = replace_plist_value(text, "CFBundleShortVersionString", new_version)
    text = replace_plist_value(text, "CFBundleVersion", new_build)

    with open(INFO_PLIST, "w", encoding="utf-8") as f:
        f.write(text)

    print(f"[INFO] {INFO_PLIST}: CFBundleShortVersionString {old_version} -> {new_version}")
    print(f"[INFO] {INFO_PLIST}: CFBundleVersion {old_build} -> {new_build}")
    return old_version


def roll_unreleased(new_version):
    """patch/minor/major/preview: [Unreleased]'s body becomes the new dated heading's body."""
    with open(CHANGELOG, "r", encoding="utf-8") as f:
        text = f.read()

    match = re.search(r"## \[Unreleased\]\n(.*?)(?=\n## \[)", text, re.DOTALL)
    if not match:
        sys.exit(f"[ERROR] Couldn't find an '## [Unreleased]' section in {CHANGELOG}.")

    body = match.group(1)
    if not body.strip():
        sys.exit(
            f"[ERROR] '## [Unreleased]' in {CHANGELOG} is empty — "
            "add changelog entries before releasing."
        )

    today = datetime.date.today().isoformat()
    replacement = f"## [Unreleased]\n\n## [{new_version}] - {today}\n{body}"
    new_text = text[: match.start()] + replacement + text[match.end() :]

    with open(CHANGELOG, "w", encoding="utf-8") as f:
        f.write(new_text)

    print(f"[INFO] {CHANGELOG}: rolled [Unreleased] into [{new_version}] - {today}")


def finalize_preview(current_version, new_version):
    """release: rename the existing '## [X.Y.Z-preview.N] - date' heading in place — no new
    changelog content to roll, since the preview's own bump already recorded it. Deliberately
    does not touch [Unreleased]: unlike every other kind, this one shouldn't require or consume
    it — a preview finalizing to stable often has nothing new to say beyond what preview.N
    already documented."""
    with open(CHANGELOG, "r", encoding="utf-8") as f:
        text = f.read()

    heading_pattern = re.compile(rf"^## \[{re.escape(current_version)}\] - \d{{4}}-\d{{2}}-\d{{2}}$", re.MULTILINE)
    if not heading_pattern.search(text):
        sys.exit(f"[ERROR] Couldn't find a '## [{current_version}] - YYYY-MM-DD' heading in {CHANGELOG} to finalize.")

    today = datetime.date.today().isoformat()
    new_text = heading_pattern.sub(f"## [{new_version}] - {today}", text, count=1)

    with open(CHANGELOG, "w", encoding="utf-8") as f:
        f.write(new_text)

    print(f"[INFO] {CHANGELOG}: renamed [{current_version}] heading to [{new_version}] - {today}")


def get_current_version():
    with open(INFO_PLIST, "rb") as f:
        return plistlib.load(f).get("CFBundleShortVersionString")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("kind", choices=["patch", "minor", "major", "preview", "release"])
    parser.add_argument(
        "--preview",
        action="store_true",
        help="With patch/minor/major, start a new -preview.1 series instead of a stable release.",
    )
    args = parser.parse_args()

    if args.preview and args.kind in ("preview", "release"):
        sys.exit(f"[ERROR] --preview doesn't apply to '{args.kind}'.")

    current = get_current_version()
    new_version = next_version(current, args.kind, args.preview)

    # CHANGELOG.md first, deliberately: both changelog functions validate before writing
    # anything, so a rejected bump (empty [Unreleased], missing preview heading) now leaves
    # Info.plist untouched too — writing the plist first meant a validation failure left the
    # version number bumped with no matching changelog entry, a real inconsistency this
    # ordering exists to prevent.
    if args.kind == "release":
        finalize_preview(current, new_version)
    else:
        roll_unreleased(new_version)
    bump_plist(new_version)

    print(f"[SUCCESS] Bumped {current} -> {new_version}. Review the diff, then commit and tag:")
    print("    git add Info.plist CHANGELOG.md")
    print(f'    git commit -m "release: v{new_version}"')
    print(f"    git tag v{new_version}")
    print("    git push && git push --tags")


if __name__ == "__main__":
    main()
