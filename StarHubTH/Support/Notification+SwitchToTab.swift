import Foundation

extension Notification.Name {
    /// Posted to ask `MainView` to switch tabs from outside the view hierarchy (an
    /// imported Nexus Collection wants to jump to the Mod Packs tab). Same shape as the
    /// existing `.jumpToMod` notification (`Features/Logs/LogsView.swift`), already used
    /// for an unrelated cross-cutting UI-navigation need.
    static let switchToTab = Notification.Name("StarHubTH.switchToTab")
}
