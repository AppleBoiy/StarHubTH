import SwiftUI

@main
struct StarHubTHApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var urlDispatcher = URLDispatcher.shared
    
    init() {
        if let currentLang = UserDefaults.standard.string(forKey: "currentLanguage") {
            UserDefaults.standard.set([currentLang], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(urlDispatcher)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 600)
    }
}
