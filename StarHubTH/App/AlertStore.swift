import Foundation

/// The app's single modal-alert channel. Replaces `StarHubTHViewModel.alertMessage`/
/// `.showAlert` — nearly every store surfaces a user-facing failure or confirmation
/// through this, so it lives in `App/` alongside the other cross-cutting state rather
/// than under any one feature.
final class AlertStore: ObservableObject {
    @Published private(set) var message: String = ""
    @Published var isPresented: Bool = false

    func show(_ message: String) {
        self.message = message
        self.isPresented = true
    }
}
