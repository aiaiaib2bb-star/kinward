import SwiftUI

/// Kinward Plus. What it adds, said plainly; the two ways to pay, the year first;
/// and the small print the App Store asks for, set where it can be read.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    /// The thing that was reached for, if the paywall was opened by reaching.
    var highlight: PlusFeature? = nil

    @State private var store = Store.shared
    @State private var chosen: Plan.Term = .year
    @State private var working = false
    @State private var thanked = false
    @State private var problem: String?
    @State private var breathe = false
    @State private var legal: LegalDoc?

    private var plan: Plan? { store.plans.first { $0.term == chosen } ?? store.plans.first }

    var body: some View {
        ZStack {
            PaperBackground(deep: true)
            if thanked {
                thanks.transition(.opacity)
            } else {
                offer.transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) { closeButton }
        .interactiveDismissDisabled(working)
        .sheet(item: $legal) { LegalDocumentView(doc: $0) }
        .alert("That didn't go through", isPresented: Binding(
            get: { problem != nil }, set: { if !$0 { problem = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(problem ?? "")
        }
        .task {
            if store.plans.isEmpty || store.loadFailed { await store.loadPlans() }
        }
        .onAppear {
            thanked = store.isPlus
            withAnimation(KMotion.breath.repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(K.inkSoft)
                .frame(width: 34, height: 34)
                .background(Circle().fill(K.surface.opacity(0.92)))
                .overlay(Circle().strokeBorder(K.border.opacity(0.7), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .padding(.top, 16).padding(.trailing, 18)
        .accessibilityLabel("Close")
        .disabled(working)
    }

    // MARK: The offer

    private var offer: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header.arriving(0.05)
                    .padding(.top, 58)
                if let highlight {
                    reasonLine(highlight).arriving(0.2).padding(.top, 20)
                }
                features.arriving(0.28).padding(.top, 26)
                plansBlock.arriving(0.42).padding(.top, 26)
                cta.arriving(0.5).padding(.top, 18)
                footer.padding(.top, 20)
                smallPrint.padding(.top, 14)
                #if DEBUG
                testingNote.padding(.top, 22)
                #endif
            }
            .padding(.horizontal, 22).padding(.bottom, 44)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(K.goldSoft.opacity(K.isClear ? 0.22 : 0.5))
                    .frame(width: 150, height: 150)
                    .blur(radius: 30)
                    .scaleEffect(breathe ? 1.08 : 0.9)
                    .opacity(breathe ? 1 : 0.7)
                Image(AppIconOption.default.preview)
                    .resizable().scaledToFill()
                    .frame(width: 86, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .strokeBorder(K.ink.opacity(0.1), lineWidth: 0.7))
                    .shadow(color: K.shadowInk.opacity(0.25), radius: 16, y: 9)
            }
            .frame(height: 104)

            Text("Kinward Plus").eyebrowStyle(K.gold)
                .padding(.top, 4)

            Text("Keep it beautifully.\nPass it on.")
                .font(.serif(31)).foregroundStyle(K.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("Everything you write and keep is free, and always will be. Plus is for how Kinward looks, and how it's handed down.")
                .font(KType.body(15)).foregroundStyle(K.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
        }
    }

    private func reasonLine(_ f: PlusFeature) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.open").font(.system(size: 12, weight: .medium))
            Text(f.reason).font(KType.label(13))
        }
        .foregroundStyle(K.sageDeep)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Capsule().fill(K.goldSoft.opacity(K.isClear ? 0.14 : 0.3)))
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                ForEach(Array(PlusFeature.allCases.enumerated()), id: \.element) { i, f in
                    HStack(alignment: .top, spacing: 13) {
                        Image(systemName: f.icon)
                            .font(.system(size: 15, weight: .regular)).foregroundStyle(K.sageDeep)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(K.goldSoft.opacity(K.isClear ? 0.16 : 0.32)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(f.title).font(KType.body(15).weight(.medium)).foregroundStyle(K.ink)
                            Text(f.note).font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                                .lineSpacing(1.5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .background(f == highlight ? K.goldSoft.opacity(K.isClear ? 0.1 : 0.16) : .clear)
                    if i < PlusFeature.allCases.count - 1 { HairLine().padding(.leading, 65) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: K.rCard, style: .continuous))
            .cardSurface()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "heart").font(.system(size: 11, weight: .medium)).foregroundStyle(K.gold)
                    .padding(.top, 2)
                Text("Always free: every memory, letter, recording and document, and sharing them with your family.")
                    .font(KType.caption(12)).foregroundStyle(K.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 6)
        }
    }

    // MARK: Plans

    @ViewBuilder
    private var plansBlock: some View {
        if store.plans.isEmpty {
            VStack(spacing: 12) {
                if store.loadFailed {
                    Text("The App Store couldn't be reached just now.")
                        .font(KType.body(14)).foregroundStyle(K.inkSoft)
                    Button {
                        Haptics.tap()
                        Task { await store.loadPlans() }
                    } label: {
                        Text("Try again").font(KType.label(14)).foregroundStyle(K.sageDeep)
                    }
                    .buttonStyle(.plain)
                } else {
                    ProgressView().tint(K.sage)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 160)
        } else {
            VStack(spacing: 10) {
                ForEach(store.plans) { planCard($0) }
            }
        }
    }

    private func planCard(_ p: Plan) -> some View {
        let on = plan?.term == p.term
        return Button {
            Haptics.tap()
            withAnimation(KMotion.gentle) { chosen = p.term }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().strokeBorder(on ? K.sageDeep : K.border, lineWidth: 1.4)
                    if on { Circle().fill(K.sageDeep).padding(5) }
                }
                .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(p.title).font(.serif(19)).foregroundStyle(K.ink)
                        if p.term == .year, store.yearlySaving > 0 {
                            Text("Save \(store.yearlySaving)%")
                                .font(.system(size: 10.5, weight: .bold))
                                .tracking(0.6).textCase(.uppercase)
                                .foregroundStyle(K.onAccent)
                                .padding(.horizontal, 8).padding(.vertical, 3.5)
                                .background(Capsule().fill(K.isClear ? K.sage : K.gold))
                        }
                    }
                    Text(subline(p)).font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(p.price).font(.serif(20)).foregroundStyle(K.ink)
                        .monospacedDigit()
                    Text(p.term == .year ? "a year" : "every 3 months")
                        .font(KType.caption(11.5)).foregroundStyle(K.inkFaint)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(K.surface)
                    .shadow(color: K.shadowInk.opacity(on ? 0.1 : 0.04), radius: on ? 16 : 8, y: on ? 7 : 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(on ? K.sageDeep : K.border.opacity(0.8), lineWidth: on ? 1.8 : 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(working)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func subline(_ p: Plan) -> String {
        if let trial = p.trial { return "\(trial) free, then \(p.perMonth) a month" }
        return p.term == .year ? "Just \(p.perMonth) a month" : "\(p.perMonth) a month"
    }

    // MARK: Buying

    private var cta: some View {
        VStack(spacing: 10) {
            Button { Task { await purchase() } } label: {
                ZStack {
                    if working {
                        ProgressView().tint(K.onAccent)
                    } else {
                        Text(ctaTitle).font(KType.body(16.5).weight(.semibold)).tracking(0.2)
                    }
                }
                .foregroundStyle(K.onAccent)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(
                    Capsule().fill(K.sageDeep)
                        .shadow(color: K.shadowInk.opacity(0.2), radius: 14, y: 6)
                )
            }
            .buttonStyle(.plain)
            .disabled(working || plan == nil)
            .opacity(plan == nil ? 0.5 : 1)

            if let p = plan {
                Text(p.trial.map { "\($0) free, then \(p.price) \(p.term == .year ? "a year" : "every 3 months"). Cancel anytime." }
                     ?? "Renews at \(p.price) \(p.term == .year ? "a year" : "every 3 months"). Cancel anytime.")
                    .font(KType.caption(12)).foregroundStyle(K.inkSoft)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var ctaTitle: String {
        if let trial = plan?.trial { return "Try \(trial) free" }
        return "Continue"
    }

    private func purchase() async {
        guard let plan else { return }
        Haptics.tap()
        working = true
        let outcome = await store.buy(plan)
        working = false
        handle(outcome)
    }

    private func restore() async {
        Haptics.tap()
        working = true
        let outcome = await store.restore()
        working = false
        handle(outcome)
    }

    private func handle(_ outcome: Store.Outcome) {
        switch outcome {
        case .done:
            Haptics.kept()
            withAnimation(KMotion.calm) { thanked = true }
        case .cancelled:
            break
        case .notConnected:
            #if DEBUG
            problem = "Purchases aren't connected in this build yet. Add the RevenueCat key to RevenueCat.plist."
            #else
            problem = "Purchases aren't available right now. Please try again in a little while."
            #endif
        case .nothingToRestore:
            problem = "No Kinward Plus purchase was found for this Apple ID."
        case .failed(let message):
            problem = message
        }
    }

    // MARK: Small print

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Restore purchases") { Task { await restore() } }
            dot
            Button("Terms of Use") { legal = .terms }
            dot
            Button("Privacy Policy") { legal = .privacy }
        }
        .font(KType.caption(12.5))
        .foregroundStyle(K.inkSoft)
        .buttonStyle(.plain)
        .disabled(working)
    }

    private var dot: some View {
        Circle().fill(K.inkFaint.opacity(0.6)).frame(width: 2.5, height: 2.5)
    }

    private var smallPrint: some View {
        Text("Payment is charged to your Apple ID when you confirm. The subscription renews automatically unless it's cancelled at least 24 hours before the end of the current period, and your account is charged for the renewal in the 24 hours before it ends. You can manage or cancel it anytime in your App Store account settings.")
            .font(KType.caption(10.5)).foregroundStyle(K.inkFaint)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    #if DEBUG
    /// Only in debug builds, and only until purchases are connected: says why the
    /// buttons can't buy anything yet, and lets the unlocked app be tried.
    @ViewBuilder
    private var testingNote: some View {
        if !store.isReady {
            VStack(spacing: 9) {
                Text("Debug build · purchases not connected")
                    .font(.system(size: 11, weight: .semibold)).textCase(.uppercase).tracking(0.8)
                    .foregroundStyle(K.inkFaint)
                Text("RevenueCat.plist has no key yet, so these are the list prices and nothing can be bought.")
                    .font(KType.caption(12)).foregroundStyle(K.inkSoft)
                    .multilineTextAlignment(.center)
                Button {
                    Haptics.tap()
                    store.testUnlock.toggle()
                    if store.testUnlock { withAnimation(KMotion.calm) { thanked = true } }
                } label: {
                    Text(store.testUnlock ? "Lock Plus again" : "Unlock Plus for testing")
                        .font(KType.label(13)).foregroundStyle(K.sageDeep)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(K.border, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
    }
    #endif

    // MARK: After

    private var thanks: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(K.goldSoft.opacity(K.isClear ? 0.22 : 0.5))
                    .frame(width: 170, height: 170)
                    .blur(radius: 34)
                    .scaleEffect(breathe ? 1.08 : 0.9)
                Image(AppIconOption.default.preview)
                    .resizable().scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                    .shadow(color: K.shadowInk.opacity(0.25), radius: 16, y: 9)
            }
            .arriving(0.05)
            Text("Thank you.")
                .font(.serif(34)).foregroundStyle(K.ink)
                .arriving(0.2)
            Text("Kinward Plus is yours. The book of your life, passing things on, the Clear look and every icon are open now.")
                .font(KType.body(15.5)).foregroundStyle(K.inkSoft)
                .multilineTextAlignment(.center).lineSpacing(3)
                .padding(.horizontal, 12)
                .arriving(0.32)
            Spacer()
            KButton(title: "Carry on") { dismiss() }
                .arriving(0.5)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 26)
    }
}

// MARK: - Arriving
// The paywall comes in the way the introduction does: a little at a time, each
// piece easing up into place out of a soft blur.

private struct Arriving: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .blur(radius: shown ? 0 : 6)
            .onAppear { withAnimation(KMotion.arrive.delay(delay)) { shown = true } }
    }
}

private extension View {
    func arriving(_ delay: Double) -> some View { modifier(Arriving(delay: delay)) }
}

/// The small mark on something that comes with Plus, shown until it's bought.
struct PlusBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill").font(.system(size: 8, weight: .bold))
            Text("Plus").font(.system(size: 10.5, weight: .bold)).tracking(0.5).textCase(.uppercase)
        }
        .foregroundStyle(K.onAccent)
        .padding(.horizontal, 7).padding(.vertical, 3.5)
        .background(Capsule().fill(K.isClear ? K.sage : K.gold))
        .accessibilityLabel("Kinward Plus")
    }
}

/// A request to show Kinward Plus. Carried by the sheet itself, so the paywall
/// always knows what was reached for — a separate flag and feature can be read a
/// frame apart, and the paywall then opens without its reason.
struct PaywallRequest: Identifiable {
    let id = UUID()
    var feature: PlusFeature?
}

extension View {
    func paywall(_ request: Binding<PaywallRequest?>) -> some View {
        sheet(item: request) { PaywallView(highlight: $0.feature) }
    }
}
