import SwiftUI
import SwiftData

/// Everything that belongs to one person, gathered in one place.
struct PersonDetail: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var person: Person

    @State private var editing = false
    @State private var openLetter: Letter?
    @State private var openMemory: MemoryEntry?
    @State private var showRecorder = false
    @State private var showCapsule = false
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        header
                        if person.accessRequestedAt != nil { accessRequest }
                        shareCard
                        capsuleCard
                        lettersBlock
                        memoriesBlock
                        voiceBlock
                        belongingsBlock
                        if !person.notes.isEmpty { notesBlock }
                        Marginalia(text: "Everything here\nis for \(person.name.isEmpty ? "them" : person.name).")
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 22).padding(.bottom, 60)
                }
            }
            // Attached here rather than to the stack of sheet modifiers below: six
            // `.sheet`s on one view is more than SwiftUI reliably tracks, and the
            // sixth one presents with its content unable to take a touch.
            .sheet(isPresented: $showShare) { SharePersonSheet(person: person) }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); editing = true } label: {
                        Image(systemName: "square.and.pencil").foregroundStyle(K.ink)
                    }
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .sheet(isPresented: $editing) { PersonEditor(person: person) }
        .sheet(item: $openLetter) { l in LetterEditor(letter: l) }
        .sheet(item: $openMemory) { m in MemoryEditor(memory: m) }
        .sheet(isPresented: $showRecorder) {
            VoiceRecorderSheet(presetTitle: "For \(person.name)", presetPerson: person)
        }
        .sheet(isPresented: $showCapsule) { CapsuleBuilder(person: person) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            PersonAvatar(person: person, size: 92).padding(.top, 6)
            VStack(alignment: .leading, spacing: 5) {
                Text(person.name.isEmpty ? "Unnamed" : person.name)
                    .font(.serif(32)).foregroundStyle(K.ink)
                Text(person.relationship.isEmpty ? "Someone who matters" : person.relationship)
                    .eyebrowStyle(K.gold)
                if let b = person.birthday {
                    Text(b.formatted(date: .long, time: .omitted))
                        .font(KType.caption(12.5)).foregroundStyle(K.inkFaint)
                }
            }
            Text("Everything I want \(person.name.isEmpty ? "them" : person.name) to know, remember and have.")
                .font(KType.body(15.5)).foregroundStyle(K.inkSoft).lineSpacing(3)

            HStack(spacing: 9) {
                actionChip(icon: "envelope", title: "Write") {
                    let l = Letter(); l.recipient = person
                    l.title = "To my \(person.relationship.lowercased().isEmpty ? "dear one" : person.relationship.lowercased())"
                    l.salutation = "My dear \(person.name),"
                    ctx.insert(l); openLetter = l
                }
                actionChip(icon: "mic", title: "Record") { showRecorder = true }
                actionChip(icon: "photo", title: "Memory") {
                    let m = MemoryEntry(); m.people = [person]; m.isDraft = true
                    ctx.insert(m); openMemory = m
                }
            }
        }
    }

    private func actionChip(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 12, weight: .light))
                Text(title).font(KType.body(14))
            }
            .foregroundStyle(K.ink)
            .padding(.horizontal, 15).padding(.vertical, 10)
            .background(Capsule().fill(K.surface).overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
        }
        .buttonStyle(.plain)
    }

    private var accessRequest: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised").font(.system(size: 13)).foregroundStyle(K.gold)
                Text("\(person.name) requested access").font(KType.body(15).weight(.medium)).foregroundStyle(K.ink)
            }
            Text("\u{201C}I'd like to see what you've prepared for me.\u{201D}")
                .font(.serif(17)).foregroundStyle(K.inkSoft).italic()
            HStack(spacing: 10) {
                Button {
                    Haptics.kept()
                    person.accessGranted = ["Memories", "Letters", "Voice", "Lessons"]
                    person.accessRequestedAt = nil
                    try? ctx.save()
                } label: {
                    Text("Approve").font(KType.body(14)).foregroundStyle(K.surface)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Capsule().fill(K.sageDeep))
                }
                .buttonStyle(.plain)
                Button {
                    Haptics.tap()
                    person.accessRequestedAt = nil
                    person.lockoutUntil = Calendar.current.date(byAdding: .day, value: 90, to: .now)
                    try? ctx.save()
                } label: {
                    Text("Not yet").font(KType.body(14)).foregroundStyle(K.ink)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Capsule().strokeBorder(K.border, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .cardSurface(radius: K.rLarge, fill: K.paper)
    }

    /// Everything they're allowed to see, gathered into one file to hand over.
    private var shareCard: some View {
        Button { Haptics.tap(); showShare = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(K.gold)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(K.paper))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Send what they can see").font(KType.body(15.5)).foregroundStyle(K.ink)
                    Text(shareSubtitle).font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(K.inkFaint)
            }
            .padding(16)
            .cardSurface(radius: K.rLarge)
        }
        .buttonStyle(.plain)
    }

    private var shareSubtitle: String {
        let n = person.accessGranted.count
        if n == 0 { return "Nothing opened to them yet — or send the lot" }
        return "\(n) area\(n == 1 ? "" : "s") open to them, as one file"
    }

    private var capsuleCard: some View {
        Button { Haptics.tap(); showCapsule = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(K.sageDeep).frame(width: 46, height: 46)
                    Image(systemName: "circle.hexagongrid").font(.system(size: 17, weight: .light))
                        .foregroundStyle(K.surface)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(person.capsule == nil ? "Build their capsule" : (person.capsule?.title ?? "Their capsule"))
                        .font(KType.body(16).weight(.medium)).foregroundStyle(K.ink)
                    Text(person.capsule == nil
                         ? "One collection, gathered for \(person.name.isEmpty ? "them" : person.name)."
                         : "Ready when you choose to share it.")
                        .font(KType.caption(12.5)).foregroundStyle(K.inkSoft).lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundStyle(K.inkFaint.opacity(0.6))
            }
            .padding(16)
            .cardSurface(fill: K.paper)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var lettersBlock: some View {
        let items = person.letters ?? []
        if !items.isEmpty {
            block(title: "Letters") {
                VStack(spacing: 10) {
                    ForEach(items.sorted(by: { $0.updatedAt > $1.updatedAt })) { l in
                        Button { Haptics.tap(); openLetter = l } label: {
                            ArchiveRow(title: l.title.isEmpty ? "Untitled letter" : l.title,
                                       subtitle: l.isSealed ? l.seal.title : String(l.body.prefix(60)),
                                       icon: l.isSealed ? "lock" : "envelope")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var memoriesBlock: some View {
        let items = person.memories ?? []
        if !items.isEmpty {
            block(title: "Memories with \(person.name)") {
                VStack(spacing: 10) {
                    ForEach(items.sorted(by: { $0.createdAt > $1.createdAt })) { m in
                        Button { Haptics.tap(); openMemory = m } label: {
                            ArchiveRow(title: m.title.isEmpty ? "Untitled" : m.title,
                                       subtitle: m.displayYear.map(String.init) ?? String(m.story.prefix(50)),
                                       icon: "photo.on.rectangle.angled",
                                       imageRef: m.photoRefs.first)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var voiceBlock: some View {
        let items = person.recordings ?? []
        if !items.isEmpty {
            block(title: "Your voice, for them") {
                VStack(spacing: 10) {
                    ForEach(items.sorted(by: { $0.createdAt > $1.createdAt })) { r in
                        VoiceBar(recording: r)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var belongingsBlock: some View {
        let items = person.belongings ?? []
        if !items.isEmpty {
            block(title: "Things for them") {
                VStack(spacing: 10) {
                    ForEach(items) { b in
                        ArchiveRow(title: b.name, subtitle: b.location, icon: "shippingbox",
                                   imageRef: b.photoRefs.first, showsChevron: false)
                    }
                }
            }
        }
    }

    private var notesBlock: some View {
        block(title: "Notes") {
            Text(person.notes)
                .font(KType.body(15)).foregroundStyle(K.inkSoft).lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18).cardSurface()
        }
    }

    private func block<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).eyebrowStyle(K.inkFaint)
            content()
        }
    }
}
