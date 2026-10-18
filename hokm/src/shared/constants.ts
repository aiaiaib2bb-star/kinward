// Timings the server paces the table by. The client reads the same numbers
// so its animations land when the server moves on.

export const T = {
  hakemRevealStep: 420,
  hakemRevealHold: 2400,
  shufflePhase: 30_000,
  /** Minimum gap between two shuffle moves — the length of one riffle on screen. */
  shuffleOp: 650,
  cutPhase: 20_000,
  /** After a cut, the deal starts on its own if the cutter does nothing more. */
  cutLinger: 6_000,
  cutAnim: 700,
  dealCardGap: 70,
  dealFlight: 320,
  dealPacketGap1: 380,
  dealPacketGap2: 300,
  trumpPhase: 20_000,
  trumpAnnounce: 1_300,
  trickEnd: 1_250,
  handEnd: 6_500,
  botMin: 650,
  botMax: 1_400,
  /** How fast a player marked away is played for. */
  awayPlay: 1_200,
  /** How long a disconnected player gets before their move is made for them. */
  offlineGrace: 8_000,
  surrenderVote: 20_000,
  surrenderCooldown: 30_000,
  /** How long an opponent has to answer a hand-swap offer. The table waits meanwhile. */
  swapOffer: 12_000,
  rematchWindow: 90_000,
} as const;

/** How long a deal stage animates for: stage 1 is the 5-card packets, stage 2 the two rounds of 4. */
export function dealDuration(stage: 1 | 2): number {
  if (stage === 1) return 3 * T.dealPacketGap1 + 4 * T.dealCardGap + T.dealFlight + 250;
  return T.trumpAnnounce + 7 * T.dealPacketGap2 + 3 * T.dealCardGap + T.dealFlight + 250;
}

export const TURN_TIMES = [15, 30, 60, 0] as const;
export const TARGET_SCORES = [3, 5, 7, 10] as const;

export const ECONOMY = {
  startCoins: 300,
  winCoins: 100,
  lossCoins: 20,
  kotBonus: 15,
  hakemKotBonus: 30,
  /** On top of the win, for the team that pulled off a Boom. */
  boomBonus: 150,
  winXp: 60,
  lossXp: 25,
  handWonXp: 5,
  levelUpCoins: 50,
  dailyBase: 50,
  dailyStep: 10,
  dailyMaxStreak: 7,
  /** Hours before the daily gift can be opened again, and before a streak lapses. */
  dailyCooldownHours: 20,
  dailyStreakHours: 48,
} as const;

/** Coin rewards shrink when bots fill seats, so practising alone isn't a coin farm. */
export function humanRewardFactor(humans: number): number {
  return [0, 0.4, 0.6, 0.8, 1][Math.max(0, Math.min(4, humans))];
}

export function xpForLevel(level: number): number {
  return 50 * level * (level - 1);
}

export function levelOf(xp: number): number {
  return Math.max(1, Math.floor((1 + Math.sqrt(1 + 0.08 * Math.max(0, xp))) / 2));
}

export const LIMITS = {
  nameLength: 16,
  chatLength: 140,
  roomMembers: 10,
  chatHistory: 40,
  /** Past games kept in a profile. */
  history: 30,
  leaderboard: 50,
  gifQuery: 50,
} as const;

/** Weeks since Monday 5 January 1970, in UTC: the weekly leaderboard resets every Monday. */
export function weekKey(now = Date.now()): number {
  return Math.floor((Math.floor(now / 86_400_000) - 4) / 7);
}

/** A title for each stretch of levels, shown under names on the leaderboard. */
export const LEVEL_TITLES: readonly { from: number; en: string; fa: string }[] = [
  { from: 1, en: 'Newcomer', fa: 'تازه‌کار' },
  { from: 3, en: 'Beginner', fa: 'نوآموز' },
  { from: 5, en: 'Intermediate', fa: 'متوسط' },
  { from: 8, en: 'Skilled', fa: 'ماهر' },
  { from: 12, en: 'Expert', fa: 'کاربلد' },
  { from: 16, en: 'Tough Rival', fa: 'حریف قدر' },
  { from: 20, en: 'Master', fa: 'استاد' },
  { from: 25, en: 'Grand Master', fa: 'استاد بزرگ' },
  { from: 30, en: 'Sultan of Hokm', fa: 'سلطان حکم' },
];

export function levelTitle(level: number): { en: string; fa: string } {
  let title = LEVEL_TITLES[0];
  for (const t of LEVEL_TITLES) if (level >= t.from) title = t;
  return title;
}

/** Release speeds (px/ms) at which a thrown card becomes a slam, and at which the slam is at full power. */
export const SLAM = {
  minSpeed: 2.3,
  maxSpeed: 5.5,
  /** Server-side: a play with at least this power shakes the table. */
  threshold: 0.05,
} as const;
