import Foundation

/// Thrown by `ProfileStoring.applyProfileToFilesystem` when one or more mod folders
/// couldn't be moved to match a profile's enabled set. Carries the names of the mods that
/// failed rather than a flat "something went wrong" — a caller otherwise has no way to
/// tell the user which mod folder to check permissions on.
struct ProfileApplyError: Error, Sendable {
    let failedModNames: [String]
}
