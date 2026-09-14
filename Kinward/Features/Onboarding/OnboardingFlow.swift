import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    /// Replaying it later is a revisit, not a first run: the answers are already
    /// there to be reviewed, and nobody should be made to re-enter them.
    enum Mode { case firstRun, revisit }

    @Environment(\.modelContext) private var ctx
    @Query(sort: \Person.createdAt) private var existingPeople: [Person]
    var profile: UserProfile
    var mode: Mode = .firstRun
    var onFinish: () -> Void

    @State private var step = 0
    @State private var firstName = ""
    @State private var know: Set<String> = []
    @State private var remember: Set<String> = []
    @State private var practical: Set<String> = []
    @State private var newPeople: [(String, String)] = []
    @State private var addingRelationship: String? = nil
    @State private var addName = ""
    @State private var firstAnswer = ""
    @State private var firstQuestion = QuestionBank.byID("q.child.detail")!
    @State private var showRecorder = false
    @State private var savedRecording: VoiceRecording?

    // The opening button grows into the page and back out of it on the far side.
    @State private var wipeScale: CGFloat = 1
    @State private var wipeOpacity: Double = 1
    @State private var wiping = false

    private let totalSteps = 8

    var body: some View {
        ZStack {
            switch step {
            case 0: cinematic(image: "hero_father_child",
                              eyebrow: "Kinward",
                              headline: "Preserve the\nmemories, stories,\nand wisdom.",
                              body: "Capture the stories, wisdom, memories and words you want the people you love to carry into their future.",
                              cta: "Get Started",
                              marginalia: "Some things are\ntoo important\nto be forgotten.",
                              plate: .push,
                              button: .beckon)
            case 1: cinematic(image: "hero_album_letters",
                              eyebrow: "Why now",
                              headline: "One day there will be\nthings they wish\nthey could ask you.",
                              body: "Kinward gives you a place to answer them long before those questions are ever asked.",
                              cta: "I understand",
                              marginalia: "They will want\nto ask. Answer\nwhile you can.",
                              plate: .pan,
                              button: .echo)
            case 2: chooser(eyebrow: "Step one",
                            headline: "What would you want\nthem to know?",
                            sub: "Pick anything that feels true. You can change this later.",
                            options: ["My childhood", "What I learned", "Things I wish I'd known", "People who shaped me",
                                      "Family history", "My favourite memories", "My voice", "Stories about my grandparents"],
                            selection: $know,
                            note: "There are no\nwrong answers here.")
            case 3: chooser(eyebrow: "Step two",
                            headline: "Some things are\nmeant to be remembered.",
                            sub: "What should outlast you?",
                            options: ["Family traditions", "Places that matter", "People you should never forget",
                                      "Moments that changed you", "What you're proud of", "What you regret",
                                      "Stories that should not disappear"],
                            selection: $remember,
                            note: "Whatever you pick,\nyou can change later.")
            case 4: chooser(eyebrow: "Step three",
                            headline: "And some things\nmay help them one day.",
                            sub: "Practical things. Only if and when you're ready.",
                            options: ["Important documents", "Property", "Insurance", "Financial instructions",
                                      "Digital accounts", "Personal belongings"],
                            selection: $practical,
                            note: "Only if and when\nyou are ready.")
            case 5: peopleStep
            case 6: firstThingStep
            default: closingStep
            }

            VStack {
                progress
                Spacer()
            }

            if wiping {
                GeometryReader { geo in
                    Circle()
                        .fill(.white)
                        .frame(width: CornerCTA.diameter, height: CornerCTA.diameter)
                        .scaleEffect(wipeScale)
                        .opacity(wipeOpacity)
                        // Exactly where the disc sits, so it grows out of the button
                        // and settles back onto the next one.
                        .position(x: geo.size.width - CornerCTA.centreInsetX,
                                  y: geo.size.height - CornerCTA.centreInsetY)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        .animation(KMotion.calm, value: step)
        // The first two screens and the last are dark. The status bar has to follow
        // them, or the clock and battery render black on a night sky.
        .preferredColorScheme(step <= 1 || step == totalSteps - 1 ? .dark : .light)
        .onAppear(perform: prime)
        .sheet(isPresented: $showRecorder) {
            VoiceRecorderSheet(presetTitle: firstQuestion.text) { rec in
                savedRecording = rec
                advance()
            }
        }
    }

    // MARK: Chrome

    private var progress: some View {
        VStack(spacing: 12) {
            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? tickColor : tickColor.opacity(0.28))
                        .frame(height: 2)
                }
            }
            // A first run has to be finished; a revisit can be left at any point.
            if mode == .revisit {
                HStack {
                    Button("Close") { Haptics.tap(); onFinish() }
                        .font(KType.body(15))
                        .foregroundStyle(tickColor)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 14)
        .animation(KMotion.gentle, value: step)
    }
    private var tickColor: Color { (step <= 1 || step == 7) ? .white.opacity(0.85) : K.inkSoft }

    private func prime() {
        guard mode == .revisit, firstName.isEmpty else { return }
        firstName = profile.firstName
        know = Set(profile.interests)
        remember = Set(profile.wantsRemembered)
        practical = Set(profile.practicalInterests)
    }

    private func advance() {
        Haptics.settle()
        withAnimation(KMotion.calm) { step = min(step + 1, totalSteps - 1) }
    }

    /// The disc opens until it is the whole page, the page changes behind the white,
    /// and then it closes again onto the disc on the other side.
    private func advanceWithWipe() {
        guard !wiping else { return }
        Haptics.settle()
        let next = min(step + 1, totalSteps - 1)
        // Only the cinematic pair has a disc to close back onto. Landing on paper,
        // the white has to dissolve into the page instead, while the page's own
        // pieces arrive under it.
        let landsOnDisc = next <= 1

        wipeScale = 1
        wipeOpacity = 1
        wiping = true
        withAnimation(.easeIn(duration: 0.24)) { wipeScale = CornerCTA.coveringScale }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            // No animation on the step itself: the swap happens behind the white.
            step = next
            if landsOnDisc {
                withAnimation(.easeOut(duration: 0.28)) { wipeScale = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { wiping = false }
            } else {
                withAnimation(.easeOut(duration: 0.32)) { wipeOpacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { wiping = false }
            }
        }
    }

    // MARK: Screens

    /// Words at the top where the sky is, the handwritten note bottom-left, and the
    /// opening disc tucked into the corner of the glass — the design sheet's layout.
    private func cinematic(image: String, eyebrow: String, headline: String,
                           body: String, cta: String, marginalia: String,
                           plate: CinematicPlate.Motion = .push,
                           button: CornerCTA.Motion = .beckon) -> some View {
        ZStack {
            CinematicPlate(image: image, motion: plate)
                .overlay(
                    // Dark enough at the top to carry a headline, dark again at the
                    // foot for the note and the disc's shadow, open in between.
                    LinearGradient(stops: [
                        .init(color: .black.opacity(0.62), location: 0),
                        .init(color: .black.opacity(0.44), location: 0.24),
                        .init(color: .black.opacity(0.10), location: 0.48),
                        .init(color: .black.opacity(0.55), location: 0.80),
                        .init(color: .black.opacity(0.88), location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                )

            VStack(alignment: .leading, spacing: 0) {
                Reveal(delay: 0.05) {
                    Text(eyebrow).eyebrowStyle(.white.opacity(0.75))
                }
                .padding(.top, 70)
                Reveal(delay: 0.13) {
                    Text(headline)
                        .font(.serif(38))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .minimumScaleFactor(0.84)
                        .shadow(color: .black.opacity(0.45), radius: 18, y: 4)
                        .padding(.top, 20)
                }
                Reveal(delay: 0.21) {
                    Text(body)
                        .font(KType.body(16))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineSpacing(5)
                        .shadow(color: .black.opacity(0.4), radius: 14, y: 2)
                        .padding(.top, 16)
                        .padding(.trailing, 12)
                }
                Spacer(minLength: 0)
                Reveal(delay: 0.34) {
                    Marginalia(text: marginalia, size: 17, color: .white.opacity(0.82))
                }
                // Clear of the disc in the corner.
                .padding(.trailing, 150)
                .padding(.bottom, 46)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            CornerCTA(title: cta, motion: button, action: advanceWithWipe)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .transition(.opacity.combined(with: .scale(scale: 1.04)))
    }

    private func chooser(eyebrow: String, headline: String, sub: String,
                         options: [String], selection: Binding<Set<String>>,
                         note: String) -> some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 0) {
                Reveal(delay: 0.04) {
                    Text(eyebrow).eyebrowStyle(K.gold)
                }
                .padding(.top, 62)
                Reveal(delay: 0.10) {
                    Text(headline)
                        .font(.serif(31)).foregroundStyle(K.ink).lineSpacing(1)
                }
                .padding(.top, 14)
                Reveal(delay: 0.16) {
                    Text(sub)
                        .font(KType.body(15)).foregroundStyle(K.inkSoft).lineSpacing(3)
                }
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        FlowChips(options: options, selection: selection, stagger: true)
                            .padding(.top, 26)
                        Reveal(delay: 0.46) {
                            Marginalia(text: note, size: 17)
                        }
                        .padding(.top, 34)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 20)
                }

                KButton(title: selection.wrappedValue.isEmpty ? "Skip for now" : "Continue",
                        style: selection.wrappedValue.isEmpty ? .quiet : .primary) { advance() }
                    .padding(.bottom, 34)
            }
            .padding(.horizontal, 26)
        }
        .preferredColorScheme(.light)
        .transition(.opacity)
    }

    private var peopleStep: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 0) {
                Text("Step four").eyebrowStyle(K.gold).padding(.top, 62)
                Text("Who are you\ndoing this for?")
                    .font(.serif(31)).foregroundStyle(K.ink).padding(.top, 14)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            FormLabel(text: "And you are")
                            KField(placeholder: "Your first name", text: $firstName, serif: true, size: 18)
                        }
                        .padding(.top, 22)

                        if !existingPeople.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Already in Kinward").eyebrowStyle(K.inkFaint)
                                ForEach(existingPeople) { p in
                                    HStack(spacing: 12) {
                                        PersonAvatar(person: p, size: 38)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(p.name.isEmpty ? "Unnamed" : p.name)
                                                .font(KType.body(15).weight(.medium)).foregroundStyle(K.ink)
                                            Text(p.relationship).font(KType.caption(12)).foregroundStyle(K.inkSoft)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .cardSurface(radius: 16)
                                }
                            }
                        }

                        if !newPeople.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(Array(newPeople.enumerated()), id: \.offset) { i, p in
                                    HStack(spacing: 12) {
                                        Circle().fill(K.goldSoft.opacity(0.55))
                                            .frame(width: 38, height: 38)
                                            .overlay(Text(String(p.0.prefix(1)).uppercased())
                                                .font(.serif(15)).foregroundStyle(K.sageDeep))
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(p.0).font(KType.body(15).weight(.medium)).foregroundStyle(K.ink)
                                            Text(p.1).font(KType.caption(12)).foregroundStyle(K.inkSoft)
                                        }
                                        Spacer()
                                        Button {
                                            Haptics.tap()
                                            withAnimation(KMotion.gentle) { _ = newPeople.remove(at: i) }
                                        } label: {
                                            Image(systemName: "xmark").font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(K.inkFaint)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .cardSurface(radius: 16)
                                }
                            }
                        }

                        FlowChipsAction(
                            options: ["Daughter", "Son", "Partner", "Parent", "Grandchild", "Sibling", "Someone else"],
                            prefix: "Add ") { rel in
                                addingRelationship = rel
                                addName = ""
                            }
                    }
                    .padding(.bottom, 18)
                }

                KButton(title: newPeople.isEmpty ? "I'll add someone later" : "Continue",
                        style: newPeople.isEmpty ? .quiet : .primary) { advance() }
                    .padding(.bottom, 34)
            }
            .padding(.horizontal, 26)
        }
        .preferredColorScheme(.light)
        .transition(.opacity)
        .alert("Add \(addingRelationship?.lowercased() ?? "someone")",
               isPresented: Binding(get: { addingRelationship != nil },
                                    set: { if !$0 { addingRelationship = nil } })) {
            TextField("Their name", text: $addName)
                .textInputAutocapitalization(.words)
            Button("Add") {
                if !addName.trimmingCharacters(in: .whitespaces).isEmpty, let rel = addingRelationship {
                    newPeople.append((addName.trimmingCharacters(in: .whitespaces), rel))
                    Haptics.kept()
                }
                addingRelationship = nil
            }
            // Without this both buttons read as equally inert; the default one is bold.
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { addingRelationship = nil }
        } message: {
            Text("Their name is all Kinward needs for now.")
        }
    }

    private var firstThingStep: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 0) {
                // Scrolls, so the keyboard pushes the writing rather than the screen.
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Start with one thing").eyebrowStyle(K.gold).padding(.top, 62)
                        Text("What is one thing about your life you hope your family never forgets?")
                            .font(.serif(28)).foregroundStyle(K.ink).lineSpacing(2)
                            .padding(.top, 14)

                        KTextArea(placeholder: "You don't have to write it well. Just write it.",
                                  text: $firstAnswer, minHeight: 190, font: KType.body(16))
                            .padding(.top, 24)

                        Button {
                            Haptics.tap(); showRecorder = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mic").font(.system(size: 14, weight: .light))
                                Text("Or record your voice instead").font(KType.body(14.5))
                            }
                            .foregroundStyle(K.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(K.surface).overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 14)
                    }
                    .padding(.bottom, 18)
                }
                // Pinned below the scroll, so it is never under the keys.
                KButton(title: firstAnswer.isEmpty ? "Do this later" : "Keep it",
                        style: firstAnswer.isEmpty ? .quiet : .primary) { advance() }
                    .padding(.bottom, 34)
            }
            .padding(.horizontal, 26)
        }
        .preferredColorScheme(.light)
        .transition(.opacity)
    }

    private var closingStep: some View {
        ZStack {
            NightSky()
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text(mode == .revisit
                     ? "That's the whole idea."
                     : "You don't have to\nremember everything\ntoday.")
                    .font(.serif(34)).foregroundStyle(.white).lineSpacing(3)
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 4)
                Text(mode == .revisit
                     ? "One question a week, kept in your own words. Little by little, your story becomes something your family can carry forward."
                     : "Every week, Kinward will ask you one meaningful question. Little by little, your story becomes something your family can carry forward.")
                    .font(KType.body(16)).foregroundStyle(.white.opacity(0.8)).lineSpacing(5)
                    .padding(.top, 18).padding(.trailing, 14)
                Button(action: finish) {
                    HStack(spacing: 10) {
                        Text(mode == .revisit ? "Back to Kinward" : "Enter Kinward").font(KType.body(16))
                        Image(systemName: "arrow.right").font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(K.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Capsule().fill(Color.white.opacity(0.96)))
                }
                .buttonStyle(.plain)
                .padding(.top, 34).padding(.bottom, 50)
            }
            .padding(.horizontal, 28)
        }
        .preferredColorScheme(.dark)
        .transition(.opacity)
    }

    // MARK: Commit

    private func finish() {
        profile.firstName = firstName.trimmingCharacters(in: .whitespaces)
        profile.interests = Array(know)
        profile.wantsRemembered = Array(remember)
        profile.practicalInterests = Array(practical)
        profile.hasOnboarded = true

        for (name, rel) in newPeople {
            ctx.insert(Person(name: name, relationship: rel))
        }
        let trimmed = firstAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, mode == .firstRun || !profile.answeredQuestionIDs.contains(firstQuestion.id) {
            let m = MemoryEntry(title: "The thing I hope they never forget", story: trimmed)
            m.whyItMatters = firstQuestion.text
            ctx.insert(m)
            profile.answeredQuestionIDs.append(firstQuestion.id)
        }
        if let rec = savedRecording, rec.title.isEmpty {
            rec.title = firstQuestion.text
        }
        try? ctx.save()
        Haptics.kept()
        onFinish()
    }
}

/// The round opening button from the design sheet: an arrow over its own label,
/// pressed like a physical key.
/// The opening button from the design sheet: a large white disc tucked into the
/// bottom-right corner of the glass and running off both edges, arrow over label.
///
/// Because the disc is cropped by the screen, the arrow and its label sit up and to
/// the left of the true centre — centred on the part you can actually see.
struct CornerCTA: View {
    /// What the button does while it waits.
    enum Motion {
        /// The arrow leans forward every few seconds and settles back: go on.
        case beckon
        /// A ring leaves the disc and travels outward: something sent ahead.
        case echo
    }

    let title: String
    var motion: Motion = .beckon
    var action: () -> Void

    @State private var pressed = false
    @State private var arrived = false

    /// Shared with the onboarding wipe, which has to start exactly where this sits.
    static let diameter: CGFloat = 168
    static let bleedX: CGFloat = 28
    static let bleedY: CGFloat = 22
    static var centreInsetX: CGFloat { diameter / 2 - bleedX }
    static var centreInsetY: CGFloat { diameter / 2 - bleedY }
    /// Enough to cover the far corner of the largest phone from down here.
    static let coveringScale: CGFloat = 11

    private var d: CGFloat { Self.diameter }
    private var bleed: CGSize { CGSize(width: Self.bleedX, height: Self.bleedY) }

    var body: some View {
        ZStack {
            if motion == .echo { echo }

            Circle()
                .fill(Color.white.opacity(0.96))
                .frame(width: d, height: d)
                .shadow(color: .black.opacity(pressed ? 0.34 : 0.26),
                        radius: pressed ? 16 : 26, y: pressed ? 6 : 10)

            VStack(spacing: 9) {
                arrow
                Text(title)
                    .font(KType.body(14))
                    .tracking(0.2)
            }
            .foregroundStyle(K.ink)
            .offset(x: -bleed.width / 2 - 8, y: -bleed.height / 2 - 24)
        }
        .frame(width: d, height: d)
        .scaleEffect(pressed ? 0.965 : 1)
        .animation(.spring(response: 0.26, dampingFraction: 0.62), value: pressed)
        .offset(x: bleed.width, y: bleed.height)
        // Rolls up out of the corner it lives in, once the words have settled.
        .scaleEffect(arrived ? 1 : 0.72, anchor: .bottomTrailing)
        .opacity(arrived ? 1 : 0)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !pressed else { return }
                    pressed = true
                    Haptics.tap()
                }
                .onEnded { v in
                    pressed = false
                    // Only fire if the finger came up on the disc.
                    let c = d / 2
                    if hypot(v.location.x - c, v.location.y - c) <= c + 8 {
                        Haptics.settle()
                        action()
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.78, dampingFraction: 0.78).delay(0.55)) {
                arrived = true
            }
        }
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
        .accessibilityAction { action() }
    }

    @ViewBuilder
    private var arrow: some View {
        let glyph = Image(systemName: "arrow.right")
            .font(.system(size: 21, weight: .regular))
            .offset(x: pressed ? 4 : 0)

        switch motion {
        case .beckon:
            // A long wait, then a lean forward and a settle back.
            glyph.keyframeAnimator(initialValue: 0.0, repeating: true) { view, x in
                view.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0, duration: 2.4)
                    SpringKeyframe(6, duration: 0.5, spring: .snappy)
                    // Settles without recoiling: a lean forward, not a flinch.
                    SpringKeyframe(0, duration: 0.9, spring: .smooth)
                }
            }
        case .echo:
            glyph
        }
    }

    /// A hairline that leaves the rim of the disc, widens and fades — the shape of
    /// an answer travelling forward to whoever asks for it.
    private var echo: some View {
        Circle()
            .stroke(Color.white, lineWidth: 1.2)
            .frame(width: d, height: d)
            .keyframeAnimator(initialValue: 0.0, repeating: true) { view, t in
                view.scaleEffect(1 + t * 0.46)
                    .opacity(t <= 0 ? 0 : (1 - t) * 0.42)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0, duration: 1.5)
                    CubicKeyframe(1, duration: 3.0)
                }
            }
            .allowsHitTesting(false)
    }
}

/// Fades and lifts its content in a beat after the page arrives, so a screen
/// assembles itself line by line instead of landing all at once.
private struct Reveal<Content: View>: View {
    var delay: Double
    @ViewBuilder var content: Content
    @State private var shown = false

    var body: some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            // Scaled from the leading edge, so the left margin never moves and only
            // the weight of the line changes.
            .scaleEffect(shown ? 1 : 0.96, anchor: .leading)
            .onAppear {
                withAnimation(.spring(response: 0.40, dampingFraction: 0.68).delay(delay)) {
                    shown = true
                }
            }
    }
}

/// The hero photograph, never quite still. The first screen pushes slowly in, the
/// way you lean toward a memory; the second drifts across, the way an eye moves over
/// a table of photographs.
private struct CinematicPlate: View {
    enum Motion { case push, pan }

    let image: String
    var motion: Motion = .push
    @State private var on = false

    var body: some View {
        Image(image)
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            // Panning needs headroom so an edge never shows.
            .scaleEffect(motion == .push ? (on ? 1.07 : 1) : 1.1)
            .offset(x: motion == .pan ? (on ? -20 : 20) : 0)
            .animation(motion == .push
                       ? .easeOut(duration: 20)
                       : .easeInOut(duration: 26).repeatForever(autoreverses: true),
                       value: on)
            .onAppear { on = true }
    }
}

// MARK: - Chips

struct FlowChips: View {
    let options: [String]
    @Binding var selection: Set<String>
    /// Chips land one after another, so a page of them assembles rather than appears.
    var stagger: Bool = false
    @State private var shown = false

    var body: some View {
        FlowLayout(spacing: 9) {
            ForEach(Array(options.enumerated()), id: \.element) { i, o in
                let on = selection.contains(o)
                Button {
                    Haptics.tap()
                    withAnimation(KMotion.gentle) {
                        if on { selection.remove(o) } else { selection.insert(o) }
                    }
                } label: {
                    HStack(spacing: 7) {
                        if on { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                        Text(o).font(KType.body(14.5))
                    }
                    .foregroundStyle(on ? K.surface : K.ink)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Capsule().fill(on ? K.sageDeep : K.surface)
                        .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
                }
                .buttonStyle(.plain)
                .opacity(!stagger || shown ? 1 : 0)
                .scaleEffect(!stagger || shown ? 1 : 0.88)
                .animation(.spring(response: 0.36, dampingFraction: 0.66)
                    .delay(0.16 + Double(i) * 0.032), value: shown)
            }
        }
        .onAppear { shown = true }
    }
}

struct FlowChipsAction: View {
    let options: [String]
    var prefix: String = ""
    var onTap: (String) -> Void
    var body: some View {
        FlowLayout(spacing: 9) {
            ForEach(options, id: \.self) { o in
                Button { Haptics.tap(); onTap(o) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .medium))
                        Text(prefix + o.lowercased()).font(KType.body(14.5))
                    }
                    .foregroundStyle(K.ink)
                    .padding(.horizontal, 15).padding(.vertical, 11)
                    .background(Capsule().fill(K.surface).overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Simple wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: maxW == .infinity ? x : maxW, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

/// The closing screen's sky. Drawn, not photographed — it never needs to load.
struct NightSky: View {
    @State private var shimmer = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0B1014), Color(hex: 0x18232B), Color(hex: 0x3A3630)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                var seed: UInt64 = 0xA11CE
                func rnd() -> Double {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    return Double((seed >> 33) & 0xFFFF) / 65535.0
                }
                for _ in 0..<260 {
                    let x = rnd() * size.width
                    let y = rnd() * size.height * 0.78
                    let r = rnd() * 1.5 + 0.35
                    let a = (1 - y / size.height) * (0.25 + rnd() * 0.75)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(.white.opacity(a)))
                }
            }
            RadialGradient(colors: [Color(hex: 0xE8C48A).opacity(0.30), .clear],
                           center: .init(x: 0.7, y: 0.88), startRadius: 10, endRadius: 380)
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}
