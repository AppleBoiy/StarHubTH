# StarHubTH — Project Structure

Companion to [`SWIFT_STANDARDS.md`](SWIFT_STANDARDS.md) (§3.3 states the rule). Explains the folder layout and the layering rule behind it, so nobody has to guess where a new file goes. The refactor that established this structure (`docs/REFACTOR_PLAN.md`, Phases 0–9) is complete — this doc now describes the current codebase, not a migration target.

`StarHubTH.xcodeproj` (generated from `project.yml` via XcodeGen) wires `StarHubTH/` and `Tests/` in as Xcode File System Synchronized Groups. **Every folder below is free — no project change is needed for any of it.** The one hard constraint: `@main` must stay in a file named exactly `StarHubTHApp.swift`.

---

## The layering rule

```
        Views  ──────────────┐
          │                  │
          ▼                  ▼
    Feature Stores  ───►  Services  ───►  Models
   (observable state)   (I/O, network)  (pure values)
```

Each folder maps to exactly one layer, so a wrong-direction import is visible in the file path:

| Folder | Layer | May import | Must not import |
|---|---|---|---|
| `Models/` | data | `Foundation` only | SwiftUI, Cocoa, services, stores |
| `Services/` | I/O | Foundation, Models | stores, views |
| `Features/*/Store` | state | Foundation, SwiftUI, Models, Services | views |
| `Features/*/Views` | UI | SwiftUI, Models, its own store | services directly |
| `DesignSystem/` | UI primitives | SwiftUI | Models, services, stores |
| `Localization/` | cross-cutting | Foundation | services, stores |
| `Support/` | extensions | Foundation | everything else |
| `App/` | composition | everything | — |

`App/` is the only folder allowed to know about everything — that's what a composition root is for.

---

## Current tree

The refactor this doc originally planned (`docs/REFACTOR_PLAN.md`, Phases 0–9) is complete — this is the actual layout, not an aspiration. It's deliberately a **pattern with representative examples per folder, not an exhaustive file listing** — the previous exhaustive map went stale the moment new files were added after it was written (Phase 8's view decomposition alone added ~35 files it never mentioned). If you need the full current list, `find StarHubTH -name "*.swift"` is always authoritative; this doc explains *why* a file is where it is, not an index of all 107.

```
StarHubTH/
├── App/                    composition root, app lifecycle — the only folder allowed to know everything
│   ├── StarHubTHApp.swift  @main ONLY — keep this filename (the one app target entry point)
│   ├── DependencyContainer.swift   the only place .shared lives
│   ├── AppCoordinator.swift        cross-store orchestration; owns no @Published state of its own
│   ├── AppEnvironment.swift        game dir, Steam user, SMAPI version
│   ├── AlertStore.swift            app-wide modal/alert state
│   └── MainView.swift + MainSidebarView.swift   app shell + sidebar; the real composition root — constructs every store
│
├── Models/                 pure value types — Foundation ONLY, no SwiftUI/Cocoa, no store references
│   ├── Mod.swift            Mod, Mod.Kind, Mod.UniqueID/.NexusID/.FolderName, ModDependency, DependencyStatus
│   ├── ModGraph.swift        dependency/group resolution as pure functions (fully unit-tested)
│   └── LogLine.swift, SaveGameInfo.swift, SaveBackup.swift, ThaiTranslationMod.swift, ...
│
├── Services/                protocol + Live implementation per I/O boundary, one subfolder per domain
│   ├── Nexus/               NexusAPIClient (protocol) + LiveNexusAPIClient, NXMParser, CollectionInstaller, NexusDownloader
│   ├── Mods/                ModScanning/ModInstalling (protocols) + ModScanner, ModInstaller, ModManifestParser
│   ├── Saves/                SaveStoring/SaveNoteStoring (protocols) + SaveManager, SaveNotesStore, SaveFileParser, SaveStorageError
│   ├── Smapi/                SmapiInstalling (protocol) + SmapiInstaller, SmapiLogParser
│   ├── Profiles/              ProfileStoring (protocol) + ProfileManager, ProfileApplyError
│   └── System/                 FilePicking (protocol) + FilePicker — the ONLY non-view file importing Cocoa (§4.2 rule)
│
├── Features/                one folder per feature: Store + its Views, named plainly (e.g. Mods/, Saves/, Profiles/)
│   └── <Feature>/
│       ├── <Feature>Store.swift    @MainActor, injected dependencies, the only thing a View touches besides Models
│       └── <views...>              each view under ~150 lines; large views (Phase 8) split into small focused files
│
├── DesignSystem/            reusable UI, knows nothing about the domain — SwiftUI (+ AppKit for rendering helpers) only
│
├── Localization/
│   ├── L10n.swift            the key namespace — every user-facing string goes through here
│   └── LocalizationStore.swift
│
└── Support/                 extensions on stdlib/Foundation types, nothing domain-specific
```

**`Tests/`** mirrors the same idea — see the dedicated section below.

---

### `Tests/`

```
Tests/
├── main.swift                  keep — entry point
├── TestRunner.swift            keep
├── Stubs/                      one Stub per protocol (Phase 3.2)
│   ├── StubNexusAPIClient.swift, StubSaveStoring.swift, StubProfileStoring.swift,
│   └── StubFilePicking.swift, StubPreferenceStoring.swift, StubModInstalling.swift,
│       StubModScanning.swift, StubSaveNoteStoring.swift, StubError.swift
├── Models/                     ModTagInferenceTests, ModGraphTests, ModListFilterTests
├── Services/                   NXMParserTests, SmapiInstallerTests, SmapiLogParserTests,
│                               ModManifestParserTests, SaveFileParserTests, SaveManagerTests
├── Features/                   one suite per store: LocalizationStoreTests, LogStoreTests,
│                               ProfilesStoreTests, SavesStoreTests, AppEnvironmentTests,
│                               ModPacksStoreTests, ModsStoreTests
└── Integration/                real network calls (Nexus API / GitHub API), gated behind
                                 STARHUB_SKIP_LIVE_TESTS (LiveTestGate.swift) — CI sets it,
                                 a local run with a real Nexus API key exercises them for real.
                                 NXMDownloadIntegrationTests, SmapiInstallerIntegrationTests,
                                 ModUpdateTests, NexusCollectionTests
```

Reorganising `Tests/` into subfolders is safe: it's an Xcode File System Synchronized Group (`project.yml`), recursively mirrored the same as `StarHubTH/`.

**Why `Integration/` exists (QoC audit, see `docs/QOC_PLAN.md`):** `NXMParserTests` and
`SmapiInstallerTests` each used to mix pure logic (parsing, string handling — fast,
deterministic, no external dependency) with one method that makes a real network call. That
made "is this test suite fast and deterministic" a per-method question, not a per-file one,
and `SmapiInstallerTests`'s live GitHub check had no skip gate at all — it ran unconditionally,
including in CI. The fix: split the live method out into `Integration/`, leaving the pure
logic in `Services/` under its original name. Every file in `Integration/` uses the same
`LiveTestGate.skipIfNeeded(_:)` check, so there's one mechanism (`STARHUB_SKIP_LIVE_TESTS`),
not an inconsistent mix of an implicit "skip if no API key" check on some files and nothing
on others.

---

## Counts

| | Before the refactor | Now |
|---|---|---|
| Source files | 39 | 107 |
| Top-level source folders | 3 | 7 |
| Largest file | 2,102 lines (`StarHubTHViewModel.swift`) | 588 lines (`ModsStore.swift`) |
| Files > 400 lines | 8 | 4 (none are views — `check_standards.py` tracks this ongoing) |
| Median file | ~150 lines | ~60 lines |

Nearly triple the file count. That's the point — a file is the unit you navigate, review, and diff. 107 files averaging small is far easier to work in than 39 averaging 315 with one at 2,102. These numbers will drift as the app grows; re-run the `find`/`wc` commands above rather than trusting this table indefinitely — that's exactly the staleness this doc's `Tests/`/tree sections already learned the hard way.

---

## Where do I put a new file?

1. **Is it pure data, no I/O, no SwiftUI?** → `Models/`
2. **Does it touch network, disk, `UserDefaults`, `NSWorkspace`, or the clock?** → `Services/<Domain>/`, behind a protocol
3. **Is it observable state for one screen or domain?** → `Features/<Feature>/<Feature>Store.swift`
4. **Is it a view for one feature?** → `Features/<Feature>/`
5. **Is it a reusable UI piece with no domain knowledge?** → `DesignSystem/`
6. **Is it a string or a key?** → `Localization/` (and add to **both** `assets/en.json` and `assets/th.json`)
7. **Is it an extension on a stdlib/Foundation type?** → `Support/`
8. **Is it app lifecycle or wiring?** → `App/`

If a file seems to belong in two places, it's doing two things — split it.
