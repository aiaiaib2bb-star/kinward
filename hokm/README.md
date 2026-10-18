# Hokm · حکم

Hokm, the Persian trick-taking card game, as a web app for playing with friends
on your phones. Open a table, send the link, and play with voice chat, emotes,
slams and a shop full of card designs.

It runs as a single Node server: it holds the deck and everyone's hands, paces
every table, and serves the app. Nothing secret ever reaches a phone that
shouldn't see it.

---

## Play tonight

You need Node 20 or newer.

```bash
cd hokm
npm install
npm run build
npm start                        # http://localhost:3000
```

Phones need an `https://` link for voice chat (browsers only allow the
microphone on secure pages). The quickest way to get one from your own
computer is a free Cloudflare tunnel, no account needed:

```bash
npx cloudflared tunnel --url http://localhost:3000
```

It prints a `https://….trycloudflare.com` address. Open it on your phone,
tap **Play with friends**, then **Invite friends** to send the table link
over WhatsApp or Telegram. Anyone who opens the link lands at your table.

Tip: on a phone, *Add to Home Screen* installs it like an app — full screen,
its own icon.

## Hosting it for good

Any host that runs a long-lived Node process with WebSockets works. Serverless
platforms (Vercel functions, Netlify) don't, because they can't hold a socket.

**Render** (free tier): create a *Web Service* from this repository with

| Setting | Value |
| --- | --- |
| Root directory | `hokm` |
| Build command | `npm ci && npm run build` |
| Start command | `npm start` |
| Health check path | `/healthz` |
| Environment | `HOKM_SECRET` = any long random string, `NODE_VERSION` = `22` |

`render.yaml` describes the same service as a Blueprint; Render looks for
blueprints at the repository root, so move it there to use it. The free tier
sleeps after 15 minutes without visitors, so the first visit afterwards takes
about a minute.

**Docker** (a VPS, Fly.io, Railway, a home server):

```bash
docker build -t hokm .
docker run -p 3000:3000 -e HOKM_SECRET=change-me -v hokm-data:/data hokm
```

Put it behind anything that terminates HTTPS (Caddy, nginx, the host's own).

### Settings

| Variable | What it does |
| --- | --- |
| `PORT` | Port to listen on. Default `3000`. |
| `HOKM_SECRET` | Signs player profiles. **Set this in production** and keep it the same across deploys, or everyone's saved coins stop being recognised. Without it a secret is generated into `DATA_DIR`. |
| `DATA_DIR` | Where profiles are stored (`profiles.json`). Default `./data`. |
| `ICE_SERVERS` | Extra STUN/TURN servers for voice, as JSON, e.g. `[{"urls":"turn:turn.example.com:3478","username":"u","credential":"p"}]`. |
| `CF_TURN_KEY_ID`, `CF_TURN_API_TOKEN` | Use Cloudflare Realtime TURN instead; the server fetches short-lived credentials itself. |
| `GIPHY_API_KEY` | Turns on GIF search in chat (get a free key at developers.giphy.com). Without it the GIF buttons are hidden. |
| `GIPHY_RATING` | The strictest GIPHY content rating to allow: `g`, `pg`, `pg-13` (default) or `r`. |
| `HOKM_TIME_SCALE` | Speeds every server timer up (`0.2`) — for testing only. |

### Voice chat and mobile data

Voice goes directly between phones (WebRTC). On home Wi-Fi that just works.
Phones on mobile data are often behind carrier NAT that only a **TURN relay**
can get through; without one, those players may not hear each other. Free and
cheap options: Cloudflare Realtime TURN (set the two `CF_TURN_*` variables) or
Metered.ca (put its servers in `ICE_SERVERS`).

Notes:

- The first tap on the mic asks for microphone permission. If it's refused,
  you can still listen.
- Settings → Voice chat switches between an open mic and push-to-talk (hold
  the mic button to talk). Long-press the mic button to leave voice.
- iPhones sometimes play WebRTC audio through the earpiece rather than the
  speaker; headphones avoid it. That's iOS, not something a web page can change.

---

## What's in it

**The game.** Standard four-player Hokm: the first ace dealt face up picks the
Hakem; the Hakem deals five each, calls the hokm from those five, then deals
four and four; follow suit if you can; first team to seven tricks takes the
hand. A plain win is 1 point, a **Kot** (7–0) is 2, and a **Hakem Kot** — the
Hakem's own team shut out — is 3. The Hakem keeps the role while their team
wins and passes it to the right when it loses. Tables play to 3, 5, 7 or 10.

**Shuffle and cut.** Every hand is dealt from a fully random deck: the server
shuffles it with the operating system's cryptographic random numbers (a
Fisher–Yates shuffle, so every order of the 52 cards is equally likely). Then
the Hakem shuffles as much as they like (each tap is a real riffle of that very
deck) and the opponent on the Hakem's left cuts by dragging down the side of
the deck to choose the depth, and can cut again before dealing. The cards come
off the top of exactly that deck, so the shuffles and the cut really decide who
gets what, and no amount of lazy shuffling can make a deal less random.

**Playing a card.** Slide your finger along the hand — the card under it rises —
then swipe up or drag it onto the table. Or tap a card to raise it and tap
again. Cards you can't play are dimmed. **Flick a card hard and it slams**: the
whole table shakes on everyone's phone, with the slammer's chosen effect.

**Talking.** Voice chat, text chat (messages pop up beside the sender), emotes,
quick phrases in English and Persian (*Bah bah!*, *Eyval!*, *Hokm bede!*), and
things to throw at other players — a rose, a tomato, a cup of chai, mom's
slipper.

**Surrender.** Either partner can propose it from the menu; the other partner
gets a yes/no. Both agree and the team loses that game.

**Boom 💣.** Before the first trick of a hand is taken, any player can call
Boom from the moves button in their bar. Their team must then take all 13
tricks: if they do, they win the whole game on the spot (plus 150 coins); if
they lose a single trick, the hand ends there and the other team wins it.
One Boom per hand.

**Swap hands 🔄.** Between tricks, a player can offer to trade their whole
hand, sight unseen, with one of the two opponents. The opponent gets 12
seconds to accept or decline while the table's clock waits. One offer per
player per hand. Bots judge only their own cards. The host can switch Booms
and swaps off in the lobby.

**GIFs.** The chat and the emote sheet have a GIF tab that searches GIPHY
(trending when the box is empty). The server does the searching, so the key
stays private, and only GIFs from its own rating-filtered results can be sent.

**Past games and the leaderboard.** Every finished game is saved to your
profile (the last 30): result, score, partner, opponents, Kots and Booms. The
leaderboard ranks players by games won, all time or this week, either
everyone or just the people you've played with.

**Coins and the shop.** Winners earn 100 coins plus 15 for each Kot and 30 for
each Hakem Kot; the other team still gets 20, a surrendering team nothing.
Rewards shrink when bots fill seats, so practising alone isn't a coin farm.
There's a daily gift, XP and levels (each level pays out too). Coins buy card
backs (Kashi tile, Termeh paisley, Yalda pomegranate, peacock feather…, plus
the painted Celestial and Ornate collections in `public/backs/`), card
faces (including Farsi numerals), tables (Persian carpet, Isfahan tiles…),
avatars, frames, profile effects that surround your avatar, slam effects,
throwables and emote packs. Everyone at the table sees your card backs, frame
and effect.

**Everything else.**

- Bots, named for heroes of the Shahnameh, fill empty seats; *Practice with
  bots* starts a game alone in one tap.
- A turn timer (15/30/60 s or none). Miss two turns and autopilot plays for
  you until you tap *I'm back*; a dropped connection gets a short grace first.
- Reload or lose signal mid-game and you come back to the same seat.
- Extra people at a full table watch as spectators. Rematch votes, team
  shuffling, host controls, kicking.
- English and Persian with a proper right-to-left layout, an optional
  four-colour deck, vibration, sounds generated in the browser, reduced motion,
  a last-trick review, screen kept awake during a game.

### Your profile

There are no accounts. Your profile (coins, items, stats) is a token signed by
the server and kept in your browser, and the server keeps a copy too. Profile →
*Move to another phone* copies a backup code you can paste on another device.

---

## Working on it

```bash
npm run dev        # server on :3000 with reload, client on :5173 with hot reload
npm test           # rules, bots and full simulated matches
npm run typecheck
npm run format
```

Open `http://<your computer's LAN address>:5173` on a phone to try changes on a
real screen (voice needs https, so use the tunnel above for that).

```
src/shared/   rules, cards, shuffling, bot, shop catalogue, wire protocol
src/server/   rooms, the match engine, profiles, static files, TURN config
src/client/   the React app: screens, the table, voice, sounds, translations
tests/        vitest suites
```

The server is authoritative and paces the table: deal animations, the pause on
a finished trick and the summary between hands are server time, so every phone
shows the same moment and a reconnecting phone lands in it. Each player gets
their own view of the game with only their own hand in it.
