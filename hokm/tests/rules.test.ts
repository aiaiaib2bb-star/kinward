import { describe, expect, it } from 'vitest';
import { isCard, newDeck, rankOf, sortHand, suitOf, suitOrder } from '../src/shared/cards';
import {
  beats,
  chooseFirstHakem,
  cutterFor,
  dealHands,
  dealOrder,
  gatherDeck,
  handOutcome,
  legalPlays,
  nextHakem,
  partnerOf,
  teamOf,
  trickWinner,
} from '../src/shared/rules';
import { cutDeck, fisherYates, riffle, seededRng } from '../src/shared/shuffle';

describe('cards', () => {
  it('builds a full pack of 52 distinct cards', () => {
    const deck = newDeck();
    expect(deck).toHaveLength(52);
    expect(new Set(deck).size).toBe(52);
    expect(deck.every(isCard)).toBe(true);
  });

  it('validates card strings', () => {
    expect(isCard('H14')).toBe(true);
    expect(isCard('S2')).toBe(true);
    expect(isCard('X5')).toBe(false);
    expect(isCard('H1')).toBe(false);
    expect(isCard('H15')).toBe(false);
    expect(isCard(14)).toBe(false);
  });

  it('sorts trump first and alternates colours where it can', () => {
    const hand = ['D3', 'S14', 'H10', 'C12', 'D14', 'H2', 'S5'];
    const sorted = sortHand(hand, 'D');
    expect(sorted.map(suitOf)).toEqual(['D', 'D', 'S', 'S', 'H', 'H', 'C']);
    expect(sorted.slice(0, 2)).toEqual(['D14', 'D3']);
    // Without clubs, the two reds must be split by the black suit.
    expect(suitOrder(['S', 'H', 'D'], null)).toEqual(['H', 'S', 'D']);
  });
});

describe('dealing', () => {
  it("deals the hakem's right first, in packets of 5, 4 and 4", () => {
    expect(dealOrder(0)).toEqual([1, 2, 3, 0]);
    expect(dealOrder(2)).toEqual([3, 0, 1, 2]);
    const deck = newDeck();
    const hands = dealHands(deck, 0);
    expect(hands.every((h) => h.length === 13)).toBe(true);
    expect(new Set(hands.flat()).size).toBe(52);
    // Seat 1 (hakem's right) receives the first five cards off the top.
    expect(hands[1].slice(0, 5)).toEqual(deck.slice(0, 5));
    // The hakem receives the last packet of the first round.
    expect(hands[0].slice(0, 5)).toEqual(deck.slice(15, 20));
    // Second round starts again with seat 1.
    expect(hands[1].slice(5, 9)).toEqual(deck.slice(20, 24));
  });

  it("has the opponent on the hakem's left cut", () => {
    expect(cutterFor(0)).toBe(3);
    expect(cutterFor(1)).toBe(0);
    expect(teamOf(cutterFor(2))).not.toBe(teamOf(2));
  });
});

describe('play', () => {
  it('forces following suit only when you can', () => {
    const hand = ['H2', 'H9', 'S14', 'C3'];
    expect(legalPlays(hand, [])).toEqual(hand);
    expect(legalPlays(hand, [{ seat: 0, card: 'H13' }])).toEqual(['H2', 'H9']);
    expect(legalPlays(hand, [{ seat: 0, card: 'D13' }])).toEqual(hand);
  });

  it('ranks cards: led suit high card, trumped by any trump, discards never win', () => {
    expect(beats('H14', 'H13', 'S')).toBe(true);
    expect(beats('H2', 'H13', 'S')).toBe(false);
    expect(beats('S2', 'H14', 'S')).toBe(true);
    expect(beats('D14', 'H2', 'S')).toBe(false);
    expect(beats('H14', 'S2', 'S')).toBe(false);
    const trick = [
      { seat: 1, card: 'H10' },
      { seat: 2, card: 'H14' },
      { seat: 3, card: 'S2' },
      { seat: 0, card: 'S3' },
    ];
    expect(trickWinner(trick, 'S')).toBe(0);
    expect(trickWinner(trick, 'D')).toBe(2);
    expect(
      trickWinner(
        [
          { seat: 3, card: 'C5' },
          { seat: 0, card: 'D14' },
        ],
        'H',
      ),
    ).toBe(3);
  });

  it('knows partners and teams', () => {
    expect(partnerOf(0)).toBe(2);
    expect(partnerOf(3)).toBe(1);
    expect(teamOf(0)).toBe(teamOf(2));
    expect(teamOf(1)).not.toBe(teamOf(2));
  });
});

describe('scoring', () => {
  it('scores a plain win, a kot and a hakem kot', () => {
    expect(handOutcome([7, 4], 0)).toEqual({ winnerTeam: 0, points: 1, kot: false, hakemKot: false });
    expect(handOutcome([7, 0], 0)).toEqual({ winnerTeam: 0, points: 2, kot: true, hakemKot: false });
    expect(handOutcome([0, 7], 0)).toEqual({ winnerTeam: 1, points: 3, kot: true, hakemKot: true });
    expect(handOutcome([3, 7], 0)).toEqual({ winnerTeam: 1, points: 1, kot: false, hakemKot: false });
    expect(handOutcome([6, 6], 0)).toBeNull();
  });

  it('keeps the hakem on a win and passes it right on a loss', () => {
    expect(nextHakem(0, 0)).toBe(0);
    expect(nextHakem(0, 1)).toBe(1);
    expect(nextHakem(3, 0)).toBe(0);
    expect(nextHakem(2, 0)).toBe(2);
  });

  it('chooses the first hakem by the first ace dealt face up', () => {
    const deck = ['H3', 'S7', 'C10', 'D2', 'H9', 'C14', 'S14'];
    const { reveals, hakem } = chooseFirstHakem(deck, 2);
    expect(reveals.map((r) => r.seat)).toEqual([2, 3, 0, 1, 2, 3]);
    expect(hakem).toBe(3);
  });
});

describe('shuffling', () => {
  it('riffles and cuts without losing or duplicating cards', () => {
    const rng = seededRng(7);
    let deck = newDeck();
    for (let i = 0; i < 20; i++) {
      deck = riffle(deck, rng);
      deck = cutDeck(deck, 1 + Math.floor(rng() * 50));
    }
    expect(deck).toHaveLength(52);
    expect(new Set(deck).size).toBe(52);
  });

  it('cuts by lifting the top cards to the bottom', () => {
    expect(cutDeck(['a', 'b', 'c', 'd', 'e'], 2)).toEqual(['c', 'd', 'e', 'a', 'b']);
    expect(cutDeck(['a', 'b', 'c'], 0)).toEqual(['b', 'c', 'a']);
    expect(cutDeck(['a', 'b', 'c'], 9)).toEqual(['c', 'a', 'b']);
  });

  it('leaves structure after one riffle and little after seven', () => {
    // Count adjacent pairs that were adjacent in the original order.
    const adjacency = (d: string[]) => {
      const orig = newDeck();
      let n = 0;
      for (let i = 1; i < d.length; i++) if (orig.indexOf(d[i]) === orig.indexOf(d[i - 1]) + 1) n++;
      return n;
    };
    let once = 0;
    let seven = 0;
    for (let s = 0; s < 40; s++) {
      const rng = seededRng(100 + s);
      let d = riffle(newDeck(), rng);
      once += adjacency(d);
      for (let i = 0; i < 6; i++) d = riffle(d, rng);
      seven += adjacency(d);
    }
    expect(once / 40).toBeGreaterThan(15);
    expect(seven / 40).toBeLessThan(5);
  });

  it('gathers the next deck from the tricks and leftovers', () => {
    const deck = fisherYates(newDeck(), seededRng(3));
    const hands = dealHands(deck, 1);
    const tricks = [0, 1, 2, 3, 4, 5, 6].map((t) => [0, 1, 2, 3].map((seat) => ({ seat, card: hands[seat][t] })));
    const left = hands.map((h) => h.slice(7));
    const gathered = gatherDeck(tricks, left);
    expect(gathered).toHaveLength(52);
    expect(new Set(gathered).size).toBe(52);
    expect(rankOf(gathered[0])).toBe(rankOf(hands[0][0]));
  });
});
