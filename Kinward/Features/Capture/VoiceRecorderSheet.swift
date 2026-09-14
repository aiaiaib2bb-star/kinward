import SwiftUI
import SwiftData

/// One screen, one job: catch a voice before the chance goes.
struct VoiceRecorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Person.createdAt) private var people: [Person]

    var presetTitle: String = ""
    var presetPerson: Person? = nil
    var onSaved: ((VoiceRecording) -> Void)? = nil

    @State private var rec = VoiceRecorder()
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var linkedPerson: Person?
    @State private var finished: (ref: String, duration: TimeInterval, levels: [Double])?
    @State private var pulse = false

    var body: some View {
        ZStack {
            PaperBackground(deep: true)
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 26) {
                        if finished == nil { recordingStage } else { reviewStage }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { title = presetTitle; linkedPerson = presetPerson }
        .interactiveDismissDisabled(rec.isRecording)
    }

    private var header: some View {
        HStack {
            Button("Cancel") { rec.discard(); dismiss() }
                .font(KType.body(15)).foregroundStyle(K.inkSoft)
            Spacer()
            Text(finished == nil ? "Record your voice" : "Keep this")
                .font(.serif(17)).foregroundStyle(K.ink)
            Spacer()
            Button("Save") { save() }
                .font(KType.body(15).weight(.medium))
                .foregroundStyle(finished == nil ? K.inkFaint.opacity(0.5) : K.sageDeep)
                .disabled(finished == nil)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
        .background(K.bg.opacity(0.9))
        .overlay(alignment: .bottom) { HairLine() }
    }

    // MARK: Stages

    private var recordingStage: some View {
        VStack(spacing: 30) {
            Text(rec.isRecording ? (rec.isPaused ? "Paused" : "Listening") : "When you're ready")
                .eyebrowStyle(K.gold)
                .padding(.top, 12)

            Text(title.isEmpty ? "Say it the way you'd say it to them." : title)
                .font(.serif(26))
                .foregroundStyle(K.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 12)

            LiveWaveform(levels: rec.levels, isPaused: rec.isPaused)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)

            Text(rec.durationText)
                .font(.sans(34, .light).monospacedDigit())
                .foregroundStyle(K.ink.opacity(rec.isRecording ? 1 : 0.35))

            HStack(spacing: 26) {
                if rec.isRecording {
                    circleButton(icon: rec.isPaused ? "mic.fill" : "pause.fill", size: 58, filled: false) {
                        rec.isPaused ? rec.resume() : rec.pause()
                    }
                    circleButton(icon: "checkmark", size: 78, filled: true) {
                        finished = rec.stop()
                    }
                    circleButton(icon: "trash", size: 58, filled: false) {
                        rec.discard()
                    }
                } else {
                    circleButton(icon: "mic.fill", size: 96, filled: true) {
                        Task { await rec.start() }
                    }
                    .scaleEffect(pulse ? 1.03 : 0.98)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { pulse = true }
                    }
                }
            }
            .padding(.top, 4)

            if rec.permissionDenied {
                Text("Kinward needs microphone access to keep your voice. You can turn it on in Settings.")
                    .font(KType.caption(13)).foregroundStyle(K.inkSoft)
                    .multilineTextAlignment(.center).padding(.horizontal, 30)
            }

            if !rec.isRecording {
                Marginalia(text: "A voice says things\nwriting never gets to.", size: 17)
                    .padding(.top, 10)
            }
        }
    }

    private var reviewStage: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let f = finished {
                VStack(spacing: 14) {
                    WaveformView(levels: f.levels, progress: VoicePlayer.shared.playingRef == f.ref ? VoicePlayer.shared.progress : 0)
                        .frame(height: 62)
                    HStack {
                        Button {
                            Haptics.tap(); VoicePlayer.shared.toggle(ref: f.ref)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: VoicePlayer.shared.playingRef == f.ref && VoicePlayer.shared.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 12))
                                Text("Listen back").font(KType.body(14))
                            }
                            .foregroundStyle(K.ink)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Capsule().fill(K.surface).overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(String(format: "%d:%02d", Int(f.duration) / 60, Int(f.duration) % 60))
                            .font(.sans(13, .medium).monospacedDigit()).foregroundStyle(K.inkSoft)
                        Button {
                            Haptics.tap()
                            VoicePlayer.shared.stop()
                            MediaStore.delete(f.ref)
                            withAnimation(KMotion.gentle) { finished = nil }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14)).foregroundStyle(K.inkSoft)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(K.surface).overlay(Circle().strokeBorder(K.border, lineWidth: 0.8)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
                .cardSurface()
            }

            FormLabel(text: "What is this?")
            KField(placeholder: "A message for my children", text: $title, serif: true, size: 17)

            FormLabel(text: "Who is it for?")
            PersonPickerRow(people: people, selection: $linkedPerson)

            FormLabel(text: "A note for later")
            KTextArea(placeholder: "Anything you want them to know about this recording.", text: $note, minHeight: 96, font: KType.body(15))
        }
    }

    private func circleButton(icon: String, size: CGFloat, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.settle(); action() }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.3, weight: .light))
                .foregroundStyle(filled ? K.surface : K.ink)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(filled ? K.sageDeep : K.surface)
                        .overlay(Circle().strokeBorder(filled ? .clear : K.border, lineWidth: 0.9))
                        .shadow(color: K.ink.opacity(filled ? 0.2 : 0.06), radius: filled ? 16 : 6, y: 5)
                )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard let f = finished else { return }
        let r = VoiceRecording(title: title.isEmpty ? "Untitled recording" : title,
                               fileRef: f.ref, duration: f.duration, levels: f.levels)
        r.note = note
        r.person = linkedPerson
        ctx.insert(r)
        try? ctx.save()
        Haptics.kept()
        onSaved?(r)
        dismiss()
    }
}

struct PersonPickerRow: View {
    let people: [Person]
    @Binding var selection: Person?
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(label: "Everyone", selected: selection == nil) { selection = nil }
                ForEach(people) { p in
                    chip(label: p.name, selected: selection?.id == p.id) { selection = p }
                }
            }
            .padding(.horizontal, 2).padding(.vertical, 2)
        }
    }
    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            Text(label)
                .font(KType.body(14))
                .foregroundStyle(selected ? K.surface : K.ink)
                .padding(.horizontal, 15).padding(.vertical, 9)
                .background(Capsule().fill(selected ? K.sageDeep : K.surface)
                    .overlay(Capsule().strokeBorder(selected ? .clear : K.border, lineWidth: 0.8)))
        }
        .buttonStyle(.plain)
    }
}
