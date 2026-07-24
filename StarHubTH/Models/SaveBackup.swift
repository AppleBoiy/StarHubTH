import Foundation

struct SaveBackup: Identifiable, Equatable {
    var id: String { folderPath.path }
    let folderPath: URL
    let timestamp: Date
    let saveFolder: String   // parent save folder name

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale.current
        return f.string(from: timestamp)
    }

    var relativeLabel: String {
        let secs = Date().timeIntervalSince(timestamp)
        if secs < 60 { return "เมื่อสักครู่" }
        if secs < 3600 { return "\(Int(secs/60)) นาทีที่แล้ว" }
        if secs < 86400 { return "\(Int(secs/3600)) ชั่วโมงที่แล้ว" }
        return "\(Int(secs/86400)) วันที่แล้ว"
    }
}
