# Hokm · handoff

How to pick this work up on your own computer. Everything lives on the branch
`claude/hokm-web-game-j61qhq` of
**https://github.com/aiaiaib2bb-star/kinward**, in the `hokm/` folder, separate
from the iOS app.

> **The branch is not on GitHub yet.** Pushes from the cloud session were
> refused (403: the Claude GitHub App isn't installed on the repo). The commits
> travel in `hokm-branch.bundle`, sent in the session. Step 1 puts them on your
> machine and pushes them with your own Git login, which works.

## 1. Get the code

You need Git and Node 20 or newer (22 was used while building it).

```bash
git clone https://github.com/aiaiaib2bb-star/kinward.git   # skip if you have a clone
cd kinward
git fetch origin                                          # main must include 6e04f62
git fetch ~/Downloads/hokm-branch.bundle claude/hokm-web-game-j61qhq:claude/hokm-web-game-j61qhq
git checkout claude/hokm-web-game-j61qhq
git push -u origin claude/hokm-web-game-j61qhq
```

Point the `git fetch` line at wherever you saved the bundle. After the push the
branch is at
https://github.com/aiaiaib2bb-star/kinward/tree/claude/hokm-web-game-j61qhq.

The branch adds these commits on top of `main` (`6e04f62`):

| Commit | What |
| --- | --- |
| `9498e3c` | The game: rules engine, server, client, voice, shop, tests, deploy files |
| `63cf5f7` | Sturdier voice, touch-accurate flicks, layout fixes from device runs |
| `95d801f` | "You stay Hakem" when the next Hakem is you |
| latest | This file |

## 2. Run it

```bash
cd hokm
npm install
npm run build
npm start                                          # http://localhost:3000
npx cloudflared tunnel --url http://localhost:3000 # https link for phones (voice needs https)
```

While working on it:

```bash
npm run dev         # server on :3000 with reload, client on :5173 with hot reload
npm test            # 28 tests: rules, bots, full simulated matches
npm run typecheck
npm run format
```

`HOKM_TIME_SCALE=0.2 npm start` runs every server timer five times faster,
which helps when testing whole games.

## 3. A lasting link for friends (Render, free)

Once the branch is on GitHub: on render.com choose **New → Web Service →
Public Git Repository**, paste `https://github.com/aiaiaib2bb-star/kinward`, and
set:

| Setting | Value |
| --- | --- |
| Branch | `claude/hokm-web-game-j61qhq` |
| Root directory | `hokm` |
| Build command | `npm ci && npm run build` |
| Start command | `npm start` |
| Instance type | Free |
| Environment | `HOKM_SECRET` = a long random string, `NODE_VERSION` = `22` |

Never change `HOKM_SECRET` afterwards: it signs everyone's saved coins. The
free plan sleeps after 15 minutes without visitors, so the first visit after a
break takes about a minute. `render.yaml` holds the same settings as a
Blueprint if you move it to the repository root. The README covers Docker and
the other environment variables.

## 4. Where things stand

**Built:** everything in the original request. Voice chat; coins with a shop
(card backs, faces, tables, frames, avatar effects, slam effects, throwables,
emote packs); the Hakem shuffles as much as they like and the opponent on
their left cuts as many times as they want; team surrender that needs both
partners; phone-first layout; slide/swipe/drag/tap-tap card play; emotes,
phrases, chat bubbles and throwables; hard flicks that slam and shake the
table. Extras: bots, practice mode, turn timer with autopilot, reconnecting
to your seat, spectators, rematch votes, last-trick review, full Persian
right-to-left UI, installable app, screen kept awake.

**Verified in the cloud session:**

- Tests, typecheck and production build pass.
- Playwright on emulated iPhone 13, iPhone SE, Pixel 7, Galaxy S9+, iPad Mini,
  a 1366×820 desktop and landscape phones, in English and Persian.
- Four browser "phones" at one table: voice connected all six pairs (10/10
  stress rounds), emotes, throwables, chat, a human cut, surrender declined
  then accepted, spectating, autopilot, a reload mid-game back into the same
  seat, rematch voting.
- Touch gestures through Chrome's touch emulation: sliding along the hand,
  flick-to-slam, tap-tap.
- Result screens for Kot, Hakem Kot, victory with a level-up, and defeat.

**Not verified:**

- Real phones on real networks: voice through carrier NAT, iPhone audio
  routing (it can use the earpiece), how the gestures feel on a real screen,
  vibration (iPhones' Safari has none), wake lock, Add to Home Screen.
- The Docker image: the cloud session had no Docker daemon, so the
  Dockerfile's steps were replayed by hand instead (they worked).

## 5. Next steps

1. Push the branch (step 1).
2. Deploy to Render (step 3) and play a real game with friends.
3. If someone on mobile data can't hear the others, add a TURN relay: set
   `CF_TURN_KEY_ID` and `CF_TURN_API_TOKEN` (Cloudflare Realtime) or
   `ICE_SERVERS` (for example Metered). The README has the format.
4. Decide whether `hokm/` stays on its own branch or merges into `main`
   (`main` is the Kinward iOS app).

## 6. How it works

```
hokm/src/shared/  rules.ts (seats, dealing, legal plays, scoring) · cards.ts · shuffle.ts
                  bot.ts · catalog.ts (shop, phrases) · constants.ts (timings, economy,
                  limits, slam speeds) · protocol.ts (every message and view type)
hokm/src/server/  index.ts (HTTP + Socket.IO, sessions, rate limits, room cleanup)
                  room.ts (members, seats, host, settings, rematch, effects, voice relay)
                  match.ts (the phase machine and its timers) · profiles.ts (signed profiles)
                  ice.ts (STUN/TURN) · static.ts (serves the built client)
hokm/src/client/  net/ · state/ · ui/screens/ · ui/game/ (Game, Hand, Trick, Seats,
                  Stages, Results, Fx, Sheets, geometry) · voice/mesh.ts · audio/sfx.ts
                  i18n/ (English + Persian) · cosmetics/ · styles/
hokm/tests/       rules, bot, match
```

- **The server is the authority.** It deals and holds every hand and sends
  each player a view with only their own cards. A state snapshot always goes
  out before the effects that play on top of it.
- **The server paces the table:** hakemSelect → shuffle → cut → deal1 → trump
  → deal2 → play ↔ trickEnd → handEnd → matchEnd. The timings are `T` in
  `src/shared/constants.ts`, and the client animates with the same numbers,
  so a timing changes in one place.
- **Seats:** turn order is counter-clockwise (seat + 1 is on your right),
  partners are seats 0+2 and 1+3, and the cutter is the opponent on the
  Hakem's left.
- **Shuffling:** in *Real* mode the next deal starts from the previous hand as
  it was gathered, and each shuffle is a Gilbert–Shannon–Reeds riffle; *Random*
  mode is a Fisher–Yates shuffle.
- **Absent players:** the server plays for bots, for players on autopilot, and
  for disconnected players after an 8-second grace. A match pauses when no
  human is online.
- **Profiles:** no accounts. A profile is an HMAC-signed token in the browser
  (`localStorage` key `hokm.token`) plus a server copy in
  `DATA_DIR/profiles.json`, and the newer version wins. Rewards (`ECONOMY` in
  constants) shrink when bots fill seats.
- **Voice:** a WebRTC mesh; the server relays signaling only between members
  who are in voice. It uses perfect negotiation (rollback only from
  `have-local-offer`), generation numbers for rebuilding a peer, a watchdog
  that rebuilds peers stuck for 9 seconds, and an ICE restart on failure.
- **Slams:** `Hand.tsx` estimates release speed from pointer samples using
  event timestamps, ignoring the pause before the finger lifts. `SLAM` in
  constants holds the speeds.
- **Layout:** `ui/game/geometry.ts` computes every position from the viewport
  and safe areas. The table is capped at 640 px wide on desktops.

For debugging, the app exposes `window.__hokm` (`app`, `net`, `settings`,
`voice`, `mesh`), including in production builds. The cloud session's tests
used it to render crafted states, with `window.__hokm.app.set({ room })`. Those
throwaway Playwright scripts weren't committed. If you write new ones, select
buttons with `button:has-text(...)`: plain `text=` also matches titles that
use the same words.

## 7. Resuming with Claude Code

```bash
cd kinward
git checkout claude/hokm-web-game-j61qhq
claude
```

Then ask it to read `hokm/HANDOFF.md` and carry on from the next steps. The
original cloud session is
https://claude.ai/code/session_01XgN6jUW7xL2hPSrURRCraF.
