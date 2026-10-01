#if DEBUG
import AVFoundation
import Foundation
import SwiftData
import UIKit

/// A believable family's Kinward, for screenshots and for seeing every screen with
/// something on it. Debug builds only — none of this is compiled into the App Store
/// build.
///
/// Everything it adds is remembered by id, so "Remove sample content" takes out
/// exactly what it put in and never touches anything typed by hand.
@MainActor
enum SampleContent {
    private static let idsKey = "kinward.sample.ids"

    static var isLoaded: Bool { !ids.isEmpty }

    private static var ids: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: idsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: idsKey) }
    }

    // MARK: - Loading

    static func load(into ctx: ModelContext, profile: UserProfile) {
        guard !isLoaded else { return }
        var made = Set<String>()
        func keep(_ id: UUID) { made.insert(id.uuidString) }

        let cal = Calendar.current
        func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d)) ?? .now
        }
        /// Spread "when it was kept" across the last year and a half, oldest first,
        /// so lists read as something built up over time.
        var tick = 0
        func kept(daysAgo: Int? = nil) -> Date {
            tick += 1
            return cal.date(byAdding: .day, value: -(daysAgo ?? max(1, 540 - tick * 9)), to: .now) ?? .now
        }

        // Photographs: the three in the app, and closer crops of each, so no two
        // memories share the same picture.
        let fieldWide = photo("hero_family_field")
        let fieldKids = photo("hero_family_field", crop: CGRect(x: 0.18, y: 0.42, width: 0.8, height: 0.5))
        let fatherChild = photo("hero_father_child")
        let fatherSunset = photo("hero_father_child", crop: CGRect(x: 0.2, y: 0.05, width: 0.8, height: 0.45))
        let album = photo("hero_album_letters")
        let albumPages = photo("hero_album_letters", crop: CGRect(x: 0.0, y: 0.5, width: 0.9, height: 0.38))

        if profile.firstName.isEmpty { profile.firstName = "Daniel" }
        let myName = [profile.firstName, profile.lastName].filter { !$0.isEmpty }.joined(separator: " ")

        // MARK: People and the tree
        // Created oldest-first in the order Home should show them: the ones it's
        // all for, then everyone they came from.
        func person(_ name: String, _ relationship: String, _ gen: Generation,
                    branch: FamilyBranch = .unknown, born: String = "", died: String = "",
                    birthday: Date? = nil, notes: String = "", role: FamilyAccess = .none,
                    email: String = "") -> Person {
            let p = Person(name: name, relationship: relationship, birthday: birthday, notes: notes)
            p.inTree = true
            p.generation = gen
            p.branch = branch
            p.birthYear = born
            p.deathYear = died
            p.isLiving = died.isEmpty
            p.accessRole = role
            p.trustedEmail = email
            p.createdAt = kept(daysAgo: 560 - tick)
            ctx.insert(p); keep(p.id)
            return p
        }

        let sara = person("Sara", "Daughter", .children, born: "1990", birthday: day(1990, 5, 14),
                          notes: "Laughs exactly like her grandmother Rose.", role: .trusted,
                          email: "sara@example.com")
        let leo = person("Leo", "Son", .children, born: "1994", birthday: day(1994, 11, 2),
                         notes: "Quiet until he isn't. Builds things.", role: .canAsk)
        let anna = person("Anna", "Wife", .you, born: "1963", birthday: day(1963, 3, 9),
                          notes: "Forty years this spring.", role: .trusted, email: "anna@example.com")
        let mila = person("Mila", "Granddaughter", .grandchildren, born: "2021",
                          birthday: day(2021, 8, 21), notes: "Sara's girl. Collects feathers.")
        let clare = person("Clare", "Sister", .you, born: "1965")
        let rose = person("Rose", "Mother", .parents, branch: .maternal, born: "1937", died: "2019")
        let thomas = person("Thomas", "Father", .parents, branch: .paternal, born: "1934", died: "2011")
        let arthur = person("Arthur", "Grandfather", .grandparents, branch: .paternal, born: "1905", died: "1979")
        let edith = person("Edith", "Grandmother", .grandparents, branch: .paternal, born: "1909", died: "1988")
        let giovanni = person("Giovanni", "Grandfather", .grandparents, branch: .maternal, born: "1910", died: "1972")
        let maria = person("Maria", "Grandmother", .grandparents, branch: .maternal, born: "1914", died: "1996")

        // You: the one already in the tree if there is one, otherwise a new one. An
        // existing self keeps any parents or partner it already has.
        let everyone = (try? ctx.fetch(FetchDescriptor<Person>())) ?? []
        let me: Person
        if let existing = everyone.first(where: { $0.isSelf && !made.contains($0.id.uuidString) }) {
            me = existing
        } else {
            me = person(myName, "You", .you, born: "1961")
            me.isSelf = true
        }

        thomas.parentIDs = [arthur.id, edith.id]
        rose.parentIDs = [giovanni.id, maria.id]
        thomas.partnerID = rose.id; rose.partnerID = thomas.id
        arthur.partnerID = edith.id; edith.partnerID = arthur.id
        giovanni.partnerID = maria.id; maria.partnerID = giovanni.id
        if me.parentIDs.isEmpty { me.parentIDs = [thomas.id, rose.id] }
        clare.parentIDs = [thomas.id, rose.id]
        if me.partnerID == nil { me.partnerID = anna.id }
        anna.partnerID = me.id
        sara.parentIDs = [me.id, anna.id]
        leo.parentIDs = [me.id, anna.id]
        mila.parentIDs = [sara.id]

        // MARK: Memories

        func memory(_ title: String, year: Int, place: String, _ stage: LifeStage,
                    photos: [String?] = [], people: [Person], why: String, _ story: String) {
            let m = MemoryEntry(title: title, story: story)
            m.approximateYear = year
            m.place = place
            m.stage = stage
            m.whyItMatters = why
            m.photoRefs = photos.compactMap { $0 }
            m.createdAt = kept(); m.updatedAt = m.createdAt
            ctx.insert(m); keep(m.id)
            m.people = people
        }

        memory("The kitchen on Alder Street", year: 1968, place: "Leeds", .childhood,
               people: [rose, thomas, clare],
               why: "Every kitchen I've had since has been trying to be this one.",
               """
               The window over the sink looked onto the yard and the washing line, and Mum stood there most of the day. The radio was always on, low. Clare and I did our homework at the table while the tea brewed, and Dad came in at six smelling of the print works and oil.

               On Sundays the whole room filled with the smell of Nonna's sauce — Mum made it the way her mother taught her, and wouldn't let anyone else stir it.
               """)
        memory("My first job at the print shop", year: 1979, place: "Leeds", .youth,
               people: [thomas],
               why: "Dad never said he was proud. He did that instead.",
               """
               I was eighteen and I thought I knew everything. Dad got me the job, and the first morning he walked me in, introduced me to old Mr Hale, and left without a word.

               At the end of the week he took the first pay packet out of my hand, counted it, and gave it back with a ten-pound note of his own folded inside.
               """)
        memory("The summer we drove to the coast", year: 1998, place: "Northumberland", .building,
               photos: [fieldWide, fieldKids], people: [anna, sara, leo],
               why: "The last summer before everyone started growing up at once.",
               """
               The car had no air conditioning and the tape deck only played one side of one tape. We drove up with the windows down and sang the same six songs all the way there.

               Sara ran straight into the long grass at the top of the dunes and Leo went after her, the way he always did. Anna and I just stood and watched them go, and I remember thinking: remember this.
               """)
        memory("Teaching Sara to ride a bike", year: 1996, place: "Roundhay Park", .building,
               photos: [fatherChild], people: [sara],
               why: "She still tells me I let go too early. I didn't. She just didn't need me.",
               """
               We did it on the path by the lake, on a Sunday, with Anna filming on the big camcorder. Sara made me promise I wouldn't let go.

               I let go about halfway down. She didn't notice until she reached the bench at the end and turned round to find me a long way back, waving.
               """)
        memory("The night Leo was born", year: 1994, place: "St James's Hospital", .building,
               people: [anna, leo],
               why: "The quietest I have ever been.",
               """
               It snowed, which it never does in November. I drove too slowly and Anna told me so, repeatedly. He arrived just after two in the morning and didn't cry at all, just looked at everything very seriously, the way he still does.
               """)
        memory("Dad's last good day", year: 2010, place: "Whitby", .midlife,
               photos: [fatherSunset], people: [thomas],
               why: "I want you to know he was happy at the end, too.",
               """
               We drove to Whitby because he wanted fish and chips on the harbour wall, like when I was a boy. He couldn't walk far by then, so we sat on the bench for most of the afternoon and watched the boats come in.

               He told me about the war, a little, for the first time. Then he told me he'd liked my mother from the first day he saw her, at a dance, in a green dress.
               """)
        memory("The shoebox of letters", year: 2019, place: "Mum's house", .later,
               photos: [album, albumPages], people: [rose, thomas],
               why: "It's the reason I started keeping all this.",
               """
               Clearing Mum's wardrobe, we found a shoebox tied with string. Inside was every letter Dad had written to her while he was away in the army — sixty-one of them, in order, each one read so often the folds had gone soft.

               We read them together at her kitchen table until it got dark.
               """)
        memory("Walking Mila to the pond", year: 2025, place: "Golden Acre Park", .recent,
               people: [mila, sara],
               why: "She asks the same questions Sara did, in the same order.",
               """
               Every Saturday morning, if it isn't raining too hard. She has to feed the ducks, count the swans, and find exactly one good feather to take home. Her collection lives in a jam jar on the kitchen windowsill.

               Last week she asked me what I was like when I was little. So I started writing it down.
               """)

        // MARK: Letters

        func letter(_ title: String, to: Person?, _ salutation: String, _ seal: SealCondition,
                    signature: String, photos: [String?] = [], draft: Bool = false,
                    daysAgo: Int? = nil, _ body: String) {
            let l = Letter(title: title, body: body)
            l.salutation = salutation
            l.signature = signature
            l.seal = seal
            l.photoRefs = photos.compactMap { $0 }
            l.isDraft = draft
            l.createdAt = kept(daysAgo: daysAgo); l.updatedAt = l.createdAt
            ctx.insert(l); keep(l.id)
            l.recipient = to
        }

        letter("For Mila, on your eighteenth birthday", to: mila, "My dearest Mila,", .birthday18,
               signature: "With all my love, Grandad", photos: [fieldKids],
               """
               You're eighteen today, and I've been trying to imagine you — taller than your mum, I expect, and still bringing home feathers.

               When you were four we walked to the pond every Saturday, and you asked me what I was like when I was little. This whole book is my answer. Take your time with it.

               Be brave with your life. Be kind with your words. And whenever you can, go and look at the sea.
               """)
        letter("For Leo, on a hard day", to: leo, "Leo,", .hardDay,
               signature: "Dad",
               """
               If you're reading this, something has gone wrong, and I'm sorry I'm not there to sit with you.

               Here is what I know. You have always been the one who keeps going quietly when everyone else has stopped. That is a strength, but it is also heavy. You are allowed to put it down. Call your sister. Eat something warm. Go to bed early.

               It will not always feel like this. I promise.
               """)
        letter("What I never said out loud", to: sara, "My dear Sara,", .none,
               signature: "Your proud dad",
               """
               I'm not good at saying these things across a table, so I'm writing them down instead.

               Watching you become a mother has been the greatest thing I've seen. You're patient in a way I never was. Mila is lucky, and so am I.
               """)
        letter("Anna, forty years on", to: anna, "Anna,", .none,
               signature: "Always yours", draft: true, daysAgo: 2,
               """
               Forty years this spring. I've been trying to write this for a month and every version starts with the dance at the Majestic, so I'm going to stop fighting it.

               You were wearing a blue coat and you told me my tie was terrible. You were right.
               """)

        // MARK: Voice

        func voice(_ title: String, seconds: Double, for p: Person?, note: String, seed: UInt64) {
            let r = VoiceRecording(title: title, fileRef: silence(seconds: seconds) ?? "",
                                   duration: seconds, levels: speechLevels(seconds: seconds, seed: seed))
            r.note = note
            r.createdAt = kept()
            ctx.insert(r); keep(r.id)
            r.person = p
        }

        voice("How I met your mother", seconds: 194, for: sara,
              note: "The Majestic, 1983. The blue coat.", seed: 11)
        voice("Nonna Maria's song", seconds: 96, for: mila,
              note: "The lullaby Mum sang to us in Italian. I've got most of the words.", seed: 27)
        voice("A bedtime story for Mila", seconds: 312, for: mila,
              note: "The one about the lighthouse keeper's cat.", seed: 43)
        voice("Dad's advice about money", seconds: 148, for: leo,
              note: "Everything Grandad Thomas told me, and one thing he got wrong.", seed: 58)

        // MARK: Lessons

        func lesson(_ c: LessonCategory, _ headline: String, _ body: String) {
            let l = Lesson(category: c, headline: headline, body: body)
            l.createdAt = kept(); l.updatedAt = l.createdAt
            ctx.insert(l); keep(l.id)
        }

        lesson(.wishIdKnown, "Nobody has it figured out.",
               "Every adult I was afraid of at twenty was making it up as they went along. Once you know that, you can stop waiting for permission.")
        lesson(.money, "Save the first ten per cent, not the last.",
               "Take it off the top on payday, before you see it. What's left is what you have. My dad did this his whole working life on a printer's wage, and he never once worried at the end of a month.")
        lesson(.love, "Love is mostly small and daily.",
               "It's the tea brought up without asking. It's remembering which friend's name to ask about. The grand gestures are lovely, but they're not what holds a marriage up.")
        lesson(.mistakes, "Say sorry first, even when you're only half wrong.",
               "I lost two years with my sister over something neither of us can now remember. Pride is very expensive.")
        lesson(.growingOlder, "The days are long and the years are short.",
               "Your grandmother told me that when Sara was a baby and I was too tired to hear it. She was right. Take the photograph. Go on the trip.")
        lesson(.believe, "Most people are doing their best.",
               "Not everyone, and not always. But assume it first, and you'll be right far more often than you're wrong.")

        // MARK: Family history

        func story(_ title: String, subject: String, generation: String, origin: String, years: String,
                   recipe: Bool = false, tradition: Bool = false, photos: [String?] = [], _ body: String) {
            let s = FamilyStory(title: title, subject: subject, generation: generation)
            s.origin = origin
            s.years = years
            s.isRecipe = recipe
            s.isTradition = tradition
            s.photoRefs = photos.compactMap { $0 }
            s.body = body
            s.createdAt = kept()
            ctx.insert(s); keep(s.id)
        }

        story("Nonna Maria's Sunday sauce", subject: "My grandmother Maria", generation: "Grandparents",
              origin: "Bari, Italy", years: "1914–1996", recipe: true,
              """
              Two tins of good tomatoes, one onion, four cloves of garlic, a glug of olive oil and a handful of basil torn at the very end. Pork ribs if it's a special Sunday.

              Soften the onion slowly — slower than you think. Add the garlic, then the tomatoes, crushed by hand. Let it barely bubble for three hours with the lid half on. Nonna said the sauce is ready when the house smells of it from the front door.
              """)
        story("How Giovanni came to Leeds", subject: "My grandfather Giovanni", generation: "Grandparents",
              origin: "Bari → Leeds", years: "1910–1972",
              """
              He came over in 1949 with one suitcase and a letter from a cousin promising work in the tailoring mills. The work was real; the cousin's flat was one room over a bakery.

              Maria followed a year later with baby Rose. He met them at the station in a borrowed suit, and they walked home through the snow because he'd spent the bus fare on flowers.
              """)
        story("Christmas Eve candles", subject: "Our family", generation: "Every generation",
              origin: "Leeds", years: "Since 1950", tradition: true,
              """
              On Christmas Eve, the youngest person in the house lights a candle in the front window for everyone who couldn't be there. Then we eat far too much and nobody is allowed to mention the washing-up until morning.
              """)

        // MARK: Guidance and documents

        func guidance(_ c: GuidanceCategory, _ title: String, detail: String, where w: String = "",
                      contact: String = "", phone: String = "") {
            let g = GuidanceNote(category: c, title: title)
            g.detail = detail
            g.whereToFind = w
            g.contactName = contact
            g.contactPhone = phone
            g.createdAt = kept(); g.updatedAt = g.createdAt
            ctx.insert(g); keep(g.id)
        }

        guidance(.important, "Call Anna first, then Clare",
                 detail: "Anna knows where everything is. Clare will help with the phone calls so nobody has to do them alone.")
        guidance(.contacts, "Our solicitor",
                 detail: "They have the original will and know what we want.",
                 contact: "Harper & Lowe", phone: "0113 496 0000")
        guidance(.belongings, "Grandad Arthur's pocket watch",
                 detail: "It goes to Leo. It needs winding every morning and loses about a minute a week.",
                 where: "Top drawer of the oak desk, in the green box.")
        guidance(.digital, "Photos and passwords",
                 detail: "Every family photo is in iCloud Photos. The password manager's emergency kit is in the safe.",
                 where: "Safe in the spare-room wardrobe. Anna has the code.")

        func document(_ title: String, _ c: DocumentCategory, note: String, where w: String) {
            let d = DocumentItem(title: title, category: c)
            d.note = note
            d.whereToFind = w
            d.createdAt = kept(); d.updatedAt = d.createdAt
            ctx.insert(d); keep(d.id)
        }

        document("Will and testament", .legal,
                 note: "Signed 2023. Executors: Anna and Sara.",
                 where: "Original with Harper & Lowe. Copy in the blue folder, oak desk.")
        document("House deeds — 12 Alder Street", .property,
                 note: "Mortgage paid off in 2016.",
                 where: "Blue folder, oak desk.")
        document("Life insurance policy", .insurance,
                 note: "Beneficiary: Anna. Policy number is on the first page.",
                 where: "Filing cabinet, second drawer, under 'Insurance'.")
        document("Passports and birth certificates", .personal,
                 note: "Mine, Anna's, and Mum's old Italian passport.",
                 where: "Fireproof box under our bed.")

        // MARK: Belongings

        func belonging(_ name: String, detail: String, story s: String, heir: Person?) {
            let b = Belonging(name: name)
            b.detail = detail
            b.story = s
            b.createdAt = kept()
            ctx.insert(b); keep(b.id)
            b.heir = heir
        }

        belonging("Grandad Arthur's pocket watch", detail: "Silver, 1931",
                  story: "He carried it every working day for forty years.", heir: leo)
        belonging("Mum's recipe box", detail: "Tin, painted with lemons",
                  story: "Half the cards are in Italian, in Nonna's handwriting.", heir: sara)
        belonging("The oak writing desk", detail: "Where most of this was written",
                  story: "Dad built it the year I was born.", heir: mila)

        // MARK: A capsule for Sara

        let capsule = LegacyCapsule(title: "For Sara")
        capsule.openingMessage = "Everything I've kept, for the one who'll look after it best."
        capsule.createdAt = kept()
        ctx.insert(capsule); keep(capsule.id)
        capsule.person = sara

        try? ctx.save()
        ids = made
    }

    // MARK: - Removing

    static func remove(from ctx: ModelContext) {
        let gone = ids
        guard !gone.isEmpty else { return }
        func sweep<T: PersistentModel>(_: T.Type, id: (T) -> UUID, media: (T) -> [String] = { _ in [] }) {
            for item in (try? ctx.fetch(FetchDescriptor<T>())) ?? [] where gone.contains(id(item).uuidString) {
                media(item).forEach { MediaStore.delete($0) }
                ctx.delete(item)
            }
        }
        sweep(MemoryEntry.self, id: \.id, media: { $0.photoRefs + [$0.audioRef].compactMap { $0 } })
        sweep(Letter.self, id: \.id, media: { $0.photoRefs + [$0.audioRef].compactMap { $0 } })
        sweep(VoiceRecording.self, id: \.id, media: { [$0.fileRef] })
        sweep(Lesson.self, id: \.id)
        sweep(FamilyStory.self, id: \.id, media: { $0.photoRefs + [$0.audioRef].compactMap { $0 } })
        sweep(GuidanceNote.self, id: \.id)
        sweep(DocumentItem.self, id: \.id, media: { $0.fileRefs })
        sweep(Belonging.self, id: \.id, media: { $0.photoRefs })
        sweep(LegacyCapsule.self, id: \.id)
        sweep(Person.self, id: \.id, media: { [$0.photoRef].compactMap { $0 } })
        // A self the sample reused keeps existing, but loses links to people who
        // have just gone.
        for p in (try? ctx.fetch(FetchDescriptor<Person>())) ?? [] {
            p.parentIDs.removeAll { gone.contains($0.uuidString) }
            if let partner = p.partnerID, gone.contains(partner.uuidString) { p.partnerID = nil }
        }
        try? ctx.save()
        ids = []
    }

    // MARK: - Media

    /// Saves one of the app's own photographs as if it had been picked, optionally
    /// cropped to a unit rect so one picture can stand in for two.
    private static func photo(_ name: String, crop: CGRect? = nil) -> String? {
        guard let image = UIImage(named: name) else { return nil }
        guard let crop, let cg = image.cgImage else { return MediaStore.saveImage(image) }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let rect = CGRect(x: crop.minX * w, y: crop.minY * h, width: crop.width * w, height: crop.height * h).integral
        guard let cut = cg.cropping(to: rect) else { return MediaStore.saveImage(image) }
        return MediaStore.saveImage(UIImage(cgImage: cut, scale: image.scale, orientation: image.imageOrientation))
    }

    /// A quiet file of the right length, so the play buttons behave as they would
    /// with a real recording.
    private static func silence(seconds: Double) -> String? {
        let ref = MediaStore.newAudioRef()
        let rate = 8_000.0
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                       AVSampleRateKey: rate, AVNumberOfChannelsKey: 1]
        guard let file = try? AVAudioFile(forWriting: MediaStore.url(for: ref), settings: settings),
              let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)
        else { return nil }
        var remaining = AVAudioFrameCount(seconds * rate)
        while remaining > 0 {
            let n = min(remaining, AVAudioFrameCount(rate))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n),
                  let channel = buffer.floatChannelData?[0] else { return nil }
            buffer.frameLength = n
            channel.update(repeating: 0, count: Int(n))
            do { try file.write(from: buffer) } catch { return nil }
            remaining -= n
        }
        return ref
    }

    /// A waveform with the rhythm of someone talking: phrases of syllables, short
    /// breaths between them, and the odd longer pause. Sampled the way the recorder
    /// samples, twenty times a second.
    private static func speechLevels(seconds: Double, seed: UInt64) -> [Double] {
        var s = seed &* 0x9E37_79B9_7F4A_7C15 | 1
        func rnd() -> Double {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Double((s >> 33) & 0xFFFF) / 65535.0
        }
        let count = min(1400, Int(seconds * 20))
        var out: [Double] = []
        out.reserveCapacity(count)
        while out.count < count {
            // A phrase…
            let syllables = 4 + Int(rnd() * 14)
            for _ in 0..<syllables {
                let len = 3 + Int(rnd() * 4)
                let peak = 0.45 + rnd() * 0.5
                for i in 0..<len {
                    let x = Double(i) / Double(max(1, len - 1))
                    out.append(max(0.04, peak * sin(.pi * x) + rnd() * 0.08))
                }
            }
            // …then a breath.
            let pause = rnd() < 0.2 ? 10 + Int(rnd() * 12) : 2 + Int(rnd() * 5)
            for _ in 0..<pause { out.append(0.02 + rnd() * 0.05) }
        }
        return Array(out.prefix(count))
    }
}
#endif
