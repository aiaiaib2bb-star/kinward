import CoreText
import Foundation
import SwiftData
import UIKit

/// Gathers everything one person is allowed to see and writes it out as a parcel you
/// can hand over: a typeset PDF of the writing, the voice as playable files, the
/// photographs, and any documents, zipped into one thing.
///
/// Nothing in here sends anything. It produces a file and stops — where it goes is
/// the share sheet's business, and the user's.
enum LegacyExport {

    /// The ten areas access is granted in. The last five carry the kind of thing you
    /// would only hand to someone you'd trust with the originals.
    static let areas = ["Memories", "Letters", "Voice", "Family history", "Lessons",
                        "Guidance", "Financial", "Documents", "Digital life", "Property"]
    static let sensitiveAreas: Set<String> = ["Guidance", "Financial", "Documents",
                                              "Digital life", "Property"]

    // MARK: - What a parcel is
    //
    // Plain values. Reading the archive happens on the main actor next to SwiftData;
    // typesetting and zipping it happens off the main actor, and only values cross.

    struct Piece: Sendable {
        var title: String
        var meta: String = ""
        var body: String = ""
        var photos: [String] = []
        var audio: [String] = []
        var files: [String] = []
    }

    struct Section: Sendable {
        var name: String
        var note: String
        var pieces: [Piece]
    }

    struct Parcel: Sendable {
        var fromName: String
        var toName: String
        var opening: String
        var sections: [Section]
        /// Letters this person is meant to open on a condition, deliberately held back.
        var sealedHeld: Int
        var everything: Bool

        var filled: [Section] { sections.filter { !$0.pieces.isEmpty } }
        var isEmpty: Bool { filled.isEmpty }
        var pieceCount: Int { filled.reduce(0) { $0 + $1.pieces.count } }
        var photoRefs: [String] { filled.flatMap(\.pieces).flatMap(\.photos) }
        var audioRefs: [String] { filled.flatMap(\.pieces).flatMap(\.audio) }
        var fileRefs: [String] { filled.flatMap(\.pieces).flatMap(\.files) }
        var includesSensitive: Bool { filled.contains { sensitiveAreas.contains($0.name) } }
        var folderName: String { "Kinward for \(toName.isEmpty ? "you" : toName)" }
    }

    // MARK: - Reading the archive

    /// Everything `person` is allowed to see, or the whole archive when `everything`.
    @MainActor
    static func parcel(for person: Person, everything: Bool,
                       from profile: UserProfile?, in ctx: ModelContext) -> Parcel {
        let granted = everything ? Set(areas) : Set(person.accessGranted)
        func all<T: PersistentModel>(_ type: T.Type) -> [T] {
            (try? ctx.fetch(FetchDescriptor<T>())) ?? []
        }
        func joined(_ parts: String?...) -> String {
            parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        }

        var sections: [Section] = []
        var sealedHeld = 0

        if granted.contains("Memories") {
            let items = all(MemoryEntry.self)
                .filter { !$0.isDraft }
                .sorted { ($0.displayYear ?? 0, $0.createdAt) < ($1.displayYear ?? 0, $1.createdAt) }
            sections.append(Section(name: "Memories",
                                    note: "What happened, and the story behind it.",
                                    pieces: items.map { m in
                var body = m.story
                if !m.whyItMatters.isEmpty {
                    body += (body.isEmpty ? "" : "\n\n") + "Why it matters — " + m.whyItMatters
                }
                return Piece(title: m.title.isEmpty ? "A memory" : m.title,
                             meta: joined(m.displayYear.map(String.init), m.place),
                             body: body,
                             photos: m.photoRefs,
                             audio: [m.audioRef].compactMap { $0 })
            }))
        }

        if granted.contains("Letters") {
            let mine = all(Letter.self).filter { $0.recipient?.id == person.id && !$0.isDraft }
            // A sealed letter is one they're meant to open on a condition. Sending it
            // now would undo the only instruction the writer left about it.
            sealedHeld = mine.filter(\.isSealed).count
            sections.append(Section(name: "Letters",
                                    note: "Words meant for you, in their own hand.",
                                    pieces: mine.filter { !$0.isSealed }.map { l in
                var body = l.salutation
                if !l.body.isEmpty { body += (body.isEmpty ? "" : "\n\n") + l.body }
                if !l.signature.isEmpty { body += "\n\n" + l.signature }
                return Piece(title: l.title.isEmpty ? "A letter" : l.title,
                             meta: l.createdAt.formatted(date: .long, time: .omitted),
                             body: body,
                             photos: l.photoRefs,
                             audio: [l.audioRef].compactMap { $0 })
            }))
        }

        if granted.contains("Voice") {
            // Recordings kept for somebody else stay with them.
            let recs = all(VoiceRecording.self)
                .filter { $0.person == nil || $0.person?.id == person.id }
                .sorted { $0.createdAt < $1.createdAt }
            sections.append(Section(name: "Voice",
                                    note: "The one thing a transcript can't replace.",
                                    pieces: recs.map { r in
                Piece(title: r.title.isEmpty ? "A recording" : r.title,
                      meta: joined(r.durationText, r.createdAt.formatted(date: .long, time: .omitted)),
                      body: joined2(r.note, r.transcript),
                      audio: [r.fileRef].filter { !$0.isEmpty })
            }))
        }

        if granted.contains("Family history") {
            let stories = all(FamilyStory.self).sorted { $0.createdAt < $1.createdAt }
            sections.append(Section(name: "Family history",
                                    note: "The people who came before, and what came with them.",
                                    pieces: stories.map { s in
                Piece(title: s.title.isEmpty ? s.subject : s.title,
                      meta: joined(s.subject, s.generation, s.years, s.origin),
                      body: s.body,
                      photos: s.photoRefs,
                      audio: [s.audioRef].compactMap { $0 })
            }))
        }

        if granted.contains("Lessons") {
            let lessons = all(Lesson.self).sorted { $0.createdAt < $1.createdAt }
            sections.append(Section(name: "Lessons",
                                    note: "The part of a life that can actually be passed on.",
                                    pieces: lessons.map { l in
                Piece(title: l.headline.isEmpty ? l.category.title : l.headline,
                      meta: l.category.title,
                      body: joined2(l.prompt, l.body),
                      audio: [l.audioRef].compactMap { $0 })
            }))
        }

        // Guidance splits along the same lines permission does.
        let notes = all(GuidanceNote.self).sorted { $0.createdAt < $1.createdAt }
        func guidance(_ name: String, _ note: String, _ match: (GuidanceCategory) -> Bool) {
            guard granted.contains(name) else { return }
            sections.append(Section(name: name, note: note,
                                    pieces: notes.filter { match($0.category) }.map { n in
                Piece(title: n.title.isEmpty ? n.category.title : n.title,
                      meta: joined(n.category.title, n.whereToFind.isEmpty ? nil : "Where to find it: \(n.whereToFind)"),
                      body: joined2(n.detail, joined(n.contactName, n.contactPhone)))
            }))
        }
        guidance("Guidance", "What they'll need to know.") { !$0.isSensitive }
        guidance("Financial", "Money, policies, and who to call.") { $0 == .financial || $0 == .insurance }
        guidance("Property", "Where things are, and who holds the keys.") { $0 == .property }
        guidance("Digital life", "Accounts, and what should happen to them.") { $0 == .digital }

        if granted.contains("Guidance") {
            let left = all(Belonging.self).filter { $0.heir?.id == person.id }
            if !left.isEmpty {
                sections.append(Section(name: "Belongings",
                                        note: "Objects meant for you, and why.",
                                        pieces: left.map { b in
                    Piece(title: b.name.isEmpty ? "A belonging" : b.name,
                          meta: b.location,
                          body: joined2(b.detail, b.story),
                          photos: b.photoRefs)
                }))
            }
        }

        if granted.contains("Documents") {
            let docs = all(DocumentItem.self).sorted { $0.createdAt < $1.createdAt }
            sections.append(Section(name: "Documents",
                                    note: "Everything in one quiet place.",
                                    pieces: docs.map { d in
                Piece(title: d.title.isEmpty ? d.category.title : d.title,
                      meta: joined(d.category.title, d.whereToFind.isEmpty ? nil : "Where to find it: \(d.whereToFind)"),
                      body: d.note,
                      files: d.fileRefs)
            }))
        }

        let from = [profile?.firstName ?? "", profile?.lastName ?? ""]
            .filter { !$0.isEmpty }.joined(separator: " ")
        return Parcel(fromName: from,
                      toName: person.name,
                      opening: person.capsule?.openingMessage ?? "",
                      sections: sections,
                      sealedHeld: sealedHeld,
                      everything: everything)
    }

    private static func joined2(_ a: String, _ b: String) -> String {
        [a, b].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    // MARK: - Writing it out

    /// Builds the folder, typesets the PDF, copies the media in, and zips the lot.
    /// Returns the zip, ready for the share sheet. Safe to call off the main actor.
    static func write(_ parcel: Parcel) throws -> URL {
        let fm = FileManager.default
        let stage = fm.temporaryDirectory.appendingPathComponent("kinward-export-\(UUID().uuidString)")
        let folder = stage.appendingPathComponent(parcel.folderName, isDirectory: true)
        try? fm.removeItem(at: stage)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        // The zip is what gets handed on; the loose copy underneath it is scratch, and
        // scratch holding somebody's whole archive shouldn't outlive the call.
        defer { try? fm.removeItem(at: stage) }

        try renderPDF(parcel, to: folder.appendingPathComponent("\(parcel.folderName).pdf"))
        let voice = try copy(parcel.audioRefs, into: folder, named: "Voice")
        let photos = try copy(parcel.photoRefs, into: folder, named: "Photos")
        let docs = try copy(parcel.fileRefs, into: folder, named: "Documents")
        try readme(parcel, voice: voice, photos: photos, documents: docs)
            .write(to: folder.appendingPathComponent("Open me first.txt"),
                   atomically: true, encoding: .utf8)

        return try zip(folder)
    }

    /// Media lives under one flat store keyed by reference; give the copies names a
    /// human can read. Returns how many actually existed.
    private static func copy(_ refs: [String], into folder: URL, named sub: String) throws -> Int {
        let fm = FileManager.default
        let present = refs.filter { !$0.isEmpty && fm.fileExists(atPath: MediaStore.url(for: $0).path) }
        guard !present.isEmpty else { return 0 }
        let dir = folder.appendingPathComponent(sub, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for (i, ref) in present.enumerated() {
            let ext = (ref as NSString).pathExtension
            let name = String(format: "%@ %02d.%@", sub, i + 1, ext.isEmpty ? "dat" : ext)
            try? fm.copyItem(at: MediaStore.url(for: ref), to: dir.appendingPathComponent(name))
        }
        return present.count
    }

    private static func readme(_ p: Parcel, voice: Int, photos: Int, documents: Int) -> String {
        var lines = [
            "Kinward",
            "",
            p.fromName.isEmpty ? "This was prepared for \(p.toName)."
                               : "\(p.fromName) prepared this for \(p.toName).",
            "Made on \(Date.now.formatted(date: .long, time: .omitted)).",
            "",
            "What's inside",
            "  \(p.folderName).pdf — everything written down, in one piece.",
        ]
        if voice > 0 { lines.append("  Voice — \(voice) recording\(voice == 1 ? "" : "s"), as .m4a files any phone or computer can play.") }
        if photos > 0 { lines.append("  Photos — \(photos) photograph\(photos == 1 ? "" : "s").") }
        if documents > 0 { lines.append("  Documents — \(documents) file\(documents == 1 ? "" : "s").") }
        lines.append("")
        lines.append("Sections included: " + p.filled.map(\.name).joined(separator: ", ") + ".")
        if p.sealedHeld > 0 {
            lines.append("")
            lines.append("\(p.sealedHeld) sealed letter\(p.sealedHeld == 1 ? " is" : "s are") not in here. "
                         + "Those were written to be opened at a particular moment, and that was the point of them.")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - The book

    private static let pageSize = CGSize(width: 595, height: 842)
    private static let margin = UIEdgeInsets(top: 88, left: 66, bottom: 80, right: 66)

    private static func renderPDF(_ parcel: Parcel, to url: URL) throws {
        let page = CGRect(origin: .zero, size: pageSize)
        let textRect = CGRect(x: margin.left, y: margin.top,
                              width: page.width - margin.left - margin.right,
                              height: page.height - margin.top - margin.bottom)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: parcel.folderName,
            kCGPDFContextAuthor as String: parcel.fromName.isEmpty ? "Kinward" : parcel.fromName
        ]

        let body = attributedBody(parcel)
        let setter = CTFramesetterCreateWithAttributedString(body)

        try UIGraphicsPDFRenderer(bounds: page, format: format).writePDF(to: url) { ctx in
            ctx.beginPage()
            drawCover(parcel, in: page)

            var cursor = 0
            while cursor < body.length {
                ctx.beginPage()
                let cg = ctx.cgContext
                cg.saveGState()
                cg.textMatrix = .identity
                // Core Text measures from the bottom-left; PDF pages here don't.
                cg.translateBy(x: 0, y: page.height)
                cg.scaleBy(x: 1, y: -1)
                let column = CGPath(rect: CGRect(x: textRect.minX,
                                                 y: page.height - textRect.maxY,
                                                 width: textRect.width,
                                                 height: textRect.height), transform: nil)
                let frame = CTFramesetterCreateFrame(setter, CFRange(location: cursor, length: 0), column, nil)
                CTFrameDraw(frame, cg)
                let shown = CTFrameGetVisibleStringRange(frame).length
                cg.restoreGState()
                // A page that fits nothing would loop forever; stop instead.
                guard shown > 0 else { break }
                cursor += shown
            }

            let plates = parcel.photoRefs.filter { MediaStore.exists($0) }
            for pair in stride(from: 0, to: plates.count, by: 2) {
                ctx.beginPage()
                drawPlates(Array(plates[pair..<min(pair + 2, plates.count)]), in: page)
            }
        }
    }

    private static func attributedBody(_ parcel: Parcel) -> NSAttributedString {
        let out = NSMutableAttributedString()
        for section in parcel.filled {
            out.append(NSAttributedString(string: section.name.uppercased() + "\n",
                                          attributes: style(.sectionName)))
            out.append(NSAttributedString(string: section.note + "\n\n", attributes: style(.sectionNote)))
            for piece in section.pieces {
                out.append(NSAttributedString(string: piece.title + "\n", attributes: style(.pieceTitle)))
                if !piece.meta.isEmpty {
                    out.append(NSAttributedString(string: piece.meta.uppercased() + "\n", attributes: style(.meta)))
                }
                if !piece.body.isEmpty {
                    out.append(NSAttributedString(string: piece.body + "\n", attributes: style(.body)))
                }
                var held: [String] = []
                if !piece.audio.isEmpty { held.append("\(piece.audio.count) recording\(piece.audio.count == 1 ? "" : "s") in the Voice folder") }
                if !piece.photos.isEmpty { held.append("\(piece.photos.count) photograph\(piece.photos.count == 1 ? "" : "s")") }
                if !piece.files.isEmpty { held.append("\(piece.files.count) file\(piece.files.count == 1 ? "" : "s") in the Documents folder") }
                if !held.isEmpty {
                    out.append(NSAttributedString(string: held.joined(separator: " · ") + "\n", attributes: style(.aside)))
                }
                out.append(NSAttributedString(string: "\n", attributes: style(.body)))
            }
            out.append(NSAttributedString(string: "\n", attributes: style(.body)))
        }
        return out
    }

    private static func drawCover(_ parcel: Parcel, in page: CGRect) {
        let x = margin.left
        let w = page.width - margin.left - margin.right
        var y = page.height * 0.30

        func put(_ text: String, _ kind: Style, gapAfter: CGFloat) {
            guard !text.isEmpty else { return }
            let s = NSAttributedString(string: text, attributes: style(kind))
            let h = s.boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude),
                                   options: [.usesLineFragmentOrigin, .usesFontLeading],
                                   context: nil).height
            s.draw(with: CGRect(x: x, y: y, width: w, height: h),
                   options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            y += h + gapAfter
        }

        put("KINWARD", .meta, gapAfter: 26)
        put(parcel.toName.isEmpty ? "For you" : "For \(parcel.toName)", .coverTitle, gapAfter: 18)
        if !parcel.fromName.isEmpty { put("From \(parcel.fromName)", .sectionNote, gapAfter: 8) }
        put(Date.now.formatted(date: .long, time: .omitted), .sectionNote, gapAfter: 34)
        put(parcel.opening, .coverNote, gapAfter: 0)

        let foot = parcel.everything
            ? "Everything kept in Kinward."
            : "Everything you were given access to: " + parcel.filled.map(\.name).joined(separator: ", ") + "."
        let s = NSAttributedString(string: foot, attributes: style(.aside))
        s.draw(with: CGRect(x: x, y: page.height - margin.bottom - 40, width: w, height: 40),
               options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    private static func drawPlates(_ refs: [String], in page: CGRect) {
        let w = page.width - margin.left - margin.right
        let slot = (page.height - margin.top - margin.bottom - 26) / CGFloat(max(refs.count, 1))
        for (i, ref) in refs.enumerated() {
            guard let image = MediaStore.image(ref) else { continue }
            let box = CGRect(x: margin.left, y: margin.top + CGFloat(i) * (slot + 26), width: w, height: slot)
            let scale = min(box.width / image.size.width, box.height / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2,
                                  width: size.width, height: size.height))
        }
    }

    // MARK: - Type

    private enum Style { case coverTitle, coverNote, sectionName, sectionNote, pieceTitle, meta, body, aside }

    private static func style(_ kind: Style) -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        switch kind {
        case .coverTitle:
            p.lineSpacing = 2
            return [.font: serif(34), .foregroundColor: ink(0x252522), .paragraphStyle: p]
        case .coverNote:
            p.lineSpacing = 6
            return [.font: serif(13), .foregroundColor: ink(0x706E67), .paragraphStyle: p]
        case .sectionName:
            p.lineSpacing = 2
            p.paragraphSpacingBefore = 26
            return [.font: sans(11, .semibold), .foregroundColor: ink(0x3B4238),
                    .kern: 2.4, .paragraphStyle: p]
        case .sectionNote:
            p.paragraphSpacing = 6
            return [.font: serif(12), .foregroundColor: ink(0x9A978C), .paragraphStyle: p]
        case .pieceTitle:
            p.lineSpacing = 1
            p.paragraphSpacingBefore = 14
            return [.font: serif(15, .medium), .foregroundColor: ink(0x252522), .paragraphStyle: p]
        case .meta:
            p.paragraphSpacing = 4
            return [.font: sans(8, .semibold), .foregroundColor: ink(0x9A978C),
                    .kern: 1.4, .paragraphStyle: p]
        case .body:
            p.lineSpacing = 4
            p.paragraphSpacing = 2
            return [.font: serif(11.5), .foregroundColor: ink(0x252522), .paragraphStyle: p]
        case .aside:
            p.lineSpacing = 2
            return [.font: sans(9), .foregroundColor: ink(0xA8946A), .paragraphStyle: p]
        }
    }

    private static func serif(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let d = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: d, size: size)
    }
    private static func sans(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }
    private static func ink(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    // MARK: - One thing to send

    /// Zips a directory using the coordinator's own archiver, so there's no third
    /// party library in the way of somebody's life's work.
    private static func zip(_ folder: URL) throws -> URL {
        var out: URL?
        var failure: Error?
        var coordinationError: NSError?

        NSFileCoordinator().coordinate(readingItemAt: folder, options: [.forUploading],
                                       error: &coordinationError) { archive in
            // The archive only exists for the length of this block, so take it now.
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(folder.lastPathComponent + ".zip")
            do {
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: archive, to: dest)
                out = dest
            } catch { failure = error }
        }

        if let coordinationError { throw coordinationError }
        if let failure { throw failure }
        guard let out else { throw CocoaError(.fileWriteUnknown) }
        return out
    }
}
