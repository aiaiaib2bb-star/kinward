import SwiftUI

// MARK: - Palette

enum K {
    // Surfaces
    static let bg          = Color(hex: 0xF5F1E8)
    static let bgDeep      = Color(hex: 0xEDE7DA)
    static let surface     = Color(hex: 0xFBF9F4)
    static let paper       = Color(hex: 0xFAF7EF)

    // Ink
    static let ink         = Color(hex: 0x252522)
    static let inkSoft     = Color(hex: 0x706E67)
    static let inkFaint    = Color(hex: 0x9A978C)

    // Accents
    static let sage        = Color(hex: 0x6D7765)
    static let sageDeep    = Color(hex: 0x3B4238)
    static let gold        = Color(hex: 0xA8946A)
    static let goldSoft    = Color(hex: 0xD8C9A6)
    static let border      = Color(hex: 0xDDD6C8)

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
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
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
    func eyebrowStyle(_ color: Color = K.inkFaint) -> some View {
        self.font(KType.eyebrow())
            .tracking(2.2)
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
                    .fill(fill)
                    .shadow(color: K.ink.opacity(0.05), radius: 14, x: 0, y: 6)
                    .shadow(color: K.ink.opacity(0.03), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(K.border.opacity(stroked ? 0.75 : 0), lineWidth: 0.7)
            )
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
            LinearGradient(colors: deep ? [K.bgDeep, K.bg] : [K.bg, K.bgDeep.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [K.goldSoft.opacity(0.22), .clear],
                           center: .init(x: 0.85, y: 0.1), startRadius: 8, endRadius: 420)
            GrainOverlay(opacity: 0.035)
        }
        .ignoresSafeArea()
    }
}

/// Deterministic film grain. Cheap, drawn once, and it stops the flats looking digital.
struct GrainOverlay: View {
    var opacity: Double = 0.04
    var body: some View {
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
        .opacity(opacity)
        .allowsHitTesting(false)
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
        Text(text)
            .font(.hand(size))
            .foregroundStyle(color)
            .rotationEffect(.degrees(-1.4))
            .lineSpacing(2)
    }
}

struct PillTag: View {
    let text: String
    var filled: Bool = false
    var body: some View {
        Text(text)
            .font(KType.label(12))
            .foregroundStyle(filled ? K.surface : K.inkSoft)
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
                    .shadow(color: K.ink.opacity(style == .primary ? 0.16 : 0.04), radius: 12, y: 5)
            )
        }
        .buttonStyle(.plain)
    }
    private var fg: Color { style == .primary ? K.surface : K.ink }
    private var bg: Color {
        switch style {
        case .primary: return K.sageDeep
        case .quiet:   return K.surface
        case .ghost:   return .clear
        }
    }
    private var strokeC: Color { style == .primary ? .clear : K.border }
}
