import Foundation

/// Phase 4.2. Owns the in-app log feed (LogsView) and SMAPI-latest.txt tailing.
///
/// Not yet `@MainActor` — same reason as LocalizationStore (Phase 4.1): the caller
/// (StarHubTHViewModel) is still nonisolated, and that annotation is Phase 5.3's own
/// coordinated pass once every store exists.
final class LogStore: ObservableObject {
    @Published var logOutput: String = ""
    @Published var logEntries: [LogEntry] = []
    @Published var isReadingSMAPILog: Bool = false
    private var smapiLogFileHandle: FileHandle?
    @Published var smapiLogTimer: Timer?

    func log(_ message: String, level: LogLevel = .info) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let entry = LogEntry(timestamp: timestamp, message: message, level: level, source: .app)

        let logString = "[\(timestamp)] \(message)\n"

        // Append to file logger
        DispatchQueue.global(qos: .background).async {
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let logDir = appSupport.appendingPathComponent("StarHubTH")
                try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
                let logFile = logDir.appendingPathComponent("StarHubTH_debug.log")
                if let data = logString.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: logFile.path) {
                        if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                            fileHandle.seekToEndOfFile()
                            fileHandle.write(data)
                            fileHandle.closeFile()
                        }
                    } else {
                        try? data.write(to: logFile)
                    }
                }
            }
        }

        if Thread.isMainThread {
            logEntries.append(entry)
            logOutput += logString
        } else {
            DispatchQueue.main.async {
                self.logEntries.append(entry)
                self.logOutput += logString
            }
        }
    }

    /// Load SMAPI-latest.txt asynchronously when Logs tab is opened.
    func loadSmapiLog() {
        let path = smapiLogPath
        guard FileManager.default.fileExists(atPath: path) else { return }

        isReadingSMAPILog = true

        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = FileManager.default.contents(atPath: path),
                  let text = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.isReadingSMAPILog = false
                }
                return
            }

            let lines = text.components(separatedBy: .newlines)
            var entries: [LogEntry] = []

            for line in lines {
                if line.hasPrefix("[") {
                    guard let bracketEnd = line.firstIndex(of: "]") else {
                        continue
                    }

                    let header = String(line[line.index(after: line.startIndex)..<bracketEnd])
                    let headerParts = header.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

                    let ts = headerParts.count >= 1 ? headerParts[0] : "—"
                    let levelStr = headerParts.count >= 2 ? headerParts[1] : ""
                    let contextName: String? = {
                        guard headerParts.count >= 3 else { return nil }
                        let name = headerParts[2...].joined(separator: " ")
                        return (name == "SMAPI" || name == "game") ? nil : name
                    }()

                    let level: LogLevel
                    switch levelStr.uppercased() {
                    case "ERROR":  level = .error
                    case "WARN":   level = .warning
                    case "ALERT":  level = .warning
                    case "INFO":   level = .info
                    default:       level = .smapi  // TRACE, DEBUG, etc.
                    }

                    let msgStart = line.index(after: bracketEnd)
                    let message = msgStart < line.endIndex
                        ? String(line[msgStart...]).trimmingCharacters(in: .whitespaces)
                        : ""

                    if !message.isEmpty || contextName != nil {
                        var entry = LogEntry(timestamp: ts, message: message, level: level, source: .smapi)
                        entry.modName = contextName
                        entries.append(entry)
                    }
                } else {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !entries.isEmpty else { continue }
                    let last = entries.removeLast()
                    let combined = last.message.isEmpty ? trimmed : last.message + "\n" + trimmed
                    var updated = LogEntry(timestamp: last.timestamp, message: combined, level: last.level, source: .smapi)
                    updated.modName = last.modName
                    entries.append(updated)
                }
            }

            DispatchQueue.main.async {
                self.logEntries.append(contentsOf: entries)
                self.isReadingSMAPILog = false
            }
        }
    }

    private var smapiLogPath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return (homeDir as NSString).appendingPathComponent(
            ".config/StardewValley/ErrorLogs/SMAPI-latest.txt"
        )
    }

    func startSmapiLogWatcher() { loadSmapiLog() }
    func stopSmapiLogWatcher() {
        smapiLogTimer?.invalidate()
        smapiLogTimer = nil
        try? smapiLogFileHandle?.close()
        smapiLogFileHandle = nil
    }
}
