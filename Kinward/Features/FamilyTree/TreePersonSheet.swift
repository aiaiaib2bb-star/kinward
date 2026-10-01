import SwiftUI
import SwiftData
import PhotosUI

/// One person in the tree: who they are, where they sit, and what — if anything —
/// they're allowed to see.
struct TreePersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var person: Person
    let everyone: [Person]

    @State private var picked: PhotosPickerItem?
    @State private var pendingSensitive: String?
    @State private var openDetail = false

    private let permissions = ["Memories", "Letters", "Voice", "Family history", "Lessons",
                               "Guidance", "Financial", "Documents", "Digital life", "Property"]
    private let sensitive: Set<String> = ["Guidance", "Financial", "Documents", "Digital life", "Property"]

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Read off the model here — the picker's label closure is
                        // @Sendable and can't reach it.
                        let initials = person.initials
                        let photoRef = person.photoRef
                        let seed = person.seed
                        let ring: Color = person.isSelf ? K.gold : .clear

                        HStack {
                            Spacer()
                            PhotosPicker(selection: $picked, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    AvatarBadge(initials: initials, photoRef: photoRef,
                                                seed: seed, size: 96)
                                        .overlay(Circle()
                                            .strokeBorder(ring, lineWidth: 2)
                                            .padding(-4))
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 11)).foregroundStyle(K.onAccent)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(K.sageDeep))
                                        .overlay(Circle().strokeBorder(K.bg, lineWidth: 2))
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, 6)

                        identity
                        placeInTree
                        accessSection
                        FormLabel(text: "What you remember about them")
                        KTextArea(placeholder: "A detail, a habit, a line they always said.",
                                  text: $person.treeNote, minHeight: 110, font: KType.body(15))
                        footerActions
                    }
                    .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { save(); dismiss() }
                        .font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    Text(person.generation.title).font(.serif(16)).foregroundStyle(K.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Keep") { save(); Haptics.kept(); dismiss() }
                        .font(KType.body(15).weight(.medium)).foregroundStyle(K.sageDeep)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .sheet(isPresented: $openDetail) { PersonDetail(person: person) }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data), let ref = MediaStore.saveImage(img) {
                    await MainActor.run {
                        MediaStore.delete(person.photoRef); person.photoRef = ref; Haptics.kept()
                    }
                }
            }
        }
    }

    // MARK: Blocks

    private var identity: some View {
        VStack(alignment: .leading, spacing: 14) {
            FormLabel(text: "Name")
            KField(placeholder: "Their name", text: $person.name, serif: true, size: 19)

            FormLabel(text: "Who they are")
            KField(placeholder: "Grandmother, brother, cousin…", text: $person.relationship)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    FormLabel(text: "Born")
                    KField(placeholder: "1931", text: $person.birthYear)
                }
                VStack(alignment: .leading, spacing: 8) {
                    FormLabel(text: person.isLiving ? "—" : "Died")
                    KField(placeholder: person.isLiving ? "" : "1998", text: $person.deathYear)
                        .opacity(person.isLiving ? 0.4 : 1)
                        .disabled(person.isLiving)
                }
            }

            Toggle(isOn: $person.isLiving.animation(KMotion.gentle)) {
                Text("Still with us").font(KType.body(15)).foregroundStyle(K.ink)
            }
            .tint(K.sage)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .cardSurface(radius: 15)
        }
    }

    private var placeInTree: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormLabel(text: "Where they sit")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Generation.allCases) { g in
                        let on = person.generation == g
                        Button { Haptics.tap(); person.generation = g } label: {
                            Text(g.title).font(KType.body(13.5))
                                .foregroundStyle(on ? K.onAccent : K.inkSoft)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(Capsule().fill(on ? K.sageDeep : K.surface)
                                    .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            FormLabel(text: "Their parents")
            if candidates(for: person.generationRaw - 1).isEmpty {
                Text("Add someone a generation above first, and you can connect them here.")
                    .font(KType.caption(13)).foregroundStyle(K.inkFaint)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface(radius: 15)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(candidates(for: person.generationRaw - 1)) { p in
                        let on = person.parentIDs.contains(p.id)
                        Button {
                            Haptics.tap()
                            withAnimation(KMotion.gentle) {
                                if on { person.parentIDs.removeAll { $0 == p.id } }
                                else { person.parentIDs.append(p.id) }
                            }
                        } label: {
                            HStack(spacing: 7) {
                                PersonAvatar(person: p, size: 22)
                                Text(p.firstName.isEmpty ? "Unnamed" : p.firstName).font(KType.body(14))
                            }
                            .foregroundStyle(on ? K.onAccent : K.ink)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Capsule().fill(on ? K.sageDeep : K.surface)
                                .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            let peers = candidates(for: person.generationRaw).filter { $0.id != person.id }
            if !peers.isEmpty {
            FormLabel(text: "Partner")
            FlowLayout(spacing: 8) {
                ForEach(peers) { p in
                    let on = person.partnerID == p.id
                    Button {
                        Haptics.tap()
                        withAnimation(KMotion.gentle) {
                            if on {
                                person.partnerID = nil
                                if p.partnerID == person.id { p.partnerID = nil }
                            } else {
                                person.partnerID = p.id
                                p.partnerID = person.id
                            }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            PersonAvatar(person: p, size: 22)
                            Text(p.firstName.isEmpty ? "Unnamed" : p.firstName).font(KType.body(14))
                        }
                        .foregroundStyle(on ? K.onAccent : K.ink)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Capsule().fill(on ? K.sageDeep : K.surface)
                            .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
                    }
                    .buttonStyle(.plain)
                }
            }
            }
        }
    }

    // MARK: Access — the point of putting the family in one place

    private var accessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HairLine().padding(.vertical, 6)
            Text("What they can see").eyebrowStyle(K.gold)

            VStack(spacing: 0) {
                ForEach(Array(FamilyAccess.allCases.enumerated()), id: \.element) { i, role in
                    if i > 0 { HairLine() }
                    Button {
                        Haptics.tap()
                        withAnimation(KMotion.gentle) { person.accessRole = role }
                        save()
                    } label: {
                        HStack(alignment: .top, spacing: 13) {
                            Image(systemName: person.accessRole == role ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 17, weight: .light))
                                .foregroundStyle(person.accessRole == role ? K.sageDeep : K.inkFaint.opacity(0.6))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(role.title).font(KType.body(15.5).weight(.medium)).foregroundStyle(K.ink)
                                Text(role.detail).font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                                    .multilineTextAlignment(.leading).lineSpacing(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .cardSurface()

            if person.accessRole != .none {
                KField(placeholder: "Their email (optional)", text: $person.trustedEmail)
            }

            if person.accessRole == .trusted {
                FormLabel(text: "What opens when you approve")
                VStack(spacing: 0) {
                    ForEach(Array(permissions.enumerated()), id: \.offset) { i, perm in
                        if i > 0 { HairLine() }
                        Toggle(isOn: binding(for: perm)) {
                            HStack(spacing: 7) {
                                Text(perm).font(KType.body(15)).foregroundStyle(K.ink)
                                if sensitive.contains(perm) {
                                    Image(systemName: "lock.fill").font(.system(size: 8)).foregroundStyle(K.gold)
                                }
                            }
                        }
                        .tint(K.sage)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                    }
                }
                .cardSurface()

                if let perm = pendingSensitive {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.shield")
                                .font(.system(size: 14, weight: .light)).foregroundStyle(K.gold)
                            Text("Sharing \(perm.lowercased()) means \(person.firstName.isEmpty ? "they" : person.firstName) could see financial, legal or account information once you approve a request. Only do this for someone you'd trust with the originals.")
                                .font(KType.body(14)).foregroundStyle(K.ink).lineSpacing(3)
                        }
                        HStack(spacing: 10) {
                            Button {
                                Haptics.kept()
                                person.accessGranted.append(perm)
                                withAnimation(KMotion.gentle) { pendingSensitive = nil }
                                save()
                            } label: {
                                Text("Yes, share it").font(KType.body(14)).foregroundStyle(K.onAccent)
                                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                                    .background(Capsule().fill(K.sageDeep))
                            }
                            .buttonStyle(.plain)
                            Button {
                                Haptics.tap()
                                withAnimation(KMotion.gentle) { pendingSensitive = nil }
                            } label: {
                                Text("Not yet").font(KType.body(14)).foregroundStyle(K.ink)
                                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                                    .background(Capsule().fill(K.surface)
                                        .overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(K.goldSoft.opacity(0.3)))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                FormLabel(text: "Quiet period")
                Text("Stop repeated requests for a while. They're simply told you're not ready.")
                    .font(KType.caption(12.5)).foregroundStyle(K.inkSoft).padding(.horizontal, 2)
                HStack(spacing: 8) {
                    ForEach([30, 90, 180, 365], id: \.self) { days in
                        Button {
                            Haptics.tap()
                            person.lockoutUntil = Calendar.current.date(byAdding: .day, value: days, to: .now)
                            save()
                        } label: {
                            Text(quietLabel(days)).font(KType.body(13)).foregroundStyle(K.ink)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Capsule().fill(K.surface)
                                    .overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let l = person.lockoutUntil, l > .now {
                    HStack(spacing: 8) {
                        Image(systemName: "clock").font(.system(size: 11)).foregroundStyle(K.gold)
                        Text("Paused until \(l.formatted(date: .abbreviated, time: .omitted))")
                            .font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                        Spacer()
                        Button("Clear") { person.lockoutUntil = nil; save() }
                            .font(KType.caption(12)).foregroundStyle(K.sage)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(K.goldSoft.opacity(0.22)))
                }
            }

            if person.accessRole != .none {
                Button {
                    Haptics.tap()
                    person.accessRequestedAt = .now
                    save()
                    dismiss()
                } label: {
                    Text("Simulate a request from \(person.firstName.isEmpty ? "them" : person.firstName)")
                        .font(KType.body(13.5)).foregroundStyle(K.inkFaint)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().strokeBorder(K.border, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footerActions: some View {
        VStack(spacing: 10) {
            Button { Haptics.tap(); openDetail = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.stack").font(.system(size: 13, weight: .light))
                    Text("Everything kept for \(person.firstName.isEmpty ? "them" : person.firstName)")
                        .font(KType.body(14.5))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(K.inkFaint.opacity(0.6))
                }
                .foregroundStyle(K.ink)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .cardSurface(radius: 15)
            }
            .buttonStyle(.plain)

            if !person.isSelf {
                Button(role: .destructive) { removeFromTree() } label: {
                    Text(person.pieceCount > 0 ? "Remove from the tree" : "Delete")
                        .font(KType.body(14)).foregroundStyle(Color(hex: 0x9A5B4C))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Capsule().strokeBorder(K.border, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    // MARK: Plumbing

    private func candidates(for generationRaw: Int) -> [Person] {
        everyone.filter { $0.inTree && $0.generationRaw == generationRaw }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func quietLabel(_ d: Int) -> String {
        switch d { case 30: "30 days"; case 90: "90 days"; case 180: "6 months"; default: "1 year" }
    }

    private func binding(for perm: String) -> Binding<Bool> {
        Binding(
            get: { person.accessGranted.contains(perm) },
            set: { on in
                guard on else {
                    person.accessGranted.removeAll { $0 == perm }; save(); return
                }
                guard sensitive.contains(perm) else {
                    person.accessGranted.append(perm); save(); return
                }
                // Asking happens in the sheet itself rather than a modal: a Toggle
                // that raises an alert from its own update is unreliable, and the
                // question reads better next to the switch it's about.
                Task { @MainActor in
                    withAnimation(KMotion.gentle) { pendingSensitive = perm }
                }
            }
        )
    }

    private func save() {
        if person.isLiving { person.deathYear = "" }
        try? ctx.save()
    }

    /// Someone with letters or memories attached leaves the tree but keeps their record.
    private func removeFromTree() {
        Haptics.tap()
        for other in everyone {
            other.parentIDs.removeAll { $0 == person.id }
            if other.partnerID == person.id { other.partnerID = nil }
        }
        if person.pieceCount > 0 {
            person.inTree = false
            person.parentIDs = []
            person.partnerID = nil
        } else {
            MediaStore.delete(person.photoRef)
            ctx.delete(person)
        }
        try? ctx.save()
        dismiss()
    }
}

// MARK: - Quick add

struct TreeQuickAdd: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    var generation: Generation?
    let everyone: [Person]
    var onAdded: (Person) -> Void

    @State private var name = ""
    @State private var relationship = ""
    @State private var chosen: Generation = .you
    @State private var parents: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        FormLabel(text: "Name")
                        KField(placeholder: "Their name", text: $name, serif: true, size: 18)

                        FormLabel(text: "Who they are")
                        KField(placeholder: "Aunt, cousin, grandchild…", text: $relationship)

                        if generation == nil {
                            FormLabel(text: "Where they sit")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Generation.allCases) { g in
                                        let on = chosen == g
                                        Button { Haptics.tap(); chosen = g } label: {
                                            Text(g.title).font(KType.body(13.5))
                                                .foregroundStyle(on ? K.onAccent : K.inkSoft)
                                                .padding(.horizontal, 14).padding(.vertical, 9)
                                                .background(Capsule().fill(on ? K.sageDeep : K.surface)
                                                    .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        let above = everyone.filter { $0.inTree && $0.generationRaw == target.rawValue - 1 }
                        if !above.isEmpty {
                            FormLabel(text: "Their parents")
                            FlowLayout(spacing: 8) {
                                ForEach(above) { p in
                                    let on = parents.contains(p.id)
                                    Button {
                                        Haptics.tap()
                                        if on { parents.remove(p.id) } else { parents.insert(p.id) }
                                    } label: {
                                        HStack(spacing: 7) {
                                            PersonAvatar(person: p, size: 22)
                                            Text(p.firstName.isEmpty ? "Unnamed" : p.firstName).font(KType.body(14))
                                        }
                                        .foregroundStyle(on ? K.onAccent : K.ink)
                                        .padding(.horizontal, 10).padding(.vertical, 7)
                                        .background(Capsule().fill(on ? K.sageDeep : K.surface)
                                            .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    Text("Add to the tree").font(.serif(16)).foregroundStyle(K.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { add() }
                        .font(KType.body(15).weight(.medium))
                        .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? K.inkFaint.opacity(0.5) : K.sageDeep)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .onAppear { chosen = generation ?? .you }
    }

    private var target: Generation { generation ?? chosen }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let p = Person(name: trimmed, relationship: relationship)
        p.generation = target
        p.parentIDs = Array(parents)
        p.inTree = true
        ctx.insert(p)
        try? ctx.save()
        Haptics.kept()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { onAdded(p) }
    }
}
