import SwiftUI

/// How you get around the app.
///
/// The dial is Kinward's own thing and stays the default. Not everyone wants to
/// learn a gesture to reach their own archive, though, so the bar is a plain
/// bottom tab bar that behaves exactly the way every other app's does.
enum NavStyle: String, CaseIterable, Identifiable {
    case dial, bar

    static let storageKey = "kinward.navStyle"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dial: "The dial"
        case .bar:  "A normal tab bar"
        }
    }

    var note: String {
        switch self {
        case .dial: "Kinward's own. Press and hold the corner, then slide."
        case .bar:  "The usual row along the bottom. Nothing to learn."
        }
    }

    var icon: String {
        switch self {
        case .dial: "circle.circle"
        case .bar:  "rectangle.split.3x1"
        }
    }

    /// How much room the navigation takes out of the bottom of every scrolling page.
    /// The dial is a large corner object; the bar is a bar.
    var bottomInset: CGFloat {
        switch self {
        case .dial: 190
        case .bar:  112
        }
    }

    /// The four sections that earn a place on the bar. The rest live behind More,
    /// which is the honest way to fit seven sections into five slots.
    static let barSections: [KinwardSection] = [.memories, .letters]
    static var moreSections: [KinwardSection] {
        KinwardSection.allCases.filter { !barSections.contains($0) }
    }
}

extension EnvironmentValues {
    /// Read by every scrolling page so its last card clears whatever is down there.
    @Entry var navBottomInset: CGFloat = NavStyle.dial.bottomInset
}
