#!/usr/bin/env python3
"""Generate a draft BBCode changelog block for assets/nexus_changelog.txt from CHANGELOG.md.

Mechanical transform of structure only (### headers -> [b]Heading[/b], bullets ->
[list]/[*] items) — "**Internal —" leads are skipped, since Nexus's changelog tab
is for what end users actually notice, same convention that already excludes
1.1.4-1.1.8 from the file. This is always a draft: review it, translate the Thai
half yourself (CHANGELOG.md has no Thai source to transform), then paste both
into Nexus's own changelog editor and prepend the same block to
assets/nexus_changelog.txt as this repo's checked-in record. Never run
automatically and never writes any file itself — see
docs/NEXUS_RELEASE_AUTOMATION_PLAN.md's Track 2 section.

Usage:
    python3 scripts/generate_nexus_changelog.py 1.1.9
"""
import argparse
import re
import sys

CHANGELOG_PATH = "CHANGELOG.md"

BOLD_LEAD_RE = re.compile(r"^\*\*(.+?)\*\*:\s*(.*)$")
INLINE_CODE_RE = re.compile(r"`([^`]+)`")
HEADING_RE = re.compile(r"^### (\w+)")
BULLET_RE = re.compile(r"^- (.*)")


def get_changelog_section(version):
    with open(CHANGELOG_PATH, encoding="utf-8") as f:
        text = f.read()
    match = re.search(
        rf"^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=\n## \[|\Z)",
        text,
        re.DOTALL | re.MULTILINE,
    )
    if not match:
        sys.exit(f"[ERROR] No '## [{version}]' section found in {CHANGELOG_PATH}.")
    return match.group(1)


def parse_subsections(body):
    """Splits a changelog version body into an ordered [(heading, [bullet, ...]), ...]."""
    sections = []
    by_heading = {}
    current = None
    for line in body.splitlines():
        heading_match = HEADING_RE.match(line)
        if heading_match:
            current = heading_match.group(1)
            if current not in by_heading:
                by_heading[current] = []
                sections.append(current)
            continue
        bullet_match = BULLET_RE.match(line)
        if bullet_match and current:
            by_heading[current].append(bullet_match.group(1))
    return [(heading, by_heading[heading]) for heading in sections]


def is_internal(bullet):
    return bullet.strip().startswith("**Internal")


def to_bbcode_bullet(bullet):
    bullet = INLINE_CODE_RE.sub(r"\1", bullet)  # BBCode has no inline-code marker
    match = BOLD_LEAD_RE.match(bullet)
    if match:
        lead, rest = match.groups()
        return f"[*] [b]{lead}[/b]: {rest}"
    return f"[*] {bullet}"


def generate_bbcode(version):
    subsections = parse_subsections(get_changelog_section(version))

    block_lines = []
    for heading, bullets in subsections:
        user_facing = [b for b in bullets if not is_internal(b)]
        if not user_facing:
            continue
        block_lines.append(f"[b]{heading}[/b]")
        block_lines.append("[list]")
        block_lines.extend(to_bbcode_bullet(b) for b in user_facing)
        block_lines.append("[/list]")
        block_lines.append("")

    if not block_lines:
        return None

    lines = [f"### Version {version} - English", ""]
    lines.extend(block_lines)
    lines.append("---")
    lines.append("")
    lines.append(f"### Version {version} - Thai (ภาษาไทย)")
    lines.append("")
    lines.append("[TODO: translate the English section above into Thai by hand]")
    lines.append("")
    lines.append("---")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("version", help="Version to generate, matching a '## [version]' heading in CHANGELOG.md (e.g. 1.1.9)")
    args = parser.parse_args()

    block = generate_bbcode(args.version)
    if block is None:
        print(f"[INFO] Every entry in [{args.version}] is internal-only — nothing user-facing to add to the Nexus changelog.")
        return

    print(block)
    print()
    print(
        "[INFO] Draft only — translate the Thai section by hand, review the English wording, "
        "then paste both into Nexus's changelog editor and prepend this block to assets/nexus_changelog.txt.",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
