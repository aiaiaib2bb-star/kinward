import SwiftUI

// MARK: - Themes
//
// Two ways Kinward can look. Paper is its own: warm stock, a serif, a hand in the
// margins. Clear is the app as the platform itself would build it — system
// materials, San Francisco throughout, one tint, and it follows the phone into
// dark mode. Every colour below is read through the current theme, so the ~1,000
// places that say `K.ink` or `K.surface` change together.

enum AppTheme: String, CaseIterable, Identifiable {
    case paper, clear

    static let storageKey = "kinward.theme"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .paper: "Paper"
        case .clear: "Clear"
        }
    }

    var note: String {
        switch self {
        case .paper: "Warm stock, a serif, a hand in the margins."
        case .clear: "System-native and quiet. Follows light and dark mode."
        }
    }

    /// Paper is a light object and stays one. Clear goes wherever the phone goes.
    var scheme: ColorScheme? { self == .paper ? .light : nil }

    var palette: Palette { self == .paper ? .paper : .clear }
}

struct Palette {
    var bg, bgDeep, surface, paper: Color
    var ink, inkSoft, inkFaint: Color
    var sage, sageDeep, gold, goldSoft, border: Color
    /// Text and glyphs that sit on a filled accent.
    var onAccent: Color
    /// Shadows are always dark; tinting them with ink made them glow once ink
    /// could be white.
    var shadowInk: Color
    /// Hairline around cards. The platform does not outline grouped cards.
    var cardStroke: Double
    var grain: Bool

    static let paper = Palette(
        bg: Color(hex: 0xF5F1E8), bgDeep: Color(hex: 0xEDE7DA),
        surface: Color(hex: 0xFBF9F4), paper: Color(hex: 0xFAF7EF),
        ink: Color(hex: 0x252522), inkSoft: Color(hex: 0x706E67), inkFaint: Color(hex: 0x9A978C),
        sage: Color(hex: 0x6D7765), sageDeep: Color(hex: 0x3B4238),
        gold: Color(hex: 0xA8946A), goldSoft: Color(hex: 0xD8C9A6), border: Color(hex: 0xDDD6C8),
        onAccent: Color(hex: 0xFBF9F4),
        shadowInk: Color(hex: 0x252522),
        cardStroke: 0.75, grain: true)

    /// System semantic colours throughout, so contrast, dark mode and Increase
    /// Contrast are the platform's problem and come out right.
    static let clear = Palette(
        bg: Color(uiColor: .systemGroupedBackground),
        bgDeep: Color(uiColor: .systemGroupedBackground),
        surface: Color(uiColor: .secondarySystemGroupedBackground),
        paper: Color(uiColor: .secondarySystemGroupedBackground),
        ink: Color(uiColor: .label),
        inkSoft: Color(uiColor: .secondaryLabel),
        inkFaint: Color(uiColor: .tertiaryLabel),
        sage: Color(uiColor: .systemIndigo),
        sageDeep: Color(uiColor: .systemIndigo),
        // One tint. What Paper does with gold, Clear does with quiet grey.
        gold: Color(uiColor: .secondaryLabel),
        goldSoft: Color(uiColor: .systemIndigo),
        border: Color(uiColor: .separator),
        onAccent: .white,
        shadowInk: Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? .clear : UIColor.black.withAlphaComponent(0.55) }),
        cardStroke: 0, grain: false)
}

// MARK: - Age
//
// Kinward wears in the way a book that is actually used does. The paper warms
// toward cream, the ink settles toward sepia, the gilt loses its shine, the edges
// tan, and a few foxing marks come up where it has been handled. Use drives it,
// not the calendar: every day it is opened, and every thing kept in it. It takes
// years to show fully. Clear only warms a little, like a print left in the light.

enum Patina {
    static let enabledKey = "kinward.age.on"
    static let daysKey    = "kinward.age.days"
    static let lastDayKey = "kinward.age.lastDay"
    static let keptKey    = "kinward.age.kept"
    static let seedKey    = "kinward.age.seed"

    /// The brown that old paper goes at the edges and in its spots.
    static let tone = Color(hex: 0x8B6A3E)

    /// 0 is new, 1 is a lifetime. Each day opened counts once and each thing kept
    /// counts half, up to a point, so an afternoon of importing photographs does
    /// not add a decade. Opened most days, it is about half-way at eighteen months
    /// and nearly all the way at seven years.
    static func wear(days: Int, kept: Int) -> Double {
        let handling = Double(days) + 0.5 * Double(min(kept, 600))
        return 1 - exp(-handling / 900)
    }

    /// Roughly how long it takes to get to `age` if it is opened most days.
    static func timeToReach(_ age: Double) -> String {
        guard age > 0.01 else { return "New" }
        let days = -900 * log(1 - min(age, 0.995)) / 1.15
        switch days {
        case ..<45:  return "A few weeks"
        case ..<330: return "About \(Int((days / 30).rounded())) months"
        case ..<540: return "About a year"
        default:
            let years = Int((days / 365).rounded())
            return years >= 10 ? "Ten years and more" : "About \(years) years"
        }
    }

    static func stage(_ age: Double) -> String {
        switch age {
        case ..<0.05: "New"
        case ..<0.2:  "Settling in"
        case ..<0.45: "Worn in"
        case ..<0.7:  "Well used"
        case ..<0.9:  "Well loved"
        default:      "An heirloom"
        }
    }
}

extension Palette {
    /// Paper after a lifetime of handling. Contrast is held: the ink goes brown,
    /// not grey, and the stock darkens with it.
    static let paperWorn = Palette(
        bg: Color(hex: 0xEBDFC5), bgDeep: Color(hex: 0xE1D2B2),
        surface: Color(hex: 0xF4ECDA), paper: Color(hex: 0xF2E7CF),
        ink: Color(hex: 0x392D22), inkSoft: Color(hex: 0x76654F), inkFaint: Color(hex: 0x9E8C70),
        sage: Color(hex: 0x6E705A), sageDeep: Color(hex: 0x434233),
        gold: Color(hex: 0x958061), goldSoft: Color(hex: 0xD1BD93), border: Color(hex: 0xD3C3A2),
        onAccent: Color(hex: 0xF4ECDA),
        shadowInk: Color(hex: 0x2E241A),
        cardStroke: 0.9, grain: true)

    /// This palette `a` of the way (0…1) through its life.
    func aged(_ a: Double, clear: Bool) -> Palette {
        guard a > 0.001 else { return self }
        var p = self
        if clear {
            // Only the stock warms. Text, tint and separators stay the platform's.
            let warm = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
                ? UIColor(red: 0.27, green: 0.21, blue: 0.14, alpha: 1)
                : UIColor(red: 0.96, green: 0.92, blue: 0.84, alpha: 1) })
            let t = a * 0.45
            p.bg = bg.mix(with: warm, by: t)
            p.bgDeep = bgDeep.mix(with: warm, by: t)
            p.surface = surface.mix(with: warm, by: t * 0.55)
            p.paper = paper.mix(with: warm, by: t * 0.55)
            return p
        }
        let w = Palette.paperWorn
        p.bg = bg.mix(with: w.bg, by: a);             p.bgDeep = bgDeep.mix(with: w.bgDeep, by: a)
        p.surface = surface.mix(with: w.surface, by: a); p.paper = paper.mix(with: w.paper, by: a)
        p.ink = ink.mix(with: w.ink, by: a);           p.inkSoft = inkSoft.mix(with: w.inkSoft, by: a)
        p.inkFaint = inkFaint.mix(with: w.inkFaint, by: a)
        p.sage = sage.mix(with: w.sage, by: a);        p.sageDeep = sageDeep.mix(with: w.sageDeep, by: a)
        p.gold = gold.mix(with: w.gold, by: a);        p.goldSoft = goldSoft.mix(with: w.goldSoft, by: a)
        p.border = border.mix(with: w.border, by: a);  p.onAccent = onAccent.mix(with: w.onAccent, by: a)
        p.shadowInk = shadowInk.mix(with: w.shadowInk, by: a)
        p.cardStroke = cardStroke + (w.cardStroke - cardStroke) * a
        return p
    }
}

/// The one mutable piece of the look. Observable, so any view that reads a colour
/// redraws when it changes — no view has to know a theme exists.
@Observable
final class ThemeStore {
    nonisolated(unsafe) static let shared = ThemeStore()

    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: AppTheme.storageKey); refresh() }
    }

    /// Whether the app shows its age. Use is counted either way, so turning it
    /// back on brings the years back rather than starting over.
    var ages: Bool {
        didSet { UserDefaults.standard.set(ages, forKey: Patina.enabledKey); refresh() }
    }

    /// Settings can show the app further along than it is. Never stored.
    var lookAhead: Double? { didSet { refresh() } }

    private(set) var daysOpened: Int
    private(set) var kept: Int
    /// How worn in this copy really is, from use alone.
    private(set) var wear: Double
    /// What is drawn: the look-ahead if there is one, otherwise the real wear.
    private(set) var age: Double = 0
    /// The theme's palette at `age`, worked out once rather than per colour read.
    private(set) var palette: Palette = .paper
    /// Where the marks fall. Each copy has its own, so no two age alike.
    let seed: UInt64

    private init() {
        let d = UserDefaults.standard
        theme = AppTheme(rawValue: d.string(forKey: AppTheme.storageKey) ?? "") ?? .paper
        ages = d.object(forKey: Patina.enabledKey) as? Bool ?? true
        let days = d.integer(forKey: Patina.daysKey), count = d.integer(forKey: Patina.keptKey)
        daysOpened = days
        kept = count
        wear = Patina.wear(days: days, kept: count)
        if let s = d.object(forKey: Patina.seedKey) as? Int {
            seed = UInt64(bitPattern: Int64(s))
        } else {
            let s = Int.random(in: .min ... .max)
            d.set(s, forKey: Patina.seedKey)
            seed = UInt64(bitPattern: Int64(s))
        }
        refresh()
    }

    func palette(for t: AppTheme) -> Palette { t.palette.aged(age, clear: t == .clear) }

    /// Called whenever the app comes to the front. The first time on a given day
    /// adds a day; `kept` is how many things the archive holds right now.
    func noteUse(kept count: Int) {
        let d = UserDefaults.standard
        let c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        let today = "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
        if d.string(forKey: Patina.lastDayKey) != today {
            d.set(today, forKey: Patina.lastDayKey)
            daysOpened += 1
            d.set(daysOpened, forKey: Patina.daysKey)
        }
        if count != kept { kept = count; d.set(count, forKey: Patina.keptKey) }
        let w = Patina.wear(days: daysOpened, kept: kept)
        if abs(w - wear) > 0.0001 { wear = w; refresh() }
    }

    private func refresh() {
        let a = lookAhead ?? (ages ? wear : 0)
        if a != age { age = a }
        palette = palette(for: theme)
    }
}

enum K {
    private static var p: Palette { ThemeStore.shared.palette }
    static var isClear: Bool { ThemeStore.shared.theme == .clear }
    /// How far along the look is, 0 (new) to 1 (a lifetime).
    static var age: Double { ThemeStore.shared.age }

    // Surfaces
    static var bg: Color       { p.bg }
    static var bgDeep: Color   { p.bgDeep }
    static var surface: Color  { p.surface }
    static var paper: Color    { p.paper }

    // Ink
    static var ink: Color      { p.ink }
    static var inkSoft: Color  { p.inkSoft }
    static var inkFaint: Color { p.inkFaint }

    // Accents
    static var sage: Color     { p.sage }
    static var sageDeep: Color { p.sageDeep }
    static var gold: Color     { p.gold }
    static var goldSoft: Color { p.goldSoft }
    static var border: Color   { p.border }
    static var onAccent: Color { p.onAccent }
    static var shadowInk: Color { p.shadowInk }

    // Night (used for the cinematic closing moments)
    static let night       = Color(hex: 0x121617)
    static let nightSoft   = Color(hex: 0x1E2528)

    // Radii
    static let rSmall: CGFloat = 14
    static let rCard: CGFloat = 22
    static let rLarge: CGFloat = 28
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

// MARK: - Typography
// Headlines: high-contrast serif (New York). Body: SF. Accent: a warm hand.

extension Font {
    /// The display face. Paper sets it in New York; Clear sets it in San Francisco
    /// and lets size decide the weight, the way the system's own large titles,
    /// titles and headlines step down from bold to regular.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        guard K.isClear else { return .system(size: size, weight: weight, design: .serif) }
        let bySize: Font.Weight = size >= 24 ? .bold : size >= 19 ? .semibold : size >= 15.5 ? .medium : .regular
        return .system(size: size, weight: heavier(bySize, weight), design: .default)
    }
    /// A serif regardless of theme — for the places where the serif is the content,
    /// like a letter someone chose to write in Classic.
    static func bookSerif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    private static func heavier(_ a: Font.Weight, _ b: Font.Weight) -> Font.Weight {
        let order: [Font.Weight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        return (order.firstIndex(of: a) ?? 3) >= (order.firstIndex(of: b) ?? 3) ? a : b
    }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    /// A believable hand. Falls back to a serif italic if the face is missing.
    static func hand(_ size: CGFloat) -> Font {
        .custom("Bradley Hand", size: size)
    }
    static func handAlt(_ size: CGFloat) -> Font {
        .custom("Noteworthy-Light", size: size)
    }
}

enum KType {
    static func display(_ s: CGFloat = 40) -> Font { .serif(s, .regular) }
    static func title(_ s: CGFloat = 30) -> Font { .serif(s, .regular) }
    static func headline(_ s: CGFloat = 20) -> Font { .serif(s, .medium) }
    static func body(_ s: CGFloat = 16) -> Font { .sans(s, .regular) }
    static func label(_ s: CGFloat = 13) -> Font { .sans(s, .medium) }
    static func caption(_ s: CGFloat = 12) -> Font { .sans(s, .regular) }
    /// Wide-tracked small caps used for section eyebrows.
    static func eyebrow(_ s: CGFloat = 11) -> Font { .sans(s, .semibold) }
}

extension View {
    /// Section labels. Paper spaces them wide like a printed running head; Clear
    /// uses the grouped-list header the system draws above every settings table.
    func eyebrowStyle(_ color: Color = K.inkFaint) -> some View {
        self.font(K.isClear ? .system(size: 13, weight: .semibold) : KType.eyebrow())
            .tracking(K.isClear ? 0.2 : 2.2)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

// MARK: - Motion
// Slow, subtle, meaningful. Nothing snaps unless a finger let go of it.

enum KMotion {
    static let calm     = Animation.timingCurve(0.22, 0.9, 0.2, 1.0, duration: 0.62)
    static let gentle   = Animation.timingCurve(0.25, 0.8, 0.25, 1.0, duration: 0.44)
    static let settle   = Animation.spring(response: 0.52, dampingFraction: 0.82)
    static let wheel    = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let breath   = Animation.easeInOut(duration: 5.2)
    /// How things enter: a long ease-out that decelerates into place and stops.
    /// No spring, so nothing overshoots its mark and settles back.
    static let arrive   = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 1.5)
}

// MARK: - Surfaces

struct CardSurface: ViewModifier {
    var radius: CGFloat = K.rCard
    var fill: Color = K.surface
    var stroked: Bool = true
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(stock)
                    .shadow(color: K.shadowInk.opacity(K.isClear ? 0.035 : 0.05), radius: 14, x: 0, y: 6)
                    .shadow(color: K.shadowInk.opacity(K.isClear ? 0.02 : 0.03), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(K.border.opacity(stroked ? ThemeStore.shared.palette.cardStroke : 0),
                                  lineWidth: 0.7)
            )
    }

    /// With age, a card tans in from its edges the way a page does.
    private var stock: AnyShapeStyle {
        guard !K.isClear, K.age > 0.02 else { return AnyShapeStyle(fill) }
        return AnyShapeStyle(fill.shadow(.inner(color: Patina.tone.opacity(0.24 * K.age), radius: 10)))
    }
}

extension View {
    func cardSurface(radius: CGFloat = K.rCard, fill: Color = K.surface, stroked: Bool = true) -> some View {
        modifier(CardSurface(radius: radius, fill: fill, stroked: stroked))
    }
}

/// The warm paper the whole app sits on, with a whisper of grain.
struct PaperBackground: View {
    var deep: Bool = false
    var body: some View {
        ZStack {
            if K.isClear {
                K.bg
            } else {
                LinearGradient(colors: deep ? [K.bgDeep, K.bg] : [K.bg, K.bgDeep.opacity(0.85)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [K.goldSoft.opacity(0.22), .clear],
                               center: .init(x: 0.85, y: 0.1), startRadius: 8, endRadius: 420)
                GrainOverlay(opacity: 0.035)
                AgeMarks(age: K.age)
            }
        }
        .ignoresSafeArea()
    }
}

/// Deterministic film grain. Cheap, drawn once, and it stops the flats looking digital.
struct GrainOverlay: View {
    var opacity: Double = 0.04
    var body: some View {
        if ThemeStore.shared.palette.grain { grain }
    }
    private var grain: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 0x5EED_1234
            func rnd() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double((seed >> 33) & 0xFFFF) / 65535.0
            }
            let count = Int(size.width * size.height / 900)
            for _ in 0..<count {
                let x = rnd() * size.width
                let y = rnd() * size.height
                let a = rnd()
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.1, height: 1.1)),
                         with: .color(.black.opacity(a * 0.5)))
            }
        }
        .blendMode(.multiply)
        // Old stock has more tooth to it.
        .opacity(opacity * (1 + 1.4 * K.age))
        .allowsHitTesting(false)
    }
}

/// What a page picks up over years of being handled. The edges tan first, a
/// little more along the bottom where it is held; then foxing comes up, a spot at
/// a time, each at its own point in the app's life. Where they fall comes from
/// this copy's seed, so no two copies age alike. Paper only.
struct AgeMarks: View, Animatable {
    var age: Double
    /// Varies the pattern between surfaces that share a seed.
    var salt: UInt64 = 0
    var edges: Bool = true

    nonisolated var animatableData: Double {
        get { age }
        set { age = newValue }
    }

    var body: some View {
        let a = age, edges = edges
        let seed0 = (ThemeStore.shared.seed ^ (salt &* 0x9E37_79B9_7F4A_7C15)) | 1
        Canvas { ctx, size in
            guard a > 0.004 else { return }
            let tone = Patina.tone
            var seed = seed0
            func rnd() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double((seed >> 33) & 0xFFFF) / 65535.0
            }
            let w = size.width, h = size.height

            if edges {
                let band = min(w, h) * 0.17
                func edge(_ rect: CGRect, from: CGPoint, to: CGPoint, _ k: Double) {
                    ctx.fill(Path(rect), with: .linearGradient(
                        Gradient(colors: [tone.opacity(k * a), tone.opacity(0)]),
                        startPoint: from, endPoint: to))
                }
                edge(CGRect(x: 0, y: 0, width: w, height: band),
                     from: .init(x: 0, y: 0), to: .init(x: 0, y: band), 0.14)
                edge(CGRect(x: 0, y: h - band * 1.4, width: w, height: band * 1.4),
                     from: .init(x: 0, y: h), to: .init(x: 0, y: h - band * 1.4), 0.19)
                edge(CGRect(x: 0, y: 0, width: band, height: h),
                     from: .init(x: 0, y: 0), to: .init(x: band, y: 0), 0.13)
                edge(CGRect(x: w - band, y: 0, width: band, height: h),
                     from: .init(x: w, y: 0), to: .init(x: w - band, y: 0), 0.13)
            }

            // Foxing: soft rust-brown spots, most of them near an edge. Every random
            // number for a spot is drawn before deciding whether it shows yet, so a
            // spot keeps its place as the app ages instead of reshuffling.
            let spots = max(6, Int(w * h / 13_000))
            for _ in 0..<spots {
                var x = rnd() * w, y = rnd() * h
                if rnd() < 0.65 {
                    let d = pow(rnd(), 2) * 0.2
                    switch Int(rnd() * 4) {
                    case 0:  x = d * w
                    case 1:  x = w - d * w
                    case 2:  y = d * h
                    default: y = h - d * h
                    }
                }
                let r = 2.5 + pow(rnd(), 3) * 15
                let appearsAt = 0.05 + rnd() * 0.85
                let strength = 0.06 + rnd() * 0.07
                let angle = rnd() * .pi * 2
                let v = min(max((a - appearsAt) / 0.22, 0), 1)
                guard v > 0 else { continue }
                let o = strength * v
                func blot(_ c: CGPoint, _ r: Double, _ o: Double) {
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(Gradient(stops: [
                                .init(color: tone.opacity(o), location: 0),
                                .init(color: tone.opacity(o * 0.6), location: 0.4),
                                .init(color: tone.opacity(0), location: 1)]),
                                center: c, startRadius: 0, endRadius: r))
                }
                blot(CGPoint(x: x, y: y), r, o)
                // A smaller one run into it, so it isn't a perfect circle.
                blot(CGPoint(x: x + cos(angle) * r * 0.55, y: y + sin(angle) * r * 0.55), r * 0.6, o * 0.8)
            }

            // Specks: the dust that settles into old stock.
            let specks = Int(w * h / 4_500)
            for _ in 0..<specks {
                let x = rnd() * w, y = rnd() * h
                let s = 0.6 + rnd() * 1.1
                let appearsAt = rnd() * 0.9
                let strength = 0.12 + rnd() * 0.2
                let v = min(max((a - appearsAt) / 0.2, 0), 1)
                guard v > 0 else { continue }
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                         with: .color(Color(hex: 0x5A4028).opacity(strength * v)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Small shared pieces

struct HairLine: View {
    var body: some View { Rectangle().fill(K.border).frame(height: 0.7) }
}

/// Handwritten marginalia, the way the design sheet uses it.
struct Marginalia: View {
    let text: String
    var size: CGFloat = 17
    var color: Color = K.inkSoft
    var body: some View {
        if K.isClear {
            // The platform has no handwriting in its chrome. The thought stays; the
            // hand becomes a footnote.
            Text(text.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: size * 0.8))
                .foregroundStyle(color.opacity(0.9))
                .lineSpacing(2)
        } else {
            Text(text)
                .font(.hand(size))
                .foregroundStyle(color)
                .rotationEffect(.degrees(-1.4))
                .lineSpacing(2)
        }
    }
}

struct PillTag: View {
    let text: String
    var filled: Bool = false
    var body: some View {
        Text(text)
            .font(KType.label(12))
            .foregroundStyle(filled ? K.onAccent : K.inkSoft)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(
                Capsule().fill(filled ? K.sageDeep : K.surface)
                    .overlay(Capsule().strokeBorder(K.border, lineWidth: filled ? 0 : 0.7))
            )
    }
}

struct KButton: View {
    let title: String
    var icon: String? = nil
    var style: Style = .primary
    var action: () -> Void
    enum Style { case primary, quiet, ghost }

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack(spacing: 9) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .regular)) }
                Text(title).font(KType.body(16)).tracking(0.2)
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 26).padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(bg)
                    .overlay(Capsule().strokeBorder(strokeC, lineWidth: 0.8))
                    .shadow(color: K.shadowInk.opacity(style == .primary ? 0.16 : 0.04), radius: 12, y: 5)
            )
        }
        .buttonStyle(.plain)
    }
    private var fg: Color { style == .primary ? K.onAccent : K.ink }
    private var bg: Color {
        switch style {
        case .primary: return K.sageDeep
        case .quiet:   return K.surface
        case .ghost:   return .clear
        }
    }
    private var strokeC: Color { style == .primary ? .clear : K.border }
}

// MARK: - The face a letter is written in
// A letter is the one place in Kinward where the typeface is the writer's choice,
// so it lives in Settings rather than being decided for them. Stored in
// UserDefaults rather than on the profile: it is a way of looking at the words,
// not a thing anyone is trying to keep.

enum LetterFace: String, CaseIterable, Identifiable {
    case hand, classic, plain

    static let storageKey = "kinward.letterFace"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hand:    "Handwritten"
        case .classic: "Classic"
        case .plain:   "Plain"
        }
    }

    var note: String {
        switch self {
        case .hand:    "Your own hand, the way a letter is usually written."
        case .classic: "Printed serif, like a page out of a book."
        case .plain:   "Clean and plain. The easiest to read aloud from."
        }
    }

    var icon: String {
        switch self {
        case .hand: "signature"; case .classic: "book.closed"; case .plain: "textformat"
        }
    }

    /// `size` is quoted in handwriting points; the printed faces carry more ink at
    /// the same nominal size, so they are stepped down to sit on the same line.
    func font(_ size: CGFloat) -> Font {
        switch self {
        case .hand:    .hand(size)
        case .classic: .bookSerif(size * 0.88)
        case .plain:   .sans(size * 0.84)
        }
    }

    /// Handwriting needs the extra air between lines; print does not.
    func lineSpacing(_ base: CGFloat) -> CGFloat {
        self == .hand ? base : base * 0.62
    }
}
