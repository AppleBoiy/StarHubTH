# StarHubTH — Domain Context

**Read this if you're touching mod installation, Nexus integration, SMAPI, profiles/packs, or saves.** It's the domain knowledge `SWIFT_STANDARDS.md`/`PROJECT_STRUCTURE.md`/`REFACTOR_PLAN.md` don't cover — what the app is *for* and what the external systems it talks to actually look like.

## What this app is

**Bare-minimum goal: a native macOS alternative to [Vortex](https://www.nexusmods.com/about/vortex/)** (Nexus Mods' official mod manager), **scoped to one game only — Stardew Valley.** Vortex doesn't ship a macOS build; that gap is the entire reason this app exists.

This scoping decision is load-bearing for every design choice in the codebase:

- No game-abstraction layer, no "profile per game," no plugin system for other titles. `Mods/`, `manifest.json`, SMAPI, and the Nexus Stardew Valley game domain are hardcoded assumptions, not configuration — and that's intentional, not a shortcut to fix later.
- The bar for "done" on any mod-management feature is **parity with what Vortex does for Stardew Valley specifically**, not full Vortex feature parity across every game it supports (collections UI, LOOT-style load-order solvers for Bethesda games, FOMOD installers, etc. are out of scope unless Stardew Valley mods actually use them).
- Published on Nexus Mods itself as a tool page (`nexus_description.txt`, `nexus_changelog.txt` at repo root are the listing copy — Thai-language, since the author also ships a companion [Thai translation pack](https://github.com/AppleBoiy/stardew-thai-translations)). The app is bilingual (en/th) because its primary audience is the Thai Stardew Valley modding community.

If a task description sounds like "add support for game X" or "generalize this to work with any game," that's a scope violation — flag it rather than building it.

## SMAPI (Stardew Modding API)

SMAPI is the third-party mod loader almost all Stardew Valley mods require — it replaces the game's launcher executable and exposes a plugin API mods hook into. This app installs, launches through, and monitors SMAPI; it does not reimplement any of its loading logic.

- **Install**: `StarHubTH/Services/Smapi/SmapiInstaller.swift`. Runs SMAPI's real installer under the hood and swaps the launcher binary; the original is preserved as `StardewValley-original` inside the game directory (its presence is literally how the app detects "SMAPI is installed" — see `getInstalledVersion`).
- **Version detection is a real workaround, not incidental complexity.** SMAPI's own packaging carries no reliable "what version is this" artifact after install (verified directly: no `smapi-internal/manifest.json`, `.deps.json` is an empty stub, `.runtimeconfig.json` only names the .NET runtime). So the app writes its own marker file, `smapi-internal/.starhubth-installed-version`, right after a successful install, and falls back to parsing `~/.config/StardewValley/ErrorLogs/SMAPI-latest.txt`'s first line only for installs it didn't perform itself. Don't "simplify" this by assuming SMAPI exposes its version somewhere — it was checked and it doesn't.
- **Log tailing**: `StarHubTH/Services/Smapi/SmapiLogParser.swift` + `LogStore` (`StarHubTH/Features/Logs/LogStore.swift`) watch the SMAPI log in real time so the in-app "Developer Logs" panel mirrors what SMAPI is doing while the game runs. Currently `Timer`-based; Phase 5.6 of the refactor plan intends to replace this with an `AsyncStream`.
- **Mod identity under SMAPI**: every mod folder under `Mods/` has a `manifest.json` (parsed by `StarHubTH/Services/Mods/ModManifestParser.swift`) with a `UniqueID` (e.g. `Pathoschild.ContentPatcher`) that SMAPI uses for dependency resolution — this is `ModItem.UniqueID` in the codebase, and it is **not** the same thing as the mod's Nexus page ID (`ModItem.NexusID`) or its folder name (`ModItem.FolderName`, the on-disk identity that survives enable/disable toggling since that just moves the folder to/from `Mods_disabled/`). All three exist as distinct wrapper types specifically so they can't be passed to the wrong parameter by accident — see the doc comment on `ModItem.UniqueID` in `StarHubTH/Models/Mod.swift`.
- Manifest fields the parser reads: `Name`, `UniqueID`, `Version` (string or `{Major,Minor,Patch}Version` object), `Author`, `Description`, `Dependencies` (array of `{UniqueID, IsRequired}`), `UpdateKeys` (a `nexus:<id>` entry is how the app links a local mod back to its Nexus page). Comments (`/* ... */`) and JSON5 are tolerated because that's what real-world manifests contain.

## Nexus Mods API

Two API surfaces, both in `StarHubTH/Services/Nexus/`:

- **REST v1** (`https://api.nexusmods.com/v1`) — `LiveNexusAPIClient.swift`. Mod info, file lists, download links, endorsements. Requires a per-user personal API key (entered in Settings, stored via `PreferenceStoring`), sent as a header on every request — there is no OAuth flow.
- **GraphQL v2** (`https://api.nexusmods.com/v2/graphql`) — used specifically for **Nexus Collections** (curated mod bundles other users publish). This is where "Mod Packs" in this app's UI get their source data.
- **`nxm://` protocol handling**: the app registers the `nxm` URL scheme (see `Info.plist`'s `CFBundleURLTypes`) so clicking "Vortex/Download with manager" on the Nexus website launches this app instead. `StarHubTH/App/URLDispatcher.swift` receives the URL, `StarHubTHViewModel.handleOpenURL(_:)` (destined to move to `AppEnvironment` or a dedicated orchestrator in Phase 4.9) parses it and routes to either a single-mod download or a collection import depending on the URL shape.
- **Rate limits and API key validity are real user-facing failure modes** — a revoked key or hitting Nexus's rate limit are exactly the kind of error Phase 7 (typed errors) is meant to surface properly instead of a generic "something went wrong" modal.

## Mod Packs vs. Mod Profiles — two different concepts, don't conflate them

- **`ModPack`** (`StarHubTH/Models/ModPack.swift`, `StarHubPack`/`StarHubPackMod`) — a **shareable, exportable bundle** of mod references (name, `UniqueID`, `NexusID`, version) plus rich metadata pulled from Nexus (author, downloads, thumbnail, revision). This is this app's answer to Nexus Collections: import someone else's collection via `nxm://` or a URL, or export your own setup to share. Lives behind `ModPacksStore`.
- **`ModProfile`** (`StarHubTH/Models/ModProfile.swift`) — just a **local, named set of enabled mod IDs** (`enabledModIds: [ModItem.UniqueID]`) for switching your own local load-out with one click (e.g. "farming run" vs. "combat-mod testing"). No sharing, no Nexus metadata, no export format. Lives behind `ProfilesStore`.

If a task mentions "profile," check which of these it actually means — the names are close enough to cause real mistakes.

## Save files

`StarHubTH/Services/Saves/SaveFileParser.swift` and `SaveManager.swift` read/write Stardew Valley's save format directly: it's XML, not a structured format the .NET/XNA game exposes an API for, so the parser does targeted regex/tag extraction (`extractTag`, `extractSpouseFromPlayer`) rather than a full XML object model — deliberately, since a full schema would need to track every field the game might add across updates and this app only needs a handful (money, playtime, season, farm type, spouse, etc. — see `SaveGameInfo`). Editing (e.g. spouse reassignment in `SaveManager.updateSpouseInPlayer`) does targeted string surgery on the same tag boundaries for the same reason.

## Where to look, by task

| You're working on... | Start here |
|---|---|
| Mod scanning / enable-disable / manifest parsing | `Services/Mods/`, `Models/Mod.swift`, `Features/Mods/ModsStore.swift` |
| Nexus downloads, endorsements, mod info | `Services/Nexus/`, `Features/Mods/ModsStore.swift` |
| Nexus Collections / Mod Packs | `Services/Nexus/LiveNexusAPIClient.swift` (GraphQL half), `Models/ModPack.swift`, `Features/ModPacks/` |
| Local profile switching | `Models/ModProfile.swift`, `Features/Profiles/` |
| SMAPI install/version/log tailing | `Services/Smapi/`, `Features/Logs/LogStore.swift` |
| `nxm://` links, app-open-URL handling | `App/URLDispatcher.swift`, `StarHubTHViewModel.handleOpenURL` |
| Save game read/edit | `Services/Saves/`, `Models/SaveGameInfo.swift`, `Models/SaveBackup.swift` |
| Thai translation mod discovery | `Features/ThaiHub/ThaiHubStore.swift` |

Architecture, layering, and coding standards are covered elsewhere — see `SWIFT_STANDARDS.md` and `PROJECT_STRUCTURE.md`. This doc is domain knowledge only: what the app is trying to be, and what the external systems it wraps actually do.
