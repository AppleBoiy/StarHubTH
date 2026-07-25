import Foundation

enum ModInstallerError: Error, LocalizedError {
    case unzipFailed(String)
    case unzipProcessError
    case noModFound
    case other(String)
    
    var errorDescription: String? {
        switch self {
        case .unzipFailed(let msg): return "Unzip Failed: \(msg)"
        case .unzipProcessError: return "Unzip Process Error"
        case .noModFound: return "No Mod Found"
        case .other(let msg): return msg
        }
    }
}

/// No stored properties — a plain, explicit `Sendable` conformance declared here (not just
/// inferred via the `ModInstalling` conformance in a different file, which Swift requires
/// for retroactive conformance to be explicit and same-file).
struct ModInstaller: Sendable {
    static func installFromZip(url: URL, gameDir: String) async throws(ModInstallerError) -> [String] {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzip.arguments = ["-o", "-q", url.path, "-d", tempDir.path]
            try unzip.run()
            unzip.waitUntilExit()

            guard unzip.terminationStatus == 0 else {
                try? fm.removeItem(at: tempDir)
                throw ModInstallerError.unzipProcessError
            }

            let fallback = url.deletingPathExtension().lastPathComponent
            // Resolve symlinks so /var and /private/var paths are consistent
            let resolvedTempDir = tempDir.resolvingSymlinksInPath()
            return try installExtractedContent(from: resolvedTempDir, gameDir: gameDir, fallbackRootName: fallback, cleanup: true)
        } catch let error as ModInstallerError {
            throw error
        } catch {
            try? fm.removeItem(at: tempDir)
            throw .unzipFailed(error.localizedDescription)
        }
    }

    static func installFromFolder(url: URL, gameDir: String) async throws(ModInstallerError) -> [String] {
        try installExtractedContent(from: url.deletingLastPathComponent(), gameDir: gameDir, specificRoot: url.lastPathComponent, fallbackRootName: url.lastPathComponent, cleanup: false)
    }

    private static func installExtractedContent(from rootDir: URL, gameDir: String, specificRoot: String? = nil, fallbackRootName: String? = nil, cleanup: Bool) throws(ModInstallerError) -> [String] {
        let fm = FileManager.default
        let modsPath = (gameDir as NSString).appendingPathComponent("Mods")

        do {
            // 1. Collect all folders that contain a manifest.json
            var manifestDirs: [URL] = []
            let enumerateRoot = specificRoot.map { rootDir.appendingPathComponent($0) } ?? rootDir
            
            if let enumerator = fm.enumerator(
                at: enumerateRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    if fileURL.lastPathComponent.lowercased() == "manifest.json" {
                        manifestDirs.append(fileURL.deletingLastPathComponent().resolvingSymlinksInPath())
                    }
                }
            }
            
            // 2. Keep only top-most (shallowest) folders
            let topLevelDirs = manifestDirs.filter { candidate in
                !manifestDirs.contains { other in
                    other != candidate && candidate.path.hasPrefix(other.path + "/")
                }
            }
            
            guard !topLevelDirs.isEmpty else {
                if cleanup { try? fm.removeItem(at: rootDir) }
                throw ModInstallerError.noModFound
            }
            
            // 3. Create Mods dir if needed
            if !fm.fileExists(atPath: modsPath) {
                try fm.createDirectory(atPath: modsPath, withIntermediateDirectories: true)
            }
            
            // 4. For each mod folder, move/copy.
            //
            // A multi-mod zip (several manifest.json folders in one archive) must install
            // atomically — either every mod in it lands, or none do. Without that, a
            // failure on the Nth folder would leave the first N-1 already moved into
            // place while the completion reports total failure, so the caller has no idea
            // some mods changed and never refreshes. To get that: backups made along the
            // way aren't trashed until the whole loop finishes, so a later failure can
            // still restore every earlier one from its backup before reporting failure.
            var installedNames: [String] = []
            var movedRoots = Set<String>()
            var completedInstalls: [(destRoot: URL, destBackup: URL?)] = []

            func rollBackCompletedInstalls() {
                for entry in completedInstalls.reversed() {
                    try? fm.removeItem(at: entry.destRoot)
                    if let backup = entry.destBackup, fm.fileExists(atPath: backup.path) {
                        try? fm.moveItem(at: backup, to: entry.destRoot)
                    }
                }
            }

            for modDir in topLevelDirs {
                let originalRelative = Array(modDir.pathComponents.dropFirst(rootDir.pathComponents.count))
                var relative = originalRelative

                // Strip common generic wrapper folders from the root
                while let first = relative.first,
                      first.lowercased() == "mods" || first.lowercased() == "stardew valley" || first.lowercased() == "stardewvalley" || first.lowercased() == "stardew_valley" {
                    relative.removeFirst()
                }

                let rootName = relative.first ?? fallbackRootName ?? "UnknownMod"
                if movedRoots.contains(rootName) { continue }
                movedRoots.insert(rootName)

                var srcRoot = rootDir
                if let firstUnstripped = relative.first, let index = originalRelative.firstIndex(of: firstUnstripped) {
                    for i in 0...index {
                        srcRoot = srcRoot.appendingPathComponent(originalRelative[i])
                    }
                } else {
                    srcRoot = modDir
                }

                let destRoot = URL(fileURLWithPath: modsPath).appendingPathComponent(rootName)
                let destBackup = URL(fileURLWithPath: modsPath).appendingPathComponent("\(rootName)_backup_temp")
                let hadExisting = fm.fileExists(atPath: destRoot.path)

                if hadExisting {
                    if fm.fileExists(atPath: destBackup.path) {
                        try? fm.removeItem(at: destBackup)
                    }
                    do {
                        try fm.moveItem(at: destRoot, to: destBackup)
                    } catch {
                        rollBackCompletedInstalls()
                        throw error
                    }
                }

                do {
                    if cleanup {
                        try fm.moveItem(at: srcRoot, to: destRoot)
                    } else {
                        try fm.copyItem(at: srcRoot, to: destRoot)
                    }
                    installedNames.append(rootName)
                    completedInstalls.append((destRoot, hadExisting ? destBackup : nil))
                } catch {
                    if hadExisting && !fm.fileExists(atPath: destRoot.path) {
                        try? fm.moveItem(at: destBackup, to: destRoot)
                    }
                    rollBackCompletedInstalls()
                    throw error
                }
            }

            // Whole batch succeeded — now it's safe to trash every backup made along the way.
            for entry in completedInstalls {
                if let backup = entry.destBackup {
                    try? fm.trashItem(at: backup, resultingItemURL: nil)
                }
            }

            if cleanup { try? fm.removeItem(at: rootDir) }
            return installedNames

        } catch let error as ModInstallerError {
            throw error
        } catch {
            if cleanup { try? fm.removeItem(at: rootDir) }
            throw .other(error.localizedDescription)
        }
    }
}
