import Foundation
import SwiftData
import UniformTypeIdentifiers

/// A parcel that can be opened by another copy of Kinward and then passed on again.
///
/// The share export is a zip you read: a PDF, the photographs, the recordings. This
/// is the other half — one file the app itself understands, so what somebody was
/// given becomes part of their own archive and travels on to their children in turn.
///
/// Every piece carries the chain of hands it has been through, so three generations
/// down it still says where it came from.
///
/// Deliberately not a zip. There is no public API for reading one back, and a
/// third-party archiver has no business sitting between a family and its own
/// history. This is JSON with the media inside it, compressed whole.
enum Heirloom {

    static let fileExtension = "kinward"
    static let contentType = UTType(exportedAs: "com.ali.Kinward.heirloom")

    /// What is allowed to travel. Guidance, documents, financial and property notes
    /// are for the people handling an estate now — not for grandchildren — so they
    /// stay out of this on purpose.
    enum Kind: String, Codable, CaseIterable {
        case memory, letter, lesson, story, voice
        var plural: String {
            switch self {
            case .memory: "memories"; case .letter: "letters"; case .lesson: "lessons"
            case .story: "family stories"; case .voice: "recordings"
            }
        }
        var one: String {
            switch self {
            case .memory: "memory"; case .letter: "letter"; case .lesson: "lesson"
            case .story: "family story"; case .voice: "recording"
            }
        }
    }

    // MARK: - On the wire

    struct Item: Codable, Sendable {
        var heirloomID: String
        var kind: Kind
        /// Oldest first. The sender appends themselves when packing.
        var passedDown: [String]

        var title: String = ""
        var body: String = ""
        var meta: String = ""
        /// Kind-specific extras, kept loose so an older build can still read a newer
        /// parcel rather than refusing the whole thing.
        var fields: [String: String] = [:]
        var photos: [String] = []
        var audio: String?
        var createdAt: Date = .now
    }

    struct Parcel: Codable, Sendable {
        var format = "kinward.heirloom"
        var version = 1
        var packedAt: Date = .now
        var from: String
        var to: String
        var note: String = ""
        var items: [Item]
        /// Media keyed by reference, stored once even when two pieces share a photo.
        var media: [String: Data] = [:]

        var isEmpty: Bool { items.isEmpty }
        func count(_ kind: Kind) -> Int { items.filter { $0.kind == kind }.count }
        var fileName: String {
            let who = to.trimmingCharacters(in: .whitespaces)
            return (who.isEmpty ? "Kinward" : "For \(who)") + "." + fileExtension
        }
    }

    enum Failure: LocalizedError {
        case notAnHeirloom, tooNew(Int), unreadable

        var errorDescription: String? {
            switch self {
            case .notAnHeirloom:
                "That isn't a Kinward parcel. Look for a file ending in .kinward."
            case .tooNew:
                "This was made by a newer version of Kinward. Update the app and try again."
            case .unreadable:
                "The file is damaged and couldn't be read."
            }
        }
    }

    // MARK: - Writing and reading the file

    private static let magic = Data("KINWARD1".utf8)

    static func encode(_ parcel: Parcel) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(parcel)
        let squeezed = try (json as NSData).compressed(using: .zlib)
        return magic + (squeezed as Data)
    }

    static func decode(_ data: Data) throws -> Parcel {
        guard data.count > magic.count, data.prefix(magic.count) == magic else {
            throw Failure.notAnHeirloom
        }
        let payload = data.dropFirst(magic.count)
        guard let json = try? (payload as NSData).decompressed(using: .zlib) else {
            throw Failure.unreadable
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let parcel = try? decoder.decode(Parcel.self, from: json as Data) else {
            throw Failure.unreadable
        }
        guard parcel.version <= 1 else { throw Failure.tooNew(parcel.version) }
        return parcel
    }

    // MARK: - Packing

    /// Everything of `person`'s that can travel, plus anything already passed down to
    /// this user — that is the part that keeps the chain moving.
    @MainActor
    static func pack(for person: Person?, kinds: Set<Kind>,
                     from profile: UserProfile?, in ctx: ModelContext) -> Parcel {
        let me = senderName(profile)
        func all<T: PersistentModel>(_ type: T.Type) -> [T] {
            (try? ctx.fetch(FetchDescriptor<T>())) ?? []
        }

        var items: [Item] = []

        if kinds.contains(.memory) {
            for m in all(MemoryEntry.self) where !m.isDraft {
                items.append(Item(
                    heirloomID: stamp(m.heirloomID) { m.heirloomID = $0 },
                    kind: .memory,
                    passedDown: m.passedDown + [me],
                    title: m.title,
                    body: m.story,
                    meta: [m.displayYear.map(String.init), m.place.isEmpty ? nil : m.place]
                        .compactMap { $0 }.joined(separator: " · "),
                    fields: ["whyItMatters": m.whyItMatters,
                             "place": m.place,
                             "stage": m.stageRaw,
                             "year": m.approximateYear.map(String.init) ?? ""],
                    photos: m.photoRefs,
                    audio: m.audioRef,
                    createdAt: m.createdAt))
            }
        }

        if kinds.contains(.letter) {
            // A sealed letter is meant to be opened at a moment somebody chose. Sending
            // it on would be the one thing the writer asked not to happen.
            let mine = all(Letter.self).filter {
                !$0.isDraft && !$0.isSealed && (person == nil || $0.recipient?.id == person?.id)
            }
            for l in mine {
                items.append(Item(
                    heirloomID: stamp(l.heirloomID) { l.heirloomID = $0 },
                    kind: .letter,
                    passedDown: l.passedDown + [me],
                    title: l.title,
                    body: l.body,
                    meta: l.recipient.map { "Written for \($0.name)" } ?? "",
                    fields: ["salutation": l.salutation,
                             "signature": l.signature,
                             "writtenFor": l.recipient?.name ?? ""],
                    photos: l.photoRefs,
                    audio: l.audioRef,
                    createdAt: l.createdAt))
            }
        }

        if kinds.contains(.lesson) {
            for l in all(Lesson.self) {
                items.append(Item(
                    heirloomID: stamp(l.heirloomID) { l.heirloomID = $0 },
                    kind: .lesson,
                    passedDown: l.passedDown + [me],
                    title: l.headline.isEmpty ? l.category.title : l.headline,
                    body: l.body,
                    meta: l.category.title,
                    fields: ["category": l.categoryRaw, "prompt": l.prompt],
                    audio: l.audioRef,
                    createdAt: l.createdAt))
            }
        }

        if kinds.contains(.story) {
            for s in all(FamilyStory.self) {
                items.append(Item(
                    heirloomID: stamp(s.heirloomID) { s.heirloomID = $0 },
                    kind: .story,
                    passedDown: s.passedDown + [me],
                    title: s.title.isEmpty ? s.subject : s.title,
                    body: s.body,
                    meta: [s.subject, s.generation, s.years, s.origin]
                        .filter { !$0.isEmpty }.joined(separator: " · "),
                    fields: ["subject": s.subject, "generation": s.generation,
                             "years": s.years, "origin": s.origin,
                             "isRecipe": String(s.isRecipe), "isTradition": String(s.isTradition)],
                    photos: s.photoRefs,
                    audio: s.audioRef,
                    createdAt: s.createdAt))
            }
        }

        if kinds.contains(.voice) {
            let recs = all(VoiceRecording.self).filter {
                person == nil || $0.person == nil || $0.person?.id == person?.id
            }
            for r in recs where !r.fileRef.isEmpty {
                items.append(Item(
                    heirloomID: stamp(r.heirloomID) { r.heirloomID = $0 },
                    kind: .voice,
                    passedDown: r.passedDown + [me],
                    title: r.title,
                    body: r.note,
                    meta: r.durationText,
                    fields: ["transcript": r.transcript, "duration": String(r.duration)],
                    audio: r.fileRef,
                    createdAt: r.createdAt))
            }
        }

        try? ctx.save()

        var media: [String: Data] = [:]
        for ref in items.flatMap({ $0.photos + [$0.audio].compactMap { $0 } }) where media[ref] == nil {
            if let data = try? Data(contentsOf: MediaStore.url(for: ref)) { media[ref] = data }
        }

        return Parcel(from: me,
                      to: person?.name ?? "",
                      note: person?.capsule?.openingMessage ?? "",
                      items: items,
                      media: media)
    }

    /// An id is minted the first time a piece travels and never changes after.
    private static func stamp(_ existing: String, set: (String) -> Void) -> String {
        guard existing.isEmpty else { return existing }
        let fresh = UUID().uuidString
        set(fresh)
        return fresh
    }

    static func senderName(_ profile: UserProfile?) -> String {
        let full = [profile?.firstName ?? "", profile?.lastName ?? ""]
            .filter { !$0.isEmpty }.joined(separator: " ")
        return full.isEmpty ? "Someone in your family" : full
    }

    // MARK: - Opening one

    struct Outcome: Sendable, Identifiable {
        let id = UUID()
        var added: [Kind: Int] = [:]
        var alreadyHad = 0
        var from = ""
        var total: Int { added.values.reduce(0, +) }
    }

    /// Writes the parcel into this archive. Pieces already here — matched on the id
    /// that travels with them — are left alone rather than duplicated.
    @MainActor
    @discardableResult
    static func open(_ parcel: Parcel, into ctx: ModelContext) -> Outcome {
        var outcome = Outcome(from: parcel.from)

        func existing<T: PersistentModel>(_ type: T.Type, _ id: (T) -> String) -> Set<String> {
            Set(((try? ctx.fetch(FetchDescriptor<T>())) ?? []).map(id).filter { !$0.isEmpty })
        }
        let have = existing(MemoryEntry.self) { $0.heirloomID }
            .union(existing(Letter.self) { $0.heirloomID })
            .union(existing(Lesson.self) { $0.heirloomID })
            .union(existing(FamilyStory.self) { $0.heirloomID })
            .union(existing(VoiceRecording.self) { $0.heirloomID })

        // Media lands first so the pieces that reference it are never dangling.
        var landed: [String: String] = [:]
        for (ref, data) in parcel.media {
            let url = MediaStore.url(for: ref)
            if !FileManager.default.fileExists(atPath: url.path) {
                try? data.write(to: url, options: .atomic)
            }
            landed[ref] = ref
        }
        func kept(_ refs: [String]) -> [String] { refs.compactMap { landed[$0] } }

        for item in parcel.items {
            guard !item.heirloomID.isEmpty else { continue }
            guard !have.contains(item.heirloomID) else { outcome.alreadyHad += 1; continue }

            switch item.kind {
            case .memory:
                let m = MemoryEntry(title: item.title, story: item.body)
                m.heirloomID = item.heirloomID
                m.passedDown = item.passedDown
                m.whyItMatters = item.fields["whyItMatters"] ?? ""
                m.place = item.fields["place"] ?? ""
                m.stageRaw = item.fields["stage"] ?? LifeStage.recent.rawValue
                m.approximateYear = item.fields["year"].flatMap(Int.init)
                m.photoRefs = kept(item.photos)
                m.audioRef = item.audio.flatMap { landed[$0] }
                m.createdAt = item.createdAt
                m.isDraft = false
                ctx.insert(m)

            case .letter:
                let l = Letter(title: item.title, body: item.body)
                l.heirloomID = item.heirloomID
                l.passedDown = item.passedDown
                l.salutation = item.fields["salutation"] ?? ""
                l.signature = item.fields["signature"] ?? ""
                l.photoRefs = kept(item.photos)
                l.audioRef = item.audio.flatMap { landed[$0] }
                l.createdAt = item.createdAt
                l.isDraft = false
                ctx.insert(l)

            case .lesson:
                let l = Lesson(category: LessonCategory(rawValue: item.fields["category"] ?? "") ?? .whatLifeTaught,
                               headline: item.title, body: item.body)
                l.heirloomID = item.heirloomID
                l.passedDown = item.passedDown
                l.prompt = item.fields["prompt"] ?? ""
                l.audioRef = item.audio.flatMap { landed[$0] }
                l.createdAt = item.createdAt
                ctx.insert(l)

            case .story:
                let s = FamilyStory(title: item.title,
                                    subject: item.fields["subject"] ?? "",
                                    generation: item.fields["generation"] ?? "")
                s.heirloomID = item.heirloomID
                s.passedDown = item.passedDown
                s.body = item.body
                s.years = item.fields["years"] ?? ""
                s.origin = item.fields["origin"] ?? ""
                s.isRecipe = item.fields["isRecipe"] == "true"
                s.isTradition = item.fields["isTradition"] == "true"
                s.photoRefs = kept(item.photos)
                s.audioRef = item.audio.flatMap { landed[$0] }
                s.createdAt = item.createdAt
                ctx.insert(s)

            case .voice:
                guard let ref = item.audio.flatMap({ landed[$0] }) else { continue }
                let r = VoiceRecording(title: item.title, fileRef: ref,
                                       duration: Double(item.fields["duration"] ?? "") ?? 0)
                r.heirloomID = item.heirloomID
                r.passedDown = item.passedDown
                r.note = item.body
                r.transcript = item.fields["transcript"] ?? ""
                r.createdAt = item.createdAt
                ctx.insert(r)
            }
            outcome.added[item.kind, default: 0] += 1
        }

        try? ctx.save()
        return outcome
    }

    /// Reads a parcel off disk, coping with a file that arrived from Files or Mail
    /// and therefore needs to be asked for first.
    static func read(_ url: URL) throws -> Parcel {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw Failure.unreadable }
        return try decode(data)
    }

    /// Writes the parcel somewhere the share sheet can pick it up.
    static func write(_ parcel: Parcel) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(parcel.fileName)
        try? FileManager.default.removeItem(at: url)
        try encode(parcel).write(to: url, options: .atomic)
        return url
    }
}

extension Array where Element == String {
    /// "Rosa, through Ali" — the chain as a person would say it out loud.
    var asChain: String {
        switch count {
        case 0: ""
        case 1: self[0]
        default: self[0] + ", through " + dropFirst().joined(separator: ", then ")
        }
    }
}
