# Workspace Rules for StarHubTH

## Coding standards — binding

- **Read [`docs/SWIFT_STANDARDS.md`](../docs/SWIFT_STANDARDS.md) before writing or modifying any Swift.** It is binding, not advisory. Every rule has a worked before/after from this repo.
- **Check [`docs/PROJECT_STRUCTURE.md`](../docs/PROJECT_STRUCTURE.md) before creating any file.** It has the folder-by-folder import rules and a decision list for placement. Do not invent a location.
- **New observable state belongs in a feature store** (`Features/<Feature>/<Feature>Store.swift`), never a shared god object.
- **If a `docs/*_PLAN.md` tracking file exists** (e.g. `docs/QOC_PLAN.md`), it's the source of truth for in-progress, phase-ordered work — read it before touching anything it covers, and don't skip ahead of the current phase. These files are deleted once their work is done and any durable lesson is folded into `SWIFT_STANDARDS.md`/`PROJECT_STRUCTURE.md` — their absence means there's no active phased plan right now, not that the rule stopped applying.
- Before reporting a Swift change complete, walk the pre-merge checklist in `docs/SWIFT_STANDARDS.md` §12 and state your answers explicitly.
- If a standard genuinely cannot be met, leave a `// STANDARDS-EXCEPTION: <rule id> — <reason>` comment. Never skip a rule silently.

## Build & verify

- Always run `xcodebuild build -project StarHubTH.xcodeproj -scheme StarHubTH -configuration Debug` to build the StarHubTH application when compiling or verifying application changes.
- Automatically run that build after modifying Swift view files, view models, or project resources to verify the build passes cleanly.
- Run `xcodebuild test -project StarHubTH.xcodeproj -scheme StarHubTH -configuration Debug -destination 'platform=macOS' -testPlan Unit` after any change to models, services, or stores. Use `-testPlan Fast`/`Integration`/`UI` instead when the change is scoped to just that group — see `docs/SWIFT_STANDARDS.md` §10.
- Report the warning count. A change that adds warnings is not done.
- Only run `xcodegen generate` after editing `project.yml` itself — not needed for ordinary Swift file changes.

## Things that will bite you

- `StarHubTH`'s sources and `StarHubTHTests`'s sources are wired as Xcode File System Synchronized Groups — new subfolders under `StarHubTH/` or `Tests/` are picked up automatically, no project edit needed.
- `StarHubTHTests` (`Tests/`) is a real XCTest target — every file needs `@testable import StarHubTH`. Keep `@main` in a file named exactly `StarHubTHApp.swift`.
- `StarHubTHUITests` exists but isn't *run* in CI (needs a GUI session + Accessibility permission) — use `-testPlan UI` to run it locally. It still must *compile* cleanly for CI to pass: `xcodebuild test` builds every target in the scheme regardless of which test plan runs.
- The build **fails** if `assets/en.json` and `assets/th.json` key sets differ. Add every new user-facing string to both files.
- Never hardcode a user-facing string. Use an `L10n` key.
