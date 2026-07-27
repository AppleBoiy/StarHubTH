import SwiftUI

/// Non-blocking overlay bound to `ToastStore.message` — sits at the bottom of the window
/// and auto-dismisses, never intercepting clicks elsewhere (unlike `AlertStore`'s modal
/// `.alert()`), so a sequence of installs doesn't force a click between every single one.
struct ToastBannerView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .lineLimit(2)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .allowsHitTesting(false)
    }
}
