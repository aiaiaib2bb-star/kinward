import Foundation
import SwiftData
import SwiftUI

// MARK: - Shared vocabulary

enum LifeStage: String, Codable, CaseIterable, Identifiable {
    case childhood, youth, earlyAdulthood, building, midlife, later, recent
    var id: String { rawValue }
    var title: String {
        switch self {
        case .childhood: "Childhood"
        case .youth: "Growing up"
        case .earlyAdulthood: "Early adulthood"
        case .building: "Building a life"
        case .midlife: "Midlife"
        case .later: "Later years"
        case .recent: "Recent"
        }
    }
}

enum LessonCategory: String, Codable, CaseIterable, Identifiable {
    case wishIdKnown, whatLifeTaught, relationships, friendship, love, money
    case career, family, mistakes, confidence, growingOlder, decisions
    case believe, changedMyMind
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wishIdKnown: "Things I wish I'd known"
        case .whatLifeTaught: "What life taught me"
        case .relationships: "Relationships"
        case .friendship: "Friendship"
        case .love: "Love"
        case .money: "Money"
        case .career: "Career"
        case .family: "Family"
        case .mistakes: "Mistakes"
        case .confidence: "Confidence"
        case .growingOlder: "Growing older"
        case .decisions: "Decisions"
        case .believe: "Things I believe"
        case .changedMyMind: "Things I changed my mind about"
        }
    }
    var icon: String {
        switch self {
        case .wishIdKnown: "lightbulb"
        case .whatLifeTaught: "book.closed"
        case .relationships: "heart"
        case .friendship: "hands.sparkles"
        case .love: "heart.text.square"
        case .money: "banknote"
        case .career: "briefcase"
        case .family: "house"
        case .mistakes: "arrow.uturn.backward"
        case .confidence: "figure.stand"
        case .growingOlder: "hourglass"
        case .decisions: "arrow.triangle.branch"
        case .believe: "quote.opening"
        case .changedMyMind: "arrow.2.squarepath"
        }
    }
}

enum GuidanceCategory: String, Codable, CaseIterable, Identifiable {
    case important, property, insurance, financial, digital, belongings, responsibilities, contacts
    var id: String { rawValue }
    var title: String {
        switch self {
        case .important: "Important information"
        case .property: "Property"
        case .insurance: "Insurance"
        case .financial: "Financial instructions"
        case .digital: "Digital life"
        case .belongings: "Personal belongings"
        case .responsibilities: "Family responsibilities"
        case .contacts: "Important contacts"
        }
    }
    var subtitle: String {
        switch self {
        case .important: "What they'll need first"
        case .property: "Real estate and its papers"
        case .insurance: "Policies and beneficiaries"
        case .financial: "Accounts, debts, instructions"
        case .digital: "Accounts and where the keys are"
        case .belongings: "Things, and who should have them"
        case .responsibilities: "Who looks after what"
        case .contacts: "People to call"
        }
    }
    var icon: String {
        switch self {
        case .important: "exclamationmark.shield"
        case .property: "house"
        case .insurance: "checkmark.shield"
        case .financial: "chart.line.uptrend.xyaxis"
        case .digital: "key"
        case .belongings: "shippingbox"
        case .responsibilities: "person.2"
        case .contacts: "phone"
        }
    }
    /// Sensitive categories sit behind the lock.
    var isSensitive: Bool {
        switch self {
        case .financial, .digital, .insurance, .property: true
        default: false
        }
    }
}

enum DocumentCategory: String, Codable, CaseIterable, Identifiable {
    case legal, property, financial, insurance, personal, digital, health, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .legal: "Legal"; case .property: "Property"; case .financial: "Financial"
        case .insurance: "Insurance"; case .personal: "Personal"; case .digital: "Digital accounts"
        case .health: "Health"; case .other: "Other"
        }
    }
    var icon: String {
        switch self {
        case .legal: "scroll"; case .property: "house"; case .financial: "banknote"
        case .insurance: "checkmark.shield"; case .personal: "person.text.rectangle"
        case .digital: "key"; case .health: "cross.case"; case .other: "folder"
        }
    }
}

/// When a sealed letter is meant to be opened. Never about death — about occasions.
enum SealCondition: String, Codable, CaseIterable, Identifiable {
    case none, onDate, birthday18, birthday21, wedding, firstChild, hardDay, whenTheyAsk
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "Open any time"
        case .onDate: "On a particular day"
        case .birthday18: "On their 18th birthday"
        case .birthday21: "On their 21st birthday"
        case .wedding: "On their wedding day"
        case .firstChild: "When they have their first child"
        case .hardDay: "On a hard day"
        case .whenTheyAsk: "When they ask for it"
        }
    }
    var icon: String {
        switch self {
        case .none: "envelope.open"
        case .onDate: "calendar"
        case .birthday18, .birthday21: "birthday.cake"
        case .wedding: "sparkles"
        case .firstChild: "figure.and.child.holdinghands"
        case .hardDay: "cloud.rain"
        case .whenTheyAsk: "hand.raised"
        }
    }
}


/// Where someone sits in the tree, relative to the person keeping it.
enum Generation: Int, CaseIterable, Identifiable, Comparable {
    case greatGrandparents = -3
    case grandparents = -2
    case parents = -1
    case you = 0
    case children = 1
    case grandchildren = 2
    var id: Int { rawValue }
    static func < (a: Generation, b: Generation) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .greatGrandparents: "Great-grandparents"
        case .grandparents: "Grandparents"
        case .parents: "Parents"
        case .you: "You"
        case .children: "Children"
        case .grandchildren: "Grandchildren"
        }
    }
    /// The nudge that gets a name out of someone.
    var prompt: String {
        switch self {
        case .greatGrandparents: "Eight people. Most of us can name two or three. Write down whoever you can."
        case .grandparents: "Four people, and everything you are came through them."
        case .parents: "Start here."
        case .you: "The tree is kept from where you stand."
        case .children: "The ones it's all for."
        case .grandchildren: "Even if they aren't here yet."
        }
    }
}

/// What a member of the family may do with the archive.
/// Deliberately only three steps — anything finer becomes a permissions screen
/// nobody reads.
enum FamilyAccess: String, Codable, CaseIterable, Identifiable {
    case none, canAsk, trusted
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "In your tree"
        case .canAsk: "Can ask you things"
        case .trusted: "Trusted with your Kinward"
        }
    }
    var detail: String {
        switch self {
        case .none: "They're part of the family. Nothing is shared."
        case .canAsk: "They can ask to see what you've kept. You answer each time."
        case .trusted: "They can request access, and you choose exactly what opens."
        }
    }
    var icon: String {
        switch self {
        case .none: "person"
        case .canAsk: "hand.raised"
        case .trusted: "key.fill"
        }
    }
}

/// Which side of the family a branch descends from. Only used for ordering,
/// so a tree reads left-to-right the way people draw it on paper.
enum FamilyBranch: String, Codable, CaseIterable {
    case unknown, paternal, maternal
    var title: String {
        switch self {
        case .unknown: "Either side"
        case .paternal: "Father's side"
        case .maternal: "Mother's side"
        }
    }
}

// MARK: - Models

@Model final class UserProfile {
    var firstName: String = ""
    var lastName: String = ""
    var avatarRef: String?
    var hasOnboarded: Bool = false
    var interests: [String] = []
    var wantsRemembered: [String] = []
    var practicalInterests: [String] = []
    var lockSensitive: Bool = true
    var weeklyQuestionEnabled: Bool = true
    var lastQuestionShown: Date?
    var answeredQuestionIDs: [String] = []
    var skippedQuestionIDs: [String] = []
    var createdAt: Date = Date.now

    init() {}
    var displayName: String { firstName.isEmpty ? "there" : firstName }
}

@Model final class Person {
    var id: UUID = UUID()
    var name: String = ""
    var relationship: String = ""
    var photoRef: String?
    var birthday: Date?
    var notes: String = ""
    var isTrusted: Bool = false
    var trustedEmail: String = ""
    var accessGranted: [String] = []
    var accessRequestedAt: Date?
    var lockoutUntil: Date?
    var createdAt: Date = Date.now
    var seed: Int = Int.random(in: 0..<9_999)

    // MARK: Family tree
    // Links are stored as ids rather than SwiftData relationships: the graph is
    // self-referential and tiny, and resolving it in memory keeps the store simple.
    var inTree: Bool = false
    var isSelf: Bool = false
    var generationRaw: Int = 0
    var parentIDs: [UUID] = []
    var partnerID: UUID?
    var branchRaw: String = FamilyBranch.unknown.rawValue
    var birthYear: String = ""
    var deathYear: String = ""
    var isLiving: Bool = true
    var treeNote: String = ""
    var accessRoleRaw: String = FamilyAccess.none.rawValue

    @Relationship(deleteRule: .nullify) var memories: [MemoryEntry]? = []
    @Relationship(deleteRule: .nullify, inverse: \Letter.recipient) var letters: [Letter]? = []
    @Relationship(deleteRule: .nullify, inverse: \VoiceRecording.person) var recordings: [VoiceRecording]? = []
    @Relationship(deleteRule: .nullify, inverse: \Belonging.heir) var belongings: [Belonging]? = []
    @Relationship(deleteRule: .cascade, inverse: \LegacyCapsule.person) var capsule: LegacyCapsule?

    init(name: String, relationship: String, photoRef: String? = nil, birthday: Date? = nil, notes: String = "") {
        self.name = name; self.relationship = relationship
        self.photoRef = photoRef; self.birthday = birthday; self.notes = notes
    }

    var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
    var pieceCount: Int {
        (memories?.count ?? 0) + (letters?.count ?? 0) + (recordings?.count ?? 0) + (belongings?.count ?? 0)
    }

    var generation: Generation {
        get { Generation(rawValue: generationRaw) ?? .you }
        set { generationRaw = newValue.rawValue }
    }
    var branch: FamilyBranch {
        get { FamilyBranch(rawValue: branchRaw) ?? .unknown }
        set { branchRaw = newValue.rawValue }
    }
    /// Reads older records that only carried `isTrusted`, and keeps that flag
    /// truthful for the screens still built around it.
    var accessRole: FamilyAccess {
        get { FamilyAccess(rawValue: accessRoleRaw) ?? (isTrusted ? .trusted : .none) }
        set {
            accessRoleRaw = newValue.rawValue
            isTrusted = newValue == .trusted
            if newValue == .none { accessGranted = [] }
        }
    }
    var lifespan: String {
        switch (birthYear.isEmpty, deathYear.isEmpty) {
        case (false, false): "\(birthYear)–\(deathYear)"
        case (false, true): isLiving ? "b. \(birthYear)" : "\(birthYear)–"
        case (true, false): "d. \(deathYear)"
        case (true, true): ""
        }
    }
    var firstName: String { String(name.split(separator: " ").first ?? "") }
}

@Model final class MemoryEntry {
    var id: UUID = UUID()
    var title: String = ""
    var story: String = ""
    var date: Date?
    var approximateYear: Int?
    var place: String = ""
    var latitude: Double?
    var longitude: Double?
    var whyItMatters: String = ""
    var photoRefs: [String] = []
    var audioRef: String?
    var stageRaw: String = LifeStage.recent.rawValue
    var isDraft: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Person.memories) var people: [Person]? = []

    init(title: String = "", story: String = "") { self.title = title; self.story = story }

    var stage: LifeStage {
        get { LifeStage(rawValue: stageRaw) ?? .recent }
        set { stageRaw = newValue.rawValue }
    }
    var displayYear: Int? { approximateYear ?? date.map { Calendar.current.component(.year, from: $0) } }
}

@Model final class Letter {
    var id: UUID = UUID()
    var title: String = ""
    var salutation: String = ""
    var body: String = ""
    var signature: String = ""
    var photoRefs: [String] = []
    var audioRef: String?
    var sealRaw: String = SealCondition.none.rawValue
    var openOn: Date?
    var isDraft: Bool = true
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var recipient: Person?

    init(title: String = "", body: String = "") { self.title = title; self.body = body }

    var seal: SealCondition {
        get { SealCondition(rawValue: sealRaw) ?? .none }
        set { sealRaw = newValue.rawValue }
    }
    var isSealed: Bool { seal != .none }
}

@Model final class Lesson {
    var id: UUID = UUID()
    var categoryRaw: String = LessonCategory.whatLifeTaught.rawValue
    var prompt: String = ""
    var headline: String = ""
    var body: String = ""
    var audioRef: String?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(category: LessonCategory = .whatLifeTaught, headline: String = "", body: String = "") {
        self.categoryRaw = category.rawValue; self.headline = headline; self.body = body
    }
    var category: LessonCategory {
        get { LessonCategory(rawValue: categoryRaw) ?? .whatLifeTaught }
        set { categoryRaw = newValue.rawValue }
    }
}

@Model final class VoiceRecording {
    var id: UUID = UUID()
    var title: String = ""
    var fileRef: String = ""
    var duration: Double = 0
    var levels: [Double] = []
    var transcript: String = ""
    var note: String = ""
    var createdAt: Date = Date.now
    var person: Person?

    init(title: String = "", fileRef: String = "", duration: Double = 0, levels: [Double] = []) {
        self.title = title; self.fileRef = fileRef; self.duration = duration; self.levels = levels
    }
    var durationText: String {
        let m = Int(duration) / 60, s = Int(duration) % 60
        return String(format: "%d:%02d", m, s)
    }
}

@Model final class DocumentItem {
    var id: UUID = UUID()
    var title: String = ""
    var categoryRaw: String = DocumentCategory.legal.rawValue
    var note: String = ""
    var fileRefs: [String] = []
    var whereToFind: String = ""
    var isSensitive: Bool = false
    var updatedAt: Date = Date.now
    var createdAt: Date = Date.now

    init(title: String = "", category: DocumentCategory = .legal) {
        self.title = title; self.categoryRaw = category.rawValue
        self.isSensitive = [.financial, .digital, .legal].contains(category)
    }
    var category: DocumentCategory {
        get { DocumentCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

@Model final class GuidanceNote {
    var id: UUID = UUID()
    var categoryRaw: String = GuidanceCategory.important.rawValue
    var title: String = ""
    var detail: String = ""
    var whereToFind: String = ""
    var contactName: String = ""
    var contactPhone: String = ""
    var updatedAt: Date = Date.now
    var createdAt: Date = Date.now

    init(category: GuidanceCategory = .important, title: String = "") {
        self.categoryRaw = category.rawValue; self.title = title
    }
    var category: GuidanceCategory {
        get { GuidanceCategory(rawValue: categoryRaw) ?? .important }
        set { categoryRaw = newValue.rawValue }
    }
}

@Model final class Belonging {
    var id: UUID = UUID()
    var name: String = ""
    var detail: String = ""
    var story: String = ""
    var location: String = ""
    var photoRefs: [String] = []
    var createdAt: Date = Date.now
    var heir: Person?

    init(name: String = "") { self.name = name }
}

@Model final class FamilyStory {
    var id: UUID = UUID()
    var title: String = ""
    var subject: String = ""       // "My grandmother Rosa"
    var generation: String = ""    // "Grandparents"
    var body: String = ""
    var origin: String = ""
    var years: String = ""
    var photoRefs: [String] = []
    var audioRef: String?
    var isRecipe: Bool = false
    var isTradition: Bool = false
    var createdAt: Date = Date.now

    init(title: String = "", subject: String = "", generation: String = "") {
        self.title = title; self.subject = subject; self.generation = generation
    }
}

@Model final class LegacyCapsule {
    var id: UUID = UUID()
    var title: String = ""
    var openingMessage: String = ""
    var coverRef: String?
    var includeMemories: Bool = true
    var includeLetters: Bool = true
    var includeVoice: Bool = true
    var includeLessons: Bool = true
    var includeFamilyHistory: Bool = true
    var includeGuidance: Bool = false
    var createdAt: Date = Date.now
    var person: Person?

    init(title: String = "") { self.title = title }
}

@Model final class AnsweredQuestion {
    var id: UUID = UUID()
    var questionID: String = ""
    var question: String = ""
    var answer: String = ""
    var audioRef: String?
    var createdAt: Date = Date.now
    init(questionID: String = "", question: String = "", answer: String = "") {
        self.questionID = questionID; self.question = question; self.answer = answer
    }
}
