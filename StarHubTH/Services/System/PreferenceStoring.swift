import Foundation

/// I/O boundary over `UserDefaults`. `PreferenceStore` is the `Live` implementation; a
/// `Stub` conformance lets stores be tested without touching real user defaults.
protocol PreferenceStoring {
    func string(forKey key: String) -> String?
    func bool(forKey key: String) -> Bool?
    func data(forKey key: String) -> Data?
    func dictionary(forKey key: String) -> [String: String]?

    func set(_ value: String?, forKey key: String)
    func set(_ value: Bool, forKey key: String)
    func set(_ value: Data?, forKey key: String)
    func set(_ value: [String: String], forKey key: String)

    func removeObject(forKey key: String)
}
