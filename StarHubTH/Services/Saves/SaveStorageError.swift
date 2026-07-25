import Foundation

/// Typed failure modes for `SaveStoring`. Replaces the old `-> Bool` returns, which told a
/// caller only *that* an operation failed, never *why* — a permissions error, a missing
/// directory, and a genuinely empty saves folder were all indistinguishable.
///
/// `detail` carries the underlying system error's own (already-localized) description, so
/// callers can append it to a headline message rather than needing a bespoke localization
/// key per failure site — the same `messageKey` + `detail` shape `SmapiInstallOutcome` uses.
enum SaveStorageError: Error {
    case directoryUnreadable(underlying: Error)
    case fileUnreadable(underlying: Error)
    case fileWriteFailed(underlying: Error)
    case backupFailed(underlying: Error)
    case moveFailed(underlying: Error)
    case internalNameUpdateFailed
    case inventoryUnreadable

    var detail: String? {
        switch self {
        case .directoryUnreadable(let error), .fileUnreadable(let error), .fileWriteFailed(let error),
             .backupFailed(let error), .moveFailed(let error):
            return error.localizedDescription
        case .internalNameUpdateFailed, .inventoryUnreadable:
            return nil
        }
    }
}
