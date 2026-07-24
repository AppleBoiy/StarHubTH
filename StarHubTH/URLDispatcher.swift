import Foundation

final class URLDispatcher: ObservableObject {
    static let shared = URLDispatcher()
    @Published var openedURL: URL? = nil
}
