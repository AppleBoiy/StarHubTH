import Foundation

/// Phase 4.2. Owns the in-app log feed (LogsView) and SMAPI-latest.txt tailing.
@MainActor
final class LogStore: ObservableObject {
    @Published var logOutput: String = ""
    @Published var logEntries: [LogLine] = []
    @Published var isReadingSMAPILog: Bool = false

    private var tailTask: Task<Void, Never>?

    func log(_ message: String, level: LogLevel = .info) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let entry = LogLine(timestamp: timestamp, message: message, level: level, source: .app)

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

        logEntries.append(entry)
        logOutput += logString
    }

    /// Loads SMAPI-latest.txt's current content, then keeps tailing the file for new writes
    /// (SMAPI appends to it as the game runs) until `stopSmapiLogWatcher()` is called.
    func startSmapiLogWatcher() {
        tailTask?.cancel()
        tailTask = Task { [weak self] in
            guard let self else { return }
            let offsetAfterInitialLoad = await self.loadSmapiLog()
            for await chunk in self.tailSmapiLog(from: offsetAfterInitialLoad) {
                if Task.isCancelled { break }
                self.appendParsedLines(chunk)
            }
        }
    }

    func stopSmapiLogWatcher() {
        tailTask?.cancel()
        tailTask = nil
    }

    /// One-shot read of the file's current content. Returns the byte offset read up to, so
    /// `tailSmapiLog(from:)` can pick up new writes from exactly where this left off instead
    /// of re-reading (and re-parsing) everything already loaded.
    @discardableResult
    private func loadSmapiLog() async -> UInt64 {
        let path = smapiLogPath
        guard FileManager.default.fileExists(atPath: path) else { return 0 }

        isReadingSMAPILog = true
        defer { isReadingSMAPILog = false }

        guard let data = FileManager.default.contents(atPath: path),
              let text = String(data: data, encoding: .utf8) else {
            return 0
        }

        appendParsedLines(text)
        return UInt64(data.count)
    }

    /// Yields newly-appended text from the SMAPI log file as SMAPI writes to it, using a
    /// `DispatchSourceFileSystemObject` to wake on writes rather than polling — the standard
    /// "tail -f" pattern. `startOffset` is the byte offset already consumed (by the initial
    /// load, or a previous call), so only genuinely new bytes are read and yielded.
    private func tailSmapiLog(from startOffset: UInt64) -> AsyncStream<String> {
        let path = smapiLogPath
        return AsyncStream { continuation in
            guard FileManager.default.fileExists(atPath: path) else {
                continuation.finish()
                return
            }

            let fileDescriptor = open(path, O_EVTONLY)
            guard fileDescriptor >= 0 else {
                continuation.finish()
                return
            }

            var offset = startOffset
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: .write,
                queue: DispatchQueue.global(qos: .utility)
            )
            // DispatchSourceFileSystemObject isn't Sendable, but `cancel()` is documented
            // safe from any queue. Box it so `onTermination`'s @Sendable closure can hold it —
            // that capture is also what keeps `source` alive for the stream's lifetime.
            let sourceBox = DispatchSourceBox(source)

            source.setEventHandler {
                guard let handle = FileHandle(forReadingAtPath: path) else { return }
                defer { try? handle.close() }
                handle.seek(toFileOffset: offset)
                let newData = handle.readDataToEndOfFile()
                guard !newData.isEmpty else { return }
                offset += UInt64(newData.count)
                if let text = String(data: newData, encoding: .utf8) {
                    continuation.yield(text)
                }
            }
            source.setCancelHandler {
                close(fileDescriptor)
            }
            continuation.onTermination = { _ in
                sourceBox.source.cancel()
            }

            source.resume()
        }
    }

    /// Parses SMAPI's `[HH:MM:SS LEVEL context] message` header lines (and their unindented
    /// continuation lines) directly into `logEntries` — shared by both the initial load and
    /// every live-tail chunk, so a continuation line arriving in a later chunk still merges
    /// correctly into the last entry appended by an earlier one.
    private func appendParsedLines(_ text: String) {
        let lines = text.components(separatedBy: .newlines)

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
                    var entry = LogLine(timestamp: ts, message: message, level: level, source: .smapi)
                    entry.modName = contextName
                    logEntries.append(entry)
                }
            } else {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !logEntries.isEmpty else { continue }
                let last = logEntries.removeLast()
                let combined = last.message.isEmpty ? trimmed : last.message + "\n" + trimmed
                var updated = LogLine(timestamp: last.timestamp, message: combined, level: last.level, source: .smapi)
                updated.modName = last.modName
                logEntries.append(updated)
            }
        }
    }

    private var smapiLogPath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return (homeDir as NSString).appendingPathComponent(
            ".config/StardewValley/ErrorLogs/SMAPI-latest.txt"
        )
    }
}

/// Lets a non-`Sendable` `DispatchSourceFileSystemObject` cross into a `@Sendable` closure.
/// Safe because `cancel()` is documented callable from any queue.
private final class DispatchSourceBox: @unchecked Sendable {
    let source: DispatchSourceFileSystemObject
    init(_ source: DispatchSourceFileSystemObject) {
        self.source = source
    }
}
