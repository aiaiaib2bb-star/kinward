import SwiftUI
import SwiftData

@main
struct KinwardApp: App {
    let container: ModelContainer

    init() {
        // Local-first. The schema is shaped so a CloudKit store can be swapped in
        // later without touching the UI or the domain layer.
        let schema = Schema([
            UserProfile.self, Person.self, MemoryEntry.self, Letter.self, Lesson.self,
            VoiceRecording.self, DocumentItem.self, GuidanceNote.self, Belonging.self,
            FamilyStory.self, LegacyCapsule.self, AnsweredQuestion.self
        ])
        do {
            container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            )
        } catch {
            // A corrupt store should never lock someone out of the app entirely.
            container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        }
        Haptics.prepare()
        // No-op until a key is dropped into Kinward/Resources/RevenueCat.plist.
        Store.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(K.sage)
        }
        .modelContainer(container)
    }
}
