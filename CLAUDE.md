# StarHubTH

macOS app (SwiftUI + AppKit) for managing Stardew Valley mods, saves, and Thai translations. Swift 5, target `arm64-apple-macos13.0`. Bilingual (en/th).

## Read this first

**[`docs/SWIFT_STANDARDS.md`](docs/SWIFT_STANDARDS.md) is binding for all Swift you write or modify.** Read it before your first Swift edit in a session. It is not a style suggestion — it encodes Apple's Swift API Design Guidelines plus the architecture decisions this project has committed to, with a concrete before/after for every rule drawn from this repo.

**[`docs/PROJECT_STRUCTURE.md`](docs/PROJECT_STRUCTURE.md)** says where every file goes — folder-by-folder import rules, the current layout, and a decision list for placing new files. Check it before creating any file.

**If a `docs/*_PLAN.md` tracking file exists** (e.g. `docs/QOC_PLAN.md`), it's the source of truth for whatever phased migration or audit is currently in progress — read it first and follow the phase order; don't refactor ahead of it opportunistically. These files are deleted once their work is done and any durable lesson is folded into `SWIFT_STANDARDS.md`/`PROJECT_STRUCTURE.md` — no such file existing right now means there's no active phased plan, not that this rule stopped applying. (`docs/REFACTOR_PLAN.md`, the original multi-phase refactor from god-object ViewModel to protocol-DI'd stores, finished all 9 phases and was retired this way — see git history for the full record.)

**[`docs/DOMAIN_CONTEXT.md`](docs/DOMAIN_CONTEXT.md)** explains what the app is and the external systems it wraps — read it before touching mod install, Nexus/SMAPI integration, packs/profiles, or saves. Bare-minimum goal: a native macOS alternative to Vortex, scoped to Stardew Valley only. Do not generalize the app to other games.

## Build and test

```bash
python3 build_app.py     # required after ANY Swift change — compiles + bundles + codesigns
python3 run_tests.py     # custom TestRunner (not XCTest)
open StarHubTH.app
python3 release.py       # zip to bundles/ for distribution
```

- `build_app.py` compiles every `.swift` under `StarHubTH/` via `os.walk`. **New subfolders need no build-script change.**
- `run_tests.py` compiles everything under `StarHubTH/` except the file named `StarHubTHApp.swift`, plus `Tests/`. Keep `@main` in a file with exactly that name.
- The build **hard-fails** if `assets/en.json` and `assets/th.json` have mismatched keys. That's intentional. Add every new user-facing string to both.

## Non-negotiables for new code

Full detail and rationale in `docs/SWIFT_STANDARDS.md`; this is the short list.

1. **No new code in `StarHubTHViewModel.swift`.** It's a 2,102-line god object with 43 `@Published` properties that is being dismantled. New state goes in a feature store under `Features/<Feature>/<Feature>Store.swift`.
2. **Every I/O boundary gets a protocol** and is injected. No `Service.shared` at a call site.
3. **`async`/`await`, never new completion handlers or `DispatchQueue`.** Stores are `@MainActor`; models are `Sendable`.
4. **Typed `throws` errors.** No new `try?`, no bare `catch {}`, no `-> Bool` to signal success, no `print(`.
5. **Swift naming.** No `get` prefix, no abbreviations (`vm`, `fm`, single-letter methods), argument labels that read as phrases.
6. **`struct` by default; `class` is `final` and justified.** Models import `Foundation` only — no `SwiftUI`/`Cocoa`, no store references.
7. **Views under ~150 lines.** `@Published` only for state some `body` actually reads; `private(set)` for anything views only read.

Before finishing any Swift change, walk the pre-merge checklist in `docs/SWIFT_STANDARDS.md` §12 and state your answers.

## Layout

```
StarHubTH/          app source — see docs/PROJECT_STRUCTURE.md for the full map
Tests/              custom TestRunner suites
assets/             en.json / th.json → generated .lproj/Localizable.strings, icons, custom UI
docs/               SWIFT_STANDARDS.md, PROJECT_STRUCTURE.md, DOMAIN_CONTEXT.md, plus any active docs/*_PLAN.md tracking file
build_app.py        build + bundle + codesign
run_tests.py        test runner
release.py          package to bundles/
```

Layering, enforced by folder — a wrong-direction import is visible in the path:

```
Views → Feature Stores → Services → Models
```

`Models/` imports `Foundation` only. `Services/` may know Models. Stores may know Services and Models. Views may know their own store and Models, never a service directly. `App/` is the only folder allowed to know everything.

## Conventions

- User-facing strings always go through the localization layer with an `L10n` key — never a literal.
- `CHANGELOG.md` is user-facing and ships inside the app bundle. Update it for anything a user would notice.
- Commit one concern at a time. Never mix a rename commit with a logic commit.
