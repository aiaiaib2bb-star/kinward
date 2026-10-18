import { type Card, SUITS, type Suit, newDeck, rankOf, suitOf } from './cards';
import { type Play, beats, legalPlays, nextSeat, partnerOf, teamOf, trickWinner } from './rules';

// A sensible, unflashy Hokm player. It only uses what a person at the table
// could know: its own cards, every card played so far this hand, and which
// suits each player has shown out of. It plays for fill-in seats and for
// anyone who is away from their phone when their turn comes up.

export interface BotView {
  seat: number;
  hand: readonly Card[];
  trump: Suit | null;
  hakem: number;
  /** The trick in progress. */
  trick: readonly Play[];
  /** Completed tricks this hand, oldest first. */
  tricks: readonly (readonly Play[])[];
}

const HIGH_CARD_WEIGHT: Record<number, number> = { 14: 4, 13: 3, 12: 2, 11: 1.5, 10: 1 };

/** The hakem's trump call from their first five cards: length first, then honours. */
export function botChooseTrump(firstFive: readonly Card[]): Suit {
  let best: Suit = suitOf(firstFive[0]);
  let bestScore = -Infinity;
  for (const suit of SUITS) {
    const cards = firstFive.filter((c) => suitOf(c) === suit);
    if (!cards.length) continue;
    const score = cards.length * 3 + cards.reduce((sum, c) => sum + (HIGH_CARD_WEIGHT[rankOf(c)] ?? 0), 0);
    if (score > bestScore) {
      bestScore = score;
      best = suit;
    }
  }
  return best;
}

/**
 * How good a hand looks before a card is played: trumps count for their
 * length and honours, side suits for their aces and guarded kings.
 */
export function handStrength(hand: readonly Card[], trump: Suit | null): number {
  let score = 0;
  for (const card of hand) {
    const rank = rankOf(card);
    const suit = suitOf(card);
    if (suit === trump) score += 1.5 + (HIGH_CARD_WEIGHT[rank] ?? 0);
    else if (rank === 14) score += 3;
    else if (rank === 13 && hand.filter((c) => suitOf(c) === suit).length >= 2) score += 1.5;
    else if (rank === 12) score += 0.5;
  }
  return score;
}

/** About what a random hand of this size scores, by the measure above. */
function typicalStrength(size: number): number {
  return (11.5 * size) / 13;
}

/**
 * A bot asked to trade hands blind: it can only judge its own cards. It
 * takes the gamble when its hand is poor and usually turns down a good one.
 */
export function botAcceptsSwap(hand: readonly Card[], trump: Suit | null, rng: () => number): boolean {
  const k = handStrength(hand, trump) / typicalStrength(hand.length || 1);
  const chance = k < 0.7 ? 0.85 : k < 1 ? 0.4 : k < 1.3 ? 0.1 : 0.02;
  return rng() < chance;
}

class Knowledge {
  readonly unseen: Set<Card>;
  /** voids[seat] holds the suits that seat has shown out of. */
  readonly voids: Set<Suit>[] = [new Set(), new Set(), new Set(), new Set()];

  constructor(readonly view: BotView) {
    const seen = new Set<Card>(view.hand);
    const allTricks = [...view.tricks, view.trick];
    for (const trick of allTricks) {
      if (!trick.length) continue;
      const led = suitOf(trick[0].card);
      for (const play of trick) {
        seen.add(play.card);
        if (suitOf(play.card) !== led) this.voids[play.seat].add(led);
      }
    }
    this.unseen = new Set(newDeck().filter((c) => !seen.has(c)));
  }

  unseenOf(suit: Suit): Card[] {
    return [...this.unseen].filter((c) => suitOf(c) === suit);
  }

  /** No card still out there in this suit outranks it. */
  isMaster(card: Card): boolean {
    const rank = rankOf(card);
    return !this.unseenOf(suitOf(card)).some((c) => rankOf(c) > rank);
  }

  /** Could `seat`, playing later in this trick, take it from `card`? Judged on known voids only. */
  couldBeat(seat: number, card: Card, led: Suit): boolean {
    const { trump } = this.view;
    const suit = suitOf(card);
    const voids = this.voids[seat];
    const higherOut = this.unseenOf(suit).some((c) => rankOf(c) > rankOf(card));
    const trumpsOut = trump !== null && this.unseenOf(trump).length > 0 && !voids.has(trump);
    if (trump !== null && suit === trump) {
      // A trump on a non-trump lead can only be over-trumped by someone out of the led suit.
      if (led !== trump) return higherOut && trumpsOut && voids.has(led);
      return higherOut && !voids.has(trump);
    }
    const canFollowHigher = higherOut && !voids.has(suit);
    const canRuff = trumpsOut && voids.has(suit);
    return canFollowHigher || canRuff;
  }
}

const byRankAsc = (a: Card, b: Card) => rankOf(a) - rankOf(b);
const lowest = (cards: readonly Card[]): Card => [...cards].sort(byRankAsc)[0];
const highest = (cards: readonly Card[]): Card => [...cards].sort(byRankAsc)[cards.length - 1];

export function botPlay(view: BotView): Card {
  const legal = legalPlays(view.hand, view.trick);
  if (legal.length === 1) return legal[0];
  const k = new Knowledge(view);
  return view.trick.length === 0 ? chooseLead(k) : chooseFollow(k, legal);
}

function opponentsOf(seat: number): number[] {
  return [nextSeat(seat), nextSeat(nextSeat(nextSeat(seat)))];
}

function chooseLead(k: Knowledge): Card {
  const { seat, hand, trump, hakem } = k.view;
  const partner = partnerOf(seat);
  const opponents = opponentsOf(seat);
  const trumps = hand.filter((c) => suitOf(c) === trump);
  const side = hand.filter((c) => suitOf(c) !== trump);
  const trumpsOut = trump !== null && k.unseenOf(trump).length > 0;
  const opponentsHoldTrump = trumpsOut && opponents.some((o) => !k.voids[o].has(trump!));

  // Pull the opponents' trumps while holding the top one and some length behind it.
  if (trump && opponentsHoldTrump) {
    const master = trumps.find((c) => k.isMaster(c));
    const onHakemTeam = teamOf(seat) === teamOf(hakem);
    if (master && (trumps.length >= 3 || (onHakemTeam && trumps.length >= 2))) return master;
  }

  const ruffRisk = (suit: Suit) => opponentsHoldTrump && opponents.some((o) => k.voids[o].has(suit) && !k.voids[o].has(trump!));

  // Cash a sure winner in a side suit nobody can trump.
  const masters = side.filter((c) => k.isMaster(c) && !ruffRisk(suitOf(c))).sort(byRankAsc);
  if (masters.length) return masters[masters.length - 1];

  // Give partner a ruff: lead a suit they're out of, if they may still hold trump.
  if (trump && trumpsOut && !k.voids[partner].has(trump)) {
    for (const suit of k.voids[partner]) {
      if (suit === trump || ruffRisk(suit)) continue;
      const cards = side.filter((c) => suitOf(c) === suit);
      if (cards.length) return lowest(cards);
    }
  }

  // Otherwise lead low from the longest suit the opponents can't ruff.
  const suits = [...new Set(side.map(suitOf))];
  if (suits.length) {
    suits.sort((a, b) => {
      const risk = Number(ruffRisk(a)) - Number(ruffRisk(b));
      if (risk) return risk;
      return side.filter((c) => suitOf(c) === b).length - side.filter((c) => suitOf(c) === a).length;
    });
    return lowest(side.filter((c) => suitOf(c) === suits[0]));
  }

  // Only trumps left.
  const master = trumps.find((c) => k.isMaster(c));
  return master ?? lowest(trumps);
}

function chooseFollow(k: Knowledge, legal: Card[]): Card {
  const { seat, hand, trump, trick } = k.view;
  const led = suitOf(trick[0].card);
  const winnerSeat = trickWinner(trick, trump);
  const winningCard = trick.find((p) => p.seat === winnerSeat)!.card;
  const partnerWinning = teamOf(winnerSeat) === teamOf(seat);
  const later: number[] = [];
  for (let s = nextSeat(seat), i = trick.length + 1; i < 4; i++, s = nextSeat(s)) later.push(s);
  const laterOpponents = later.filter((s) => teamOf(s) !== teamOf(seat));
  const holds = (card: Card) => !laterOpponents.some((o) => k.couldBeat(o, card, led));

  const following = suitOf(legal[0]) === led;
  if (following) {
    if (partnerWinning) {
      if (holds(winningCard)) return lowest(legal);
      const secure = legal.filter((c) => beats(c, winningCard, trump) && holds(c));
      return secure.length ? lowest(secure) : lowest(legal);
    }
    const winners = legal.filter((c) => beats(c, winningCard, trump));
    if (!winners.length) return lowest(legal);
    if (!laterOpponents.length) return lowest(winners);
    const secure = winners.filter(holds);
    if (secure.length) return lowest(secure);
    // Second hand low, third hand high.
    return trick.length === 2 ? highest(winners) : lowest(legal);
  }

  // Out of the led suit: trump in or throw something away.
  if (partnerWinning && holds(winningCard)) return discard(k, hand);
  const trumps = hand.filter((c) => suitOf(c) === trump);
  const overTrumps = trumps.filter((c) => beats(c, winningCard, trump));
  if (overTrumps.length) {
    const secure = overTrumps.filter(holds);
    if (secure.length) return lowest(secure);
    if (!partnerWinning) return lowest(overTrumps);
  }
  return discard(k, hand);
}

/** Throws the least useful card: a low side card, never a sure winner if it can help it. */
function discard(k: Knowledge, hand: readonly Card[]): Card {
  const { trump } = k.view;
  const side = hand.filter((c) => suitOf(c) !== trump);
  if (!side.length) return lowest(hand);
  const plain = side.filter((c) => !k.isMaster(c));
  const pool = plain.length ? plain : side;
  const suitLength = (c: Card) => hand.filter((h) => suitOf(h) === suitOf(c)).length;
  return [...pool].sort((a, b) => rankOf(a) - rankOf(b) || suitLength(a) - suitLength(b))[0];
}
