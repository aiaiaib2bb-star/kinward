import SwiftUI
import SwiftData
import PhotosUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var profile: UserProfile
    @Query private var memories: [MemoryEntry]
    @Query private var letters: [Letter]
    @Query private var recordings: [VoiceRecording]
    @Query private var lessons: [Lesson]
    @Query private var stories: [FamilyStory]
    @Query private var people: [Person]

    @AppStorage(LetterFace.storageKey) private var faceRaw = LetterFace.hand.rawValue
    @AppStorage(NavStyle.storageKey) private var navRaw = NavStyle.dial.rawValue
    @State private var picked: PhotosPickerItem?
    @State private var gate = BiometricGate.shared
    @State private var icons = AppIconStore.shared
    @State private var themes = ThemeStore.shared
    @State private var store = Store.shared
    @State private var paywall: PaywallRequest?
    @State private var legal: LegalDoc?
    #if DEBUG
    @State private var sampleLoaded = SampleContent.isLoaded
    #endif
    @State private var confirmReset = false
    @State private var replayIntro = false

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        profileBlock
                        countsBlock
                        plusBlock
                        themeBlock
                        ageBlock
                        preferencesBlock
                        navStyleBlock
                        appIconBlock
                        letterFaceBlock
                        privacyBlock
                        legalBlock
                        #if DEBUG
                        testingBlock
                        #endif
                        aboutBlock
                    }
                    .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { try? ctx.save(); dismiss() }
                        .font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) { Text("You").font(.serif(16)).foregroundStyle(K.ink) }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        // A look ahead is only ever a look. Leaving Settings lets the app settle
        // back to the age it really is.
        .onDisappear {
            withAnimation(.easeInOut(duration: 1.1)) { themes.lookAhead = nil }
        }
        .paywall($paywall)
        .sheet(item: $legal) { LegalDocumentView(doc: $0) }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data), let ref = MediaStore.saveImage(img) {
                    await MainActor.run {
                        MediaStore.delete(profile.avatarRef)
                        profile.avatarRef = ref; try? ctx.save(); Haptics.kept()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $replayIntro) {
            OnboardingFlow(profile: profile, mode: .revisit) {
                try? ctx.save()
                replayIntro = false
            }
        }
        .alert("Erase everything?", isPresented: $confirmReset) {
            Button("Erase", role: .destructive) { eraseAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every memory, letter, recording and document is deleted from this device. This cannot be undone.")
        }
    }

    private var profileBlock: some View {
        // The picker's label closure is @Sendable, so read the model here.
        let avatarRef = profile.avatarRef
        let initial = String(profile.displayName.prefix(1)).uppercased()

        return VStack(spacing: 16) {
            PhotosPicker(selection: $picked, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        if let img = MediaStore.image(avatarRef) {
                            Image(uiImage: img).resizable().scaledToFill()
                        } else {
                            LinearGradient(colors: [K.gold.opacity(0.85), K.sage], startPoint: .topLeading, endPoint: .bottomTrailing)
                            Text(initial)
                                .font(.serif(32)).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 96, height: 96).clipShape(Circle())
                    .overlay(Circle().strokeBorder(K.surface, lineWidth: 1.4))
                    Image(systemName: "camera.fill").font(.system(size: 11)).foregroundStyle(K.onAccent)
                        .frame(width: 30, height: 30).background(Circle().fill(K.sageDeep))
                        .overlay(Circle().strokeBorder(K.bg, lineWidth: 2))
                }
            }
            .padding(.top, 8)

            HStack(spacing: 10) {
                KField(placeholder: "First name", text: $profile.firstName, serif: true, size: 17)
                KField(placeholder: "Last name", text: $profile.lastName, serif: true, size: 17)
            }
        }
    }

    private var countsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What you've kept").eyebrowStyle(K.inkFaint)
            HStack(spacing: 10) {
                stat(memories.count, "memories")
                stat(letters.count, "letters")
                stat(recordings.count, "recordings")
            }
            HStack(spacing: 10) {
                stat(lessons.count, "lessons")
                stat(stories.count, "family")
                stat(people.count, "people")
            }
        }
    }
    private func stat(_ n: Int, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text("\(n)").font(.serif(24)).foregroundStyle(n == 0 ? K.inkFaint.opacity(0.55) : K.ink)
            Text(label).font(KType.caption(11.5)).foregroundStyle(K.inkSoft)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 15)
        .cardSurface(radius: 16)
    }

    private var preferencesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How Kinward behaves").eyebrowStyle(K.inkFaint)
            VStack(spacing: 0) {
                Toggle(isOn: $profile.weeklyQuestionEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("One question a week").font(KType.body(15)).foregroundStyle(K.ink)
                        Text("Quiet, never a streak.").font(KType.caption(12)).foregroundStyle(K.inkSoft)
                    }
                }
                .tint(K.sage).padding(.horizontal, 16).padding(.vertical, 12)
                HairLine()
                Toggle(isOn: $profile.lockSensitive) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lock documents and guidance").font(KType.body(15)).foregroundStyle(K.ink)
                        Text("Opens with \(gate.biometryName).").font(KType.caption(12)).foregroundStyle(K.inkSoft)
                    }
                }
                .tint(K.sage).padding(.horizontal, 16).padding(.vertical, 12)
            }
            .cardSurface()
        }
    }

    // MARK: Plus

    private func offer(_ feature: PlusFeature?) {
        paywall = PaywallRequest(feature: feature)
    }

    /// Kinward Plus: an invitation until it's bought, and a thank-you after, with
    /// the way to manage it close by.
    @ViewBuilder
    private var plusBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kinward Plus").eyebrowStyle(K.inkFaint)
            if store.isPlus {
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        plusMark
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Kinward Plus").font(.serif(18)).foregroundStyle(K.ink)
                            Text("Thank you. Everything it adds is open.")
                                .font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 19)).foregroundStyle(K.sageDeep)
                    }
                    .padding(14)
                    HairLine()
                    Button {
                        Haptics.tap()
                        Task { await store.manage() }
                    } label: {
                        HStack {
                            Text("Manage subscription").font(KType.body(15)).foregroundStyle(K.ink)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .medium))
                                .foregroundStyle(K.inkFaint)
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 16).padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                    #if DEBUG
                    if store.testUnlock {
                        HairLine()
                        Button {
                            Haptics.tap()
                            withAnimation(KMotion.gentle) { store.testUnlock = false }
                        } label: {
                            Text("Lock Plus again · debug builds only")
                                .font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                    #endif
                }
                .cardSurface()
            } else {
                Button { Haptics.tap(); offer(nil) } label: {
                    HStack(spacing: 14) {
                        plusMark
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Keep it beautifully. Pass it on.")
                                .font(.serif(17)).foregroundStyle(K.ink)
                                .multilineTextAlignment(.leading)
                            Text("The book of your life, passing things on, the Clear look and every icon. From \(fromPrice) a month.")
                                .font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                            .foregroundStyle(K.inkFaint.opacity(0.7))
                    }
                    .padding(14)
                    .background(
                        RadialGradient(colors: [K.goldSoft.opacity(K.isClear ? 0.12 : 0.3), .clear],
                                       center: .topLeading, startRadius: 4, endRadius: 260)
                            .clipShape(RoundedRectangle(cornerRadius: K.rCard, style: .continuous))
                    )
                    .contentShape(Rectangle())
                    .cardSurface()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var plusMark: some View {
        Image(AppIconOption.default.preview)
            .resizable().scaledToFill()
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(K.ink.opacity(0.1), lineWidth: 0.7))
            .shadow(color: K.shadowInk.opacity(0.14), radius: 6, y: 3)
    }

    /// The year's price per month — the lowest way in.
    private var fromPrice: String {
        store.plans.first { $0.term == .year }?.perMonth ?? Plan.listPrices[0].perMonth
    }

    /// The look of the whole app. Each choice is shown as a small working picture of
    /// Home in its own colours and type, so it is picked by eye rather than by name.
    private var themeBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Look").eyebrowStyle(K.inkFaint)
            HStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    let on = themes.theme == theme
                    let locked = theme == .clear && !store.has(.clearLook)
                    Button {
                        Haptics.tap()
                        if locked { offer(.clearLook); return }
                        withAnimation(.easeInOut(duration: 0.45)) { themes.theme = theme }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            ThemePreview(theme: theme)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(on ? K.sageDeep : K.border.opacity(0.6),
                                                      lineWidth: on ? 2 : 0.7)
                                )
                                .overlay(alignment: .topTrailing) {
                                    if locked { PlusBadge().padding(9) }
                                }
                            HStack(alignment: .top, spacing: 6) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(theme.title).font(KType.body(15).weight(.medium))
                                        .foregroundStyle(K.ink)
                                    Text(theme.note).font(KType.caption(11.5))
                                        .foregroundStyle(K.inkSoft)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17, weight: .light))
                                    .foregroundStyle(on ? K.sageDeep : K.border)
                            }
                            .padding(.horizontal, 2)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
    }

    // MARK: Age

    /// The age the app really is, whatever is being shown.
    private var realAge: Double { themes.ages ? themes.wear : 0 }
    private var shownAge: Double { themes.lookAhead ?? realAge }

    /// Kinward wears in with use. Three pages show it today, some years on and a
    /// lifetime on; tapping one, or dragging along the line, shows the whole app
    /// that way — this screen included — until it is let go back.
    private var ageBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Age with you").eyebrowStyle(K.inkFaint)
            VStack(alignment: .leading, spacing: 0) {
                Toggle(isOn: $themes.ages.animation(.easeInOut(duration: 1.4))) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Let Kinward age").font(KType.body(15)).foregroundStyle(K.ink)
                        Text(K.isClear ? "Very slowly. On Clear, only the page warms."
                                       : "Very slowly, the way a well-used book does.")
                            .font(KType.caption(12)).foregroundStyle(K.inkSoft)
                    }
                }
                .tint(K.sage).padding(.horizontal, 16).padding(.vertical, 12)
                .onChange(of: themes.ages) { _, _ in Haptics.tap() }

                HairLine()

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        agePage(realAge, "Today", isToday: true)
                        agePage(realAge + (1 - realAge) * 0.55, "Some years on")
                        agePage(0.97, "A lifetime on")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(Patina.stage(shownAge))
                                .font(.serif(18)).foregroundStyle(K.ink)
                                .contentTransition(.opacity)
                            Spacer()
                            if themes.lookAhead != nil {
                                Button {
                                    Haptics.tap()
                                    withAnimation(.easeInOut(duration: 1.1)) { themes.lookAhead = nil }
                                } label: {
                                    Text("Back to today").font(KType.label(12.5)).foregroundStyle(K.sageDeep)
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity)
                            }
                        }
                        Slider(value: lookAhead, in: 0...1)
                            .tint(K.sage)
                        HStack {
                            Text("New"); Spacer(); Text("A lifetime")
                        }
                        .font(KType.caption(11)).foregroundStyle(K.inkFaint)
                    }

                    Text(ageStatus)
                        .font(KType.caption(12)).foregroundStyle(K.inkSoft)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .cardSurface()
            .animation(KMotion.gentle, value: themes.lookAhead == nil)
        }
    }

    /// Dragging shows the whole app at that age, in hundredths so a slow drag
    /// does not redraw everything on every point.
    private var lookAhead: Binding<Double> {
        Binding(get: { shownAge },
                set: { themes.lookAhead = ($0 * 100).rounded() / 100 })
    }

    private var ageStatus: String {
        if themes.lookAhead != nil {
            return shownAge < 0.01
                ? "How it looked on the first day."
                : "\(Patina.timeToReach(shownAge)) of opening it most days. Close Settings and it goes back to today."
        }
        guard themes.ages else {
            return "It stays as new. Your days with it are still counted, so turning this back on brings them back."
        }
        let d = themes.daysOpened, k = themes.kept
        return "Opened on \(d) \(d == 1 ? "day" : "days"), with \(k) \(k == 1 ? "thing" : "things") kept. It changes a little at a time, over years — every day you open it, and everything you keep."
    }

    /// A page of this theme's stock at `age`, with the same marks the app would get.
    private func agePage(_ age: Double, _ label: String, isToday: Bool = false) -> some View {
        let theme = themes.theme
        let p = theme.palette.aged(age, clear: theme == .clear)
        let on = isToday ? themes.lookAhead == nil : abs(shownAge - age) < 0.006
        return Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 1.1)) { themes.lookAhead = isToday ? nil : age }
        } label: {
            VStack(spacing: 7) {
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(p.paper)
                    if theme == .paper {
                        AgeMarks(age: age, salt: 0xA6E)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("My dearest,")
                            .font(theme == .clear ? .system(size: 11, weight: .semibold) : .hand(13))
                            .foregroundStyle(p.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        ForEach(0..<3, id: \.self) { i in
                            Capsule().fill(p.inkSoft.opacity(0.4))
                                .frame(width: i == 2 ? 34 : nil, height: 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Spacer(minLength: 0)
                        Rectangle().fill(p.gold).frame(width: 20, height: 1.2)
                    }
                    .padding(10)
                }
                .frame(height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(on ? K.sageDeep : p.border.opacity(0.9), lineWidth: on ? 1.8 : 0.7)
                )
                Text(label)
                    .font(KType.caption(11).weight(on ? .medium : .regular))
                    .foregroundStyle(on ? K.ink : K.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    /// The dial is the app's own idea and stays the default, but it is a gesture to
    /// learn, and not everyone wants to learn one to reach their own archive.
    private var navStyleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How you get around").eyebrowStyle(K.inkFaint)
            VStack(spacing: 0) {
                ForEach(Array(NavStyle.allCases.enumerated()), id: \.element) { i, style in
                    Button {
                        Haptics.tap()
                        withAnimation(KMotion.gentle) { navRaw = style.rawValue }
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: style.icon)
                                .font(.system(size: 16, weight: .light)).foregroundStyle(K.sage)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(style.title).font(KType.body(15)).foregroundStyle(K.ink)
                                Text(style.note).font(KType.caption(12)).foregroundStyle(K.inkSoft)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: navRaw == style.rawValue ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 17, weight: .light))
                                .foregroundStyle(navRaw == style.rawValue ? K.sageDeep : K.border)
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 16).padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                    if i < NavStyle.allCases.count - 1 { HairLine() }
                }
            }
            .cardSurface()
        }
    }

    /// The icon on the home screen. Two across, so the artwork is big enough to
    /// actually choose between.
    @ViewBuilder
    private var appIconBlock: some View {
        if icons.isSupported {
            VStack(alignment: .leading, spacing: 10) {
                Text("The icon on your home screen").eyebrowStyle(K.inkFaint)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(AppIconOption.allCases) { option in
                        iconChoice(option)
                    }
                }
                if let failure = icons.failure {
                    Text(failure).font(KType.caption(12)).foregroundStyle(Color(hex: 0x9A5B4C))
                        .padding(.leading, 2)
                }
            }
        }
    }

    private func iconChoice(_ option: AppIconOption) -> some View {
        let on = icons.selected == option
        let locked = option != .default && !store.has(.icons)
        return Button {
            Haptics.tap()
            if locked { offer(.icons); return }
            withAnimation(KMotion.gentle) { icons.set(option) }
        } label: {
            HStack(spacing: 11) {
                Image(option.preview)
                    .resizable().scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(K.ink.opacity(0.12), lineWidth: 0.7))
                    .shadow(color: K.shadowInk.opacity(0.12), radius: 5, y: 2)
                    .overlay(alignment: .bottomTrailing) {
                        if locked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8.5, weight: .bold)).foregroundStyle(K.onAccent)
                                .frame(width: 19, height: 19)
                                .background(Circle().fill(K.isClear ? K.sage : K.gold))
                                .overlay(Circle().strokeBorder(K.surface, lineWidth: 1.5))
                                .offset(x: 5, y: 5)
                        }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title).font(KType.body(14).weight(on ? .medium : .regular))
                        .foregroundStyle(K.ink).lineLimit(1)
                    Text(option.note).font(KType.caption(11)).foregroundStyle(K.inkSoft)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(K.surface)
                    .shadow(color: K.shadowInk.opacity(0.05), radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(on ? K.sageDeep : K.border.opacity(0.75),
                                  lineWidth: on ? 1.6 : 0.7)
            )
        }
        .buttonStyle(.plain)
    }

    /// Not everyone wants their letters in a hand. The choice applies wherever a
    /// letter is shown — writing it, reading it back, and in the legacy book.
    private var letterFaceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How a letter is written").eyebrowStyle(K.inkFaint)
            VStack(spacing: 0) {
                ForEach(Array(LetterFace.allCases.enumerated()), id: \.element) { i, f in
                    Button {
                        Haptics.tap()
                        withAnimation(KMotion.gentle) { faceRaw = f.rawValue }
                    } label: {
                        HStack(spacing: 13) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(f.title).font(KType.body(15)).foregroundStyle(K.ink)
                                Text(f.note).font(KType.caption(12)).foregroundStyle(K.inkSoft)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 8)
                            Text("My dearest,")
                                .font(f.font(17)).foregroundStyle(K.inkFaint)
                                .lineLimit(1)
                            Image(systemName: faceRaw == f.rawValue ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 17, weight: .light))
                                .foregroundStyle(faceRaw == f.rawValue ? K.sageDeep : K.border)
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 16).padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                    if i < LetterFace.allCases.count - 1 { HairLine() }
                }
            }
            .cardSurface()
        }
    }

    private var privacyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Privacy").eyebrowStyle(K.inkFaint)
            VStack(alignment: .leading, spacing: 11) {
                line("lock", "Everything stays on your device. No account, no server, no feed.")
                line("eye.slash", "Nobody sees your Kinward unless you decide to share it.")
                line("hand.raised", "No advertising. Your story is never a product.")
            }
            .padding(16).cardSurface()

            Button { Haptics.tap(); gate.lock() } label: {
                Text("Lock private sections now").font(KType.body(14)).foregroundStyle(K.ink)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Capsule().fill(K.surface).overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
            }
            .buttonStyle(.plain)

            Button { Haptics.tap(); confirmReset = true } label: {
                Text("Erase everything").font(KType.body(14)).foregroundStyle(Color(hex: 0x9A5B4C))
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Capsule().strokeBorder(K.border, lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
    }
    /// The two documents, readable in the app itself so they work with no signal
    /// and before any website exists, and the way to reach a person.
    private var legalBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Terms & privacy").eyebrowStyle(K.inkFaint)
            VStack(spacing: 0) {
                ForEach(LegalDoc.allCases) { doc in
                    Button { Haptics.tap(); legal = doc } label: {
                        legalRow(doc.icon, doc.title, trailing: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    HairLine().padding(.leading, 52)
                }
                Button {
                    Haptics.tap()
                    Task { await store.manage() }
                } label: {
                    legalRow("creditcard", "Manage subscription", trailing: "arrow.up.right")
                }
                .buttonStyle(.plain)
                if let email = Publisher.supportEmail, let url = URL(string: "mailto:\(email)") {
                    HairLine().padding(.leading, 52)
                    Link(destination: url) {
                        legalRow("envelope", "Contact support", trailing: "arrow.up.right")
                    }
                    .buttonStyle(.plain)
                }
            }
            .cardSurface()
        }
    }

    #if DEBUG
    /// Debug builds only, and compiled out of the App Store build: a sample family
    /// to fill every screen for screenshots, and Plus switched on without buying it.
    private var testingBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("For screenshots · debug only").eyebrowStyle(K.inkFaint)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(sampleLoaded
                         ? "A sample family is loaded: memories, letters, voice, lessons, family history, documents and a four-generation tree. Removing it takes out only what it added."
                         : "Fills Kinward with a sample family — memories with photographs, sealed letters, voice notes, lessons, recipes, documents and a family tree. Your own entries stay as they are.")
                        .font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        Haptics.tap()
                        withAnimation(KMotion.gentle) {
                            if sampleLoaded { SampleContent.remove(from: ctx) }
                            else { SampleContent.load(into: ctx, profile: profile) }
                            sampleLoaded = SampleContent.isLoaded
                        }
                        Haptics.kept()
                    } label: {
                        Text(sampleLoaded ? "Remove sample content" : "Load sample content")
                            .font(KType.body(14.5).weight(.medium))
                            .foregroundStyle(sampleLoaded ? Color(hex: 0x9A5B4C) : K.onAccent)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Capsule().fill(sampleLoaded ? K.surface : K.sageDeep))
                            .overlay(Capsule().strokeBorder(sampleLoaded ? K.border : .clear, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                HairLine()
                Toggle(isOn: Binding(get: { store.testUnlock },
                                     set: { v in withAnimation(KMotion.gentle) { store.testUnlock = v } })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unlock Plus for testing").font(KType.body(15)).foregroundStyle(K.ink)
                        Text("The book, Pass it on, Clear and every icon, without buying.")
                            .font(KType.caption(12)).foregroundStyle(K.inkSoft)
                    }
                }
                .tint(K.sage).padding(.horizontal, 16).padding(.vertical, 12)
            }
            .cardSurface()
        }
    }
    #endif

    private func legalRow(_ icon: String, _ title: String, trailing: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .light)).foregroundStyle(K.sage)
                .frame(width: 24)
            Text(title).font(KType.body(15)).foregroundStyle(K.ink)
            Spacer()
            Image(systemName: trailing).font(.system(size: 12, weight: .medium))
                .foregroundStyle(K.inkFaint.opacity(0.7))
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func line(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon).font(.system(size: 12, weight: .light)).foregroundStyle(K.sage).frame(width: 18)
            Text(text).font(KType.body(14)).foregroundStyle(K.inkSoft).lineSpacing(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }

    private var aboutBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { Haptics.tap(); replayIntro = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .light)).foregroundStyle(K.gold)
                        .frame(width: 42, height: 42)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(K.goldSoft.opacity(0.3)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("See the introduction again")
                            .font(KType.body(15.5).weight(.medium)).foregroundStyle(K.ink)
                        Text("Revisit why you started, and change what you told us.")
                            .font(KType.caption(12)).foregroundStyle(K.inkSoft)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(K.inkFaint.opacity(0.6))
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .cardSurface(radius: 18)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)

            Button {
                Haptics.tap()
                profile.hasSeenTutorial = false
                try? ctx.save()
                dismiss()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "hand.point.up.left")
                        .font(.system(size: 15, weight: .light)).foregroundStyle(K.sage)
                        .frame(width: 42, height: 42)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(K.bgDeep.opacity(0.7)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Walk me through it again")
                            .font(KType.body(15.5).weight(.medium)).foregroundStyle(K.ink)
                        Text("The short tour of Home, as it was on the first day.")
                            .font(KType.caption(12)).foregroundStyle(K.inkSoft)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(K.inkFaint.opacity(0.6))
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .cardSurface(radius: 18)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)

            HairLine().padding(.vertical, 8)
            Text("Kinward").font(.serif(19)).foregroundStyle(K.ink)
            Text("Your story. Their future.").font(KType.body(14)).foregroundStyle(K.inkSoft)
            Text("Version \(Self.version)").font(KType.caption(12)).foregroundStyle(K.inkFaint)
            Marginalia(text: "Some things should not\ndisappear when we do.").padding(.top, 12)
        }
    }

    /// Read from the bundle, so the number shown is the one that shipped.
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = info?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func eraseAll() {
        for m in memories { m.photoRefs.forEach { MediaStore.delete($0) }; MediaStore.delete(m.audioRef); ctx.delete(m) }
        for l in letters { l.photoRefs.forEach { MediaStore.delete($0) }; MediaStore.delete(l.audioRef); ctx.delete(l) }
        for r in recordings { MediaStore.delete(r.fileRef); ctx.delete(r) }
        for l in lessons { MediaStore.delete(l.audioRef); ctx.delete(l) }
        for s in stories { s.photoRefs.forEach { MediaStore.delete($0) }; MediaStore.delete(s.audioRef); ctx.delete(s) }
        for p in people { MediaStore.delete(p.photoRef); ctx.delete(p) }
        try? ctx.save()
        Haptics.kept()
        dismiss()
    }
}


/// A miniature of Home drawn straight from one theme's palette, independent of the
/// theme currently in use — so both can be compared side by side.
private struct ThemePreview: View {
    let theme: AppTheme
    /// At the app's current age, so the choice is shown as it would really look.
    private var p: Palette { ThemeStore.shared.palette(for: theme) }

    private func display(_ size: CGFloat) -> Font {
        theme == .clear ? .system(size: size, weight: .bold)
                        : .system(size: size, design: .serif)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Good evening").font(.system(size: 7)).foregroundStyle(p.inkSoft)
            Text("Ali").font(display(15)).foregroundStyle(p.ink)

            Text(theme == .clear ? "THIS WEEK" : "THIS WEEK")
                .font(.system(size: 5.5, weight: .semibold))
                .tracking(theme == .clear ? 0.2 : 1.2)
                .foregroundStyle(theme == .clear ? p.inkSoft : p.gold)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("What did home feel like?")
                    .font(display(10)).foregroundStyle(p.ink)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text("Answer")
                    .font(.system(size: 6.5, weight: .medium))
                    .foregroundStyle(p.onAccent)
                    .padding(.horizontal, 8).padding(.vertical, 3.5)
                    .background(Capsule().fill(p.sageDeep))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(p.surface)
                    .shadow(color: p.shadowInk.opacity(0.06), radius: 4, y: 2)
            )
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(p.border.opacity(p.cardStroke), lineWidth: 0.5))

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(p.surface)
                        .frame(height: 20)
                        .overlay(Circle().fill(p.sage.opacity(0.85)).frame(width: 5, height: 5))
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 150, alignment: .top)
        .background(
            ZStack {
                p.bg
                if theme == .paper {
                    RadialGradient(colors: [p.goldSoft.opacity(0.25), .clear],
                                   center: .init(x: 0.9, y: 0.1), startRadius: 2, endRadius: 120)
                    AgeMarks(age: K.age, salt: 0x7E3E)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
