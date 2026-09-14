import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var phase
    @Query private var profiles: [UserProfile]
    @State private var router = Router()
    @State private var booted = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ZStack {
            if let p = profile {
                if p.hasOnboarded {
                    main(profile: p)
                        .preferredColorScheme(.light)
                        .transition(.opacity)
                } else {
                    OnboardingFlow(profile: p) {
                        withAnimation(KMotion.calm) { try? ctx.save() }
                    }
                    .transition(.opacity)
                }
            } else {
                PaperBackground().overlay(ProgressView().tint(K.sage))
                    .preferredColorScheme(.light)
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
        }
        .onChange(of: phase) { _, new in
            // Leaving the app re-arms the lock over the private sections.
            if new != .active { BiometricGate.shared.lock(); VoicePlayer.shared.stop() }
        }
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

            RadialWheel(router: router) { router.showCapture = true }
        }
        .sheet(isPresented: $router.showCapture) {
            CaptureSheet(router: router)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $router.showSearch) { SearchView() }
        .sheet(isPresented: $router.showSettings) { SettingsView(profile: p) }
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
