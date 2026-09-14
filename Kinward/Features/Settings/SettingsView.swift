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

    @State private var picked: PhotosPickerItem?
    @State private var gate = BiometricGate.shared
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
                        preferencesBlock
                        privacyBlock
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
                    Image(systemName: "camera.fill").font(.system(size: 11)).foregroundStyle(K.surface)
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

            HairLine().padding(.vertical, 8)
            Text("Kinward").font(.serif(19)).foregroundStyle(K.ink)
            Text("Your story. Their future.").font(KType.body(14)).foregroundStyle(K.inkSoft)
            Text("Version 1.0").font(KType.caption(12)).foregroundStyle(K.inkFaint)
            Marginalia(text: "Some things should not\ndisappear when we do.").padding(.top, 12)
        }
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
