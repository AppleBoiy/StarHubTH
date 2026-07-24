# StarHubTH — Project Structure

Companion to [`SWIFT_STANDARDS.md`](SWIFT_STANDARDS.md) (§3.3 states the rule) and [`REFACTOR_PLAN.md`](REFACTOR_PLAN.md) (Phase 1 executes the move). This file is the complete **current → target** map for all 39 source files, so nobody has to guess where a file goes.

`build_app.py` compiles via `os.walk("StarHubTH")` and `run_tests.py` does the same minus `StarHubTHApp.swift`. **Every folder below is free — no build-script change is needed for any of it.** The one hard constraint: `@main` must stay in a file named exactly `StarHubTHApp.swift`.

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

## Target tree

```
StarHubTH/
├── App/                                    ← composition root, app lifecycle
│   ├── StarHubTHApp.swift                  @main ONLY — keep this filename
│   ├── AppDelegate.swift
│   ├── URLDispatcher.swift
│   ├── DependencyContainer.swift           NEW (Phase 3) — the only place .shared lives
│   ├── AppEnvironment.swift                NEW (Phase 4.8) — game dir, Steam user, SMAPI version
│   └── MainView.swift                      app shell + sidebar; owns the stores
│
├── Models/                                 pure value types — Foundation ONLY
│   ├── Mod.swift                           Mod, Mod.Kind, Mod.ID/.NexusID/.FolderName, ModDependency, DependencyStatus
│   ├── Mod+TagInference.swift              the 60-line keyword matcher
│   ├── ModUpdateInfo.swift
│   ├── ModCollection.swift                 ModCollection, CollectionModItem
│   ├── ModPack.swift                       StarHubPack, StarHubPackMod
│   ├── ModProfile.swift
│   ├── ThaiTranslationMod.swift            + TranslationAvailability enum
│   ├── LogLine.swift                       LogLine, LogLevel, LogSource — no SwiftUI
│   ├── SaveGameInfo.swift
│   ├── SaveBackup.swift
│   ├── SaveNote.swift
│   ├── SaveNode.swift
│   └── InventoryItem.swift
│
├── Services/                               protocol + Live implementation per boundary
│   ├── Nexus/
│   │   ├── NexusAPIClient.swift            protocol
│   │   ├── LiveNexusAPIClient.swift        URLSession implementation
│   │   ├── NexusModels.swift               ModInfo, ModFile — the Decodables nested in NexusAPIService today
│   │   ├── NexusCategory.swift             the 26-case categoryTag switch
│   │   ├── NexusDownloader.swift
│   │   ├── CollectionInstaller.swift
│   │   └── NXMParser.swift                 nxm:// URL scheme — belongs with Nexus
│   ├── Mods/
│   │   ├── ModScanning.swift               protocol
│   │   ├── ModScanner.swift
│   │   ├── ModManifestParser.swift
│   │   ├── ModInstalling.swift             protocol
│   │   └── ModInstaller.swift              + ModInstallerError
│   ├── Saves/
│   │   ├── SaveStoring.swift               protocol
│   │   ├── SaveStorage.swift               was SaveManager
│   │   ├── SaveNoteStoring.swift           protocol
│   │   ├── SaveNotesStore.swift
│   │   └── SaveFileParser.swift
│   ├── Smapi/
│   │   ├── SmapiInstalling.swift           protocol
│   │   ├── SmapiInstaller.swift
│   │   └── SmapiLogParser.swift
│   ├── Profiles/
│   │   ├── ProfileStoring.swift            protocol
│   │   └── ProfileStorage.swift            was ProfileManager
│   └── System/
│       ├── FilePicking.swift               protocol — wraps NSOpenPanel
│       ├── FilePicker.swift                the ONLY non-view file importing Cocoa
│       ├── PreferenceStoring.swift         protocol — wraps UserDefaults
│       └── PreferenceStore.swift
│
├── Features/                               one folder per feature: Store + its Views
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── CoreModRow.swift
│   │   └── CoreModStatus.swift
│   ├── Mods/
│   │   ├── ModsStore.swift                 NEW (Phase 4.7)
│   │   ├── ModListFilter.swift             the filter/sort pipeline as a TESTED value type
│   │   ├── ModListFilters.swift            ModFilterStatus, ModFilterDate, ModSortOption
│   │   ├── ModListView.swift               ← 1,227 lines, split below
│   │   ├── ModRow.swift
│   │   ├── ModGroupRow.swift
│   │   ├── ModFilterBar.swift
│   │   ├── ModListToolbar.swift
│   │   ├── ModDropTarget.swift
│   │   ├── ModDetailView.swift             + ModHeader, ModDependencyList, ModActions
│   │   ├── ModConfigEditorView.swift       + ConfigTreeNode, ConfigSection, ConfigField
│   │   └── DependencyGraphView.swift       + ModNodeView, DependencyNodeView, ConnectionPathView
│   ├── Saves/
│   │   ├── SavesStore.swift                NEW (Phase 4.6)
│   │   ├── SavesViewOptions.swift          SaveViewMode, SaveSortOption
│   │   ├── SavesView.swift                 + SaveCard, SaveGrid, SaveList, SaveToolbar
│   │   ├── SaveTimelineView.swift          + BackupRow
│   │   └── SaveCopySheets.swift            DuplicateSaveSheet, BranchBackupSheet
│   ├── Profiles/
│   │   ├── ProfilesStore.swift             NEW (Phase 4.4)
│   │   └── ModProfilesView.swift           + ProfileRow, ProfileEditor
│   ├── ModPacks/
│   │   ├── ModPacksStore.swift             NEW (Phase 4.5)
│   │   └── ModPacksView.swift              + PackRow, PackModStatusBadge
│   ├── ThaiHub/
│   │   ├── ThaiHubStore.swift              NEW (Phase 4.3)
│   │   ├── ThaiTranslationHubView.swift
│   │   ├── ThaiModRow.swift
│   │   └── ThaiModDetailView.swift
│   ├── Logs/
│   │   ├── LogStore.swift                  NEW (Phase 4.2)
│   │   ├── LogsView.swift
│   │   └── LogEntryRow.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Changelog/
│       ├── AppChangelogView.swift
│       └── SimpleMarkdownView.swift
│
├── DesignSystem/                           reusable UI, knows nothing about the domain
│   ├── Color+Theme.swift
│   ├── VisualEffectBlur.swift
│   ├── GlassCard.swift
│   ├── ValleyToggleStyle.swift
│   ├── PillButton.swift
│   ├── AppButtonStyle.swift
│   ├── StardewPanel.swift
│   ├── StardewButton.swift
│   ├── StandardSection.swift
│   ├── StandardRow.swift
│   ├── InfoPopoverButton.swift
│   ├── View+Modifiers.swift                was Views/ViewExtensions.swift
│   └── LogLevel+Presentation.swift         NEW — .color/.icon moved OFF the model
│
├── Localization/
│   ├── L10n.swift                          the key namespace
│   └── LocalizationStore.swift             NEW (Phase 4.1) — replaces L(_:) with subscript(_:)
│
└── Support/
    ├── Dictionary+CaseInsensitive.swift
    └── Notification+Names.swift            the extension currently at LogsView.swift:311
```

---

## Complete file map — all 39 files

### Root (6 files)

| Today | Lines | Target |
|---|---|---|
| `StarHubTHApp.swift` | 49 | **splits →** `App/StarHubTHApp.swift` (`@main`, keep name), `App/AppDelegate.swift`, `App/URLDispatcher.swift` |
| `StarHubTHViewModel.swift` | 2,102 | **dissolves →** 5 model files, 2 feature enums, 1 support extension, then 8 stores (Phase 4). File is deleted at 4.9. |
| `SaveManager.swift` | 653 | **splits →** `Models/SaveGameInfo.swift`, `Models/SaveBackup.swift`, `Models/SaveNote.swift`, `Models/SaveNode.swift`, `Services/Saves/SaveStorage.swift`, `Services/Saves/SaveNotesStore.swift` |
| `NexusAPIService.swift` | 502 | **splits →** `Services/Nexus/{NexusAPIClient,LiveNexusAPIClient,NexusModels,NexusCategory}.swift` |
| `SmapiInstaller.swift` | 416 | → `Services/Smapi/SmapiInstaller.swift` (+ extract `SmapiInstalling` protocol) |
| `L10n.swift` | 532 | → `Localization/L10n.swift` |

### `StarHubTHViewModel.swift` breakdown

| Content | Target |
|---|---|
| `Dictionary.caseInsensitiveValue` | `Support/Dictionary+CaseInsensitive.swift` |
| `ModItem`, `ModDependency`, `DependencyStatus`, `PackModStatus` | `Models/Mod.swift` |
| `ModItem.inferTag` (60 lines) | `Models/Mod+TagInference.swift` |
| `ModUpdateInfo` | `Models/ModUpdateInfo.swift` |
| `ThaiTranslationMod` | `Models/ThaiTranslationMod.swift` |
| `LogEntry`, `LogLevel`, `LogSource` | `Models/LogLine.swift` (+ `.color`/`.icon` → `DesignSystem/`) |
| `ModFilterStatus`, `ModFilterDate`, `ModSortOption` | `Features/Mods/ModListFilters.swift` |
| `SaveViewMode`, `SaveSortOption` | `Features/Saves/SavesViewOptions.swift` |
| the class body (~1,700 lines) | 8 stores across `Features/*/` + `App/AppEnvironment.swift` |

### `Models/` (11 files) — 7 of these are misfiled today

`Models/` should hold data, not behaviour. Seven current occupants are services:

| Today | Lines | Target | Why |
|---|---|---|---|
| `Models/ModInstaller.swift` | 158 | `Services/Mods/ModInstaller.swift` | performs filesystem I/O |
| `Models/ModScanner.swift` | 91 | `Services/Mods/ModScanner.swift` | walks the filesystem |
| `Models/ModManifestParser.swift` | 94 | `Services/Mods/ModManifestParser.swift` | reads files |
| `Models/NexusDownloader.swift` | 73 | `Services/Nexus/NexusDownloader.swift` | network |
| `Models/ProfileManager.swift` | 153 | `Services/Profiles/ProfileStorage.swift` | persistence |
| `Models/SaveFileParser.swift` | 75 | `Services/Saves/SaveFileParser.swift` | reads files |
| `Models/SmapiLogParser.swift` | 96 | `Services/Smapi/SmapiLogParser.swift` | reads files |
| `Models/InventoryItem.swift` | 15 | **stays** | pure data ✓ |
| `Models/ModCollection.swift` | 14 | **stays** | pure data ✓ |
| `Models/ModPack.swift` | 42 | **stays** | pure data ✓ |
| `Models/ModProfile.swift` | 7 | **stays** | pure data ✓ |

*A parser is a capability, not a datum. That most of them are already `struct`s with `static` methods is good design — they just live in the wrong folder, which is why they read as "models" and get skipped when someone looks for the I/O.*

### `Services/` (2 files)

| Today | Lines | Target |
|---|---|---|
| `Services/NXMParser.swift` | 29 | `Services/Nexus/NXMParser.swift` |
| `Services/CollectionInstaller.swift` | 24 | `Services/Nexus/CollectionInstaller.swift` |

### `Views/` (20 files)

| Today | Lines | Target |
|---|---|---|
| `ModListView.swift` | 1,227 | `Features/Mods/` — splits into 6 files + `ModListFilter` value type |
| `SavesView.swift` | 800 | `Features/Saves/` — splits into 5 files |
| `MainView.swift` | 625 | `App/MainView.swift` — splits out `Sidebar`, `SidebarItem` |
| `ModConfigEditorView.swift` | 524 | `Features/Mods/` — splits into 3 files |
| `ModProfilesView.swift` | 419 | `Features/Profiles/` — splits into 3 |
| `ModDetailView.swift` | 412 | `Features/Mods/` — splits into 4 |
| `ModPacksView.swift` | 384 | `Features/ModPacks/` — splits into 3 |
| `ThaiTranslationHubView.swift` | 314 | `Features/ThaiHub/` — 3 types already inside → 3 files |
| `LogsView.swift` | 313 | `Features/Logs/` — + `LogEntryRow.swift`; `Notification.Name` ext → `Support/` |
| `SaveTimelineView.swift` | 291 | `Features/Saves/` — + `BackupRow.swift` |
| `HomeView.swift` | 284 | `Features/Home/` — + `CoreModRow`, `CoreModStatus` |
| `DependencyGraphView.swift` | 268 | `Features/Mods/` — 4 types inside → 4 files |
| `SettingsView.swift` | 260 | `Features/Settings/` |
| `AppTheme.swift` | 150 | `DesignSystem/` — 8 types inside → 6 files |
| `SaveCopySheets.swift` | 108 | `Features/Saves/` — 2 sheets |
| `SharedComponents.swift` | 99 | `DesignSystem/` — 3 types → 3 files |
| `AppChangelogView.swift` | 83 | `Features/Changelog/` — + `SimpleMarkdownView` |
| `StardewPanel.swift` | 22 | `DesignSystem/` |
| `ViewExtensions.swift` | 16 | `DesignSystem/View+Modifiers.swift` |
| `StardewButton.swift` | 7 | `DesignSystem/` |

### `Tests/`

```
Tests/
├── main.swift                  keep — entry point
├── TestRunner.swift            keep
├── Stubs/                      NEW (Phase 3.2) — one Stub per protocol
│   ├── StubNexusAPIClient.swift
│   ├── StubSaveStoring.swift
│   ├── StubProfileStoring.swift
│   ├── StubFilePicking.swift
│   └── StubPreferenceStoring.swift
├── Models/                     ModTagInferenceTests, ModUpdateTests
├── Services/                   NXMParserTests, SmapiLogParserTests, ModManifestParserTests,
│                               SaveFileParserTests, NexusCollectionTests, SmapiInstallerTests
└── Features/                   NEW — one suite per store, added as each is extracted
```

Reorganising `Tests/` into subfolders is safe: `run_tests.py` walks `Tests/` recursively.

---

## Counts

| | Now | Target |
|---|---|---|
| Source files | 39 | ~110 |
| Top-level source folders | 3 | 8 |
| Largest file | 2,102 lines | < 400 |
| Files > 400 lines | 8 | 0 |
| Median file | ~150 lines | ~80 |

Roughly triple the file count. That's the point — a file is the unit you navigate, review, and diff. 110 files averaging 80 lines is far easier to work in than 39 averaging 315 with one at 2,102.

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
