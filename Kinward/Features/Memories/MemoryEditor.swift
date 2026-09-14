import SwiftUI
import SwiftData

struct MemoryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var memory: MemoryEntry
    @Query(sort: \Person.createdAt) private var people: [Person]

    @State private var hasDate: Bool
    @State private var date: Date
    @State private var showRecorder = false
    @State private var linked: Set<UUID> = []

    init(memory: MemoryEntry) {
        self.memory = memory
        _hasDate = State(initialValue: memory.date != nil)
        _date = State(initialValue: memory.date ?? .now)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        TextField("", text: $memory.title,
                                  prompt: Text("Give it a name").foregroundStyle(K.inkFaint.opacity(0.8)))
                            .font(.serif(28)).foregroundStyle(K.ink)
                            .padding(.top, 6)

                        PhotoStrip(refs: $memory.photoRefs)
                        PhotoAddButton(refs: $memory.photoRefs)

                        FormLabel(text: "The story")
                        KTextArea(placeholder: "Tell it the way you'd tell it out loud. Details are the part that survives.",
                                  text: $memory.story, minHeight: 190)

                        FormLabel(text: "Why this matters")
                        KTextArea(placeholder: "The reason you kept this one.",
                                  text: $memory.whyItMatters, minHeight: 90, font: KType.body(15))

                        FormLabel(text: "Where")
                        KField(placeholder: "A house, a town, a shoreline", text: $memory.place)

                        FormLabel(text: "When")
                        whenRow

                        FormLabel(text: "Life stage")
                        stagePicker

                        FormLabel(text: "Who was there")
                        peoplePicker

                        FormLabel(text: "Your voice")
                        voiceSection

                        Button(role: .destructive) { deleteAll() } label: {
                            HStack {
                                Image(systemName: "trash").font(.system(size: 13))
                                Text("Delete this memory").font(KType.body(14))
                            }
                            .foregroundStyle(Color(hex: 0x9A5B4C))
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(Capsule().strokeBorder(K.border, lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 14)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { save(); dismiss() }
                        .font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    Text("Memory").font(.serif(16)).foregroundStyle(K.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Keep") { save(); Haptics.kept(); dismiss() }
                        .font(KType.body(15).weight(.medium)).foregroundStyle(K.sageDeep)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .onAppear { linked = Set((memory.people ?? []).map(\.id)) }
        .sheet(isPresented: $showRecorder) {
            VoiceRecorderSheet(presetTitle: memory.title) { rec in
                memory.audioRef = rec.fileRef
                save()
            }
        }
    }

    private var whenRow: some View {
        VStack(spacing: 10) {
            Toggle(isOn: $hasDate.animation(KMotion.gentle)) {
                Text("I know the date").font(KType.body(15)).foregroundStyle(K.ink)
            }
            .tint(K.sage)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .cardSurface(radius: 15)

            if hasDate {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .cardSurface(radius: 15)
            } else {
                HStack(spacing: 10) {
                    Text("Roughly").font(KType.body(15)).foregroundStyle(K.inkSoft)
                    TextField("Year", value: $memory.approximateYear, format: .number.grouping(.never))
                        .keyboardType(.numberPad)
                        .font(KType.body(16)).foregroundStyle(K.ink)
                        .frame(width: 80)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .cardSurface(radius: 15)
            }
        }
    }

    private var stagePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LifeStage.allCases) { s in
                    let on = memory.stage == s
                    Button { Haptics.tap(); memory.stage = s } label: {
                        Text(s.title).font(KType.body(13.5))
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
    }

    private var peoplePicker: some View {
        Group {
            if people.isEmpty {
                Text("Add someone in People and they'll appear here.")
                    .font(KType.caption(13)).foregroundStyle(K.inkFaint)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface(radius: 15)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(people) { p in
                        let on = linked.contains(p.id)
                        Button {
                            Haptics.tap()
                            withAnimation(KMotion.gentle) {
                                if on { linked.remove(p.id) } else { linked.insert(p.id) }
                            }
                        } label: {
                            HStack(spacing: 7) {
                                PersonAvatar(person: p, size: 22)
                                Text(p.name).font(KType.body(14))
                            }
                            .foregroundStyle(on ? K.surface : K.ink)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Capsule().fill(on ? K.sageDeep : K.surface)
                                .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var voiceSection: some View {
        if let ref = memory.audioRef, MediaStore.exists(ref) {
            HStack(spacing: 12) {
                Button { Haptics.tap(); VoicePlayer.shared.toggle(ref: ref) } label: {
                    Image(systemName: VoicePlayer.shared.playingRef == ref && VoicePlayer.shared.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13)).foregroundStyle(K.surface)
                        .frame(width: 38, height: 38).background(Circle().fill(K.sageDeep))
                }
                .buttonStyle(.plain)
                Text("Told in your own voice").font(KType.body(14)).foregroundStyle(K.ink)
                Spacer()
                Button {
                    Haptics.tap(); VoicePlayer.shared.stop()
                    MediaStore.delete(memory.audioRef); memory.audioRef = nil; save()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 12)).foregroundStyle(K.inkFaint)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .cardSurface(radius: 15)
        } else {
            Button { Haptics.tap(); showRecorder = true } label: {
                HStack(spacing: 9) {
                    Image(systemName: "mic").font(.system(size: 14, weight: .light))
                    Text("Tell this one out loud").font(KType.body(14.5))
                    Spacer()
                }
                .foregroundStyle(K.ink)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .cardSurface(radius: 15)
            }
            .buttonStyle(.plain)
        }
    }

    private func save() {
        memory.date = hasDate ? date : nil
        if hasDate { memory.approximateYear = nil }
        memory.people = people.filter { linked.contains($0.id) }
        memory.updatedAt = .now
        memory.isDraft = memory.title.isEmpty && memory.story.isEmpty

        // An entry the user opened and left completely blank was never a memory.
        if isBlank { ctx.delete(memory) }
        try? ctx.save()
    }

    private var isBlank: Bool {
        memory.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && memory.story.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && memory.whyItMatters.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && memory.place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && memory.photoRefs.isEmpty && memory.audioRef == nil
    }

    private func deleteAll() {
        memory.photoRefs.forEach { MediaStore.delete($0) }
        MediaStore.delete(memory.audioRef)
        ctx.delete(memory); try? ctx.save()
        Haptics.tap(); dismiss()
    }
}
