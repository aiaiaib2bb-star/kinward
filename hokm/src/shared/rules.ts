import { ACE, type Card, type Suit, rankOf, suitOf } from './cards';

// Seats are 0–3 in turn order. Hokm is played counter-clockwise, so seat
// n + 1 sits on seat n's right. Partners face each other: seats 0 and 2 are
// one team, 1 and 3 the other.

export const SEAT_COUNT = 4;
export const HAND_SIZE = 13;
export const TRICKS_TO_WIN_HAND = 7;
/** Hokm deals in packets: five each first (the hakem calls trump on those), then four, then four. */
export const DEAL_PACKETS: readonly number[] = [5, 4, 4];

export interface Play {
  seat: number;
  card: Card;
}

export const teamOf = (seat: number): number => seat % 2;
export const nextSeat = (seat: number): number => (seat + 1) % SEAT_COUNT;
export const prevSeat = (seat: number): number => (seat + SEAT_COUNT - 1) % SEAT_COUNT;
export const partnerOf = (seat: number): number => (seat + 2) % SEAT_COUNT;
export const seatsOfTeam = (team: number): number[] => [team, team + 2];

/** Dealing starts with the player on the hakem's right and ends with the hakem. */
export function dealOrder(hakem: number): number[] {
  return [1, 2, 3, 0].map((offset) => (hakem + offset) % SEAT_COUNT);
}

/** The opponent on the hakem's left cuts the deck, as at a real table. */
export function cutterFor(hakem: number): number {
  return prevSeat(hakem);
}

/**
 * Deals from the top of the deck in Hokm's packets. Each seat's hand comes
 * back in the order it was received, so its first five cards are the ones
 * the player holds while the hakem is calling trump.
 */
export function dealHands(deck: readonly Card[], hakem: number): Card[][] {
  const hands: Card[][] = [[], [], [], []];
  let pos = 0;
  for (const size of DEAL_PACKETS) {
    for (const seat of dealOrder(hakem)) {
      hands[seat].push(...deck.slice(pos, pos + size));
      pos += size;
    }
  }
  return hands;
}

export function ledSuit(trick: readonly Play[]): Suit | null {
  return trick.length ? suitOf(trick[0].card) : null;
}

/** You must follow the led suit if you can; otherwise anything goes, trump or not. */
export function legalPlays(hand: readonly Card[], trick: readonly Play[]): Card[] {
  const led = ledSuit(trick);
  if (!led) return hand.slice();
  const following = hand.filter((c) => suitOf(c) === led);
  return following.length ? following : hand.slice();
}

export function isLegalPlay(hand: readonly Card[], trick: readonly Play[], card: Card): boolean {
  return hand.includes(card) && legalPlays(hand, trick).includes(card);
}

/** Whether `challenger` takes the trick from `winning`, the card currently winning it. */
export function beats(challenger: Card, winning: Card, trump: Suit | null): boolean {
  const cs = suitOf(challenger);
  const ws = suitOf(winning);
  if (cs === ws) return rankOf(challenger) > rankOf(winning);
  // Different suits: only a trump can take a non-trump. A discard never wins.
  return trump !== null && cs === trump;
}

export function trickWinner(trick: readonly Play[], trump: Suit | null): number {
  let best = trick[0];
  for (let i = 1; i < trick.length; i++) if (beats(trick[i].card, best.card, trump)) best = trick[i];
  return best.seat;
}

export interface HandOutcome {
  winnerTeam: number;
  points: number;
  /** The losers took no tricks at all. */
  kot: boolean;
  /** A kot against the hakem's own team — the most humiliating result, worth three. */
  hakemKot: boolean;
}

export const POINTS_HAND = 1;
export const POINTS_KOT = 2;
export const POINTS_HAKEM_KOT = 3;

export function handOutcome(tricksWon: readonly number[], hakemTeam: number): HandOutcome | null {
  const winnerTeam = tricksWon[0] >= TRICKS_TO_WIN_HAND ? 0 : tricksWon[1] >= TRICKS_TO_WIN_HAND ? 1 : -1;
  if (winnerTeam < 0) return null;
  const kot = tricksWon[1 - winnerTeam] === 0;
  const hakemKot = kot && winnerTeam !== hakemTeam;
  return { winnerTeam, points: hakemKot ? POINTS_HAKEM_KOT : kot ? POINTS_KOT : POINTS_HAND, kot, hakemKot };
}

/** The hakem keeps the role while their team wins; otherwise it passes to the right. */
export function nextHakem(hakem: number, winnerTeam: number): number {
  return teamOf(hakem) === winnerTeam ? hakem : nextSeat(hakem);
}

/**
 * Picks the first hakem the traditional way: cards are dealt face up, one at
 * a time around the table from `startSeat`, until someone receives an ace.
 */
export function chooseFirstHakem(deck: readonly Card[], startSeat: number): { reveals: Play[]; hakem: number } {
  const reveals: Play[] = [];
  let seat = startSeat;
  for (const card of deck) {
    reveals.push({ seat, card });
    if (rankOf(card) === ACE) return { reveals, hakem: seat };
    seat = nextSeat(seat);
  }
  return { reveals, hakem: startSeat };
}

/**
 * The deck for the next hand, gathered the way it is off a real table: the
 * tricks in the order they were taken, then whatever was still in hand when
 * the hand was decided.
 */
export function gatherDeck(tricks: readonly (readonly Play[])[], hands: readonly (readonly Card[])[]): Card[] {
  const cards: Card[] = [];
  for (const trick of tricks) for (const play of trick) cards.push(play.card);
  for (const hand of hands) cards.push(...hand);
  return cards;
}
