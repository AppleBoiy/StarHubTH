# StarHubTH — Nexus Release Automation Plan

**Goal.** StarHubTH is itself published on Nexus Mods as a tool page (`docs/DOMAIN_CONTEXT.md`) — `assets/nexus_description.txt`/`nexus_description_en.txt`/`nexus_changelog.txt` are hand-maintained BBCode, pasted into the Nexus web listing by hand on every release, same as the screenshots. Reduce the manual work at release time: auto-upload the built release zip to the existing Nexus file slot from CI, and auto-generate the BBCode changelog text from `CHANGELOG.md` so it's never out of sync or hand-transcribed.

**Status.** Track 1 implemented 2026-07-27, pending its first real dry-run on the next tag push. Track 2 not started.

---

## What's actually possible here (confirmed against Nexus's current API, checked 2026-07-26)

Nexus Mods has a genuine public **Upload API** (beta since March 2026, the standard upload path since June 2026), with an official GitHub Action wrapping it: [`Nexus-Mods/upload-action`](https://github.com/Nexus-Mods/upload-action). This is real, not speculative — but it does **one specific thing**, and the boundary matters for scoping this plan correctly:

- It **version-ups an existing file slot** on an existing mod page (`file_id` — found in that file's "API Info" on the Nexus Files tab). It does not create a new mod page and cannot create a new file slot from nothing. StarHubTH already has both (a mod page and a Main file), so this is a fit.
- It takes a per-version `description` string (plain text/BBCode for that *file version's* notes) and can optionally sync the *mod's* version number to the uploaded file's version (`update_mod_version: true`).
- **It does not, anywhere, update the mod page's own description or changelog tab text.** That remains web-UI-only — confirmed directly against the action's README, not assumed. So "auto-update the Nexus mod page when the README changes" is only ever partially true: the *file upload* can be fully automatic, the *page copy* (`nexus_description*.txt`) cannot, at any layer of the current public API.

**Consequence for scope:** this plan has two genuinely different tracks, not one "sync everything" pipeline — same shape of finding as `.claude/skills/refresh-screenshots/SKILL.md`'s "this can't be a CI job" constraint (screenshots need the maintainer's own real, populated app state; a CI runner has none).

---

## Track 1 — Auto-upload the release build (CI, fully automatable)

Slot `Nexus-Mods/upload-action` into `.github/workflows/release.yml`, right after the existing `python3 release.py --publish` step (which already builds and zips via `ditto`, and already knows the version from `Info.plist` — see `docs/RELEASING.md`). The zip `release.py` already produces is exactly what this action wants as `filename`.

Needed, as GitHub Actions repo secrets — **done**:
- A Nexus personal API key authorized to upload to the StarHubTH mod page — added as the `NEXUSMODS_API_KEY` repo secret 2026-07-27.
- The `file_id` of StarHubTH's existing "Main" file slot on Nexus — `7706256`, not sensitive, checked directly into `release.yml`.

Behavior: every tag push that reaches `release.py --publish` today also pushes that same build to Nexus, using that release's `CHANGELOG.md` section (already extracted by `release.py`'s `get_changelog_notes`, reusable as-is) as the file version's `description` input, with `update_mod_version: true` so the Nexus page's version badge stays in sync automatically.

## Track 2 — Auto-generate the BBCode changelog (local script, not CI)

`assets/nexus_changelog.txt` is not curated prose the way `nexus_description*.txt` is — it's a near-mechanical transform of `CHANGELOG.md`'s `## [version]` sections: `### Added`/`### Fixed` headers → `[b]Added[/b]`/`[b]Fixed[/b]`, `- **Bold lead**: rest` bullets → `[list][*] [b]Bold lead[/b]: rest[/list]`. Confirmed by direct comparison of the two files for `1.1.3`/`1.1.7`-era entries — the structure maps cleanly today because `CHANGELOG.md` is already disciplined (`docs/RELEASING.md` enforces the heading format via `bump_version.py`).

A script (`scripts/generate_nexus_changelog.py`, mirroring `scripts/generate_localizable_strings.py`'s house style) that takes a version and emits the BBCode block, appending it to `assets/nexus_changelog.txt` in the same "one version's worth of BBCode" shape the file already has. This stays **local, run-and-review**, not a CI step or a build-time hard gate — same caution level as `scripts/screenshot_diff_report.py`'s diff-and-report approach (see the refresh-screenshots skill), because a silent mis-transform landing directly on the public Nexus listing is a worse failure than a missed manual paste.

**`nexus_description*.txt` is explicitly out of scope for automation.** It's curated marketing copy with hand-picked banner images (`stardew-thai-translations` repo assets) that don't correspond to anything in `README.md`/`README_EN.md` 1:1 — the earlier README/Nexus "convert" idea doesn't survive contact with what the file actually contains. If this changes later (e.g. the description is restructured to mirror the README more closely), revisit; don't force a converter onto content it was never authored to round-trip.

---

## Phases

**Phase 1 — Track 1 prerequisites (blocks everything else in Track 1)** ✅ done 2026-07-27
- [x] 1.1 `file_id` is `7706256`; account confirmed via the key already added below.
- [x] 1.2 `NEXUSMODS_API_KEY` added as a GitHub Actions repo secret (confirmed via `gh secret list`, added 2026-07-27T04:44:40Z).

**Phase 2 — Track 1 implementation** ✅ implemented 2026-07-27, not yet dry-run
- [x] 2.1 Added the `Nexus-Mods/upload-action` step to `release.yml` (pinned to `v1.0.0-beta.9` by commit SHA), reading `zip_path`/`version`/`changelog_notes` from the existing "Build, package, and publish release" step's new outputs — `release.py` now writes those via `write_github_output()` whenever `GITHUB_OUTPUT` is set (no-op locally).
- [x] 2.2 Set `archive_existing_version: true`, `update_mod_version: true`, and `primary_mod_manager_download: true`.
- [ ] 2.3 **Not yet done** — needs a real tag push to dry-run against. This only proves out on the *next* release; verify the Nexus file slot actually updates before treating Track 1 as fully done.

**Phase 3 — Track 2 implementation** — not started
- [ ] 3.1 Write `scripts/generate_nexus_changelog.py`: `CHANGELOG.md` version section → BBCode block, matching `assets/nexus_changelog.txt`'s existing format exactly.
- [ ] 3.2 Wire it as an optional step documented in `docs/RELEASING.md`'s release procedure (after `bump_version.py`, before tagging) — never auto-committed, always reviewed before it's pasted into Nexus, same spirit as `docs/RELEASING.md`'s existing "Optional: refresh screenshots before a release" section.

**Phase 4 — Document and fold in**
- [x] 4.1 `docs/RELEASING.md`'s release procedure now describes the automatic Nexus upload step.
- [ ] 4.2 Update `docs/DOMAIN_CONTEXT.md`'s note about `nexus_changelog.txt` being hand-maintained — blocked on Phase 3 (still hand-transcribed until Track 2 exists); `nexus_description*.txt` stays hand-maintained as-is regardless.

---

## Decisions

- **`nexus_description*.txt` stays fully manual, indefinitely.** Not a phased "later" item — the content doesn't correspond to README structure closely enough to automate safely (see Track 2 section above).
- **Track 2 output is never auto-pasted to Nexus or auto-committed.** A human reviews the generated BBCode and pastes it into Nexus's own editor, exactly like today — the only change is where the BBCode text comes from.
- **Track 1 runs automatically on every tag push once wired up** — no `workflow_dispatch`-only staging period. Decided 2026-07-27; revisit if a bad automated upload ever actually happens.
- **`update_mod_version: true`** — the Nexus page's version badge stays in sync with every upload automatically, matching the fact the zip/changelog are already auto-derived from the same tag.
- **`archive_existing_version: true`** — the previous release's file is archived (still reachable, no longer featured) each time a new one uploads, keeping the Files tab to one current recommended download.
- **`primary_mod_manager_download: true`** — each new release becomes the file Vortex/mod-manager clients treat as primary, matching that every tagged release is meant to supersede the last.

## Open questions — for you, not assumed

None remaining for Track 1 — all resolved 2026-07-27 (see Decisions and Phase 1/2 above). Track 2 has no open questions blocking it either; it just hasn't been built yet.

---

## When this plan is done

Fold the durable outcome into `docs/RELEASING.md`'s release procedure and `docs/DOMAIN_CONTEXT.md`'s Nexus API note, then delete this file, same retirement pattern as `docs/TEST_STRATEGY_PLAN.md`.
