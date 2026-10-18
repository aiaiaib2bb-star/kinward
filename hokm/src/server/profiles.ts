import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { DEFAULT_EQUIPPED, EQUIP_SLOTS, type EquipSlot, STARTER_ITEMS, getItem } from '../shared/catalog';
import { ECONOMY, LIMITS, levelOf, weekKey } from '../shared/constants';
import type { GameRecord, LeaderboardEntry, LeaderboardView, Profile, PublicProfile, RecordPlayer, Stats } from '../shared/protocol';

// Profiles live in two places on purpose. The server keeps them in a JSON
// file, and every client also holds its own profile as a signed token. If
// the server's disk is wiped (free hosts do that on every deploy), players
// come back with their token and keep their coins; the signature means a
// token can't be edited to add any. Whichever copy has the higher version
// wins.

const EMPTY_STATS: Stats = {
  played: 0,
  won: 0,
  lost: 0,
  handsPlayed: 0,
  handsWon: 0,
  kots: 0,
  hakemKots: 0,
  timesHakem: 0,
  slams: 0,
  surrenders: 0,
  streak: 0,
  bestStreak: 0,
  coinsEarned: 0,
  boomsCalled: 0,
  booms: 0,
  swaps: 0,
};

export function cleanName(raw: unknown): string {
  if (typeof raw !== 'string') return '';
  const stripped = raw
    // Control characters and bidi overrides: no zero-width tricks or names that flip the layout.
    .replace(/[\u0000-\u001f\u007f-\u009f​-‏‪-‮⁦-⁩﻿]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  return Array.from(stripped).slice(0, LIMITS.nameLength).join('');
}

export function publicProfile(p: Profile): PublicProfile {
  return {
    id: p.id,
    name: p.name,
    level: levelOf(p.xp),
    equipped: { ...p.equipped },
    stats: {
      played: p.stats.played,
      won: p.stats.won,
      kots: p.stats.kots,
      hakemKots: p.stats.hakemKots,
      bestStreak: p.stats.bestStreak,
    },
  };
}

const b64 = (buf: Buffer | string) => Buffer.from(buf).toString('base64url');

export class ProfileStore {
  private readonly profiles = new Map<string, Profile>();
  private readonly file: string | null;
  private readonly secret: Buffer;
  private dirty = false;
  private flushTimer: NodeJS.Timeout | null = null;

  constructor(dataDir: string | null, secret?: string) {
    this.file = dataDir ? path.join(dataDir, 'profiles.json') : null;
    if (dataDir) fs.mkdirSync(dataDir, { recursive: true });
    this.secret = Buffer.from(secret || this.loadOrCreateSecret(dataDir));
    this.load();
  }

  private loadOrCreateSecret(dataDir: string | null): string {
    if (!dataDir) return crypto.randomBytes(32).toString('hex');
    const file = path.join(dataDir, 'secret.key');
    try {
      return fs.readFileSync(file, 'utf8').trim();
    } catch {
      const secret = crypto.randomBytes(32).toString('hex');
      fs.writeFileSync(file, secret, { mode: 0o600 });
      return secret;
    }
  }

  private load() {
    if (!this.file) return;
    try {
      const data = JSON.parse(fs.readFileSync(this.file, 'utf8')) as Profile[];
      for (const p of data) this.profiles.set(p.id, normalize(p));
    } catch {
      // First run, or an unreadable file: start empty. Tokens still restore everyone.
    }
  }

  private scheduleFlush() {
    this.dirty = true;
    if (this.flushTimer || !this.file) return;
    this.flushTimer = setTimeout(() => {
      this.flushTimer = null;
      this.flush();
    }, 1500);
  }

  flush() {
    if (!this.file || !this.dirty) return;
    this.dirty = false;
    const tmp = `${this.file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify([...this.profiles.values()]));
    fs.renameSync(tmp, this.file);
  }

  sign(p: Profile): string {
    const body = b64(JSON.stringify(p));
    const sig = crypto.createHmac('sha256', this.secret).update(body).digest('base64url');
    return `${body}.${sig}`;
  }

  /** Returns the profile a token stands for, or null if it was tampered with or signed by another server. */
  verify(token: string): Profile | null {
    if (typeof token !== 'string' || token.length > 20_000) return null;
    const dot = token.lastIndexOf('.');
    if (dot < 0) return null;
    const body = token.slice(0, dot);
    const sig = Buffer.from(token.slice(dot + 1));
    const expected = Buffer.from(crypto.createHmac('sha256', this.secret).update(body).digest('base64url'));
    if (sig.length !== expected.length || !crypto.timingSafeEqual(sig, expected)) return null;
    try {
      return normalize(JSON.parse(Buffer.from(body, 'base64url').toString('utf8')));
    } catch {
      return null;
    }
  }

  /** Signs in with a token, preferring whichever copy of the profile is newer. */
  resolve(token: string): Profile | null {
    const fromToken = this.verify(token);
    if (!fromToken) return null;
    const stored = this.profiles.get(fromToken.id);
    if (stored && stored.v >= fromToken.v) return stored;
    this.profiles.set(fromToken.id, fromToken);
    this.scheduleFlush();
    return fromToken;
  }

  get(id: string): Profile | undefined {
    return this.profiles.get(id);
  }

  create(name: string, avatar: string | undefined): Profile {
    const id = crypto.randomBytes(9).toString('base64url');
    const equipped = { ...DEFAULT_EQUIPPED };
    const av = avatar ? getItem(avatar) : undefined;
    if (av && av.kind === 'avatar' && av.price === 0) equipped.avatar = av.id;
    const profile: Profile = {
      id,
      name: cleanName(name) || 'Player',
      coins: ECONOMY.startCoins,
      xp: 0,
      owned: [...STARTER_ITEMS],
      equipped,
      stats: { ...EMPTY_STATS },
      daily: { last: 0, streak: 0 },
      history: [],
      week: { key: weekKey(), played: 0, won: 0 },
      createdAt: Date.now(),
      v: 1,
    };
    this.profiles.set(id, profile);
    this.scheduleFlush();
    return profile;
  }

  /** Records a change. Call after mutating a profile in place. */
  save(p: Profile) {
    p.v += 1;
    this.profiles.set(p.id, p);
    this.scheduleFlush();
  }

  rename(p: Profile, name: string): boolean {
    const clean = cleanName(name);
    if (!clean) return false;
    p.name = clean;
    this.save(p);
    return true;
  }

  buy(p: Profile, itemId: string): string | null {
    const it = getItem(itemId);
    if (!it) return 'unknown_item';
    if (p.owned.includes(it.id)) return 'already_owned';
    if (p.coins < it.price) return 'not_enough_coins';
    p.coins -= it.price;
    p.owned.push(it.id);
    this.save(p);
    return null;
  }

  equip(p: Profile, itemId: string): string | null {
    const it = getItem(itemId);
    if (!it) return 'unknown_item';
    if (!p.owned.includes(it.id)) return 'not_owned';
    const slot = (EQUIP_SLOTS as readonly string[]).includes(it.kind) ? (it.kind as EquipSlot) : null;
    if (!slot) return 'not_equippable';
    p.equipped[slot] = it.id;
    this.save(p);
    return null;
  }

  /**
   * Players ranked by games won, all time or this week. `among` narrows it to
   * a set of players (the people you've played with). Ties go to whoever
   * needed fewer games.
   */
  leaderboard(period: LeaderboardView['period'], scope: LeaderboardView['scope'], you: Profile): LeaderboardView {
    const week = weekKey();
    const among =
      scope === 'played' ? new Set([you.id, ...you.history.flatMap((g) => [g.partner, ...g.opponents]).flatMap((x) => (x?.id ? [x.id] : []))]) : null;
    const tally = (p: Profile) => (period === 'week' ? (p.week.key === week ? p.week : { played: 0, won: 0 }) : p.stats);
    const rows = [...this.profiles.values()]
      .filter((p) => (!among || among.has(p.id)) && tally(p).played > 0)
      .map((p) => ({ p, ...tally(p) }))
      .sort((a, b) => b.won - a.won || a.played - b.played || a.p.createdAt - b.p.createdAt);
    const entry = (r: (typeof rows)[number], i: number): LeaderboardEntry => ({
      rank: i + 1,
      id: r.p.id,
      name: r.p.name,
      level: levelOf(r.p.xp),
      equipped: { ...r.p.equipped },
      won: r.won,
      played: r.played,
    });
    const mine = rows.findIndex((r) => r.p.id === you.id);
    return {
      period,
      scope,
      entries: rows.slice(0, LIMITS.leaderboard).map(entry),
      you: mine >= 0 ? entry(rows[mine], mine) : null,
      total: rows.length,
    };
  }

  /** Opens the daily gift if it's ready. Consecutive days grow it, up to a week. */
  claimDaily(p: Profile, now = Date.now()): { coins: number; streak: number } | null {
    const hours = (now - p.daily.last) / 3_600_000;
    if (hours < ECONOMY.dailyCooldownHours) return null;
    const streak = hours <= ECONOMY.dailyStreakHours ? Math.min(ECONOMY.dailyMaxStreak, p.daily.streak + 1) : 1;
    const coins = ECONOMY.dailyBase + ECONOMY.dailyStep * (streak - 1);
    p.daily = { last: now, streak };
    p.coins += coins;
    p.stats.coinsEarned += coins;
    this.save(p);
    return { coins, streak };
  }
}

/** Fills in anything an older profile (or a hand-edited file) is missing. */
function normalize(raw: Profile): Profile {
  const owned = Array.isArray(raw.owned) ? raw.owned.filter((id) => typeof id === 'string' && getItem(id)) : [];
  for (const id of STARTER_ITEMS) if (!owned.includes(id)) owned.push(id);
  const equipped = { ...DEFAULT_EQUIPPED };
  for (const slot of EQUIP_SLOTS) {
    const id = raw.equipped?.[slot];
    const it = id ? getItem(id) : undefined;
    if (it && it.kind === slot && owned.includes(id)) equipped[slot] = id;
  }
  return {
    id: String(raw.id),
    name: cleanName(raw.name) || 'Player',
    coins: Math.max(0, Math.floor(Number(raw.coins) || 0)),
    xp: Math.max(0, Math.floor(Number(raw.xp) || 0)),
    owned,
    equipped,
    stats: { ...EMPTY_STATS, ...(raw.stats ?? {}) },
    daily: { last: Number(raw.daily?.last) || 0, streak: Number(raw.daily?.streak) || 0 },
    history: Array.isArray(raw.history) ? raw.history.slice(0, LIMITS.history).flatMap(cleanRecord) : [],
    week: { key: Number(raw.week?.key) || 0, played: Number(raw.week?.played) || 0, won: Number(raw.week?.won) || 0 },
    createdAt: Number(raw.createdAt) || Date.now(),
    v: Number(raw.v) || 1,
  };
}

function cleanPlayer(raw: unknown): RecordPlayer | null {
  if (!raw || typeof raw !== 'object') return null;
  const r = raw as RecordPlayer;
  const name = typeof r.name === 'string' ? r.name.slice(0, 40) : '';
  if (r.bot) return { name, bot: true };
  return typeof r.id === 'string' ? { id: r.id.slice(0, 40), name } : { name };
}

/** A past game read back from a token or the file: anything malformed is dropped. */
function cleanRecord(raw: unknown): GameRecord[] {
  if (!raw || typeof raw !== 'object') return [];
  const r = raw as GameRecord;
  const n = (v: unknown) => Math.max(0, Math.floor(Number(v) || 0));
  if (!Array.isArray(r.score) || !Number.isFinite(Number(r.at))) return [];
  return [
    {
      at: Number(r.at),
      won: !!r.won,
      reason: r.reason === 'surrender' || r.reason === 'boom' ? r.reason : 'score',
      score: [n(r.score[0]), n(r.score[1])],
      target: n(r.target),
      hands: n(r.hands),
      kots: n(r.kots),
      boom: r.boom === 'won' || r.boom === 'lost' ? r.boom : undefined,
      coins: n(r.coins),
      partner: cleanPlayer(r.partner),
      opponents: Array.isArray(r.opponents) ? r.opponents.slice(0, 2).flatMap((o) => cleanPlayer(o) ?? []) : [],
    },
  ];
}
