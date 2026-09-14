import SwiftUI

/// Type set along an arc — used for the section name that wraps the dial.
/// Only ever drawn on the upper half of the circle, so every glyph is rotated
/// with the clockwise tangent and reads the right way up.
struct CurvedText: View {
    let text: String
    var radius: CGFloat
    /// Where the middle of the string sits, in degrees (0 = right, clockwise positive).
    var centerAngle: Double
    var size: CGFloat = 10
    var weight: Font.Weight = .semibold
    var color: Color = .white
    var tracking: Double = 3.0

    /// Degrees each glyph occupies at this radius.
    private var perChar: Double {
        (tracking + Double(size) * 0.62) / Double(radius) * 57.2957795
    }

    var body: some View {
        let chars = Array(text)
        let total = perChar * Double(max(chars.count - 1, 0))
        let start = centerAngle - total / 2

        ZStack {
            ForEach(Array(chars.enumerated()), id: \.offset) { i, ch in
                let a = start + perChar * Double(i)
                Text(String(ch))
                    .font(.sans(size, weight))
                    .foregroundStyle(color)
                    .fixedSize()
                    .rotationEffect(.degrees(a + 90))
                    .offset(x: radius * cos(a * .pi / 180),
                            y: radius * sin(a * .pi / 180))
            }
        }
    }

    /// Total sweep the string needs, so a band can be drawn wide enough for it.
    var sweep: Double { perChar * Double(max(text.count - 1, 0)) }
}
