import SwiftUI
import SwiftData

struct FamilyHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \FamilyStory.createdAt, order: .reverse) private var stories: [FamilyStory]
    @State private var editing: FamilyStory?
    @State private var filter: String?

    private let generations = ["Parents", "Grandparents", "Great-grandparents", "Origins", "Traditions", "Recipes"]

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("The people and places that came before you — so your children know they didn't start from nothing.")
                            .font(KType.body(15)).foregroundStyle(K.inkSoft).lineSpacing(3)
                            .padding(.top, 8)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                chip("All", on: filter == nil) { filter = nil }
                                ForEach(generations, id: \.self) { g in
                                    chip(g, on: filter == g) { filter = g }
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        if shown.isEmpty {
                            QuietEmptyState(icon: "tree",
                                            title: "Nothing recorded yet",
                                            message: "Start with one person: a grandparent, a name, a place they left.",
                                            actionTitle: "Add a family story") { add(nil) }
                        } else {
                            VStack(spacing: 12) {
                                ForEach(shown) { s in
                                    Button { Haptics.tap(); editing = s } label: { FamilyStoryCard(story: s) }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                s.photoRefs.forEach { MediaStore.delete($0) }
                                                MediaStore.delete(s.audioRef)
                                                ctx.delete(s); try? ctx.save()
                                            } label: { Label("Delete", systemImage: "trash") }
                                        }
                                }
                            }
                        }

                        Text("Add").eyebrowStyle(K.inkFaint).padding(.top, 6)
                        LazyVGrid(columns: [.init(.flexible(), spacing: 10), .init(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(generations, id: \.self) { g in
                                Button { Haptics.tap(); add(g) } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: icon(for: g)).font(.system(size: 13, weight: .light))
                                            .foregroundStyle(K.gold)
                                        Text(g).font(KType.body(13.5)).foregroundStyle(K.ink)
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
                    .padding(.horizontal, 22).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) { Text("Family history").font(.serif(16)).foregroundStyle(K.ink) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); add(filter) } label: { Image(systemName: "plus").foregroundStyle(K.ink) }
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .sheet(item: $editing) { s in FamilyStoryEditor(story: s) }
    }

    private var shown: [FamilyStory] {
        guard let f = filter else { return stories }
        if f == "Recipes" { return stories.filter(\.isRecipe) }
        if f == "Traditions" { return stories.filter(\.isTradition) }
        return stories.filter { $0.generation == f }
    }

    private func icon(for g: String) -> String {
        switch g {
        case "Parents": "person.2"
        case "Grandparents": "figure.2.and.child.holdinghands"
        case "Great-grandparents": "clock.arrow.circlepath"
        case "Origins": "globe.europe.africa"
        case "Traditions": "sparkles"
        default: "fork.knife"
        }
    }

    private func chip(_ t: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); withAnimation(KMotion.gentle) { action() } } label: {
            Text(t).font(KType.body(13.5))
                .foregroundStyle(on ? K.surface : K.inkSoft)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(on ? K.sageDeep : K.surface)
                    .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
        }
        .buttonStyle(.plain)
    }

    private func add(_ generation: String?) {
        let s = FamilyStory(title: "", subject: "", generation: generation ?? "Grandparents")
        if generation == "Recipes" { s.isRecipe = true; s.generation = "Recipes" }
        if generation == "Traditions" { s.isTradition = true; s.generation = "Traditions" }
        ctx.insert(s); editing = s
    }
}

struct FamilyStoryCard: View {
    let story: FamilyStory
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let ref = story.photoRefs.first {
                MediaImage(ref: ref)
                    .frame(height: 150).frame(maxWidth: .infinity).clipped()
                    .overlay(LinearGradient(colors: [.clear, .black.opacity(0.22)], startPoint: .center, endPoint: .bottom))
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(story.generation).eyebrowStyle(K.gold)
                    if !story.years.isEmpty {
                        Text("·").foregroundStyle(K.inkFaint)
                        Text(story.years).font(KType.caption(11.5)).foregroundStyle(K.inkFaint)
                    }
                    Spacer()
                    if story.audioRef != nil {
                        Image(systemName: "waveform").font(.system(size: 11)).foregroundStyle(K.sage)
                    }
                }
                Text(story.title.isEmpty ? (story.subject.isEmpty ? "Untitled" : story.subject) : story.title)
                    .font(.serif(20)).foregroundStyle(K.ink).multilineTextAlignment(.leading)
                if !story.subject.isEmpty && !story.title.isEmpty {
                    Text(story.subject).font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                }
                if !story.body.isEmpty {
                    Text(story.body).font(KType.body(14.5)).foregroundStyle(K.inkSoft)
                        .lineSpacing(3).lineLimit(3).multilineTextAlignment(.leading)
                }
                if !story.origin.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin").font(.system(size: 9))
                        Text(story.origin).font(KType.caption(12))
                    }
                    .foregroundStyle(K.gold)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .background(RoundedRectangle(cornerRadius: K.rCard, style: .continuous).fill(K.surface))
        .clipShape(RoundedRectangle(cornerRadius: K.rCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: K.rCard, style: .continuous).strokeBorder(K.border, lineWidth: 0.8))
        .shadow(color: K.ink.opacity(0.05), radius: 14, y: 6)
    }
}

struct FamilyStoryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var story: FamilyStory
    @State private var showRecorder = false

    private let generations = ["Parents", "Grandparents", "Great-grandparents", "Origins", "Traditions", "Recipes"]

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        PhotoStrip(refs: $story.photoRefs, height: 120)
                        PhotoAddButton(label: "Old photographs", refs: $story.photoRefs)

                        FormLabel(text: "Title")
                        KField(placeholder: story.isRecipe ? "My grandmother's ragù" : "The crossing", text: $story.title, serif: true, size: 19)

                        FormLabel(text: "Who it's about")
                        KField(placeholder: "My grandmother Rosa", text: $story.subject)

                        FormLabel(text: "Generation")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(generations, id: \.self) { g in
                                    let on = story.generation == g
                                    Button { Haptics.tap(); story.generation = g } label: {
                                        Text(g).font(KType.body(13.5))
                                            .foregroundStyle(on ? K.surface : K.inkSoft)
                                            .padding(.horizontal, 14).padding(.vertical, 9)
                                            .background(Capsule().fill(on ? K.sageDeep : K.surface)
                                                .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 7) {
                                FormLabel(text: "Years")
                                KField(placeholder: "1921–1998", text: $story.years)
                            }
                            VStack(alignment: .leading, spacing: 7) {
                                FormLabel(text: "Place")
                                KField(placeholder: "Bari, Italy", text: $story.origin)
                            }
                        }

                        FormLabel(text: story.isRecipe ? "The recipe, and the story with it" : "The story")
                        KTextArea(placeholder: "Names, dates, the details nobody else would remember.",
                                  text: $story.body, minHeight: 220)

                        if let ref = story.audioRef, MediaStore.exists(ref) {
                            HStack(spacing: 12) {
                                Button { Haptics.tap(); VoicePlayer.shared.toggle(ref: ref) } label: {
                                    Image(systemName: VoicePlayer.shared.playingRef == ref && VoicePlayer.shared.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 12)).foregroundStyle(K.surface)
                                        .frame(width: 34, height: 34).background(Circle().fill(K.sageDeep))
                                }
                                .buttonStyle(.plain)
                                Text("Told in your voice").font(KType.body(14)).foregroundStyle(K.ink)
                                Spacer()
                                Button {
                                    Haptics.tap(); VoicePlayer.shared.stop()
                                    MediaStore.delete(story.audioRef); story.audioRef = nil
                                } label: { Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(K.inkFaint) }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11).cardSurface(radius: 15)
                        } else {
                            Button { Haptics.tap(); showRecorder = true } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: "mic").font(.system(size: 14, weight: .light))
                                    Text("Tell it out loud").font(KType.body(14.5))
                                    Spacer()
                                }
                                .foregroundStyle(K.ink)
                                .padding(.horizontal, 16).padding(.vertical, 14).cardSurface(radius: 15)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { save(); dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) { Text("Family story").font(.serif(16)).foregroundStyle(K.ink) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Keep") { save(); Haptics.kept(); dismiss() }
                        .font(KType.body(15).weight(.medium)).foregroundStyle(K.sageDeep)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .sheet(isPresented: $showRecorder) {
            VoiceRecorderSheet(presetTitle: story.title.isEmpty ? story.subject : story.title) { rec in
                story.audioRef = rec.fileRef; try? ctx.save()
            }
        }
    }
    private func save() {
        if story.title.isEmpty && story.subject.isEmpty && story.body.isEmpty { ctx.delete(story) }
        try? ctx.save()
    }
}
