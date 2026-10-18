import { botAcceptsSwap, botChooseTrump, botPlay } from '../shared/bot';
import { type Card, type Suit, isCard, isSuit, newDeck, rankOf, suitOf } from '../shared/cards';
import { SLAM, T, dealDuration } from '../shared/constants';
import type { DeckOp, GameView, MatchResultView, Phase, RoomSettings } from '../shared/protocol';
import {
  HAND_SIZE,
  type HandOutcome,
  POINTS_HAND,
  type Play,
  TRICKS_TO_WIN_HAND,
  beats,
  chooseFirstHakem,
  cutterFor,
  dealHands,
  gatherDeck,
  handOutcome,
  isLegalPlay,
  legalPlays,
  nextHakem,
  nextSeat,
  partnerOf,
  teamOf,
  trickWinner,
} from '../shared/rules';
import { type Rng, casualCutCount, cutDeck, fisherYates, randomInt, riffle } from '../shared/shuffle';

// One match: hands are played until a team reaches the target score or
// surrenders. The server paces everything — deal animations, the pause on
// a finished trick, the summary between hands — so every phone at the
// table sees the same moment, and a phone that reconnects lands in it.

export type Control = 'human' | 'bot' | 'offline';

export interface MatchStats {
  hands: number;
  handsWon: [number, number];
  kots: [number, number];
  hakemKots: [number, number];
  timesHakem: number[];
  slams: number[];
  /** Booms each team called, and the ones that came off. */
  boomsCalled: [number, number];
  booms: [number, number];
  /** Hands each seat traded away. */
  swaps: number[];
}

export interface MatchEnd {
  winnerTeam: number;
  reason: 'score' | 'surrender' | 'boom';
  surrenderTeam: number | null;
  stats: MatchStats;
}

export interface MatchHooks {
  /** Who is driving a seat right now. */
  control(seat: number): Control;
  changed(): void;
  slam(seat: number, power: number, card: Card): void;
  emote(seat: number, emote: string): void;
  toast(key: string, params?: Record<string, string | number>): void;
  /** Someone called Boom. */
  boom(seat: number): void;
  /** A swap offer was answered (or ran out, which counts as a no). */
  swapped(from: number, to: number, accepted: boolean): void;
  ended(end: MatchEnd): void;
}

type Actor = Control | 'away';

function guard(fn: () => void) {
  try {
    fn();
  } catch (err) {
    console.error('Match timer failed:', err);
  }
}

export class Match {
  phase: Phase = 'hakemSelect';
  phaseStartedAt = Date.now();
  deadline: number | null = null;
  deadlineFrom: number | null = null;
  handNumber = 0;
  scores: [number, number] = [0, 0];
  hakem: number | null = null;
  trump: Suit | null = null;
  hands: Card[][] = [[], [], [], []];
  trick: Play[] = [];
  trickSlams: Record<string, number> = {};
  tricks: Play[][] = [];
  tricksWon: [number, number] = [0, 0];
  turn: number | null = null;
  trickWinnerSeat: number | null = null;
  lastTrick: { plays: Play[]; winner: number } | null = null;
  hakemReveals: Play[] = [];
  handResult: GameView['handResult'] = null;
  surrender: { team: number; by: number; expires: number } | null = null;
  boom: { team: number; by: number } | null = null;
  swapOffer: { from: number; to: number; expires: number } | null = null;
  readonly swapsUsed = new Set<number>();
  result: MatchResultView | null = null;
  ended: MatchEnd | null = null;
  readonly away = new Set<number>();
  readonly stats: MatchStats = {
    hands: 0,
    handsWon: [0, 0],
    kots: [0, 0],
    hakemKots: [0, 0],
    timesHakem: [0, 0, 0, 0],
    slams: [0, 0, 0, 0],
    boomsCalled: [0, 0],
    booms: [0, 0],
    swaps: [0, 0, 0, 0],
  };

  private deck: Card[] = [];
  private ops = { shuffles: 0, cuts: 0, last: null as DeckOp | null, seq: 0 };
  private lastOpAt = 0;
  private missed = [0, 0, 0, 0];
  private surrenderCooldown = [0, 0];
  private actorDeadline: number | null = null;
  private actorFrom: number | null = null;
  private timer: NodeJS.Timeout | null = null;
  private pending: (() => void) | null = null;
  private surrenderTimer: NodeJS.Timeout | null = null;
  private swapTimer: NodeJS.Timeout | null = null;
  private paused = false;

  constructor(
    private readonly settings: RoomSettings,
    private readonly hooks: MatchHooks,
    private readonly rng: Rng,
    private readonly timeScale = 1,
  ) {}

  start() {
    const deck = fisherYates(newDeck(), this.rng);
    const { reveals, hakem } = chooseFirstHakem(deck, randomInt(this.rng, 0, 3));
    this.hakemReveals = reveals;
    this.setPhase('hakemSelect');
    this.hooks.changed();
    this.after(reveals.length * T.hakemRevealStep + T.hakemRevealHold, () => {
      this.hakem = hakem;
      this.hakemReveals = [];
      // The first hand is dealt from a well-used deck, not a new one sorted by suit.
      this.deck = fisherYates(newDeck(), this.rng);
      this.beginHand();
    });
  }

  dispose() {
    this.clearTimer();
    this.clearSurrender();
    this.clearSwapTimer();
  }

  // ——— Timing ———

  private ms(value: number) {
    return Math.round(value * this.timeScale);
  }

  private after(delay: number, fn: () => void) {
    this.clearTimer();
    this.pending = fn;
    this.timer = setTimeout(() => {
      this.timer = null;
      this.pending = null;
      guard(fn);
    }, this.ms(delay));
  }

  private clearTimer() {
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
    this.pending = null;
  }

  private setPhase(phase: Phase) {
    this.phase = phase;
    this.phaseStartedAt = Date.now();
    this.deadline = null;
    this.deadlineFrom = null;
  }

  /** The seat the table is waiting on, if any. */
  actor(): number | null {
    if (this.hakem === null) return null;
    switch (this.phase) {
      case 'shuffle':
      case 'trump':
        return this.hakem;
      case 'cut':
        return cutterFor(this.hakem);
      case 'play':
        return this.turn;
      default:
        return null;
    }
  }

  private controlOf(seat: number): Actor {
    const control = this.hooks.control(seat);
    if (control === 'human' && this.away.has(seat)) return 'away';
    return control;
  }

  /** Starts the clock on whoever must act next. */
  private startActor(limit: number | null) {
    this.actorFrom = Date.now();
    this.actorDeadline = limit ? this.actorFrom + this.ms(limit) : null;
    this.armActor();
    this.hooks.changed();
  }

  private armActor() {
    if (this.paused || this.ended) return;
    const seat = this.actor();
    if (seat === null) return;
    if (this.swapOffer) {
      // The table waits for the answer; the clock starts afresh after it.
      this.clearTimer();
      this.deadline = null;
      this.deadlineFrom = null;
      return;
    }
    const control = this.controlOf(seat);
    const now = Date.now();
    let delay: number | null;
    if (control === 'bot') {
      delay = this.ms(randomInt(this.rng, T.botMin, T.botMax));
      this.deadline = null;
      this.deadlineFrom = null;
    } else if (control === 'away') {
      delay = this.ms(T.awayPlay);
      this.deadline = now + delay;
      this.deadlineFrom = now;
    } else if (control === 'offline') {
      delay = Math.min(this.ms(T.offlineGrace), this.actorDeadline ? this.actorDeadline - now : Infinity);
      this.deadline = now + delay;
      this.deadlineFrom = now;
    } else {
      delay = this.actorDeadline ? this.actorDeadline - now : null;
      this.deadline = this.actorDeadline;
      this.deadlineFrom = this.actorFrom;
    }
    this.clearTimer();
    if (delay === null) return;
    // Raw setTimeout: the delay is already scaled.
    this.timer = setTimeout(
      () => {
        this.timer = null;
        guard(() => this.autoAct(seat, control));
      },
      Math.max(0, delay),
    );
  }

  /** Makes the move for a bot, or for a player who ran out of time or isn't there. */
  private autoAct(seat: number, control: Actor) {
    if (this.actor() !== seat || this.ended) return;
    const idleHuman = control === 'human';
    switch (this.phase) {
      case 'shuffle': {
        if (idleHuman && this.ops.shuffles === 0) this.missTurn(seat);
        const riffles = control === 'bot' ? randomInt(this.rng, 3, 6) : Math.max(0, 3 - this.ops.shuffles);
        return this.autoShuffle(seat, riffles);
      }
      case 'cut': {
        if (this.ops.cuts > 0) return this.deal();
        if (idleHuman) this.missTurn(seat);
        this.applyCut(casualCutCount(52, this.rng));
        this.hooks.changed();
        this.after(T.cutAnim + 450, () => this.deal());
        return;
      }
      case 'trump':
        if (idleHuman) this.missTurn(seat);
        return this.applyTrump(botChooseTrump(this.hands[seat].slice(0, 5)));
      case 'play': {
        if (idleHuman) this.missTurn(seat);
        const card = botPlay({
          seat,
          hand: this.hands[seat],
          trump: this.trump,
          hakem: this.hakem!,
          trick: this.trick,
          tricks: this.tricks,
        });
        return this.applyPlay(seat, card, control === 'bot' ? this.botSlam(card) : 0);
      }
      default:
    }
  }

  private missTurn(seat: number) {
    this.missed[seat] += 1;
    if (this.missed[seat] >= 2 && !this.away.has(seat)) {
      this.away.add(seat);
      this.hooks.changed();
    }
  }

  /** A player did something themselves: they're here. */
  private present(seat: number) {
    this.missed[seat] = 0;
    if (this.away.delete(seat)) this.hooks.changed();
  }

  /** Bots occasionally slam a card that takes the trick. */
  private botSlam(card: Card): number {
    if (!this.trick.length) return 0;
    const winning = this.trick.find((p) => p.seat === trickWinner(this.trick, this.trump))!.card;
    const takes = beats(card, winning, this.trump);
    if (takes && (rankOf(card) === 14 || suitOf(card) === this.trump) && this.rng() < 0.18) return 0.35 + this.rng() * 0.5;
    return 0;
  }

  // ——— Presence ———

  /** A seat came online, went offline or was handed to a bot: re-time whoever we're waiting on. */
  presenceChanged() {
    if (this.paused || this.ended) return;
    const seat = this.actor();
    if (seat === null) return;
    if (this.phase === 'shuffle' && this.hooks.control(seat) === 'bot') return; // a bot shuffle in progress keeps going
    this.armActor();
    this.hooks.changed();
  }

  /** Nobody is watching: stop the clock rather than play the match out to an empty room. */
  pause() {
    if (this.paused || this.ended) return;
    this.paused = true;
    const pending = this.pending;
    this.clearTimer();
    this.pending = pending;
  }

  resume() {
    if (!this.paused || this.ended) return;
    this.paused = false;
    const pending = this.pending;
    if (this.actor() !== null) {
      const limit = this.phase === 'play' ? this.turnLimit() : this.phase === 'trump' ? T.trumpPhase : this.phase === 'cut' ? T.cutPhase : T.shufflePhase;
      this.startActor(limit);
    } else if (pending) {
      this.after(400, pending);
    }
  }

  // ——— Shuffle and cut ———

  private beginHand() {
    this.handNumber += 1;
    this.trump = null;
    this.hands = [[], [], [], []];
    this.trick = [];
    this.trickSlams = {};
    this.tricks = [];
    this.tricksWon = [0, 0];
    this.turn = null;
    this.trickWinnerSeat = null;
    this.lastTrick = null;
    this.handResult = null;
    this.boom = null;
    this.swapOffer = null;
    this.swapsUsed.clear();
    this.clearSwapTimer();
    this.ops = { shuffles: 0, cuts: 0, last: null, seq: this.ops.seq };
    if (this.settings.shuffleMode === 'random') this.deck = fisherYates(this.deck, this.rng);
    this.stats.timesHakem[this.hakem!] += 1;
    this.setPhase('shuffle');
    this.startActor(T.shufflePhase);
  }

  shuffle(seat: number, kind: 'riffle' | 'cut') {
    if (this.phase !== 'shuffle' || seat !== this.hakem || this.paused) return;
    if (kind !== 'riffle' && kind !== 'cut') return;
    if (Date.now() - this.lastOpAt < this.ms(T.shuffleOp) - 60) return;
    this.present(seat);
    this.applyShuffle(kind);
    this.hooks.changed();
  }

  shuffleDone(seat: number) {
    if (this.phase !== 'shuffle' || seat !== this.hakem || this.paused) return;
    this.present(seat);
    this.toCut();
  }

  private applyShuffle(kind: 'riffle' | 'cut') {
    let count: number | undefined;
    if (kind === 'riffle') this.deck = riffle(this.deck, this.rng);
    else {
      count = casualCutCount(this.deck.length, this.rng);
      this.deck = cutDeck(this.deck, count);
    }
    this.ops.shuffles += 1;
    this.ops.last = { kind, count, of: this.deck.length, seq: ++this.ops.seq };
    this.lastOpAt = Date.now();
  }

  /** Plays a shuffle out move by move so everyone sees it, then passes the deck to be cut. */
  private autoShuffle(seat: number, moves: number) {
    const step = (left: number) => {
      if (this.phase !== 'shuffle' || this.actor() !== seat || this.ended) return;
      if (left <= 0) return this.toCut();
      this.applyShuffle(left === 2 && this.rng() < 0.4 ? 'cut' : 'riffle');
      this.hooks.changed();
      this.after(T.shuffleOp + 120, () => step(left - 1));
    };
    step(moves);
  }

  private toCut() {
    this.setPhase('cut');
    this.startActor(T.cutPhase);
  }

  cut(seat: number, count: number) {
    if (this.phase !== 'cut' || seat !== this.actor() || this.paused) return;
    if (!Number.isFinite(count)) return;
    if (Date.now() - this.lastOpAt < this.ms(T.cutAnim) - 60) return;
    this.present(seat);
    this.applyCut(count);
    // Deal by itself shortly unless the cutter wants another go.
    this.actorFrom = Date.now();
    this.actorDeadline = this.actorFrom + this.ms(T.cutLinger);
    this.armActor();
    this.hooks.changed();
  }

  cutDone(seat: number) {
    if (this.phase !== 'cut' || seat !== this.actor() || this.ops.cuts === 0 || this.paused) return;
    this.present(seat);
    this.deal();
  }

  private applyCut(count: number) {
    const k = Math.min(51, Math.max(1, Math.round(count)));
    this.deck = cutDeck(this.deck, k);
    this.ops.cuts += 1;
    this.ops.last = { kind: 'cut', count: k, of: 52, seq: ++this.ops.seq };
    this.lastOpAt = Date.now();
  }

  // ——— Deal and trump ———

  private deal() {
    if (this.phase !== 'cut') return;
    this.hands = dealHands(this.deck, this.hakem!);
    this.deck = [];
    this.setPhase('deal1');
    this.hooks.changed();
    this.after(dealDuration(1), () => {
      this.setPhase('trump');
      this.startActor(T.trumpPhase);
    });
  }

  chooseTrump(seat: number, suit: Suit) {
    if (this.phase !== 'trump' || seat !== this.hakem || !isSuit(suit) || this.paused) return;
    this.present(seat);
    this.applyTrump(suit);
  }

  private applyTrump(suit: Suit) {
    this.trump = suit;
    this.setPhase('deal2');
    this.hooks.changed();
    this.after(dealDuration(2), () => {
      this.setPhase('play');
      this.turn = this.hakem;
      this.startActor(this.turnLimit());
    });
  }

  private turnLimit(): number | null {
    return this.settings.turnTime > 0 ? this.settings.turnTime * 1000 : null;
  }

  // ——— Play ———

  play(seat: number, card: Card, power: number): string | null {
    if (this.paused) return 'paused';
    if (this.phase !== 'play') return 'not_now';
    if (seat !== this.turn) return 'not_your_turn';
    if (this.swapOffer) return 'swap_pending';
    if (!isCard(card) || !isLegalPlay(this.hands[seat], this.trick, card)) return 'illegal';
    this.present(seat);
    this.applyPlay(seat, card, Number.isFinite(power) ? power : 0);
    return null;
  }

  private applyPlay(seat: number, card: Card, power: number) {
    this.hands[seat] = this.hands[seat].filter((c) => c !== card);
    this.trick.push({ seat, card });
    const p = Math.max(0, Math.min(1, power));
    if (p >= SLAM.threshold) {
      this.stats.slams[seat] += 1;
      this.trickSlams[card] = Math.round(p * 100) / 100;
      this.hooks.slam(seat, p, card);
    }
    if (this.trick.length < 4) {
      this.turn = nextSeat(seat);
      this.startActor(this.turnLimit());
      return;
    }
    const winner = trickWinner(this.trick, this.trump);
    this.trickWinnerSeat = winner;
    this.tricksWon[teamOf(winner)] += 1;
    this.turn = null;
    this.setPhase('trickEnd');
    this.hooks.changed();
    this.after(T.trickEnd, () => {
      this.tricks.push(this.trick);
      this.lastTrick = { plays: this.trick, winner };
      this.trick = [];
      this.trickSlams = {};
      this.trickWinnerSeat = null;
      if (this.boom) {
        // A Boom plays on past seven: it ends at the first trick lost, or at thirteen.
        if (teamOf(winner) !== this.boom.team) return this.endHand(false);
        if (this.tricksWon[this.boom.team] >= HAND_SIZE) return this.endHand(true);
      } else if (this.tricksWon[teamOf(winner)] >= TRICKS_TO_WIN_HAND) return this.endHand();
      this.setPhase('play');
      this.turn = winner;
      this.startActor(this.turnLimit());
    });
  }

  /** `boomWon` is set when the hand ends a Boom: true if the callers took all thirteen. */
  private endHand(boomWon?: boolean) {
    const hakem = this.hakem!;
    const boom = this.boom && boomWon !== undefined ? { ...this.boom, won: boomWon } : undefined;
    let outcome: HandOutcome;
    if (boom) {
      // A Boom that comes off takes the whole game; one that fails just loses the hand.
      const winnerTeam = boom.won ? boom.team : 1 - boom.team;
      const points = boom.won ? Math.max(1, this.settings.targetScore - this.scores[winnerTeam]) : POINTS_HAND;
      outcome = { winnerTeam, points, kot: false, hakemKot: false };
      if (boom.won) this.stats.booms[boom.team] += 1;
    } else {
      outcome = handOutcome(this.tricksWon, teamOf(hakem))!;
    }
    this.scores[outcome.winnerTeam] += outcome.points;
    this.stats.hands += 1;
    this.stats.handsWon[outcome.winnerTeam] += 1;
    if (outcome.hakemKot) this.stats.hakemKots[outcome.winnerTeam] += 1;
    else if (outcome.kot) this.stats.kots[outcome.winnerTeam] += 1;
    const next = nextHakem(hakem, outcome.winnerTeam);
    this.handResult = { ...outcome, tricks: [this.tricksWon[0], this.tricksWon[1]], nextHakem: next, hakem, boom };
    this.deck = gatherDeck(this.tricks, this.hands);
    this.hands = [[], [], [], []];
    this.setPhase('handEnd');
    this.hooks.changed();
    if (outcome.kot || boom) this.botsReact(outcome.winnerTeam);
    const over = this.scores[outcome.winnerTeam] >= this.settings.targetScore;
    this.after(T.handEnd, () => {
      if (over) return this.finish(outcome.winnerTeam, boom?.won ? 'boom' : 'score', null);
      this.hakem = next;
      this.beginHand();
    });
  }

  private botsReact(winnerTeam: number) {
    for (let seat = 0; seat < 4; seat++) {
      if (this.hooks.control(seat) !== 'bot' || this.rng() > 0.55) continue;
      const won = teamOf(seat) === winnerTeam;
      const pool = won ? ['😎', 'p_kot', '🔥', 'p_again'] : ['😭', '😱', 'p_luck'];
      const emote = pool[Math.floor(this.rng() * pool.length)];
      setTimeout(() => this.hooks.emote(seat, emote), 400 + seat * 350);
    }
  }

  private finish(winnerTeam: number, reason: MatchEnd['reason'], surrenderTeam: number | null) {
    this.clearTimer();
    this.clearSurrender();
    this.clearSwapTimer();
    this.surrender = null;
    this.swapOffer = null;
    this.turn = null;
    this.ended = { winnerTeam, reason, surrenderTeam, stats: this.stats };
    this.setPhase('matchEnd');
    this.hooks.ended(this.ended);
    this.hooks.changed();
  }

  // ——— Boom ———

  /**
   * Calls Boom for the caller's team: they must take all thirteen tricks.
   * It can be called from the moment play starts until the first trick is
   * taken, once a hand.
   */
  callBoom(seat: number): string | null {
    if (this.settings.booms === false) return 'boom_off';
    if (this.ended || this.paused) return 'not_now';
    if (this.boom) return 'boom_taken';
    if (this.phase !== 'play' || this.tricks.length > 0) return 'boom_late';
    this.present(seat);
    const team = teamOf(seat);
    this.boom = { team, by: seat };
    this.stats.boomsCalled[team] += 1;
    this.hooks.boom(seat);
    this.hooks.changed();
    return null;
  }

  // ——— Swapping hands ———

  /**
   * Offers your whole hand to an opponent for theirs. Only between tricks,
   * so both hands hold the same number of cards, and once a hand per
   * player. The clock stops until they answer.
   */
  offerSwap(seat: number, to: number): string | null {
    if (this.settings.swaps === false) return 'swap_off';
    if (this.ended || this.paused) return 'not_now';
    if (!Number.isInteger(to) || to < 0 || to > 3 || teamOf(to) === teamOf(seat)) return 'swap_target';
    if (this.swapOffer) return 'swap_pending';
    if (this.swapsUsed.has(seat)) return 'swap_used';
    if (this.phase !== 'play' || this.trick.length > 0 || this.hands[seat].length !== this.hands[to].length) return 'swap_between';
    this.present(seat);
    this.swapsUsed.add(seat);
    const expires = Date.now() + this.ms(T.swapOffer);
    this.swapOffer = { from: seat, to, expires };
    this.armActor();
    const control = this.controlOf(to);
    const answerIn = control === 'human' ? expires - Date.now() : this.ms(randomInt(this.rng, 1400, 2800));
    const answer = control === 'bot' && botAcceptsSwap(this.hands[to], this.trump, this.rng);
    this.swapTimer = setTimeout(() => {
      this.swapTimer = null;
      guard(() => this.resolveSwap(answer));
    }, answerIn);
    this.hooks.changed();
    return null;
  }

  answerSwap(seat: number, accept: boolean) {
    if (!this.swapOffer || this.swapOffer.to !== seat || this.ended) return;
    this.present(seat);
    this.resolveSwap(accept);
  }

  private resolveSwap(accept: boolean) {
    const offer = this.swapOffer;
    if (!offer) return;
    this.clearSwapTimer();
    this.swapOffer = null;
    const ok = accept && this.phase === 'play' && this.trick.length === 0;
    if (ok) {
      [this.hands[offer.from], this.hands[offer.to]] = [this.hands[offer.to], this.hands[offer.from]];
      this.stats.swaps[offer.from] += 1;
      this.stats.swaps[offer.to] += 1;
    }
    this.hooks.swapped(offer.from, offer.to, ok);
    if (this.phase === 'play') this.startActor(this.turnLimit());
    else this.hooks.changed();
  }

  private clearSwapTimer() {
    if (this.swapTimer) clearTimeout(this.swapTimer);
    this.swapTimer = null;
  }

  // ——— Surrender ———

  requestSurrender(seat: number): string | null {
    if (this.ended) return 'over';
    const team = teamOf(seat);
    if (this.surrender) return 'pending';
    if (Date.now() < this.surrenderCooldown[team]) return 'cooldown';
    const partner = partnerOf(seat);
    // A bot, absent or away partner goes along with it.
    if (this.controlOf(partner) !== 'human') {
      this.finish(1 - team, 'surrender', team);
      return null;
    }
    const expires = Date.now() + this.ms(T.surrenderVote);
    this.surrender = { team, by: seat, expires };
    this.surrenderTimer = setTimeout(() => this.cancelSurrender('surrender_timeout'), expires - Date.now());
    this.hooks.changed();
    return null;
  }

  voteSurrender(seat: number, agree: boolean) {
    const s = this.surrender;
    if (!s || this.ended || teamOf(seat) !== s.team || seat === s.by) return;
    if (agree) this.finish(1 - s.team, 'surrender', s.team);
    else this.cancelSurrender('surrender_declined');
  }

  private cancelSurrender(key: string) {
    const s = this.surrender;
    if (!s) return;
    this.clearSurrender();
    this.surrender = null;
    this.surrenderCooldown[s.team] = Date.now() + this.ms(T.surrenderCooldown);
    this.hooks.toast(key, { team: s.team });
    this.hooks.changed();
  }

  private clearSurrender() {
    if (this.surrenderTimer) clearTimeout(this.surrenderTimer);
    this.surrenderTimer = null;
  }

  /** "I'm back": the player takes their seat over from the autopilot. */
  back(seat: number) {
    this.present(seat);
    if (this.actor() === seat) this.armActor();
    this.hooks.changed();
  }

  // ——— Views ———

  viewFor(seat: number | null): GameView {
    const inPacketOne = this.phase === 'deal1' || this.phase === 'trump';
    const handOf = (s: number) => (inPacketOne ? this.hands[s].slice(0, 5) : this.hands[s]);
    const hand = seat === null ? [] : handOf(seat);
    return {
      phase: this.phase,
      phaseStartedAt: this.phaseStartedAt,
      deadline: this.deadline,
      deadlineFrom: this.deadlineFrom,
      handNumber: this.handNumber,
      scores: [this.scores[0], this.scores[1]],
      targetScore: this.settings.targetScore,
      hakem: this.hakem,
      cutter: this.hakem === null ? null : cutterFor(this.hakem),
      trump: this.trump,
      turn: this.turn,
      trick: this.trick.slice(),
      trickSlams: { ...this.trickSlams },
      tricksWon: [this.tricksWon[0], this.tricksWon[1]],
      handCounts: [0, 1, 2, 3].map((s) => handOf(s).length),
      hand: hand.slice(),
      legal: seat !== null && this.phase === 'play' && this.turn === seat ? legalPlays(this.hands[seat], this.trick) : [],
      hakemReveals: this.hakemReveals.slice(),
      deckOps: { shuffles: this.ops.shuffles, cuts: this.ops.cuts, last: this.ops.last },
      dealer: this.hakem,
      lastTrick: this.lastTrick,
      trickWinner: this.trickWinnerSeat,
      handResult: this.handResult,
      matchResult: this.result,
      surrender: this.surrender,
      boom: this.boom,
      swapOffer: this.swapOffer,
      swapsUsed: [...this.swapsUsed],
      away: [...this.away],
    };
  }
}
