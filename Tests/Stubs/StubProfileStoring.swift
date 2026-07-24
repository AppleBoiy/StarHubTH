import Foundation

final class StubProfileStoring: ProfileStoring {
    var profiles: [ModProfile] = []
    var activeId: UUID?
    var applyResult = true
    private(set) var savedProfiles: [ModProfile]?

    func loadProfiles() -> (profiles: [ModProfile], activeId: UUID?) {
        (profiles, activeId)
    }

    func saveProfiles(_ profiles: [ModProfile], activeProfileId: UUID?) {
        self.profiles = profiles
        self.activeId = activeProfileId
        savedProfiles = profiles
    }

    func applyProfileToFilesystem(profile: ModProfile, mods: [ModItem], gameDir: String) -> Bool {
        applyResult
    }

    func exportProfile(_ profile: ModProfile, mods: [ModItem], to url: URL) throws {}

    func importProfile(from url: URL) throws -> (ModCollection, ModProfile) {
        throw StubError.unconfigured
    }
}
