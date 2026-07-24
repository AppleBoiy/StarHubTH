import Foundation

/// I/O boundary for mod profiles: persistence, filesystem application, and
/// import/export. `ProfileManager` is the `Live` implementation; a `Stub` conformance
/// lets stores be tested without touching UserDefaults or the filesystem.
protocol ProfileStoring {
    func loadProfiles() -> (profiles: [ModProfile], activeId: UUID?)
    func saveProfiles(_ profiles: [ModProfile], activeProfileId: UUID?)
    func applyProfileToFilesystem(profile: ModProfile, mods: [ModItem], gameDir: String) -> Bool
    func exportProfile(_ profile: ModProfile, mods: [ModItem], to url: URL) throws
    func importProfile(from url: URL) throws -> (ModCollection, ModProfile)
}

extension ProfileManager: ProfileStoring {}
