# StarHubTH — Quality-of-Code (QoC) Audit Plan

**Goal.** Verify (and where needed, fix) six specific quality dimensions the refactor plan didn't cover: test-suite conventions, folder-structure conformance, tooling-script robustness, root-level file hygiene, docs placement, and retiring finished tracking docs. This is a smaller, audit-driven plan, not a rewrite — most of the codebase came back clean.

**Lifecycle note (this is the point of item 6 below, applied to itself):** like `REFACTOR_PLAN.md`, this file is a *tracking* document, not a permanent one. Once every phase here is checked off, fold any durably useful lesson into `SWIFT_STANDARDS.md`/`PROJECT_STRUCTURE.md`/`CLAUDE.md` and delete this file. Don't let it accumulate as dead-weight documentation the way `REFACTOR_PLAN.md` almost did.

---

## Where we are (findings from a 3-agent audit, cross-verified)

| Area | Verdict |
|---|---|
| Test isolation (§ Phase A) | **Fixed.** Was: 4 of 18 files made real live network calls, 3 gated on a real `UserDefaults` check, 1 (`SmapiInstallerTests`) not gated at all — hit `api.github.com` unconditionally, including in CI. Now: split into `Tests/Integration/` with one shared `STARHUB_SKIP_LIVE_TESTS` gate; CI sets it. |
| Folder structure (§ Phase B) | **Tests/ reorg + SaveManager violation fixed.** `PROJECT_STRUCTURE.md`'s file map is still stale (pre-refactor 39-file snapshot; Phase 8 alone added ~35 undocumented files) — that part (B.3) is still open. |
| Script quality (§ Phase C) | **`run_tests.py` cannot report a test failure to CI at all** — it discards the test binary's exit code and never calls `sys.exit`. `release.py` prints `[SUCCESS]` after an unchecked `ditto` call and has zero exit-code propagation on any failure path. `build_app.py` has 2 of 4 failure paths that print `[ERROR]` but still exit 0 (Swift-compile failure, no-swift-files), plus an unchecked codesign step. `scripts/check_standards.py` is the one script that gets this right — a template for the others. |
| Root-level hygiene (§ Phase D) | Mostly clean — everything gitignored is correctly ignored, `screenshots/` must stay at root (README depends on it). `nexus_*.txt` files are root-placed by documented convention (`DOMAIN_CONTEXT.md`) but nothing technical requires that; `nexus_description_en.txt` isn't even mentioned in that doc. `.agents/AGENTS.md` is tracked — worth a one-line confirmation it's meant to be. |
| Docs placement (§ Phase E) | Clean — exactly the 4 files `CLAUDE.md` expects, nothing stray, nothing missing. The staleness is in *content* (`PROJECT_STRUCTURE.md`'s file map, `SWIFT_STANDARDS.md`'s several "Today." sections still describing the pre-refactor codebase), not placement. |
| Plan retirement (§ Phase F) | `REFACTOR_PLAN.md` is fully complete (Phases 0–9) and contains 13 lessons, several of which are durable Swift-language gotchas worth keeping past this plan's own lifecycle (e.g. `@MainActor` default-parameter evaluation context, protocol-conformance isolation rules, `DispatchSemaphore` in async contexts). |

---

## Progress tracker

- [x] A.1 Added a skip-gate to `SmapiInstallerTests`'s live GitHub call (it had none at all before). Done as part of A.2's split, via one shared `Tests/Integration/LiveTestGate.swift` (`STARHUB_SKIP_LIVE_TESTS`) rather than reusing the Nexus-specific API-key check, since this call needs no key.
- [x] A.2 Split the 2 mixed files (`NXMParserTests`, `SmapiInstallerTests` each had pure logic + one live method) — pure logic stays under its original name in `Tests/Services/`, live methods moved to new `Tests/Integration/NXMDownloadIntegrationTests.swift` / `SmapiInstallerIntegrationTests.swift`. The 2 already-fully-live files (`ModUpdateTests`, `NexusCollectionTests`) moved to `Tests/Integration/` as-is. `.github/workflows/build.yml` sets `STARHUB_SKIP_LIVE_TESTS=1`. Verified both ways: with a real API key configured locally, all 4 still run live and pass; with the env var set (simulating CI), all 4 skip cleanly and the suite still reports 200/200.
- [x] A.3 Documented the taxonomy in `SWIFT_STANDARDS.md` §10 (also refreshed that section's stale pre-refactor "Today" paragraph while there — see F.2)
- [x] B.1 Reorganized `Tests/` into `Tests/Models/`, `Tests/Services/`, `Tests/Features/`, plus a new `Tests/Integration/` (extends the doc — see A.2). Done in the same commit as A.1/A.2 since they're the same mechanical move.
- [x] B.2 Fixed `SaveManager.swift`'s `AppKit`/`NSWorkspace` violation — added `FilePicking.reveal(_:)`, routed through it, dropped `openSaveInFinder` from `SaveStoring` entirely (revealing a file in Finder isn't a save-storage concern). Found and fixed a second, identical violation in `SavesStore.swift` (`openSavesFolder()`) the same pass — the original audit's grep missed it.
  - **New finding, not fixed here (flagging, not expanding scope):** `Features/Mods/ModsStore.swift`'s `backUp`/`restore` and `Features/ModPacks/ModPacksStore.swift`'s `exportModPack` all construct `NSSavePanel`/`NSOpenPanel` directly instead of going through `FilePicking`. This isn't a new regression — it's `docs/REFACTOR_PLAN.md` Phase 3.4's own named, deliberate deferral ("`restoreModZip` and the `NSSavePanel` backup-export flows weren't named in this step and are untouched"). Fixing it needs a real protocol addition (`FilePicking` has no "save panel with a suggested filename" method yet) plus updating 3 call sites and their stub — a separate, sizable chunk of work. Worth its own pass if/when you want it.
- [x] B.3 Replaced `PROJECT_STRUCTURE.md`'s stale "Complete file map — all 39 files" (a pre-refactor migration table) with a pattern-plus-representative-example tree per folder, so it can't go stale the same way again. Updated the `Counts` table with real current numbers. 372 lines → 144.
- [x] C.1 Fix `run_tests.py`: capture the test binary's real exit code, `sys.exit(1)` on failure. Verified by deliberately breaking an assertion — old script exited 0 on a failing suite, new one exits 1.
- [x] C.2 Fix `build_app.py`: `sys.exit(1)` on Swift-compile failure and the no-swift-files path; check the codesign step before printing `[SUCCESS]`; guard the `Info.plist` copy like its sibling copies; `[WARN]` when an optional asset is missing instead of silently skipping. Verified by deliberately breaking a Swift file — old script exited 0, new one exits 1.
- [x] C.3 Fix `release.py`: check `ditto`'s return code before declaring success; fix the literal `\n` in the upload-failure message; use `sys.executable` instead of hardcoded `"python3"`; reconcile the two different version-fallback strings into one `UNKNOWN_VERSION = "0.0.0"` sentinel; `sys.exit(1)` on every failure path. Verified with a dry run (build + zip, skip the actual GitHub upload).
- [x] C.4 Extracted `APP_NAME`/`APP_DIR`/`TARGET_TRIPLE` into new `build_config.py`, imported by all three scripts. Also dropped the now-unused `glob`/`plistlib` imports in `build_app.py` and `shutil` in `release.py`.
- [ ] D.1 Decide + act: move `nexus_changelog.txt`/`nexus_description.txt`/`nexus_description_en.txt` into `assets/` for tidiness (nothing requires root placement), and update `DOMAIN_CONTEXT.md` accordingly — or, if root stays, at least add `nexus_description_en.txt` to `DOMAIN_CONTEXT.md`'s explanation since it's currently undocumented
- [ ] D.2 Confirm `.agents/AGENTS.md` is intentionally tracked (analogous to `CLAUDE.md` for other AI tooling) — one-line note, no action expected
- [ ] E.1 No placement fix needed — covered by B.3's content refresh instead
- [ ] F.1 Extract the durable engineering lessons from `REFACTOR_PLAN.md` (the Swift/compiler gotchas — lessons 2, 4, 5, 6 — not the "we did X in commit Y" narrative) into `SWIFT_STANDARDS.md`, most naturally as short additions to the sections they concern (§6 Concurrency, §5 State) rather than one dumped appendix
- [ ] F.2 Refresh `SWIFT_STANDARDS.md`'s stale "Today." paragraphs (§6, §10, and any others) that still describe the pre-refactor codebase, now that the refactor is done
- [ ] F.3 Delete `docs/REFACTOR_PLAN.md` once F.1/F.2 land — git history keeps the full original for anyone who wants the archaeology
- [ ] F.4 Once this plan (`QOC_PLAN.md`) is itself fully checked off: fold anything durable into the permanent docs the same way, then delete this file too

---

## Notes on sequencing and judgment calls

- **C (scripts) should go first**, regardless of the letter ordering above. Every "build green, 198/198 tests passing" claim made throughout this whole project was verified by *reading printed output*, which happens to be reliable — but it means the CI workflow added in Phase 9 (`.github/workflows/build.yml`) is currently trusting a script that would report green on a red test suite. That's worth fixing before anything else compounds on top of it.
- **A.1/A.2 are a judgment call, not a bug fix** — the live-network tests are a deliberate, documented choice (verifying the real `Live*` implementations against the real APIs), just under-fenced structurally. The fix is separation and consistency, not deletion.
- **B.2 (`SaveManager` AppKit violation)** has two valid resolutions: route through `FilePicking` (consistent with the doc's stated rule), or decide the rule itself is too strict for a one-line `NSWorkspace.shared.open(folder)` convenience call and amend `PROJECT_STRUCTURE.md` instead. Either is defensible; pick one deliberately rather than leaving the doc and the code disagreeing.
- **D.1 is genuinely optional** — nothing is broken today, it's pure tidiness. Low cost either way.
