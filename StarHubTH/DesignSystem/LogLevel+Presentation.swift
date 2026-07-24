import SwiftUI

extension LogLevel {
    var color: Color {
        switch self {
        case .info:    return .primary
        case .warning: return .orange
        case .error:   return .red
        case .smapi:   return .blue
        }
    }

    var icon: String {
        switch self {
        case .info:    return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error:   return "xmark.octagon"
        case .smapi:   return "terminal"
        }
    }
}
