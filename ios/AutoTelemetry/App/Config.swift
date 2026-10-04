import Foundation

enum Config {
    /// The router's public address; every maps-engine call lives under /maps/ on it.
    static let routerBaseURL: String = info("RouterBaseURL")
    static let clerkPublishableKey: String = info("ClerkPublishableKey")

    private static func info(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
    }
}
