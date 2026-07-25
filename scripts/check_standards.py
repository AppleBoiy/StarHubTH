#!/usr/bin/env python3
"""Static checks for the rules in docs/SWIFT_STANDARDS.md (Refactor Phase 9.1).

Scans every .swift file under StarHubTH/ for the six patterns the standards doc
calls out by name (§11 anti-patterns / §12 pre-merge checklist):

  - `get`-prefixed methods
  - non-`final` classes
  - `.shared` singleton access outside App/
  - `DispatchQueue` use without a nearby justifying comment
  - files over 400 lines
  - `@Published` properties without `private(set)`

This is a whole-codebase scan, not a diff against a baseline — it reports the
current state, not just newly introduced violations. Per the plan, it starts
as a warnings-only report (exit 0). Pass --strict (or set
STARHUB_STANDARDS_STRICT=1) to make any finding exit 1, once the codebase is
actually clean enough for that to be worth enforcing.
"""
import argparse
import os
import re
import sys

SOURCE_ROOT = "StarHubTH"

# Framework singletons that are the correct call, not the anti-pattern.
# `.shared` on an app-owned type outside App/ is what this check is for.
ALLOWED_SHARED_RECEIVERS = {
    "NSWorkspace",
    "URLSession",
    "NSAppleEventManager",
    "FileManager",  # `.default`, but harmless to allow-list defensively
}

GET_PREFIX_RE = re.compile(r"\bfunc\s+(get[A-Z]\w*)\s*\(")
CLASS_DECL_RE = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:public\s+|open\s+|internal\s+|private\s+|fileprivate\s+)?(final\s+)?class\s+(\w+)")
SHARED_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\.shared\b")
PUBLISHED_RE = re.compile(r"@Published\s+(private\(set\)\s+)?var\s+(\w+)")


def iter_swift_files(root):
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            if name.endswith(".swift"):
                yield os.path.join(dirpath, name)


def check_get_prefix(path, lines, findings):
    for lineno, line in enumerate(lines, start=1):
        for match in GET_PREFIX_RE.finditer(line):
            findings.append((path, lineno, "get-prefix", f"`{match.group(1)}` should drop the `get` prefix (§1.1)"))


def check_non_final_class(path, lines, findings):
    for lineno, line in enumerate(lines, start=1):
        match = CLASS_DECL_RE.match(line)
        if match and match.group(1) is None:
            findings.append((path, lineno, "non-final-class", f"`class {match.group(2)}` is missing `final` (§2.2)"))


def check_shared_outside_app(path, lines, findings):
    if path.startswith(os.path.join(SOURCE_ROOT, "App") + os.sep):
        return
    for lineno, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("///"):
            continue
        for match in SHARED_RE.finditer(line):
            receiver = match.group(1)
            if receiver in ALLOWED_SHARED_RECEIVERS:
                continue
            findings.append((
                path, lineno, "shared-outside-app",
                f"`{receiver}.shared` used outside App/ — inject via DependencyContainer instead (§4.2)",
            ))


def check_dispatch_queue(path, lines, findings):
    for lineno, line in enumerate(lines, start=1):
        if "DispatchQueue" not in line:
            continue
        window_start = max(0, lineno - 3)
        window = lines[window_start:lineno]
        has_comment_nearby = any("//" in w for w in window)
        if not has_comment_nearby:
            findings.append((
                path, lineno, "dispatch-queue",
                "`DispatchQueue` with no justifying comment nearby — prefer async/await, or explain why (§6.2)",
            ))


def check_file_length(path, lines, findings):
    count = len(lines)
    if count > 400:
        findings.append((path, count, "file-length", f"{count} lines — split it (§ file-size convention)"))


def check_published_private_set(path, lines, findings):
    for lineno, line in enumerate(lines, start=1):
        match = PUBLISHED_RE.search(line)
        if match and not match.group(1):
            findings.append((
                path, lineno, "published-private-set",
                f"`@Published var {match.group(2)}` has no `private(set)` — confirm views don't just read it (§8)",
            ))


CHECKS = [
    check_get_prefix,
    check_non_final_class,
    check_shared_outside_app,
    check_dispatch_queue,
    check_file_length,
    check_published_private_set,
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--strict", action="store_true",
        help="Exit 1 if any finding is reported (default: report only, exit 0).",
    )
    args = parser.parse_args()
    strict = args.strict or bool(os.environ.get("STARHUB_STANDARDS_STRICT"))

    findings = []
    for path in sorted(iter_swift_files(SOURCE_ROOT)):
        with open(path, "r", encoding="utf-8") as file:
            lines = file.readlines()
        for check in CHECKS:
            check(path, lines, findings)

    if not findings:
        print("[OK] check_standards: no findings.")
        return 0

    by_category = {}
    for path, lineno, category, message in findings:
        by_category.setdefault(category, []).append((path, lineno, message))

    for category, items in sorted(by_category.items()):
        print(f"\n=== {category} ({len(items)}) ===")
        for path, lineno, message in items:
            print(f"{path}:{lineno}: {message}")

    print(f"\n[{'ERROR' if strict else 'WARN'}] check_standards: {len(findings)} finding(s) across {len(by_category)} categor{'y' if len(by_category) == 1 else 'ies'}.")
    if strict:
        print("[ERROR] Run without --strict to treat these as advisory instead of build-breaking.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
