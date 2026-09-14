import SwiftUI
import SwiftData

/// The guided pass: ask for names, generation by generation, and take whatever
/// the person can remember. Every field is optional on purpose — a half-finished
/// tree is the normal outcome, and it's still worth having.
struct FamilyTreeBuilder: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var profiles: [UserProfile]
    @Query(sort: \Person.createdAt) private var everyone: [Person]

    @State private var step = 0
    private let totalSteps = 9

    // Committed as we go, so later steps can hang off earlier ones.
    @State private var me: Person?
    @State private var mother: Person?
    @State private var father: Person?
    @State private var grandparents: [Person?] = Array(repeating: nil, count: 4)
    @State private var greats: [Person?] = Array(repeating: nil, count: 8)
    @State private var siblings: [Person] = []
    @State private var partner: Person?
    @State private var children: [Person] = []
    @State private var grandchildren: [Person] = []

    // Drafts for the current step.
    @State private var myName = ""
    @State private var motherName = ""
    @State private var fatherName = ""
    @State private var gpNames = Array(repeating: "", count: 4)
    @State private var ggNames = Array(repeating: "", count: 8)
    @State private var siblingNames: [String] = [""]
    @State private var partnerName = ""
    @State private var childNames: [String] = [""]
    @State private var grandchildNames: [String] = [""]
    @State private var grandchildParent: Person?

    var body: some View {
        ZStack {
            PaperBackground(deep: step % 2 == 0)
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        content
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
                footer
            }
        }
        .animation(KMotion.calm, value: step)
        .onAppear { prime() }
    }

    // MARK: Chrome

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                Button(step == 0 ? "Close" : "Back") {
                    Haptics.tap()
                    if step == 0 { dismiss() } else { withAnimation(KMotion.calm) { step -= 1 } }
                }
                .font(KType.body(15)).foregroundStyle(K.inkSoft)
                Spacer()
                if step > 0 && step < totalSteps - 1 {
                    Button("Finish") { commitCurrent(); dismiss() }
                        .font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
            }
            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule().fill(i <= step ? K.sageDeep.opacity(0.75) : K.border)
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 6)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            KButton(title: step == totalSteps - 1 ? "Done" : (isStepEmpty ? "Skip this one" : "Continue"),
                    style: isStepEmpty && step != totalSteps - 1 ? .quiet : .primary) {
                advance()
            }
            if step > 0 && step < totalSteps - 1 {
                Text("Anything you can't remember, leave blank.")
                    .font(KType.caption(12)).foregroundStyle(K.inkFaint)
            }
        }
        .padding(.horizontal, 24).padding(.bottom, 26).padding(.top, 6)
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: intro
        case 1: youStep
        case 2: parentsStep
        case 3: grandparentsStep
        case 4: greatsStep
        case 5: siblingsStep
        case 6: partnerStep
        case 7: childrenStep
        default: closingStep
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your family tree").eyebrowStyle(K.gold).padding(.top, 8)
            Text("How far back\ncan you go?")
                .font(.serif(34)).foregroundStyle(K.ink).lineSpacing(1)
            Text("Most people can name their four grandparents. Very few can name all eight great-grandparents — and after that, almost nobody.\n\nThis takes a few minutes. Names alone are enough.")
                .font(KType.body(16)).foregroundStyle(K.inkSoft).lineSpacing(5)
            Image("hero_album_letters")
                .resizable().scaledToFill()
                .frame(height: 200).frame(maxWidth: .infinity).clipped()
                .clipShape(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous)
                    .strokeBorder(K.border, lineWidth: 0.8))
                .padding(.top, 4)
        }
    }

    private var youStep: some View {
        stepBody(eyebrow: "Step one", title: "Start with you.",
                 blurb: "The tree is kept from where you stand.") {
            field("Your name", $myName)
        }
    }

    private var parentsStep: some View {
        stepBody(eyebrow: "Step two", title: "Your parents.",
                 blurb: Generation.parents.prompt) {
            field("Mother", $motherName)
            field("Father", $fatherName)
        }
    }

    private var grandparentsStep: some View {
        stepBody(eyebrow: "Step three", title: "Your grandparents.",
                 blurb: Generation.grandparents.prompt) {
            group(label(fatherName, "Father") + "'s parents") {
                field("His father", $gpNames[0])
                field("His mother", $gpNames[1])
            }
            group(label(motherName, "Mother") + "'s parents") {
                field("Her father", $gpNames[2])
                field("Her mother", $gpNames[3])
            }
        }
    }

    private var greatsStep: some View {
        stepBody(eyebrow: "Step four", title: "And theirs.",
                 blurb: Generation.greatGrandparents.prompt) {
            ForEach(0..<4, id: \.self) { i in
                group(label(gpNames[i], ["Father's father", "Father's mother",
                                         "Mother's father", "Mother's mother"][i]) + "'s parents") {
                    field("Father", $ggNames[i * 2])
                    field("Mother", $ggNames[i * 2 + 1])
                }
            }
        }
    }

    private var siblingsStep: some View {
        stepBody(eyebrow: "Step five", title: "Your brothers\nand sisters.",
                 blurb: "Including the ones who are no longer here.") {
            nameList($siblingNames, placeholder: "Their name", addLabel: "Add another")
        }
    }

    private var partnerStep: some View {
        stepBody(eyebrow: "Step six", title: "Your partner.",
                 blurb: "If there's someone who belongs beside you.") {
            field("Their name", $partnerName)
        }
    }

    private var childrenStep: some View {
        stepBody(eyebrow: "Step seven", title: "Your children.",
                 blurb: Generation.children.prompt) {
            if !linkable.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Already in Kinward").eyebrowStyle(K.inkFaint)
                    FlowLayout(spacing: 8) {
                        ForEach(linkable) { p in
                            Button {
                                Haptics.tap()
                                if let i = childNames.firstIndex(where: { $0.isEmpty }) {
                                    childNames[i] = p.name
                                } else {
                                    childNames.append(p.name)
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    PersonAvatar(person: p, size: 22)
                                    Text(p.name).font(KType.body(14))
                                }
                                .foregroundStyle(K.ink)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(Capsule().fill(K.surface)
                                    .overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            nameList($childNames, placeholder: "Their name", addLabel: "Add another child")
        }
    }

    private var closingStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your tree").eyebrowStyle(K.gold).padding(.top, 8)
            Text(countSoFar == 0 ? "Nothing written\ndown yet." : "\(countSoFar) \(countSoFar == 1 ? "name" : "names").")
                .font(.serif(34)).foregroundStyle(K.ink).lineSpacing(1)
            Text(countSoFar == 0
                 ? "You can start any time. Even one name is a beginning."
                 : "Anything you couldn't remember, someone in your family probably can. Ask them, and add it here when they tell you.")
                .font(KType.body(16)).foregroundStyle(K.inkSoft).lineSpacing(5)

            VStack(spacing: 0) {
                ForEach(Generation.allCases) { gen in
                    let n = everyone.filter { $0.inTree && $0.generation == gen }.count
                    if n > 0 {
                        HStack {
                            Text(gen.title).font(KType.body(15)).foregroundStyle(K.inkSoft)
                            Spacer()
                            Text("\(n)").font(.serif(17)).foregroundStyle(K.ink)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        if gen != Generation.allCases.last { HairLine() }
                    }
                }
            }
            .cardSurface()

            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "key").font(.system(size: 12, weight: .light))
                    .foregroundStyle(K.sage).frame(width: 18)
                Text("Tap anyone in the tree to give them access — to ask you things, or as a trusted person.")
                    .font(KType.body(14)).foregroundStyle(K.inkSoft).lineSpacing(2)
            }
            Marginalia(text: "Now they know\nwhere they come from.").padding(.top, 4)
        }
    }

    // MARK: Step scaffolding

    @ViewBuilder
    private func stepBody<C: View>(eyebrow: String, title: String, blurb: String,
                                   @ViewBuilder fields: () -> C) -> some View {
        Text(eyebrow).eyebrowStyle(K.gold).padding(.top, 8)
        Text(title).font(.serif(31)).foregroundStyle(K.ink).lineSpacing(1)
        Text(blurb).font(KType.body(15.5)).foregroundStyle(K.inkSoft).lineSpacing(4)
        VStack(alignment: .leading, spacing: 14) { fields() }.padding(.top, 4)
    }

    @ViewBuilder
    private func group<C: View>(_ title: String, @ViewBuilder fields: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).eyebrowStyle(K.inkFaint)
            fields()
        }
    }

    private func field(_ placeholder: String, _ text: Binding<String>) -> some View {
        KField(placeholder: placeholder, text: text, serif: true, size: 17)
    }

    private func nameList(_ names: Binding<[String]>, placeholder: String, addLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(names.wrappedValue.indices, id: \.self) { i in
                field(placeholder, Binding(
                    get: { i < names.wrappedValue.count ? names.wrappedValue[i] : "" },
                    set: { if i < names.wrappedValue.count { names.wrappedValue[i] = $0 } }))
            }
            Button {
                Haptics.tap()
                withAnimation(KMotion.gentle) { names.wrappedValue.append("") }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .medium))
                    Text(addLabel).font(KType.body(14))
                }
                .foregroundStyle(K.ink)
                .padding(.horizontal, 15).padding(.vertical, 10)
                .background(Capsule().fill(K.surface).overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
            }
            .buttonStyle(.plain)
        }
    }

    private func label(_ name: String, _ fallback: String) -> String {
        let t = name.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? fallback : t
    }

    private var linkable: [Person] {
        everyone.filter { !$0.inTree && !$0.name.isEmpty }
    }
    private var countSoFar: Int { everyone.filter(\.inTree).count }

    private var isStepEmpty: Bool {
        func any(_ xs: [String]) -> Bool { xs.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
        switch step {
        case 0: return false
        case 1: return myName.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return !any([motherName, fatherName])
        case 3: return !any(gpNames)
        case 4: return !any(ggNames)
        case 5: return !any(siblingNames)
        case 6: return partnerName.trimmingCharacters(in: .whitespaces).isEmpty
        case 7: return !any(childNames)
        default: return false
        }
    }

    // MARK: Commit

    private func prime() {
        if let existing = everyone.first(where: { $0.isSelf }) {
            me = existing; myName = existing.name
        } else {
            myName = profiles.first?.firstName ?? ""
        }
    }

    private func advance() {
        commitCurrent()
        Haptics.settle()
        if step >= totalSteps - 1 { dismiss() }
        else { withAnimation(KMotion.calm) { step += 1 } }
    }

    /// Each step writes its own names into the store before moving on, so a person
    /// who stops halfway keeps everything they've already typed.
    private func commitCurrent() {
        switch step {
        case 1:
            me = upsert(me, name: myName, relationship: "You", generation: .you,
                        branch: .unknown, isSelf: true)
        case 2:
            mother = upsert(mother, name: motherName, relationship: "Mother",
                            generation: .parents, branch: .maternal)
            father = upsert(father, name: fatherName, relationship: "Father",
                            generation: .parents, branch: .paternal)
            me?.parentIDs = [mother, father].compactMap(\.?.id)
        case 3:
            let specs: [(String, FamilyBranch, Person?)] = [
                ("Grandfather", .paternal, father), ("Grandmother", .paternal, father),
                ("Grandfather", .maternal, mother), ("Grandmother", .maternal, mother)
            ]
            for i in 0..<4 {
                grandparents[i] = upsert(grandparents[i], name: gpNames[i],
                                         relationship: specs[i].0, generation: .grandparents,
                                         branch: specs[i].1)
            }
            father?.parentIDs = [grandparents[0], grandparents[1]].compactMap(\.?.id)
            mother?.parentIDs = [grandparents[2], grandparents[3]].compactMap(\.?.id)
        case 4:
            for i in 0..<8 {
                let branch: FamilyBranch = i < 4 ? .paternal : .maternal
                greats[i] = upsert(greats[i], name: ggNames[i],
                                   relationship: i % 2 == 0 ? "Great-grandfather" : "Great-grandmother",
                                   generation: .greatGrandparents, branch: branch)
            }
            for g in 0..<4 {
                grandparents[g]?.parentIDs = [greats[g * 2], greats[g * 2 + 1]].compactMap(\.?.id)
            }
        case 5:
            siblings = commitList(siblingNames, existing: siblings, relationship: "Sibling",
                                  generation: .you, branch: .unknown,
                                  parents: me?.parentIDs ?? [])
        case 6:
            partner = upsert(partner, name: partnerName, relationship: "Partner",
                             generation: .you, branch: .unknown)
            if let p = partner, let m = me { p.partnerID = m.id; m.partnerID = p.id }
        case 7:
            let parents = [me, partner].compactMap(\.?.id)
            children = commitList(childNames, existing: children, relationship: "Child",
                                  generation: .children, branch: .unknown, parents: parents,
                                  linkExisting: true)
        default: break
        }
        try? ctx.save()
    }

    /// Creates, updates, or clears one slot. Returns nil when the name was left blank
    /// and nothing had been created for it yet.
    @discardableResult
    private func upsert(_ existing: Person?, name: String, relationship: String,
                        generation: Generation, branch: FamilyBranch,
                        isSelf: Bool = false) -> Person? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            if let e = existing, e.pieceCount == 0, !e.isSelf {
                ctx.delete(e)
            }
            return trimmed.isEmpty && existing?.isSelf == true ? existing : nil
        }
        let person = existing ?? {
            // Reuse someone already in Kinward rather than making a second record.
            if let match = everyone.first(where: {
                $0.name.caseInsensitiveCompare(trimmed) == .orderedSame && !$0.inTree
            }) { return match }
            let p = Person(name: trimmed, relationship: relationship)
            ctx.insert(p)
            return p
        }()
        person.name = trimmed
        if person.relationship.isEmpty { person.relationship = relationship }
        person.generation = generation
        person.branch = branch
        person.isSelf = isSelf
        person.inTree = true
        return person
    }

    private func commitList(_ names: [String], existing: [Person], relationship: String,
                            generation: Generation, branch: FamilyBranch,
                            parents: [UUID], linkExisting: Bool = false) -> [Person] {
        var out: [Person] = []
        for (i, raw) in names.enumerated() {
            let slot = i < existing.count ? existing[i] : nil
            guard let p = upsert(slot, name: raw, relationship: relationship,
                                 generation: generation, branch: branch) else { continue }
            p.parentIDs = parents
            out.append(p)
        }
        return out
    }
}
