import Foundation

/// In-memory stand-in for `UserDefaults`.
final class StubPreferenceStoring: PreferenceStoring {
    private var strings: [String: String] = [:]
    private var bools: [String: Bool] = [:]
    private var datas: [String: Data] = [:]
    private var dictionaries: [String: [String: String]] = [:]
    private var stringArrays: [String: [String]] = [:]

    func string(forKey key: String) -> String? { strings[key] }
    func bool(forKey key: String) -> Bool? { bools[key] }
    func data(forKey key: String) -> Data? { datas[key] }
    func dictionary(forKey key: String) -> [String: String]? { dictionaries[key] }

    func set(_ value: String?, forKey key: String) { strings[key] = value }
    func set(_ value: Bool, forKey key: String) { bools[key] = value }
    func set(_ value: Data?, forKey key: String) { datas[key] = value }
    func set(_ value: [String: String], forKey key: String) { dictionaries[key] = value }
    func set(_ value: [String], forKey key: String) { stringArrays[key] = value }

    func removeObject(forKey key: String) {
        strings.removeValue(forKey: key)
        bools.removeValue(forKey: key)
        datas.removeValue(forKey: key)
        dictionaries.removeValue(forKey: key)
        stringArrays.removeValue(forKey: key)
    }
}
