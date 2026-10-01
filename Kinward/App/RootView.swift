import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var phase
    @Query private var profiles: [UserProfile]
    @State private var router = Router()
    @State private var booted = false
    @State private var showTutorial = false
    @AppStorage(NavStyle.storageKey) private var navRaw = NavStyle.dial.rawValue
    private var nav: NavStyle { NavStyle(rawValue: navRaw) ?? .dial }

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ZStack {
            if let p = profile {
                if p.hasOnboarded {
                    main(profile: p)
                        .preferredColorScheme(ThemeStore.shared.theme.scheme)
                        .transition(.opacity)
                } else {
                    OnboardingFlow(profile: p) {
                        withAnimation(KMotion.calm) { try? ctx.save() }
                    }
                    .transition(.opacity)
                }
            } else {
                PaperBackground().overlay(ProgressView().tint(K.sage))
                    .preferredColorScheme(ThemeStore.shared.theme.scheme)
            }
        }
        .animation(KMotion.calm, value: profile?.hasOnboarded)
        .task {
            guard !booted else { return }
            booted = true
            if profiles.isEmpty {
                let p = UserProfile()
                ctx.insert(p)
                try? ctx.save()
            }
            Housekeeping.pruneBlankEntries(in: ctx)
            noteUse()
        }
        .onChange(of: phase) { _, new in
            // Leaving the app re-arms the lock over the private sections.
            if new != .active { BiometricGate.shared.lock(); VoicePlayer.shared.stop() }
            else { noteUse(); Store.shared.settle() }
        }
    }

    /// Counts toward the app's age: one for each day it is opened, and a little
    /// for everything in it.
    private func noteUse() {
        func n<T: PersistentModel>(_: T.Type) -> Int { (try? ctx.fetchCount(FetchDescriptor<T>())) ?? 0 }
        let kept = n(MemoryEntry.self) + n(Letter.self) + n(Lesson.self) + n(VoiceRecording.self)
            + n(FamilyStory.self) + n(DocumentItem.self) + n(GuidanceNote.self) + n(Belonging.self)
        ThemeStore.shared.noteUse(kept: kept)
    }

    @ViewBuilder
    private func main(profile p: UserProfile) -> some View {
        ZStack {
            Group {
                if router.atHome {
                    HomeView(router: router, profile: p)
                        .transition(.opacity)
                } else {
                    section
                        .transition(.opacity)
                }
            }
            .animation(KMotion.gentle, value: router.atHome)
            .animation(KMotion.gentle, value: router.section)

            switch nav {
            case .dial: RadialWheel(router: router) { router.showCapture = true }
            case .bar:  TabBarNav(router: router) { router.showCapture = true }
            }
        }
        .environment(\.navBottomInset, nav.bottomInset)
        // Only over Home, and only once: the tour points at things that are on that
        // screen, so it has nothing to say anywhere else.
        //
        // Plain state rather than a binding onto the model. The tour is presented
        // from inside `overlayPreferenceValue`, which runs during layout, and reading
        // an observable model there — let alone writing one — puts the pass into a
        // loop that never settles.
        .tutorial(isPresented: $showTutorial, style: nav) {
            p.hasSeenTutorial = true
            try? ctx.save()
        }
        .onAppear { offerTutorial(p) }
        .onChange(of: router.atHome) { _, home in
            if home { offerTutorial(p) } else { showTutorial = false }
        }
        .sheet(isPresented: $router.showCapture) {
            CaptureSheet(router: router)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $router.showSearch) { SearchView() }
        .sheet(isPresented: $router.showSettings) { SettingsView(profile: p) }
    }

    /// Shown once, and only on Home. A short delay lets the page settle so the ring
    /// lands on a card that has stopped moving.
    private func offerTutorial(_ p: UserProfile) {
        guard router.atHome, !p.hasSeenTutorial, !showTutorial else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            if router.atHome, !p.hasSeenTutorial { showTutorial = true }
        }
    }

    @ViewBuilder
    private var section: some View {
        switch router.section {
        case .memories:  MemoriesView(router: router)
        case .people:    PeopleView(router: router)
        case .letters:   LettersView(router: router)
        case .lessons:   LessonsView(router: router)
        case .guidance:  GuidanceView(router: router)
        case .documents: DocumentsView(router: router)
        case .legacy:    LegacyView(router: router)
        }
    }
}
