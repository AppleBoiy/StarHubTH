import Foundation

/// The lower-level "run a `Process`" plumbing behind `SmapiInstaller`'s install/uninstall
/// flow (§ file-size convention split — see SmapiInstaller.swift's header comment).
extension SmapiInstaller {
    /// Runs a `Process` off the calling actor and resumes once it exits — shared plumbing
    /// behind the unzip/xattr steps above.
    func runProcess(executable: String, arguments: [String]) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            // Process.run()/waitUntilExit() are synchronous-blocking with no async form —
            // off-load to a background queue so the caller's actor isn't blocked.
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Runs SMAPI's own official installer binary non-interactively by
    /// feeding its fixed prompt sequence through stdin in one write:
    /// color scheme, "enter a custom game path" (option 2 — never trust
    /// its auto-detected option 1, which only matches well-known install
    /// locations), the game path itself, then install (1) or uninstall (2).
    /// Verified directly against a real download: this sequence is stable,
    /// short, and doesn't require synchronizing on the installer's output
    /// text (which could reword between versions) — stdin is a queue the
    /// installer's prompts consume from in order, regardless of what's
    /// already been printed.
    ///
    /// The process's exit code alone isn't fully trustworthy: on its error
    /// path, the installer tries to read a keypress before exiting, which
    /// throws an unhandled .NET exception (and a non-zero exit) whenever
    /// stdin isn't a real terminal — including some cases that already
    /// completed the actual install/uninstall work. So success is
    /// determined by a combination of the installer's own "done" message
    /// and concrete file-system evidence, not the exit code by itself.
    ///
    /// On a successful install, also writes `version` to
    /// `installedVersionMarkerRelativePath` — verified directly against a
    /// real install that nothing else on disk reliably states SMAPI's own
    /// version afterward (see `installedVersion`'s doc comment), so this
    /// app records what it just installed instead of guessing later.
    func runOfficialInstaller(at installerPath: String, version: String, gameDir: String, action: InstallerAction) async -> SmapiInstallOutcome {
        await withCheckedContinuation { continuation in
            // Process.run()/waitUntilExit() are synchronous-blocking with no async form —
            // off-load to a background queue so the caller's actor isn't blocked.
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: installerPath)

                let stdinPipe = Pipe()
                let stdoutPipe = Pipe()
                process.standardInput = stdinPipe
                process.standardOutput = stdoutPipe
                process.standardError = stdoutPipe

                let answers = "1\n2\n\(gameDir)\n\(action.rawValue)\n"

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: SmapiInstallOutcome(success: false, messageKey: L10n.Smapi.installError, detail: error.localizedDescription))
                    return
                }

                stdinPipe.fileHandleForWriting.write(answers.data(using: .utf8) ?? Data())
                try? stdinPipe.fileHandleForWriting.close()

                let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let output = String(data: outputData, encoding: .utf8) ?? ""

                let fileManager = FileManager.default
                let smapiInternalPath = (gameDir as NSString).appendingPathComponent("smapi-internal")

                switch action {
                case .install:
                    let succeeded = output.contains("SMAPI is installed!") && fileManager.fileExists(atPath: smapiInternalPath)
                    if succeeded {
                        let markerPath = (gameDir as NSString).appendingPathComponent(Self.installedVersionMarkerRelativePath)
                        try? version.write(toFile: markerPath, atomically: true, encoding: .utf8)
                        continuation.resume(returning: SmapiInstallOutcome(success: true, messageKey: L10n.Smapi.installSuccess, detail: nil))
                    } else {
                        continuation.resume(returning: SmapiInstallOutcome(success: false, messageKey: L10n.Smapi.installError, detail: Self.lastMeaningfulLine(of: output)))
                    }
                case .uninstall:
                    let succeeded = output.contains("SMAPI is removed!") && !fileManager.fileExists(atPath: smapiInternalPath)
                    if succeeded {
                        continuation.resume(returning: SmapiInstallOutcome(success: true, messageKey: L10n.Smapi.uninstallSuccess, detail: nil))
                    } else {
                        continuation.resume(returning: SmapiInstallOutcome(success: false, messageKey: L10n.Smapi.uninstallFailed, detail: Self.lastMeaningfulLine(of: output)))
                    }
                }
            }
        }
    }

    /// Picks a short, useful line from the installer's captured output for
    /// the error detail shown to the user. Its crash output ends in a C#
    /// stack trace, which isn't useful verbatim — the actual error message
    /// is the line announcing the exception, so surface that instead of the
    /// trace beneath it.
    nonisolated static func lastMeaningfulLine(of output: String) -> String {
        let lines = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        if let idx = lines.firstIndex(where: { $0.contains("unexpected exception") || $0.contains("failed") }) {
            return lines[idx]
        }
        return lines.last(where: { !$0.isEmpty }) ?? "unknown error"
    }
}
