import { type Socket, io } from 'socket.io-client';
import type { Card, Suit } from '../../shared/cards';
import type { ClientToServer, FxEvent, Gif, LeaderboardView, RoomSettings, ServerToClient, Welcome } from '../../shared/protocol';
import { emitFx } from '../fx/bus';
import { isStringKey, t } from '../i18n';
import { app, toast } from '../state/app';
import { settings } from '../state/settings';
import { syncClock } from './clock';

const TOKEN_KEY = 'hokm.token';

export const socket: Socket<ServerToClient, ClientToServer> = io({
  autoConnect: false,
  transports: ['websocket', 'polling'],
  reconnectionDelay: 400,
  reconnectionDelayMax: 2500,
  timeout: 8000,
});

export function getToken(): string | null {
  try {
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return memoryToken;
  }
}

let memoryToken: string | null = null;

function setToken(token: string) {
  memoryToken = token;
  try {
    localStorage.setItem(TOKEN_KEY, token);
  } catch {
    // Kept in memory for this session only.
  }
}

type Result<T> = { ok: true; data?: T } | { ok: false; error: string };

/** Emits an event with an acknowledgement, giving up after a few seconds. */
function request<T>(event: string, ...args: unknown[]): Promise<Result<T>> {
  return new Promise((resolve) => {
    if (!socket.connected) return resolve({ ok: false, error: 'timeout' });
    const timer = setTimeout(() => resolve({ ok: false, error: 'timeout' }), 6000);
    (socket.emit as (...a: unknown[]) => void)(event, ...args, (res: Result<T>) => {
      clearTimeout(timer);
      resolve(res ?? { ok: false, error: 'generic' });
    });
  });
}

export function errorText(code: string): string {
  const key = `err_${code}`;
  return isStringKey(key) ? t(key) : t('err_generic');
}

/** Runs a request and toasts its error, if any. Resolves to the data on success. */
async function act<T>(event: string, ...args: unknown[]): Promise<T | undefined> {
  const res = await request<T>(event, ...args);
  if (!res.ok) {
    toast(errorText(res.error), 'bad');
    return undefined;
  }
  return res.data ?? (true as unknown as T);
}

async function hello(draft?: { name: string; avatar: string }) {
  const token = getToken() ?? undefined;
  const res = await request<Welcome>('hello', { token, ...draft, lang: settings.get().lang });
  if (!res.ok) {
    if (res.error === 'need_profile') app.set({ needsProfile: true, ready: true });
    return false;
  }
  const w = res.data!;
  setToken(w.token);
  syncClock(w.serverNow);
  app.set({ profile: w.profile, iceServers: w.iceServers, needsProfile: false, ready: true, elsewhere: false, features: w.features ?? { gifs: false } });
  const pending = app.get().pendingJoin;
  if (pending) {
    app.set({ pendingJoin: null });
    if (w.room !== pending) await net.joinRoom(pending);
  }
  return true;
}

socket.on('connect', () => {
  app.set({ conn: 'online' });
  void hello();
});

socket.on('disconnect', () => app.set({ conn: 'offline' }));
socket.io.on('reconnect_attempt', () => app.set({ conn: 'connecting' }));

socket.on('room', (view) => {
  if (view) syncClock(view.serverNow);
  app.set({ room: view });
  const path = view ? `/r/${view.code}` : '/';
  if (location.pathname !== path) history.replaceState(null, '', path);
});

socket.on('profile', ({ profile, token }) => {
  setToken(token);
  app.set({ profile });
});

socket.on('fx', (event: FxEvent) => {
  if (event.type === 'toast') {
    if (isStringKey(event.key)) toast(t(event.key), 'info');
    return;
  }
  emitFx(event);
});

socket.on('kicked', ({ reason }) => {
  if (reason === 'elsewhere') app.set({ elsewhere: true, room: null });
  else toast(t('kicked'), 'bad');
});

// A phone coming back from the background should not wait out a reconnect backoff.
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && !socket.connected && !app.get().elsewhere) socket.connect();
});

export function start() {
  const match = location.pathname.match(/^\/r\/([A-Za-z0-9]{4})\/?$/);
  if (match) app.set({ pendingJoin: match[1].toUpperCase() });
  socket.connect();
}

export const net = {
  createProfile: (name: string, avatar: string) => hello({ name, avatar }),
  reconnectHere() {
    app.set({ elsewhere: false, conn: 'connecting' });
    socket.connect();
  },

  /** Checks a backup code on a throwaway connection before swapping it in. */
  async restore(code: string): Promise<boolean> {
    const probe = io({ transports: ['websocket', 'polling'], forceNew: true });
    const ok = await new Promise<boolean>((resolve) => {
      const timer = setTimeout(() => resolve(false), 6000);
      probe.on('connect', () => {
        probe.emit('hello', { token: code.trim() }, (res: { ok: boolean }) => {
          clearTimeout(timer);
          resolve(!!res?.ok);
        });
      });
    });
    probe.close();
    if (ok) {
      setToken(code.trim());
      location.reload();
    }
    return ok;
  },

  rename: (name: string) => act('profile:update', { name }),
  buy: (item: string) => act('shop:buy', { item }),
  equip: (item: string) => act('shop:equip', { item }),
  claimDaily: () => act<{ coins: number; streak: number }>('daily:claim'),

  async createRoom(opts: { settings?: Partial<RoomSettings>; practice?: boolean } = {}) {
    return act<{ code: string }>('room:create', opts);
  },
  joinRoom: (code: string) => act<{ code: string }>('room:join', { code: code.toUpperCase() }),
  leaveRoom() {
    socket.emit('room:leave');
    app.set({ room: null });
    history.replaceState(null, '', '/');
  },
  sit: (seat: number) => act('room:sit', { seat }),
  stand: () => socket.emit('room:stand'),
  bot: (seat: number, add: boolean) => act('room:bot', { seat, add }),
  kick: (id: string) => socket.emit('room:kick', { id }),
  roomSettings: (patch: Partial<RoomSettings>) => socket.emit('room:settings', patch),
  start: () => act('room:start'),
  shuffleSeats: () => socket.emit('room:shuffleSeats'),
  rematch: () => socket.emit('room:rematch'),
  lobby: () => socket.emit('room:lobby'),

  shuffle: (kind: 'riffle' | 'cut') => socket.emit('game:shuffle', { kind }),
  shuffleDone: () => socket.emit('game:shuffleDone'),
  cut: (count: number) => socket.emit('game:cut', { count }),
  cutDone: () => socket.emit('game:cutDone'),
  trump: (suit: Suit) => socket.emit('game:trump', { suit }),
  play: (card: Card, power: number) => request('game:play', { card, power }),
  back: () => socket.emit('game:back'),
  surrender: () => socket.emit('game:surrender'),
  surrenderVote: (agree: boolean) => socket.emit('game:surrenderVote', { agree }),
  boom: () => act('game:boom'),
  offerSwap: (to: number) => act('game:swapOffer', { to }),
  answerSwap: (accept: boolean) => socket.emit('game:swapAnswer', { accept }),

  emote: (emote: string) => socket.emit('fx:emote', { emote }),
  throwItem: (to: string, item: string) => socket.emit('fx:throw', { to, item }),
  chat: (text: string) => socket.emit('chat', { text }),
  sendGif: (id: string) => act('chat:gif', { id }),
  /** Quiet on failure: the picker shows its own message. */
  searchGifs: (q: string, offset = 0) => request<Gif[]>('gif:search', { q, offset }),
  leaderboard: (period: LeaderboardView['period'], scope: LeaderboardView['scope']) => request<LeaderboardView>('leaderboard', { period, scope }),

  voiceJoin: () => socket.emit('voice:join'),
  voiceLeave: () => socket.emit('voice:leave'),
  voiceMic: (on: boolean) => socket.emit('voice:mic', { on }),
  voiceSignal: (to: string, data: unknown) => socket.emit('voice:signal', { to, data }),
};
