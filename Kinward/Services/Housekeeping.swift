import Foundation
import SwiftData

/// Editors work on real persisted objects, so an entry the user opened and abandoned
/// can survive a crash or a dismissed sheet. This clears those on launch, and only
/// those: anything with a single character of content is left alone.
enum Housekeeping {
    @MainActor
    static func pruneBlankEntries(in ctx: ModelContext) {
        func blank(_ s: String) -> Bool {
            s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if let items = try? ctx.fetch(FetchDescriptor<MemoryEntry>()) {
            for m in items where blank(m.title) && blank(m.story) && blank(m.whyItMatters)
                && blank(m.place) && m.photoRefs.isEmpty && m.audioRef == nil {
                ctx.delete(m)
            }
        }
        if let items = try? ctx.fetch(FetchDescriptor<Letter>()) {
            for l in items where blank(l.title) && blank(l.body) && blank(l.salutation)
                && l.photoRefs.isEmpty && l.audioRef == nil {
                ctx.delete(l)
            }
        }
        if let items = try? ctx.fetch(FetchDescriptor<Lesson>()) {
            for l in items where blank(l.headline) && blank(l.body) && l.audioRef == nil {
                ctx.delete(l)
            }
        }
        if let items = try? ctx.fetch(FetchDescriptor<FamilyStory>()) {
            for s in items where blank(s.title) && blank(s.subject) && blank(s.body)
                && s.photoRefs.isEmpty && s.audioRef == nil {
                ctx.delete(s)
            }
        }
        if let items = try? ctx.fetch(FetchDescriptor<GuidanceNote>()) {
            for n in items where blank(n.title) && blank(n.detail) && blank(n.whereToFind) {
                ctx.delete(n)
            }
        }
        if let items = try? ctx.fetch(FetchDescriptor<DocumentItem>()) {
            for d in items where blank(d.title) && d.fileRefs.isEmpty && blank(d.note) {
                ctx.delete(d)
            }
        }
        if let items = try? ctx.fetch(FetchDescriptor<Belonging>()) {
            for b in items where blank(b.name) && blank(b.story) && b.photoRefs.isEmpty {
                ctx.delete(b)
            }
        }
        if let items = try? ctx.fetch(FetchDescriptor<Person>()) {
            for p in items where blank(p.name) && p.pieceCount == 0 && p.photoRef == nil {
                ctx.delete(p)
            }
        }
        try? ctx.save()
    }
}
