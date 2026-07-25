import Foundation

/// Characterization tests for LocalizationStore, extracted from StarHubTHViewModel in
/// refactor Phase 4.1. Uses StubPreferenceStoring (Phase 3.2) instead of real UserDefaults.
@MainActor
struct LocalizationStoreTests {
    static func run() {
        print("Running LocalizationStoreTests...")
        testDefaultsToNormalizedLanguage()
        testSettingLanguagePersists()
        testUnsupportedLanguageCorrectsToEnglish()
        testDateFormatterEnglish()
        testDateFormatterThai()
        testLocalizedTagKnownAndUnknown()
    }

    private static func testDefaultsToNormalizedLanguage() {
        let prefs = StubPreferenceStoring()
        prefs.set("th", forKey: "currentLanguage")
        let store = LocalizationStore(preferenceStoring: prefs)
        SimpleTestFramework.assertEqual(store.currentLanguage, "th", "a saved supported language is used as-is")
    }

    private static func testSettingLanguagePersists() {
        let prefs = StubPreferenceStoring()
        let store = LocalizationStore(preferenceStoring: prefs)
        store.currentLanguage = "th"
        SimpleTestFramework.assertEqual(prefs.string(forKey: "currentLanguage"), "th", "setting currentLanguage persists it")
    }

    private static func testUnsupportedLanguageCorrectsToEnglish() {
        let prefs = StubPreferenceStoring()
        let store = LocalizationStore(preferenceStoring: prefs)
        store.currentLanguage = "fr"
        SimpleTestFramework.assertEqual(store.currentLanguage, "en", "an unsupported language self-corrects to en")
    }

    private static func testDateFormatterEnglish() {
        let prefs = StubPreferenceStoring()
        prefs.set("en", forKey: "currentLanguage")
        let store = LocalizationStore(preferenceStoring: prefs)
        let formatter = store.makeDateFormatter()
        SimpleTestFramework.assertEqual(formatter.calendar.identifier, .gregorian, "English date formatter uses the Gregorian calendar")
        SimpleTestFramework.assertEqual(formatter.dateFormat, "M/d/yyyy", "English short date format is M/d/yyyy")
    }

    private static func testDateFormatterThai() {
        let prefs = StubPreferenceStoring()
        prefs.set("th", forKey: "currentLanguage")
        let store = LocalizationStore(preferenceStoring: prefs)
        let formatter = store.makeDateFormatter()
        SimpleTestFramework.assertEqual(formatter.calendar.identifier, .buddhist, "Thai date formatter uses the Buddhist calendar")
        SimpleTestFramework.assertEqual(formatter.dateFormat, "d/M/yyyy", "Thai short date format is d/M/yyyy")
    }

    private static func testLocalizedTagKnownAndUnknown() {
        let store = LocalizationStore(preferenceStoring: StubPreferenceStoring())
        SimpleTestFramework.assertFalse(store.localizedTag("Framework").isEmpty, "a known tag resolves to a non-empty localized string")
        SimpleTestFramework.assertEqual(store.localizedTag("SomeRandomTag"), "SomeRandomTag", "an unrecognized tag passes through unchanged")
        SimpleTestFramework.assertEqual(store.localizedTag(""), "", "an empty tag passes through unchanged")
    }
}
