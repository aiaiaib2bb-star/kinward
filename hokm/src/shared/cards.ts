// Cards are plain strings: the suit letter followed by the rank number,
// 2 through 14, where 11 = Jack, 12 = Queen, 13 = King and 14 = Ace.
// "H14" is the ace of hearts, "S2" the two of spades. Strings make cards
// cheap to send, compare and use as React keys.

export type Suit = 'S' | 'H' | 'C' | 'D';
export type Card = string;

export const SUITS: readonly Suit[] = ['S', 'H', 'C', 'D'];
export const RANKS: readonly number[] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];
export const ACE = 14;

export function suitOf(card: Card): Suit {
  return card[0] as Suit;
}

export function rankOf(card: Card): number {
  return Number(card.slice(1));
}

export function makeCard(suit: Suit, rank: number): Card {
  return `${suit}${rank}`;
}

export function isCard(value: unknown): value is Card {
  if (typeof value !== 'string' || value.length < 2 || value.length > 3) return false;
  const suit = value[0];
  const rank = Number(value.slice(1));
  return (SUITS as readonly string[]).includes(suit) && Number.isInteger(rank) && rank >= 2 && rank <= 14;
}

export function isSuit(value: unknown): value is Suit {
  return typeof value === 'string' && (SUITS as readonly string[]).includes(value);
}

export function isRed(suit: Suit): boolean {
  return suit === 'H' || suit === 'D';
}

/** A fresh pack, ordered by suit then rank, as it comes out of the box. */
export function newDeck(): Card[] {
  const deck: Card[] = [];
  for (const suit of SUITS) for (const rank of RANKS) deck.push(makeCard(suit, rank));
  return deck;
}

export function rankLabel(rank: number): string {
  switch (rank) {
    case 11:
      return 'J';
    case 12:
      return 'Q';
    case 13:
      return 'K';
    case 14:
      return 'A';
    default:
      return String(rank);
  }
}

/**
 * The order suits are laid out in a hand: trump first (once there is one),
 * then the rest arranged so neighbouring suits alternate colour wherever the
 * cards actually held allow it — two red suits side by side are easy to misread
 * on a small screen.
 */
export function suitOrder(present: readonly Suit[], trump: Suit | null): Suit[] {
  const suits = SUITS.filter((s) => present.includes(s));
  let best: Suit[] = suits;
  let bestScore = Infinity;
  for (const perm of permutations(suits)) {
    if (trump && suits.includes(trump) && perm[0] !== trump) continue;
    let clashes = 0;
    for (let i = 1; i < perm.length; i++) if (isRed(perm[i]) === isRed(perm[i - 1])) clashes++;
    // Prefer the canonical order when clash counts tie, so the hand never
    // reshuffles itself for no visible reason.
    const drift = perm.reduce((acc, s, i) => acc + Math.abs(SUITS.indexOf(s) - i) * 0.01, 0);
    const score = clashes + drift;
    if (score < bestScore) {
      bestScore = score;
      best = perm;
    }
  }
  return best;
}

/** Sorts a hand by suit (see suitOrder) and, within a suit, high to low. */
export function sortHand(cards: readonly Card[], trump: Suit | null): Card[] {
  const present = [...new Set(cards.map(suitOf))];
  const order = suitOrder(present, trump);
  return [...cards].sort((a, b) => {
    const sa = order.indexOf(suitOf(a));
    const sb = order.indexOf(suitOf(b));
    if (sa !== sb) return sa - sb;
    return rankOf(b) - rankOf(a);
  });
}

function permutations<T>(items: readonly T[]): T[][] {
  if (items.length <= 1) return [items.slice()];
  const out: T[][] = [];
  items.forEach((item, i) => {
    const rest = items.filter((_, j) => j !== i);
    for (const p of permutations(rest)) out.push([item, ...p]);
  });
  return out;
}
