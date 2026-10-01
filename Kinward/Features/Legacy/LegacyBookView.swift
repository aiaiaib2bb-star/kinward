import SwiftUI
import SwiftData

/// The whole archive, read the way a family would read it years from now:
/// chapters, in order, with nothing to tap.
struct LegacyBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \MemoryEntry.createdAt) private var memories: [MemoryEntry]
    @Query(sort: \Lesson.createdAt) private var lessons: [Lesson]
    @Query(sort: \Letter.createdAt) private var letters: [Letter]
    @Query(sort: \FamilyStory.createdAt) private var stories: [FamilyStory]
    @Query(sort: \VoiceRecording.createdAt) private var recordings: [VoiceRecording]
    @Query(sort: \Person.createdAt) private var people: [Person]
    @AppStorage(LetterFace.storageKey) private var faceRaw = LetterFace.hand.rawValue
    private var face: LetterFace { LetterFace(rawValue: faceRaw) ?? .hand }

    private var name: String { profiles.first?.firstName ?? "" }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [K.bgDeep, K.bg], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 34) {
                        cover
                        let present = chaptersPresent
                        ForEach(Array(present.enumerated()), id: \.element) { i, kind in
                            chapter(numeral(i + 1), kind.title) { pages(for: kind) }
                        }
                        if present.isEmpty { emptyBook }
                        colophon
                    }
                    .padding(.horizontal, 24).padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) { Text("The book").font(.serif(16)).foregroundStyle(K.ink) }
            }
            .toolbarBackground(K.bgDeep, for: .navigationBar)
        }
    }

    private enum Chapter: String, CaseIterable, Hashable {
        case family, memories, people, lessons, letters, voice
        var title: String {
            switch self {
            case .family: "Where I come from"
            case .memories: "What happened"
            case .people: "Who mattered"
            case .lessons: "What I learned"
            case .letters: "What I wanted to say"
            case .voice: "My voice"
            }
        }
    }

    private var chaptersPresent: [Chapter] {
        Chapter.allCases.filter { c in
            switch c {
            case .family: !stories.isEmpty
            case .memories: !memories.isEmpty
            case .people: !people.isEmpty
            case .lessons: !lessons.isEmpty
            case .letters: !letters.isEmpty
            case .voice: !recordings.isEmpty
            }
        }
    }

    @ViewBuilder
    private func pages(for c: Chapter) -> some View {
        switch c {
        case .family: familyPages
        case .memories: memoryPages
        case .people: peoplePages
        case .lessons: lessonPages
        case .letters: letterPages
        case .voice: voicePages
        }
    }

    private func numeral(_ n: Int) -> String {
        let table: [(Int, String)] = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = n, out = ""
        for (v, s) in table { while n >= v { out += s; n -= v } }
        return out
    }

    private var emptyBook: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nothing to bind yet").font(.serif(22)).foregroundStyle(K.ink)
            Text("Keep a memory, write a letter, record something. This page fills itself.")
                .font(KType.body(15)).foregroundStyle(K.inkSoft).lineSpacing(3)
        }
    }

    private var cover: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("A life")
                .font(.serif(15)).tracking(5).textCase(.uppercase).foregroundStyle(K.gold)
                .padding(.top, 28)
            Text(name.isEmpty ? "My story" : "The life of \(name)")
                .font(.serif(38)).foregroundStyle(K.ink).lineSpacing(2)
            Text("Collected in Kinward · \(Date.now.formatted(.dateTime.year()))")
                .font(KType.caption(13)).foregroundStyle(K.inkSoft)
            HairLine().padding(.top, 10)
        }
    }

    private func chapter<C: View>(_ numeral: String, _ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(numeral).font(.serif(13)).tracking(4).foregroundStyle(K.gold)
                Text(title).font(.serif(27)).foregroundStyle(K.ink)
            }
            content()
        }
    }

    private var familyPages: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(stories) { s in
                page(title: s.title.isEmpty ? s.subject : s.title,
                     sub: [s.generation, s.years, s.origin].filter { !$0.isEmpty }.joined(separator: " · "),
                     body: s.body, photo: s.photoRefs.first)
            }
        }
    }
    private var memoryPages: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(memories.sorted { ($0.displayYear ?? 0) < ($1.displayYear ?? 0) }) { m in
                page(title: m.title.isEmpty ? "Untitled" : m.title,
                     sub: [m.displayYear.map(String.init) ?? "", m.place].filter { !$0.isEmpty }.joined(separator: " · "),
                     body: m.story.isEmpty ? m.whyItMatters : m.story,
                     photo: m.photoRefs.first)
            }
        }
    }
    private var peoplePages: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(people) { p in
                HStack(spacing: 14) {
                    PersonAvatar(person: p, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.name).font(.serif(18)).foregroundStyle(K.ink)
                        Text(p.notes.isEmpty ? p.relationship : p.notes)
                            .font(KType.body(14)).foregroundStyle(K.inkSoft)
                            .lineLimit(3).multilineTextAlignment(.leading)
                    }
                    Spacer()
                }
            }
        }
    }
    private var lessonPages: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(lessons) { l in
                page(title: l.headline.isEmpty ? l.category.title : l.headline,
                     sub: l.category.title, body: l.body, photo: nil)
            }
        }
    }
    private var letterPages: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(letters) { l in
                VStack(alignment: .leading, spacing: 10) {
                    Text(l.recipient.map { "To \($0.name)" } ?? (l.title.isEmpty ? "A letter" : l.title))
                        .font(.serif(20)).foregroundStyle(K.ink)
                    if !l.salutation.isEmpty {
                        Text(l.salutation).font(face.font(18)).foregroundStyle(K.inkSoft)
                    }
                    Text(l.body).font(face.font(17)).foregroundStyle(K.ink).lineSpacing(face.lineSpacing(7))
                    if !l.signature.isEmpty {
                        Text(l.signature).font(face.font(18)).foregroundStyle(K.inkSoft).padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)
                if l.id != letters.last?.id { HairLine().opacity(0.6) }
            }
        }
    }
    private var voicePages: some View {
        VStack(spacing: 10) {
            ForEach(recordings) { r in VoiceBar(recording: r, compact: true) }
        }
    }

    private func page(title: String, sub: String, body: String, photo: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let photo {
                MediaImage(ref: photo)
                    .frame(height: 190).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Text(title).font(.serif(21)).foregroundStyle(K.ink)
            if !sub.isEmpty { Text(sub).eyebrowStyle(K.gold) }
            if !body.isEmpty {
                Text(body).font(.serif(16)).foregroundStyle(K.ink.opacity(0.85)).lineSpacing(6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var colophon: some View {
        VStack(alignment: .leading, spacing: 10) {
            HairLine()
            Text("Kept in Kinward by \(name.isEmpty ? "one person" : name).")
                .font(KType.caption(12.5)).foregroundStyle(K.inkFaint)
            Marginalia(text: "Some things should\nnot disappear.")
        }
        .padding(.top, 14)
    }
}

// MARK: - Trusted people

struct TrustedPeopleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Person.createdAt) private var people: [Person]
    @State private var managing: Person?

    private let permissions = ["Memories", "Letters", "Voice", "Family history", "Lessons",
                               "Guidance", "Financial", "Documents", "Digital life", "Property"]

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Kinward never decides when your story should be opened. Trusted people can ask; you answer.")
                            .font(KType.body(15)).foregroundStyle(K.inkSoft).lineSpacing(3)
                            .padding(.top, 8)

                        if people.isEmpty {
                            QuietEmptyState(icon: "key", title: "No one yet",
                                            message: "Add someone in People or build your family tree, then choose what they can see.")
                        } else {
                            VStack(spacing: 12) {
                                ForEach(ordered) { p in
                                    Button { Haptics.tap(); managing = p } label: {
                                        HStack(spacing: 14) {
                                            PersonAvatar(person: p, size: 46)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(p.name.isEmpty ? "Unnamed" : p.name)
                                                    .font(KType.body(16).weight(.medium)).foregroundStyle(K.ink)
                                                Text(status(p)).font(KType.caption(12)).foregroundStyle(statusColor(p))
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(K.inkFaint.opacity(0.6))
                                        }
                                        .padding(14).cardSurface(radius: 18)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("How it works").eyebrowStyle(K.inkFaint).padding(.top, 10)
                            infoRow("hand.raised", "They ask", "\u{201C}I'd like to see what you've prepared for me.\u{201D}")
                            infoRow("bell", "You're told", "Kinward tells you who asked, and when.")
                            infoRow("checkmark.circle", "You decide", "Approve, decline, or choose exactly what opens.")
                            infoRow("clock", "Or pause it", "Set a quiet period so nobody can ask again for a while.")
                        }
                    }
                    .padding(.horizontal, 22).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) { Text("Trusted people").font(.serif(16)).foregroundStyle(K.ink) }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .sheet(item: $managing) { p in AccessManager(person: p, permissions: permissions) }
    }

    private func status(_ p: Person) -> String {
        if p.accessRequestedAt != nil { return "Waiting for your answer" }
        if !p.accessGranted.isEmpty { return "Can see \(p.accessGranted.count) \(p.accessGranted.count == 1 ? "area" : "areas")" }
        if let l = p.lockoutUntil, l > .now { return "Paused until \(l.formatted(date: .abbreviated, time: .omitted))" }
        switch p.accessRole {
        case .trusted: return "Trusted · nothing shared yet"
        case .canAsk: return "Can ask you things"
        case .none: return "No access"
        }
    }
    private func statusColor(_ p: Person) -> Color {
        p.accessRequestedAt != nil ? K.gold : K.inkSoft
    }

    /// Anyone with a role first, so the list reads as an access list.
    private var ordered: [Person] {
        people.sorted {
            if ($0.accessRole != .none) != ($1.accessRole != .none) { return $0.accessRole != .none }
            return $0.createdAt < $1.createdAt
        }
    }

    private func infoRow(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon).font(.system(size: 13, weight: .light)).foregroundStyle(K.sage)
                .frame(width: 30, height: 30)
                .background(Circle().fill(K.bgDeep.opacity(0.7)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(KType.body(14.5).weight(.medium)).foregroundStyle(K.ink)
                Text(body).font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                    .multilineTextAlignment(.leading).lineSpacing(2)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .cardSurface(radius: 16)
    }
}

struct AccessManager: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var person: Person
    let permissions: [String]
    @State private var confirmSensitive = false
    @State private var pendingSensitive: String?

    private let sensitive: Set<String> = ["Guidance", "Financial", "Documents", "Digital life", "Property"]

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 14) {
                            PersonAvatar(person: person, size: 58)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(person.name).font(.serif(21)).foregroundStyle(K.ink)
                                Text(person.relationship).eyebrowStyle(K.gold)
                            }
                            Spacer()
                        }
                        .padding(.top, 8)

                        VStack(spacing: 0) {
                            ForEach(Array(FamilyAccess.allCases.enumerated()), id: \.element) { i, role in
                                if i > 0 { HairLine() }
                                Button {
                                    Haptics.tap()
                                    withAnimation(KMotion.gentle) { person.accessRole = role }
                                    try? ctx.save()
                                } label: {
                                    HStack(alignment: .top, spacing: 13) {
                                        Image(systemName: person.accessRole == role ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: 17, weight: .light))
                                            .foregroundStyle(person.accessRole == role ? K.sageDeep : K.inkFaint.opacity(0.6))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(role.title).font(KType.body(15.5).weight(.medium)).foregroundStyle(K.ink)
                                            Text(role.detail).font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                                                .multilineTextAlignment(.leading).lineSpacing(2)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .cardSurface()

                        if person.accessRole == .trusted {
                            FormLabel(text: "What they may see")
                            VStack(spacing: 0) {
                                ForEach(Array(permissions.enumerated()), id: \.offset) { i, perm in
                                    if i > 0 { HairLine() }
                                    Toggle(isOn: binding(for: perm)) {
                                        HStack(spacing: 7) {
                                            Text(perm).font(KType.body(15)).foregroundStyle(K.ink)
                                            if sensitive.contains(perm) {
                                                Image(systemName: "lock.fill").font(.system(size: 8)).foregroundStyle(K.gold)
                                            }
                                        }
                                    }
                                    .tint(K.sage)
                                    .padding(.horizontal, 16).padding(.vertical, 11)
                                }
                            }
                            .cardSurface()

                            FormLabel(text: "Quiet period")
                            Text("Stop repeated requests for a while. They'll simply be told you're not ready.")
                                .font(KType.caption(12.5)).foregroundStyle(K.inkSoft).padding(.horizontal, 2)
                            HStack(spacing: 8) {
                                ForEach([30, 90, 180, 365], id: \.self) { days in
                                    Button {
                                        Haptics.tap()
                                        person.lockoutUntil = Calendar.current.date(byAdding: .day, value: days, to: .now)
                                        try? ctx.save()
                                    } label: {
                                        Text(label(days)).font(KType.body(13))
                                            .foregroundStyle(K.ink)
                                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                                            .background(Capsule().fill(K.surface)
                                                .overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            if let l = person.lockoutUntil, l > .now {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock").font(.system(size: 11)).foregroundStyle(K.gold)
                                    Text("Requests paused until \(l.formatted(date: .abbreviated, time: .omitted))")
                                        .font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                                    Spacer()
                                    Button("Clear") { person.lockoutUntil = nil; try? ctx.save() }
                                        .font(KType.caption(12)).foregroundStyle(K.sage)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(K.goldSoft.opacity(0.22)))
                            }

                            // Lets you feel the other side of the flow before it ever happens for real.
                            Button {
                                Haptics.tap()
                                person.accessRequestedAt = .now
                                try? ctx.save()
                                dismiss()
                            } label: {
                                Text("Simulate a request from \(person.name)")
                                    .font(KType.body(13.5)).foregroundStyle(K.inkFaint)
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Capsule().strokeBorder(K.border, lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 22).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { try? ctx.save(); dismiss() }
                        .font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) { Text("Access").font(.serif(16)).foregroundStyle(K.ink) }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .alert("Share sensitive information?", isPresented: $confirmSensitive) {
            Button("Yes, share it") {
                if let p = pendingSensitive { person.accessGranted.append(p); try? ctx.save(); Haptics.kept() }
                pendingSensitive = nil
            }
            Button("Cancel", role: .cancel) { pendingSensitive = nil }
        } message: {
            Text("\(person.name) would be able to see financial, legal or account information. Only do this for someone you'd trust with the originals.")
        }
    }

    private func label(_ d: Int) -> String {
        switch d { case 30: "30 days"; case 90: "90 days"; case 180: "6 months"; default: "1 year" }
    }

    private func binding(for perm: String) -> Binding<Bool> {
        Binding(
            get: { person.accessGranted.contains(perm) },
            set: { on in
                guard on else {
                    person.accessGranted.removeAll { $0 == perm }; try? ctx.save(); return
                }
                guard sensitive.contains(perm) else {
                    person.accessGranted.append(perm); try? ctx.save(); return
                }
                // Presentation flags set during a Toggle's update get dropped.
                Task { @MainActor in
                    pendingSensitive = perm
                    confirmSensitive = true
                }
            }
        )
    }
}
