import SwiftUI
import SwiftData

struct LegacyView: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var router: Router
    @Query(sort: \Person.createdAt) private var people: [Person]
    @Query(sort: \FamilyStory.createdAt, order: .reverse) private var stories: [FamilyStory]
    @Query private var memories: [MemoryEntry]
    @Query private var letters: [Letter]
    @Query private var lessons: [Lesson]
    @Query private var recordings: [VoiceRecording]

    @State private var capsuleFor: Person?
    @State private var previewFor: Person?
    @State private var showFamily = false
    @State private var showTree = false
    @State private var showBook = false
    @State private var showTrusted = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "What you\nleave behind.",
                              subtitle: "Gathered, for the people it was always meant for.",
                              onBack: { router.goHome() })

                capsulesBlock
                toolsBlock
                familyBlock

                Marginalia(text: KinwardSection.legacy.marginalia).padding(.top, 6)
            }
            .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 190)
        }
        .background(PaperBackground())
        .overlay(alignment: .top) { StatusBarScrim() }
        .sheet(item: $capsuleFor) { p in CapsuleBuilder(person: p) }
        .sheet(item: $previewFor) { p in CapsuleRecipientPreview(person: p) }
        .sheet(isPresented: $showFamily) { FamilyHistoryView() }
        .sheet(isPresented: $showTree) { FamilyTreeView() }
        .sheet(isPresented: $showBook) { LegacyBookView() }
        .sheet(isPresented: $showTrusted) { TrustedPeopleView() }
    }

    // MARK: Capsules

    private var capsulesBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legacy capsules").eyebrowStyle(K.gold)
            if people.isEmpty {
                QuietEmptyState(icon: "circle.hexagongrid",
                                title: "A capsule is for one person",
                                message: "Add someone first, then gather everything you'd want them to open one day.",
                                actionTitle: "Add someone") { router.go(.people) }
            } else {
                VStack(spacing: 12) {
                    ForEach(people) { p in
                        capsuleRow(p)
                    }
                }
            }
        }
    }

    private func capsuleRow(_ p: Person) -> some View {
        VStack(spacing: 0) {
            Button { Haptics.tap(); capsuleFor = p } label: {
                HStack(spacing: 14) {
                    PersonAvatar(person: p, size: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.capsule?.title.isEmpty == false ? p.capsule!.title : "For \(p.name)")
                            .font(.serif(19)).foregroundStyle(K.ink)
                            .multilineTextAlignment(.leading)
                        Text(capsuleSummary(p)).font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(K.inkFaint.opacity(0.6))
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            HairLine().padding(.horizontal, 16)

            Button { Haptics.tap(); previewFor = p } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eye").font(.system(size: 12, weight: .light))
                    Text("See it the way \(p.name.isEmpty ? "they" : p.name) would")
                        .font(KType.body(13.5))
                    Spacer()
                }
                .foregroundStyle(K.sage)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .cardSurface(fill: K.paper)
    }

    private func capsuleSummary(_ p: Person) -> String {
        let n = p.pieceCount
        if n == 0 { return "Nothing gathered yet" }
        func part(_ c: Int?, _ one: String, _ many: String) -> String? {
            guard let c, c > 0 else { return nil }
            return "\(c) \(c == 1 ? one : many)"
        }
        return [part(p.memories?.count, "memory", "memories"),
                part(p.letters?.count, "letter", "letters"),
                part(p.recordings?.count, "recording", "recordings"),
                part(p.belongings?.count, "thing", "things")]
            .compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Tools

    private var toolsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your whole archive").eyebrowStyle(K.inkFaint)
            Button { Haptics.tap(); showBook = true } label: {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("The book of your life")
                            .font(.serif(20)).foregroundStyle(K.ink)
                        Text("\(totalPieces) \(totalPieces == 1 ? "piece" : "pieces"), read end to end the way a family would.")
                            .font(KType.caption(13)).foregroundStyle(K.inkSoft)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.leading, 20).padding(.vertical, 20)
                    Spacer(minLength: 10)
                    Image("hero_album_letters").resizable().scaledToFill()
                        .frame(width: 96, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(10)
                }
                .cardSurface(fill: K.paper)
            }
            .buttonStyle(.plain)

            Button { Haptics.tap(); showTrusted = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "key")
                        .font(.system(size: 16, weight: .light)).foregroundStyle(K.sage)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(K.bgDeep.opacity(0.7)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Trusted people").font(KType.body(16).weight(.medium)).foregroundStyle(K.ink)
                        Text("Who can ask, and what they'd be allowed to see.")
                            .font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(K.inkFaint.opacity(0.6))
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
                .cardSurface(radius: 18)
            }
            .buttonStyle(.plain)
        }
    }

    private var treeSummary: String {
        let n = people.filter(\.inTree).count
        if n == 0 { return "Names, generation by generation, as far back as you can go." }
        let shared = people.filter { $0.inTree && $0.accessRole != .none }.count
        return shared == 0
            ? "\(n) \(n == 1 ? "name" : "names") kept"
            : "\(n) \(n == 1 ? "name" : "names") · \(shared) with access"
    }

    private var totalPieces: Int {
        memories.count + letters.count + lessons.count + recordings.count + stories.count
    }

    // MARK: Family history

    private var familyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Those who came before").eyebrowStyle(K.inkFaint)

            Button { Haptics.tap(); showTree = true } label: {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Family tree").font(.serif(20)).foregroundStyle(K.ink)
                        Text(treeSummary)
                            .font(KType.caption(13)).foregroundStyle(K.inkSoft)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.leading, 20).padding(.vertical, 20)
                    Spacer(minLength: 10)
                    Image("hero_family_field").resizable().scaledToFill()
                        .frame(width: 96, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(10)
                }
                .cardSurface(fill: K.paper)
            }
            .buttonStyle(.plain)

            Button { Haptics.tap(); showFamily = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "tree")
                        .font(.system(size: 16, weight: .light)).foregroundStyle(K.gold)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(K.goldSoft.opacity(0.28)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Family history").font(KType.body(16).weight(.medium)).foregroundStyle(K.ink)
                        Text(stories.isEmpty
                             ? "Grandparents, origins, recipes, traditions."
                             : "\(stories.count) \(stories.count == 1 ? "story" : "stories") kept")
                            .font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(K.inkFaint.opacity(0.6))
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
                .cardSurface(radius: 18)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Capsule builder

struct CapsuleBuilder: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var person: Person
    @State private var capsule: LegacyCapsule?
    @State private var preview = false

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    if let c = capsule {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 10) {
                                PersonAvatar(person: person, size: 66).padding(.top, 8)
                                Text("A capsule for \(person.name)").font(.serif(26)).foregroundStyle(K.ink)
                                Text("One collection, opened only when you decide to share it.")
                                    .font(KType.body(14.5)).foregroundStyle(K.inkSoft).lineSpacing(3)
                            }

                            FormLabel(text: "Title")
                            KField(placeholder: "Everything I want you to know", text: Binding(
                                get: { c.title }, set: { c.title = $0 }), serif: true, size: 18)

                            FormLabel(text: "The first thing they'll read")
                            KTextArea(placeholder: "If you're reading this, then…", text: Binding(
                                get: { c.openingMessage }, set: { c.openingMessage = $0 }), minHeight: 150)

                            FormLabel(text: "What's inside")
                            VStack(spacing: 0) {
                                toggleRow("Memories", count: person.memories?.count ?? 0, on: Binding(
                                    get: { c.includeMemories }, set: { c.includeMemories = $0 }))
                                HairLine()
                                toggleRow("Letters", count: person.letters?.count ?? 0, on: Binding(
                                    get: { c.includeLetters }, set: { c.includeLetters = $0 }))
                                HairLine()
                                toggleRow("Your voice", count: person.recordings?.count ?? 0, on: Binding(
                                    get: { c.includeVoice }, set: { c.includeVoice = $0 }))
                                HairLine()
                                toggleRow("Life lessons", count: nil, on: Binding(
                                    get: { c.includeLessons }, set: { c.includeLessons = $0 }))
                                HairLine()
                                toggleRow("Family history", count: nil, on: Binding(
                                    get: { c.includeFamilyHistory }, set: { c.includeFamilyHistory = $0 }))
                                HairLine()
                                toggleRow("Guidance and documents", count: nil, sensitive: true, on: Binding(
                                    get: { c.includeGuidance }, set: { c.includeGuidance = $0 }))
                            }
                            .cardSurface()

                            if c.includeGuidance {
                                HStack(spacing: 9) {
                                    Image(systemName: "exclamationmark.shield").font(.system(size: 12)).foregroundStyle(K.gold)
                                    Text("This capsule now contains sensitive information. Sharing it will ask you to confirm twice.")
                                        .font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(K.goldSoft.opacity(0.25)))
                            }

                            KButton(title: "See it as \(person.name.isEmpty ? "they" : person.name) would", icon: "eye", style: .quiet) {
                                save(); preview = true
                            }
                            .padding(.top, 6)
                        }
                        .padding(.horizontal, 22).padding(.bottom, 50)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { save(); dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) { Text("Capsule").font(.serif(16)).foregroundStyle(K.ink) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Keep") { save(); Haptics.kept(); dismiss() }
                        .font(KType.body(15).weight(.medium)).foregroundStyle(K.sageDeep)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .sheet(isPresented: $preview) { CapsuleRecipientPreview(person: person) }
        .onAppear {
            if let existing = person.capsule { capsule = existing }
            else {
                let c = LegacyCapsule(title: "Everything I want you to know")
                c.person = person
                ctx.insert(c)
                capsule = c
            }
        }
    }

    private func toggleRow(_ title: String, count: Int?, sensitive: Bool = false, on: Binding<Bool>) -> some View {
        Toggle(isOn: on) {
            HStack(spacing: 7) {
                Text(title).font(KType.body(15)).foregroundStyle(K.ink)
                if sensitive { Image(systemName: "lock.fill").font(.system(size: 8)).foregroundStyle(K.gold) }
                if let count { Text("\(count)").font(KType.caption(12)).foregroundStyle(K.inkFaint) }
            }
        }
        .tint(K.sage)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func save() { try? ctx.save() }
}
