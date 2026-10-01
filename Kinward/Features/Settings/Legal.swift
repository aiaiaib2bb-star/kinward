import SwiftUI

// MARK: - Who publishes Kinward
//
// Fill these in before submitting. They are the only things the privacy policy
// and terms need that the code can't know. Until they are set, the documents
// read "the developer named on Kinward's App Store page" and point people to the
// App Store for contact, which is true but less helpful.
//
// The website pages are made from the same text — see Website/make_pages.py.

enum Publisher {
    /// Your name, or your company's, as it appears as the seller on the App Store.
    static let name: String? = nil
    /// Where people write for help. Also goes in App Store Connect as support.
    static let supportEmail: String? = nil
    /// The country whose law the terms are under, as a phrase: "Germany",
    /// "England and Wales", "the State of California".
    static let lawOf: String? = nil
    /// Where the same two documents are published. App Store Connect asks for the
    /// privacy policy's address; the terms are linked from the App Store listing.
    static let privacyPage: URL? = nil
    static let termsPage: URL? = nil
}

enum Links {
    static let manageSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!
}

// MARK: - The documents

/// The privacy policy and terms, read from Legal.json — the one copy of the text,
/// which the website pages are also built from, so the app and the site can't
/// drift apart.
enum LegalDoc: String, Identifiable, CaseIterable {
    case privacy, terms

    var id: String { rawValue }

    struct Section: Decodable, Hashable {
        let heading: String
        let paragraphs: [String]
    }

    struct Body: Decodable {
        let title: String
        let summary: [String]
        let sections: [Section]
    }

    private struct File: Decodable {
        let updated: String
        let privacy: Body
        let terms: Body
    }

    private static let file: File? = {
        guard let url = Bundle.main.url(forResource: "Legal", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }()

    static var updated: String { file?.updated ?? "" }

    var body: Body {
        let b = (self == .privacy ? Self.file?.privacy : Self.file?.terms)
            ?? Body(title: title, summary: [], sections: [])
        return Body(title: b.title,
                    summary: b.summary.map(Self.fill),
                    sections: b.sections.map { Section(heading: $0.heading, paragraphs: $0.paragraphs.map(Self.fill)) })
    }

    var title: String { self == .privacy ? "Privacy Policy" : "Terms of Use" }
    var icon: String { self == .privacy ? "hand.raised" : "doc.text" }
    var webPage: URL? { self == .privacy ? Publisher.privacyPage : Publisher.termsPage }

    /// Puts the publisher's details into the text, or an honest stand-in for each.
    private static func fill(_ s: String) -> String {
        let developer = Publisher.name ?? "the developer named on Kinward’s App Store page"
        let contact: String
        if let e = Publisher.supportEmail {
            contact = "Questions about this, or anything else? Write to [\(e)](mailto:\(e))."
        } else {
            contact = "Questions about this, or anything else? Use the support link on Kinward’s App Store page."
        }
        let law = Publisher.lawOf.map { "the laws of \($0)" }
            ?? "the laws of the country where \(developer) is established"
        return s.replacingOccurrences(of: "{developer}", with: developer)
            .replacingOccurrences(of: "{contact}", with: contact)
            .replacingOccurrences(of: "{law}", with: law)
    }
}

/// One of the documents, set as a page to read rather than a wall of small print:
/// the short version first, then the whole of it.
struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let doc: LegalDoc

    var body: some View {
        let b = doc.body
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kinward").eyebrowStyle(K.gold)
                            Text(b.title).font(.serif(32)).foregroundStyle(K.ink)
                            Text("Last updated \(LegalDoc.updated)")
                                .font(KType.caption(12.5)).foregroundStyle(K.inkFaint)
                        }

                        if !b.summary.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("In short").eyebrowStyle(K.inkFaint)
                                ForEach(b.summary, id: \.self) { line in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(K.sage)
                                        Text(line).font(KType.body(14.5)).foregroundStyle(K.ink)
                                            .lineSpacing(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardSurface()
                        }

                        ForEach(b.sections, id: \.self) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.heading).font(.serif(20)).foregroundStyle(K.ink)
                                ForEach(section.paragraphs, id: \.self) { paragraph($0) }
                            }
                        }

                        if let url = doc.webPage {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Text("Also published at \(url.host() ?? url.absoluteString)")
                                    Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .medium))
                                }
                                .font(KType.caption(13)).foregroundStyle(K.sageDeep)
                            }
                        }
                    }
                    .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .tint(K.sageDeep)
    }

    /// A paragraph, or a bullet when it starts with one. Links are Markdown, so
    /// they can be tapped.
    @ViewBuilder
    private func paragraph(_ p: String) -> some View {
        if p.hasPrefix("• ") {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Circle().fill(K.gold).frame(width: 4.5, height: 4.5).offset(y: -3)
                Text(LocalizedStringKey(String(p.dropFirst(2))))
                    .font(KType.body(15)).foregroundStyle(K.inkSoft).lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)
        } else {
            Text(LocalizedStringKey(p))
                .font(KType.body(15)).foregroundStyle(K.inkSoft).lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
