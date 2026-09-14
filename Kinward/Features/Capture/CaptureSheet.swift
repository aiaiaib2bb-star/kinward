import SwiftUI
import SwiftData

/// One list of everything you can preserve, reachable from anywhere by
/// holding the dial.
struct CaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var router: Router
    @Query(sort: \Person.createdAt) private var people: [Person]

    @State private var openMemory: MemoryEntry?
    @State private var openLetter: Letter?
    @State private var openLesson: Lesson?
    @State private var openStory: FamilyStory?
    @State private var openPerson: Person?
    @State private var openBelonging: Belonging?
    @State private var showRecorder = false
    @State private var showPrompts = false

    private struct Action: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let run: () -> Void
    }

    var body: some View {
        ZStack {
            PaperBackground(deep: true)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preserve something").font(.serif(27)).foregroundStyle(K.ink)
                        Text("Nothing here takes more than a few minutes.")
                            .font(KType.body(14.5)).foregroundStyle(K.inkSoft)
                    }
                    .padding(.top, 26).padding(.bottom, 12)

                    ForEach(actions) { a in
                        Button { Haptics.tap(); a.run() } label: {
                            HStack(spacing: 14) {
                                Image(systemName: a.icon)
                                    .font(.system(size: 16, weight: .light)).foregroundStyle(K.sage)
                                    .frame(width: 44, height: 44)
                                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(K.bgDeep.opacity(0.7)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.title).font(KType.body(16).weight(.medium)).foregroundStyle(K.ink)
                                    Text(a.subtitle).font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(K.inkFaint.opacity(0.55))
                            }
                            .padding(.horizontal, 15).padding(.vertical, 11)
                            .cardSurface(radius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22).padding(.bottom, 40)
            }
        }
        .sheet(item: $openMemory) { m in MemoryEditor(memory: m) }
        .sheet(item: $openLetter) { l in LetterEditor(letter: l) }
        .sheet(item: $openLesson) { l in LessonEditor(lesson: l) }
        .sheet(item: $openStory) { s in FamilyStoryEditor(story: s) }
        .sheet(item: $openPerson) { p in PersonEditor(person: p) }
        .sheet(item: $openBelonging) { b in BelongingEditor(belonging: b, people: people) }
        .sheet(isPresented: $showRecorder) { VoiceRecorderSheet() }
        .sheet(isPresented: $showPrompts) {
            PromptDeck { q in
                showPrompts = false
                let m = MemoryEntry(title: "", story: "")
                m.whyItMatters = q.text
                m.isDraft = true
                ctx.insert(m)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { openMemory = m }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var actions: [Action] {
        [
            Action(title: "Write a story", subtitle: "Something that happened, and why it stayed with you", icon: "book.closed") {
                let m = MemoryEntry(); m.isDraft = true; ctx.insert(m); openMemory = m
            },
            Action(title: "Record your voice", subtitle: "The one thing a transcript can't replace", icon: "mic") {
                showRecorder = true
            },
            Action(title: "Write a letter", subtitle: "Words meant for one particular person", icon: "envelope") {
                let l = Letter(); ctx.insert(l); openLetter = l
            },
            Action(title: "Save a memory with photos", subtitle: "Pictures, plus the story behind them", icon: "photo.on.rectangle.angled") {
                let m = MemoryEntry(); m.isDraft = true; ctx.insert(m); openMemory = m
            },
            Action(title: "Share advice", subtitle: "Something you had to learn the hard way", icon: "lightbulb") {
                let l = Lesson(); ctx.insert(l); openLesson = l
            },
            Action(title: "Answer a question", subtitle: "Easier than a blank page", icon: "quote.opening") {
                showPrompts = true
            },
            Action(title: "Add family history", subtitle: "Grandparents, origins, recipes, traditions", icon: "tree") {
                let s = FamilyStory(title: "", subject: "", generation: "Grandparents"); ctx.insert(s); openStory = s
            },
            Action(title: "Add a person", subtitle: "Someone this is all for", icon: "person.crop.circle.badge.plus") {
                let p = Person(name: "", relationship: ""); ctx.insert(p); openPerson = p
            },
            Action(title: "Add a belonging", subtitle: "An object, its story, and who should have it", icon: "shippingbox") {
                let b = Belonging(); ctx.insert(b); openBelonging = b
            },
            Action(title: "Add a document", subtitle: "A will, a deed, a policy — behind your lock", icon: "doc.text") {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { router.go(.documents) }
            }
        ]
    }
}
