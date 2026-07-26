# StarHubTH — Xcode Migration Plan

**Goal.** Replace the script-based build/test pipeline (`build_app.py`, `run_tests.py`, and the parts of `release.py`/CI that depend on them) with a real Xcode project, without regressing the "new subfolders need no build-script change" guarantee the current scripts provide via `os.walk`. This is a full migration, not an additive layer — `build_app.py`/`run_tests.py` are meant to go away once every phase below lands, and every doc that currently documents the script-based pipeline as fact (`CLAUDE.md`, `.agents/AGENTS.md`, `docs/SWIFT_STANDARDS.md`, `docs/PROJECT_STRUCTURE.md`, `docs/RELEASING.md`, both READMEs) moves with it.

**Lifecycle note**, same as `REFACTOR_PLAN.md`/`QOC_PLAN.md` before it: this is a tracking document, not a permanent one. Once every phase is checked off, fold any durable lesson into `SWIFT_STANDARDS.md`/`PROJECT_STRUCTURE.md`/`CLAUDE.md` and delete this file.

**Sequencing note**: each phase after Phase 0 is a checkpoint — get explicit sign-off before starting it. This is a large, mechanical-but-risky change (a ~200-assertion test suite conversion alone touches 32 files); doing it in one uninterrupted pass is exactly the failure mode phasing exists to avoid.

---

## Phase 0 — New Xcode project, app target only

Stand up a `project.yml`-driven (XcodeGen) `.xcodeproj` with a single macOS app target that builds `StarHubTH.app`, proven equivalent to `build_app.py`'s output. Nothing else changes yet — `build_app.py`/`run_tests.py`/`release.py`/CI/docs all keep working exactly as today; both build paths coexist during the migration.

- [x] 0.1 Extracted `assets/en.json`/`th.json` → `en.lproj`/`th.lproj` `Localizable.strings` generation (plus the hard-fail-on-key-mismatch check) out of `build_app.py` into `scripts/generate_localizable_strings.py`, imported by `build_app.py` so the logic isn't duplicated. Verified `python3 build_app.py` still succeeds unchanged.
- [x] 0.2 Wrote root `project.yml`: macOS app target, sources over `StarHubTH/` via `type: syncedFolder` (XcodeGen 2.46.0 does support emitting a File System Synchronized Group — confirmed via its CHANGELOG.md, "Basic support for Xcode 16's synchronized folders... no cache invalidation or need to regenerate when files are added or removed"), `INFOPLIST_FILE: Info.plist` / `GENERATE_INFOPLIST_FILE: NO` (existing root Info.plist reused as-is), `CODE_SIGN_STYLE: Manual` / `CODE_SIGN_IDENTITY: "-"`, `MACOSX_DEPLOYMENT_TARGET: "13.0"`, `ARCHS: arm64`, `SWIFT_VERSION: "6"`, resources (`assets/custom_ui`, `AppIcon.icns`, `CHANGELOG.md`, `en.lproj`/`th.lproj`), and 0.1's script wired as a `prebuildScripts` Run Script phase.
- [x] 0.3 `xcodegen generate` + `xcodebuild -project StarHubTH.xcodeproj -scheme StarHubTH build` succeeded (**BUILD SUCCEEDED**); `open`ing the built `.app` launched it, process confirmed running via `ps`.
- [x] 0.4 Diffed the Xcode-built bundle's `Contents/Resources` against a fresh `python3 build_app.py` output: identical file list, byte-identical `en.lproj`/`th.lproj`/`Localizable.strings` and `CHANGELOG.md`. `Info.plist` differs only by Xcode's standard auto-injected build-metadata keys (`BuildMachineOSBuild`, `DTXcode`, `DTSDKName`, etc.) — every original key/value (`CFBundleIdentifier`, `CFBundleExecutable`, `CFBundleShortVersionString`, `CFBundleURLTypes`/`nxm://` scheme, etc.) is preserved unchanged.
- [x] 0.5 Confirmed `python3 build_app.py` (succeeds, same warnings as before) and `python3 run_tests.py` (210/210 passed) both still work unchanged.
- [x] 0.6 Removed the now-superseded standalone `StarHubTHUITests/project.yml`; kept `StarHubTHUITests/Sources/*.swift` on disk unused, for Phase 2 to absorb.

**Resolved during Phase 3**: `StarHubTH.xcodeproj` is committed to the repo (not gitignored) — `.gitignore` documents this decision directly. `xcodegen generate` is a "run this after editing `project.yml`" step, not a required setup step for a fresh checkout.

**File-discovery design choice** (the load-bearing detail every doc repeats as a guarantee): prefer Xcode's native File System Synchronized Groups (Xcode 16+, this repo has 26.6) over XcodeGen-regenerate, since it needs no regeneration step at all — closest match to `os.walk`'s zero-touch behavior. If XcodeGen can't emit one, fall back to a regenerated recursive `sources:` path and say so plainly in the Phase 4 doc rewrite rather than overstating the guarantee.

## Phase 1 — Test suite → XCTest — DONE

Convert all 32 files / ~200 assertions in `Tests/`: `SimpleTestFramework.assertEqual/assertTrue/assertFalse` → `XCTAssertEqual/XCTAssertTrue/XCTAssertFalse`, `struct FooTests { static func run() }` → `final class FooTests: XCTestCase` with individual `test*` methods XCTest auto-discovers. Remove `Tests/main.swift`'s manual `DispatchSemaphore` + `RunLoop.main` pump in favor of XCTest's native async test support — verify per-suite this is actually safe, especially wherever code-under-test still hops through `DispatchQueue.main.async` (e.g. `ModsStore.scanMods`). `Tests/Integration/`'s `LiveTestGate`/`STARHUB_SKIP_LIVE_TESTS` gating carries over via `XCTSkipIf`.

- [x] 1.1 New `StarHubTHTests` XCTest target added to `project.yml`, hosted by the `StarHubTH` app target (`TEST_HOST`/`BUNDLE_LOADER`), sources over `Tests/` via a synced folder (same file-discovery guarantee as the app target).
- [x] 1.2 Mechanical conversion pass, all 20 test-suite files (7 Features, 4 Integration, 3 Models, 6 Services) + 9 Stub files (added `@testable import StarHubTH`) + `LiveTestGate.swift` (simplified to expose `isSkipped`, `skipIfNeeded`'s `SimpleTestFramework` dependency removed). `grep -rn "func test" Tests/ | wc -l` → 79, matching `xcodebuild test`'s "Executed 79 tests" exactly — nothing silently dropped.
- [x] 1.3 Confirmed via `grep -n DispatchQueue StarHubTH/Features/Mods/ModsStore.swift` that `scanMods` is fully synchronous (no `.main.async` hop) — the pump hack was stale, safely dropped entirely; `testScanModsPopulatesStateFromStub` needs no draining. Two Integration tests (`ModUpdateTests`, `NXMDownloadIntegrationTests`) used `DispatchSemaphore.wait` inside an `async` function — a genuine Swift 6 strict-concurrency violation once `SWIFT_VERSION: "6"` applied to the test target (unlike `run_tests.py`, which never passed `-swift-version 6` to the test binary). Fixed by switching to `URLSession.shared.download(for:)`, the same async pattern `ModPacksStore.swift` already uses.
- [x] 1.4 `xcodebuild test -project StarHubTH.xcodeproj -scheme StarHubTH` → **TEST SUCCEEDED**, 79 tests executed, 3 skipped (live-network Integration tests, correctly gated by `STARHUB_SKIP_LIVE_TESTS=1`), 0 failures.

**Consequence, not a regression**: `python3 run_tests.py` no longer compiles (`Tests/` now contains `@testable import StarHubTH` and `XCTestCase`, which a flat `swiftc` invocation can't resolve) — expected the moment the test suite itself converts, not deferrable to Phase 3. `python3 build_app.py` is unaffected and still succeeds. `run_tests.py` is formally deleted in Phase 3 below, not before.

## Phase 2 — Fold in UI tests — DONE

- [x] 2.1 Added `StarHubTHUITests` target to `project.yml` (`type: bundle.ui-testing`, `TEST_TARGET_NAME: StarHubTH`), sourcing the existing `StarHubTHUITests/Sources/{AppLauncher.swift,SmokeUITests.swift}` from the earlier spike.
- [x] 2.2 Simplified `AppLauncher` to a bare `XCUIApplication().launch()` — `TEST_TARGET_NAME` makes Xcode resolve it to the in-project `StarHubTH` app target directly, no more external-path workaround.
- [x] 2.3 Two Swift 6 strict-concurrency fixes needed along the way: `SmokeUITests` needed `@MainActor` (calling `waitForExpectations` from a non-isolated test method is a sending-non-Sendable-value error under `SWIFT_VERSION: "6"`).
- [x] 2.4 Added the accessibility identifiers the smoke tests actually needed but that were never wired into the views during the original (superseded) additive spike: `.accessibilityIdentifier("mods-search-field")` on `ModListView`'s `.searchable(...)`, `.accessibilityIdentifier("mod-row-\(mod.folderName.rawValue)")` on `ModListRow`'s root `HStack`.
- [x] 2.5 **Manual, one-time setup surfaced and completed**: the process driving `xcodebuild test` needs Accessibility permission (System Settings → Privacy & Security → Accessibility) to query button elements inside the app window — without it, `Window (First Match)` resolves but nothing inside it does. Granted to Claude.app (the top of this session's process tree) — flagged and done, not something automatable.
- [x] 2.6 `xcodebuild test` (full scheme, both `StarHubTHTests` and `StarHubTHUITests`) → **TEST SUCCEEDED**: 79 unit tests (3 skipped, live-network) + 2 UI tests, 0 failures.

## Phase 3 — CI + release.py — DONE

- [x] 3.1 Rewrote `.github/workflows/build.yml`/`release.yml`: `xcodebuild build`/`xcodebuild test -only-testing:StarHubTHTests` replace `build_app.py`/`run_tests.py`. CI only *runs* the unit-test target (`StarHubTHUITests` excluded from execution — needs a GUI session + Accessibility permission, see Phase 2.5, that a fresh CI runner isn't guaranteed to have). **Important nuance found the hard way (see below): `-only-testing:StarHubTHTests` only skips *running* `StarHubTHUITests` — `xcodebuild test` still *builds* every target in the scheme's test action first, so `StarHubTHUITests` must compile cleanly for CI to pass even though it never executes there.** Don't treat that target as CI-exempt when changing it.
- [x] 3.2 `release.py`'s build step now runs `xcodebuild build -project StarHubTH.xcodeproj -scheme StarHubTH -configuration Debug -derivedDataPath build` (Debug, matching what `build_app.py` always produced — it never distinguished Debug/Release) and locates the app at `build/Build/Products/Debug/StarHubTH.app`. Version-read/zip/`gh release` logic unchanged. Verified locally: `python3 release.py` builds, zips, and the archive's `Contents/Resources` (Localizable.strings, CHANGELOG.md, Info.plist) are all present and correct.
- [x] 3.3 Deleted `build_app.py`/`run_tests.py`. `build_config.py` trimmed to just `APP_NAME`/`APP_DIR` (release.py's only remaining consumer) — `TARGET_TRIPLE` dropped, nothing references it anymore. `scripts/check_standards.py`/`scripts/bump_version.py` verified still work unchanged. Added `build/` (release.py's `-derivedDataPath`) and `xcuserdata/` to `.gitignore`.

**The "unverified assumption" flagged here originally — resolved, and it mattered.** Whether the `macos-14` runner's default Xcode supports Swift 6 + File System Synchronized Groups turned out to be **no** (confirmed by a separate, parallel fix already on `main` before this branch merged: runners default to Xcode 15.4, with 16.1/16.2 present but not selected — both workflows now glob for `/Applications/Xcode_16*.app` explicitly and fail fast if none exists). That fix was carried over during the merge into this branch.

**Two more real bugs only surfaced once CI actually ran on the true Xcode 16.2 toolchain** — this local dev machine's Xcode/Swift toolchain is unusually new and more lenient, so `xcodebuild test` passing here was not proof of portability:
1. `SmokeUITests`'s `setUpWithError()`/`tearDownWithError()` overrides touched a `@MainActor`-isolated property from XCTestCase's synchronous, nonisolated override points — a hard Swift 6 error. Fixed by switching to the async `setUp()`/`tearDown()` overrides.
2. `AppLauncher.launch()` was a plain `static func` on a non-isolated enum calling `XCUIApplication`'s `@MainActor`-isolated APIs — fixed by marking it `@MainActor`.

Both fixed post-merge (commits `5940970`, `1c7d4db`); CI is now green end-to-end on real Xcode 16.2. **Lesson for future Swift 6 concurrency changes in this repo: verify on CI, not just locally, before trusting a green result.**

## Phase 4 — Docs — DONE

Rewrote every passage that documented the script-based pipeline as current fact:

- [x] 4.1 `CLAUDE.md` — "Build and test" section (xcodegen/xcodebuild commands, synced-group note, `StarHubTHUITests` not run in CI), "Layout" section (new entries for `project.yml`/`StarHubTH.xcodeproj`/`scripts/`/`StarHubTHUITests/`), header's stale "Swift 5" corrected to "Swift 6 language mode".
- [x] 4.2 `.agents/AGENTS.md` — "Build & verify" and "Things that will bite you" sections rewritten to the same commands/facts as CLAUDE.md.
- [x] 4.3 `docs/SWIFT_STANDARDS.md` — §3 `os.walk` claim, §6.3 concurrency-flag description (now points at `project.yml`'s `SWIFT_VERSION: "6"`), §10 "Today" paragraph (79 XCTest methods, `StarHubTHUITests` mentioned), §10's `run_tests.py` file-discovery paragraph, §12 checklist commands, §13's stale "past Swift 5" reading-list note.
- [x] 4.4 `docs/PROJECT_STRUCTURE.md` — opening paragraph, `StarHubTHApp.swift` tree comment, `Tests/` subfolder-reorg note — all now describe the Xcode File System Synchronized Group mechanism.
- [x] 4.5 `docs/RELEASING.md` — one line (`run_tests.py` → `xcodebuild test`, `release.py`'s build step → `xcodebuild`); rest of the versioning/Info.plist-source-of-truth policy is unchanged since `INFOPLIST_FILE` still points at the same file.
- [x] 4.6 `README.md`/`README_EN.md` — Developer/build sections rewritten in both languages; `README_EN.md`'s "Xcode ... for compiling from source" phrasing corrected (Xcode is now the primary path); Xcode version bumped 15.0 → 16.0 (needed for File System Synchronized Groups) in both.
- [ ] 4.7 Fold durable lessons from this migration into `SWIFT_STANDARDS.md`/`PROJECT_STRUCTURE.md`, then delete this file — left for a deliberate later pass, not bundled into this one, so the full migration record stays reviewable first.

**Confirmed out of scope, verified by grep**: `docs/DOMAIN_CONTEXT.md` (no build-system mentions). `docs/QOC_PLAN.md` was nearly-finished and deliberately left untouched by this migration when this note was first written — it has since been fully retired by a separate commit (`main`'s "QoC Phase F.4 — retire QOC_PLAN.md"), merged into this branch; nothing here needed to change as a result. `CHANGELOG.md`, `release.py`'s explanatory comment, and `scripts/generate_localizable_strings.py`'s docstring keep their `build_app.py` mentions deliberately — historical narrative, not live claims about current mechanics (the same standard that commit itself established).
