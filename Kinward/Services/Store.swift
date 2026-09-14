import Foundation
import RevenueCat

/// RevenueCat, kept at arm's length.
///
/// The public SDK key lives in `Kinward/Resources/RevenueCat.plist`, which is not in
/// version control. If that file is missing — a fresh clone, or before a key has been
/// pasted in — the app runs exactly as it did before: nothing about writing, keeping
/// or reading anything depends on this, and nothing here should ever be load-bearing
/// for someone's own archive.
@MainActor
enum Store {
    /// True once a key was found and RevenueCat was configured.
    private(set) static var isReady = false

    static func start() {
        guard !isReady, let key = publicKey else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: key)
        isReady = true
    }

    /// Whether this person currently has an entitlement. Always false while the SDK
    /// is unconfigured, so every caller falls back to the free experience rather than
    /// to an error.
    static func isActive(_ entitlement: String) async -> Bool {
        guard isReady else { return false }
        guard let info = try? await Purchases.shared.customerInfo() else { return false }
        return info.entitlements[entitlement]?.isActive == true
    }

    /// The key, or nil if the file is absent or still holds the placeholder.
    private static var publicKey: String? {
        guard let url = Bundle.main.url(forResource: "RevenueCat", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any],
              let key = dict["PublicSDKKey"] as? String
        else { return nil }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
