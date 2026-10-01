import SwiftData
import SwiftUI

// MARK: - The line that says where something came from

/// Shown on anything that didn't start here. Small, but it is the whole point:
/// three generations on, a grandchild can still see whose hands this came through.
struct ChainLine: View {
    let chain: [String]
    var size: CGFloat = 12
    var body: some View {
        if !chain.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "arrow.down.forward.and.arrow.up.backward.circle")
                    .font(.system(size: size - 1, weight: .light))
                Text("Passed down from \(chain.asChain)")
                    .font(KType.caption(size))
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(K.gold)
        }
    }
}

// MARK: - Passing it on

/// Builds the one file another copy of Kinward can open.
///
/// Everything already passed down to this user is in here too — that is what makes
/// it a chain rather than a single handover.
struct PassItOnSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var profiles: [UserProfile]
    @Query(sort: \Person.createdAt) private var people: [Person]

    /// nil means "not addressed to anyone in particular".
    @State var person: Person?
    @State private var kinds: Set<Heirloom.Kind> = Set(Heirloom.Kind.allCases)
    @State private var parcel: Heirloom.Parcel?
    @State private var file: URL?
    @State private var working = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        whoBlock
                        whatBlock
                        inheritedBlock
                        actions
                        Marginalia(text: "It doesn't stop\nwith them.").padding(.top, 2)
                    }
                    .padding(.horizontal, 22).padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    Text("Pass it on").font(.serif(16)).foregroundStyle(K.ink)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .onAppear(perform: refresh)
        .onChange(of: kinds) { _, _ in refresh() }
        .alert("It couldn't be prepared", isPresented: Binding(
            get: { failure != nil }, set: { if !$0 { failure = nil } }
        )) {
            Button("All right", role: .cancel) { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("So it keeps going")
                .font(.serif(28)).foregroundStyle(K.ink).padding(.top, 6)
            Text("A file only Kinward opens. Whoever you send it to gets these pieces in their own archive — and can pass the same ones on to their children, with your name still on them.")
                .font(KType.body(15)).foregroundStyle(K.inkSoft).lineSpacing(3)
        }
    }

    private var whoBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            FormLabel(text: "Who it's going to")
            PersonPickerRow(people: people, selection: $person)
                .onChange(of: person?.id) { _, _ in refresh() }
        }
    }

    private var whatBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            FormLabel(text: "What travels")
            FlowLayout(spacing: 8) {
                ForEach(Heirloom.Kind.allCases, id: \.self) { kind in
                    let on = kinds.contains(kind)
                    let n = parcel?.count(kind) ?? 0
                    Button {
                        Haptics.tap()
                        withAnimation(KMotion.gentle) {
                            if on { kinds.remove(kind) } else { kinds.insert(kind) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(kind.plural.capitalizedFirst).font(KType.body(13.5))
                            if on, n > 0 {
                                Text("\(n)").font(KType.caption(11.5)).opacity(0.75)
                            }
                        }
                        .foregroundStyle(on ? K.onAccent : K.ink)
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .background(Capsule().fill(on ? K.sageDeep : K.surface)
                            .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Guidance, documents and anything financial stay behind. Those are for whoever settles things now, not for grandchildren.")
                .font(KType.caption(12)).foregroundStyle(K.inkFaint).lineSpacing(2)
        }
    }

    @ViewBuilder
    private var inheritedBlock: some View {
        let onward = parcel?.items.filter { $0.passedDown.count > 1 } ?? []
        if !onward.isEmpty {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 13, weight: .light)).foregroundStyle(K.gold)
                Text("\(onward.count) of these \(onward.count == 1 ? "was" : "were") passed to you by somebody else. \(onward.count == 1 ? "It goes" : "They go") on with this, still carrying their name.")
                    .font(KType.body(14)).foregroundStyle(K.ink).lineSpacing(3)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(K.goldSoft.opacity(0.22)))
        }
    }

    @ViewBuilder
    private var actions: some View {
        if let file {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    Haptics.tap()
                    SystemShare.present(file)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 13, weight: .medium))
                        Text("Send it on").font(KType.body(16))
                    }
                    .foregroundStyle(K.onAccent)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Capsule().fill(K.sageDeep))
                }
                .buttonStyle(.plain)
                Text("\(file.lastPathComponent) · \(fileSize(file)) — they open it with Kinward.")
                    .font(KType.caption(12)).foregroundStyle(K.inkSoft).lineSpacing(2)
                Button("Build it again") { self.file = nil }
                    .font(KType.body(14)).foregroundStyle(K.inkFaint)
            }
        } else if let parcel, !parcel.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button(action: prepare) {
                    HStack(spacing: 8) {
                        if working { ProgressView().tint(K.onAccent) }
                        Text(working ? "Gathering it up…" : "Prepare it").font(KType.body(16))
                    }
                    .foregroundStyle(K.onAccent)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Capsule().fill(K.sageDeep))
                }
                .buttonStyle(.plain)
                .disabled(working)
                Text(summary(parcel)).font(KType.caption(12)).foregroundStyle(K.inkSoft)
            }
        } else {
            QuietEmptyState(icon: "tray",
                            title: "Nothing to pass on yet",
                            message: "Write something down first, then it has somewhere to go.")
        }
    }

    private func summary(_ p: Heirloom.Parcel) -> String {
        Heirloom.Kind.allCases.compactMap { k -> String? in
            let n = p.count(k)
            guard n > 0 else { return nil }
            return "\(n) \(n == 1 ? k.one : k.plural)"
        }.joined(separator: " · ")
    }

    private func fileSize(_ url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return ByteCountFormatter.string(fromByteCount: (attrs?[.size] as? NSNumber)?.int64Value ?? 0,
                                         countStyle: .file)
    }

    private func refresh() {
        file = nil
        parcel = Heirloom.pack(for: person, kinds: kinds, from: profiles.first, in: ctx)
    }

    private func prepare() {
        guard let parcel, !parcel.isEmpty else { return }
        working = true
        Task {
            do {
                // Encoding embeds and compresses every photograph, so it stays off the
                // main actor no matter how big the archive has become.
                let url = try await Task.detached(priority: .userInitiated) {
                    try Heirloom.write(parcel)
                }.value
                file = url
                Haptics.kept()
            } catch {
                failure = error.localizedDescription
            }
            working = false
        }
    }
}

// MARK: - Opening one somebody sent you

/// What arrived, said plainly. Shown after a parcel has already been written in.
struct HeirloomArrivedSheet: View {
    @Environment(\.dismiss) private var dismiss
    let outcome: Heirloom.Outcome

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(outcome.total > 0 ? "It's yours now" : "Nothing new arrived")
                            .font(.serif(30)).foregroundStyle(K.ink).padding(.top, 14)

                        Text(outcome.total > 0
                             ? "\(outcome.from) passed these to you. They're in your Kinward, and they'll go on to whoever you pass them to next."
                             : "You already had everything in that parcel.")
                            .font(KType.body(15)).foregroundStyle(K.inkSoft).lineSpacing(3)

                        if outcome.total > 0 {
                            VStack(spacing: 0) {
                                ForEach(Heirloom.Kind.allCases, id: \.self) { kind in
                                    let n = outcome.added[kind] ?? 0
                                    if n > 0 {
                                        HStack {
                                            Text("\(n)").font(.serif(21)).foregroundStyle(K.ink)
                                                .frame(minWidth: 34, alignment: .leading)
                                            Text(n == 1 ? kind.one : kind.plural)
                                                .font(KType.body(15)).foregroundStyle(K.inkSoft)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 13)
                                        if kind != Heirloom.Kind.allCases.last { HairLine() }
                                    }
                                }
                            }
                            .cardSurface()
                        }

                        if outcome.alreadyHad > 0 {
                            Text("\(outcome.alreadyHad) \(outcome.alreadyHad == 1 ? "piece was" : "pieces were") already here and \(outcome.alreadyHad == 1 ? "was" : "were") left alone.")
                                .font(KType.caption(12.5)).foregroundStyle(K.inkFaint).lineSpacing(2)
                        }

                        Marginalia(text: "Someone kept this\nso you could have it.").padding(.top, 8)
                    }
                    .padding(.horizontal, 22).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(KType.body(15).weight(.medium)).foregroundStyle(K.sageDeep)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
    }
}

// MARK: - Everything that came from somebody else

struct PassedDownView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var memories: [MemoryEntry]
    @Query private var letters: [Letter]
    @Query private var lessons: [Lesson]
    @Query private var stories: [FamilyStory]
    @Query private var recordings: [VoiceRecording]

    private struct Row: Identifiable {
        let id: String
        let kind: Heirloom.Kind
        let title: String
        let body: String
        let chain: [String]
    }

    private var rows: [Row] {
        var out: [Row] = []
        out += memories.filter { !$0.passedDown.isEmpty }.map {
            Row(id: $0.heirloomID, kind: .memory,
                title: $0.title.isEmpty ? "A memory" : $0.title, body: $0.story, chain: $0.passedDown)
        }
        out += letters.filter { !$0.passedDown.isEmpty }.map {
            Row(id: $0.heirloomID, kind: .letter,
                title: $0.title.isEmpty ? "A letter" : $0.title, body: $0.body, chain: $0.passedDown)
        }
        out += lessons.filter { !$0.passedDown.isEmpty }.map {
            Row(id: $0.heirloomID, kind: .lesson,
                title: $0.headline.isEmpty ? $0.category.title : $0.headline, body: $0.body, chain: $0.passedDown)
        }
        out += stories.filter { !$0.passedDown.isEmpty }.map {
            Row(id: $0.heirloomID, kind: .story,
                title: $0.title.isEmpty ? $0.subject : $0.title, body: $0.body, chain: $0.passedDown)
        }
        out += recordings.filter { !$0.passedDown.isEmpty }.map {
            Row(id: $0.heirloomID, kind: .voice,
                title: $0.title.isEmpty ? "A recording" : $0.title, body: $0.note, chain: $0.passedDown)
        }
        return out
    }

    /// Grouped by whoever it started with, because that is how a family talks about it.
    private var byOrigin: [(String, [Row])] {
        Dictionary(grouping: rows) { $0.chain.first ?? "" }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("What reached you")
                            .font(.serif(30)).foregroundStyle(K.ink).padding(.top, 12)

                        if rows.isEmpty {
                            QuietEmptyState(icon: "arrow.down.forward.and.arrow.up.backward.circle",
                                            title: "Nothing has been passed to you yet",
                                            message: "When someone sends you their Kinward parcel, what's inside lands here — and carries on from you.")
                        } else {
                            ForEach(byOrigin, id: \.0) { origin, items in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(origin.isEmpty ? "Family" : origin).eyebrowStyle(K.gold)
                                    ForEach(items) { row in
                                        VStack(alignment: .leading, spacing: 7) {
                                            Text(row.title).font(.serif(18)).foregroundStyle(K.ink)
                                                .multilineTextAlignment(.leading)
                                            if !row.body.isEmpty {
                                                Text(row.body).font(KType.body(14))
                                                    .foregroundStyle(K.inkSoft)
                                                    .lineLimit(3).lineSpacing(2)
                                                    .multilineTextAlignment(.leading)
                                            }
                                            HStack(spacing: 8) {
                                                PillTag(text: row.kind.one.capitalizedFirst)
                                                Spacer(minLength: 0)
                                            }
                                            ChainLine(chain: row.chain, size: 11.5)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(16)
                                        .cardSurface(fill: K.paper)
                                    }
                                }
                            }
                        }

                        Marginalia(text: "It didn't start with you,\nand it doesn't end here.")
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 22).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
    }
}

extension String {
    var capitalizedFirst: String { isEmpty ? self : prefix(1).uppercased() + dropFirst() }
}
