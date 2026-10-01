import SwiftUI
import SwiftData

/// A sheet of paper, not a form.
struct LetterEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var letter: Letter
    @Query(sort: \Person.createdAt) private var people: [Person]

    /// Shared with Settings, so the face a letter is written in is the same face
    /// it is read in, everywhere it appears.
    @AppStorage(LetterFace.storageKey) private var faceRaw = LetterFace.hand.rawValue
    private var face: LetterFace { LetterFace(rawValue: faceRaw) ?? .hand }

    @State private var showRecorder = false
    @State private var openOn: Date = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @FocusState private var writing: Bool

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
                .scrollDismissesKeyboard(.interactively)
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
                    facePicker
                    Button("Keep") { save(); Haptics.kept(); dismiss() }
                        .font(KType.body(15).weight(.medium)).foregroundStyle(K.sageDeep)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { writing = false }
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

    private var facePicker: some View {
        Menu {
            Picker("How it's written", selection: $faceRaw) {
                ForEach(LetterFace.allCases) { f in
                    Label(f.title, systemImage: f.icon).tag(f.rawValue)
                }
            }
        } label: {
            Image(systemName: face.icon).foregroundStyle(K.inkSoft)
        }
        .onChange(of: faceRaw) { _, _ in Haptics.tap() }
    }

    // MARK: The sheet
    // Every field wraps and keeps growing. A line cap on a vertical field doesn't
    // stop the typing — it scrolls the field inside itself and the first words
    // disappear off the top, which is worse than running long.

    private var paper: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("", text: $letter.title,
                      prompt: Text("A letter to…").foregroundStyle(K.inkFaint.opacity(0.75)),
                      axis: .vertical)
                .lineLimit(1...)
                .font(.serif(25)).foregroundStyle(K.ink)

            HairLine().opacity(0.6)

            TextField("", text: $letter.salutation,
                      prompt: Text("My dearest,").foregroundStyle(K.inkFaint.opacity(0.75)),
                      axis: .vertical)
                .lineLimit(1...)
                .font(face.font(21)).foregroundStyle(K.ink)

            // The body is a TextEditor, not a vertical TextField: a letter needs
            // Return to make a new paragraph, and a vertical TextField submits on
            // Return instead. Its own scrolling is off so the paper grows and the
            // page — not a box inside the page — follows the cursor down.
            ZStack(alignment: .topLeading) {
                if letter.body.isEmpty {
                    Text("Write the things you'd want them to be able to read again in twenty years.")
                        .font(face.font(19))
                        .foregroundStyle(K.inkFaint.opacity(0.7))
                        .lineSpacing(face.lineSpacing(9))
                        .padding(.horizontal, 5).padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $letter.body)
                    .font(face.font(19))
                    .foregroundStyle(K.ink)
                    .lineSpacing(face.lineSpacing(9))
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .frame(minHeight: 240)
                    .focused($writing)
                    // A TextEditor keeps the height it measured for the old face,
                    // which leaves a hole under the last line. Rebuild it instead.
                    .id(faceRaw)
            }

            PhotoStrip(refs: $letter.photoRefs, height: 104)

            TextField("", text: $letter.signature,
                      prompt: Text("With all my love,").foregroundStyle(K.inkFaint.opacity(0.75)),
                      axis: .vertical)
                .lineLimit(1...)
                .font(face.font(21)).foregroundStyle(K.ink)
                .padding(.top, 6)
        }
        .textFieldStyle(.plain)
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: K.rLarge, style: .continuous).fill(K.paper)
                // The warm light in the corner is Paper's; on Clear it would tint
                // the page with the accent.
                if !K.isClear {
                    RoundedRectangle(cornerRadius: K.rLarge, style: .continuous)
                        .fill(RadialGradient(colors: [K.goldSoft.opacity(0.16), .clear],
                                             center: .topTrailing, startRadius: 4, endRadius: 320))
                }
                GrainOverlay(opacity: 0.028)
                    .clipShape(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous))
                if !K.isClear {
                    AgeMarks(age: K.age, salt: 0x1E77E7)
                        .clipShape(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous))
                }
            }
            .shadow(color: K.shadowInk.opacity(0.10), radius: 22, y: 10)
        )
        .overlay(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous)
            .strokeBorder(K.border.opacity(K.isClear ? 0 : 1), lineWidth: 0.8))
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
                            .font(.system(size: 12)).foregroundStyle(K.onAccent)
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
                        .foregroundStyle(on ? K.onAccent : K.ink)
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
