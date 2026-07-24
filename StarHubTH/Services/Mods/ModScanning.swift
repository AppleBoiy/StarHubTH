import Foundation

/// I/O boundary for reading installed mods off disk. `ModScanner` is the `Live`
/// implementation; a `Stub` conformance lets stores be tested without a filesystem.
protocol ModScanning {
    func scan(gameDir: String, customModTags: [String: String]) -> [ModItem]
}

extension ModScanner: ModScanning {
    func scan(gameDir: String, customModTags: [String: String]) -> [ModItem] {
        Self.scan(gameDir: gameDir, customModTags: customModTags)
    }
}
