import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var router: Router
    var profile: UserProfile

    @Query(sort: \MemoryEntry.updatedAt, order: .reverse) private var memories: [MemoryEntry]
    @Query(sort: \Letter.updatedAt, order: .reverse) private var letters: [Letter]
    @Query(sort: \Person.createdAt) private var people: [Person]
    @Query(sort: \VoiceRecording.createdAt, order: .reverse) private var recordings: [VoiceRecording]
    @Query(sort: \Lesson.updatedAt, order: .reverse) private var lessons: [Lesson]
    @Query(sort: \FamilyStory.createdAt, order: .reverse) private var stories: [FamilyStory]

    @State private var question: LifeQuestion = QuestionBank.all[0]
    @State private var answering: LifeQuestion?
    @State private var openMemory: MemoryEntry?
    @State private var openLetter: Letter?
    @State private var showRecorder = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 30) {
                greeting
                weeklyQuestion
                if let resume = resumeItem { continueSection(resume) }
                quickCapture
                if !people.isEmpty { peoplePreview }
                yourKinward
                closingLine
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 190)
        }
        .background(PaperBackground())
        // Content scrolls the full height, so give the status bar something to sit on
        // instead of letting tile edges collide with the clock.
        .overlay(alignment: .top) { StatusBarScrim() }
        .onAppear { question = QuestionBank.next(for: profile) }
        .sheet(item: $answering) { q in AnswerQuestionSheet(question: q, profile: profile) }
        .sheet(item: $openMemory) { m in MemoryEditor(memory: m) }
        .sheet(item: $openLetter) { l in LetterEditor(letter: l) }
        .sheet(isPresented: $showRecorder) { VoiceRecorderSheet() }
    }

    // MARK: Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Button { Haptics.tap(); router.showSettings = true } label: {
                    ZStack {
                        if let img = MediaStore.image(profile.avatarRef) {
                            Image(uiImage: img).resizable().scaledToFill()
                        } else {
                            LinearGradient(colors: [K.gold.opacity(0.8), K.sage], startPoint: .topLeading, endPoint: .bottomTrailing)
                            // `displayName` falls back to "there", and an initial taken
                            // from that renders a meaningless "T". Show a figure instead.
                            if profile.firstName.isEmpty {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 19, weight: .light))
                                    .foregroundStyle(.white.opacity(0.9))
                            } else {
                                Text(String(profile.firstName.prefix(1)).uppercased())
                                    .font(.serif(19)).foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(K.surface, lineWidth: 1.2))
                    .shadow(color: K.ink.opacity(0.1), radius: 6, y: 2)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(timeGreeting).font(KType.body(15)).foregroundStyle(K.inkSoft)
                    Text(profile.displayName).font(.serif(24)).foregroundStyle(K.ink)
                }
                Spacer()
                RoundIconButton(icon: "magnifyingglass") { router.showSearch = true }
            }
            .padding(.top, 10)

            Text(heroLine)
                .font(.serif(22))
                .foregroundStyle(K.ink.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var timeGreeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<5: "Still awake,"
        case 5..<12: "Good morning,"
        case 12..<18: "Good afternoon,"
        default: "Good evening,"
        }
    }

    private var heroLine: String {
        let n = totalPieces
        if n == 0 { return "Some things should not disappear when we do." }
        if people.isEmpty { return "Your story is beginning. Who is it for?" }
        let name = people.first?.name ?? "them"
        return n < 6
            ? "You've started something \(name) will be glad you kept."
            : "Your story. Their future."
    }

    // MARK: This week's question

    private var weeklyQuestion: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("This week's question").eyebrowStyle(K.gold)
                Spacer()
                Button {
                    Haptics.tap()
                    withAnimation(KMotion.gentle) {
                        question = QuestionBank.next(for: profile, excluding: [question.id])
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 10, weight: .medium))
                        Text("Ask me another").font(KType.caption(12))
                    }
                    .foregroundStyle(K.inkSoft)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 18) {
                Text(question.text)
                    .font(.serif(23))
                    .foregroundStyle(K.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button { Haptics.tap(); answering = question } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil").font(.system(size: 12, weight: .regular))
                            Text("Answer").font(KType.body(14.5))
                        }
                        .foregroundStyle(K.surface)
                        .padding(.horizontal, 20).padding(.vertical, 11)
                        .background(Capsule().fill(K.sageDeep))
                    }
                    .buttonStyle(.plain)

                    Button { Haptics.tap(); showRecorder = true } label: {
                        Image(systemName: "mic")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(K.ink)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(K.surface).overlay(Circle().strokeBorder(K.border, lineWidth: 0.8)))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        Haptics.tap()
                        profile.skippedQuestionIDs.append(question.id)
                        try? ctx.save()
                        withAnimation(KMotion.gentle) { question = QuestionBank.next(for: profile) }
                    } label: {
                        Text("Not today").font(KType.body(13.5)).foregroundStyle(K.inkFaint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: K.rLarge, style: .continuous).fill(K.paper)
                    RoundedRectangle(cornerRadius: K.rLarge, style: .continuous)
                        .fill(LinearGradient(colors: [K.goldSoft.opacity(0.30), .clear],
                                             startPoint: .topTrailing, endPoint: .bottomLeading))
                }
                .shadow(color: K.ink.opacity(0.06), radius: 16, y: 7)
            )
            .overlay(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous)
                .strokeBorder(K.border, lineWidth: 0.8))
        }
    }

    // MARK: Continue

    private enum Resume { case memory(MemoryEntry), letter(Letter) }
    private var resumeItem: Resume? {
        if let l = letters.first(where: { $0.isDraft && !$0.body.isEmpty }) { return .letter(l) }
        if let m = memories.first(where: { $0.isDraft }) { return .memory(m) }
        if let l = letters.first { return .letter(l) }
        if let m = memories.first { return .memory(m) }
        return nil
    }

    private func continueSection(_ r: Resume) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue your story").eyebrowStyle(K.inkFaint)
            Button {
                Haptics.tap()
                switch r {
                case .memory(let m): openMemory = m
                case .letter(let l): openLetter = l
                }
            } label: {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(resumeTitle(r)).font(.serif(19)).foregroundStyle(K.ink)
                            .lineLimit(2).multilineTextAlignment(.leading)
                        Text(resumeSub(r)).font(KType.caption(13)).foregroundStyle(K.inkSoft)
                            .lineLimit(2).multilineTextAlignment(.leading)
                    }
                    .padding(.leading, 20).padding(.vertical, 20)
                    Spacer(minLength: 12)
                    Group {
                        if let ref = resumeImage(r), MediaStore.exists(ref) {
                            MediaImage(ref: ref)
                        } else {
                            ZStack {
                                LinearGradient(colors: [K.bgDeep, K.goldSoft.opacity(0.7)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                                Image(systemName: resumeGlyph(r))
                                    .font(.system(size: 20, weight: .ultraLight))
                                    .foregroundStyle(K.sageDeep.opacity(0.55))
                            }
                        }
                    }
                    .frame(width: 104, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(10)
                }
                .cardSurface()
            }
            .buttonStyle(.plain)
        }
    }
    private func resumeTitle(_ r: Resume) -> String {
        switch r {
        case .memory(let m): m.title.isEmpty ? "An unfinished memory" : m.title
        case .letter(let l): l.title.isEmpty ? "An unfinished letter" : l.title
        }
    }
    private func resumeSub(_ r: Resume) -> String {
        switch r {
        case .memory(let m): m.story.isEmpty ? "Nothing written yet" : String(m.story.prefix(80))
        case .letter(let l): l.recipient.map { "For \($0.name)" } ?? (l.body.isEmpty ? "Not started" : String(l.body.prefix(80)))
        }
    }
    private func resumeGlyph(_ r: Resume) -> String {
        switch r {
        case .memory: "photo.on.rectangle.angled"
        case .letter: "envelope"
        }
    }
    private func resumeImage(_ r: Resume) -> String? {
        switch r {
        case .memory(let m): m.photoRefs.first
        case .letter(let l): l.photoRefs.first ?? l.recipient?.photoRef
        }
    }

    // MARK: Quick capture

    private var quickCapture: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preserve something").eyebrowStyle(K.inkFaint)
            HStack(spacing: 10) {
                quickTile(icon: "pencil.line", label: "Write") {
                    let m = MemoryEntry(); m.isDraft = true; ctx.insert(m); openMemory = m
                }
                quickTile(icon: "mic", label: "Record") { showRecorder = true }
                quickTile(icon: "envelope", label: "Letter") {
                    let l = Letter(); ctx.insert(l); openLetter = l
                }
                quickTile(icon: "lightbulb", label: "Advice") {
                    router.go(.lessons)
                }
            }
        }
    }

    private func quickTile(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            VStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 17, weight: .light)).foregroundStyle(K.ink)
                Text(label).font(KType.caption(12)).foregroundStyle(K.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .cardSurface(radius: 18)
        }
        .buttonStyle(.plain)
    }

    // MARK: People

    private var peoplePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("The people who matter").eyebrowStyle(K.inkFaint)
                Spacer()
                Button { Haptics.tap(); router.go(.people) } label: {
                    Text("All").font(KType.caption(12)).foregroundStyle(K.inkSoft)
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(people.prefix(8)) { p in
                        Button { Haptics.tap(); router.go(.people) } label: {
                            VStack(spacing: 8) {
                                PersonAvatar(person: p, size: 62)
                                Text(p.name).font(KType.caption(12.5)).foregroundStyle(K.ink).lineLimit(1)
                                if p.pieceCount > 0 {
                                    Text("\(p.pieceCount)").font(KType.caption(11)).foregroundStyle(K.inkFaint)
                                }
                            }
                            .frame(width: 72)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: Overview

    private var totalPieces: Int {
        memories.count + letters.count + recordings.count + lessons.count + stories.count
    }

    private var yourKinward: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Kinward").eyebrowStyle(K.inkFaint)
            VStack(spacing: 0) {
                statRow(count: memories.count, noun: "memory", plural: "memories", section: .memories)
                if !stories.isEmpty { HairLine(); statRow(count: stories.count, noun: "family story", plural: "family stories", section: .legacy) }
                HairLine()
                statRow(count: letters.count, noun: "letter", plural: "letters", section: .letters)
                HairLine()
                statRow(count: recordings.count, noun: "recording", plural: "recordings", section: .memories)
                HairLine()
                statRow(count: lessons.count, noun: "lesson", plural: "lessons", section: .lessons)
                HairLine()
                statRow(count: people.count, noun: "person", plural: "people", section: .people)
            }
            .cardSurface()
        }
    }

    private func statRow(count: Int, noun: String, plural: String, section: KinwardSection) -> some View {
        Button { Haptics.tap(); router.go(section) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(count)")
                    .font(.serif(26))
                    .foregroundStyle(count == 0 ? K.inkFaint.opacity(0.5) : K.ink)
                    .frame(width: 40, alignment: .leading)
                Text(count == 1 ? noun : plural)
                    .font(KType.body(15))
                    .foregroundStyle(K.inkSoft)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .medium))
                    .foregroundStyle(K.inkFaint.opacity(0.6))
            }
            .padding(.horizontal, 18).padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var closingLine: some View {
        Marginalia(text: totalPieces == 0
                   ? "Start with one thing.\nThe rest follows."
                   : "Little by little,\nthis becomes something.", size: 18)
            .padding(.top, 4)
    }
}
