# Kinward

**Your story. Their future.**

A private iOS app for preserving the stories, memories, wisdom, voice, letters and
practical knowledge you want the people you love to carry forward.

Built in SwiftUI + SwiftData, local-first, no account, no backend, no advertising.
Everything a person writes, records and keeps is free. **Kinward Plus**, an optional
subscription sold through RevenueCat, adds how it looks and how it's handed down.

---

## Running it

```bash
xcodegen generate && open Kinward.xcodeproj
```

Then run on any iOS 18+ simulator or device. Requires Xcode 16+ (built and verified
against Xcode 26.6 / Swift 6.3, iPhone 17 Pro simulator and a physical iPhone).

**Signing.** Code signing is disabled for the simulator SDK only
(`CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]`), so headless simulator builds need no
certificate. Device builds sign automatically against team `PLBCH3VD36` with
bundle id `com.ali.Kinward`. Change `DEVELOPMENT_TEAM` in `project.yml` — not in the
Xcode UI, which `xcodegen generate` overwrites.

`project.yml` is the source of truth for the project — re-run `xcodegen generate`
after adding files. The generated `Kinward.xcodeproj` is disposable.

**Purchases.** The RevenueCat public SDK key is read at runtime from
`Kinward/Resources/RevenueCat.plist`, which is gitignored. Create it with one
`PublicSDKKey` string (`appl_…`). Without it the app runs normally and Plus simply
reads as not bought. Archiving stops with a clear error if the key is missing, so an
App Store build can't ship unable to sell.

**Screenshots.** Debug builds have Settings → *For screenshots* → **Load sample
content**: a four-generation sample family with memories, photographs, sealed
letters, voice notes, lessons, recipes and documents, and a switch that unlocks Plus
without buying it. *Remove sample content* takes out exactly what it added. None of
it is compiled into a Release build.

---

## The dial

The signature navigation is a radial menu in the bottom-right corner. Open, it fans
into that same corner and no further — the page stays visible and readable behind it.

- **Closed** — a small dial carrying the current section's name curved around a dark
  hub, with quiet ticks marking the other six sections.
- **Press and hold it** — the corner panel blooms out of the dial, the hub presses in,
  and the seven sections stagger onto an arc. **Without lifting**, move in the
  direction of whichever one you want: it lights up with a haptic detent, the hint
  reads *Release to open*, and lifting opens it. You never have to reach the node —
  about 50pt in its direction is enough — and you can change your mind by sweeping
  across to another before letting go. One press, one motion, done.
- **Or just tap it** — the fan stays open to browse. A press that never reaches a
  node is only ever a tap, so the hub is inert while your finger is down on it.
- **Tap a section** — go there. **Tap the hub** — go home. **Tap the gold `+`** — keep
  something new. **Release outside the panel** — close, and the dial goes back to the
  section you opened it on, so poking around never moves you off your page.

Geometry: hub 74pt from the right edge and 104pt up, arc of icons at r=132 sweeping
178°→280° (pointing-left up to pointing-up), panel a quarter-round of r=176 bled out
to the bottom and right edges of the glass. The wheel is laid out inside the safe
area, so the panel path deliberately overshoots its own bounds to reach them.

Only the section you're on is named, in a small card above the fan. Seven names will
not fit on an arc this size without colliding, and the card doubles as a readout: it
names the hub and the `+` too as you sweep across them.

The press surface is a fixed layer anchored where the closed dial sits, mounted
whether the fan is open or not — otherwise the panel blooming mid-press would move
the view out from under the finger and cancel the gesture.

Touch handling is deliberately flat. Every gesture reads its position in one named
coordinate space, and one function (`RadialWheel.target(at:hub:)`) turns a point into
the hub, a section, the `+`, or nothing — so the press off the closed dial and a
fresh touch on the open fan behave identically, and nothing underneath competes for
the same touch. The one difference is that a press treats the hub as *nothing
chosen*, because that is where the finger started.

The seven sections tell a sentence, in order:

> What happened → who mattered → what I want to say → what I learned →
> what they'll need to know → what they may need → what I leave behind.

---

## Kinward Plus — RevenueCat

A custom SwiftUI paywall (`Features/Paywall/PaywallView.swift`) on top of the
RevenueCat SDK (`Services/Store.swift`).

| | |
|---|---|
| Entitlement | `plus` |
| Offering | `default`, with an **Annual** and a **3 Month** package |
| Products | `com.ali.Kinward.plus.yearly` · $14.99 / year, `com.ali.Kinward.plus.quarterly` · $9.99 / 3 months |
| What it unlocks | The book of your life, Pass it on, the Clear look, eight alternate app icons |
| Always free | Every memory, letter, recording, lesson, document and family-tree entry, and sharing them |

- **Prices come from the store.** Plans are built from `offerings.current.annual`
  and `.threeMonth`, so price, per-month price and any free trial are whatever App
  Store Connect says, localised. The yearly "Save %" badge is worked out from the two
  live prices rather than written down.
- **Opened by reaching.** Anything that needs Plus carries a small *PLUS* badge;
  tapping it opens the paywall saying what was reached for and highlighting that
  row. It also opens from Settings → Kinward Plus.
- **Entitlement kept true.** `customerInfoStream` drives the state, and the last
  answer is cached so a subscriber with no signal still has what they paid for.
  Purchases, restores and Ask to Buy all resolve through the same path.
- **Lapse is gentle.** If Plus ends, the Clear look falls back to Paper and the
  icon to the default sealed letter. Nothing anyone kept is touched.
- **The small print is in the app.** Renewal terms under the button, Restore
  purchases, and the Terms of Use and Privacy Policy as readable pages in the app
  itself (Settings → *Terms & privacy*), built from the same `Legal.json` as the
  website copies in `Website/`.
- **Nothing is tracked.** RevenueCat sees an anonymous app user id and purchase
  history, for app functionality only. There's no analytics or advertising SDK.

---

## What's in it

**Sharing** — a person's card has *Send what they can see*. It gathers everything
that person has been granted — or the whole archive, with one toggle — into a single
zip: a typeset PDF of the writing (real text, paginated with Core Text, cover page and
photo plates), the voice recordings as `.m4a` files anything can play, the photographs,
the documents, and a plain-text note explaining what the recipient is looking at. The
ten permission areas map onto the archive directly, guidance splitting along the same
lines permission does (Financial takes the financial and insurance notes, Property the
property ones, Digital life the digital ones, Guidance the rest).

Two rules it keeps. **Sealed letters stay behind** — they were written to be opened at
a particular moment, and sending one early would undo the only instruction their writer
left about it; the sheet says how many are held and why. And **building a parcel that
carries financial, legal or account information asks for Face ID first**, because that
is exactly what the app keeps behind Face ID everywhere else.

Kinward does not send it. There is no account and no server; the parcel goes to the
system share sheet and the person holding the phone chooses the app, the address and
the moment. The address field on a trusted person is kept for exactly that — it is a
note to yourself, not a destination.

**Onboarding** — eight cinematic screens over real photography, ending on a drawn
night sky. The first two follow the design sheet's layout: words at the top where the
sky is, the handwritten note bottom-left, and a large white disc tucked into the
bottom-right corner, running off both edges of the glass with the arrow over its
label. Because the disc is cropped by the screen, its content sits up and left of the
true centre, on the part you can actually see. It rolls up out of that corner once
the words have settled, and eyebrow, headline, body and note fade up in sequence
rather than landing at once.

Each of the two screens moves differently, in a way that belongs to what it says.
*Preserve the memories* pushes slowly into the photograph, the way you lean toward a
memory, and its arrow leans forward every few seconds and settles back: go on. *One
day there will be things they wish they could ask you* drifts across its photograph
instead, the way an eye moves over a table of pictures, and a hairline leaves the rim
of the disc every four and a half seconds and travels outward, fading — the shape of
an answer sent ahead of the question. Collects what the user cares about and who
they're doing it for; that
answer weights the question deck for the rest of the app's life. Replayable any time
from Settings → *See the introduction again*, which reopens the same flow in revisit
mode: the previous answers come back pre-selected, people already in Kinward are
listed rather than re-added, and nothing is duplicated on the way out.

**Home** — greeting, this week's question (answer, record, ask another, not today),
continue your story, quick capture, the people who matter, and a calm count of what's
been kept. No streaks, no badges, no progress bars.

**Memories** — title, story, why it matters, place, date or an approximate year, life
stage, people, photographs and your voice. Five views: all, a life timeline grouped
by year, a photo grid, voice recordings, and places.

**People** — everyone the archive is for, each with their own page gathering the
letters, memories, recordings and belongings meant for them.

**Letters** — written on paper. The writer chooses the face in Settings —
*Handwritten* (`Bradley Hand`), *Classic* (a book serif) or *Plain* — and it applies
wherever a letter is shown. Every field grows with what's typed, so the start of a
long title never scrolls out of sight. Eight starting templates. Each letter can be **sealed** to an
occasion — an 18th birthday, a wedding day, a first child, a hard day — which Kinward
records but never opens on its own.

**Lessons** — fourteen categories of hard-won knowledge, each startable from a
question rather than a blank page.

**Guidance** — eight categories of practical knowledge (property, insurance,
financial instructions, digital life, belongings, contacts…). The sensitive ones sit
behind Face ID.

**Documents** — the whole section is locked. `VisionKit` document scanning with edge
detection, plus photo import, categories, and a note of where the original lives.

**Family tree** — a pannable, zoomable tree built from the person keeping it:
great-grandparents down to grandchildren. A guided pass asks for names generation
by generation, labelling each step with the names already given ("Giuseppe's
parents", "Rosa's parents"), and takes whatever the person can remember — every
field is optional, because a half-finished tree is the normal outcome and still
worth having. Anyone already in Kinward can be linked rather than duplicated. Tap a
node to set years, who their parents are, a partner, what you remember about them —
and what they're allowed to see. Reachable from People and from Legacy.

**Legacy** —
- *Legacy capsules*: one collection per person, with an opening message and toggles
  for what's inside.
- *See it the way they would*: a full recipient preview — night sky, "someone special
  has left something for you", then the capsule as they'd read it. This is the screen
  that explains the app.
- *The book of your life*: the entire archive typeset as chapters, in order, with
  nothing to tap.
- *Trusted people*: they ask, you answer. Everyone in the family gets one of three
  levels — *in your tree* (nothing shared), *can ask you things*, or *trusted with
  your Kinward* (per-area permissions). Anything financial, legal or account-related
  asks a second time before it opens, in context rather than as a modal. A quiet
  period (30 days to a year) stops repeated requests. No death detection, no
  automatic release — by design.
- *Family history*: parents, grandparents, great-grandparents, origins, traditions,
  recipes.
- *Pass it on*: what you were given becomes yours to give. A `.kinward` parcel
  (compressed JSON with its media embedded) opens in another person's Kinward, adds
  their name to the chain it has travelled, and can be sent on again to the next
  generation. Opening the same parcel twice never duplicates anything.

**Voice** — real `AVAudioRecorder` capture with live metering; the waveform you see is
the waveform that was recorded. Pause, resume, listen back, discard, title it, point
it at a person. Recordings attach to memories, letters, lessons and family stories.

**Search** — one field across memories, letters, lessons, voice, family history,
people, belongings and guidance.

**Settings** — profile, what you've kept, Kinward Plus, the look, *Age with you*,
the weekly question and lock toggles, how you get around (the dial or a normal tab
bar), the home-screen icon, how letters are written, the privacy model, Terms &
privacy, lock-now, erase-everything, and both the introduction and the tour again.

**Two looks** — *Paper* is Kinward's own: warm stock, New York, a hand in the
margins. *Clear* is the app as the platform would build it: system grouped
backgrounds, San Francisco throughout, one indigo tint, and it follows the phone
into dark mode.

**Age with you** — the app wears in slowly with use, the way a book does. The paper
warms, the ink settles toward sepia, the gilt dulls, the edges tan and foxing comes
up a spot at a time, each copy in its own pattern. Use drives it (days opened, things
kept), not the calendar, and it takes years. It can be turned off, and Settings can
look ahead to show the whole app at any age.

**A first-run tour** — a short spotlight walk around Home, shown once, replayable.

**Nine app icons** — the default sealed letter and eight alternates.

---

## Design system

Everything lives in `Design/KinwardTheme.swift`.

| | |
|---|---|
| Paper | `#F5F1E8` → `#EDE7DA`, surface `#FBF9F4` |
| Ink | `#252522` / `#706E67` / `#9A978C` |
| Accents | sage `#6D7765`, deep sage `#3B4238`, gold `#A8946A` |
| Headlines | New York (serif), 18–40pt |
| Body | SF Pro |
| Hand | Bradley Hand, for letters and marginalia only |
| Motion | 0.44–0.62s, spring settle, nothing snaps unless a finger let go |

Paper is the default; *Clear* swaps every token for a UIKit semantic colour through
one observable `ThemeStore`, and *Age with you* mixes either palette toward its worn
form, so the ~1,000 places that say `K.ink` change together.

Every Paper surface carries a deterministic film grain (`GrainOverlay`) so the flats
never read as digital. Section screens close with handwritten marginalia, as in the design
sheet.

---

## Architecture

```
App/          KinwardApp (ModelContainer), RootView (onboarding gate + router)
Design/       Theme, shared components, waveform views
Navigation/   KinwardSection, Router, RadialWheel, CurvedText
Models/       12 @Model types + the shared vocabulary enums
Services/     MediaStore, VoiceRecorder/VoicePlayer, BiometricGate, QuestionBank,
              Haptics, Housekeeping, Store (RevenueCat), AppIconStore, Heirloom,
              LegacyExport, SampleContent (debug only)
Features/     one folder per section
```

The family tree is one more view onto `Person`, not a parallel model: the relative
you tag in a memory, write a letter to, and grant access to is the same record.
Tree links (`parentIDs`, `partnerID`) are stored as ids rather than SwiftData
relationships — the graph is self-referential and tiny, and resolving it in memory
keeps the store simple. `TreeLayout` settles each generation under the one above it,
then makes one upward pass to re-centre parents over their children, which is what
makes a drawn tree look tidy rather than merely correct.

- **Local-first.** SwiftData with a local store. The schema is shaped for CloudKit
  (optional relationships, defaulted attributes) so a `.cloudKitDatabase` configuration
  can be swapped in without touching the UI or the domain layer.
- **Media never goes in the database.** Photos and audio are written to the app's
  Application Support container and referenced by filename (`MediaStore`). Deleting an
  entry deletes its files.
- **Face ID** guards Documents and the sensitive Guidance categories, with a three
  minute grace window that re-arms whenever the app leaves the foreground. If the
  device has no passcode, the gate opens rather than locking someone out of their own
  archive.
- **Housekeeping.** Editors work on real persisted objects, so an abandoned entry can
  survive a dismissed sheet. `Housekeeping.pruneBlankEntries` clears entries with
  literally no content on launch — and only those.
- **158 questions** in `QuestionBank`, weighted by what the user said they cared about
  during onboarding and filtered against what they've already answered or set aside.
  Each question knows where its answer belongs (memory, lesson, family story, letter).

---

## Deliberately not in V1

Per the brief: no automatic death detection, no automatic post-death release, no
public profiles, no feed, no followers, no advertising, no gamification.

## Where a backend would go

`MediaStore`, `QuestionBank` and the SwiftData context are the only places that touch
storage. RevenueCat is the only network call the app makes. A sync service would sit behind the same call sites; the views and models
would not change.
