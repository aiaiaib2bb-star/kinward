import SwiftUI
import SwiftData

struct MemoriesView: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var router: Router
    @Query(sort: \MemoryEntry.createdAt, order: .reverse) private var memories: [MemoryEntry]
    @Query(sort: \VoiceRecording.createdAt, order: .reverse) private var recordings: [VoiceRecording]

    enum Mode: String, CaseIterable { case all = "All", timeline = "Timeline", grid = "Photos", voice = "Voice", places = "Places" }
    @State private var mode: Mode = .all
    @State private var editing: MemoryEntry?
    @State private var showRecorder = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(title: "Memories",
                              subtitle: "What happened, and the story behind it.",
                              onBack: { router.goHome() },
                              trailing: { AnyView(RoundIconButton(icon: "plus") { newMemory() }) })

                segmented

                switch mode {
                case .all:      allList
                case .timeline: LifeTimeline(memories: memories) { editing = $0 }
                case .grid:     photoGrid
                case .voice:    voiceList
                case .places:   placesList
                }

                Marginalia(text: KinwardSection.memories.marginalia).padding(.top, 8)
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 190)
        }
        .background(PaperBackground())
        .sheet(item: $editing) { m in MemoryEditor(memory: m) }
        .sheet(isPresented: $showRecorder) { VoiceRecorderSheet() }
    }

    private var segmented: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Button { Haptics.tap(); withAnimation(KMotion.gentle) { mode = m } } label: {
                        Text(m.rawValue)
                            .font(KType.body(13.5))
                            .foregroundStyle(mode == m ? K.surface : K.inkSoft)
                            .padding(.horizontal, 15).padding(.vertical, 9)
                            .background(Capsule().fill(mode == m ? K.sageDeep : K.surface)
                                .overlay(Capsule().strokeBorder(mode == m ? .clear : K.border, lineWidth: 0.8)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var allList: some View {
        if memories.isEmpty {
            QuietEmptyState(icon: "photo.on.rectangle.angled",
                            title: "Nothing kept yet",
                            message: "A memory is a moment plus the reason it mattered. Start with one you'd hate to lose.",
                            actionTitle: "Keep a memory") { newMemory() }
        } else {
            VStack(spacing: 12) {
                ForEach(memories) { m in
                    Button { Haptics.tap(); editing = m } label: { MemoryCard(memory: m) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { delete(m) } label: { Label("Delete", systemImage: "trash") }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var photoGrid: some View {
        let all = memories.flatMap { m in m.photoRefs.map { (m, $0) } }
        if all.isEmpty {
            QuietEmptyState(icon: "photo", title: "No photographs yet",
                            message: "Photographs anchor a story. Add a few to any memory and they'll gather here.")
        } else {
            LazyVGrid(columns: [.init(.flexible(), spacing: 6), .init(.flexible(), spacing: 6), .init(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(Array(all.enumerated()), id: \.offset) { _, pair in
                    Button { Haptics.tap(); editing = pair.0 } label: {
                        MediaImage(ref: pair.1)
                            .aspectRatio(1, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var voiceList: some View {
        if recordings.isEmpty {
            QuietEmptyState(icon: "waveform", title: "Your voice isn't here yet",
                            message: "Sometimes a voice says more than words. It takes a minute.",
                            actionTitle: "Record something") { showRecorder = true }
        } else {
            VStack(spacing: 10) {
                ForEach(recordings) { r in
                    VStack(alignment: .leading, spacing: 8) {
                        VoiceBar(recording: r)
                        HStack(spacing: 8) {
                            if let p = r.person {
                                PillTag(text: "For \(p.name)")
                            }
                            Text(r.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(KType.caption(11.5)).foregroundStyle(K.inkFaint)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            MediaStore.delete(r.fileRef); ctx.delete(r); try? ctx.save()
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                Button { Haptics.tap(); showRecorder = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "mic").font(.system(size: 13, weight: .light))
                        Text("Record something new").font(KType.body(14.5))
                    }
                    .foregroundStyle(K.ink).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(K.surface).overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var placesList: some View {
        let grouped = Dictionary(grouping: memories.filter { !$0.place.isEmpty }, by: { $0.place })
        if grouped.isEmpty {
            QuietEmptyState(icon: "mappin.and.ellipse", title: "No places yet",
                            message: "Add a place to a memory and your family will know where to stand one day.")
        } else {
            VStack(spacing: 12) {
                ForEach(grouped.keys.sorted(), id: \.self) { place in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin").font(.system(size: 12)).foregroundStyle(K.gold)
                            Text(place).font(.serif(19)).foregroundStyle(K.ink)
                            Spacer()
                            Text("\(grouped[place]?.count ?? 0)").font(KType.caption(12)).foregroundStyle(K.inkFaint)
                        }
                        ForEach(grouped[place] ?? []) { m in
                            Button { Haptics.tap(); editing = m } label: {
                                HStack(spacing: 10) {
                                    Rectangle().fill(K.border).frame(width: 0.8, height: 26)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(m.title.isEmpty ? "Untitled" : m.title)
                                            .font(KType.body(14.5)).foregroundStyle(K.ink).lineLimit(1)
                                        if let y = m.displayYear {
                                            Text(String(y)).font(KType.caption(11.5)).foregroundStyle(K.inkFaint)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .cardSurface()
                }
            }
        }
    }

    private func newMemory() {
        let m = MemoryEntry(); m.isDraft = true
        ctx.insert(m); editing = m
    }
    private func delete(_ m: MemoryEntry) {
        m.photoRefs.forEach { MediaStore.delete($0) }
        MediaStore.delete(m.audioRef)
        ctx.delete(m); try? ctx.save(); Haptics.tap()
    }
}

// MARK: - Card

struct MemoryCard: View {
    let memory: MemoryEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let first = memory.photoRefs.first {
                MediaImage(ref: first)
                    .frame(height: 168)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        if memory.photoRefs.count > 1 {
                            Text("\(memory.photoRefs.count) photographs")
                                .font(KType.caption(11)).foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(.black.opacity(0.35)))
                                .padding(12)
                        }
                    }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let y = memory.displayYear {
                        Text(String(y)).eyebrowStyle(K.gold)
                    }
                    if !memory.place.isEmpty {
                        Text("·").foregroundStyle(K.inkFaint)
                        Text(memory.place).font(KType.caption(11.5)).foregroundStyle(K.inkFaint)
                    }
                    Spacer()
                    if memory.audioRef != nil {
                        Image(systemName: "waveform").font(.system(size: 11)).foregroundStyle(K.sage)
                    }
                }
                Text(memory.title.isEmpty ? "Untitled memory" : memory.title)
                    .font(.serif(20)).foregroundStyle(K.ink)
                    .multilineTextAlignment(.leading).lineLimit(2)
                if !memory.story.isEmpty {
                    Text(memory.story)
                        .font(KType.body(14.5)).foregroundStyle(K.inkSoft)
                        .lineSpacing(3).lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                if let ppl = memory.people, !ppl.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(ppl.prefix(4)) { p in PersonAvatar(person: p, size: 24) }
                        Text(ppl.map(\.name).joined(separator: ", "))
                            .font(KType.caption(11.5)).foregroundStyle(K.inkFaint)
                            .padding(.leading, 14).lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(18)
        }
        .background(RoundedRectangle(cornerRadius: K.rCard, style: .continuous).fill(K.surface))
        .clipShape(RoundedRectangle(cornerRadius: K.rCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: K.rCard, style: .continuous).strokeBorder(K.border, lineWidth: 0.8))
        .shadow(color: K.ink.opacity(0.05), radius: 14, y: 6)
    }
}

// MARK: - Life timeline

struct LifeTimeline: View {
    let memories: [MemoryEntry]
    var onTap: (MemoryEntry) -> Void

    private var years: [(Int, [MemoryEntry])] {
        let dated = memories.compactMap { m -> (Int, MemoryEntry)? in m.displayYear.map { ($0, m) } }
        let grouped = Dictionary(grouping: dated, by: { $0.0 })
        return grouped.map { ($0.key, $0.value.map(\.1)) }.sorted { $0.0 > $1.0 }
    }
    private var undated: [MemoryEntry] { memories.filter { $0.displayYear == nil } }

    var body: some View {
        if memories.isEmpty {
            QuietEmptyState(icon: "calendar", title: "A life, in order",
                            message: "Give a memory a year and it takes its place on your timeline.")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(years, id: \.0) { year, items in
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 0) {
                            Text(String(year))
                                .font(.serif(17)).foregroundStyle(K.ink)
                                .frame(width: 52, alignment: .leading)
                            Rectangle().fill(K.border).frame(width: 0.8)
                                .frame(maxHeight: .infinity)
                                .padding(.leading, -26)
                        }
                        .frame(width: 52)

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(items) { m in
                                Button { Haptics.tap(); onTap(m) } label: {
                                    HStack(spacing: 12) {
                                        Circle().fill(K.gold).frame(width: 6, height: 6)
                                            .offset(x: -21)
                                            .frame(width: 0)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(m.title.isEmpty ? "Untitled" : m.title)
                                                .font(KType.body(15).weight(.medium)).foregroundStyle(K.ink)
                                                .multilineTextAlignment(.leading)
                                            if !m.story.isEmpty {
                                                Text(m.story).font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                                                    .lineLimit(2).multilineTextAlignment(.leading)
                                            }
                                            Text(m.stage.title).eyebrowStyle(K.inkFaint.opacity(0.8))
                                        }
                                        Spacer(minLength: 0)
                                        if let ref = m.photoRefs.first {
                                            MediaImage(ref: ref).frame(width: 46, height: 46)
                                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                    }
                                    .padding(14)
                                    .cardSurface(radius: 16)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 18)
                    }
                }
                if !undated.isEmpty {
                    Text("Undated").eyebrowStyle(K.inkFaint).padding(.top, 10).padding(.bottom, 10)
                    VStack(spacing: 10) {
                        ForEach(undated) { m in
                            Button { Haptics.tap(); onTap(m) } label: {
                                ArchiveRow(title: m.title.isEmpty ? "Untitled" : m.title,
                                           subtitle: String(m.story.prefix(60)),
                                           icon: "photo.on.rectangle.angled")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
