import SwiftUI
import SwiftData

/// A sheet of paper, not a form.
struct LetterEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var letter: Letter
    @Query(sort: \Person.createdAt) private var people: [Person]

    @State private var handwritten = true
    @State private var showRecorder = false
    @State private var showSeal = false
    @State private var openOn: Date = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [K.bgDeep, K.bg], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        paper
                        extras
                    }
                    .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { save(); dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    Text(letter.recipient.map { "For \($0.name)" } ?? "Letter")
                        .font(.serif(16)).foregroundStyle(K.ink)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { Haptics.tap(); withAnimation(KMotion.gentle) { handwritten.toggle() } } label: {
                        Image(systemName: handwritten ? "textformat" : "signature")
                            .foregroundStyle(K.inkSoft)
                    }
                    Button("Keep") { save(); Haptics.kept(); dismiss() }
                        .font(KType.body(15).weight(.medium)).foregroundStyle(K.sageDeep)
                }
            }
            .toolbarBackground(K.bgDeep, for: .navigationBar)
        }
        .sheet(isPresented: $showRecorder) {
            VoiceRecorderSheet(presetTitle: letter.title, presetPerson: letter.recipient) { rec in
                letter.audioRef = rec.fileRef; save()
            }
        }
        .onAppear { openOn = letter.openOn ?? openOn }
    }

    // MARK: The sheet

    private var paper: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("", text: $letter.title,
                      prompt: Text("A letter to…").foregroundStyle(K.inkFaint.opacity(0.75)))
                .font(.serif(25)).foregroundStyle(K.ink)

            HairLine().opacity(0.6)

            TextField("", text: $letter.salutation,
                      prompt: Text("My dearest,").foregroundStyle(K.inkFaint.opacity(0.75)))
                .font(handwritten ? .hand(21) : .serif(18))
                .foregroundStyle(K.ink)

            ZStack(alignment: .topLeading) {
                if letter.body.isEmpty {
                    Text("Write the things you'd want them to be able to read again in twenty years.")
                        .font(handwritten ? .hand(19) : .serif(17))
                        .foregroundStyle(K.inkFaint.opacity(0.7))
                        .lineSpacing(handwritten ? 9 : 6)
                        .padding(.horizontal, 5).padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $letter.body)
                    .font(handwritten ? .hand(19) : .serif(17))
                    .foregroundStyle(K.ink)
                    .lineSpacing(handwritten ? 9 : 6)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 280)
            }

            PhotoStrip(refs: $letter.photoRefs, height: 104)

            TextField("", text: $letter.signature,
                      prompt: Text("With all my love,").foregroundStyle(K.inkFaint.opacity(0.75)))
                .font(handwritten ? .hand(21) : .serif(18))
                .foregroundStyle(K.ink)
                .padding(.top, 6)
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: K.rLarge, style: .continuous).fill(K.paper)
                RoundedRectangle(cornerRadius: K.rLarge, style: .continuous)
                    .fill(RadialGradient(colors: [K.goldSoft.opacity(0.16), .clear],
                                         center: .topTrailing, startRadius: 4, endRadius: 320))
                GrainOverlay(opacity: 0.028)
                    .clipShape(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous))
            }
            .shadow(color: K.ink.opacity(0.10), radius: 22, y: 10)
        )
        .overlay(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous).strokeBorder(K.border, lineWidth: 0.8))
    }

    // MARK: Below the fold

    private var extras: some View {
        VStack(alignment: .leading, spacing: 16) {
            FormLabel(text: "Who it's for")
            PersonPickerRow(people: people, selection: Binding(
                get: { letter.recipient },
                set: { letter.recipient = $0 }
            ))

            FormLabel(text: "Add to it")
            HStack(spacing: 10) {
                PhotoAddButton(label: "Photographs", refs: $letter.photoRefs)
                Button { Haptics.tap(); showRecorder = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: letter.audioRef == nil ? "mic" : "waveform")
                            .font(.system(size: 14, weight: .light))
                        Text(letter.audioRef == nil ? "Your voice" : "Recorded").font(KType.body(14))
                    }
                    .foregroundStyle(K.ink)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Capsule().fill(K.surface).overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
                }
                .buttonStyle(.plain)
            }

            if let ref = letter.audioRef, MediaStore.exists(ref) {
                HStack(spacing: 12) {
                    Button { Haptics.tap(); VoicePlayer.shared.toggle(ref: ref) } label: {
                        Image(systemName: VoicePlayer.shared.playingRef == ref && VoicePlayer.shared.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12)).foregroundStyle(K.surface)
                            .frame(width: 34, height: 34).background(Circle().fill(K.sageDeep))
                    }
                    .buttonStyle(.plain)
                    Text("Read aloud in your own voice").font(KType.body(14)).foregroundStyle(K.ink)
                    Spacer()
                    Button {
                        Haptics.tap(); VoicePlayer.shared.stop()
                        MediaStore.delete(letter.audioRef); letter.audioRef = nil; save()
                    } label: { Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(K.inkFaint) }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .cardSurface(radius: 15)
            }

            FormLabel(text: "When should it be opened?")
            sealPicker
        }
    }

    private var sealPicker: some View {
        VStack(spacing: 10) {
            FlowLayout(spacing: 8) {
                ForEach(SealCondition.allCases) { s in
                    let on = letter.seal == s
                    Button {
                        Haptics.tap()
                        withAnimation(KMotion.gentle) { letter.seal = s }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: s.icon).font(.system(size: 10, weight: .light))
                            Text(s.title).font(KType.body(13.5))
                        }
                        .foregroundStyle(on ? K.surface : K.ink)
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .background(Capsule().fill(on ? K.sageDeep : K.surface)
                            .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
                    }
                    .buttonStyle(.plain)
                }
            }
            if letter.seal == .onDate {
                DatePicker("Open on", selection: $openOn, displayedComponents: .date)
                    .font(KType.body(14))
                    .tint(K.sage)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .cardSurface(radius: 15)
            }
            if letter.isSealed {
                HStack(spacing: 9) {
                    Image(systemName: "info.circle").font(.system(size: 12)).foregroundStyle(K.gold)
                    Text("Kinward keeps this closed until you choose to share it. Nothing opens on its own.")
                        .font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(K.goldSoft.opacity(0.22)))
            }
        }
    }

    private func save() {
        letter.openOn = letter.seal == .onDate ? openOn : nil
        letter.updatedAt = .now
        letter.isDraft = letter.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        try? ctx.save()
    }
}
