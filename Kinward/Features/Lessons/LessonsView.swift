import SwiftUI
import SwiftData

struct LessonsView: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var router: Router
    @Environment(\.navBottomInset) private var navBottomInset
    @Query(sort: \Lesson.updatedAt, order: .reverse) private var lessons: [Lesson]

    @State private var editing: Lesson?
    @State private var filter: LessonCategory?
    @State private var showPrompts = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(title: "What life\ntaught you.",
                              subtitle: "The part that can actually be passed on.",
                              onBack: { router.goHome() },
                              trailing: { AnyView(RoundIconButton(icon: "plus") { newLesson(nil) }) })

                promptCard

                if !lessons.isEmpty { filters }

                if lessons.isEmpty {
                    QuietEmptyState(icon: "lightbulb",
                                    title: "Nothing written down yet",
                                    message: "You know things that took decades to learn. Write one down before it feels obvious.",
                                    actionTitle: "Start with a question") { showPrompts = true }
                } else {
                    VStack(spacing: 12) {
                        ForEach(shown) { l in
                            Button { Haptics.tap(); editing = l } label: { LessonCard(lesson: l) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        MediaStore.delete(l.audioRef); ctx.delete(l); try? ctx.save()
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }

                categoriesBlock
                Marginalia(text: KinwardSection.lessons.marginalia).padding(.top, 8)
            }
            .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, navBottomInset)
        }
        .background(PaperBackground())
        .overlay(alignment: .top) { StatusBarScrim() }
        .sheet(item: $editing) { l in LessonEditor(lesson: l) }
        .sheet(isPresented: $showPrompts) {
            PromptDeck(themes: [.lessons, .legacy, .belief, .hardship, .work, .love]) { q in
                showPrompts = false
                let l = Lesson(category: .whatLifeTaught)
                l.prompt = q.text
                ctx.insert(l)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { editing = l }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var shown: [Lesson] {
        guard let f = filter else { return lessons }
        return lessons.filter { $0.category == f }
    }

    private var promptCard: some View {
        Button { Haptics.tap(); showPrompts = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 17, weight: .light)).foregroundStyle(K.gold)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(K.goldSoft.opacity(0.28)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Answer a question instead").font(KType.body(15.5).weight(.medium)).foregroundStyle(K.ink)
                    Text("Easier than starting from a blank page.").font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundStyle(K.inkFaint.opacity(0.6))
            }
            .padding(16).cardSurface(fill: K.paper)
        }
        .buttonStyle(.plain)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", on: filter == nil) { filter = nil }
                ForEach(usedCategories) { c in
                    chip(c.title, on: filter == c) { filter = c }
                }
            }
            .padding(.vertical, 2)
        }
        .fadingTrailingEdge()
    }
    private var usedCategories: [LessonCategory] {
        LessonCategory.allCases.filter { c in lessons.contains { $0.category == c } }
    }
    private func chip(_ t: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); withAnimation(KMotion.gentle) { action() } } label: {
            Text(t).font(KType.body(13.5))
                .foregroundStyle(on ? K.onAccent : K.inkSoft)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(on ? K.sageDeep : K.surface)
                    .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
        }
        .buttonStyle(.plain)
    }

    private var categoriesBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Write about").eyebrowStyle(K.inkFaint)
            LazyVGrid(columns: [.init(.flexible(), spacing: 10), .init(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(LessonCategory.allCases) { c in
                    Button { Haptics.tap(); newLesson(c) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: c.icon).font(.system(size: 13, weight: .light)).foregroundStyle(K.sage)
                            Text(c.title).font(KType.body(13.5)).foregroundStyle(K.ink)
                                .multilineTextAlignment(.leading).lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardSurface(radius: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func newLesson(_ c: LessonCategory?) {
        let l = Lesson(category: c ?? .whatLifeTaught)
        ctx.insert(l); editing = l
    }
}

struct LessonCard: View {
    let lesson: Lesson
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: lesson.category.icon).font(.system(size: 11)).foregroundStyle(K.gold)
                Text(lesson.category.title).eyebrowStyle(K.gold)
                Spacer()
                if lesson.audioRef != nil {
                    Image(systemName: "waveform").font(.system(size: 11)).foregroundStyle(K.sage)
                }
            }
            if !lesson.prompt.isEmpty {
                Text(lesson.prompt).font(KType.caption(12.5)).foregroundStyle(K.inkFaint)
                    .italic().multilineTextAlignment(.leading)
            }
            Text(lesson.headline.isEmpty ? "Untitled" : lesson.headline)
                .font(.serif(20)).foregroundStyle(K.ink)
                .multilineTextAlignment(.leading)
            if !lesson.body.isEmpty {
                Text(lesson.body).font(KType.body(14.5)).foregroundStyle(K.inkSoft)
                    .lineSpacing(3).lineLimit(4).multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardSurface()
    }
}

struct LessonEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var lesson: Lesson
    @State private var showRecorder = false

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        if !lesson.prompt.isEmpty {
                            Text(lesson.prompt)
                                .font(.serif(21)).foregroundStyle(K.ink).lineSpacing(2)
                                .padding(18)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(K.goldSoft.opacity(0.22)))
                                .padding(.top, 8)
                        }

                        FormLabel(text: "Category")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(LessonCategory.allCases) { c in
                                    let on = lesson.category == c
                                    Button { Haptics.tap(); lesson.category = c } label: {
                                        Text(c.title).font(KType.body(13.5))
                                            .foregroundStyle(on ? K.onAccent : K.inkSoft)
                                            .padding(.horizontal, 14).padding(.vertical, 9)
                                            .background(Capsule().fill(on ? K.sageDeep : K.surface)
                                                .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        FormLabel(text: "In one line")
                        TextField("", text: $lesson.headline,
                                  prompt: Text("The thing itself").foregroundStyle(K.inkFaint.opacity(0.8)),
                                  axis: .vertical)
                            .lineLimit(1...)
                            .font(.serif(22)).foregroundStyle(K.ink)
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .cardSurface(radius: 16)

                        FormLabel(text: "And the rest")
                        KTextArea(placeholder: "How you learned it. What it cost. What you'd do differently.",
                                  text: $lesson.body, minHeight: 220)

                        if let ref = lesson.audioRef, MediaStore.exists(ref) {
                            HStack(spacing: 12) {
                                Button { Haptics.tap(); VoicePlayer.shared.toggle(ref: ref) } label: {
                                    Image(systemName: VoicePlayer.shared.playingRef == ref && VoicePlayer.shared.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 12)).foregroundStyle(K.onAccent)
                                        .frame(width: 34, height: 34).background(Circle().fill(K.sageDeep))
                                }
                                .buttonStyle(.plain)
                                Text("In your voice").font(KType.body(14)).foregroundStyle(K.ink)
                                Spacer()
                                Button {
                                    Haptics.tap(); VoicePlayer.shared.stop()
                                    MediaStore.delete(lesson.audioRef); lesson.audioRef = nil
                                } label: { Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(K.inkFaint) }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11).cardSurface(radius: 15)
                        } else {
                            Button { Haptics.tap(); showRecorder = true } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: "mic").font(.system(size: 14, weight: .light))
                                    Text("Say it out loud instead").font(KType.body(14.5))
                                    Spacer()
                                }
                                .foregroundStyle(K.ink)
                                .padding(.horizontal, 16).padding(.vertical, 14).cardSurface(radius: 15)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { save(); dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) { Text("Lesson").font(.serif(16)).foregroundStyle(K.ink) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Keep") { save(); Haptics.kept(); dismiss() }
                        .font(KType.body(15).weight(.medium)).foregroundStyle(K.sageDeep)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .sheet(isPresented: $showRecorder) {
            VoiceRecorderSheet(presetTitle: lesson.headline.isEmpty ? lesson.prompt : lesson.headline) { rec in
                lesson.audioRef = rec.fileRef; save()
            }
        }
    }

    private func save() {
        lesson.updatedAt = .now
        if lesson.headline.isEmpty && lesson.body.isEmpty && lesson.audioRef == nil {
            ctx.delete(lesson)
        }
        try? ctx.save()
    }
}

/// A deck of questions to pull from, filtered by theme.
struct PromptDeck: View {
    var themes: [LifeQuestion.Theme] = LifeQuestion.Theme.allCases
    var onPick: (LifeQuestion) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PaperBackground(deep: true)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Pick a question").font(.serif(26)).foregroundStyle(K.ink).padding(.top, 26)
                    ForEach(themes, id: \.self) { t in
                        let qs = QuestionBank.all.filter { $0.theme == t }
                        if !qs.isEmpty {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(t.title).eyebrowStyle(K.gold)
                                ForEach(qs) { q in
                                    Button { Haptics.tap(); onPick(q) } label: {
                                        HStack {
                                            Text(q.text).font(.serif(16.5)).foregroundStyle(K.ink)
                                                .multilineTextAlignment(.leading).lineSpacing(2)
                                            Spacer(minLength: 10)
                                            Image(systemName: "arrow.right").font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(K.inkFaint.opacity(0.6))
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 14)
                                        .cardSurface(radius: 16)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 22).padding(.bottom, 40)
            }
        }
    }
}
