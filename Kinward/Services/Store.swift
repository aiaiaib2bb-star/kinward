import Foundation
import RevenueCat
import UIKit

// MARK: - Kinward Plus
//
// Everything a person writes, records and keeps is free, and stays free: nobody's
// archive is ever held behind a payment. Plus is for how Kinward looks and for how
// it is handed down — the four things below, and nothing else.
//
// Setup, outside the code:
//   App Store Connect — one subscription group, "Kinward Plus", with two
//     auto-renewing products: 3 months at $9.99 and 1 year at $14.99.
//   RevenueCat — an entitlement named "plus" holding both products, and the
//     current offering holding them as its Three Month and Annual packages.
// The paywall reads its prices from there, so they are changed there, not here.

enum PlusFeature: String, CaseIterable, Identifiable {
    case legacyBook, passItOn, clearLook, icons

    var id: String { rawValue }

    var title: String {
        switch self {
        case .legacyBook: "The book of your life"
        case .passItOn:   "Pass it on"
        case .clearLook:  "The Clear look"
        case .icons:      "Every icon"
        }
    }

    var note: String {
        switch self {
        case .legacyBook: "Everything you've kept, set as a book to be read years from now."
        case .passItOn:   "Hand what you've kept to your children, for them to hand to theirs."
        case .clearLook:  "Kinward the way the iPhone itself would make it, in light and dark."
        case .icons:      "Eleven more for your home screen — pewter, marble, the seal and the rest."
        }
    }

    var icon: String {
        switch self {
        case .legacyBook: "book.closed"
        case .passItOn:   "arrow.turn.down.right"
        case .clearLook:  "circle.lefthalf.filled"
        case .icons:      "square.grid.2x2"
        }
    }

    /// Said at the top of the paywall when it was opened by reaching for this.
    var reason: String {
        switch self {
        case .legacyBook: "The book of your life comes with Kinward Plus."
        case .passItOn:   "Passing things on comes with Kinward Plus."
        case .clearLook:  "The Clear look comes with Kinward Plus."
        case .icons:      "The other icons come with Kinward Plus."
        }
    }
}

/// One of the two ways to pay. Built from a RevenueCat package when purchases are
/// connected, and from the list prices otherwise so the paywall can still be seen.
struct Plan: Identifiable {
    enum Term: String { case year, quarter }

    let term: Term
    let price: String
    let perMonth: String
    /// The price as a number, for working out what the year saves.
    let amount: Double
    /// "1 week free", when the product carries a free trial.
    let trial: String?
    let package: Package?

    var id: String { term.rawValue }
    var title: String { term == .year ? "Yearly" : "3 months" }
    var per: String { term == .year ? "year" : "3 months" }

    static let listPrices: [Plan] = [
        Plan(term: .year, price: "$14.99", perMonth: "$1.25", amount: 14.99, trial: nil, package: nil),
        Plan(term: .quarter, price: "$9.99", perMonth: "$3.33", amount: 9.99, trial: nil, package: nil),
    ]
}

@MainActor
@Observable
final class Store {
    static let shared = Store()
    static let entitlement = "plus"

    private static let cacheKey = "kinward.plus.active"
    #if DEBUG
    private static let testKey = "kinward.plus.testUnlock"
    #endif

    /// True once a key was found and RevenueCat was configured.
    private(set) var isReady = false
    /// What the App Store last said. Cached, so a subscriber opening the app with no
    /// signal still has what they paid for.
    private(set) var entitled: Bool
    private(set) var plans: [Plan] = []
    /// How much cheaper the year is than four quarters, as a whole percentage.
    var yearlySaving: Int {
        guard let y = plans.first(where: { $0.term == .year })?.amount,
              let q = plans.first(where: { $0.term == .quarter })?.amount, q > 0
        else { return 0 }
        return max(0, Int(((1 - y / (q * 4)) * 100).rounded(.down)))
    }
    private(set) var loadFailed = false

    #if DEBUG
    /// Debug builds only: lets the paywall be walked through before purchases are
    /// connected. Compiled out of anything that ships.
    var testUnlock: Bool {
        didSet { UserDefaults.standard.set(testUnlock, forKey: Self.testKey); settle() }
    }
    var isPlus: Bool { entitled || testUnlock }
    #else
    var isPlus: Bool { entitled }
    #endif

    private init() {
        entitled = UserDefaults.standard.bool(forKey: Self.cacheKey)
        #if DEBUG
        testUnlock = UserDefaults.standard.bool(forKey: Self.testKey)
        #endif
    }

    func has(_ feature: PlusFeature) -> Bool { isPlus }

    // MARK: Starting

    func start() {
        guard !isReady else { return }
        guard let key = Self.publicKey else {
            // Nothing to ask, so the answer is no — but only for what Plus adds.
            // Everything else carries on exactly as it would.
            set(entitled: false)
            plans = Plan.listPrices
            return
        }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: key)
        isReady = true
        Task {
            for await info in Purchases.shared.customerInfoStream { apply(info) }
        }
        Task { await loadPlans() }
    }

    func loadPlans() async {
        guard isReady else { plans = Plan.listPrices; return }
        loadFailed = false
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else { loadFailed = true; return }
            var found: [Plan] = []
            if let year = current.annual { found.append(Self.plan(.year, year)) }
            if let quarter = current.threeMonth { found.append(Self.plan(.quarter, quarter)) }
            plans = found
            loadFailed = found.isEmpty
        } catch {
            loadFailed = true
        }
    }

    private static func plan(_ term: Plan.Term, _ package: Package) -> Plan {
        let p = package.storeProduct
        var trial: String?
        if let intro = p.introductoryDiscount, intro.paymentMode == .freeTrial {
            trial = "\(describe(intro.subscriptionPeriod)) free"
        }
        return Plan(term: term, price: p.localizedPriceString,
                    perMonth: p.localizedPricePerMonth ?? "",
                    amount: (p.price as NSDecimalNumber).doubleValue, trial: trial, package: package)
    }

    private static func describe(_ period: SubscriptionPeriod) -> String {
        let n = period.value
        let unit: String
        switch period.unit {
        case .day:   unit = n == 1 ? "day" : "days"
        case .week:  unit = n == 1 ? "week" : "weeks"
        case .month: unit = n == 1 ? "month" : "months"
        case .year:  unit = n == 1 ? "year" : "years"
        @unknown default: unit = "days"
        }
        return n == 1 ? "1 \(unit)" : "\(n) \(unit)"
    }

    // MARK: Buying

    enum Outcome: Equatable {
        case done, cancelled, notConnected, nothingToRestore
        case failed(String)
    }

    func buy(_ plan: Plan) async -> Outcome {
        guard isReady, let package = plan.package else { return .notConnected }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            apply(result.customerInfo)
            // Ask to Buy and the like leave it pending; the stream picks it up later.
            return entitled ? .done : .failed("The App Store hasn't confirmed it yet. It will unlock as soon as it does.")
        } catch let error as ErrorCode where error == .purchaseCancelledError {
            return .cancelled
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async -> Outcome {
        guard isReady else { return .notConnected }
        do {
            apply(try await Purchases.shared.restorePurchases())
            return entitled ? .done : .nothingToRestore
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func manage() async {
        if isReady, (try? await Purchases.shared.showManageSubscriptions()) != nil { return }
        await UIApplication.shared.open(Links.manageSubscriptions)
    }

    // MARK: Keeping it true

    private func apply(_ info: CustomerInfo) {
        set(entitled: info.entitlements[Self.entitlement]?.isActive == true)
    }

    private func set(entitled value: Bool) {
        if value != entitled {
            entitled = value
            UserDefaults.standard.set(value, forKey: Self.cacheKey)
        }
        settle()
    }

    /// When Plus ends, what it added goes back to how Kinward comes: Paper, and the
    /// leather icon. Nothing that was written or kept is touched.
    ///
    /// iOS only changes the home-screen icon for an app that is in front, so that
    /// part waits for the next time it is — RootView calls this again then.
    func settle() {
        guard !isPlus else { return }
        if ThemeStore.shared.theme == .clear { ThemeStore.shared.theme = .paper }
        if AppIconStore.shared.selected != .default,
           UIApplication.shared.applicationState == .active {
            AppIconStore.shared.set(.default)
        }
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
