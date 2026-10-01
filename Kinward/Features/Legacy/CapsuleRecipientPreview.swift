import SwiftUI
import SwiftData

/// What the other person would see. Seeing this is usually the moment people
/// understand what they're actually building.
struct CapsuleRecipientPreview: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var person: Person
    @Query private var lessons: [Lesson]
    @Query private var stories: [FamilyStory]

    @State private var opened = false
    @State private var readingLetter: Letter?

    var body: some View {
        ZStack {
            if !opened { envelope } else { contents }
        }
        .animation(KMotion.calm, value: opened)
        .sheet(item: $readingLetter) { l in LetterReader(letter: l) }
    }

    private var envelope: some View {
        ZStack {
            NightSky()
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: "envelope")
                    .font(.system(size: 34, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 96, height: 96)
                    .background(Circle().stroke(.white.opacity(0.3), lineWidth: 0.8))

                Text("Someone special has\nleft something for you.")
                    .font(.serif(30)).foregroundStyle(.white)
                    .multilineTextAlignment(.center).lineSpacing(3)
                    .shadow(color: .black.opacity(0.45), radius: 16, y: 4)

                if !(person.capsule?.openingMessage.isEmpty ?? true) {
                    Text("A message is waiting for you.")
                        .font(KType.body(15)).foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Button { Haptics.settle(); opened = true } label: {
                    Text("Open it").font(KType.body(16)).foregroundStyle(K.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 17)
                        .background(Capsule().fill(.white.opacity(0.96)))
                }
                .buttonStyle(.plain)
                Button { dismiss() } label: {
                    Text("Close preview").font(KType.body(14)).foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 44)
            }
            .padding(.horizontal, 30)
        }
        .preferredColorScheme(.dark)
        .transition(.opacity)
    }

    private var contents: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("For \(person.name)").eyebrowStyle(K.gold).padding(.top, 12)
                            Text(person.capsule?.title.isEmpty == false
                                 ? person.capsule!.title
                                 : "Everything I want you to know")
                                .font(.serif(31)).foregroundStyle(K.ink).lineSpacing(2)
                        }

                        if let msg = person.capsule?.openingMessage, !msg.isEmpty {
                            Text(msg)
                                .font(.hand(19)).foregroundStyle(K.ink).lineSpacing(7)
                                .padding(22)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous).fill(K.paper))
                                .overlay(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous)
                                    .strokeBorder(K.border, lineWidth: 0.8))
                                .shadow(color: K.shadowInk.opacity(0.07), radius: 16, y: 7)
                        }

                        if person.capsule?.includeLetters ?? true, let ls = person.letters, !ls.isEmpty {
                            group("Letters") {
                                VStack(spacing: 12) {
                                    ForEach(ls.sorted(by: { $0.updatedAt > $1.updatedAt })) { l in
                                        Button { Haptics.tap(); readingLetter = l } label: {
                                            LetterCard(letter: l)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        if person.capsule?.includeVoice ?? true, let rs = person.recordings, !rs.isEmpty {
                            group("Their voice") {
                                VStack(spacing: 10) {
                                    ForEach(rs.sorted(by: { $0.createdAt > $1.createdAt })) { r in
                                        VoiceBar(recording: r)
                                    }
                                }
                            }
                        }

                        if person.capsule?.includeMemories ?? true, let ms = person.memories, !ms.isEmpty {
                            group("Memories") {
                                VStack(spacing: 12) {
                                    ForEach(ms.sorted(by: { ($0.displayYear ?? 0) > ($1.displayYear ?? 0) })) { m in
                                        MemoryCard(memory: m)
                                    }
                                }
                            }
                        }

                        if person.capsule?.includeLessons ?? true, !lessons.isEmpty {
                            group("What they learned") {
                                VStack(spacing: 12) {
                                    ForEach(lessons.prefix(6)) { l in LessonCard(lesson: l) }
                                }
                            }
                        }

                        if person.capsule?.includeFamilyHistory ?? true, !stories.isEmpty {
                            group("Where you come from") {
                                VStack(spacing: 12) {
                                    ForEach(stories.prefix(6)) { s in FamilyStoryCard(story: s) }
                                }
                            }
                        }

                        if let bs = person.belongings, !bs.isEmpty {
                            group("Things they wanted you to have") {
                                VStack(spacing: 10) {
                                    ForEach(bs) { b in
                                        ArchiveRow(title: b.name, subtitle: b.location.isEmpty ? b.detail : b.location,
                                                   icon: "shippingbox", imageRef: b.photoRefs.first, showsChevron: false)
                                    }
                                }
                            }
                        }

                        if isEmptyCapsule {
                            QuietEmptyState(icon: "circle.hexagongrid",
                                            title: "Nothing in here yet",
                                            message: "Write \(person.name) a letter, record something, or tag them in a memory — it will appear here.")
                        }

                        Marginalia(text: "This is what they'd find.")
                            .padding(.top, 6).padding(.bottom, 20)
                    }
                    .padding(.horizontal, 22).padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye").font(.system(size: 11))
                        Text("Preview").font(KType.label(13))
                    }
                    .foregroundStyle(K.inkFaint)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .transition(.opacity)
    }

    private var isEmptyCapsule: Bool {
        (person.letters?.isEmpty ?? true) && (person.memories?.isEmpty ?? true)
            && (person.recordings?.isEmpty ?? true) && (person.belongings?.isEmpty ?? true)
    }

    private func group<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title).eyebrowStyle(K.inkFaint)
            content()
        }
    }
}

/// A letter as the recipient reads it — no fields, just paper.
struct LetterReader: View {
    @Environment(\.dismiss) private var dismiss
    let letter: Letter
    @AppStorage(LetterFace.storageKey) private var faceRaw = LetterFace.hand.rawValue
    private var face: LetterFace { LetterFace(rawValue: faceRaw) ?? .hand }

    var body: some View {
        ZStack {
            LinearGradient(colors: [K.bgDeep, K.bg], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if !letter.salutation.isEmpty {
                        Text(letter.salutation).font(face.font(23)).foregroundStyle(K.ink)
                    }
                    Text(letter.body.isEmpty ? "…" : letter.body)
                        .font(face.font(20)).foregroundStyle(K.ink).lineSpacing(face.lineSpacing(9))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !letter.photoRefs.isEmpty {
                        HStack(spacing: -18) {
                            ForEach(Array(letter.photoRefs.prefix(3).enumerated()), id: \.offset) { i, ref in
                                MediaImage(ref: ref)
                                    .frame(width: 116, height: 138)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(7)
                                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
                                    .shadow(color: K.shadowInk.opacity(0.18), radius: 9, y: 4)
                                    .rotationEffect(.degrees(Double(i) * 5.5 - 4))
                            }
                        }
                        .padding(.vertical, 10)
                    }

                    if !letter.signature.isEmpty {
                        Text(letter.signature).font(face.font(23)).foregroundStyle(K.ink).padding(.top, 4)
                    }

                    if let ref = letter.audioRef, MediaStore.exists(ref) {
                        Button { Haptics.tap(); VoicePlayer.shared.toggle(ref: ref) } label: {
                            HStack(spacing: 11) {
                                Image(systemName: VoicePlayer.shared.playingRef == ref && VoicePlayer.shared.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 12)).foregroundStyle(K.onAccent)
                                    .frame(width: 34, height: 34).background(Circle().fill(K.sageDeep))
                                Text("Hear it read aloud").font(KType.body(14.5)).foregroundStyle(K.ink)
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(Capsule().fill(K.bgDeep.opacity(0.7)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                    }
                }
                .padding(28)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: K.rLarge, style: .continuous).fill(K.paper)
                        GrainOverlay(opacity: 0.03).clipShape(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous))
                        if !K.isClear {
                            AgeMarks(age: K.age, salt: 0x1E77E7)
                                .clipShape(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous))
                        }
                    }
                    .shadow(color: K.shadowInk.opacity(0.12), radius: 26, y: 12)
                )
                .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 40)
            }
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .medium))
                            .foregroundStyle(K.ink).frame(width: 36, height: 36)
                            .background(Circle().fill(K.surface.opacity(0.9)))
                            .shadow(color: K.shadowInk.opacity(0.08), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 14)
        }
    }
}
