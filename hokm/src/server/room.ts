import type { Socket } from 'socket.io';
import { DEFAULT_EQUIPPED, ITEMS, emotesOwned, getItem } from '../shared/catalog';
import { ECONOMY, LIMITS, TARGET_SCORES, TURN_TIMES, humanRewardFactor, levelOf, weekKey } from '../shared/constants';
import type {
  ChatMessage,
  ClientToServer,
  FxEvent,
  GameRecord,
  Gif,
  MatchResultView,
  MemberView,
  Profile,
  PublicProfile,
  RecordPlayer,
  RoomSettings,
  RoomView,
  ServerToClient,
} from '../shared/protocol';
import { partnerOf, teamOf } from '../shared/rules';
import type { Rng } from '../shared/shuffle';
import { type Control, Match, type MatchEnd } from './match';
import { type ProfileStore, publicProfile } from './profiles';

export type GameSocket = Socket<ClientToServer, ServerToClient>;

export interface RoomDeps {
  store: ProfileStore;
  rng: Rng;
  timeScale: number;
  /** Pushes a player's updated profile (and fresh token) to their phone. */
  sendProfile(profile: Profile): void;
}

interface Member {
  id: string;
  bot: PublicProfile | null;
  profile: Profile | null;
  socket: GameSocket | null;
  seat: number | null;
  /** Left during a match; their seat is played for them until they come back. */
  left: boolean;
  inVoice: boolean;
  micOn: boolean;
  fxTimes: number[];
  lastChatAt: number;
}

// Bots are named for heroes of the Shahnameh. The client translates the key.
const BOT_NAMES = ['rostam', 'sohrab', 'gordafarid', 'tahmineh', 'kaveh', 'shirin', 'farhad', 'manijeh', 'bijan', 'rudabeh', 'zal', 'siavash'];

const DEFAULT_SETTINGS: RoomSettings = { targetScore: 7, turnTime: 30, swaps: true, booms: true };

export class Room {
  readonly members = new Map<string, Member>();
  readonly seats: (string | null)[] = [null, null, null, null];
  hostId = '';
  settings: RoomSettings = { ...DEFAULT_SETTINGS };
  match: Match | null = null;
  readonly chat: ChatMessage[] = [];
  readonly rematch = new Set<string>();
  /** Last time a human was connected — the registry closes rooms that stay empty. */
  lastActive = Date.now();
  private chatSeq = 0;
  private stateDirty = false;
  private flushQueued = false;
  private fxQueue: FxEvent[] = [];
  private lobbyTimer: NodeJS.Timeout | null = null;
  private hostTimer: NodeJS.Timeout | null = null;

  constructor(
    readonly code: string,
    private readonly deps: RoomDeps,
  ) {}

  // ——— Membership ———

  get humans(): Member[] {
    return [...this.members.values()].filter((m) => !m.bot);
  }

  get onlineHumans(): Member[] {
    return this.humans.filter((m) => m.socket);
  }

  private seatOf(id: string): number | null {
    const i = this.seats.indexOf(id);
    return i < 0 ? null : i;
  }

  private seatMember(seat: number): Member | undefined {
    const id = this.seats[seat];
    return id ? this.members.get(id) : undefined;
  }

  private get inMatch(): boolean {
    return !!this.match && !this.match.ended;
  }

  join(profile: Profile, socket: GameSocket): string | null {
    let m = this.members.get(profile.id);
    if (!m) {
      if (this.members.size >= LIMITS.roomMembers) return 'room_full';
      m = { id: profile.id, bot: null, profile, socket: null, seat: null, left: false, inVoice: false, micOn: false, fxTimes: [], lastChatAt: 0 };
      this.members.set(profile.id, m);
      if (!this.match) {
        const free = this.seats.indexOf(null);
        if (free >= 0) {
          this.seats[free] = m.id;
          m.seat = free;
        }
      }
    }
    m.profile = profile;
    m.socket = socket;
    m.left = false;
    socket.join(this.code);
    if (!this.hostId || !this.members.get(this.hostId) || this.members.get(this.hostId)!.bot) this.hostId = m.id;
    this.lastActive = Date.now();
    this.match?.resume();
    this.match?.presenceChanged();
    this.touch();
    return null;
  }

  /** The socket dropped; the seat is kept and played for until they're back. */
  disconnect(id: string) {
    const m = this.members.get(id);
    if (!m || m.bot) return;
    m.socket = null;
    m.inVoice = false;
    m.micOn = false;
    this.afterPresenceChange(false);
  }

  leave(id: string) {
    const m = this.members.get(id);
    if (!m || m.bot) return;
    m.socket?.leave(this.code);
    m.socket = null;
    m.inVoice = false;
    m.micOn = false;
    this.rematch.delete(id);
    if (this.inMatch && m.seat !== null) {
      m.left = true;
    } else {
      if (m.seat !== null) this.seats[m.seat] = null;
      this.members.delete(id);
    }
    this.afterPresenceChange();
  }

  /**
   * Someone came or went. A host who leaves hands the table over at once; a
   * host whose connection merely dropped (a reload, a tunnel) gets a little
   * while to come back first.
   */
  private afterPresenceChange(left = true) {
    if (!this.members.get(this.hostId)?.socket) {
      if (left || !this.members.has(this.hostId)) this.passHost();
      else {
        if (this.hostTimer) clearTimeout(this.hostTimer);
        this.hostTimer = setTimeout(() => {
          this.hostTimer = null;
          if (!this.members.get(this.hostId)?.socket) {
            this.passHost();
            this.touch();
          }
        }, 20_000);
      }
    }
    if (this.onlineHumans.length === 0) {
      this.lastActive = Date.now();
      this.match?.pause();
    } else {
      this.match?.presenceChanged();
    }
    this.checkRematch();
    this.touch();
  }

  private passHost() {
    const next = this.onlineHumans[0];
    if (next) this.hostId = next.id;
  }

  get isEmpty(): boolean {
    return this.humans.length === 0;
  }

  sit(id: string, seat: number): string | null {
    const m = this.members.get(id);
    if (!m || this.match) return 'not_now';
    if (!Number.isInteger(seat) || seat < 0 || seat > 3) return 'bad_seat';
    if (this.seats[seat] && this.seats[seat] !== id) return 'seat_taken';
    if (m.seat !== null) this.seats[m.seat] = null;
    this.seats[seat] = id;
    m.seat = seat;
    this.touch();
    return null;
  }

  stand(id: string) {
    const m = this.members.get(id);
    if (!m || this.match || m.seat === null) return;
    this.seats[m.seat] = null;
    m.seat = null;
    this.touch();
  }

  setBot(requester: string, seat: number, add: boolean): string | null {
    if (requester !== this.hostId) return 'host_only';
    if (this.match) return 'not_now';
    if (!Number.isInteger(seat) || seat < 0 || seat > 3) return 'bad_seat';
    const current = this.seatMember(seat);
    if (add) {
      if (current) return 'seat_taken';
      if (this.members.size >= LIMITS.roomMembers) return 'room_full';
      const bot = this.makeBot();
      this.members.set(bot.id, bot);
      this.seats[seat] = bot.id;
      bot.seat = seat;
    } else {
      if (!current?.bot) return 'not_a_bot';
      this.members.delete(current.id);
      this.seats[seat] = null;
    }
    this.touch();
    return null;
  }

  private makeBot(): Member {
    const taken = new Set([...this.members.values()].map((m) => m.bot?.name));
    const free = BOT_NAMES.filter((n) => !taken.has(n));
    const name = free[Math.floor(this.deps.rng() * free.length)] ?? 'rostam';
    const pick = (kind: string) => {
      const options = ITEMS.filter((i) => i.kind === kind);
      return options[Math.floor(this.deps.rng() * options.length)].id;
    };
    // Bots dress up in shop items — it shows players what they could buy.
    const equipped = {
      ...DEFAULT_EQUIPPED,
      avatar: pick('avatar'),
      cardBack: pick('cardBack'),
      frame: pick('frame'),
      aura: this.deps.rng() < 0.5 ? pick('aura') : 'aura_none',
      slam: pick('slam'),
    };
    const id = `bot_${name}_${Math.floor(this.deps.rng() * 1e6).toString(36)}`;
    const level = 3 + Math.floor(this.deps.rng() * 20);
    return {
      id,
      bot: { id, name, level, equipped, stats: { played: 0, won: 0, kots: 0, hakemKots: 0, bestStreak: 0 }, bot: true },
      profile: null,
      socket: null,
      seat: null,
      left: false,
      inVoice: false,
      micOn: false,
      fxTimes: [],
      lastChatAt: 0,
    };
  }

  kick(requester: string, target: string) {
    if (requester !== this.hostId || target === requester) return;
    const m = this.members.get(target);
    if (!m) return;
    if (m.bot) {
      if (!this.match && m.seat !== null) this.setBot(requester, m.seat, false);
      return;
    }
    m.socket?.emit('kicked', { reason: 'kicked' });
    m.socket?.emit('room', null);
    this.leave(target);
  }

  updateSettings(requester: string, patch: Partial<RoomSettings>) {
    if (requester !== this.hostId || this.match) return;
    if (TARGET_SCORES.includes(patch.targetScore as never)) this.settings.targetScore = patch.targetScore!;
    if (TURN_TIMES.includes(patch.turnTime as never)) this.settings.turnTime = patch.turnTime!;
    if (typeof patch.swaps === 'boolean') this.settings.swaps = patch.swaps;
    if (typeof patch.booms === 'boolean') this.settings.booms = patch.booms;
    this.touch();
  }

  shuffleSeats(requester: string) {
    if (requester !== this.hostId || this.match) return;
    const ids = this.seats.slice();
    for (let i = ids.length - 1; i > 0; i--) {
      const j = Math.floor(this.deps.rng() * (i + 1));
      [ids[i], ids[j]] = [ids[j], ids[i]];
    }
    ids.forEach((id, seat) => {
      this.seats[seat] = id;
      const m = id ? this.members.get(id) : undefined;
      if (m) m.seat = seat;
    });
    this.touch();
  }

  // ——— Match lifecycle ———

  start(requester: string): string | null {
    if (requester !== this.hostId) return 'host_only';
    if (this.inMatch) return 'not_now';
    if (this.seats.some((id) => !id)) return 'need_four';
    this.beginMatch();
    return null;
  }

  private beginMatch() {
    this.match?.dispose();
    this.clearLobbyTimer();
    this.rematch.clear();
    const match = new Match(
      this.settings,
      {
        control: (seat) => this.control(seat),
        changed: () => this.touch(),
        slam: (seat, power, card) => {
          const m = this.seatMember(seat);
          const effect = (m?.bot ?? (m?.profile ? publicProfile(m.profile) : null))?.equipped.slam ?? 'slam_thud';
          this.fx({ type: 'slam', seat, power, effect, card });
        },
        emote: (seat, emote) => {
          const m = this.seatMember(seat);
          if (m && this.match === match) this.fx({ type: 'emote', from: m.id, emote });
        },
        toast: (key, params) => this.fx({ type: 'toast', key, params }),
        boom: (seat) => this.fx({ type: 'boom', seat }),
        swapped: (from, to, accepted) => this.fx({ type: 'swap', from, to, accepted }),
        ended: (end) => this.settle(match, end),
      },
      this.deps.rng,
      this.deps.timeScale,
    );
    this.match = match;
    match.start();
    this.touch();
  }

  private control(seat: number): Control {
    const m = this.seatMember(seat);
    if (!m) return 'offline';
    if (m.bot) return 'bot';
    return m.socket && !m.left ? 'human' : 'offline';
  }

  /** Pays out coins and XP when a match ends. */
  private settle(match: Match, end: MatchEnd) {
    const seated = this.seats
      .map((id, seat) => ({ m: id ? this.members.get(id) : undefined, seat }))
      .filter((x): x is { m: Member; seat: number } => !!x.m?.profile);
    const factor = humanRewardFactor(seated.length);
    const rewards: MatchResultView['rewards'] = {};
    const now = Date.now();
    const week = weekKey(now);
    for (const { m, seat } of seated) {
      const p = m.profile!;
      const team = teamOf(seat);
      const won = team === end.winnerTeam;
      const surrendered = end.surrenderTeam === team;
      let coins = won ? ECONOMY.winCoins : surrendered ? 0 : ECONOMY.lossCoins;
      coins += end.stats.kots[team] * ECONOMY.kotBonus + end.stats.hakemKots[team] * ECONOMY.hakemKotBonus;
      coins += end.stats.booms[team] * ECONOMY.boomBonus;
      coins = Math.round(coins * factor);
      const xp = Math.round(((won ? ECONOMY.winXp : ECONOMY.lossXp) + end.stats.handsWon[team] * ECONOMY.handWonXp) * factor);
      const before = levelOf(p.xp);
      p.xp += xp;
      const after = levelOf(p.xp);
      if (after > before) coins += (after - before) * ECONOMY.levelUpCoins;
      p.coins += coins;
      const s = p.stats;
      s.played += 1;
      if (won) {
        s.won += 1;
        s.streak += 1;
        s.bestStreak = Math.max(s.bestStreak, s.streak);
      } else {
        s.lost += 1;
        s.streak = 0;
      }
      if (surrendered) s.surrenders += 1;
      s.handsPlayed += end.stats.hands;
      s.handsWon += end.stats.handsWon[team];
      s.kots += end.stats.kots[team];
      s.hakemKots += end.stats.hakemKots[team];
      s.timesHakem += end.stats.timesHakem[seat];
      s.slams += end.stats.slams[seat];
      s.coinsEarned += coins;
      s.boomsCalled += end.stats.boomsCalled[team];
      s.booms += end.stats.booms[team];
      s.swaps += end.stats.swaps[seat];
      if (p.week.key !== week) p.week = { key: week, played: 0, won: 0 };
      p.week.played += 1;
      if (won) p.week.won += 1;
      p.history.unshift(this.record(match, end, seat, won, coins, now));
      if (p.history.length > LIMITS.history) p.history.length = LIMITS.history;
      this.deps.store.save(p);
      this.deps.sendProfile(p);
      rewards[m.id] = { coins, xp, levelUp: after > before ? after : undefined };
    }
    match.result = { winnerTeam: end.winnerTeam, reason: end.reason, rewards };
    // Players who left during the match are let go now that it's over.
    for (const m of [...this.members.values()]) if (m.left) this.dropMember(m);
    // If nobody asks for a rematch, the table goes back to the lobby on its own.
    this.clearLobbyTimer();
    this.lobbyTimer = setTimeout(() => this.toLobby(), 90_000);
    this.checkRematch();
  }

  /** How a finished game is remembered in one player's history. */
  private record(match: Match, end: MatchEnd, seat: number, won: boolean, coins: number, at: number): GameRecord {
    const team = teamOf(seat);
    const who = (s: number): RecordPlayer | null => {
      const m = this.seatMember(s);
      if (!m) return null;
      if (m.bot) return { name: m.bot.name, bot: true };
      return { id: m.id, name: m.profile?.name ?? '' };
    };
    const boomsUs = end.stats.booms[team];
    const boomsThem = end.stats.booms[1 - team];
    return {
      at,
      won,
      reason: end.reason,
      score: [match.scores[team], match.scores[1 - team]],
      target: this.settings.targetScore,
      hands: end.stats.hands,
      kots: end.stats.kots[team] + end.stats.hakemKots[team],
      boom: boomsUs ? 'won' : boomsThem ? 'lost' : undefined,
      coins,
      partner: who(partnerOf(seat)),
      opponents: [who((seat + 1) % 4), who((seat + 3) % 4)].filter((x): x is RecordPlayer => !!x),
    };
  }

  private dropMember(m: Member) {
    if (m.seat !== null && this.seats[m.seat] === m.id) this.seats[m.seat] = null;
    this.members.delete(m.id);
  }

  voteRematch(id: string) {
    if (!this.match?.ended) return;
    const seat = this.seatOf(id);
    if (seat === null) return;
    if (this.rematch.has(id)) this.rematch.delete(id);
    else this.rematch.add(id);
    this.checkRematch();
    this.touch();
  }

  private checkRematch() {
    if (!this.match?.ended) return;
    if (this.seats.some((id) => !id)) return;
    const humans = this.seats.map((id) => this.members.get(id!)!).filter((m) => !m.bot);
    if (!humans.length || !humans.every((m) => this.rematch.has(m.id) || !m.socket)) return;
    if (!humans.some((m) => this.rematch.has(m.id))) return;
    this.beginMatch();
  }

  toLobby(requester?: string) {
    if (requester !== undefined && requester !== this.hostId) return;
    if (!this.match?.ended) return;
    this.clearLobbyTimer();
    this.match.dispose();
    this.match = null;
    this.rematch.clear();
    for (const [seat, id] of this.seats.entries()) if (id && !this.members.has(id)) this.seats[seat] = null;
    this.touch();
  }

  private clearLobbyTimer() {
    if (this.lobbyTimer) clearTimeout(this.lobbyTimer);
    this.lobbyTimer = null;
  }

  dispose() {
    this.match?.dispose();
    this.clearLobbyTimer();
    if (this.hostTimer) clearTimeout(this.hostTimer);
  }

  // ——— Game actions ———

  private seatFor(id: string): number | null {
    if (!this.inMatch) return null;
    return this.seatOf(id);
  }

  gameShuffle(id: string, kind: 'riffle' | 'cut') {
    const seat = this.seatFor(id);
    if (seat !== null) this.match!.shuffle(seat, kind);
  }

  gameShuffleDone(id: string) {
    const seat = this.seatFor(id);
    if (seat !== null) this.match!.shuffleDone(seat);
  }

  gameCut(id: string, count: number) {
    const seat = this.seatFor(id);
    if (seat !== null) this.match!.cut(seat, count);
  }

  gameCutDone(id: string) {
    const seat = this.seatFor(id);
    if (seat !== null) this.match!.cutDone(seat);
  }

  gameTrump(id: string, suit: string) {
    const seat = this.seatFor(id);
    if (seat !== null) this.match!.chooseTrump(seat, suit as never);
  }

  gamePlay(id: string, card: string, power: number): string | null {
    const seat = this.seatFor(id);
    if (seat === null) return 'not_seated';
    return this.match!.play(seat, card, power);
  }

  gameBack(id: string) {
    const seat = this.seatFor(id);
    if (seat !== null) this.match!.back(seat);
  }

  surrender(id: string): string | null {
    const seat = this.seatFor(id);
    if (seat === null) return 'not_seated';
    return this.match!.requestSurrender(seat);
  }

  surrenderVote(id: string, agree: boolean) {
    const seat = this.seatFor(id);
    if (seat !== null) this.match!.voteSurrender(seat, agree);
  }

  boom(id: string): string | null {
    const seat = this.seatFor(id);
    if (seat === null) return 'not_seated';
    return this.match!.callBoom(seat);
  }

  offerSwap(id: string, to: number): string | null {
    const seat = this.seatFor(id);
    if (seat === null) return 'not_seated';
    return this.match!.offerSwap(seat, to);
  }

  answerSwap(id: string, accept: boolean) {
    const seat = this.seatFor(id);
    if (seat !== null) this.match!.answerSwap(seat, accept);
  }

  // ——— Social ———

  /** At most 4 effects in any 5 seconds per player. */
  private fxAllowed(m: Member): boolean {
    const now = Date.now();
    m.fxTimes = m.fxTimes.filter((t) => now - t < 5000);
    if (m.fxTimes.length >= 4) return false;
    m.fxTimes.push(now);
    return true;
  }

  emote(id: string, emote: string) {
    const m = this.members.get(id);
    if (!m?.profile || typeof emote !== 'string') return;
    if (!emotesOwned(m.profile.owned).has(emote)) return;
    if (!this.fxAllowed(m)) return;
    this.fx({ type: 'emote', from: id, emote });
  }

  throwItem(id: string, to: string, item: string) {
    const m = this.members.get(id);
    if (!m?.profile || to === id || !this.members.has(to)) return;
    const it = getItem(item);
    if (!it || it.kind !== 'throwable' || !m.profile.owned.includes(item)) return;
    if (!this.fxAllowed(m)) return;
    this.fx({ type: 'throw', from: id, to, item });
  }

  say(id: string, text: string) {
    const m = this.members.get(id);
    if (!m?.profile || typeof text !== 'string') return;
    const clean = Array.from(text.replace(/[\u0000-\u001f\u007f‪-‮⁦-⁩]/g, ' ').trim())
      .slice(0, LIMITS.chatLength)
      .join('');
    if (!clean) return;
    const now = Date.now();
    if (now - m.lastChatAt < 600) return;
    m.lastChatAt = now;
    this.post({ id: ++this.chatSeq, from: id, text: clean, at: now });
  }

  /** A GIF the server has vetted (it came back from our own GIPHY search). */
  sayGif(id: string, gif: Gif): string | null {
    const m = this.members.get(id);
    if (!m?.profile) return 'no_room';
    const now = Date.now();
    if (now - m.lastChatAt < 1200) return 'slow_down';
    m.lastChatAt = now;
    this.post({ id: ++this.chatSeq, from: id, text: '', gif, at: now });
    return null;
  }

  private post(message: ChatMessage) {
    this.chat.push(message);
    if (this.chat.length > LIMITS.chatHistory) this.chat.shift();
    this.fx({ type: 'chat', message });
  }

  // ——— Voice ———

  voiceJoin(id: string) {
    const m = this.members.get(id);
    if (!m?.socket) return;
    m.inVoice = true;
    this.touch();
  }

  voiceLeave(id: string) {
    const m = this.members.get(id);
    if (!m) return;
    m.inVoice = false;
    m.micOn = false;
    this.touch();
  }

  voiceMic(id: string, on: boolean) {
    const m = this.members.get(id);
    if (!m?.inVoice) return;
    m.micOn = !!on;
    this.touch();
  }

  /** Relays WebRTC negotiation between two people who are both in voice. */
  voiceSignal(from: string, to: string, data: unknown) {
    const a = this.members.get(from);
    const b = this.members.get(to);
    if (!a?.inVoice || !b?.inVoice || !b.socket) return;
    b.socket.emit('voice:signal', { from, data });
  }

  // ——— Broadcasting ———

  touch() {
    this.stateDirty = true;
    this.queueFlush();
  }

  private fx(event: FxEvent) {
    this.fxQueue.push(event);
    this.queueFlush();
  }

  private queueFlush() {
    if (this.flushQueued) return;
    this.flushQueued = true;
    setImmediate(() => this.flush());
  }

  /** State goes out before effects, so a slam always finds its card on the table. */
  private flush() {
    this.flushQueued = false;
    if (this.stateDirty) {
      this.stateDirty = false;
      for (const m of this.members.values()) if (m.socket) m.socket.emit('room', this.viewFor(m.id));
    }
    const events = this.fxQueue;
    this.fxQueue = [];
    for (const e of events) for (const m of this.members.values()) if (m.socket) m.socket.emit('fx', e);
  }

  viewFor(id: string): RoomView {
    const members: MemberView[] = [...this.members.values()].map((m) => ({
      id: m.id,
      profile: m.bot ?? publicProfile(m.profile!),
      seat: m.seat,
      online: !!m.bot || (!!m.socket && !m.left),
      auto: m.seat !== null && this.inMatch && (this.control(m.seat) !== 'human' || this.match!.away.has(m.seat)) && !m.bot,
      inVoice: m.inVoice,
      micOn: m.micOn,
    }));
    const seat = this.seatOf(id);
    return {
      code: this.code,
      hostId: this.hostId,
      settings: { ...this.settings },
      members,
      seats: this.seats.slice(),
      game: this.match ? this.match.viewFor(seat) : null,
      you: id,
      chat: this.chat.slice(-20),
      rematch: [...this.rematch],
      serverNow: Date.now(),
    };
  }
}
