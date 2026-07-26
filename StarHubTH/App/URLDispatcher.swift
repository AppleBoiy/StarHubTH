import Foundation

/// Holds genuine mutable state (`openedURL`, read/written from multiple places), so unlike
/// this phase's other flagged singletons a plain `Sendable` conformance would be dishonest —
/// `@MainActor` is the correct fix (it's an `ObservableObject` bound to SwiftUI already, so
/// every legitimate reader/writer is on the main thread by convention).
@MainActor
final class URLDispatcher: ObservableObject {
    static let shared = URLDispatcher()
    @Published var openedURL: URL? = nil // STANDARDS-EXCEPTION: §8 — AppDelegate writes the incoming URL; MainView clears it after handling
}
