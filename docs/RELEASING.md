# StarHubTH — Release Numbering

Read this before touching `release.py`, `Info.plist`'s version keys, or any future release automation. It defines the versioning standard this project follows — nothing here wires up auto-release CI yet, that's a separate step once this is settled.

## The standard: SemVer + a separate build number

`CHANGELOG.md` already declares [Semantic Versioning](https://semver.org/spec/v2.0.0.html) — this doc makes that binding and adds the one thing SemVer doesn't cover: Apple's build-number field.

Two numbers, two different jobs, both live in `Info.plist`:

| Key | Format | Means | Bumped |
|---|---|---|---|
| `CFBundleShortVersionString` | `MAJOR.MINOR.PATCH` (SemVer, optional `-preview.N`) | The version a user sees | Once per release |
| `CFBundleVersion` | Plain monotonically increasing integer (`"1"`, `"2"`, `"3"`, ...) | Distinguishes builds macOS/Gatekeeper/an updater can compare | Every build that ships, even two builds of the same `CFBundleShortVersionString` |

**Current state is broken and needs fixing before automation goes on top of it:** `CFBundleShortVersionString` has moved 1.0.0 → 1.1.3 correctly, but `CFBundleVersion` has stayed `"1"` since the first release. It must become a real incrementing counter — this is what a future updater or `defaults compare` check relies on, not the marketing string.

### SemVer rules for this app

StarHubTH is a shipped desktop app, not a library — there's no public API to break — so read the three fields as:

- **PATCH** — bug fix, no new user-facing capability. (`1.1.3` → `1.1.4`)
- **MINOR** — new feature or visible behavior change, backward compatible (existing profiles/packs/saves still load). (`1.1.3` → `1.2.0`)
- **MAJOR** — reserved for changes that break compatibility with existing user data/config (e.g. a mod-pack export format change, a save-file schema the old app can't read) or a deliberate relaunch milestone. Don't bump it for size of effort alone — the Phase 9 architecture refactor was internal-only and correctly stayed PATCH/MINOR in the changelog, not MAJOR.
- **Prerelease** — `MAJOR.MINOR.PATCH-preview.N` (e.g. `1.2.0-preview.1`) for a build shared before the stable cut of that version. `N` starts at `1` and increments; it resets when the base version changes. Use `-preview.N`, not ad hoc suffixes — `1.1.1-preview` and `1.1.2-preview-2` (both in the changelog history) are exactly the inconsistency this doc exists to stop.

## Single source of truth

`Info.plist` is authoritative. Every other place a version appears is *derived*, never hand-typed separately:

- **Git tag** — always `vMAJOR.MINOR.PATCH[-preview.N]`, created from whatever `Info.plist` says at release time. No other tag shapes (retire the `-rev1` pattern seen on `v1.0.6-rev1`; if a build needs a redo, bump `CFBundleVersion` and re-tag the same `CFBundleShortVersionString` only if it never shipped — otherwise cut a new PATCH).
- **Release zip filename / GitHub release title** (`release.py`) — already reads `CFBundleShortVersionString` out of `Info.plist`. Keep it that way; don't let it take a version argument that could disagree with the plist.
- **`CHANGELOG.md` heading** — the `## [Unreleased]` section is renamed to `## [MAJOR.MINOR.PATCH] - YYYY-MM-DD` at release time, matching `Info.plist` exactly. A version with no changelog entry, or a changelog entry with no matching tag, is a bug — the current history has both (1.1.1-preview and 1.1.2-preview-2 have changelog entries but no tag).

## Release procedure

`scripts/bump_version.py` does steps 1–2 (it refuses to run if `[Unreleased]` in `CHANGELOG.md` is empty, so a changelog entry is required, not optional):

```bash
python3 scripts/bump_version.py patch   # or minor / major / preview / release
```

It edits `Info.plist` (bumps `CFBundleShortVersionString` and increments `CFBundleVersion`) and rolls `CHANGELOG.md`'s `[Unreleased]` section into a dated `## [MAJOR.MINOR.PATCH] - YYYY-MM-DD` heading, then prints the remaining steps. It does **not** commit, tag, or push — review the diff, then optionally draft this version's Nexus changelog entry before committing:

```bash
python3 scripts/generate_nexus_changelog.py MAJOR.MINOR.PATCH
```

This prints a draft BBCode block (mechanically transformed from the `CHANGELOG.md` section you just rolled, skipping any `**Internal —` entries the same way `assets/nexus_changelog.txt` already excludes internal-only versions like `1.1.4`–`1.1.8`) — never written to any file automatically. Review the English wording, translate the Thai half yourself (there's no Thai source to transform from), then paste both into Nexus's own changelog editor and prepend the same block to `assets/nexus_changelog.txt` as this repo's checked-in record. Skip this entirely if the version has nothing user-facing — the script says so itself when every entry is internal-only.

```bash
git add Info.plist CHANGELOG.md
git commit -m "release: vMAJOR.MINOR.PATCH"   # one concern, not mixed with feature work
git tag vMAJOR.MINOR.PATCH                    # or vMAJOR.MINOR.PATCH-preview.N
git push && git push --tags
```

Pushing the tag is the deliberate, explicit trigger — that's where a human decides "yes, release this," same as any other push. From there, [`.github/workflows/release.yml`](../.github/workflows/release.yml) takes over: it checks the pushed tag matches `Info.plist` (fails loudly if you tagged without bumping), runs `xcodebuild test` (the `StarHubTHTests` unit suite), then `python3 release.py --publish` to build via `xcodebuild`, codesign, zip, and publish the GitHub Release with that version's changelog section as the release notes. A final step then pushes that same build to StarHubTH's existing Nexus Mods file slot (`Nexus-Mods/upload-action`, `file_id` `7706256`, using the `NEXUSMODS_API_KEY` repo secret), with the same changelog section as the file version's description, `update_mod_version`/`archive_existing_version`/`primary_mod_manager_download` all `true` — so the Nexus page's version badge, featured file, and file history all stay in sync with GitHub automatically. This is fully automatic on every tag push; if a bad upload ever happens, revisit that choice (see `docs/NEXUS_RELEASE_AUTOMATION_PLAN.md`'s Decisions, once that file still exists — it's deleted once its outcome is fully folded in here).

`release.py` still works standalone for a local build — run it without `--publish` and it either prompts (interactive terminal) or just skips the upload (non-interactive, no `--publish`), so it never hangs waiting on input that isn't there.

## Optional: refresh screenshots before a release

`README.md`/`README_EN.md` and the Nexus listing embed real, populated-app screenshots (`screenshots/en/`, `screenshots/th/`). If a release adds or changes something screenshot-worthy, run the `/refresh-screenshots` skill (`.claude/skills/refresh-screenshots/SKILL.md`) — it drives the real app against your own real `gameDir`/mods/saves via `TestPlans/ScreenshotCapture.xctestplan` and `scripts/screenshot_manifest.json`, and reports differences against the checked-in files without ever auto-committing. Same posture as `Integration`/`UI`/`UILive`: manual, local-only, never part of `release.yml`. Not a hard gate — skip it for releases with nothing visually new.
