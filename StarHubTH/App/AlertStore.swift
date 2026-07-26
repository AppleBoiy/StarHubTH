import Foundation

/// The app's single modal-alert channel. Replaces `StarHubTHViewModel.alertMessage`/
/// `.showAlert` — nearly every store surfaces a user-facing failure or confirmation
/// through this, so it lives in `App/` alongside the other cross-cutting state rather
/// than under any one feature.
@MainActor
final class AlertStore: ObservableObject {
    @Published private(set) var message: String = ""
    @Published var isPresented: Bool = false // STANDARDS-EXCEPTION: §8 — SwiftUI's .alert(isPresented:) needs a two-way Binding to reset this to false on dismiss

    func show(_ message: String) {
        self.message = message
        self.isPresented = true
    }
}
