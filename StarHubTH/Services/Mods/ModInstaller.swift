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

struct ModInstaller {
    static func installFromZip(url: URL, gameDir: String, completion: @escaping (Result<[String], ModInstallerError>) -> Void) {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
                let unzip = Process()
                unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzip.arguments = ["-o", "-q", url.path, "-d", tempDir.path]
                try unzip.run()
                unzip.waitUntilExit()
                
                guard unzip.terminationStatus == 0 else {
                    try? fm.removeItem(at: tempDir)
                    DispatchQueue.main.async { completion(.failure(.unzipProcessError)) }
                    return
                }
                
                let fallback = url.deletingPathExtension().lastPathComponent
                // Resolve symlinks so /var and /private/var paths are consistent
                let resolvedTempDir = tempDir.resolvingSymlinksInPath()
                installExtractedContent(from: resolvedTempDir, gameDir: gameDir, fallbackRootName: fallback, cleanup: true, completion: completion)
            } catch {
                try? fm.removeItem(at: tempDir)
                DispatchQueue.main.async { completion(.failure(.unzipFailed(error.localizedDescription))) }
            }
        }
    }
    
    static func installFromFolder(url: URL, gameDir: String, completion: @escaping (Result<[String], ModInstallerError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            installExtractedContent(from: url.deletingLastPathComponent(), gameDir: gameDir, specificRoot: url.lastPathComponent, fallbackRootName: url.lastPathComponent, cleanup: false, completion: completion)
        }
    }
    
    private static func installExtractedContent(from rootDir: URL, gameDir: String, specificRoot: String? = nil, fallbackRootName: String? = nil, cleanup: Bool, completion: @escaping (Result<[String], ModInstallerError>) -> Void) {
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
                DispatchQueue.main.async { completion(.failure(.noModFound)) }
                return
            }
            
            // 3. Create Mods dir if needed
            if !fm.fileExists(atPath: modsPath) {
                try fm.createDirectory(atPath: modsPath, withIntermediateDirectories: true)
            }
            
            // 4. For each mod folder, move/copy
            var installedNames: [String] = []
            var movedRoots = Set<String>()
            
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
                
                if fm.fileExists(atPath: destRoot.path) {
                    if fm.fileExists(atPath: destBackup.path) {
                        try? fm.removeItem(at: destBackup)
                    }
                    try fm.moveItem(at: destRoot, to: destBackup)
                }
                
                do {
                    if cleanup {
                        try fm.moveItem(at: srcRoot, to: destRoot)
                    } else {
                        try fm.copyItem(at: srcRoot, to: destRoot)
                    }
                    if fm.fileExists(atPath: destBackup.path) {
                        try? fm.trashItem(at: destBackup, resultingItemURL: nil)
                    }
                    installedNames.append(rootName)
                } catch {
                    if fm.fileExists(atPath: destBackup.path) && !fm.fileExists(atPath: destRoot.path) {
                        try? fm.moveItem(at: destBackup, to: destRoot)
                    }
                    throw error
                }
            }
            
            if cleanup { try? fm.removeItem(at: rootDir) }
            DispatchQueue.main.async { completion(.success(installedNames)) }
            
        } catch {
            if cleanup { try? fm.removeItem(at: rootDir) }
            DispatchQueue.main.async { completion(.failure(.other(error.localizedDescription))) }
        }
    }
}
