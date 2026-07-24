import Foundation

enum TranslationAvailability: Equatable {
    case installed
    case downloadable
    case baseModMissing

    var localizationKey: String {
        switch self {
        case .installed:      return L10n.ThaiHub.installed
        case .downloadable:   return L10n.ThaiHub.availableDownload
        case .baseModMissing: return L10n.ThaiHub.missingOriginal
        }
    }
}

struct ThaiTranslationMod: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let author: String
    let version: String
    let status: String
    let url: String
    let nexusUrl: String
    var availability: TranslationAvailability = .baseModMissing

    var isInstalled: Bool { availability == .installed }
}
