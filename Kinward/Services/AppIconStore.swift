import SwiftUI
import UIKit

/// The icon on the home screen. The default one is the leather relief; the rest
/// are the alternates declared in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`.
///
/// `name` is nil for the default, which is what `setAlternateIconName` expects,
/// and otherwise has to match the `.appiconset` in the catalogue exactly.
enum AppIconOption: String, CaseIterable, Identifiable {
    case `default`, pewter, marble, house, letter, hands, window
    case bust, seal, hourglass, compass, arch

    var id: String { rawValue }

    /// nil means the primary icon.
    var name: String? {
        switch self {
        case .default:   nil
        case .pewter:    "Pewter"
        case .marble:    "Marble"
        case .house:     "House"
        case .letter:    "Letter"
        case .hands:     "Hands"
        case .window:    "Window"
        case .bust:      "Bust"
        case .seal:      "Seal"
        case .hourglass: "Hourglass"
        case .compass:   "Compass"
        case .arch:      "Arch"
        }
    }

    var title: String {
        switch self {
        case .default:   "Leather"
        case .pewter:    "Pewter"
        case .marble:    "Marble"
        case .house:     "The house"
        case .letter:    "The letter"
        case .hands:     "Hands"
        case .window:    "The window"
        case .bust:      "The likeness"
        case .seal:      "The seal"
        case .hourglass: "The hourglass"
        case .compass:   "The compass"
        case .arch:      "The arch"
        }
    }

    var note: String {
        switch self {
        case .default:   "Gilt on worn leather. How Kinward comes."
        case .pewter:    "Cast in dark metal."
        case .marble:    "Gilt on pale stone."
        case .house:     "A house among the cypresses."
        case .letter:    "Sealed, and waiting."
        case .hands:     "The whole point of it."
        case .window:    "A view someone kept."
        case .bust:      "Carved to outlast the carver."
        case .seal:      "Closed by hand, opened later."
        case .hourglass: "The reason to start now."
        case .compass:   "Something to steer by."
        case .arch:      "A way through."
        }
    }

    /// The thumbnail shown in Settings. App icon assets are not addressable by
    /// name at runtime, so each option carries its own image.
    var preview: String { "iconpreview_\(rawValue)" }

    static func current(_ alternate: String?) -> AppIconOption {
        allCases.first { $0.name == alternate } ?? .default
    }
}

@MainActor
@Observable
final class AppIconStore {
    static let shared = AppIconStore()

    private(set) var selected: AppIconOption
    private(set) var failure: String?

    var isSupported: Bool { UIApplication.shared.supportsAlternateIcons }

    private init() {
        let installed = UIApplication.shared.alternateIconName
        selected = .current(installed)
        // An icon that has since been retired (Clock went this way) would otherwise
        // leave the home screen pointing at artwork the bundle no longer carries.
        if let installed, !AppIconOption.allCases.contains(where: { $0.name == installed }) {
            UIApplication.shared.setAlternateIconName(nil)
        }
    }

    func set(_ option: AppIconOption) {
        guard option != selected else { return }
        let previous = selected
        selected = option
        UIApplication.shared.setAlternateIconName(option.name) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    // iOS refused it — put the selection back where it was rather
                    // than leaving Settings disagreeing with the home screen.
                    self.selected = previous
                    self.failure = error.localizedDescription
                } else {
                    self.failure = nil
                    Haptics.kept()
                }
            }
        }
    }
}
