# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.5] - 2026-07-04

### Added
- **Typed Localization System (L10n)**: Replaced all raw Thai string keys with a typed `L10n` enum. Every UI string now goes through `vm.L(L10n.Section.key)` — compiler will catch missing or mistyped keys instead of silently falling back.
- **Auto-toggle Dependencies Setting**: Added a new "Mod Behavior" section in Settings with a toggle to enable/disable automatic dependency chain toggling. When enabled, opening a mod also enables its required dependencies, and closing a mod closes mods that depend on it. Can now be turned off for manual per-mod control.
- **Mod Profile Improvements**:
  - Profile detail sheet now reflects actual filesystem state when the active profile is opened (no more "0 mods" display).
  - Creating a new profile now snapshots currently enabled mods automatically instead of starting empty.
  - Profile checkbox list now groups mods the same way as the main Mod List page (groups stay grouped instead of being flattened).
  - Checking a mod in a profile now respects the "Auto-toggle Dependencies" setting — checking one mod can cascade-enable its dependencies.
  - Toggling mods on the main Mod List page now syncs the active profile's stored list automatically.
  - Fixed a critical bug where group mods (e.g. Eli & Dylan with 15 sub-mods) were incorrectly matched by `uniqueId = ""` in `applyProfileToFilesystem`, causing only standalone mods to apply correctly. Groups now match by checking if any child is in the enabled list.
  - `updateProfile` (OK button) now correctly applies changes to the filesystem when editing the active profile, instead of being overwritten by a sync from the old filesystem state.
- **Core Extensions — 3-State Status**: The Core Extensions section on the Home screen now distinguishes between three states:
  - ✅ Green: Installed and enabled
  - 🟠 Orange: Installed but disabled
  - ❌ Red: Not installed
- **Core Extensions — Author & Version**: Each core mod row now shows the author name and installed version when the mod is found on disk.
- **Core Extensions — SVE**: Added Stardew Valley Expanded (SVE) to the Core Extensions tracking list.
- **English README & Nexus Description**: Added `README_EN.md` and `nexus_description_en.txt` for international users. Added `[!IMPORTANT]` callout at the top of the Thai README linking to the English version.

### Changed
- `smapiInstalledVersion` changed from `String` (using `"ยังไม่ได้ติดตั้ง"` as sentinel) to `String?` (`nil` = not installed) — removes a fragile Thai string comparison from business logic.
- `SmapiInstaller` status messages now use `L10n.Smapi` keys instead of `String(localized:)`, ensuring they go through the same runtime language bundle as the rest of the app.
- `applyChain` in ProfileDetailSheet now delegates entirely to `vm.applyChainToSet(mod:enable:currentEnabled:)` in the ViewModel — single source of truth, guaranteed identical behavior between the Mod List page and the Profile detail page.

### Fixed
- Fixed profile mod count showing 0 on re-open by loading from actual filesystem state for the active profile in `onAppear`.
- Fixed `applyProfileToFilesystem` not moving group mod folders because `uniqueId` for groups is always `""`.
- Fixed `syncActiveProfileIds` being called after `applyProfileToFilesystem` overwrote the newly saved `enabledModIds` with the old filesystem state.
- Fixed sidebar section headers being re-translated via `LocalizedStringKey` after already receiving a translated string — headers now use `Text(string)` directly.
- Fixed hardcoded Thai strings in `SaveEditorView`, `SettingsView`, `ModListView`, `MainView` alert, and `toggleMod` log messages.



### Added
- Added **Mod Profiles** feature: You can now create, switch, and delete multiple mod profiles to manage different mod setups easily.
- Added a Profile Indicator badge next to the Steam avatar on the Home screen to quickly identify the active profile.
- Added "Select All" and "Deselect All" buttons in the Mod Profiles management window.
- Added Mod ID (`UniqueID`) support to the Mod List search bar, allowing you to search mods by their internal ID.

### Changed
- **Smart Dependency Management**: 
  - When enabling a mod, the app will now automatically recursively enable all of its REQUIRED dependencies.
  - When disabling a mod, the app will now automatically recursively disable all enabled mods that rely on it (preventing crashes from missing dependencies).
  - This system correctly navigates group folders to find the exact sub-mods causing the dependency.
- Enhanced the Dependency Status Indicator in the Mod Info popup with 3 clear states:
  - ✅ Green Checkmark: Dependency is installed AND enabled.
  - ❕ Orange Exclamation: Dependency is installed BUT disabled.
  - ❌ Red Cross: Dependency is NOT installed.
- Simplified the Mod List toolbar by removing the redundant API status indicator (this status is already available on the Home screen).

### Fixed
- Fixed a major flaw in the Mod toggle logic where group folders failed to resolve sub-mod dependencies.
- Fixed the API indicator styling conflict that caused a "double border" glitch due to native macOS toolbar styling.

## [1.0.3] - 2026-07-03

### Changed
- Standardized UI components (Settings/Toggles) to match native macOS aesthetics.
- Replaced custom toggle switches with native macOS `SwitchToggleStyle`.
- Improved UI alignment by allowing components to size naturally and align right in settings.
- Moved search bars and action buttons (like refresh/status badges) to the native macOS Navigation Toolbar.
- Renamed "Game System Info" section to "App Info".
- Added native-style section headers to the Sidebar (e.g., "Game Management", "System Settings", "Online Services") to group menu items logically.

### Fixed
- Fixed app launching to the incorrect default tab (now opens to the Home/Profile page).
- Implemented full Navigation History, allowing the macOS Back/Forward toolbar buttons to correctly navigate through previously visited tabs.
- Reduced sizes of toggle switches and info popover buttons to be properly proportional to the surrounding text.
- Removed redundant English parenthetical texts from localized Thai UI strings.
- Fixed a bug where English and Japanese localizations in the Settings page failed to display properly due to mismatched translation keys.

## [1.0.2] - 2026-07-03

### Added
- Added full **Japanese Localization** (Trilingual Support).

### Fixed
- Fixed a bug where navigation titles and `String(localized:)` did not dynamically update when changing languages in-app.
- Fixed a type mismatch bug that caused save file money to display as corrupted memory addresses when formatted with commas.
- Improved localized format strings in the Saves View to respect native language grammar structures (e.g. "ฟาร์ม our's" instead of "our's Farm" in Thai).
- Cleaned up redundant English parentheses in Thai and Japanese UI texts.

## [1.0.1] - 2026-07-01

### Added
- Added partial Thai translation (~41%) for **Sword & Sorcery** by DaisyNiko.
  - ✅ **Mateo** — Core dialogue, Events (0H–14H), Marriage dialogue, Custom Talk (CH2–CH5)
  - ✅ **Hector / Biróg** — Core dialogue, Events (0H–14H) including D&D session, river restoration, and grove revelation; Marriage dialogue; Custom Talk (CH2–CH5 + Other)
  - ✅ **Eyvind** — Chapter 2–4 dialogue (backstory with Mateo)
  - ✅ **Cirrus** — Core dialogue, Festival dialogue (all seasons), Gift reactions, Movie reactions, Resort dialogue, Player Death reactions
  - 🔄 **Cirrus** — Marriage dialogue, Events (0H–10H), Strings (in progress)
  - ⏳ **Dandelion, Roslin, and remaining characters** — Pending
- Updated README.md to include Sword & Sorcery and added full Thai-language README section.

## [1.0.0] - 2026-07-01

### Added
- Initial release of the Thai translation collection.
- Added translation for **UI Info Suite 2 Alternative** (v2.8.32) by DazUki.
- Added translation for **Unlockable Bundles** (v4.3.1) by DeLiXx.
- Added translation for **Wear More Rings** (v7.9) by bcmpinc.
- Added translation for **World Navigator** (v1.4.2) by pneuma163.
