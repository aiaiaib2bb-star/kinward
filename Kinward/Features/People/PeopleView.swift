import SwiftUI
import SwiftData
import PhotosUI

struct PeopleView: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var router: Router
    @Query(sort: \Person.createdAt) private var people: [Person]
    @State private var editing: Person?
    @State private var detail: Person?
    @State private var showTree = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(title: "The people\nwho matter.",
                              subtitle: "Their stories, your advice, and what they mean to you.",
                              onBack: { router.goHome() },
                              trailing: { AnyView(RoundIconButton(icon: "plus") { newPerson() }) })

                Button { Haptics.tap(); showTree = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "tree")
                            .font(.system(size: 16, weight: .light)).foregroundStyle(K.gold)
                            .frame(width: 44, height: 44)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(K.goldSoft.opacity(0.28)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Family tree").font(KType.body(16).weight(.medium)).foregroundStyle(K.ink)
                            Text(treeLine).font(KType.caption(12.5)).foregroundStyle(K.inkSoft)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                            .foregroundStyle(K.inkFaint.opacity(0.6))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .cardSurface(radius: 18, fill: K.paper)
                }
                .buttonStyle(.plain)

                if people.isEmpty {
                    QuietEmptyState(icon: "person.2",
                                    title: "Nobody added yet",
                                    message: "Kinward is built around people, not files. Start with one person you're doing this for.",
                                    actionTitle: "Add someone") { newPerson() }
                } else {
                    VStack(spacing: 12) {
                        ForEach(people) { p in
                            Button { Haptics.tap(); detail = p } label: { PersonCard(person: p) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button { editing = p } label: { Label("Edit", systemImage: "pencil") }
                                    Button(role: .destructive) { ctx.delete(p); try? ctx.save() } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                Marginalia(text: KinwardSection.people.marginalia).padding(.top, 8)
            }
            .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 190)
        }
        .background(PaperBackground())
        .sheet(item: $editing) { p in PersonEditor(person: p) }
        .sheet(item: $detail) { p in PersonDetail(person: p) }
        .sheet(isPresented: $showTree) { FamilyTreeView() }
    }

    private var treeLine: String {
        let n = people.filter(\.inTree).count
        return n == 0 ? "How far back can you go?" : "\(n) \(n == 1 ? "name" : "names") across your generations"
    }

    private func newPerson() {
        let p = Person(name: "", relationship: "")
        ctx.insert(p); editing = p
    }
}

struct PersonCard: View {
    let person: Person
    var body: some View {
        HStack(spacing: 14) {
            PersonAvatar(person: person, size: 62)
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name.isEmpty ? "Unnamed" : person.name)
                    .font(.serif(19)).foregroundStyle(K.ink)
                Text(summary).font(KType.caption(13)).foregroundStyle(K.inkSoft).lineLimit(1)
                if person.isTrusted {
                    HStack(spacing: 5) {
                        Image(systemName: "key.fill").font(.system(size: 8))
                        Text("Trusted").font(KType.caption(10.5))
                    }
                    .foregroundStyle(K.gold)
                }
            }
            Spacer()
            if person.accessRequestedAt != nil {
                Circle().fill(K.gold).frame(width: 8, height: 8)
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundStyle(K.inkFaint.opacity(0.6))
        }
        .padding(16)
        .cardSurface()
    }
    private var summary: String {
        var bits: [String] = []
        if !person.relationship.isEmpty { bits.append(person.relationship) }
        let n = person.pieceCount
        bits.append(n == 0 ? "Nothing kept yet" : "\(n) \(n == 1 ? "piece" : "pieces")")
        return bits.joined(separator: " · ")
    }
}

// MARK: - Editor

struct PersonEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var person: Person
    @State private var picked: PhotosPickerItem?
    @State private var hasBirthday: Bool
    @State private var birthday: Date

    init(person: Person) {
        self.person = person
        _hasBirthday = State(initialValue: person.birthday != nil)
        _birthday = State(initialValue: person.birthday ?? Date(timeIntervalSince1970: 0))
    }

    private let relationships = ["Daughter", "Son", "Partner", "Mother", "Father", "Grandchild",
                                 "Sister", "Brother", "Friend", "Mentor", "Someone else"]

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // The picker's label closure is @Sendable, so read the model here.
                        let initials = person.initials
                        let photoRef = person.photoRef
                        let seed = person.seed

                        HStack {
                            Spacer()
                            PhotosPicker(selection: $picked, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    AvatarBadge(initials: initials, photoRef: photoRef,
                                                seed: seed, size: 104)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 11)).foregroundStyle(K.surface)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(K.sageDeep))
                                        .overlay(Circle().strokeBorder(K.bg, lineWidth: 2))
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, 10)

                        FormLabel(text: "Name")
                        KField(placeholder: "Their name", text: $person.name, serif: true, size: 19)

                        FormLabel(text: "Who they are to you")
                        FlowLayout(spacing: 8) {
                            ForEach(relationships, id: \.self) { r in
                                let on = person.relationship == r
                                Button { Haptics.tap(); person.relationship = r } label: {
                                    Text(r).font(KType.body(14))
                                        .foregroundStyle(on ? K.surface : K.ink)
                                        .padding(.horizontal, 14).padding(.vertical, 9)
                                        .background(Capsule().fill(on ? K.sageDeep : K.surface)
                                            .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Toggle(isOn: $hasBirthday.animation(KMotion.gentle)) {
                            Text("I know their birthday").font(KType.body(15)).foregroundStyle(K.ink)
                        }
                        .tint(K.sage)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .cardSurface(radius: 15)

                        if hasBirthday {
                            DatePicker("", selection: $birthday, displayedComponents: .date)
                                .datePickerStyle(.compact).labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .cardSurface(radius: 15)
                        }

                        FormLabel(text: "Notes")
                        KTextArea(placeholder: "What you'd want someone to know about them.",
                                  text: $person.notes, minHeight: 110, font: KType.body(15))

                        trustedBlock
                    }
                    .padding(.horizontal, 22).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { save(); dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) { Text("Person").font(.serif(16)).foregroundStyle(K.ink) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save(); Haptics.kept(); dismiss() }
                        .font(KType.body(15).weight(.medium)).foregroundStyle(K.sageDeep)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data), let ref = MediaStore.saveImage(img) {
                    await MainActor.run { MediaStore.delete(person.photoRef); person.photoRef = ref; Haptics.kept() }
                }
            }
        }
    }

    private var trustedBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HairLine().padding(.vertical, 6)
            Toggle(isOn: Binding(
                get: { person.accessRole == .trusted },
                set: { person.accessRole = $0 ? .trusted : .none }
            ).animation(KMotion.gentle)) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("A trusted person").font(KType.body(15)).foregroundStyle(K.ink)
                    Text("They can ask to see what you've prepared. Nothing opens without you.")
                        .font(KType.caption(12)).foregroundStyle(K.inkSoft)
                }
            }
            .tint(K.sage)
            .padding(.horizontal, 16).padding(.vertical, 13)
            .cardSurface(radius: 15)

            if person.accessRole != .none {
                KField(placeholder: "Their email (optional)", text: $person.trustedEmail)
            }
        }
    }

    private func save() {
        person.birthday = hasBirthday ? birthday : nil
        if person.name.trimmingCharacters(in: .whitespaces).isEmpty && person.pieceCount == 0 {
            ctx.delete(person)
        }
        try? ctx.save()
    }
}
