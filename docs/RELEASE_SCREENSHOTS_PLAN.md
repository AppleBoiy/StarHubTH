# StarHubTH — Release Screenshot Refresh Plan

**Goal.** Not "reproduce the same 15 Thai / 11 English files" — the exact count/numbering doesn't matter (confirmed 2026-07-26). The actual problem: screenshots get added ad hoc over time, features get added without anyone remembering to add a matching screenshot, and there's no single place that says "here is every feature StarHubTH has, and whether it's currently shown in the README." Fix that structurally — a canonical, checked-in feature inventory that both drives an automated capture step and can flag when the app has grown a screen the inventory doesn't know about yet — not just a one-time refresh.

**Status.** Planning only. The inventory below (Phase 1) is done as research; nothing is implemented — no capture script, no skill, no new accessibility identifiers beyond what already exists from the round-trip UI test work.

---

## Decisions (revised from the original draft of this plan)

- **Filenames: descriptive, not numbered.** Reversed from the earlier "keep numbered" decision — that decision made sense when the goal was "regenerate file N in place, don't break `<img>` references." It stops making sense once the goal is "never lose track of what's covered": a number carries no information on its own, which is exactly the problem being fixed. New shape: `screenshots/en/<slug>.png` / `screenshots/th/<slug>.png`, where `<slug>` matches an ID in the checklist below (e.g. `mod-list.png`, `save-editor.png`, `thaihub-detail.png`). READMEs get their `<img>` references updated once, at rollout, not per release.
- **No second synthetic screenshot set.** Confirmed out of scope — only the real, populated marketing set matters.
- **Skill stays manually invoked**, same as `Integration`/`UI` test plans — a deliberate pre-release step, never automatic.
- **Screen count parity between languages is not a goal.** Thai and English can cover different subsets of the checklist below (e.g. Thai showing ThaiHub states English doesn't need) without that being a bug to fix.

---

## Phase 1 — Canonical feature checklist (done as research, not yet checked in)

Built by reading the app's own navigation code (`MainView.swift`'s `currentTab` switch, `MainSidebarView.swift`'s `sidebar-tab-*` rows) and every top-level `View` in each `Features/*` folder — not by looking at the old screenshots first, so it can't inherit their blind spots. Cross-checked against the 15 existing Thai PNGs afterward: every one of them maps cleanly onto an entry below, plus this list surfaces several states the old set never captured at all (grid view modes, the Updates screen, Logs, the mod config editor, save timeline/backups, profile detail).

**Tier — Core (one screenshot each; this is the set the capture skill targets by default):**

| ID | Feature | Trigger |
|---|---|---|
| `home` | Home dashboard | `sidebar-tab-Home` (via profile card) |
| `updates` | Updates / Software Update screen | Alert badge row, only visible with pending updates |
| `saves-list` | Saves — list view | `sidebar-tab-Saves` |
| `saves-grid` | Saves — grid view | Saves view-mode toggle |
| `save-editor` | Save Editor (avatar/notes/character/inventory) | Open a save |
| `save-timeline` | Save Timeline — backups list | "View Backups" on a save |
| `mods-list` | Mods — list view | `sidebar-tab-Mods` |
| `mods-grid` | Mods — grid view | Mods view-mode toggle |
| `mods-group-expanded` | Mods — group row expanded (multi-file mod, dependency warning) | Expand a group row |
| `mod-detail-description` | Mod Detail — Description tab | Open a mod's detail view |
| `mod-detail-dependencies` | Mod Detail — Dependencies tab (graph) | Dependencies tab |
| `mod-config-editor` | Mod Config Editor — Visual tab | Open a mod's config |
| `profiles-list` | Profiles — populated list | `sidebar-tab-Profiles` |
| `profile-detail` | Profile Detail sheet | Open a profile |
| `modpacks-empty` | ModPacks — empty/import prompt | `sidebar-tab-ModPacks`, nothing imported |
| `modpacks-imported` | ModPacks — imported collection banner + rows | After importing a collection |
| `settings` | Settings — full page | `sidebar-tab-Settings` |
| `logs` | Logs — main list | `sidebar-tab-Logs` |
| `changelog` | App Changelog | `sidebar-tab-AppChangelog` |
| `thaihub-list` | ThaiHub — mod list | `sidebar-tab-ThaiHub` |
| `thaihub-detail` | ThaiHub — mod detail | Open a Thai mod |

**Tier — Extended (optional; sub-states worth having but not required for a baseline README refresh):** mod list empty state, mod list no-search-results, mod install-in-progress overlay, mod detail Changelog tab, mod config editor Code/JSON tab, saves empty state, save timeline empty state, save timeline branch/restore sheets, profiles empty state, profile "Manage Mods" popover, various filter/sort menus (Mods, Saves), Home mid-SMAPI-install state, Logs level/source filters, Logs empty state, ThaiHub loading state.

This checklist is the actual deliverable of Phase 1 — it needs to land as a real, checked-in file (`docs/SCREENSHOT_INVENTORY.md` or a structured `scripts/screenshot_manifest.json` the capture script also reads — leaning JSON since Phase 3 needs to consume it programmatically, not just read it) before Phase 2 starts, so it's reviewable on its own rather than buried inside a script.

---

## Phase 2 — Reachability

Most Core-tier entries are already reachable via the `sidebar-tab-*` identifiers the round-trip UI tests already rely on. What's missing an identifier today, needed to drive/verify navigation deterministically for capture:

- Mod Detail tab picker (Description/Changelog/Dependencies) — currently a plain `Picker`, no identifier (same gap Tier C's live-data tests already hit and worked around for the toolbar buttons — this is the segmented tab control itself).
- Mod Config Editor tab picker (Visual/Code).
- Save Editor — no identifiers on its section anchors at all yet.
- Profile Detail sheet, "Manage Mods" popover trigger.
- ThaiHub mod row → detail (same "info button" pattern as `mod-row-info-button-<folder>` from Tier C).
- Saves/Mods view-mode toggles (list↔grid).

This extends the same identifier work from the round-trip UI tests and Tier C — same files, same pattern, not a new mechanism.

---

## Phase 3 — Capture mechanism

- 3.1 A capture script (real app, `screencapture -l <windowID>` via Bash — not `XCTestCase`/`XCUIScreen`, since this drives the maintainer's own populated app state, not a test fixture) that reads the Phase 1 manifest, navigates to each Core-tier entry via its accessibility identifiers, and captures a PNG named `<slug>.png`.
- 3.2 A coverage check, run as part of the same pass: grep the current `sidebar-tab-*`/major-state identifiers actually present in the codebase, diff against the manifest's `trigger` field, and warn — not fail — on anything in the app that the manifest doesn't know about yet. This is the actual fix for "I lost track": it turns silent drift into a visible warning the next time the skill runs, instead of relying on someone remembering.
- 3.3 A diff/report step against the existing checked-in PNGs (perceptual, not pixel-exact — a changed cursor position or animation frame isn't a real change) — reports, never auto-overwrites or auto-commits.

## Phase 4 — Package as a skill

Wrap Phases 1–3 as an invokable skill (`/refresh-screenshots`), documented in `docs/RELEASING.md` as an optional pre-release step — precondition (a real, populated `gameDir` with representative mods/saves/profiles already set up) stated explicitly, never wired into `release.yml`.

---

## Open questions — for you, not assumed

- Extended tier: worth capturing at all, ever, or is Core-only the permanent scope? Can stay undecided until Phase 3 — doesn't block Phase 1/2.
- The manifest format — `docs/SCREENSHOT_INVENTORY.md` (human-first, harder for a script to consume reliably) vs `scripts/screenshot_manifest.json` (script-first, needs a rendered/generated doc view if you want it human-browsable too). Leaning JSON per Phase 1's note above, but flagging since it affects how Phase 2/3 are built.

---

## When this plan is done

Fold the durable outcome into `docs/RELEASING.md`'s release procedure and delete this file, same retirement pattern as `docs/TEST_STRATEGY_PLAN.md`.
