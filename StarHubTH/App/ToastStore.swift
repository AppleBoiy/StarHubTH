import Foundation

/// The app's single non-blocking, auto-dismissing confirmation channel — for things the
/// user doesn't need to explicitly acknowledge (e.g. "mod installed"), unlike `AlertStore`'s
/// modal `.alert()` for failures that do. Installing every missing mod in a Mod Pack used to
/// fire one blocking alert per mod through `AlertStore`, forcing a click between each one
/// before the next install could even start — this exists so success no longer does that.
@MainActor
final class ToastStore: ObservableObject {
    @Published private(set) var message: String?

    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, duration: Duration = .seconds(3)) {
        dismissTask?.cancel()
        self.message = message
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}
