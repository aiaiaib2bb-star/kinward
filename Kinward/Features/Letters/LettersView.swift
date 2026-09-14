import SwiftUI
import SwiftData

struct LettersView: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var router: Router
    @Query(sort: \Letter.updatedAt, order: .reverse) private var letters: [Letter]
    @Query(sort: \Person.createdAt) private var people: [Person]
    @State private var editing: Letter?
    @State private var showTemplates = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(title: "Letters",
                              subtitle: "Words meant for one person, in your own hand.",
                              onBack: { router.goHome() },
                              trailing: { AnyView(RoundIconButton(icon: "plus") { showTemplates = true }) })

                if letters.isEmpty {
                    QuietEmptyState(icon: "envelope",
                                    title: "No letters yet",
                                    message: "A letter is the most direct thing you can leave. Say it now, not one day.",
                                    actionTitle: "Write a letter") { showTemplates = true }
                } else {
                    VStack(spacing: 14) {
                        ForEach(letters) { l in
                            Button { Haptics.tap(); editing = l } label: { LetterCard(letter: l) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) { delete(l) } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }

                Marginalia(text: KinwardSection.letters.marginalia).padding(.top, 8)
            }
            .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 190)
        }
        .background(PaperBackground())
        .sheet(item: $editing) { l in LetterEditor(letter: l) }
        .sheet(isPresented: $showTemplates) {
            LetterTemplates(people: people) { title, salutation, recipient in
                let l = Letter(title: title)
                l.salutation = salutation
                l.recipient = recipient
                ctx.insert(l); try? ctx.save()
                showTemplates = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { editing = l }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func delete(_ l: Letter) {
        l.photoRefs.forEach { MediaStore.delete($0) }
        MediaStore.delete(l.audioRef)
        ctx.delete(l); try? ctx.save(); Haptics.tap()
    }
}

/// A letter, as a piece of folded paper.
struct LetterCard: View {
    let letter: Letter
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let r = letter.recipient {
                        Text("For \(r.name)").eyebrowStyle(K.gold)
                    } else {
                        Text("Unaddressed").eyebrowStyle(K.inkFaint)
                    }
                    Text(letter.title.isEmpty ? "Untitled letter" : letter.title)
                        .font(.serif(21)).foregroundStyle(K.ink)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if letter.isSealed {
                    VStack(spacing: 4) {
                        Image(systemName: letter.seal.icon)
                            .font(.system(size: 13, weight: .light)).foregroundStyle(K.gold)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(K.goldSoft.opacity(0.3)))
                    }
                }
            }

            if !letter.body.isEmpty {
                Text(letter.body)
                    .font(.hand(17))
                    .foregroundStyle(K.inkSoft)
                    .lineSpacing(5)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Nothing written yet.")
                    .font(KType.caption(13)).foregroundStyle(K.inkFaint)
            }

            HStack(spacing: 10) {
                if letter.isSealed {
                    PillTag(text: letter.seal.title)
                }
                if letter.audioRef != nil {
                    Image(systemName: "waveform").font(.system(size: 11)).foregroundStyle(K.sage)
                }
                if !letter.photoRefs.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo").font(.system(size: 10))
                        Text("\(letter.photoRefs.count)").font(KType.caption(11))
                    }
                    .foregroundStyle(K.inkFaint)
                }
                Spacer()
                Text(letter.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(KType.caption(11.5)).foregroundStyle(K.inkFaint)
            }
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: K.rCard, style: .continuous).fill(K.paper)
                RoundedRectangle(cornerRadius: K.rCard, style: .continuous)
                    .fill(LinearGradient(colors: [K.goldSoft.opacity(0.16), .clear],
                                         startPoint: .topTrailing, endPoint: .bottomLeading))
            }
            .shadow(color: K.ink.opacity(0.06), radius: 14, y: 6)
        )
        .overlay(RoundedRectangle(cornerRadius: K.rCard, style: .continuous).strokeBorder(K.border, lineWidth: 0.8))
    }
}

struct LetterTemplates: View {
    let people: [Person]
    var onPick: (String, String, Person?) -> Void
    @Environment(\.dismiss) private var dismiss

    private let templates: [(String, String, String)] = [
        ("To my daughter", "My dearest", "Daughter"),
        ("To my son", "My dear", "Son"),
        ("To my partner", "My love", "Partner"),
        ("To my grandchildren", "To my grandchildren", "Grandchild"),
        ("To my parents", "Dear Mum and Dad", "Mother"),
        ("To someone I miss", "I still think of you", ""),
        ("To my future self", "Dear me", ""),
        ("To whoever finds this", "Whoever you are", "")
    ]

    var body: some View {
        ZStack {
            PaperBackground(deep: true)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Who is it for?").font(.serif(26)).foregroundStyle(K.ink).padding(.top, 26)
                    Text("Pick a starting point. You can change every word of it.")
                        .font(KType.body(14.5)).foregroundStyle(K.inkSoft)

                    if !people.isEmpty {
                        Text("Your people").eyebrowStyle(K.inkFaint).padding(.top, 10)
                        VStack(spacing: 10) {
                            ForEach(people) { p in
                                Button {
                                    Haptics.tap()
                                    onPick("To my \(p.relationship.lowercased().isEmpty ? p.name.lowercased() : p.relationship.lowercased())",
                                           "My dear \(p.name),", p)
                                } label: {
                                    HStack(spacing: 13) {
                                        PersonAvatar(person: p, size: 44)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.name).font(KType.body(16).weight(.medium)).foregroundStyle(K.ink)
                                            Text(p.relationship).font(KType.caption(12)).foregroundStyle(K.inkSoft)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(K.inkFaint.opacity(0.6))
                                    }
                                    .padding(14).cardSurface(radius: 18)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text("Or begin here").eyebrowStyle(K.inkFaint).padding(.top, 10)
                    VStack(spacing: 10) {
                        ForEach(templates, id: \.0) { t in
                            Button {
                                Haptics.tap()
                                let match = people.first { $0.relationship == t.2 }
                                onPick(t.0, match.map { "\(t.1) \($0.name)," } ?? "\(t.1),", match)
                            } label: {
                                HStack {
                                    Text(t.0).font(.serif(18)).foregroundStyle(K.ink)
                                    Spacer()
                                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(K.inkFaint.opacity(0.7))
                                }
                                .padding(.horizontal, 18).padding(.vertical, 16)
                                .cardSurface(radius: 18, fill: K.paper)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 22).padding(.bottom, 40)
            }
        }
    }
}
