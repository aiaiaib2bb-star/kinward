import type { Card } from './cards';

/** Returns a float in [0, 1). The server passes a crypto-backed one; tests pass a seeded one. */
export type Rng = () => number;

/** Small, fast, seedable generator for tests and simulations. */
export function seededRng(seed: number): Rng {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function randomInt(rng: Rng, min: number, maxInclusive: number): number {
  return min + Math.floor(rng() * (maxInclusive - min + 1));
}

/** A perfectly uniform shuffle: every hand's deck starts from one. */
export function fisherYates(deck: readonly Card[], rng: Rng): Card[] {
  const out = deck.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

/**
 * One riffle shuffle, modelled the way hands actually do it (Gilbert–Shannon–
 * Reeds): the deck is split roughly in half, binomially, and cards fall from
 * the two halves with probability proportional to how many each half still
 * holds. On its own a riffle leaves a lot of the old order intact (about
 * seven mix a 52-card deck thoroughly); in the game it is applied to a deck
 * that is already fully random, so it moves real cards without making any
 * deal less random.
 */
export function riffle(deck: readonly Card[], rng: Rng): Card[] {
  let split = 0;
  for (let i = 0; i < deck.length; i++) if (rng() < 0.5) split++;
  const left = deck.slice(0, split);
  const right = deck.slice(split);
  const out: Card[] = [];
  let l = 0;
  let r = 0;
  while (l < left.length || r < right.length) {
    const leftLeft = left.length - l;
    const rightLeft = right.length - r;
    if (rng() < leftLeft / (leftLeft + rightLeft)) out.push(left[l++]);
    else out.push(right[r++]);
  }
  return out;
}

/**
 * Cuts the deck: the top `count` cards are lifted off and put underneath.
 * deck[0] is the top of the deck. The count is clamped so a cut always moves
 * at least one card and leaves at least one behind.
 */
export function cutDeck(deck: readonly Card[], count: number): Card[] {
  const n = deck.length;
  if (n < 2) return deck.slice();
  const k = Math.min(n - 1, Math.max(1, Math.round(count)));
  return deck.slice(k).concat(deck.slice(0, k));
}

/** A cut somewhere in the middle third of the deck, the way people cut without thinking. */
export function casualCutCount(deckSize: number, rng: Rng): number {
  const lo = Math.round(deckSize * 0.3);
  const hi = Math.round(deckSize * 0.7);
  return randomInt(rng, lo, hi);
}
