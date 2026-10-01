import SwiftUI
import SwiftData

struct FamilyTreeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Person.createdAt) private var everyone: [Person]

    @State private var scale: CGFloat = 1
    @State private var gestureScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var selected: Person?
    @State private var showBuilder = false
    @State private var addingAt: Generation?
    @State private var addingAnyone = false
    @State private var didCentre = false
    @State private var viewport: CGSize = .zero

    private var tree: [Person] { everyone.filter(\.inTree) }
    private var layout: TreeLayout { TreeLayout(people: tree) }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                if tree.isEmpty { empty } else { canvas }
                if !tree.isEmpty { VStack { Spacer(); toolbar } }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    Text("Family tree").font(.serif(16)).foregroundStyle(K.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !tree.isEmpty {
                        Button { Haptics.tap(); addingAnyone = true } label: {
                            Image(systemName: "plus").foregroundStyle(K.ink)
                        }
                    }
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .sheet(isPresented: $showBuilder) { FamilyTreeBuilder() }
        .sheet(item: $selected) { p in TreePersonSheet(person: p, everyone: everyone) }
        .sheet(item: $addingAt) { g in
            TreeQuickAdd(generation: g, everyone: everyone) { selected = $0 }
        }
        .sheet(isPresented: $addingAnyone) {
            TreeQuickAdd(generation: nil, everyone: everyone) { selected = $0 }
        }
    }

    // MARK: Empty

    private var empty: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Who did you\ncome from?")
                    .font(.serif(32)).foregroundStyle(K.ink).lineSpacing(1)
                    .padding(.top, 18)
                Text("Most people can name their four grandparents. Very few can name all eight great-grandparents. Whatever you can remember, write it down — the rest your family may still be able to tell you.")
                    .font(KType.body(15.5)).foregroundStyle(K.inkSoft).lineSpacing(4)

                Image("hero_family_field")
                    .resizable().scaledToFill()
                    .frame(height: 190).frame(maxWidth: .infinity).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: K.rLarge, style: .continuous)
                        .strokeBorder(K.border, lineWidth: 0.8))

                KButton(title: "Build your tree", icon: "arrow.right") { showBuilder = true }

                VStack(alignment: .leading, spacing: 11) {
                    Text("What it's for").eyebrowStyle(K.inkFaint).padding(.top, 8)
                    note("tree", "Names first. Dates, places and stories can come later.")
                    note("key", "Anyone in the tree can be given access — to ask you things, or as a trusted person.")
                    note("lock", "Nothing here leaves your device unless you decide it should.")
                }
                Marginalia(text: "A name written down\nis a name that survives.").padding(.top, 6)
            }
            .padding(.horizontal, 22).padding(.bottom, 50)
        }
    }

    private func note(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon).font(.system(size: 12, weight: .light))
                .foregroundStyle(K.sage).frame(width: 18)
            Text(text).font(KType.body(14)).foregroundStyle(K.inkSoft).lineSpacing(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { geo in
            let l = layout
            ZStack(alignment: .topLeading) {
                Color.clear
                ZStack(alignment: .topLeading) {
                    generationRules(l)
                    connectors(l)
                    ForEach(l.placed) { node in
                        TreeNodeView(person: node.person, isSelf: node.person.isSelf)
                            .position(node.point)
                            .onTapGesture { Haptics.tap(); selected = node.person }
                    }
                    addSlots(l)
                }
                .frame(width: l.size.width, height: l.size.height, alignment: .topLeading)
                .scaleEffect(scale * gestureScale, anchor: .topLeading)
                .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)

                generationLabels(l)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = $0.translation }
                    .onEnded { _ in
                        offset.width += dragOffset.width
                        offset.height += dragOffset.height
                        dragOffset = .zero
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { gestureScale = $0.magnification }
                    .onEnded { _ in
                        scale = min(max(scale * gestureScale, 0.45), 1.8)
                        gestureScale = 1
                    }
            )
            // The first layout pass can report a size the canvas can't be centred in,
            // so wait for a real viewport before choosing an origin.
            .onAppear { viewport = geo.size; centreIfReady(l) }
            .onChange(of: geo.size) { _, new in viewport = new; centreIfReady(l) }
        }
        .clipped()
    }

    /// The rule runs with the canvas; the label stays pinned to the viewport so a
    /// half-built tree still explains itself however far you've panned.
    private func generationRules(_ l: TreeLayout) -> some View {
        ForEach(l.rows, id: \.0) { _, y in
            Rectangle().fill(K.border.opacity(0.45))
                .frame(width: max(l.size.width, 260), height: 0.7)
                .position(x: max(l.size.width, 260) / 2, y: y - TreeLayout.nodeHeight / 2 - 20)
        }
    }

    private func generationLabels(_ l: TreeLayout) -> some View {
        let k = scale * gestureScale
        let dy = offset.height + dragOffset.height
        return ForEach(l.rows, id: \.0) { gen, y in
            Text(gen.title)
                .eyebrowStyle(gen == .you ? K.gold : K.inkFaint.opacity(0.8))
                .fixedSize()
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(K.bg.opacity(0.92)))
                .position(x: 66, y: (y - TreeLayout.nodeHeight / 2 - 20) * k + dy)
                .allowsHitTesting(false)
        }
    }

    private func connectors(_ l: TreeLayout) -> some View {
        Canvas { ctx, _ in
            for link in l.links {
                var path = Path()
                let r: CGFloat = 10
                path.move(to: link.from)
                path.addLine(to: CGPoint(x: link.from.x, y: link.junction - r))
                let goingRight = link.to.x > link.from.x
                path.addQuadCurve(
                    to: CGPoint(x: link.from.x + (goingRight ? r : -r), y: link.junction),
                    control: CGPoint(x: link.from.x, y: link.junction))
                path.addLine(to: CGPoint(x: link.to.x - (goingRight ? r : -r), y: link.junction))
                path.addQuadCurve(
                    to: CGPoint(x: link.to.x, y: link.junction + r),
                    control: CGPoint(x: link.to.x, y: link.junction))
                path.addLine(to: link.to)
                ctx.stroke(path, with: .color(K.border), lineWidth: 1.1)
            }
        }
        .frame(width: l.size.width, height: l.size.height)
        .allowsHitTesting(false)
    }

    /// A ghost slot at the end of every generation, and for the ones not started yet.
    private func addSlots(_ l: TreeLayout) -> some View {
        let occupied = Set(tree.map(\.generationRaw))
        let rowY = Dictionary(uniqueKeysWithValues: l.rows.map { ($0.0.rawValue, $0.1) })
        let rightEdge = Dictionary(
            Set(tree.map(\.generationRaw)).map { g in
                (g, l.placed.filter { $0.person.generationRaw == g }.map(\.point.x).max() ?? 0)
            },
            uniquingKeysWith: { a, _ in a })

        return ForEach(Generation.allCases) { gen in
            if occupied.contains(gen.rawValue), let y = rowY[gen.rawValue] {
                ghost(gen).position(x: (rightEdge[gen.rawValue] ?? 0) + TreeLayout.nodeWidth + TreeLayout.hGap, y: y)
            }
        }
    }

    private func ghost(_ gen: Generation) -> some View {
        Button { Haptics.tap(); addingAt = gen } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .light)).foregroundStyle(K.inkFaint)
                    .frame(width: 54, height: 54)
                    .background(Circle().strokeBorder(K.border, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                Text("Add").font(KType.caption(11.5)).foregroundStyle(K.inkFaint)
            }
            .frame(width: TreeLayout.nodeWidth, height: TreeLayout.nodeHeight)
        }
        .buttonStyle(.plain)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            pill(icon: "minus.magnifyingglass") {
                withAnimation(KMotion.gentle) { scale = max(scale - 0.2, 0.45) }
            }
            pill(icon: "scope") {
                withAnimation(KMotion.settle) { scale = 1; centre(on: layout, in: viewport) }
            }
            pill(icon: "plus.magnifyingglass") {
                withAnimation(KMotion.gentle) { scale = min(scale + 0.2, 1.8) }
            }
            Spacer()
            Button { Haptics.tap(); showBuilder = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "person.badge.plus").font(.system(size: 12, weight: .light))
                    Text("Add more names").font(KType.body(13.5))
                }
                .foregroundStyle(K.onAccent)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(Capsule().fill(K.sageDeep))
                .shadow(color: K.shadowInk.opacity(0.16), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18).padding(.bottom, 14)
    }

    private func pill(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.tap(); action() }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light)).foregroundStyle(K.ink)
                .frame(width: 40, height: 40)
                .background(Circle().fill(K.surface).overlay(Circle().strokeBorder(K.border, lineWidth: 0.8)))
                .shadow(color: K.shadowInk.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func centreIfReady(_ l: TreeLayout) {
        guard !didCentre, viewport.height > 240, !l.placed.isEmpty else { return }
        didCentre = true
        centre(on: l, in: viewport)
    }

    /// Open on the person keeping the tree, not on the top-left corner.
    private func centre(on l: TreeLayout, in viewport: CGSize) {
        guard viewport.height > 0 else { return }
        let anchor = l.placed.first(where: { $0.person.isSelf })?.point
            ?? l.placed.first(where: { $0.person.generationRaw == 0 })?.point
            ?? CGPoint(x: l.size.width / 2, y: l.size.height / 2)
        offset = CGSize(width: viewport.width / 2 - anchor.x,
                        height: viewport.height * 0.62 - anchor.y)
    }
}

// MARK: - Node

struct TreeNodeView: View {
    let person: Person
    var isSelf: Bool = false

    var body: some View {
        VStack(spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                PersonAvatar(person: person, size: 56)
                    .opacity(person.isLiving ? 1 : 0.88)
                    .overlay(
                        Circle().strokeBorder(isSelf ? K.gold : .clear, lineWidth: 2)
                            .padding(-3)
                    )
                if person.accessRole != .none {
                    Image(systemName: person.accessRole.icon)
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(K.onAccent)
                        .frame(width: 17, height: 17)
                        .background(Circle().fill(person.accessRole == .trusted ? K.gold : K.sage))
                        .overlay(Circle().strokeBorder(K.bg, lineWidth: 1.4))
                        .offset(x: 2, y: 1)
                }
            }
            VStack(spacing: 1) {
                Text(person.name.isEmpty ? "Unnamed" : person.firstName)
                    .font(KType.body(12.5).weight(.medium))
                    .foregroundStyle(K.ink)
                    .lineLimit(1)
                if !person.lifespan.isEmpty {
                    Text(person.lifespan).font(KType.caption(10)).foregroundStyle(K.inkFaint)
                        .lineLimit(1)
                } else if !person.relationship.isEmpty {
                    Text(person.relationship).font(KType.caption(10)).foregroundStyle(K.inkFaint)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: TreeLayout.nodeWidth, height: TreeLayout.nodeHeight)
        .contentShape(Rectangle())
    }
}
