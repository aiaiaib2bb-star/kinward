import SwiftUI

/// The short walk around the app a first-time user gets, once, after onboarding.
///
/// It points at things that are actually on screen rather than describing them in
/// the abstract: the week's question, the quick row, and whichever way out of Home
/// this person has chosen. Skippable at every step, and repeatable from Settings.
enum TutorialStop: String, CaseIterable, Identifiable {
    case question, quick, navigation, search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .question:   "One question a week"
        case .quick:      "Or start it yourself"
        case .navigation: "Everything you keep"
        case .search:     "And it stays yours"
        }
    }

    func text(for style: NavStyle) -> String {
        switch self {
        case .question:
            "Kinward asks you one thing at a time. Answer it in a sentence or speak it out loud — there's no wrong length, and nothing is a streak."
        case .quick:
            "A memory, your voice, a letter to one person, or something you had to learn the hard way. Any of them takes a minute."
        case .navigation:
            switch style {
            case .dial:
                "Press and hold the dial in the corner, then slide your thumb without lifting. The seven parts of your Kinward fan out — let go on the one you want."
            case .bar:
                "The bar along the bottom holds Home, your memories and letters, and the button that keeps something new. More has the rest."
            }
        case .search:
            "All of it stays on this device. No account, no server, nobody else's copy. You decide if and when any of it is shared."
        }
    }

    var icon: String {
        switch self {
        case .question: "quote.opening"
        case .quick: "plus.circle"
        case .navigation: "circle.circle"
        case .search: "lock"
        }
    }
}

// MARK: - Telling the overlay where things are

private struct TutorialAnchorKey: PreferenceKey {
    static let defaultValue: [TutorialStop: Anchor<CGRect>] = [:]
    static func reduce(value: inout [TutorialStop: Anchor<CGRect>],
                       nextValue: () -> [TutorialStop: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Marks this view as the thing a tutorial stop is talking about.
    func tutorialAnchor(_ stop: TutorialStop) -> some View {
        anchorPreference(key: TutorialAnchorKey.self, value: .bounds) { [stop: $0] }
    }
}

// MARK: - The tour

struct TutorialOverlay: View {
    @Binding var isPresented: Bool
    var style: NavStyle
    /// Where the page says its landmarks are, re-read on every layout pass.
    var anchors: [TutorialStop: Anchor<CGRect>]
    /// Called once the last card is dismissed, so it is never shown again.
    var onFinish: () -> Void

    @State private var index = 0
    @State private var shown = false

    private var stops: [TutorialStop] { TutorialStop.allCases }
    private var stop: TutorialStop { stops[min(index, stops.count - 1)] }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(shown ? 0.62 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { next() }

                content(in: proxy)
            }
            .opacity(shown ? 1 : 0)
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45).delay(0.35)) { shown = true }
        }
    }

    @ViewBuilder
    private func content(in proxy: GeometryProxy) -> some View {
        // The overlay sits above the page, so it reads the page's anchors from the
        // same coordinate space the page published them in.
        let target = anchors[stop].map { proxy[$0] }

        ZStack(alignment: .topLeading) {
            if let target {
                // A ring rather than a hole: punching the scrim out makes the page
                // behind it look lit from nowhere, and this keeps the dimming even.
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.6)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
                    .frame(width: target.width + 14, height: target.height + 14)
                    .position(x: target.midX, y: target.midY)
                    .animation(KMotion.gentle, value: index)
                    .allowsHitTesting(false)
            }

            card(for: proxy, target: target)
        }
    }

    private func card(for proxy: GeometryProxy, target: CGRect?) -> some View {
        // Sit under the thing being pointed at when there is room, over it otherwise.
        let below = (target?.maxY ?? 0) + 260 < proxy.size.height
        let y = target.map { below ? $0.maxY + 24 : max(90, $0.minY - 240) }
            ?? proxy.size.height / 2

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: stop.icon)
                    .font(.system(size: 12, weight: .light)).foregroundStyle(K.gold)
                Text("\(index + 1) of \(stops.count)")
                    .font(KType.eyebrow(10)).tracking(2).textCase(.uppercase)
                    .foregroundStyle(K.inkFaint)
                Spacer()
                Button("Skip") { finish() }
                    .font(KType.caption(12.5)).foregroundStyle(K.inkFaint)
            }
            Text(stop.title).font(.serif(22)).foregroundStyle(K.ink)
            Text(stop.text(for: style))
                .font(KType.body(14.5)).foregroundStyle(K.inkSoft).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    ForEach(stops.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == index ? K.sageDeep : K.border)
                            .frame(width: i == index ? 16 : 5, height: 5)
                    }
                }
                Spacer()
                Button {
                    Haptics.tap()
                    next()
                } label: {
                    Text(index == stops.count - 1 ? "Start" : "Next")
                        .font(KType.body(14.5).weight(.medium))
                        .foregroundStyle(K.onAccent)
                        .padding(.horizontal, 22).padding(.vertical, 10)
                        .background(Capsule().fill(K.sageDeep))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(width: min(proxy.size.width - 44, 360), alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(K.surface)
                .shadow(color: .black.opacity(0.32), radius: 26, y: 10)
        )
        .position(x: proxy.size.width / 2, y: y + 110)
        .animation(KMotion.gentle, value: index)
    }

    private func next() {
        if index >= stops.count - 1 {
            finish()
        } else {
            Haptics.tap()
            withAnimation(KMotion.gentle) { index += 1 }
        }
    }

    private func finish() {
        Haptics.settle()
        withAnimation(.easeIn(duration: 0.28)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            isPresented = false
            onFinish()
        }
    }
}

extension View {
    /// Hangs the tour over a page and feeds it the anchors that page published.
    func tutorial(isPresented: Binding<Bool>, style: NavStyle,
                  onFinish: @escaping () -> Void) -> some View {
        overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            if isPresented.wrappedValue {
                TutorialOverlay(isPresented: isPresented, style: style,
                                anchors: anchors, onFinish: onFinish)
            }
        }
    }
}
