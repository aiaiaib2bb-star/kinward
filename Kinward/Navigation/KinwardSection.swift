import SwiftUI

enum KinwardSection: String, CaseIterable, Identifiable, Hashable {
    case memories, people, letters, lessons, guidance, documents, legacy
    var id: String { rawValue }

    var title: String {
        switch self {
        case .memories: "Memories"; case .people: "People"; case .letters: "Letters"
        case .lessons: "Lessons"; case .guidance: "Guidance"; case .documents: "Documents"
        case .legacy: "Legacy"
        }
    }
    /// The sentence the wheel is telling, one turn at a time.
    var meaning: String {
        switch self {
        case .memories: "What happened"
        case .people: "Who mattered"
        case .letters: "What I want to say"
        case .lessons: "What I learned"
        case .guidance: "What they'll need to know"
        case .documents: "What they may need"
        case .legacy: "What I leave behind"
        }
    }
    var icon: String {
        switch self {
        case .memories: "photo.on.rectangle.angled"
        case .people: "person.2"
        case .letters: "envelope"
        case .lessons: "lightbulb"
        case .guidance: "map"
        case .documents: "doc.text"
        case .legacy: "circle.hexagongrid"
        }
    }
    var marginalia: String {
        switch self {
        case .memories: "So they can still\nsee it the way you did."
        case .people: "People are\nthe true legacy."
        case .letters: "Say it now.\nNot one day."
        case .lessons: "Give them tools,\nnot just memories."
        case .guidance: "Clarity today.\nPeace tomorrow."
        case .documents: "Everything in\none quiet place."
        case .legacy: "A part of you\ncan live on."
        }
    }
    var isSensitive: Bool { self == .guidance || self == .documents }
}

/// One source of truth for where the app is, so the wheel and the content never disagree.
@MainActor
@Observable
final class Router {
    var section: KinwardSection = .memories
    var atHome: Bool = true
    var wheelOpen: Bool = false
    var showCapture: Bool = false
    var showSearch: Bool = false
    var showSettings: Bool = false
    var path = NavigationPath()

    func go(_ s: KinwardSection) {
        guard !(section == s && !atHome) else { atHome = false; return }
        path = NavigationPath()
        section = s
        atHome = false
    }
    func goHome() {
        path = NavigationPath()
        atHome = true
    }
}
