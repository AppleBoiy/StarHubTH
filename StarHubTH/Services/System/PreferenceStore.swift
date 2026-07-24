import Foundation

struct PreferenceStore: PreferenceStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func bool(forKey key: String) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func dictionary(forKey key: String) -> [String: String]? {
        defaults.dictionary(forKey: key) as? [String: String]
    }

    func set(_ value: String?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func set(_ value: Data?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func set(_ value: [String: String], forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func removeObject(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}
