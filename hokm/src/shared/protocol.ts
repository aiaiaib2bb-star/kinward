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
  /** Booms called and booms that took all 13 tricks. */
  boomsCalled: number;
  booms: number;
  /** Hands traded with an opponent. */
  swaps: number;
}

/** Someone you played with or against, as a past game remembers them. */
export interface RecordPlayer {
  /** Only people have ids; bots carry their name key. */
  id?: string;
  name: string;
  bot?: boolean;
}

/** One finished game, from the point of view of the player who kept it. */
export interface GameRecord {
  at: number;
  won: boolean;
  reason: 'score' | 'surrender' | 'boom';
  /** Your team's points first. */
  score: [number, number];
  target: number;
  hands: number;
  kots: number;
  /** A boom in this game: 'won' if your team pulled one off, 'lost' if the other team did. */
  boom?: 'won' | 'lost';
  coins: number;
  partner: RecordPlayer | null;
  opponents: RecordPlayer[];
}

/** Wins this week, for the weekly leaderboard. `key` counts weeks from Monday 5 Jan 1970 (UTC). */
export interface WeekStats {
  key: number;
  played: number;
  won: number;
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
  /** Your most recent games, newest first. */
  history: GameRecord[];
  week: WeekStats;
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
  /** Players may offer an opponent a straight swap of hands. */
  swaps: boolean;
  /** Players may call Boom: take all 13 tricks and win the game outright. */
  booms: boolean;
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
  reason: 'score' | 'surrender' | 'boom';
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
  handResult: (HandOutcome & { tricks: [number, number]; nextHakem: number; hakem: number; boom?: BoomResult }) | null;
  matchResult: MatchResultView | null;
  surrender: { team: number; by: number; expires: number } | null;
  /** A Boom called this hand: that team must take every trick. */
  boom: { team: number; by: number } | null;
  /** A hand swap waiting on the opponent's answer. The table's clock stops meanwhile. */
  swapOffer: { from: number; to: number; expires: number } | null;
  /** Seats that have already offered a swap this hand (one offer each). */
  swapsUsed: number[];
  /** Seats whose players have stopped answering and are being played for. */
  away: number[];
}

export interface BoomResult {
  team: number;
  by: number;
  won: boolean;
}

/** A GIF from GIPHY, as the server vetted it. */
export interface Gif {
  id: string;
  /** The animation shown in chat, about 200 px wide. */
  url: string;
  /** A smaller rendition for the picker. */
  preview: string;
  w: number;
  h: number;
}

export interface ChatMessage {
  id: number;
  from: string;
  text: string;
  gif?: Gif;
  at: number;
}

export interface LeaderboardEntry {
  rank: number;
  id: string;
  name: string;
  level: number;
  equipped: Equipped;
  won: number;
  played: number;
}

export interface LeaderboardView {
  period: 'all' | 'week';
  scope: 'global' | 'played';
  entries: LeaderboardEntry[];
  /** Your own row, wherever you rank, or null if you haven't played yet. */
  you: LeaderboardEntry | null;
  /** How many players are ranked in all. */
  total: number;
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
  | { type: 'boom'; seat: number }
  | { type: 'swap'; from: number; to: number; accepted: boolean }
  | { type: 'toast'; key: string; params?: Record<string, string | number> };

export interface Welcome {
  profile: Profile;
  token: string;
  iceServers: RTCIceServerLike[];
  serverNow: number;
  room: string | null;
  features: { gifs: boolean };
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
  'game:boom': (ack: Ack) => void;
  'game:swapOffer': (msg: { to: number }, ack: Ack) => void;
  'game:swapAnswer': (msg: { accept: boolean }) => void;
  'fx:emote': (msg: { emote: string }) => void;
  'fx:throw': (msg: { to: string; item: string }) => void;
  chat: (msg: { text: string }) => void;
  'chat:gif': (msg: { id: string }, ack: Ack) => void;
  'gif:search': (msg: { q: string; offset?: number }, ack: Ack<Gif[]>) => void;
  leaderboard: (msg: { period: LeaderboardView['period']; scope: LeaderboardView['scope'] }, ack: Ack<LeaderboardView>) => void;
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
