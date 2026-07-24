# StarHubTH — Refactor Plan

**Goal.** Bring the codebase to the standards in [`SWIFT_STANDARDS.md`](SWIFT_STANDARDS.md) without a big-bang rewrite and without a release where the app is broken.

**Constraints this plan respects:**

- Target stays `arm64-apple-macos13.0`, Swift 5. No `@Observable`, no Swift 6 strict mode.
- Build is `python3 build_app.py` → `swiftc` over `os.walk("StarHubTH")`. **New subfolders need no build-script change.** Verified.
- Tests are `python3 run_tests.py` → a hand-rolled `TestRunner`, compiling everything under `StarHubTH/` except the file literally named `StarHubTHApp.swift`, plus `Tests/`. **Keep `@main` in a file with that exact name.**
- Single maintainer, shipping releases from `main`. Every phase must end green.

---

## Where we are

| Metric | Now | Target |
|---|---|---|
| Largest file | `StarHubTHViewModel.swift` — 2,102 lines | < 400 |
| `@Published` on one object | 43 | ≤ 8 per store |
| Protocols in codebase | **0** | one per I/O boundary |
| `@MainActor` annotations | **0** | every store |
| `DispatchQueue` calls | 65 | ~0 |
| `@escaping` completion handlers | 23 | 0 |
| App-singleton `.shared` call sites | 39 across 5 types | 0 outside composition root |
| `try?` / bare `catch {}` | 71 / 42 | justified only |
| `final` classes | 0 of 10 | 10 of 10 |
| Views > 400 lines | 7 | 0 |
| Test files / lines | 10 / 597 | grows each phase |

---

## Progress tracker

**This is the single source of truth for "what's done."** Tick a box in the *same commit* that finishes the step, and cite the step ID in the commit message (e.g. `refactor: Phase 1.2 — split StarHubTHViewModel models`). A new session's first move is: read this list, run `build_app.py` + `run_tests.py` to confirm the last checked step is still green, then start on the first unchecked box. Do not check a box until build and tests are both green.

- [ ] 0.1 Tag `pre-refactor-baseline`
- [ ] 0.2 Record baseline build log
- [ ] 0.3 Characterization tests (dependency resolution, pack status, ModListView filter/sort, profile chain resolution)
- [ ] 0.4 Add `-Xfrontend -warn-concurrency`, record baseline warning count
- [ ] 0.5 Docs link block in README.md / README_EN.md
- [ ] 1.1 Create folder skeleton
- [ ] 1.2 Split `StarHubTHViewModel.swift`
- [ ] 1.3 Split `SaveManager.swift`
- [ ] 1.4 Relocate remaining files per PROJECT_STRUCTURE.md
- [ ] 1.5 Mark all 10 classes `final`
- [ ] 1.6 Fix `URLDispatcher` `@StateObject` → `@ObservedObject`
- [ ] 2.1 Replace `ThaiTranslationMod` bool pair with `TranslationAvailability`
- [ ] 2.2 Move `LogLevel.color`/`.icon` out of Models
- [ ] 2.3 Introduce `Mod.Kind` (`.single` / `.group`)
- [ ] 2.4 Fix empty-`uniqueId` group latent bug + regression test
- [ ] 2.5 Add `Mod.ID` / `Mod.NexusID` / `Mod.FolderName` wrapper types
- [ ] 3.1 Define protocols at each I/O boundary
- [ ] 3.2 Rename implementations `Live*`, write `Stub*`
- [ ] 3.3 Composition root (`App/DependencyContainer.swift`)
- [ ] 3.4 Confine AppKit (`FilePicking`)
- [ ] 3.5 Wrap `UserDefaults` (`PreferenceStoring`)
- [ ] 4.1 `LocalizationStore`
- [ ] 4.2 `LogStore`
- [ ] 4.3 `ThaiHubStore`
- [ ] 4.4 `ProfilesStore`
- [ ] 4.5 `ModPacksStore`
- [ ] 4.6 `SavesStore`
- [ ] 4.7 `ModsStore`
- [ ] 4.8 `AppEnvironment`
- [ ] 4.9 Delete `StarHubTHViewModel`
- [ ] 5.1 `NexusAPIClient` → `async throws`
- [ ] 5.2 Convert remaining `@escaping` completion handlers
- [ ] 5.3 Annotate every store `@MainActor`
- [ ] 5.4 Filesystem services → `actor`
- [ ] 5.5 Conform models to `Sendable`
- [ ] 5.6 SMAPI log tailing → `AsyncStream`
- [ ] 5.7 Burn down `-warn-concurrency` warnings to zero
- [ ] 6.1 `vm` → store name at all call sites
- [ ] 6.2 Drop `get` prefix / convert to properties
- [ ] 6.3 Argument label sweep
- [ ] 6.4 Type renames (`ModItem` → `Mod`, etc.)
- [ ] 6.5 Member renames (`uniqueId` → `id`, etc.)
- [ ] 6.6 Boolean renames (`showAlert` → `isAlertPresented`, etc.)
- [ ] 6.7 Local `fm` → `fileManager`
- [ ] 7.1 Typed error enum per service
- [ ] 7.2 Audit all `try?`
- [ ] 7.3 Audit all bare `catch {}`
- [ ] 7.4 Replace `-> Bool` status returns with `throws`
- [ ] 7.5 Route `print(` calls into `LogStore`
- [ ] 7.6 Surface typed errors in UI + localization keys
- [ ] 8 View decomposition (`ModListView`, `SavesView`, `MainView`, `ModConfigEditorView`, `ModProfilesView`, `ModDetailView`, `ModPacksView`)
- [ ] 9.1 `scripts/check_standards.py`
- [ ] 9.2 Wire into `build_app.py` + GitHub Action
- [ ] 9.3 SwiftLint / swift-format config (optional)
- [ ] 9.4 Update `CHANGELOG.md`

**Current state (verified 2026-07-25): nothing above is checked.** The codebase is still flat (`Models/Services/Views`), 74 `.shared` call sites, 65 `DispatchQueue` calls, 0 protocols, 0 `@MainActor`. Start at 0.1.

---

## Sequencing principle

Phases are ordered so each one **makes the next one cheaper and is independently shippable**. Nothing here requires a long-lived branch. Rough order of risk:

```
P0 guardrails ── P1 extract types ── P2 fix layering ── P3 protocols+DI ── P4 split stores
   (none)          (mechanical)        (small)          (medium)          (highest)
                                                                              │
                                        P8 views ── P7 errors ── P6 naming ── P5 concurrency
                                        (medium)     (medium)     (medium)     (medium)
```

Phases 5–8 can be interleaved with feature work; 1–4 should run consecutively.

---

## Phase 0 — Guardrails

**Why first.** You cannot safely refactor 12,000 lines against a test suite that only covers parsers. This phase buys the safety net.

| Step | Detail |
|---|---|
| 0.1 | Tag the current commit `pre-refactor-baseline`. Every later phase diffs against it. |
| 0.2 | Record a baseline: `python3 build_app.py 2>&1 \| tee docs/baseline-build.log`, note warning count. |
| 0.3 | Write **characterization tests** for behaviour you're about to move: dependency resolution (`resolveDependencyStatus`), pack status (`resolvePackModStatus`), the `ModListView` filter/sort pipeline, profile chain resolution (`applyChainToSet`). These are pure logic buried in the ViewModel and the view — extract them to free functions *first*, test them, then refactor around them. |
| 0.4 | Add `-Xfrontend -warn-concurrency` to the `swiftc` args in `build_app.py`. Expect a wall of warnings — do not fix them yet. Record the count; it's the Phase 5 burndown number. |
| 0.5 | Add a `docs/` link block to `README.md` and `README_EN.md`. |

**Verification.** Build green, tests pass, new tests fail-then-pass when you deliberately break the logic they cover.
**Risk.** None — additive only.

---

## Phase 1 — Extract types out of the god files

**Why.** Purely mechanical, zero behaviour change, and it makes every later diff readable. Do it before anything semantic.

**The complete current → target file map for all 39 source files is in [`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md).** Follow it rather than improvising; the tables below are the execution order for that map.

**1.1 — Create the folder skeleton.** No files moved yet:

```
StarHubTH/{App,Features,DesignSystem,Localization,Support}/
StarHubTH/Services/{Nexus,Mods,Saves,Smapi,Profiles,System}/
```

**1.2 — Split `StarHubTHViewModel.swift` (2,102 lines).** Move, don't edit:

| Move to | Types |
|---|---|
| `Models/Mod.swift` | `ModItem`, `ModDependency`, `DependencyStatus` |
| `Models/ModUpdateInfo.swift` | `ModUpdateInfo` |
| `Models/ThaiTranslationMod.swift` | `ThaiTranslationMod` |
| `Models/LogEntry.swift` | `LogEntry`, `LogLevel`, `LogSource` |
| `Features/Mods/ModListFilters.swift` | `ModFilterStatus`, `ModFilterDate`, `ModSortOption` |
| `Features/Saves/SavesViewOptions.swift` | `SaveViewMode`, `SaveSortOption` |
| `Support/Dictionary+CaseInsensitive.swift` | the `Dictionary` extension at the top |
| `Models/ModTagInference.swift` | `ModItem.inferTag` — 60 lines of keyword matching in an `extension` |

The ViewModel drops to roughly 1,700 lines and now contains only the ViewModel.

**1.3 — Split `SaveManager.swift` (653 lines):** `Models/SaveGameInfo.swift`, `Models/SaveBackup.swift`, `Models/SaveNote.swift`, `Models/SaveNode.swift`, `Services/Saves/SaveNotesStore.swift`, `Services/Saves/SaveManager.swift`.

**1.4 — Relocate the rest**, per `PROJECT_STRUCTURE.md`. Two things worth flagging because they're easy to miss:

- **Seven files in `Models/` are actually services** — `ModInstaller`, `ModScanner`, `ModManifestParser`, `NexusDownloader`, `ProfileManager`, `SaveFileParser`, `SmapiLogParser` all perform I/O. They move to `Services/<Domain>/`. Only `InventoryItem`, `ModCollection`, `ModPack` and `ModProfile` are genuinely models and stay put. This is why the codebase reads as having "no I/O layer" — it has one, filed under `Models/`.
- `StarHubTHApp.swift` → `App/`, **keeping the filename** (`run_tests.py` excludes it by name). Split `AppDelegate` and `URLDispatcher` into their own files; both then compile into the test binary, which is harmless since neither carries `@main`.

**1.5 — Mark all 10 classes `final`:** `NexusAPIService`, `SaveManager`, `SaveNotesStore`, `ProfileManager`, `CollectionInstaller`, `SmapiInstaller`, `URLDispatcher`, `AppDelegate`, `ConfigTreeNode`, `StarHubTHViewModel`. Nothing subclasses any of them.

**1.6 — Fix `@StateObject private var urlDispatcher = URLDispatcher.shared`** in `StarHubTHApp.swift`. `@StateObject` declares ownership of an object the view creates; this one is externally owned. Change to `@ObservedObject`. One-line, zero behaviour change today, prevents a real bug the moment `URLDispatcher` stops being a singleton.

**Verification.** `git diff --stat` shows moves only; `build_app.py` and `run_tests.py` both green. Because Swift has no per-file imports, a pure move cannot change behaviour — if the build breaks, something wasn't a pure move.
**Risk.** Very low. Do it in one commit per numbered step so a bisect is trivial.

---

## Phase 2 — Fix the layering violations

**Why.** These are small, but they block Phase 3: you can't inject a service into a model that reaches upward into the ViewModel.

| Step | Fix | Standard |
|---|---|---|
| 2.1 | Delete `ThaiTranslationMod.installationStatusText(vm:)`. Replace the `isInstalled`/`isOriginalModInstalled` pair with `enum TranslationAvailability { case installed, downloadable, baseModMissing }` + a `localizationKey` property. Update `ThaiTranslationHubView` to render it. | §3.1, §2.3 |
| 2.2 | Move `LogLevel.color` and `LogLevel.icon` out of the model into `DesignSystem/LogLevel+Presentation.swift`. `Models/LogEntry.swift` then imports `Foundation` only. | §3.1 |
| 2.3 | Introduce `Mod.Kind` (`.single` / `.group(children:)`) replacing `isGroup` + `children:[ModItem]?`. Add `var allMods: [Mod]` to kill the duplicated `flatMap { $0.isGroup ? ($0.children ?? []) : [$0] }`. | §2.3 |
| 2.4 | **Latent bug.** `ModScanner` builds group rows with `uniqueId: ""`, so all groups share the empty identity, and `resolveDependencyStatus(for:)` — which compares dependency IDs to `uniqueId` — can resolve an empty dependency ID to a group and wrongly report `.active`. 2.3's `Mod.Kind` fixes this structurally: a group stops carrying a mod identity at all. Add a regression test. **Leave `ModItem.id = folderName` alone** — it is stable across toggling (the folder moves between `Mods/` and `Mods_disabled/`, it is not renamed) and switching it to `uniqueId` would collide every group. | §2.5 |
| 2.5 | Add `Mod.ID`, `Mod.NexusID`, `Mod.FolderName` wrapper types. Migrate signatures. This is where `setCustomTag(for modId:)` (SMAPI ID) vs `downloadModFromNexus(nexusId:)` (Nexus int) stop being confusable. | §2.4 |

**Verification.** Characterization tests from 0.3 must still pass. For 2.4, add a test asserting a mod declaring an empty-string dependency resolves `.missing`, not `.active`.
**Risk.** Low–medium. 2.3 and 2.5 touch many call sites but the compiler finds every one.

---

## Phase 3 — Protocols and dependency injection

**Why.** This is the highest-leverage phase. It's what makes Phase 4's stores testable, and it's the difference between "we have tests for parsers" and "we have tests".

**3.1 — Define protocols at each I/O boundary.** Narrow, one per capability:

```swift
protocol NexusAPIClient: Sendable { ... }        // was NexusAPIService.shared
protocol ModScanning { ... }                     // was ModScanner (already a value type ✓)
protocol ModInstalling { ... }                   // was ModInstaller
protocol SaveStoring { ... }                     // was SaveManager.shared
protocol SaveNoteStoring { ... }                 // was SaveNotesStore.shared
protocol ProfileStoring { ... }                  // was ProfileManager.shared
protocol SmapiInstalling { ... }                 // was SmapiInstaller.shared
protocol FilePicking { ... }                     // wraps NSOpenPanel — see 3.4
protocol PreferenceStoring { ... }               // wraps the 26 raw UserDefaults hits
```

**3.2 — Rename implementations** `Live*` (`LiveNexusAPIClient`) and write a `Stub*` for each in `Tests/Stubs/`.

**3.3 — Composition root.** `App/DependencyContainer.swift` holds the only `.shared`-equivalent instances and hands them to stores at init. Retire the 39 app-singleton call sites as each consumer is converted — expect most to fall out during Phase 4 rather than here. Framework singletons (`NSWorkspace.shared` ×20, `URLSession.shared` ×10) stay, but move behind `FilePicking` / the Nexus client so the *calling* type stays testable.

**3.4 — Confine AppKit.** `NSOpenPanel` currently lives inside `openInstallModPanel()`, `selectGameDir()` and `selectCustomAvatar()` on the ViewModel, which is why none of them can be tested. Move behind `FilePicking`; the only implementation imports `Cocoa`.

**3.5 — Wrap `UserDefaults`.** 26 direct hits. The worst is `customModTags`, a computed property that hits `UserDefaults.dictionary(forKey:)` on every read — and `ModListView` reads it twice per mod row inside `body` (lines 922, 929), so it's a plist decode per row per redraw. Behind `PreferenceStoring` it becomes cached, injectable, and testable.

**Verification.** Each protocol lands with a stub and at least one test that was impossible before. Test count should roughly double this phase.
**Risk.** Medium. Convert one service per commit, keep the old `.shared` alive until its last caller is gone.

---

## Phase 4 — Split the god ViewModel

**Why last among the structural phases.** With Phases 1–3 done, this is mostly moving already-extracted, already-testable code into the right container. Attempting it first would mean moving untested code with hardcoded dependencies.

**Extraction order — least-entangled first:**

| # | Store | Source (VM lines) | Notes |
|---|---|---|---|
| 4.1 | `LocalizationStore` | 380–413, 549–613 | Nearly standalone. Replace `L(_:)` with `subscript(_:)` here (§1.4). Every view touches it → do it first, alone, verify the app still speaks both languages. |
| 4.2 | `LogStore` | 1000–1130 | Replace `@Published var smapiLogTimer: Timer?` with a private `Task`. Removes a global invalidation source. |
| 4.3 | `ThaiHubStore` | 1486–1698 | Self-contained after 2.1. |
| 4.4 | `ProfilesStore` | 1699–1885 | Depends on `ProfileStoring` + `ModsStore` read access. |
| 4.5 | `ModPacksStore` | 1884–2102 | Depends on `NexusAPIClient`, `ModsStore`. |
| 4.6 | `SavesStore` | 1136–1330 | Depends on `SaveStoring`, `SaveNoteStoring`, `FilePicking`. |
| 4.7 | `ModsStore` | 231–960, 1356–1485 | Largest. Split again if it exceeds 400 lines: `ModsStore` + `ModTagStore`. |
| 4.8 | `AppEnvironment` | 380–670 | Game dir, Steam user, SMAPI version. Whatever is genuinely global. |
| 4.9 | Delete `StarHubTHViewModel` | — | If anything is left, it wasn't classified. Classify it. |

**Per-store recipe:**

1. Create `Features/<X>/<X>Store.swift`, `@MainActor final class`, dependencies injected.
2. Move properties and methods. Mark every view-read-only property `private(set)` (§8).
3. Move presentation state (`editingSave`, `viewingModDetails`, `showAlert`, …) **out** of the store into the owning view's `@State` (§5.3). Move filter state (`modFilterStatus`, `modFilterTag`, `modFilterDate`, `modSortOption`) into `ModListView`'s `@State` next to `searchText`.
4. Register in `DependencyContainer`, inject via `.environmentObject(...)` at `MainView`.
5. Swap `@ObservedObject var vm` for `@EnvironmentObject private var <x>` in that feature's views only.
6. Add tests for the store — now possible, because dependencies are protocols.
7. Build, test, run the app, exercise the feature by hand. Commit.

Note on 4.1: `L(_:)` has **408 call sites**. Do the rename to `subscript(_:)` mechanically in its own commit, separate from the store extraction, so the diff stays reviewable.

**Verification.** After each store: build green, tests green, feature manually exercised. After 4.9: the app should feel measurably more responsive — mod search and log tailing no longer redraw unrelated screens.
**Risk.** Highest in the plan, which is exactly why it's nine separate commits behind three phases of preparation.

---

## Phase 5 — Structured concurrency

Can start once Phase 3 lands (protocols are where `async` signatures are declared) and interleave with Phase 4.

| Step | Work |
|---|---|
| 5.1 | Convert `NexusAPIClient` protocol methods to `async throws`. Removes the largest cluster of `@escaping` + `DispatchQueue.main.async` pairs. |
| 5.2 | Convert remaining `@escaping` completion handlers (23 total): `syncTagFromNexus`, `installModFromZip`, `downloadModFromNexus`, `startDownload`, `importCollectionFromURL`, `selectCustomAvatar`. |
| 5.3 | Annotate every store `@MainActor`. Delete the `DispatchQueue.main.async` hops it makes redundant. |
| 5.4 | Make filesystem services `actor`s (`SaveStorage`, `ModInstaller`) so concurrent scans can't interleave writes. |
| 5.5 | Conform models to `Sendable`. Value types mostly get it free. |
| 5.6 | Replace `Timer`-based SMAPI log tailing with an `AsyncStream` + cancellable `Task` (§6.4). |
| 5.7 | Burn down the Phase 0.4 warning count to zero, then promote `-warn-concurrency` to error-level. |

**Verification.** Warning count strictly decreasing each commit. Run with `-enable-actor-data-race-checks` and exercise mod install + log tail + save edit concurrently.
**Risk.** Medium. `@MainActor` on a store surfaces every place work was silently happening off-main — those are real bugs, and the compiler is now showing them to you. Expect the diff to be larger than it looks.

---

## Phase 6 — Naming sweep

Do this **after** structure settles, so renames don't collide with moves. Every step is compiler-verified; none can silently break.

| Step | Rename |
|---|---|
| 6.1 | `vm` → the store's name at all 50 sites (`mods`, `saves`, `strings`, …). Mostly free once Phase 4 splits the views by feature. |
| 6.2 | Drop `get` from 13 methods; convert no-arg pure ones to properties (§1.1). |
| 6.3 | Argument labels: `backupMod(mod:)` → `backUp(_:)`, `installThaiTranslation(mod:)` → `install(_:)`, etc. (§1.3). |
| 6.4 | Types: `ModItem` → `Mod`, `LogEntry` → `LogLine`, `StarHubTHViewModel` → gone. `NexusAPIService` → `NexusAPIClient` (already done in 3.2). |
| 6.5 | Members: `ModItem.uniqueId` → `Mod.id`, `.modTag` → `.tag` (§1.6). |
| 6.6 | Booleans: `showAlert` → `isAlertPresented`, `showSmapiAlerts` → resolved by 5.3/§5.3 anyway. |
| 6.7 | Local `fm` → `fileManager`. |

**Risk.** Low, high churn. One rename category per commit; never mix a rename commit with a logic commit.

---

## Phase 7 — Error handling

| Step | Work |
|---|---|
| 7.1 | Define a typed error enum per service, `LocalizedError`-conforming, following the existing `ModInstallerError` / `NexusDownloaderError` pattern — those two are already correct. |
| 7.2 | Audit all 71 `try?`. Each becomes either a `throws` propagation or keeps `try?` **with a comment** saying why absence is expected. |
| 7.3 | Audit all 42 bare `catch {}`. Same treatment. |
| 7.4 | Replace `-> Bool` status returns with `throws`: `createBackup`, `branchFromBackup`, `deleteBackup`, `applyProfileToFilesystem`, and every `(Bool) -> Void` completion. |
| 7.5 | Route the 19 `print(` calls into `LogStore`. |
| 7.6 | Surface typed errors in the UI with real messages, replacing generic `showModal(message:)` strings. Add the localization keys to **both** `assets/en.json` and `assets/th.json` — `build_app.py` hard-fails on key mismatch, which is a feature. |

**Verification.** Deliberately break things — revoke the Nexus API key, chmod the saves directory, feed a corrupt zip — and confirm the user sees an accurate, localized message rather than silence.
**Risk.** Medium. This phase *changes user-visible behaviour by design*: failures that were silent now speak. That's the point, but it needs manual testing.

---

## Phase 8 — View decomposition

Do last; needs the stores from Phase 4 to be meaningful.

| File | Now | Split into |
|---|---|---|
| `ModListView` | 1,227 | `ModListView`, `ModRow`, `ModGroupRow`, `ModFilterBar`, `ModDropTarget`, `ModListToolbar`; move the filter/sort pipeline into a tested `ModListFilter` value type |
| `SavesView` | 800 | `SavesView`, `SaveCard`, `SaveGrid`, `SaveList`, `SaveToolbar` |
| `MainView` | 625 | `MainView`, `Sidebar`, `SidebarItem`, per-tab container views |
| `ModConfigEditorView` | 524 | `ModConfigEditorView`, `ConfigSection`, `ConfigField` (one per value kind) |
| `ModProfilesView` | 419 | + `ProfileRow`, `ProfileEditor` |
| `ModDetailView` | 412 | + `ModHeader`, `ModDependencyList`, `ModActions` |
| `ModPacksView` | 384 | + `PackRow`, `PackModStatusBadge` |

**Verification.** Every extracted subview gets a `#Preview`. If it can't be previewed, it's still over-coupled — that's the test.
**Risk.** Medium. Purely visual; regressions are immediately obvious.

---

## Phase 9 — Lock it in

| Step | Work |
|---|---|
| 9.1 | Add `scripts/check_standards.py`: fail the build on new `get`-prefixed funcs, new `.shared` outside `App/`, new `DispatchQueue`, files over 400 lines, non-`final` classes, `@Published` without `private(set)` where only read. Start as warnings, promote to errors. |
| 9.2 | Wire it into `build_app.py` and a GitHub Action on PR. |
| 9.3 | Add SwiftLint or `swift-format` with a config matching §1–§8 (optional — the custom script covers the repo-specific rules that no linter knows). |
| 9.4 | Update `CHANGELOG.md`; note the architecture change for contributors. |

---

## Definition of done

- `StarHubTHViewModel` no longer exists.
- No Swift file over 400 lines.
- App-owned `.shared` returns hits only in `App/DependencyContainer.swift` (framework singletons excepted).
- `grep -rc "DispatchQueue" StarHubTH/` → 0, or every hit carries a justifying comment.
- Every store is `@MainActor`; build is clean under `-warn-concurrency`.
- Every service has a protocol, a `Live` implementation, a `Stub`, and tests.
- `python3 build_app.py` and `python3 run_tests.py` both green; test suite is several times the current 597 lines.
- Checklist in `SWIFT_STANDARDS.md` §12 is automated wherever mechanically checkable.

---

## Suggested pacing

The phases are ordered by dependency, not by calendar. If you want a rhythm: 0–1 are an evening each and give immediate readability wins; 2 is a weekend; 3 is the one worth taking slowly because everything downstream depends on it; 4 is nine small commits, one per store, spread across whatever cadence suits; 5–8 interleave with normal feature work indefinitely. Ship a release after Phase 1 (pure structure, zero risk) and after Phase 4 (the responsiveness win) — both are natural checkpoints.
