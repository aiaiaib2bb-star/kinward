import SwiftUI
import SwiftData

/// One field over the whole archive.
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var memories: [MemoryEntry]
    @Query private var letters: [Letter]
    @Query private var lessons: [Lesson]
    @Query private var recordings: [VoiceRecording]
    @Query private var stories: [FamilyStory]
    @Query private var people: [Person]
    @Query private var belongings: [Belonging]
    @Query private var guidance: [GuidanceNote]

    @State private var query = ""
    @FocusState private var focused: Bool
    @State private var openMemory: MemoryEntry?
    @State private var openLetter: Letter?
    @State private var openLesson: Lesson?
    @State private var openPerson: Person?
    @State private var openStory: FamilyStory?

    var body: some View {
        ZStack {
            PaperBackground(deep: true)
            VStack(spacing: 0) {
                field
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        if query.isEmpty {
                            suggestions
                        } else if isEmpty {
                            QuietEmptyState(icon: "magnifyingglass", title: "Nothing found",
                                            message: "Try a name, a place, a year, or a word you'd have used.")
                        } else {
                            results
                        }
                    }
                    .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 60)
                }
            }
        }
        .sheet(item: $openMemory) { m in MemoryEditor(memory: m) }
        .sheet(item: $openLetter) { l in LetterEditor(letter: l) }
        .sheet(item: $openLesson) { l in LessonEditor(lesson: l) }
        .sheet(item: $openPerson) { p in PersonDetail(person: p) }
        .sheet(item: $openStory) { s in FamilyStoryEditor(story: s) }
        .onAppear { focused = true }
    }

    private var field: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(K.inkFaint)
                TextField("", text: $query,
                          prompt: Text("Search everything").foregroundStyle(K.inkFaint.opacity(0.85)))
                    .font(KType.body(16)).foregroundStyle(K.ink)
                    .focused($focused)
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 15)).foregroundStyle(K.inkFaint.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 15).padding(.vertical, 13)
            .background(Capsule().fill(K.surface).overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))

            Button("Done") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)
    }

    private var q: String { query.lowercased().trimmingCharacters(in: .whitespaces) }
    private func has(_ s: String...) -> Bool { s.contains { $0.lowercased().contains(q) } }

    private var mResults: [MemoryEntry] { memories.filter { has($0.title, $0.story, $0.place, $0.whyItMatters, String($0.displayYear ?? 0)) } }
    private var lResults: [Letter] { letters.filter { has($0.title, $0.body, $0.salutation, $0.recipient?.name ?? "") } }
    private var lsResults: [Lesson] { lessons.filter { has($0.headline, $0.body, $0.prompt, $0.category.title) } }
    private var rResults: [VoiceRecording] { recordings.filter { has($0.title, $0.note, $0.person?.name ?? "") } }
    private var sResults: [FamilyStory] { stories.filter { has($0.title, $0.subject, $0.body, $0.origin, $0.generation) } }
    private var pResults: [Person] { people.filter { has($0.name, $0.relationship, $0.notes) } }
    private var bResults: [Belonging] { belongings.filter { has($0.name, $0.story, $0.location, $0.detail) } }
    private var gResults: [GuidanceNote] { guidance.filter { has($0.title, $0.detail, $0.whereToFind, $0.contactName) } }

    private var isEmpty: Bool {
        mResults.isEmpty && lResults.isEmpty && lsResults.isEmpty && rResults.isEmpty
            && sResults.isEmpty && pResults.isEmpty && bResults.isEmpty && gResults.isEmpty
    }

    @ViewBuilder
    private var results: some View {
        if !pResults.isEmpty {
            group("People") {
                ForEach(pResults) { p in
                    Button { Haptics.tap(); openPerson = p } label: {
                        ArchiveRow(title: p.name, subtitle: p.relationship, icon: "person", imageRef: p.photoRef)
                    }.buttonStyle(.plain)
                }
            }
        }
        if !mResults.isEmpty {
            group("Memories") {
                ForEach(mResults) { m in
                    Button { Haptics.tap(); openMemory = m } label: {
                        ArchiveRow(title: m.title.isEmpty ? "Untitled" : m.title,
                                   subtitle: snippet(m.story.isEmpty ? m.whyItMatters : m.story),
                                   icon: "photo.on.rectangle.angled", imageRef: m.photoRefs.first)
                    }.buttonStyle(.plain)
                }
            }
        }
        if !lResults.isEmpty {
            group("Letters") {
                ForEach(lResults) { l in
                    Button { Haptics.tap(); openLetter = l } label: {
                        ArchiveRow(title: l.title.isEmpty ? "Untitled letter" : l.title,
                                   subtitle: snippet(l.body), icon: "envelope")
                    }.buttonStyle(.plain)
                }
            }
        }
        if !lsResults.isEmpty {
            group("Lessons") {
                ForEach(lsResults) { l in
                    Button { Haptics.tap(); openLesson = l } label: {
                        ArchiveRow(title: l.headline.isEmpty ? l.category.title : l.headline,
                                   subtitle: snippet(l.body), icon: l.category.icon)
                    }.buttonStyle(.plain)
                }
            }
        }
        if !rResults.isEmpty {
            group("Voice") { ForEach(rResults) { r in VoiceBar(recording: r, compact: true) } }
        }
        if !sResults.isEmpty {
            group("Family history") {
                ForEach(sResults) { s in
                    Button { Haptics.tap(); openStory = s } label: {
                        ArchiveRow(title: s.title.isEmpty ? s.subject : s.title,
                                   subtitle: snippet(s.body), icon: "tree", imageRef: s.photoRefs.first)
                    }.buttonStyle(.plain)
                }
            }
        }
        if !bResults.isEmpty {
            group("Belongings") {
                ForEach(bResults) { b in
                    ArchiveRow(title: b.name, subtitle: b.location, icon: "shippingbox",
                               imageRef: b.photoRefs.first, showsChevron: false)
                }
            }
        }
        if !gResults.isEmpty {
            group("Guidance") {
                ForEach(gResults) { g in
                    ArchiveRow(title: g.title, subtitle: g.category.title, icon: g.category.icon, showsChevron: false)
                }
            }
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Try").eyebrowStyle(K.inkFaint)
            FlowLayout(spacing: 8) {
                ForEach(hints, id: \.self) { h in
                    Button { Haptics.tap(); query = h } label: {
                        Text(h).font(KType.body(14)).foregroundStyle(K.ink)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Capsule().fill(K.surface).overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
                    }
                    .buttonStyle(.plain)
                }
            }
            Marginalia(text: "Everything you've kept,\nin one place.").padding(.top, 16)
        }
    }
    private var hints: [String] {
        var h = people.prefix(4).map(\.name).filter { !$0.isEmpty }
        h += ["childhood", "father", "home", "advice"]
        return Array(h.prefix(8))
    }

    private func snippet(_ s: String) -> String { String(s.prefix(70)) }

    private func group<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).eyebrowStyle(K.gold)
            content()
        }
    }
}
