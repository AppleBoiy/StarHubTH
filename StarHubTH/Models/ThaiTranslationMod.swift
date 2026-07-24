import Foundation

struct ThaiTranslationMod: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let author: String
    let version: String
    let status: String
    let url: String
    let nexusUrl: String
    var isInstalled: Bool = false
    var isOriginalModInstalled: Bool = false

    func installationStatusText(vm: StarHubTHViewModel) -> String {
        if isInstalled {
            return vm.L(L10n.ThaiHub.installed)
        } else if isOriginalModInstalled {
            return vm.L(L10n.ThaiHub.availableDownload)
        } else {
            return vm.L(L10n.ThaiHub.missingOriginal)
        }
    }
}
