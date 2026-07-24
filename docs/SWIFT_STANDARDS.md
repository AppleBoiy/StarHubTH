# StarHubTH — Swift & Apple Design Standards

**Status:** binding for all new and modified code.
**Baseline:** Swift 5, `arm64-apple-macos13.0`, SwiftUI + AppKit interop.
**Source of truth:** [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) and Apple's SwiftUI/Swift Concurrency guidance. Where this document and Apple's guidelines disagree, Apple wins — file an issue and fix this doc.

Every rule below is written as **Rule → Why → What's in the repo today → What to write instead.** The "in the repo today" lines are real, so nobody has to guess what the rule is reacting to.

---

## 0. How this is enforced

1. **Every PR / every agent change** runs through the [Pre-merge checklist](#12-pre-merge-checklist).
2. `.agents/AGENTS.md` and `CLAUDE.md` point here. Any agent touching Swift reads this file first.
3. New code is held to 100% of these rules. Touched code is held to the rules relevant to the change ("campsite rule" — leave it cleaner). Untouched legacy is migrated on the schedule in `docs/REFACTOR_PLAN.md`, not opportunistically.
4. A rule you cannot follow is a rule that gets an explicit, one-line `// STANDARDS-EXCEPTION: <rule id> — <reason>` comment. No silent exceptions.

---

## 1. Naming — clarity at the point of use

Apple's first principle: *clarity at the point of use is the most important goal.* Names are read far more often than written. Brevity is not a goal in itself.

### 1.1 No `get` prefix on accessors

**Rule.** Methods that return a value without side effects read as noun phrases. Drop `get`.

**Why.** `get` is an Objective-C artifact (where it meant "returns by out-parameter"). In Swift it adds a syllable and zero information.

**Today.** 13 offenders, including `getMissingDependencies(for:)`, `getModInfo(modId:apiKey:)`, `getDownloadLink(...)`, `getNote(for:)`, `getTopLevelFolder(for:)`, `getInstalledVersion()`, `getCollectionGraph(...)`.

```swift
// ✗ before
func getMissingDependencies(for mod: ModItem) -> [String]
func getModInfo(modId: Int, apiKey: String, completion: @escaping (Result<ModInfo, Error>) -> Void)
func getNote(for folderName: String) -> SaveNote
func getInstalledVersion() -> String?

// ✓ after
func missingDependencies(for mod: Mod) -> [Mod.ID]
func modInfo(id: Mod.NexusID) async throws -> ModInfo
func note(forSave folderName: String) -> SaveNote
var installedVersion: String? { get }        // no args, no side effects → property
```

**Corollary.** A no-argument, side-effect-free, cheap method should be a **property**, not a method. `getInstalledVersion()` → `installedVersion`.

### 1.2 Mutating/non-mutating pairs use the ed/ing rule

**Rule.** Mutating methods are imperative verbs (`sort()`, `enable()`); their non-mutating counterparts get `-ed`/`-ing` (`sorted()`, `enabling()`). Non-mutating methods that can't take a suffix read as noun phrases.

```swift
// ✓
mutating func enable(_ mod: Mod)
func enabling(_ mod: Mod) -> ModSet
```

### 1.3 Argument labels carry the grammar

**Rule.** The first argument label should make the call read as a phrase. Omit it only when the argument is the direct object of the verb, or for full-width type conversions.

**Today.** `func backupMod(mod: ModItem)` — "mod" is said twice and the label adds nothing. `func installThaiTranslation(mod: ThaiTranslationMod)` — same.

```swift
// ✗ before
vm.backupMod(mod: mod)
vm.installThaiTranslation(mod: translation)
vm.setNote(for: folderName, tag: tag, note: note)

// ✓ after
store.backUp(mod)                                   // direct object → no label
store.install(translation)
store.setNote(note, tag: tag, forSave: folderName)  // preposition begins the label, not floats alone
```

### 1.4 No abbreviations, no single-letter API

**Rule.** Spell words out. Abbreviations are permitted only when they are strictly more common than the expansion in every context (`URL`, `ID`, `HTML`, `API`). Uncommon abbreviations are banned in any name visible outside a single function body.

**Today.** This is the single most repeated violation in the codebase:

- `vm` appears as a property or parameter name **50 times** (`@ObservedObject var vm: StarHubTHViewModel` in 43 of them).
- `func L(_ key: String) -> String` — a public, single-letter method on the ViewModel, called from **408 sites**.
- `let fm = FileManager.default` throughout `SaveManager` and friends.
- `ModItem.modTag`, `ModItem.uniqueId` on a type already named `Mod*` — the `mod` prefix is redundant.

```swift
// ✗ before
struct ModListView: View {
    @ObservedObject var vm: StarHubTHViewModel
    Text(vm.L(L10n.Mods.title))
}

// ✓ after
struct ModListView: View {
    @EnvironmentObject private var mods: ModsStore
    @EnvironmentObject private var strings: LocalizationStore
    Text(strings[L10n.Mods.title])     // subscript reads better than a one-letter func
}
```

`L(_:)` is exempt from *nothing* — if the terseness is genuinely load-bearing at 408 call sites, express it as a `subscript` or a `LocalizedKey` type that resolves itself, not as a one-letter method.

### 1.5 Type names are nouns; protocol names are nouns or `-able`/`-ing`

**Rule.** Protocols describing *what something is* are nouns (`Collection`). Protocols describing a *capability* end in `-able`, `-ible`, or `-ing` (`Equatable`, `ModInstalling`).

**Today.** There are **zero protocols in the entire codebase** — see §4.

### 1.6 Don't encode the container in the member

**Rule.** Members inherit their type's context. Don't repeat it.

```swift
// ✗ before                          // ✓ after
struct ModItem {                     struct Mod {
    let uniqueId: String                 let id: ID
    var modTag: String                   var tag: Tag
}                                    }
```

Also: `ModItem`, `LogEntry`, `InventoryItem` — the `Item`/`Entry` suffix is filler. `Mod`, `LogLine`, `InventorySlot` are clearer. (Rename via Phase 6 of the refactor plan; do not churn these ad hoc.)

### 1.7 Booleans read as assertions

`isEnabled` ✓, `hasChildren` ✓, `showAlert` ✗ → `isAlertPresented`. `showSmapiAlerts` ✗ → `areSmapiAlertsPresented` or better, model it as state (§5.3).

---

## 2. Types and value semantics

### 2.1 Default to `struct`. Reach for `class` only for identity or reference-shared mutable state

**Rule.** Value types unless you need reference semantics, inheritance from an ObjC class, or a deliberate shared mutable lifetime.

**Today — this is done well.** The large majority of non-View types are `struct`/`enum`; `ModScanner`, `ModInstaller`, `SaveFileParser`, `SmapiLogParser`, `NXMParser`, `ModManifestParser` are all stateless value types with static/pure methods. **Keep this.** The exceptions (`SaveManager`, `NexusAPIService`, `ProfileManager`, `CollectionInstaller`, `SaveNotesStore`) are classes *only* because they're singletons — see §4.

### 2.2 Mark classes `final` unless designed for subclassing

**Today.** There are 10 classes in the repo and **not one is `final`**: `NexusAPIService`, `SaveManager`, `SaveNotesStore`, `ProfileManager`, `CollectionInstaller`, `SmapiInstaller`, `URLDispatcher`, `AppDelegate`, `StarHubTHViewModel`, and `ConfigTreeNode`. Nothing subclasses any of them. All 10 should be `final`. (`AppDelegate` inherits `NSObject` for the protocol conformance, but is itself a leaf.)

**Why.** `final` documents intent, enables static dispatch, and prevents accidental inheritance. Swift has no `sealed`; `final` is the tool.

### 2.3 Make illegal states unrepresentable

**Rule.** Prefer enums with associated values over parallel optional/boolean fields.

**Today.** `ThaiTranslationMod` carries `isInstalled: Bool` + `isOriginalModInstalled: Bool` — four representable combinations, three meaningful. `ModItem` carries `isGroup: Bool` + `children: [ModItem]?` — a group with `nil` children and a non-group with children are both constructible and both meaningless.

```swift
// ✗ before
struct ModItem {
    var children: [ModItem]?
    var isGroup: Bool = false
}
struct ThaiTranslationMod {
    var isInstalled: Bool = false
    var isOriginalModInstalled: Bool = false
}

// ✓ after
struct Mod {
    enum Kind {
        case single
        case group(children: [Mod])      // a group always has its children
    }
    let kind: Kind
}
enum TranslationAvailability {
    case installed
    case downloadable          // base mod present, translation not
    case baseModMissing
}
```

This also deletes the `mods.flatMap { $0.isGroup ? ($0.children ?? []) : [$0] }` incantation that is copy-pasted in `StarHubTHViewModel` (`resolveDependencyStatus`, `resolvePackModStatus`), with variants of the same "is it a group?" branch scattered through `ModListView`'s filter pipeline and `ModScanner`.

### 2.4 Strongly-typed identifiers over bare `String`/`Int`

**Rule.** IDs that flow across layers get a wrapper type.

**Today.** `uniqueId: String`, `folderName: String`, `nexusId: Int`, `modId: String`, `fileId: Int` are all raw and interchangeable at the type level. `setCustomTag(for modId: String, ...)` takes a SMAPI unique ID; `downloadModFromNexus(nexusId: Int, ...)` takes a Nexus numeric ID. Nothing stops you passing the wrong one.

```swift
// ✓
extension Mod {
    struct ID: Hashable, RawRepresentable { let rawValue: String }        // SMAPI UniqueID
    struct NexusID: Hashable, RawRepresentable { let rawValue: Int }
    struct FolderName: Hashable, RawRepresentable { let rawValue: String }
}
```

### 2.5 `Equatable`/`Hashable`/`Identifiable` conformance is deliberate

`Identifiable.id` must be **stable and unique**. `LogEntry` uses `let id = UUID()` — correct. `ModItem.id` returns `folderName` (the path relative to `Mods/`), which is stable across enable/disable since toggling moves the folder between `Mods/` and `Mods_disabled/` without renaming it — also correct.

The real hazard is `uniqueId`. `ModScanner` constructs group rows with `uniqueId: ""`, so **every group shares the empty-string identity**. Any lookup keyed on `uniqueId` can match a group by accident — `resolveDependencyStatus(for:)` compares dependency IDs against `uniqueId` case-insensitively, so a manifest declaring an empty dependency ID resolves to a group and reports `.active`. This is the §2.3 illegal-state problem again: a group is not a mod and should not be forced to carry a mod's identity. `Mod.Kind` fixes it structurally.

**Do not "fix" this by switching `id` to `uniqueId`** — that would collide every group onto one identity and is strictly worse.

---

## 3. Layering — the dependency rule

### 3.1 Dependencies point one direction only

```
        Views  ──────────────┐
          │                  │
          ▼                  ▼
    Feature Stores  ───►  Services  ───►  Models
   (observable state)   (I/O, network)  (pure values)
```

- **Models** import `Foundation` only. No `SwiftUI`, no `Cocoa`, no service or store types.
- **Services** import `Foundation`. They may know Models. They must not know Stores or Views.
- **Stores** may know Services and Models. They must not know Views.
- **Views** may know Stores and Models. They must not perform I/O directly.

**Today — violated in both directions:**

```swift
// StarHubTHViewModel.swift:120 — a MODEL reaching up into the VIEW MODEL
struct ThaiTranslationMod {
    func installationStatusText(vm: StarHubTHViewModel) -> String {
        if isInstalled { return vm.L(L10n.ThaiHub.installed) }
        ...
    }
}
```

A value type cannot be tested, reused, or reasoned about if it needs a 2,100-line ViewModel to answer a question about itself. Fix: the model exposes state, the view renders it.

```swift
// ✓ Model — pure
extension TranslationAvailability {
    var localizationKey: String {
        switch self {
        case .installed:      return L10n.ThaiHub.installed
        case .downloadable:   return L10n.ThaiHub.availableDownload
        case .baseModMissing: return L10n.ThaiHub.missingOriginal
        }
    }
}
// ✓ View — renders
Text(strings[translation.availability.localizationKey])
```

Also violated: `LogLevel` (a model enum) lives in the ViewModel file and imports `SwiftUI` to vend `var color: Color`. Colour is a presentation decision. Move the mapping to the design system.

### 3.2 One concept per file; file name matches the primary type

**Today.** `StarHubTHViewModel.swift` declares **12 types** before the ViewModel even starts: `ModDependency`, `DependencyStatus`, `ModItem`, `ModUpdateInfo`, `ThaiTranslationMod`, `LogLevel`, `LogSource`, `LogEntry`, `SaveViewMode`, `SaveSortOption`, `ModFilterStatus`, `ModFilterDate`, `ModSortOption`. `SaveManager.swift` declares five.

**Rule.** A file declares one primary type plus its tightly-coupled nested types and extensions. If you can't name the file after what's in it, it holds too much.

### 3.3 Target folder layout

```
StarHubTH/
├── App/                 StarHubTHApp, AppDelegate, URLDispatcher, DependencyContainer
├── Models/              pure value types — Foundation only
├── Services/            protocol + implementation pairs
│   ├── Nexus/           NexusAPIClient(+Protocol), NexusDownloader
│   ├── Mods/            ModScanner, ModInstaller, ModManifestParser
│   ├── Saves/           SaveStorage, SaveFileParser, SaveNotesStore
│   └── Smapi/           SmapiInstaller, SmapiLogParser
├── Features/            one folder per feature: <Feature>Store.swift + its Views
│   ├── Mods/  Saves/  Profiles/  ModPacks/  ThaiHub/  Logs/  Settings/  Home/
├── DesignSystem/        AppTheme, StardewPanel, StardewButton, SharedComponents
├── Localization/        L10n, LocalizationStore
└── Support/             shared extensions
```

`build_app.py` compiles via `os.walk("StarHubTH")`, so new subdirectories are picked up with **zero build-script changes**. Verified.

**[`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md) is the full expansion of this tree** — every folder's allowed imports, the complete current → target map for all 39 files, and a "where do I put a new file?" decision list. Consult it before creating any file.

Note that `Models/` today contains seven files that perform I/O (`ModInstaller`, `ModScanner`, `ModManifestParser`, `NexusDownloader`, `ProfileManager`, `SaveFileParser`, `SmapiLogParser`). Those are services. A parser is a capability, not a datum.

---

## 4. Protocol-oriented design and dependency injection

### 4.1 Every I/O boundary sits behind a protocol

**Rule.** Anything that touches the network, the filesystem, `UserDefaults`, the clock, or `NSWorkspace` is reached through a protocol, and the concrete implementation is injected.

**Why.** Swift is a protocol-oriented language; protocols are how you get testability without mocking frameworks. They are also how you keep a change to `NexusAPIService` from being a change to twelve views.

**Today.** `grep '^protocol' **/*.swift` returns **nothing**. There are zero abstraction seams in 12,000 lines. Consequences: `NexusAPIService.shared` is hit directly from the ViewModel, so no mod-update logic can be unit-tested without live network and a real API key. The existing `Tests/` folder can only cover the pure parsers (`NXMParser`, `SmapiLogParser`, `ModManifestParser`, `SaveFileParser`) — which is exactly what it does, and why coverage stops there.

```swift
// ✓ Protocol lives next to its use, named for the capability
protocol NexusAPIClient: Sendable {
    func modInfo(id: Mod.NexusID) async throws -> ModInfo
    func modFiles(id: Mod.NexusID) async throws -> [ModFile]
    func downloadLink(modID: Mod.NexusID, fileID: ModFile.ID) async throws -> URL
}

final class LiveNexusAPIClient: NexusAPIClient { /* URLSession */ }
struct StubNexusAPIClient: NexusAPIClient { /* fixtures, for Tests/ */ }
```

**Keep protocols narrow.** A protocol per capability, sized to what one consumer needs — not one `AppServicing` protocol with 40 methods.

### 4.2 No `.shared` at call sites

**Rule.** Singletons may exist as a composition-root convenience. They must never be referenced from inside a type that could otherwise be tested.

**Today.** **39 call sites across 5 app-owned singletons** — `SaveManager.shared` (13), `SaveNotesStore.shared` (10), `NexusAPIService.shared` (9), `ProfileManager.shared` (6), `CollectionInstaller.shared` (1) — plus `URLDispatcher.shared` (4). Every one is a hardcoded dependency.

*(Framework singletons — `NSWorkspace.shared` ×20, `URLSession.shared` ×10, `NSAppleEventManager.shared` ×1 — are legitimate, but the `URLSession` and `NSWorkspace` uses should still sit behind your own protocol so the calling type stays testable. `SmapiInstaller` is **not** a singleton; it's an `ObservableObject` injected via `@ObservedObject`, which is the pattern the others should move toward.)*

```swift
// ✗ before
func syncTagFromNexus(for mod: ModItem, ...) {
    NexusAPIService.shared.getModInfo(modId: modId, apiKey: apiKey) { ... }
}

// ✓ after
final class ModsStore: ObservableObject {
    private let nexus: NexusAPIClient
    init(nexus: NexusAPIClient) { self.nexus = nexus }

    func syncTag(for mod: Mod) async { let info = try? await nexus.modInfo(id: mod.nexusID) ... }
}
```

Composition happens once, in `App/DependencyContainer.swift`, and is handed down via `@EnvironmentObject` / initializer injection.

### 4.3 Protocol extensions for shared default behaviour, not inheritance

Swift's answer to a base class is a protocol extension. Use it. There is no class inheritance in this codebase today — keep it that way.

---

## 5. State and SwiftUI

### 5.1 One store per feature, not one ViewModel per app

**Rule.** Observable state objects are scoped to a feature. A store owns the state for one screen or one domain concern.

**Today.** `StarHubTHViewModel` is **2,102 lines with 43 `@Published` properties and ~90 methods**, covering: game directory detection, Steam user lookup, mod scanning, mod toggling, dependency resolution, tag inference, Nexus sync, mod install from zip/folder, SMAPI install/uninstall, SMAPI log tailing, app logging, save listing/editing/duplication/deletion, save backups and timelines, save notes, avatars, mod backup/restore, Thai translation hub, profiles, mod pack import/export, localization, and date formatting.

**Why this hurts, concretely.** Every one of those 43 `@Published` properties invalidates **every view** that holds `@ObservedObject var vm` — and 44 views do. Typing in a search box, ticking a mod, or a log line arriving from the SMAPI tail re-renders the entire app. It is also why 44 views are coupled to one type, so no view can be previewed, tested, or moved independently.

**Target decomposition** (details and sequencing in `docs/REFACTOR_PLAN.md`):

| Store | Owns | Approx. source today |
|---|---|---|
| `AppEnvironment` | game dir, Steam user, language, SMAPI version | VM ll. 380–670 |
| `ModsStore` | mod list, filters, toggle, install, tags, dependencies | VM ll. 231–960, 1356–1485 |
| `SavesStore` | saves, editing, backups, notes, avatars | VM ll. 1136–1330 |
| `ProfilesStore` | mod profiles, apply/sync | VM ll. 1699–1885 |
| `ModPacksStore` | export/import, Nexus collections | VM ll. 1884–2102 |
| `ThaiHubStore` | translation catalogue + install | VM ll. 1486–1698 |
| `LogStore` | app log + SMAPI tail | VM ll. 1000–1130 |
| `LocalizationStore` | current language, string lookup | VM ll. 549–613 |

### 5.2 State ownership: `@StateObject` creates, `@ObservedObject` borrows

**Rule.** The view that *owns* an observable object declares it `@StateObject`. Views that receive one declare `@ObservedObject` or take it from `@EnvironmentObject`. Never create an object in an `@ObservedObject` property — it will be re-created on every parent redraw.

**Today.** 2 `@StateObject` vs 44 `@ObservedObject` (43 of them `vm`), and **zero `@EnvironmentObject`**. `MainView` correctly owns the ViewModel with `@StateObject var vm = StarHubTHViewModel()` and passes it down explicitly to every screen — the rule is followed, but the manual pass-through is why 43 views name the same property.

One thing to fix while splitting: `StarHubTHApp` declares `@StateObject private var urlDispatcher = URLDispatcher.shared`. `@StateObject` means "this view creates and owns this object"; assigning an externally-owned singleton to it is a category error. It happens to work because the singleton outlives the view, but it should be `@ObservedObject` (or injected) — or `URLDispatcher` should stop being a singleton.

As stores are split, prefer `@EnvironmentObject` for the handful that are genuinely app-wide (`LocalizationStore`, `AppEnvironment`) and explicit injection for feature stores, so a view's dependencies stay visible in its signature.

### 5.3 Views hold view state; stores hold domain state

**Rule.** `@State` is for things that die with the view (text field contents, hover, sheet presentation). Domain state lives in the store.

**Today.** Both directions are broken. `searchText` lives in `ModListView` as `@State` ✓, but the filters it composes with (`modFilterStatus`, `modFilterTag`, `modFilterDate`, `modSortOption`) are `@Published` on the global ViewModel ✗ — they're view state. Meanwhile navigation/presentation state is on the ViewModel too: `editingModConfig`, `viewingModDetails`, `editingSave`, `viewingSaveTimeline`, `saveToDuplicate`, `backupToBranch`, `showAlert`, `alertMessage`, `requestedTab`. And `@Published var smapiLogTimer: Timer?` publishes a `Timer` — a non-`Equatable` reference object that no view renders, firing a global invalidation every time it's set.

**Rule of thumb.** If a property is not read by any view's `body`, it must not be `@Published`.

### 5.4 Derived state is computed, not stored

`availableTags` and `processedMods` in `ModListView` are computed properties ✓ — correct pattern. But `processedMods` runs a five-stage filter/sort pipeline on every `body` evaluation, and `body` is re-evaluated on every one of the 43 publishers. Correct shape, wrong invalidation frequency; §5.1 fixes it.

### 5.5 Decompose views at ~150 lines

**Rule.** A `View` file over ~150 lines, or a `body` over ~50, gets split into subviews. SwiftUI's diffing is per-view — small views are the performance mechanism, not just a style preference.

**Today.** `ModListView` 1,227 · `SavesView` 800 · `MainView` 625 · `ModConfigEditorView` 524 · `ModProfilesView` 419 · `ModDetailView` 412 · `ModPacksView` 384.

### 5.6 Prefer SwiftUI-native APIs over AppKit bridges

`import Cocoa` in a ViewModel and `NSOpenPanel` calls inside `openInstallModPanel()`/`selectGameDir()` mean the store can't be exercised without a running `NSApplication`. Put AppKit behind a protocol (§4.1) — `protocol FilePicking { func chooseDirectory() async -> URL? }` — so the store stays testable and the AppKit dependency is confined to one file.

---

## 6. Concurrency

### 6.1 Structured concurrency (`async`/`await`) is the default

**Rule.** New asynchronous work uses `async`/`await` and `Task`. Completion handlers are not written in new code. `DispatchQueue` is used only where a specific API demands it, with a comment saying which.

**Why.** Compiler-checked, cancellable, no callback nesting, and it's the only path to data-race safety.

**Today.** 65 `DispatchQueue` calls across 8 files, 23 `@escaping` completion handlers, `async` used in 8 files — the codebase is mid-migration with no rule about which side it's on. Everything on macOS 13 supports full structured concurrency; there is no compatibility reason to keep the old style.

```swift
// ✗ before — callback + manual hop + weak dance, 3 nesting levels
func syncTagFromNexus(for mod: ModItem, shouldRefresh: Bool = true, completion: @escaping (Bool) -> Void) {
    NexusAPIService.shared.getModInfo(modId: modId, apiKey: apiKey) { [weak self] result in
        DispatchQueue.main.async {
            switch result {
            case .success(let info): ...; completion(true)
            case .failure:           completion(false)
            }
        }
    }
}

// ✓ after
@MainActor
func syncTag(for mod: Mod) async throws {
    let info = try await nexus.modInfo(id: mod.nexusID)
    guard let categoryID = info.categoryID else { throw ModsError.missingCategory(mod.id) }
    setTag(NexusCategory(id: categoryID).tag, for: mod.id)
}
```

Note what disappears: the manual main-queue hop, `[weak self]`, the `Bool` success flag that discards the error, and the ambiguity about which thread the caller resumes on.

### 6.2 Annotate the actor

**Rule.** Every observable store is `@MainActor`. Every service that owns mutable state is an `actor` or is documented immutable/`Sendable`. Model types are `Sendable`.

**Today.** **Zero `@MainActor` annotations in the codebase.** `StarHubTHViewModel` publishes to SwiftUI from `URLSession` callbacks, timer callbacks, and `FileManager` work, and correctness rests entirely on 65 hand-written `DispatchQueue.main.async` calls being individually correct. One miss is a UI-thread violation the compiler currently cannot see.

```swift
@MainActor final class ModsStore: ObservableObject { ... }   // hops are now the compiler's job
actor SaveStorage { ... }                                     // owns filesystem serialization
struct Mod: Sendable, Identifiable { ... }
```

### 6.3 Turn on concurrency checking

Add to `build_app.py`'s `swiftc` invocation:

```python
"-Xfrontend", "-warn-concurrency",
"-Xfrontend", "-enable-actor-data-race-checks",
```

Warnings first (Phase 5 of the plan), then error-level once the count reaches zero. This is what makes §6.2 enforceable rather than aspirational.

### 6.4 Timers and file watchers are cancellable and owned

`@Published var smapiLogTimer: Timer?` on the ViewModel is a leak waiting to happen and a redraw trigger (§5.3). Replace with a `Task` held privately by `LogStore`, cancelled in `stopWatching()`:

```swift
private var tailTask: Task<Void, Never>?
func startWatching() {
    tailTask?.cancel()
    tailTask = Task { [weak self] in
        for await line in smapiLog.lines { await self?.append(line) }
    }
}
```

---

## 7. Errors

### 7.1 Typed errors, `throws`, and no silent swallowing

**Rule.** Recoverable failures are `throw`n as a domain-specific `Error` enum conforming to `LocalizedError`. `try?` is permitted only where "absent" is a legitimate, expected outcome, and gets a comment saying so.

**Today.** **71 `try?` and 42 bare `catch {`** against 42 `do {` blocks. A representative case:

```swift
// ✗ SaveManager.fetchSaves() — a permissions error, a missing directory, and
//    an empty saves folder are all reported to the user as "you have no saves".
guard let folders = try? fm.contentsOfDirectory(at: savesDir, ...) else { return [] }
```

```swift
// ✓
enum SaveStorageError: Error, LocalizedError {
    case savesDirectoryUnreadable(URL, underlying: Error)
    var errorDescription: String? { ... }
}

func saves() throws -> [SaveGameInfo] {
    do { ... } catch { throw SaveStorageError.savesDirectoryUnreadable(savesDirectory, underlying: error) }
}
```

`ModInstallerError` and `NexusDownloaderError` already do this correctly — that's the house pattern, apply it everywhere.

### 7.2 Don't return `Bool` for "did it work"

**Today.** `createBackup(info:) -> Bool`, `branchFromBackup(...) -> Bool`, `deleteBackup(_:) -> Bool`, `applyProfileToFilesystem(profile:) -> Bool`, and every `completion: (Bool) -> Void`. The caller is told *that* it failed and never *why*, so no user-facing message can be accurate.

**Rule.** `throws` for operations, `Result` only when crossing an API that needs a value. Never a bare `Bool`.

### 7.3 `print` is not logging

19 `print(` calls. Route everything through the app's `log(_:level:)` (soon `LogStore`) or `os.Logger`. `print` is invisible in a shipped `.app`.

---

## 8. Access control

**Rule.** Everything starts `private`. Widen only when a caller outside the file needs it. `internal` is a decision, not a default you fell into.

**Today.** Almost nothing is marked. All 43 `@Published` properties on the ViewModel are read-write from every view, so any view can mutate any state — there is no invariant a store can defend. `customModTags` is a good example of what that costs: it's a computed property that hits `UserDefaults.dictionary(forKey:)` on **every** read, and `ModListView` reads it twice per mod row inside `body` (`ModListView.swift:922, 929`). A plist decode per row per redraw, publicly writable, with no owner.

```swift
// ✓ readable everywhere, writable only by the owner
@Published private(set) var mods: [Mod] = []
func toggle(_ mod: Mod) { ... }        // the only way in
```

Apply `private(set)` to every store property that views only read. That single change turns 43 uncontrolled mutation points into an intentional API.

---

## 9. Documentation

- Public and `internal` API gets `///` doc comments with a one-sentence summary starting with a verb phrase. Add `- Parameters:`/`- Returns:`/`- Throws:` when non-obvious.
- Document **why**, not what. `// 1. Search` above a `.filter` is noise; `// SMAPI treats folder names case-insensitively on APFS, so compare folded` is worth its line.
- `// MARK: -` to section files — already used well in `StarHubTHViewModel`; keep it as files are split.

---

## 10. Testing

**Rule.** Every new service protocol ships with a stub implementation and at least one test. Pure functions (parsers, filters, sorters, dependency resolution) are tested directly.

**Today.** 10 files, 597 lines, driven by a hand-rolled `TestRunner` (not XCTest) via `run_tests.py`. Coverage is confined to the pure value types — `NXMParser`, `SmapiLogParser`, `ModManifestParser`, `SaveFileParser`, mod-update comparison, tag inference, Nexus collections. Nothing touching the ViewModel is tested, because nothing touching the ViewModel is testable.

`run_tests.py` compiles every file under `StarHubTH/` **except `StarHubTHApp.swift`** (matched by filename, not path) plus everything under `Tests/`. So:

- Extracting types into new folders is test-safe.
- Extracting `AppDelegate`/`URLDispatcher` out of `StarHubTHApp.swift` puts them **into** the test binary. That's fine (no `@main`), but keep `@main` in `StarHubTHApp.swift` and keep that filename.

Each store extracted in the refactor must arrive with tests. That's the acceptance criterion for the phase, not a follow-up.

---

## 11. Anti-patterns — quick reference

| Don't | Do | Rule |
|---|---|---|
| `func getFoo()` | `func foo()` / `var foo` | §1.1 |
| `vm`, `fm`, `L(_:)` | `mods`, `fileManager`, `strings[_:]` | §1.4 |
| `isGroup: Bool` + `children: [T]?` | `enum Kind { case single, group([T]) }` | §2.3 |
| `class Foo` (no `final`) | `final class Foo` | §2.2 |
| `Service.shared` at a call site | injected `protocol Servicing` | §4.2 |
| One ViewModel for the app | one store per feature | §5.1 |
| `@Published` for non-rendered state | `private` / `@State` | §5.3 |
| `DispatchQueue.main.async` | `@MainActor` | §6.2 |
| `completion: @escaping (Bool) -> Void` | `async throws` | §6.1, §7.2 |
| `try?` / `catch {}` | typed `throws` | §7.1 |
| `print(...)` | `LogStore` / `os.Logger` | §7.3 |
| `@Published var x` | `@Published private(set) var x` | §8 |

---

## 12. Pre-merge checklist

Copy into every PR description. An agent making changes states its answers explicitly.

**Naming**
- [ ] No `get`-prefixed methods; no-arg pure accessors are properties
- [ ] No abbreviations (`vm`, `fm`, single letters) in any name outside a function body
- [ ] Argument labels make call sites read as phrases
- [ ] Booleans read as assertions (`is`/`has`/`should`)

**Types & layering**
- [ ] New types are `struct`/`enum` unless reference semantics are required and justified
- [ ] New classes are `final`
- [ ] Models import `Foundation` only — no `SwiftUI`/`Cocoa`, no store references
- [ ] One primary type per file; filename matches
- [ ] No new illegal-state combinations (parallel `Bool`s / optionals)

**Dependencies**
- [ ] Every new I/O boundary has a protocol
- [ ] No new `.shared` references outside `App/DependencyContainer.swift`
- [ ] Dependencies are injected via `init` or `@EnvironmentObject`

**State**
- [ ] New observable state went into a feature store, not `StarHubTHViewModel`
- [ ] Every `@Published` property is read by some `body`
- [ ] Store properties views only read are `private(set)`
- [ ] New/changed views stay under ~150 lines

**Concurrency**
- [ ] New async work uses `async`/`await`, not completion handlers
- [ ] No new `DispatchQueue` (or a comment justifies it)
- [ ] New stores are `@MainActor`; new models are `Sendable`
- [ ] Build produces no new concurrency warnings

**Errors**
- [ ] No new `try?` or bare `catch {}` without a comment
- [ ] Failures `throw` typed errors; no `-> Bool` status returns
- [ ] No new `print(`

**Verification**
- [ ] `python3 build_app.py` succeeds with no new warnings
- [ ] `python3 run_tests.py` passes
- [ ] New service protocols have a stub + at least one test
- [ ] Localization keys exist in **both** `assets/en.json` and `assets/th.json` (the build fails otherwise — by design)

---

## 13. Reading list

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) — §1 is a compression of this; read the original.
- WWDC: *Protocol-Oriented Programming in Swift* (408, 2015) — §4.
- WWDC: *Meet async/await in Swift* (10132, 2021), *Protect mutable state with Swift actors* (10133, 2021) — §6.
- WWDC: *Data Essentials in SwiftUI* (10040, 2020), *Demystify SwiftUI* (10022, 2021) — §5.
- [Swift Concurrency Migration Guide](https://www.swift.org/migration/documentation/migrationguide/) — for when the target moves past Swift 5.
