import Foundation

/// Phase 4.3. Owns the Thai Translation Hub's fetched mod list and detail-sheet state.
///
/// `gameDir` and `mods` aren't owned here — they belong to AppEnvironment (4.8) and
/// ModsStore (4.7), neither of which exists yet — so the methods that need them take
/// the current value as a parameter instead of storing a reference back to the
/// not-yet-extracted parts of StarHubTHViewModel. Once those stores exist, the
/// ViewModel's forwarding methods are the only thing that needs to change.
@MainActor
final class ThaiHubStore: ObservableObject {
    @Published var thaiTranslations: [ThaiTranslationMod] = []
    @Published var viewingThaiMod: ThaiTranslationMod?

    private let localization: LocalizationStore

    init(localization: LocalizationStore) {
        self.localization = localization
    }

    func fetchThaiTranslations(gameDir: String, mods: [Mod]) async {
        guard let url = URL(string: "https://raw.githubusercontent.com/AppleBoiy/stardew-thai-translations/main/README.md") else { return }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let content = String(data: data, encoding: .utf8) else { return }

        var newTranslations: [ThaiTranslationMod] = []
            let lines = content.components(separatedBy: .newlines)
            var inTable = false

            for line in lines {
                if line.starts(with: "| ชื่อม็อด") {
                    inTable = true
                    continue
                }
                if inTable && line.starts(with: "| :---") { continue }
                if inTable && line.starts(with: "|") {
                    let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                    if parts.count >= 6 {
                        let rawName = parts[1] // **[[CP] Additional Farm Cave](https://...)**
                        var cleanName = rawName.replacingOccurrences(of: "**", with: "")
                        var url = ""

                        // Use regex to extract name and URL: [Name](URL)
                        let pattern = "\\[(.*?)\\]\\((.*?)\\)"
                        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                           let match = regex.firstMatch(in: cleanName, options: [], range: NSRange(location: 0, length: cleanName.utf16.count)) {
                            if let nameRange = Range(match.range(at: 1), in: cleanName) {
                                let extractedName = String(cleanName[nameRange])
                                if let urlRange = Range(match.range(at: 2), in: cleanName) {
                                    url = String(cleanName[urlRange])
                                }
                                cleanName = extractedName
                            }
                        }

                        let author = parts[2]
                        let version = parts[3]
                        let status = parts[4]

                        let rawNexus = parts[5]
                        var nexusUrl = ""
                        if let r1 = rawNexus.range(of: "("), let r2 = rawNexus.range(of: ")") {
                            nexusUrl = String(rawNexus[rawNexus.index(after: r1.lowerBound)..<r2.lowerBound])
                        }

                        let mod = ThaiTranslationMod(
                            name: cleanName,
                            author: author,
                            version: version,
                            status: status,
                            url: url,
                            nexusUrl: nexusUrl
                        )
                        newTranslations.append(mod)
                    }
                } else if inTable && line.isEmpty {
                    inTable = false
                }
            }

        thaiTranslations = newTranslations
        evaluateThaiTranslationStatus(gameDir: gameDir, mods: mods)
    }

    func evaluateThaiTranslationStatus(gameDir: String, mods: [Mod]) {
        guard !gameDir.isEmpty else { return }
        let fm = FileManager.default
        let modsDir = (gameDir as NSString).appendingPathComponent("Mods")

        for i in 0..<thaiTranslations.count {
            // Very simple check: does any mod folder contain an i18n/th.json?
            // AND does the folder name sort of match the mod name?
            let nameToCheck = thaiTranslations[i].name.replacingOccurrences(of: "[CP]", with: "").trimmingCharacters(in: .whitespaces)
            var foundTranslation = false
            var foundOriginal = false
            for mod in mods {
                if mod.name.localizedCaseInsensitiveContains(nameToCheck) || nameToCheck.localizedCaseInsensitiveContains(mod.name) {
                    foundOriginal = true

                    let thJsonPath = (modsDir as NSString).appendingPathComponent("\(mod.folderName)/i18n/th.json")
                    let cpThJsonPath = (modsDir as NSString).appendingPathComponent("\(mod.folderName)/[CP] \(mod.folderName)/i18n/th.json") // Handle nested [CP]

                    if fm.fileExists(atPath: thJsonPath) || fm.fileExists(atPath: cpThJsonPath) {
                        foundTranslation = true
                    } else if case .group(let children) = mod.kind {
                        for child in children {
                            let childThJsonPath = (modsDir as NSString).appendingPathComponent("\(child.folderName)/i18n/th.json")
                            let childCpThJsonPath = (modsDir as NSString).appendingPathComponent("\(child.folderName)/[CP] \(child.folderName)/i18n/th.json")
                            if fm.fileExists(atPath: childThJsonPath) || fm.fileExists(atPath: childCpThJsonPath) {
                                foundTranslation = true
                                break
                            }
                        }
                    }
                }
            }
            thaiTranslations[i].availability = foundTranslation ? .installed : (foundOriginal ? .downloadable : .baseModMissing)
        }

        // Sort installed mods first, then alphabetically
        thaiTranslations.sort { mod1, mod2 in
            if mod1.isInstalled != mod2.isInstalled {
                return mod1.isInstalled
            }
            return mod1.name.localizedStandardCompare(mod2.name) == .orderedAscending
        }
    }

    func install(
        _ mod: ThaiTranslationMod,
        gameDir: String,
        showModal: @escaping (String) -> Void,
        onInstalled: @escaping () -> Void
    ) async {
        guard !gameDir.isEmpty else { return }

        let modsDir = (gameDir as NSString).appendingPathComponent("Mods")
        let zipName = "\(mod.name.replacingOccurrences(of: "[CP] ", with: "")) - Thai Translation.zip"

        showModal(String(format: localization.L(L10n.VM.downloadingTranslation), mod.name))

        let apiUrl = URL(string: "https://api.github.com/repos/AppleBoiy/stardew-thai-translations/releases?per_page=100")!
        var request = URLRequest(url: apiUrl)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            showModal(String(format: localization.L(L10n.VM.downloadFailed), error.localizedDescription))
            return
        }

        guard let releases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            showModal(localization.L(L10n.VM.downloadFailed) + " (Invalid API Response)")
            return
        }

        var targetDownloadUrl: URL? = nil

        for release in releases {
            if let assets = release["assets"] as? [[String: Any]] {
                for asset in assets {
                    if let name = asset["name"] as? String {
                        let normalizedAssetName = name.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "")
                        let normalizedZipName = zipName.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "")

                        if normalizedAssetName == normalizedZipName,
                           let browserDownloadUrl = asset["browser_download_url"] as? String,
                           let url = URL(string: browserDownloadUrl) {
                            targetDownloadUrl = url
                            break
                        }
                    }
                }
            }
            if targetDownloadUrl != nil { break }
        }

        guard let downloadUrl = targetDownloadUrl else {
            showModal(localization.L(L10n.VM.downloadFailed) + " (Zip not found in releases)")
            return
        }

        let localUrl: URL
        let response: URLResponse
        do {
            (localUrl, response) = try await URLSession.shared.download(for: URLRequest(url: downloadUrl))
        } catch {
            showModal(String(format: localization.L(L10n.VM.downloadFailed), error.localizedDescription))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            showModal(localization.L(L10n.VM.downloadFailed) + " (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", localUrl.path, "-d", modsDir]

        do {
            let status: Int32 = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try process.run()
                        process.waitUntilExit()
                        continuation.resume(returning: process.terminationStatus)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            if status == 0 {
                showModal(String(format: localization.L(L10n.VM.installThaiSuccess), mod.name))
                onInstalled()
            } else {
                showModal(localization.L(L10n.VM.unzipError))
            }
        } catch {
            showModal(String(format: localization.L(L10n.VM.unzipFailed), error.localizedDescription))
        }
    }
}
