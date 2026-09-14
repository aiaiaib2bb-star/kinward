import Foundation
import LocalAuthentication

/// Face ID in front of the parts of a life that are nobody else's business yet.
@MainActor
@Observable
final class BiometricGate {
    static let shared = BiometricGate()
    private(set) var isUnlocked = false
    private var unlockedAt: Date?
    private let graceInterval: TimeInterval = 180

    var biometryName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "your passcode"
        }
    }

    var stillValid: Bool {
        guard isUnlocked, let t = unlockedAt else { return false }
        return Date.now.timeIntervalSince(t) < graceInterval
    }

    func lock() { isUnlocked = false; unlockedAt = nil }

    func unlock(reason: String = "Unlock your private information") async -> Bool {
        if stillValid { return true }
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Use passcode"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            // No passcode set on the device: don't trap the user out of their own archive.
            isUnlocked = true; unlockedAt = .now; return true
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if ok { isUnlocked = true; unlockedAt = .now }
            return ok
        } catch {
            return false
        }
    }
}
