import Foundation

struct LifeQuestion: Identifiable, Hashable {
    let id: String
    let text: String
    let theme: Theme
    /// Where an answer naturally belongs once it's written.
    let lands: Landing

    enum Theme: String, CaseIterable {
        case childhood, family, people, lessons, love, work, place, belief, legacy, ordinary
        var title: String {
            switch self {
            case .childhood: "Childhood"; case .family: "Family"; case .people: "People"
            case .lessons: "What you learned"; case .love: "Love"; case .work: "Work"
            case .place: "Places"; case .belief: "What you believe"; case .legacy: "What you leave"
            case .ordinary: "Ordinary days"
            }
        }
    }
    enum Landing { case memory, lesson, familyStory, letter }
}

enum QuestionBank {
    static let all: [LifeQuestion] = [
        // Childhood
        .init(id: "q.home.feel", text: "What did home feel like when you were a child?", theme: .childhood, lands: .memory),
        .init(id: "q.child.detail", text: "What is a childhood memory you can still remember in detail?", theme: .childhood, lands: .memory),
        .init(id: "q.child.smell", text: "What smell takes you straight back to being small?", theme: .childhood, lands: .memory),
        .init(id: "q.child.sunday", text: "What did Sundays look like in your family when you were young?", theme: .childhood, lands: .memory),
        .init(id: "q.child.afraid", text: "What were you afraid of as a child, and what happened to that fear?", theme: .childhood, lands: .memory),
        .init(id: "q.child.free", text: "Where did you go when you wanted to be left alone?", theme: .childhood, lands: .memory),
        .init(id: "q.child.game", text: "What did you play, and who did you play it with?", theme: .childhood, lands: .memory),

        // Family
        .init(id: "q.parents.taught", text: "What did your parents teach you without realising it?", theme: .family, lands: .lesson),
        .init(id: "q.family.story", text: "What family story should never be forgotten?", theme: .family, lands: .familyStory),
        .init(id: "q.grandparents", text: "What do you remember about your grandparents that your children may never know?", theme: .family, lands: .familyStory),
        .init(id: "q.traditions", text: "What traditions do you hope your family continues?", theme: .family, lands: .familyStory),
        .init(id: "q.recipe", text: "Is there a dish in your family that should outlive all of you?", theme: .family, lands: .familyStory),
        .init(id: "q.name", text: "Where does your name come from?", theme: .family, lands: .familyStory),
        .init(id: "q.family.left", text: "Who in your family left somewhere to give the next one a better start?", theme: .family, lands: .familyStory),
        .init(id: "q.family.argue", text: "What did your family argue about, and did it ever get resolved?", theme: .family, lands: .familyStory),

        // People
        .init(id: "q.loved.you", text: "Who loved you at a time when you didn't know how much you needed it?", theme: .people, lands: .memory),
        .init(id: "q.shaped", text: "Who shaped the way you think, and how would you describe them to a stranger?", theme: .people, lands: .memory),
        .init(id: "q.friend.long", text: "Who has known you the longest, and what do they know that no one else does?", theme: .people, lands: .memory),
        .init(id: "q.kindness", text: "What is the kindest thing anyone ever did for you?", theme: .people, lands: .memory),
        .init(id: "q.lost.touch", text: "Who did you lose touch with, and do you think of them still?", theme: .people, lands: .memory),
        .init(id: "q.teacher", text: "Was there a teacher, boss or stranger who changed your direction?", theme: .people, lands: .memory),

        // Lessons
        .init(id: "q.mistake", text: "What mistake changed the way you live?", theme: .lessons, lands: .lesson),
        .init(id: "q.eighteen", text: "What would you tell yourself at eighteen?", theme: .lessons, lands: .lesson),
        .init(id: "q.earlier", text: "What did life teach you that you wish you'd understood earlier?", theme: .lessons, lands: .lesson),
        .init(id: "q.right.people", text: "What have you learned about choosing the right people?", theme: .lessons, lands: .lesson),
        .init(id: "q.money.hard", text: "What did you learn about money the hard way?", theme: .lessons, lands: .lesson),
        .init(id: "q.changed.mind", text: "What have you completely changed your mind about?", theme: .lessons, lands: .lesson),
        .init(id: "q.hard.time", text: "How did you get through the hardest year you've had?", theme: .lessons, lands: .lesson),
        .init(id: "q.apology", text: "What did you learn about apologising — properly?", theme: .lessons, lands: .lesson),
        .init(id: "q.enough", text: "When did you first feel like you had enough?", theme: .lessons, lands: .lesson),

        // Love
        .init(id: "q.first.love", text: "What do you remember about falling in love for the first time?", theme: .love, lands: .memory),
        .init(id: "q.partner.know", text: "What do you want your partner to know that you've never quite said?", theme: .love, lands: .letter),
        .init(id: "q.love.lasts", text: "What actually makes love last, in your experience?", theme: .love, lands: .lesson),
        .init(id: "q.child.born", text: "What do you remember about the day your child was born?", theme: .love, lands: .memory),

        // Work
        .init(id: "q.first.job", text: "What was your first job, and what did it cost you to keep it?", theme: .work, lands: .memory),
        .init(id: "q.proud.work", text: "What work are you proud of that nobody ever praised?", theme: .work, lands: .memory),
        .init(id: "q.career.advice", text: "What would you tell someone starting out in your line of work?", theme: .work, lands: .lesson),
        .init(id: "q.risk", text: "What risk did you take that turned out to be worth it?", theme: .work, lands: .lesson),

        // Place
        .init(id: "q.place.matter", text: "Which place should your family visit one day, and why?", theme: .place, lands: .memory),
        .init(id: "q.house", text: "Describe the house you grew up in, room by room.", theme: .place, lands: .memory),
        .init(id: "q.city", text: "What did your city look like before it changed?", theme: .place, lands: .memory),
        .init(id: "q.journey", text: "What journey changed how you see the world?", theme: .place, lands: .memory),

        // Belief
        .init(id: "q.believe", text: "What do you believe that you can't prove?", theme: .belief, lands: .lesson),
        .init(id: "q.faith", text: "What do you turn to when things are beyond your control?", theme: .belief, lands: .lesson),
        .init(id: "q.fair", text: "What have you decided about fairness?", theme: .belief, lands: .lesson),

        // Legacy
        .init(id: "q.decision", text: "What decision changed the direction of your life?", theme: .legacy, lands: .memory),
        .init(id: "q.proud", text: "What are you most proud of?", theme: .legacy, lands: .lesson),
        .init(id: "q.regret", text: "What do you regret?", theme: .legacy, lands: .lesson),
        .init(id: "q.remembered", text: "What do you hope people remember about you?", theme: .legacy, lands: .letter),
        .init(id: "q.grandchildren", text: "What do you want your grandchildren to know about the world you lived in?", theme: .legacy, lands: .letter),
        .init(id: "q.fifty.years", text: "What advice would you give someone in your family fifty years from now?", theme: .legacy, lands: .letter),
        .init(id: "q.unfinished", text: "What did you start that you'd like someone to finish?", theme: .legacy, lands: .letter),

        // Ordinary days — the ones people forget to record
        .init(id: "q.today", text: "What did today actually look like? The ordinary version.", theme: .ordinary, lands: .memory),
        .init(id: "q.laugh", text: "What still makes you laugh every single time?", theme: .ordinary, lands: .memory),
        .init(id: "q.morning", text: "How do your mornings go, and how long have they gone that way?", theme: .ordinary, lands: .memory),
        .init(id: "q.song", text: "What song would you want played in a room full of people who knew you?", theme: .ordinary, lands: .memory),
        .init(id: "q.handwriting", text: "What do you always carry, and why that one?", theme: .ordinary, lands: .memory),
        .init(id: "q.comfort", text: "What food do you cook when you need comforting?", theme: .ordinary, lands: .memory)
    ]

    static func byID(_ id: String) -> LifeQuestion? { all.first { $0.id == id } }

    /// Weighted toward what the user said they cared about at the start, and away
    /// from anything already answered or set aside.
    static func next(for profile: UserProfile?, excluding extra: Set<String> = []) -> LifeQuestion {
        let done = Set(profile?.answeredQuestionIDs ?? []).union(profile?.skippedQuestionIDs ?? []).union(extra)
        let interests = Set(profile?.interests ?? []).union(profile?.wantsRemembered ?? [])
        let pool = all.filter { !done.contains($0.id) }
        let candidates = pool.isEmpty ? all : pool

        func score(_ q: LifeQuestion) -> Int {
            var s = 0
            for i in interests where matches(interest: i, theme: q.theme) { s += 3 }
            return s
        }
        let best = candidates.map { ($0, score($0) + Int.random(in: 0...2)) }
            .sorted { $0.1 > $1.1 }
        return best.first?.0 ?? all[0]
    }

    private static func matches(interest: String, theme: LifeQuestion.Theme) -> Bool {
        let i = interest.lowercased()
        switch theme {
        case .childhood: return i.contains("childhood")
        case .family: return i.contains("family") || i.contains("grandparent") || i.contains("tradition")
        case .people: return i.contains("people") || i.contains("shaped") || i.contains("forget")
        case .lessons: return i.contains("learn") || i.contains("wish") || i.contains("known")
        case .place: return i.contains("place")
        case .legacy: return i.contains("proud") || i.contains("regret") || i.contains("disappear")
        case .ordinary: return i.contains("favorite") || i.contains("favourite") || i.contains("memor")
        case .love, .work, .belief: return false
        }
    }
}
