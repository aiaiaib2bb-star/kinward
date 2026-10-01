import Foundation

struct LifeQuestion: Identifiable, Hashable {
    let id: String
    let text: String
    let theme: Theme
    /// Where an answer naturally belongs once it's written.
    let lands: Landing

    enum Theme: String, CaseIterable {
        case childhood, family, heritage, people, lessons, love, work
        case place, belief, hardship, joy, ordinary, time, legacy
        var title: String {
            switch self {
            case .childhood: "Childhood"; case .family: "Family"
            case .heritage: "Where you come from"; case .people: "People"
            case .lessons: "What you learned"; case .love: "Love"
            case .work: "Work"; case .place: "Places"
            case .belief: "What you believe"; case .hardship: "What was hard"
            case .joy: "What you loved"; case .ordinary: "Ordinary days"
            case .time: "Time and change"; case .legacy: "What you leave"
            }
        }
    }
    enum Landing { case memory, lesson, familyStory, letter }
}

enum QuestionBank {
    static let all: [LifeQuestion] = [
        // MARK: Childhood
        .init(id: "q.home.feel", text: "What did home feel like when you were a child?", theme: .childhood, lands: .memory),
        .init(id: "q.child.detail", text: "What is a childhood memory you can still remember in detail?", theme: .childhood, lands: .memory),
        .init(id: "q.child.smell", text: "What smell takes you straight back to being small?", theme: .childhood, lands: .memory),
        .init(id: "q.child.sunday", text: "What did Sundays look like in your family when you were young?", theme: .childhood, lands: .memory),
        .init(id: "q.child.afraid", text: "What were you afraid of as a child, and what happened to that fear?", theme: .childhood, lands: .memory),
        .init(id: "q.child.free", text: "Where did you go when you wanted to be left alone?", theme: .childhood, lands: .memory),
        .init(id: "q.child.game", text: "What did you play, and who did you play it with?", theme: .childhood, lands: .memory),
        .init(id: "q.child.trouble", text: "What did you get in trouble for, and was it worth it?", theme: .childhood, lands: .memory),
        .init(id: "q.child.money", text: "Did your family have money when you were young, and how could you tell?", theme: .childhood, lands: .memory),
        .init(id: "q.child.want", text: "What did you want more than anything as a child, and did you ever get it?", theme: .childhood, lands: .memory),
        .init(id: "q.child.school", text: "What was your first day of school like, as far as you remember it?", theme: .childhood, lands: .memory),
        .init(id: "q.child.grew", text: "When did you stop feeling like a child?", theme: .childhood, lands: .memory),
        .init(id: "q.child.food", text: "What did your house smell like at dinnertime?", theme: .childhood, lands: .memory),
        .init(id: "q.child.summer", text: "Describe one summer you never wanted to end.", theme: .childhood, lands: .memory),

        // MARK: Family
        .init(id: "q.parents.taught", text: "What did your parents teach you without realising it?", theme: .family, lands: .lesson),
        .init(id: "q.family.story", text: "What family story should never be forgotten?", theme: .family, lands: .familyStory),
        .init(id: "q.grandparents", text: "What do you remember about your grandparents that your children may never know?", theme: .family, lands: .familyStory),
        .init(id: "q.traditions", text: "What traditions do you hope your family continues?", theme: .family, lands: .familyStory),
        .init(id: "q.recipe", text: "Is there a dish in your family that should outlive all of you?", theme: .family, lands: .familyStory),
        .init(id: "q.name", text: "Where does your name come from?", theme: .family, lands: .familyStory),
        .init(id: "q.family.left", text: "Who in your family left somewhere to give the next one a better start?", theme: .family, lands: .familyStory),
        .init(id: "q.family.argue", text: "What did your family argue about, and did it ever get resolved?", theme: .family, lands: .familyStory),
        .init(id: "q.family.mother", text: "Describe your mother as she was, not as people remember her.", theme: .family, lands: .familyStory),
        .init(id: "q.family.father", text: "Describe your father as he was, not as people remember him.", theme: .family, lands: .familyStory),
        .init(id: "q.family.sibling", text: "What is true about your brothers or sisters that nobody outside the family sees?", theme: .family, lands: .familyStory),
        .init(id: "q.family.parent.now", text: "What do you understand about your parents now that you couldn't then?", theme: .family, lands: .lesson),
        .init(id: "q.family.holidays", text: "How did your family mark the big days of the year?", theme: .family, lands: .familyStory),
        .init(id: "q.family.hands", text: "Whose hands do you remember, and what were they always doing?", theme: .family, lands: .familyStory),
        .init(id: "q.family.gone", text: "Who in your family died before you were ready, and what did you lose with them?", theme: .family, lands: .familyStory),
        .init(id: "q.family.repeat", text: "What did you decide not to repeat from the way you were raised?", theme: .family, lands: .lesson),
        .init(id: "q.family.phrase", text: "What did someone in your family always say, word for word?", theme: .family, lands: .familyStory),

        // MARK: Where you come from
        .init(id: "q.heritage.where", text: "Where is your family actually from, as far back as you can trace it?", theme: .heritage, lands: .familyStory),
        .init(id: "q.heritage.language", text: "What language was spoken in your home, and what happened to it?", theme: .heritage, lands: .familyStory),
        .init(id: "q.heritage.came", text: "Who was the first in your family to arrive where you live now, and why did they come?", theme: .heritage, lands: .familyStory),
        .init(id: "q.heritage.cost", text: "What did your parents or grandparents give up that you benefited from?", theme: .heritage, lands: .familyStory),
        .init(id: "q.heritage.custom", text: "What custom from your background do you still keep, even quietly?", theme: .heritage, lands: .familyStory),
        .init(id: "q.heritage.lost", text: "What has your family already forgotten that you'd like put back?", theme: .heritage, lands: .familyStory),
        .init(id: "q.heritage.faithhome", text: "What was your family's faith, and how was it practised at home?", theme: .heritage, lands: .familyStory),
        .init(id: "q.heritage.object", text: "Is there an object in your family that has been passed down? Where did it start?", theme: .heritage, lands: .familyStory),

        // MARK: People
        .init(id: "q.loved.you", text: "Who loved you at a time when you didn't know how much you needed it?", theme: .people, lands: .memory),
        .init(id: "q.shaped", text: "Who shaped the way you think, and how would you describe them to a stranger?", theme: .people, lands: .memory),
        .init(id: "q.friend.long", text: "Who has known you the longest, and what do they know that no one else does?", theme: .people, lands: .memory),
        .init(id: "q.kindness", text: "What is the kindest thing anyone ever did for you?", theme: .people, lands: .memory),
        .init(id: "q.lost.touch", text: "Who did you lose touch with, and do you think of them still?", theme: .people, lands: .memory),
        .init(id: "q.teacher", text: "Was there a teacher, boss or stranger who changed your direction?", theme: .people, lands: .memory),
        .init(id: "q.people.forgave", text: "Who did you forgive, and what did it take to get there?", theme: .people, lands: .lesson),
        .init(id: "q.people.owe", text: "Who never got thanked properly, and what would you say to them now?", theme: .people, lands: .letter),
        .init(id: "q.people.trusted", text: "Who could you call at three in the morning, and why them?", theme: .people, lands: .memory),
        .init(id: "q.people.difficult", text: "Who was difficult to love, and what did loving them teach you?", theme: .people, lands: .lesson),
        .init(id: "q.people.friend.made", text: "How did you meet your closest friend? Tell it the long way.", theme: .people, lands: .memory),
        .init(id: "q.people.missed", text: "Whose funeral or wedding did you miss, and does it still sit with you?", theme: .people, lands: .memory),

        // MARK: Lessons
        .init(id: "q.mistake", text: "What mistake changed the way you live?", theme: .lessons, lands: .lesson),
        .init(id: "q.eighteen", text: "What would you tell yourself at eighteen?", theme: .lessons, lands: .lesson),
        .init(id: "q.earlier", text: "What did life teach you that you wish you'd understood earlier?", theme: .lessons, lands: .lesson),
        .init(id: "q.right.people", text: "What have you learned about choosing the right people?", theme: .lessons, lands: .lesson),
        .init(id: "q.money.hard", text: "What did you learn about money the hard way?", theme: .lessons, lands: .lesson),
        .init(id: "q.changed.mind", text: "What have you completely changed your mind about?", theme: .lessons, lands: .lesson),
        .init(id: "q.hard.time", text: "How did you get through the hardest year you've had?", theme: .lessons, lands: .lesson),
        .init(id: "q.apology", text: "What did you learn about apologising — properly?", theme: .lessons, lands: .lesson),
        .init(id: "q.enough", text: "When did you first feel like you had enough?", theme: .lessons, lands: .lesson),
        .init(id: "q.lessons.anger", text: "What have you learned about your own temper?", theme: .lessons, lands: .lesson),
        .init(id: "q.lessons.walkaway", text: "How do you know when it's time to walk away from something?", theme: .lessons, lands: .lesson),
        .init(id: "q.lessons.advice.bad", text: "What advice were you given that turned out to be wrong?", theme: .lessons, lands: .lesson),
        .init(id: "q.lessons.body", text: "What have you learned about looking after yourself that took too long?", theme: .lessons, lands: .lesson),
        .init(id: "q.lessons.alone", text: "What did being alone teach you?", theme: .lessons, lands: .lesson),
        .init(id: "q.lessons.asking", text: "What have you learned about asking for help?", theme: .lessons, lands: .lesson),
        .init(id: "q.lessons.promise", text: "What promise did you keep when it would have been easier not to?", theme: .lessons, lands: .lesson),
        .init(id: "q.lessons.strangers", text: "What have you learned about how to treat people who can do nothing for you?", theme: .lessons, lands: .lesson),
        .init(id: "q.lessons.patience", text: "What is worth waiting for, and what is not?", theme: .lessons, lands: .lesson),

        // MARK: Love
        .init(id: "q.first.love", text: "What do you remember about falling in love for the first time?", theme: .love, lands: .memory),
        .init(id: "q.partner.know", text: "What do you want your partner to know that you've never quite said?", theme: .love, lands: .letter),
        .init(id: "q.love.lasts", text: "What actually makes love last, in your experience?", theme: .love, lands: .lesson),
        .init(id: "q.child.born", text: "What do you remember about the day your child was born?", theme: .love, lands: .memory),
        .init(id: "q.love.met", text: "How did you meet the person you built a life with?", theme: .love, lands: .memory),
        .init(id: "q.love.knew", text: "When did you know it was serious?", theme: .love, lands: .memory),
        .init(id: "q.love.hard", text: "What got you through the hardest stretch of your marriage or relationship?", theme: .love, lands: .lesson),
        .init(id: "q.love.ended", text: "What did a relationship that ended teach you?", theme: .love, lands: .lesson),
        .init(id: "q.love.parenting", text: "What do you know about raising children that no book told you?", theme: .love, lands: .lesson),
        .init(id: "q.love.sorry", text: "Is there something you'd apologise to your children for?", theme: .love, lands: .letter),
        .init(id: "q.love.proud.child", text: "What do you admire about each of your children, in their own words?", theme: .love, lands: .letter),
        .init(id: "q.love.said", text: "What do you wish you'd said out loud more often?", theme: .love, lands: .letter),

        // MARK: Work
        .init(id: "q.first.job", text: "What was your first job, and what did it cost you to keep it?", theme: .work, lands: .memory),
        .init(id: "q.proud.work", text: "What work are you proud of that nobody ever praised?", theme: .work, lands: .memory),
        .init(id: "q.career.advice", text: "What would you tell someone starting out in your line of work?", theme: .work, lands: .lesson),
        .init(id: "q.risk", text: "What risk did you take that turned out to be worth it?", theme: .work, lands: .lesson),
        .init(id: "q.work.day", text: "Describe an ordinary working day of yours, start to finish.", theme: .work, lands: .memory),
        .init(id: "q.work.hands", text: "What can you do with your hands that is worth someone learning from you?", theme: .work, lands: .lesson),
        .init(id: "q.work.boss", text: "What did you learn about leading people, or about being led badly?", theme: .work, lands: .lesson),
        .init(id: "q.work.failed", text: "What did you try that didn't work, and what happened next?", theme: .work, lands: .lesson),
        .init(id: "q.work.balance", text: "What did your work cost your family, honestly?", theme: .work, lands: .lesson),
        .init(id: "q.work.stopped", text: "What was it like when the work stopped — retirement, redundancy, or a change?", theme: .work, lands: .memory),

        // MARK: Places
        .init(id: "q.place.matter", text: "Which place should your family visit one day, and why?", theme: .place, lands: .memory),
        .init(id: "q.house", text: "Describe the house you grew up in, room by room.", theme: .place, lands: .memory),
        .init(id: "q.city", text: "What did your city look like before it changed?", theme: .place, lands: .memory),
        .init(id: "q.journey", text: "What journey changed how you see the world?", theme: .place, lands: .memory),
        .init(id: "q.place.first.own", text: "What was the first place that was properly yours?", theme: .place, lands: .memory),
        .init(id: "q.place.return", text: "Is there a place you've gone back to? What was different, and what wasn't?", theme: .place, lands: .memory),
        .init(id: "q.place.table", text: "Describe the table your family ate at, and who sat where.", theme: .place, lands: .memory),
        .init(id: "q.place.window", text: "What did you see out of the window of the place you lived longest?", theme: .place, lands: .memory),
        .init(id: "q.place.never", text: "Where did you always mean to go, and never did?", theme: .place, lands: .memory),

        // MARK: What you believe
        .init(id: "q.believe", text: "What do you believe that you can't prove?", theme: .belief, lands: .lesson),
        .init(id: "q.faith", text: "What do you turn to when things are beyond your control?", theme: .belief, lands: .lesson),
        .init(id: "q.fair", text: "What have you decided about fairness?", theme: .belief, lands: .lesson),
        .init(id: "q.belief.right", text: "How do you decide what the right thing to do is?", theme: .belief, lands: .lesson),
        .init(id: "q.belief.changed.faith", text: "Has what you believe changed over your life? What moved it?", theme: .belief, lands: .lesson),
        .init(id: "q.belief.death", text: "What do you think happens after this, and how does that sit with you?", theme: .belief, lands: .lesson),
        .init(id: "q.belief.good.life", text: "What makes a life a good one, in your judgement?", theme: .belief, lands: .lesson),
        .init(id: "q.belief.stand", text: "What would you not do, whatever you were offered?", theme: .belief, lands: .lesson),
        .init(id: "q.belief.hope", text: "What are you hopeful about, even now?", theme: .belief, lands: .lesson),

        // MARK: What was hard
        .init(id: "q.hard.worst", text: "What is the hardest thing you have lived through?", theme: .hardship, lands: .memory),
        .init(id: "q.hard.helped", text: "Who helped you when you were at your lowest, and how?", theme: .hardship, lands: .memory),
        .init(id: "q.hard.afraid.now", text: "What frightens you these days, and what do you do about it?", theme: .hardship, lands: .lesson),
        .init(id: "q.hard.grief", text: "What did grief actually feel like, and what helped?", theme: .hardship, lands: .lesson),
        .init(id: "q.hard.carry", text: "What have you carried quietly that your family never knew about?", theme: .hardship, lands: .memory),
        .init(id: "q.hard.illness", text: "What did being ill, or caring for someone ill, teach you?", theme: .hardship, lands: .lesson),
        .init(id: "q.hard.start.again", text: "When did you have to start again from nothing?", theme: .hardship, lands: .memory),
        .init(id: "q.hard.advice", text: "What would you say to someone going through what you went through?", theme: .hardship, lands: .letter),

        // MARK: What you loved
        .init(id: "q.joy.happiest", text: "When were you happiest? Describe the day, not the year.", theme: .joy, lands: .memory),
        .init(id: "q.joy.music", text: "What music did you love, and what was going on in your life then?", theme: .joy, lands: .memory),
        .init(id: "q.joy.book", text: "What book, film or story stayed with you, and why that one?", theme: .joy, lands: .memory),
        .init(id: "q.joy.best.day", text: "Describe the best day you can remember, hour by hour.", theme: .joy, lands: .memory),
        .init(id: "q.joy.laughed", text: "When did you laugh until you couldn't breathe?", theme: .joy, lands: .memory),
        .init(id: "q.joy.good.at", text: "What were you quietly very good at?", theme: .joy, lands: .memory),
        .init(id: "q.joy.collected", text: "What did you collect, keep, or never throw away?", theme: .joy, lands: .memory),
        .init(id: "q.joy.free.day", text: "If you had one free day and no obligations, how did you spend it?", theme: .joy, lands: .memory),

        // MARK: Ordinary days — the ones people forget to record
        .init(id: "q.today", text: "What did today actually look like? The ordinary version.", theme: .ordinary, lands: .memory),
        .init(id: "q.laugh", text: "What still makes you laugh every single time?", theme: .ordinary, lands: .memory),
        .init(id: "q.morning", text: "How do your mornings go, and how long have they gone that way?", theme: .ordinary, lands: .memory),
        .init(id: "q.song", text: "What song would you want played in a room full of people who knew you?", theme: .ordinary, lands: .memory),
        .init(id: "q.handwriting", text: "What do you always carry, and why that one?", theme: .ordinary, lands: .memory),
        .init(id: "q.comfort", text: "What food do you cook when you need comforting?", theme: .ordinary, lands: .memory),
        .init(id: "q.ordinary.sound", text: "What sound do you hear most days that you'd miss if it stopped?", theme: .ordinary, lands: .memory),
        .init(id: "q.ordinary.walk", text: "Where do you walk, and what do you think about while you're walking?", theme: .ordinary, lands: .memory),
        .init(id: "q.ordinary.habit", text: "What small habit of yours would your family recognise instantly?", theme: .ordinary, lands: .memory),
        .init(id: "q.ordinary.saturday", text: "What does a Saturday look like in your life right now?", theme: .ordinary, lands: .memory),
        .init(id: "q.ordinary.calm", text: "What settles you when the day has been too much?", theme: .ordinary, lands: .memory),
        .init(id: "q.ordinary.cost", text: "What does a loaf of bread cost right now, and what did it cost when you started out?", theme: .ordinary, lands: .memory),

        // MARK: Time and change
        .init(id: "q.time.world", text: "What has changed most in the world since you were young?", theme: .time, lands: .memory),
        .init(id: "q.time.news", text: "What event did you watch happen, and where were you when it did?", theme: .time, lands: .memory),
        .init(id: "q.time.miss", text: "What do you miss about how things used to be?", theme: .time, lands: .memory),
        .init(id: "q.time.better", text: "What is genuinely better now than it was then?", theme: .time, lands: .lesson),
        .init(id: "q.time.age", text: "What did nobody warn you about getting older?", theme: .time, lands: .lesson),
        .init(id: "q.time.fast", text: "Which years went by too fast, and what were you doing?", theme: .time, lands: .memory),
        .init(id: "q.time.future", text: "What do you imagine your family's life looks like in fifty years?", theme: .time, lands: .letter),

        // MARK: What you leave
        .init(id: "q.decision", text: "What decision changed the direction of your life?", theme: .legacy, lands: .memory),
        .init(id: "q.proud", text: "What are you most proud of?", theme: .legacy, lands: .lesson),
        .init(id: "q.regret", text: "What do you regret?", theme: .legacy, lands: .lesson),
        .init(id: "q.remembered", text: "What do you hope people remember about you?", theme: .legacy, lands: .letter),
        .init(id: "q.grandchildren", text: "What do you want your grandchildren to know about the world you lived in?", theme: .legacy, lands: .letter),
        .init(id: "q.fifty.years", text: "What advice would you give someone in your family fifty years from now?", theme: .legacy, lands: .letter),
        .init(id: "q.unfinished", text: "What did you start that you'd like someone to finish?", theme: .legacy, lands: .letter),
        .init(id: "q.legacy.wrong", text: "What do people get wrong about you?", theme: .legacy, lands: .letter),
        .init(id: "q.legacy.one.thing", text: "If your family only kept one thing you've written, what should it be?", theme: .legacy, lands: .letter),
        .init(id: "q.legacy.wedding", text: "What would you want said at the wedding of someone you won't be there for?", theme: .legacy, lands: .letter),
        .init(id: "q.legacy.hard.day", text: "What do you want them to read on a day when everything has gone wrong?", theme: .legacy, lands: .letter),
        .init(id: "q.legacy.forgive", text: "Is there anyone you want to forgive, in writing, while you still can?", theme: .legacy, lands: .letter),
        .init(id: "q.legacy.permission", text: "What do you want to give your family permission to do after you're gone?", theme: .legacy, lands: .letter),
        .init(id: "q.legacy.worked", text: "What did you get right that you'd want copied?", theme: .legacy, lands: .lesson)
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
        case .heritage: return i.contains("family") || i.contains("grandparent") || i.contains("tradition") || i.contains("history")
        case .people: return i.contains("people") || i.contains("shaped") || i.contains("forget")
        case .lessons: return i.contains("learn") || i.contains("wish") || i.contains("known")
        case .place: return i.contains("place")
        case .legacy: return i.contains("proud") || i.contains("regret") || i.contains("disappear")
        case .ordinary: return i.contains("favorite") || i.contains("favourite") || i.contains("memor")
        case .joy: return i.contains("favorite") || i.contains("favourite") || i.contains("memor") || i.contains("voice")
        case .hardship: return i.contains("moments") || i.contains("changed")
        case .time: return i.contains("disappear") || i.contains("history")
        case .love, .work, .belief: return false
        }
    }
}
