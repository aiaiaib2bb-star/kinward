import SwiftUI
import SwiftData

/// Answering the week's question. The answer files itself where it belongs.
struct AnswerQuestionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    let question: LifeQuestion
    var profile: UserProfile

    @State private var text = ""
    @State private var showRecorder = false
    @State private var savedRef: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(question.theme.title).eyebrowStyle(K.gold).padding(.top, 12)
                        Text(question.text)
                            .font(.serif(26)).foregroundStyle(K.ink).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)

                        KTextArea(placeholder: "However it comes out is fine. Nobody is marking this.",
                                  text: $text, minHeight: 250)

                        Button { Haptics.tap(); showRecorder = true } label: {
                            HStack(spacing: 9) {
                                Image(systemName: savedRef == nil ? "mic" : "waveform")
                                    .font(.system(size: 14, weight: .light))
                                Text(savedRef == nil ? "Answer out loud instead" : "Recorded")
                                    .font(KType.body(14.5))
                                Spacer()
                            }
                            .foregroundStyle(K.ink)
                            .padding(.horizontal, 16).padding(.vertical, 14).cardSurface(radius: 15)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 9) {
                            Image(systemName: landingIcon).font(.system(size: 12)).foregroundStyle(K.sage)
                            Text("This will be kept in \(landingName).")
                                .font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 22).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Not now") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Keep") { save() }
                        .font(KType.body(15).weight(.medium))
                        .foregroundStyle(canSave ? K.sageDeep : K.inkFaint.opacity(0.5))
                        .disabled(!canSave)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .sheet(isPresented: $showRecorder) {
            VoiceRecorderSheet(presetTitle: question.text) { rec in savedRef = rec.fileRef }
        }
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || savedRef != nil
    }
    private var landingName: String {
        switch question.lands {
        case .memory: "Memories"; case .lesson: "Lessons"
        case .familyStory: "Legacy"; case .letter: "Letters"
        }
    }
    private var landingIcon: String {
        switch question.lands {
        case .memory: "photo.on.rectangle.angled"; case .lesson: "lightbulb"
        case .familyStory: "tree"; case .letter: "envelope"
        }
    }

    private func save() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch question.lands {
        case .memory:
            let m = MemoryEntry(title: shortTitle, story: body)
            m.whyItMatters = question.text
            m.audioRef = savedRef
            ctx.insert(m)
        case .lesson:
            let l = Lesson(category: inferredCategory, headline: shortTitle, body: body)
            l.prompt = question.text
            l.audioRef = savedRef
            ctx.insert(l)
        case .familyStory:
            let s = FamilyStory(title: shortTitle, subject: "", generation: "Family")
            s.body = body
            s.audioRef = savedRef
            ctx.insert(s)
        case .letter:
            let l = Letter(title: shortTitle, body: body)
            l.salutation = "There's something I want you to know."
            l.audioRef = savedRef
            l.isDraft = false
            ctx.insert(l)
        }
        let a = AnsweredQuestion(questionID: question.id, question: question.text, answer: body)
        a.audioRef = savedRef
        ctx.insert(a)

        profile.answeredQuestionIDs.append(question.id)
        profile.lastQuestionShown = .now
        try? ctx.save()
        Haptics.kept()
        dismiss()
    }

    private var shortTitle: String {
        let t = question.text
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "What ", with: "")
            .replacingOccurrences(of: "Who ", with: "")
        return String(t.prefix(60))
    }

    private var inferredCategory: LessonCategory {
        switch question.theme {
        case .love: .love; case .work: .career; case .family: .family
        case .belief: .believe; case .legacy: .whatLifeTaught
        default: .wishIdKnown
        }
    }
}
