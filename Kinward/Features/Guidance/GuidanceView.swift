import SwiftUI
import SwiftData

struct GuidanceView: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var router: Router
    @Environment(\.navBottomInset) private var navBottomInset
    @Query(sort: \GuidanceNote.updatedAt, order: .reverse) private var notes: [GuidanceNote]
    @Query(sort: \Belonging.createdAt, order: .reverse) private var belongings: [Belonging]

    @State private var openCategory: GuidanceCategory?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(title: "Guidance",
                              subtitle: "The practical knowledge that saves them weeks of guessing.",
                              onBack: { router.goHome() })

                ForEach(GuidanceCategory.allCases) { c in
                    Button { Haptics.tap(); openCategory = c } label: {
                        HStack(spacing: 14) {
                            Image(systemName: c.icon)
                                .font(.system(size: 16, weight: .light)).foregroundStyle(K.sage)
                                .frame(width: 42, height: 42)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(K.bgDeep.opacity(0.7)))
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(c.title).font(KType.body(16).weight(.medium)).foregroundStyle(K.ink)
                                    if c.isSensitive {
                                        Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(K.gold)
                                    }
                                }
                                Text(c.subtitle).font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            let n = count(for: c)
                            if n > 0 {
                                Text("\(n)").font(KType.caption(12)).foregroundStyle(K.inkFaint)
                            }
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                                .foregroundStyle(K.inkFaint.opacity(0.6))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                        .cardSurface(radius: 18)
                    }
                    .buttonStyle(.plain)
                }

                Marginalia(text: KinwardSection.guidance.marginalia).padding(.top, 8)
            }
            .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, navBottomInset)
        }
        .background(PaperBackground())
        .overlay(alignment: .top) { StatusBarScrim() }
        .sheet(item: $openCategory) { c in
            LockedContent(required: c.isSensitive, label: c.title) {
                GuidanceCategoryView(category: c)
            }
        }
    }

    private func count(for c: GuidanceCategory) -> Int {
        c == .belongings ? belongings.count : notes.filter { $0.category == c }.count
    }
}

/// Wraps sensitive content behind the device's own lock.
struct LockedContent<Content: View>: View {
    let required: Bool
    let label: String
    @ViewBuilder var content: () -> Content
    @State private var gate = BiometricGate.shared
    @State private var tried = false

    var body: some View {
        Group {
            if !required || gate.stillValid {
                content()
            } else {
                ZStack {
                    PaperBackground(deep: true)
                    VStack(spacing: 18) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 30, weight: .ultraLight)).foregroundStyle(K.gold)
                            .frame(width: 78, height: 78)
                            .background(Circle().fill(K.surface).overlay(Circle().strokeBorder(K.border, lineWidth: 0.8)))
                        Text(label).font(.serif(25)).foregroundStyle(K.ink)
                        Text("This part of your Kinward stays closed until you unlock it.")
                            .font(KType.body(15)).foregroundStyle(K.inkSoft)
                            .multilineTextAlignment(.center).frame(maxWidth: 280).lineSpacing(3)
                        KButton(title: "Unlock with \(gate.biometryName)", icon: "faceid") { unlock() }
                            .frame(maxWidth: 300)
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 30)
                }
            }
        }
        .task { if required && !tried { tried = true; _ = await gate.unlock(reason: "Open \(label)") } }
    }
    private func unlock() { Task { await gate.unlock(reason: "Open \(label)") } }
}

struct GuidanceCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    let category: GuidanceCategory

    @Query private var allNotes: [GuidanceNote]
    @Query(sort: \Belonging.createdAt, order: .reverse) private var belongings: [Belonging]
    @Query(sort: \Person.createdAt) private var people: [Person]

    @State private var editing: GuidanceNote?
    @State private var editingBelonging: Belonging?

    private var notes: [GuidanceNote] {
        allNotes.filter { $0.categoryRaw == category.rawValue }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(category.subtitle).font(KType.body(15)).foregroundStyle(K.inkSoft)
                            .padding(.top, 8)

                        if category == .belongings {
                            belongingsList
                        } else {
                            notesList
                        }
                    }
                    .padding(.horizontal, 22).padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    Text(category.title).font(.serif(16)).foregroundStyle(K.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); add() } label: { Image(systemName: "plus").foregroundStyle(K.ink) }
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .sheet(item: $editing) { n in GuidanceNoteEditor(note: n) }
        .sheet(item: $editingBelonging) { b in BelongingEditor(belonging: b, people: people) }
    }

    @ViewBuilder
    private var notesList: some View {
        if notes.isEmpty {
            QuietEmptyState(icon: category.icon, title: "Nothing here yet",
                            message: emptyCopy, actionTitle: "Add the first one") { add() }
        } else {
            VStack(spacing: 12) {
                ForEach(notes) { n in
                    Button { Haptics.tap(); editing = n } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(n.title.isEmpty ? "Untitled" : n.title)
                                .font(KType.body(16).weight(.medium)).foregroundStyle(K.ink)
                                .multilineTextAlignment(.leading)
                            if !n.detail.isEmpty {
                                Text(n.detail).font(KType.body(14)).foregroundStyle(K.inkSoft)
                                    .lineSpacing(3).lineLimit(3).multilineTextAlignment(.leading)
                            }
                            if !n.whereToFind.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin").font(.system(size: 9))
                                    Text(n.whereToFind).font(KType.caption(12))
                                }
                                .foregroundStyle(K.gold)
                            }
                            if !n.contactName.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "phone").font(.system(size: 9))
                                    Text("\(n.contactName)\(n.contactPhone.isEmpty ? "" : " · \(n.contactPhone)")")
                                        .font(KType.caption(12))
                                }
                                .foregroundStyle(K.inkFaint)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16).cardSurface()
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) { ctx.delete(n); try? ctx.save() } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var belongingsList: some View {
        if belongings.isEmpty {
            QuietEmptyState(icon: "shippingbox", title: "No belongings listed",
                            message: "Objects carry stories. Write down what a thing is, and who should have it.",
                            actionTitle: "Add something") { add() }
        } else {
            VStack(spacing: 12) {
                ForEach(belongings) { b in
                    Button { Haptics.tap(); editingBelonging = b } label: {
                        HStack(spacing: 14) {
                            if let ref = b.photoRefs.first {
                                MediaImage(ref: ref).frame(width: 58, height: 58)
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            } else {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 16, weight: .light)).foregroundStyle(K.sage)
                                    .frame(width: 46, height: 46)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(K.bgDeep.opacity(0.7)))
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(b.name.isEmpty ? "Untitled" : b.name)
                                    .font(KType.body(16).weight(.medium)).foregroundStyle(K.ink)
                                if let h = b.heir {
                                    Text("For \(h.name)").font(KType.caption(12)).foregroundStyle(K.gold)
                                } else if !b.location.isEmpty {
                                    Text(b.location).font(KType.caption(12)).foregroundStyle(K.inkSoft)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                                .foregroundStyle(K.inkFaint.opacity(0.6))
                        }
                        .padding(14).cardSurface(radius: 18)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            b.photoRefs.forEach { MediaStore.delete($0) }
                            ctx.delete(b); try? ctx.save()
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
    }

    private var emptyCopy: String {
        switch category {
        case .important: "The first three things someone would need to know."
        case .property: "Where the deeds are, who the notary is, what to do with the place."
        case .insurance: "Which policies exist, who they pay out to, and the numbers."
        case .financial: "Accounts, debts, standing payments, and your instructions."
        case .digital: "Email, accounts, subscriptions, and where the keys live."
        case .contacts: "The accountant, the lawyer, the neighbour with the spare key."
        case .responsibilities: "Who looks after what, when you no longer can."
        case .belongings: "Objects carry stories."
        }
    }

    private func add() {
        if category == .belongings {
            let b = Belonging(); ctx.insert(b); editingBelonging = b
        } else {
            let n = GuidanceNote(category: category); ctx.insert(n); editing = n
        }
    }
}

struct GuidanceNoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var note: GuidanceNote

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        FormLabel(text: "What is it")
                        KField(placeholder: "e.g. Life insurance — Generali", text: $note.title, serif: true, size: 18)

                        FormLabel(text: "What they need to know")
                        KTextArea(placeholder: "Policy numbers, instructions, anything that saves them a phone call.",
                                  text: $note.detail, minHeight: 170)

                        FormLabel(text: "Where to find it")
                        KField(placeholder: "Bottom drawer, study. Blue folder.", text: $note.whereToFind)

                        FormLabel(text: "Who to call")
                        KField(placeholder: "Name", text: $note.contactName)
                        KField(placeholder: "Phone or email", text: $note.contactPhone)

                        HStack(spacing: 9) {
                            Image(systemName: "lock.shield").font(.system(size: 12)).foregroundStyle(K.gold)
                            Text("Kept on this device, behind your lock. Never shared until you say so.")
                                .font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(K.goldSoft.opacity(0.2)))
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { save(); dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    Text(note.category.title).font(.serif(16)).foregroundStyle(K.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Keep") { save(); Haptics.kept(); dismiss() }
                        .font(KType.body(15).weight(.medium)).foregroundStyle(K.sageDeep)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
    }
    private func save() {
        note.updatedAt = .now
        if note.title.isEmpty && note.detail.isEmpty { ctx.delete(note) }
        try? ctx.save()
    }
}

struct BelongingEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var belonging: Belonging
    let people: [Person]

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        PhotoStrip(refs: $belonging.photoRefs, height: 120)
                        PhotoAddButton(label: "Photograph it", refs: $belonging.photoRefs)

                        FormLabel(text: "What it is")
                        KField(placeholder: "My father's watch", text: $belonging.name, serif: true, size: 18)

                        FormLabel(text: "The story behind it")
                        KTextArea(placeholder: "Where it came from, and why it isn't just an object.",
                                  text: $belonging.story, minHeight: 150)

                        FormLabel(text: "Where it is")
                        KField(placeholder: "Top of the wardrobe, in the green box", text: $belonging.location)

                        FormLabel(text: "Who should have it")
                        PersonPickerRow(people: people, selection: Binding(
                            get: { belonging.heir }, set: { belonging.heir = $0 }))

                        Text("Kinward records your wish. It isn't a will — put anything binding in a legal document too.")
                            .font(KType.caption(12)).foregroundStyle(K.inkFaint)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { save(); dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) { Text("Belonging").font(.serif(16)).foregroundStyle(K.ink) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Keep") { save(); Haptics.kept(); dismiss() }
                        .font(KType.body(15).weight(.medium)).foregroundStyle(K.sageDeep)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
    }
    private func save() {
        if belonging.name.isEmpty && belonging.photoRefs.isEmpty { ctx.delete(belonging) }
        try? ctx.save()
    }
}
