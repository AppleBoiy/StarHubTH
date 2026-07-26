import XCTest
@testable import StarHubTH

/// Characterization tests for LocalizationStore, extracted from StarHubTHViewModel in
/// refactor Phase 4.1. Uses StubPreferenceStoring (Phase 3.2) instead of real UserDefaults.
@MainActor
final class LocalizationStoreTests: XCTestCase {
    func testDefaultsToNormalizedLanguage() {
        let prefs = StubPreferenceStoring()
        prefs.set("th", forKey: "currentLanguage")
        let store = LocalizationStore(preferenceStoring: prefs)
        XCTAssertEqual(store.currentLanguage, "th", "a saved supported language is used as-is")
    }

    func testSettingLanguagePersists() {
        let prefs = StubPreferenceStoring()
        let store = LocalizationStore(preferenceStoring: prefs)
        store.currentLanguage = "th"
        XCTAssertEqual(prefs.string(forKey: "currentLanguage"), "th", "setting currentLanguage persists it")
    }

    func testUnsupportedLanguageCorrectsToEnglish() {
        let prefs = StubPreferenceStoring()
        let store = LocalizationStore(preferenceStoring: prefs)
        store.currentLanguage = "fr"
        XCTAssertEqual(store.currentLanguage, "en", "an unsupported language self-corrects to en")
    }

    func testDateFormatterEnglish() {
        let prefs = StubPreferenceStoring()
        prefs.set("en", forKey: "currentLanguage")
        let store = LocalizationStore(preferenceStoring: prefs)
        let formatter = store.makeDateFormatter()
        XCTAssertEqual(formatter.calendar.identifier, .gregorian, "English date formatter uses the Gregorian calendar")
        XCTAssertEqual(formatter.dateFormat, "M/d/yyyy", "English short date format is M/d/yyyy")
    }

    func testDateFormatterThai() {
        let prefs = StubPreferenceStoring()
        prefs.set("th", forKey: "currentLanguage")
        let store = LocalizationStore(preferenceStoring: prefs)
        let formatter = store.makeDateFormatter()
        XCTAssertEqual(formatter.calendar.identifier, .buddhist, "Thai date formatter uses the Buddhist calendar")
        XCTAssertEqual(formatter.dateFormat, "d/M/yyyy", "Thai short date format is d/M/yyyy")
    }

    func testLocalizedTagKnownAndUnknown() {
        let store = LocalizationStore(preferenceStoring: StubPreferenceStoring())
        XCTAssertFalse(store.localizedTag("Framework").isEmpty, "a known tag resolves to a non-empty localized string")
        XCTAssertEqual(store.localizedTag("SomeRandomTag"), "SomeRandomTag", "an unrecognized tag passes through unchanged")
        XCTAssertEqual(store.localizedTag(""), "", "an empty tag passes through unchanged")
    }
}
