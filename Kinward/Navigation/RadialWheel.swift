import SwiftUI

/// The dial. Closed it's a quiet mark in the corner; open it fans out into that same
/// corner — the seven sections on an arc, with the page still there behind it.
///
/// Two ways in. Press and hold the closed dial and the fan blooms under your thumb:
/// slide up or down without lifting and the sections step past with a detent each time,
/// release to open the one you landed on. Or tap it, and the fan stays open — touch a
/// section, or sweep your thumb around the arc and let go on the one you want.
///
/// Touch handling is deliberately flat: while the fan is open a single transparent
/// layer covers the screen and works out what the finger meant from where it is —
/// the hub, a section, the keep-something node, or nothing at all.
struct RadialWheel: View {
    @Bindable var router: Router
    var onCapture: () -> Void

    // MARK: - Geometry

    // Closed
    private let closedSize: CGFloat = 92
    private var closedRadius: CGFloat { closedSize / 2 - 10 }
    /// The selected section's name rests up-and-left of the closed dial, where the
    /// screen has room for it.
    private let anchor: Double = -132

    // Open: everything is measured from a hub in the bottom-right corner.
    private let panelRadius: CGFloat = 176
    private let hubRadius: CGFloat = 37
    private let iconRadius: CGFloat = 132
    /// The fan climbs from pointing-left to pointing-up, so the sentence the sections
    /// tell reads as a rise: what happened, up to what I leave behind.
    private let fanStart: Double = 178
    private let fanStep: Double = 17
    /// Below the first section and a little further off than one step, so it reads as
    /// something other than an eighth section.
    private var captureAngle: Double { fanStart - fanStep * 1.25 }
    private var fanEnd: Double { fanStart + fanStep * Double(sections.count - 1) }

    private var sections: [KinwardSection] { KinwardSection.allCases }
    private var selectedIndex: Int { sections.firstIndex(of: router.section) ?? 0 }
    private func angle(for index: Int) -> Double { fanStart + fanStep * Double(index) }

    // MARK: - State

    @State private var breathe = false
    @State private var sectionAtOpen: KinwardSection = .memories

    // Press off the closed dial
    @State private var pressing = false
    /// True once the finger has actually reached a node. Until then the press is
    /// still just a tap, and lifting leaves the fan open to browse.
    @State private var engaged = false
    @State private var detentKick = false

    /// What the finger is over, for both the press and a fresh touch on the open fan.
    @State private var pointing: FanTarget? = nil

    /// One space for every gesture here, so a finger's position means the same thing
    /// whichever layer caught it.
    private static let space = "kinward.wheel"

    private enum FanTarget: Equatable {
        case hub, capture, section(KinwardSection)
    }

    var body: some View {
        GeometryReader { geo in
            let open = router.wheelOpen
            let closedCentre = CGPoint(x: geo.size.width - 58, y: geo.size.height - 82)
            let openHub = CGPoint(x: geo.size.width - 74, y: geo.size.height - 104)

            ZStack {
                if open {
                    // The page keeps its light; only the corner the fan sits in recedes.
                    RadialGradient(colors: [K.ink.opacity(0.13), K.ink.opacity(0.05), .clear],
                                   center: UnitPoint(x: openHub.x / max(geo.size.width, 1),
                                                     y: openHub.y / max(geo.size.height, 1)),
                                   startRadius: panelRadius * 0.55,
                                   endRadius: panelRadius + 165)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)

                    panel(size: geo.size, hub: openHub)
                    fan(hub: openHub)
                    caption(hub: openHub, size: geo.size)
                }

                closedDial
                    .position(closedCentre)
                    .opacity(open ? 0 : 1)
                    .scaleEffect(open ? 0.84 : 1)
                    .animation(KMotion.settle, value: open)
                    .allowsHitTesting(false)

                hub(open: open).position(open ? openHub : closedCentre)

                if open { openTouch(hub: openHub) }

                // Anchored where the closed dial sits and never removed, so the fan
                // blooming mid-press can't cancel the gesture. It reads translation,
                // not location, for the same reason.
                Circle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: closedSize + 20, height: closedSize + 20)
                    .position(closedCentre)
                    .gesture(pressAndScrub(hub: openHub))
                    .allowsHitTesting(!open || pressing)
            }
            .coordinateSpace(.named(Self.space))
            .onAppear {
                withAnimation(KMotion.breath.repeatForever(autoreverses: true)) { breathe = true }
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Closed dial

    /// At this size individual icons are illegible, so the ring carries the section's
    /// name instead, with the remaining sections marked as quiet ticks.
    @ViewBuilder
    private var closedDial: some View {
        let label = CurvedText(text: router.section.title.uppercased(),
                               radius: closedRadius, centerAngle: anchor,
                               size: 7.5, weight: .semibold,
                               color: K.surface, tracking: 1.6)
        let band = min(max(label.sweep + 24, 56), 150)
        let gap = 18.0
        let free = 360 - band - gap * 2
        let others = sections.count - 1

        ZStack {
            Circle()
                .fill(K.surface.opacity(0.94))
                .frame(width: closedSize, height: closedSize)
                .shadow(color: K.ink.opacity(0.13), radius: 15, y: 6)
                .overlay(Circle().strokeBorder(K.border.opacity(0.85), lineWidth: 0.8)
                    .frame(width: closedSize, height: closedSize))

            Circle()
                .trim(from: 0, to: band / 360)
                .stroke(K.sageDeep, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(anchor - band / 2))
                .frame(width: closedRadius * 2, height: closedRadius * 2)
            label
            ForEach(0..<others, id: \.self) { i in
                let a = anchor + band / 2 + gap + free / Double(others - 1) * Double(i)
                Circle()
                    .fill(K.inkFaint.opacity(0.42))
                    .frame(width: 2.6, height: 2.6)
                    .offset(x: closedRadius * cos(a * .pi / 180),
                            y: closedRadius * sin(a * .pi / 180))
            }
        }
        .frame(width: closedSize, height: closedSize)
    }

    // MARK: - Open panel

    /// The dial's own circle, grown until it fills the corner of the page and no more.
    private func panel(size: CGSize, hub c: CGPoint) -> some View {
        let shape = CornerPanel(hub: c, radius: panelRadius)
        return shape
            .fill(K.surface.opacity(0.99))
            .overlay(shape.stroke(K.border, lineWidth: 0.9))
            .shadow(color: K.ink.opacity(0.15), radius: 28, x: -6, y: -6)
            .scaleEffect(router.wheelOpen ? 1 : 0.3,
                         anchor: UnitPoint(x: c.x / max(size.width, 1),
                                           y: c.y / max(size.height, 1)))
            .opacity(router.wheelOpen ? 1 : 0)
            .animation(KMotion.settle, value: router.wheelOpen)
            .allowsHitTesting(false)
    }

    // MARK: - The fan

    /// Sections, their track, and the needle pointing at the current one. Laid out
    /// with offsets inside a hub-centred box so the whole set blooms out of the hub.
    private func fan(hub c: CGPoint) -> some View {
        ZStack {
            Circle()
                .trim(from: (fanStart - 11) / 360, to: (fanEnd + 11) / 360)
                .stroke(K.border, style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .frame(width: iconRadius * 2, height: iconRadius * 2)

            needle

            ForEach(Array(sections.enumerated()), id: \.element) { i, s in
                node(section: s, index: i)
            }
            captureNode
        }
        .frame(width: panelRadius * 2, height: panelRadius * 2)
        .position(c)
        .allowsHitTesting(false)
    }

    /// A short spoke from the hub toward whatever the dial is currently on.
    private var needle: some View {
        let inner = hubRadius + 13
        let outer = iconRadius - 27
        return Capsule()
            .fill(K.sageDeep.opacity(0.42))
            .frame(width: outer - inner, height: 1.6)
            .offset(x: (inner + outer) / 2)
            .rotationEffect(.degrees(angle(for: selectedIndex)))
            .animation(KMotion.wheel, value: selectedIndex)
            .opacity(router.wheelOpen ? 1 : 0)
            .animation(KMotion.gentle, value: router.wheelOpen)
    }

    /// Icons only. Seven names will not fit on an arc this size without colliding,
    /// so the one you're on is named in the card above the fan instead.
    @ViewBuilder
    private func node(section s: KinwardSection, index i: Int) -> some View {
        let a = angle(for: i) * .pi / 180
        let selected = s == router.section

        ZStack {
            Circle()
                .fill(K.sageDeep)
                .frame(width: 44, height: 44)
                .shadow(color: K.ink.opacity(selected ? 0.24 : 0), radius: 11, y: 4)
                .opacity(selected ? 1 : 0)
            Image(systemName: s.icon)
                .font(.system(size: selected ? 18 : 17, weight: .light))
                .foregroundStyle(selected ? K.surface : K.inkSoft.opacity(0.92))
        }
        .frame(width: 44, height: 44)
        .scaleEffect(selected && detentKick ? 1.07 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.55), value: detentKick)
        .animation(KMotion.wheel, value: selected)
        .offset(x: cos(a) * iconRadius, y: sin(a) * iconRadius)
        .scaleEffect(router.wheelOpen ? 1 : 0.45)
        .opacity(router.wheelOpen ? 1 : 0)
        .animation(.spring(response: 0.44, dampingFraction: 0.8)
            .delay(Double(i) * 0.022), value: router.wheelOpen)
    }

    @ViewBuilder
    private var captureNode: some View {
        let a = captureAngle * .pi / 180
        let hot = pointing == .capture
        Group {
            ZStack {
                Circle()
                    .fill(hot ? K.gold : K.surface)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(K.goldSoft, lineWidth: 1))
                    .shadow(color: K.ink.opacity(hot ? 0.2 : 0.08), radius: 9, y: 3)
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(hot ? K.surface : K.gold)
            }
            .animation(KMotion.wheel, value: hot)
            .offset(x: cos(a) * iconRadius, y: sin(a) * iconRadius)
        }
        .scaleEffect(router.wheelOpen ? 1 : 0.45)
        .opacity(router.wheelOpen ? 1 : 0)
        .animation(.spring(response: 0.44, dampingFraction: 0.8), value: router.wheelOpen)
    }

    // MARK: - Hub

    @ViewBuilder
    private func hub(open: Bool) -> some View {
        let d = open ? hubRadius * 2 : CGFloat(54)
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [K.sageDeep, Color(hex: 0x2C322A)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: d, height: d)
                .shadow(color: K.ink.opacity(0.3), radius: 14, y: 6)
                .scaleEffect(open ? 1 : (breathe ? 1.015 : 0.985))
            if open {
                VStack(spacing: 2) {
                    Image(systemName: "house").font(.system(size: 16, weight: .light))
                    Text("HOME").font(.sans(7, .semibold)).tracking(1.6)
                }
                .foregroundStyle(K.surface.opacity(0.95))
            } else {
                Image(systemName: router.atHome ? "house" : router.section.icon)
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(K.surface.opacity(0.95))
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .frame(width: d, height: d)
        .scaleEffect(pressing || pointing == .hub ? 0.93 : 1)
        .animation(.spring(response: 0.24, dampingFraction: 0.7), value: pressing)
        .animation(.spring(response: 0.24, dampingFraction: 0.7), value: pointing)
        .animation(KMotion.settle, value: open)
        .allowsHitTesting(false)
    }

    // MARK: - Caption above the fan

    /// Names what the dial is on. It carries its own surface because the page stays
    /// visible behind the fan, and bare text over a page is unreadable.
    private func caption(hub c: CGPoint, size: CGSize) -> some View {
        let (title, meaning) = readout
        return VStack(alignment: .trailing, spacing: 2) {
            Text(pressing ? "Release to open" : "Point at one")
                .eyebrowStyle(pressing ? K.gold : K.inkFaint)
                .contentTransition(.opacity)
            Text(title)
                .font(.serif(21))
                .foregroundStyle(K.ink)
            Text(meaning)
                .font(.sans(12.5))
                .foregroundStyle(K.inkSoft)
        }
        .multilineTextAlignment(.trailing)
        .padding(.horizontal, 17)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(K.surface)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(K.border, lineWidth: 0.8))
                .shadow(color: K.ink.opacity(0.1), radius: 16, y: 6)
        )
        .fixedSize()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 22)
        .padding(.bottom, size.height - (c.y - panelRadius) + 16)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// What the card names: the hub and the keep-something node speak for themselves
    /// too, so sweeping onto either one says what it is before you commit.
    private var readout: (String, String) {
        switch pointing {
        case .hub:     ("Home", "Where you left off")
        case .capture: ("Preserve", "Keep something new")
        default:       (router.section.title, router.section.meaning)
        }
    }

    // MARK: - Press, scrub, release

    /// Touch down blooms the fan; from there the finger simply points. Whatever it is
    /// over is what lights up, and whatever it is over when it lifts is what opens —
    /// you never have to reach the node itself, only far enough in its direction. A
    /// press that never reaches anything is just a tap, and leaves the fan open.
    private func pressAndScrub(hub c: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { v in
                if !pressing {
                    engaged = false
                    pressing = true
                    pointing = nil
                    Haptics.settle()
                    openFan()
                }
                trackFinger(to: v.location, hub: c, hubIsNothing: true)
                if pointing != nil { engaged = true }
            }
            .onEnded { v in
                pressing = false
                let reached = engaged
                engaged = false
                guard reached else { pointing = nil; return }
                commit(at: v.location, hub: c, hubIsNothing: true)
            }
    }

    // MARK: - Sweeping the open fan

    private func openTouch(hub c: CGPoint) -> some View {
        Color.white.opacity(0.001)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { v in trackFinger(to: v.location, hub: c) }
                    .onEnded { v in commit(at: v.location, hub: c) }
            )
    }

    /// Light up whatever the finger is over, ticking once as it crosses onto it.
    ///
    /// A press begins on the hub, so during a press the hub has to mean *nothing
    /// chosen*: lifting without ever leaving it is simply the tap that opened the fan.
    private func trackFinger(to p: CGPoint, hub c: CGPoint, hubIsNothing: Bool = false) {
        var t = target(at: p, hub: c)
        if hubIsNothing, t == .hub { t = nil }
        guard t != pointing else { return }
        pointing = t
        switch t {
        case .section(let s) where s != router.section:
            router.section = s
            Haptics.detent()
            detentKick.toggle()
        case .hub, .capture:
            Haptics.detent()
        default:
            break
        }
    }

    /// Act on whatever the finger came up on.
    private func commit(at p: CGPoint, hub c: CGPoint, hubIsNothing: Bool = false) {
        var t = target(at: p, hub: c)
        if hubIsNothing, t == .hub { t = nil }
        pointing = nil
        switch t {
        case .hub:
            Haptics.settle()
            router.goHome()
            close(haptic: false)
        case .capture:
            Haptics.tap()
            close(haptic: false)
            onCapture()
        case .section(let s):
            select(s)
        case nil:
            close()
        }
    }

    /// What the finger is over: the hub, one wedge of the fan, or nothing.
    private func target(at p: CGPoint, hub c: CGPoint) -> FanTarget? {
        let dx = p.x - c.x, dy = p.y - c.y
        let r = hypot(dx, dy)
        if r <= hubRadius + 10 { return .hub }
        guard r >= hubRadius + 14, r <= panelRadius + 26 else { return nil }

        let a = atan2(dy, dx) * 180 / .pi
        var best: (FanTarget, Double) = (.capture, arcGap(captureAngle, a))
        for (i, s) in sections.enumerated() {
            let d = arcGap(angle(for: i), a)
            if d < best.1 { best = (.section(s), d) }
        }
        // Wedges are contiguous inside the fan, with a little slack past each end.
        guard best.1 <= fanStep * 0.75 else { return nil }
        return best.0
    }

    /// Distance between two angles in degrees, wrapped into 0...180.
    private func arcGap(_ a: Double, _ b: Double) -> Double {
        abs(((a - b).truncatingRemainder(dividingBy: 360) + 540)
            .truncatingRemainder(dividingBy: 360) - 180)
    }

    // MARK: - Opening and closing

    private func openFan() {
        sectionAtOpen = router.section
        withAnimation(KMotion.settle) { router.wheelOpen = true }
    }

    private func select(_ s: KinwardSection) {
        Haptics.settle()
        router.go(s)
        withAnimation(KMotion.settle) { router.wheelOpen = false }
    }

    /// Dismissed without choosing, so put the dial back where it was — poking around
    /// the fan shouldn't quietly move you off the page you were on.
    private func close(haptic: Bool = true) {
        if haptic { Haptics.tap() }
        if router.section != sectionAtOpen {
            withAnimation(KMotion.wheel) { router.section = sectionAtOpen }
        }
        withAnimation(KMotion.settle) { router.wheelOpen = false }
    }
}

/// The corner the fan lives in: the dial's circle grown to a quarter-round, run out
/// to the bottom and right edges so it reads as part of the screen, not a floating card.
private struct CornerPanel: Shape {
    var hub: CGPoint
    var radius: CGFloat

    /// Overshoot: this view is laid out inside the safe area, and the panel should
    /// still meet the bottom and right edges of the glass.
    private let bleed: CGFloat = 140

    func path(in rect: CGRect) -> Path {
        let maxX = rect.maxX + bleed
        let maxY = rect.maxY + bleed
        return Path { p in
            p.move(to: CGPoint(x: hub.x - radius, y: maxY))
            p.addLine(to: CGPoint(x: hub.x - radius, y: hub.y))
            p.addArc(center: hub, radius: radius,
                     startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.addLine(to: CGPoint(x: maxX, y: hub.y - radius))
            p.addLine(to: CGPoint(x: maxX, y: maxY))
            p.closeSubpath()
        }
    }
}
