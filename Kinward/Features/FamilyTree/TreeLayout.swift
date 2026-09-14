import SwiftUI

/// Turns a flat list of relatives into coordinates.
///
/// Generations are rows. Within a row, a person wants to sit under the middle of
/// their parents; where that isn't possible they take the next free slot. A single
/// upward pass then re-centres parents over their children, which is what makes a
/// hand-drawn tree look tidy rather than merely correct.
struct TreeLayout {
    struct Placed: Identifiable {
        let id: UUID
        let person: Person
        let point: CGPoint
    }
    struct Link: Identifiable {
        let id: String
        let from: CGPoint      // parent, bottom centre
        let to: CGPoint        // child, top centre
        let junction: CGFloat  // y of the horizontal run between them
    }

    static let nodeWidth: CGFloat = 92
    static let nodeHeight: CGFloat = 104
    static let hGap: CGFloat = 20
    static let rowHeight: CGFloat = 168

    private(set) var placed: [Placed] = []
    private(set) var links: [Link] = []
    private(set) var rows: [(Generation, CGFloat)] = []
    private(set) var size: CGSize = .zero

    private var step: CGFloat { Self.nodeWidth + Self.hGap }

    init(people: [Person]) {
        guard !people.isEmpty else { return }

        let byID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
        let gens = Set(people.map(\.generationRaw)).sorted()
        var x: [UUID: CGFloat] = [:]

        // Downward pass: each generation settles under the one above it.
        var previousRow: [Person] = []
        for g in gens {
            var row = people.filter { $0.generationRaw == g }
            row = order(row, previousRow: previousRow, x: x, byID: byID)

            // No sentinel: the first person in a row has no left-hand neighbour to
            // clear, and a huge placeholder would poison every later coordinate.
            var cursor: CGFloat? = nil
            for person in row {
                let floorX = cursor.map { $0 + step }
                let put: CGFloat
                switch (desiredX(for: person, x: x), floorX) {
                case let (wanted?, floor?): put = max(wanted, floor)
                case let (wanted?, nil):    put = wanted
                case let (nil, floor?):     put = floor
                case (nil, nil):            put = 0
                }
                x[person.id] = put
                cursor = put
            }
            previousRow = row
        }

        // Upward pass: a couple should sit over the middle of their children.
        for g in gens.reversed().dropFirst() {
            let row = people.filter { $0.generationRaw == g }.sorted { (x[$0.id] ?? 0) < (x[$1.id] ?? 0) }
            for (i, person) in row.enumerated() {
                let kids = people.filter { $0.parentIDs.contains(person.id) }
                guard !kids.isEmpty else { continue }
                let wanted = kids.compactMap { x[$0.id] }.reduce(0, +) / CGFloat(kids.count)
                let lower = i > 0 ? (x[row[i - 1].id] ?? -.greatestFiniteMagnitude) + step : -.greatestFiniteMagnitude
                let upper = i < row.count - 1 ? (x[row[i + 1].id] ?? .greatestFiniteMagnitude) - step : .greatestFiniteMagnitude
                x[person.id] = min(max(wanted, lower), upper)
            }
        }

        // Normalise to a positive canvas.
        let minX = x.values.min() ?? 0
        let maxX = x.values.max() ?? 0
        for k in x.keys { x[k]! -= minX - Self.nodeWidth / 2 }

        let topGen = gens.first ?? 0
        func y(_ g: Int) -> CGFloat {
            CGFloat(g - topGen) * Self.rowHeight + Self.nodeHeight / 2 + 16
        }

        placed = people.compactMap { p in
            guard let px = x[p.id] else { return nil }
            return Placed(id: p.id, person: p, point: CGPoint(x: px, y: y(p.generationRaw)))
        }
        rows = gens.compactMap { g in
            guard let gen = Generation(rawValue: g) else { return nil }
            return (gen, y(g))
        }

        let points = Dictionary(uniqueKeysWithValues: placed.map { ($0.id, $0.point) })
        links = people.flatMap { child -> [Link] in
            guard let cp = points[child.id] else { return [] }
            return child.parentIDs.compactMap { pid in
                guard let pp = points[pid] else { return nil }
                return Link(id: "\(pid)-\(child.id)",
                            from: CGPoint(x: pp.x, y: pp.y + Self.nodeHeight / 2 - 22),
                            to: CGPoint(x: cp.x, y: cp.y - Self.nodeHeight / 2 + 8),
                            junction: pp.y + Self.rowHeight / 2 - 10)
            }
        }

        size = CGSize(width: (maxX - minX) + Self.nodeWidth * 1.5,
                      height: CGFloat(gens.count) * Self.rowHeight + 40)
    }

    /// Parents first by the side of the family they're on, then by where their
    /// own children ended up, so branches don't cross.
    private func order(_ row: [Person], previousRow: [Person], x: [UUID: CGFloat],
                       byID: [UUID: Person]) -> [Person] {
        var sorted = row.sorted { a, b in
            let ax = desiredX(for: a, x: x), bx = desiredX(for: b, x: x)
            switch (ax, bx) {
            case let (a?, b?) where a != b: return a < b
            case (nil, _?): return false
            case (_?, nil): return true
            default: break
            }
            if a.branchRaw != b.branchRaw {
                return rank(a.branch) < rank(b.branch)
            }
            return a.createdAt < b.createdAt
        }
        // Keep couples side by side.
        var out: [Person] = []
        var used = Set<UUID>()
        for p in sorted where !used.contains(p.id) {
            out.append(p); used.insert(p.id)
            if let pid = p.partnerID, !used.contains(pid),
               let partner = byID[pid], partner.generationRaw == p.generationRaw {
                out.append(partner); used.insert(pid)
            }
        }
        sorted = out
        return sorted
    }

    private func rank(_ b: FamilyBranch) -> Int {
        switch b { case .paternal: 0; case .unknown: 1; case .maternal: 2 }
    }

    private func desiredX(for person: Person, x: [UUID: CGFloat]) -> CGFloat? {
        let known = person.parentIDs.compactMap { x[$0] }
        guard !known.isEmpty else { return nil }
        return known.reduce(0, +) / CGFloat(known.count)
    }
}
