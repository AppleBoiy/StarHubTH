# Workspace Rules for StarHubTH

## Coding standards — binding

- **Read [`docs/SWIFT_STANDARDS.md`](../docs/SWIFT_STANDARDS.md) before writing or modifying any Swift.** It is binding, not advisory. Every rule has a worked before/after from this repo.
- **Check [`docs/PROJECT_STRUCTURE.md`](../docs/PROJECT_STRUCTURE.md) before creating any file.** It has the folder-by-folder import rules and a decision list for placement. Do not invent a location.
- **Follow [`docs/REFACTOR_PLAN.md`](../docs/REFACTOR_PLAN.md) when touching legacy code.** Phases are dependency-ordered. Do not refactor ahead of the current phase.
- **Do not add code to `StarHubTH/StarHubTHViewModel.swift`.** It is a god object being dismantled. New observable state belongs in a feature store.
- Before reporting a Swift change complete, walk the pre-merge checklist in `docs/SWIFT_STANDARDS.md` §12 and state your answers explicitly.
- If a standard genuinely cannot be met, leave a `// STANDARDS-EXCEPTION: <rule id> — <reason>` comment. Never skip a rule silently.

## Build & verify

- Always run `./build_app.py` (or `python3 build_app.py`) to build the StarHubTH application when compiling or verifying application changes.
- Automatically execute `./build_app.py` after modifying Swift view files, view models, or project resources to verify the build passes cleanly.
- Run `python3 run_tests.py` after any change to models, services, or stores.
- Report the warning count. A change that adds warnings is not done.

## Things that will bite you

- `build_app.py` walks `StarHubTH/` recursively — new subfolders are picked up automatically, no script edit needed.
- `run_tests.py` compiles everything under `StarHubTH/` **except the file named `StarHubTHApp.swift`** (matched by filename, not path). Keep `@main` in a file with that exact name.
- The build **fails** if `assets/en.json` and `assets/th.json` key sets differ. Add every new user-facing string to both files.
- Never hardcode a user-facing string. Use an `L10n` key.
