import SwiftUI
import Cocoa

extension View {
    // Utility to change cursor to pointing hand on hover (supported on all macOS versions)
    func pointingHandCursor() -> some View {
        self.onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

