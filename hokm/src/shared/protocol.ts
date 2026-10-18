import type { Card, Suit } from './cards';
import type { Equipped } from './catalog';
import type { HandOutcome, Play } from './rules';

// The wire format between client and server. The server is the only one
// that knows the deck and everyone's hands; each client receives a view
// with just what its player is allowed to see.

export type Lang = 'en' | 'fa';

export interface Stats {
  played: number;
  won: number;
  lost: number;
  handsPlayed: number;
  handsWon: number;
  kots: number;
  hakemKots: number;
  timesHakem: number;
  slams: number;
  surrenders: number;
  streak: number;
  bestStreak: number;
  coinsEarned: number;
}

export interface Profile {
  id: string;
  name: string;
  coins: number;
  xp: number;
  owned: string[];
  equipped: Equipped;
  stats: Stats;
  daily: { last: number; streak: number };
  createdAt: number;
  /** Bumped on every change; the higher of two copies wins. */
  v: number;
}

/** What other people see of a player. */
export interface PublicProfile {
  id: string;
  name: string;
  level: number;
  equipped: Equipped;
  stats: Pick<Stats, 'played' | 'won' | 'kots' | 'hakemKots' | 'bestStreak'>;
  bot?: boolean;
}

export interface RoomSettings {
  targetScore: number;
  /** Seconds per move; 0 means no limit. */
  turnTime: number;
  /** 'real': the deck carries the last hand's order and only the dealer's shuffles mix it. 'random': every deal is fully random. */
  shuffleMode: 'real' | 'random';
}

export interface MemberView {
  id: string;
  profile: PublicProfile;
  seat: number | null;
  online: boolean;
  /** Being played for automatically (away, disconnected or left). */
  auto: boolean;
  inVoice: boolean;
  micOn: boolean;
}

export type Phase = 'hakemSelect' | 'shuffle' | 'cut' | 'deal1' | 'trump' | 'deal2' | 'play' | 'trickEnd' | 'handEnd' | 'matchEnd';

export interface DeckOp {
  kind: 'riffle' | 'cut';
  /** For cuts, how many cards were lifted off the top (out of `of`). */
  count?: number;
  of?: number;
  seq: number;
}

export interface MatchResultView {
  winnerTeam: number;
  reason: 'score' | 'surrender';
  /** Coins and XP each human player earned, by member id. */
  rewards: Record<string, { coins: number; xp: number; levelUp?: number }>;
}

export interface GameView {
  phase: Phase;
  phaseStartedAt: number;
  /** When the current actor runs out of time, or null for no limit. Server clock. */
  deadline: number | null;
  /** When that countdown started, so a timer ring knows its full length. */
  deadlineFrom: number | null;
  handNumber: number;
  scores: [number, number];
  targetScore: number;
  hakem: number | null;
  cutter: number | null;
  trump: Suit | null;
  turn: number | null;
  trick: Play[];
  /** How hard each card in the current trick was slammed, if it was. */
  trickSlams: Record<string, number>;
  tricksWon: [number, number];
  handCounts: number[];
  /** Your cards, if you hold a seat. During the trump call only the first five are dealt to you. */
  hand: Card[];
  /** Cards you may play right now. */
  legal: Card[];
  hakemReveals: Play[];
  deckOps: { shuffles: number; cuts: number; last: DeckOp | null };
  dealer: number | null;
  lastTrick: { plays: Play[]; winner: number } | null;
  trickWinner: number | null;
  handResult: (HandOutcome & { tricks: [number, number]; nextHakem: number; hakem: number }) | null;
  matchResult: MatchResultView | null;
  surrender: { team: number; by: number; expires: number } | null;
  /** Seats whose players have stopped answering and are being played for. */
  away: number[];
}

export interface ChatMessage {
  id: number;
  from: string;
  text: string;
  at: number;
}

export interface RoomView {
  code: string;
  hostId: string;
  settings: RoomSettings;
  members: MemberView[];
  seats: (string | null)[];
  game: GameView | null;
  you: string;
  chat: ChatMessage[];
  rematch: string[];
  serverNow: number;
}

export type FxEvent =
  | { type: 'emote'; from: string; emote: string }
  | { type: 'throw'; from: string; to: string; item: string }
  | { type: 'slam'; seat: number; power: number; effect: string; card: Card }
  | { type: 'chat'; message: ChatMessage }
  | { type: 'toast'; key: string; params?: Record<string, string | number> };

export interface Welcome {
  profile: Profile;
  token: string;
  iceServers: RTCIceServerLike[];
  serverNow: number;
  room: string | null;
}

export interface RTCIceServerLike {
  urls: string | string[];
  username?: string;
  credential?: string;
}

export type Ack<T = unknown> = (res: { ok: true; data?: T } | { ok: false; error: string }) => void;

export interface ClientToServer {
  hello: (msg: { token?: string; name?: string; avatar?: string; lang?: Lang }, ack: Ack<Welcome>) => void;
  'profile:update': (msg: { name?: string }, ack: Ack) => void;
  'shop:buy': (msg: { item: string }, ack: Ack) => void;
  'shop:equip': (msg: { item: string }, ack: Ack) => void;
  'daily:claim': (ack: Ack<{ coins: number; streak: number }>) => void;
  'room:create': (msg: { settings?: Partial<RoomSettings>; practice?: boolean }, ack: Ack<{ code: string }>) => void;
  'room:join': (msg: { code: string }, ack: Ack<{ code: string }>) => void;
  'room:leave': () => void;
  'room:sit': (msg: { seat: number }, ack: Ack) => void;
  'room:stand': () => void;
  'room:bot': (msg: { seat: number; add: boolean }, ack: Ack) => void;
  'room:kick': (msg: { id: string }) => void;
  'room:settings': (msg: Partial<RoomSettings>) => void;
  'room:start': (ack: Ack) => void;
  'room:shuffleSeats': () => void;
  'room:rematch': () => void;
  'room:lobby': () => void;
  'game:shuffle': (msg: { kind: 'riffle' | 'cut' }) => void;
  'game:shuffleDone': () => void;
  'game:cut': (msg: { count: number }) => void;
  'game:cutDone': () => void;
  'game:trump': (msg: { suit: Suit }) => void;
  'game:play': (msg: { card: Card; power?: number }, ack: Ack) => void;
  'game:back': () => void;
  'game:surrender': () => void;
  'game:surrenderVote': (msg: { agree: boolean }) => void;
  'fx:emote': (msg: { emote: string }) => void;
  'fx:throw': (msg: { to: string; item: string }) => void;
  chat: (msg: { text: string }) => void;
  'voice:join': () => void;
  'voice:leave': () => void;
  'voice:mic': (msg: { on: boolean }) => void;
  'voice:signal': (msg: { to: string; data: unknown }) => void;
}

export interface ServerToClient {
  room: (view: RoomView | null) => void;
  profile: (msg: { profile: Profile; token: string }) => void;
  fx: (event: FxEvent) => void;
  'voice:signal': (msg: { from: string; data: unknown }) => void;
  kicked: (msg: { reason: string }) => void;
}
