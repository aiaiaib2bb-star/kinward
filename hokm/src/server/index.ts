import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Server } from 'socket.io';
import type { Ack, ClientToServer, Lang, Profile, RoomSettings, ServerToClient } from '../shared/protocol';
import type { Rng } from '../shared/shuffle';
import { gifsEnabled, searchGifs, vettedGif } from './gifs';
import { iceServers, relayStatus } from './ice';
import { ProfileStore } from './profiles';
import { type GameSocket, Room } from './room';
import { serveStatic } from './static';

const PORT = Number(process.env.PORT ?? 3000);
const DATA_DIR = process.env.DATA_DIR ?? path.resolve(process.cwd(), 'data');
const TIME_SCALE = Number(process.env.HOKM_TIME_SCALE ?? 1) || 1;
const here = path.dirname(fileURLToPath(import.meta.url));
const CLIENT_DIR = process.env.CLIENT_DIR ?? path.resolve(here, '../client');

/** Shuffles and deals use the OS's cryptographic randomness: 53-bit floats in [0, 1). */
const pool = new Uint32Array(512);
let poolPos = pool.length;
const secureRng: Rng = () => {
  if (poolPos + 2 > pool.length) {
    crypto.getRandomValues(pool);
    poolPos = 0;
  }
  const hi = pool[poolPos++] >>> 5;
  const lo = pool[poolPos++] >>> 6;
  return (hi * 67_108_864 + lo) / 9_007_199_254_740_992;
};

const store = new ProfileStore(DATA_DIR, process.env.HOKM_SECRET);
const rooms = new Map<string, Room>();
const roomOf = new Map<string, string>();
const sessions = new Map<string, GameSocket>();

const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function newCode(): string {
  for (;;) {
    let code = '';
    for (let i = 0; i < 4; i++) code += CODE_CHARS[crypto.randomInt(CODE_CHARS.length)];
    if (!rooms.has(code)) return code;
  }
}

function sendProfile(profile: Profile) {
  sessions.get(profile.id)?.emit('profile', { profile, token: store.sign(profile) });
}

const deps = { store, rng: secureRng, timeScale: TIME_SCALE, sendProfile };

const httpServer = http.createServer((req, res) => {
  if (req.url === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'text/plain' }).end('ok');
    return;
  }
  // Counts only, no names: lets a deploy wait until nobody is mid-game (a restart ends every table).
  if (req.url === '/status') {
    const tables = [...rooms.values()];
    void relayStatus().then((voiceRelay) => {
      const status = {
        online: sessions.size,
        tables: tables.length,
        gamesInProgress: tables.filter((r) => r.match && !r.match.ended && r.onlineHumans.length > 0).length,
        voiceRelay,
      };
      res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }).end(JSON.stringify(status));
    });
    return;
  }
  serveStatic(CLIENT_DIR, req, res);
});

const io = new Server<ClientToServer, ServerToClient>(httpServer, {
  pingInterval: 10_000,
  pingTimeout: 9_000,
  maxHttpBufferSize: 64 * 1024,
  cors: process.env.NODE_ENV === 'production' ? undefined : { origin: true },
});

function fail<T>(ack: Ack<T> | undefined, error: string) {
  if (typeof ack === 'function') ack({ ok: false, error });
}

function ok<T>(ack: Ack<T> | undefined, data?: T) {
  if (typeof ack === 'function') ack({ ok: true, data });
}

io.on('connection', (raw: GameSocket) => {
  let profile: Profile | null = null;
  let lang: Lang = 'en';
  // Every handler runs guarded: a bug in one event must not take every table down with it.
  const socket = new Proxy(raw, {
    get(target, prop, receiver) {
      if (prop !== 'on') return Reflect.get(target, prop, receiver);
      return (event: string, handler: (...args: unknown[]) => unknown) =>
        target.on(
          event as never,
          ((...args: unknown[]) => {
            try {
              const out = handler(...args);
              if (out instanceof Promise) out.catch((err) => console.error(`Error in ${event}:`, err));
            } catch (err) {
              console.error(`Error in ${event}:`, err);
            }
          }) as never,
        );
    },
  }) as GameSocket;

  // Token buckets: bursts are fine, floods are not. Voice negotiation gets its
  // own, roomier one — a phone on mobile data sends a flurry of ICE candidates
  // to every other player at once, and dropping them breaks the call.
  // GIF searches reach GIPHY, so they get a tight bucket of their own.
  const buckets = {
    game: { tokens: 40, cap: 40, rate: 20, at: Date.now() },
    voice: { tokens: 240, cap: 240, rate: 60, at: Date.now() },
    gif: { tokens: 8, cap: 8, rate: 1, at: Date.now() },
  };
  socket.use(([event], next) => {
    const b = event === 'voice:signal' ? buckets.voice : event === 'gif:search' ? buckets.gif : buckets.game;
    const now = Date.now();
    b.tokens = Math.min(b.cap, b.tokens + ((now - b.at) / 1000) * b.rate);
    b.at = now;
    if (b.tokens < 1) return next(new Error('slow_down'));
    b.tokens -= 1;
    next();
  });
  socket.on('error', () => {});

  const room = (): Room | undefined => {
    if (!profile) return undefined;
    const code = roomOf.get(profile.id);
    return code ? rooms.get(code) : undefined;
  };

  const leaveRoom = () => {
    if (!profile) return;
    const r = room();
    roomOf.delete(profile.id);
    if (r) {
      r.leave(profile.id);
      if (r.isEmpty) closeRoom(r);
    }
  };

  socket.on('hello', async (msg, ack) => {
    if (typeof ack !== 'function') return;
    const token = typeof msg?.token === 'string' ? msg.token : '';
    if (msg?.lang === 'fa' || msg?.lang === 'en') lang = msg.lang;
    let p = token ? store.resolve(token) : null;
    if (!p) {
      if (typeof msg?.name !== 'string' || !msg.name.trim()) return fail(ack, 'need_profile');
      p = store.create(msg.name, msg.avatar);
    }
    // One live connection per player: a second tab or phone takes over.
    const previous = sessions.get(p.id);
    if (previous && previous.id !== socket.id) {
      previous.emit('kicked', { reason: 'elsewhere' });
      previous.disconnect(true);
    }
    profile = p;
    sessions.set(p.id, socket);
    const r = room();
    if (r) {
      if (r.join(p, socket)) roomOf.delete(p.id);
    }
    ack({
      ok: true,
      data: {
        profile: p,
        token: store.sign(p),
        iceServers: await iceServers(),
        serverNow: Date.now(),
        room: room()?.code ?? null,
        features: { gifs: gifsEnabled },
      },
    });
  });

  socket.on('disconnect', () => {
    if (!profile || sessions.get(profile.id) !== socket) return;
    sessions.delete(profile.id);
    room()?.disconnect(profile.id);
  });

  // ——— Profile and shop ———

  socket.on('profile:update', (msg, ack) => {
    if (!profile) return fail(ack, 'no_profile');
    if (typeof msg?.name === 'string' && !store.rename(profile, msg.name)) return fail(ack, 'bad_name');
    sendProfile(profile);
    room()?.touch();
    ok(ack);
  });

  socket.on('shop:buy', (msg, ack) => {
    if (!profile) return fail(ack, 'no_profile');
    const err = store.buy(profile, String(msg?.item));
    if (err) return fail(ack, err);
    sendProfile(profile);
    ok(ack);
  });

  socket.on('shop:equip', (msg, ack) => {
    if (!profile) return fail(ack, 'no_profile');
    const err = store.equip(profile, String(msg?.item));
    if (err) return fail(ack, err);
    sendProfile(profile);
    room()?.touch();
    ok(ack);
  });

  socket.on('daily:claim', (ack) => {
    if (!profile) return fail(ack, 'no_profile');
    const gift = store.claimDaily(profile);
    if (!gift) return fail(ack, 'not_ready');
    sendProfile(profile);
    ok(ack, gift);
  });

  // ——— Rooms ———

  socket.on('room:create', (msg, ack) => {
    if (!profile) return fail(ack, 'no_profile');
    leaveRoom();
    const code = newCode();
    const r = new Room(code, deps);
    rooms.set(code, r);
    r.join(profile, socket);
    roomOf.set(profile.id, code);
    r.updateSettings(profile.id, (msg?.settings ?? {}) as Partial<RoomSettings>);
    if (msg?.practice) {
      for (let seat = 0; seat < 4; seat++) if (!r.seats[seat]) r.setBot(profile.id, seat, true);
      r.start(profile.id);
    }
    ok(ack, { code });
  });

  socket.on('room:join', (msg, ack) => {
    if (!profile) return fail(ack, 'no_profile');
    const code = String(msg?.code ?? '')
      .toUpperCase()
      .trim();
    const r = rooms.get(code);
    if (!r) return fail(ack, 'no_such_room');
    if (roomOf.get(profile.id) !== code) leaveRoom();
    const err = r.join(profile, socket);
    if (err) return fail(ack, err);
    roomOf.set(profile.id, code);
    ok(ack, { code });
  });

  socket.on('room:leave', () => {
    leaveRoom();
    socket.emit('room', null);
  });

  socket.on('room:sit', (msg, ack) => {
    const r = room();
    if (!r || !profile) return fail(ack, 'no_room');
    const err = r.sit(profile.id, Number(msg?.seat));
    if (err) return fail(ack, err);
    ok(ack);
  });

  socket.on('room:stand', () => profile && room()?.stand(profile.id));

  socket.on('room:bot', (msg, ack) => {
    const r = room();
    if (!r || !profile) return fail(ack, 'no_room');
    const err = r.setBot(profile.id, Number(msg?.seat), !!msg?.add);
    if (err) return fail(ack, err);
    ok(ack);
  });

  socket.on('room:kick', (msg) => {
    const r = room();
    if (!r || !profile) return;
    const target = String(msg?.id);
    r.kick(profile.id, target);
    if (!target.startsWith('bot_') && roomOf.get(target) === r.code) roomOf.delete(target);
  });

  socket.on('room:settings', (msg) => profile && room()?.updateSettings(profile.id, msg ?? {}));
  socket.on('room:shuffleSeats', () => profile && room()?.shuffleSeats(profile.id));
  socket.on('room:rematch', () => profile && room()?.voteRematch(profile.id));
  socket.on('room:lobby', () => profile && room()?.toLobby(profile.id));

  socket.on('room:start', (ack) => {
    const r = room();
    if (!r || !profile) return fail(ack, 'no_room');
    const err = r.start(profile.id);
    if (err) return fail(ack, err);
    ok(ack);
  });

  // ——— The game ———

  socket.on('game:shuffle', (msg) => profile && room()?.gameShuffle(profile.id, msg?.kind === 'cut' ? 'cut' : 'riffle'));
  socket.on('game:shuffleDone', () => profile && room()?.gameShuffleDone(profile.id));
  socket.on('game:cut', (msg) => profile && room()?.gameCut(profile.id, Number(msg?.count)));
  socket.on('game:cutDone', () => profile && room()?.gameCutDone(profile.id));
  socket.on('game:trump', (msg) => profile && room()?.gameTrump(profile.id, String(msg?.suit)));
  socket.on('game:back', () => profile && room()?.gameBack(profile.id));

  socket.on('game:play', (msg, ack) => {
    const r = room();
    if (!r || !profile) return fail(ack, 'no_room');
    const err = r.gamePlay(profile.id, String(msg?.card), Number(msg?.power ?? 0));
    if (err) return fail(ack, err);
    ok(ack);
  });

  socket.on('game:surrender', () => {
    const r = room();
    if (!r || !profile) return;
    const err = r.surrender(profile.id);
    if (err) socket.emit('fx', { type: 'toast', key: `surrender_${err}` });
  });

  socket.on('game:surrenderVote', (msg) => profile && room()?.surrenderVote(profile.id, !!msg?.agree));

  socket.on('game:boom', (ack) => {
    const r = room();
    if (!r || !profile) return fail(ack, 'no_room');
    const err = r.boom(profile.id);
    if (err) return fail(ack, err);
    ok(ack);
  });

  socket.on('game:swapOffer', (msg, ack) => {
    const r = room();
    if (!r || !profile) return fail(ack, 'no_room');
    const err = r.offerSwap(profile.id, Number(msg?.to));
    if (err) return fail(ack, err);
    ok(ack);
  });

  socket.on('game:swapAnswer', (msg) => profile && room()?.answerSwap(profile.id, !!msg?.accept));

  // ——— Social ———

  socket.on('fx:emote', (msg) => profile && room()?.emote(profile.id, String(msg?.emote)));
  socket.on('fx:throw', (msg) => profile && room()?.throwItem(profile.id, String(msg?.to), String(msg?.item)));
  socket.on('chat', (msg) => profile && room()?.say(profile.id, String(msg?.text ?? '')));

  socket.on('chat:gif', (msg, ack) => {
    const r = room();
    if (!r || !profile) return fail(ack, 'no_room');
    const gif = vettedGif(msg?.id);
    if (!gif) return fail(ack, 'gif_gone');
    const err = r.sayGif(profile.id, gif);
    if (err) return fail(ack, err);
    ok(ack);
  });

  socket.on('gif:search', async (msg, ack) => {
    if (typeof ack !== 'function') return;
    if (!profile) return fail(ack, 'no_profile');
    if (!gifsEnabled) return fail(ack, 'gifs_off');
    try {
      ok(ack, await searchGifs(String(msg?.q ?? ''), Number(msg?.offset ?? 0), lang));
    } catch (err) {
      console.error('GIF search failed:', err instanceof Error ? err.message : err);
      fail(ack, 'gifs_down');
    }
  });

  socket.on('leaderboard', (msg, ack) => {
    if (typeof ack !== 'function') return;
    if (!profile) return fail(ack, 'no_profile');
    const period = msg?.period === 'week' ? 'week' : 'all';
    const scope = msg?.scope === 'played' ? 'played' : 'global';
    ok(ack, store.leaderboard(period, scope, profile));
  });

  socket.on('voice:join', () => profile && room()?.voiceJoin(profile.id));
  socket.on('voice:leave', () => profile && room()?.voiceLeave(profile.id));
  socket.on('voice:mic', (msg) => profile && room()?.voiceMic(profile.id, !!msg?.on));
  socket.on('voice:signal', (msg) => {
    if (!profile || !msg || typeof msg.to !== 'string') return;
    room()?.voiceSignal(profile.id, msg.to, msg.data);
  });
});

function closeRoom(r: Room) {
  r.dispose();
  rooms.delete(r.code);
  for (const [id, code] of roomOf) if (code === r.code) roomOf.delete(id);
}

// Rooms nobody has been connected to for a while are closed.
setInterval(() => {
  const now = Date.now();
  for (const r of rooms.values()) {
    if (r.onlineHumans.length === 0 && now - r.lastActive > 20 * 60_000) closeRoom(r);
  }
}, 60_000).unref();

process.on('uncaughtException', (err) => console.error('Uncaught:', err));
process.on('unhandledRejection', (err) => console.error('Unhandled rejection:', err));

const shutdown = () => {
  store.flush();
  process.exit(0);
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

httpServer.listen(PORT, () => {
  const hasClient = fs.existsSync(path.join(CLIENT_DIR, 'index.html'));
  console.log(`Hokm server listening on http://localhost:${PORT}${hasClient ? '' : ' (no client build found; use the Vite dev server)'}`);
});
