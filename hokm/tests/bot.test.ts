import { describe, expect, it } from 'vitest';
import { botChooseTrump, botPlay, type BotView } from '../src/shared/bot';
import { newDeck, suitOf } from '../src/shared/cards';
import { type Play, TRICKS_TO_WIN_HAND, dealHands, handOutcome, isLegalPlay, nextSeat, teamOf, trickWinner } from '../src/shared/rules';
import { fisherYates, seededRng } from '../src/shared/shuffle';

describe('bot trump call', () => {
  it('calls its longest, strongest suit', () => {
    expect(botChooseTrump(['H14', 'H13', 'S2', 'C3', 'H4'])).toBe('H');
    expect(botChooseTrump(['S2', 'S3', 'D14', 'D13', 'C4'])).toBe('D');
  });
});

describe('bot play', () => {
  const view = (over: Partial<BotView>): BotView => ({
    seat: 0,
    hand: [],
    trump: 'S',
    hakem: 0,
    trick: [],
    tricks: [],
    ...over,
  });

  it('follows suit, and plays low when partner already has the trick', () => {
    const card = botPlay(
      view({
        seat: 3,
        hand: ['H2', 'H13', 'C5'],
        trick: [
          { seat: 0, card: 'H9' },
          { seat: 1, card: 'H14' },
          { seat: 2, card: 'H3' },
        ],
      }),
    );
    expect(card).toBe('H2');
  });

  it('wins cheaply as the last player', () => {
    const card = botPlay(
      view({
        seat: 3,
        hand: ['H2', 'H11', 'H14'],
        trick: [
          { seat: 0, card: 'H9' },
          { seat: 1, card: 'H3' },
          { seat: 2, card: 'H10' },
        ],
      }),
    );
    expect(card).toBe('H11');
  });

  it('trumps in when out of the led suit and the opponents are winning', () => {
    const card = botPlay(
      view({
        seat: 1,
        trump: 'S',
        hand: ['S3', 'S12', 'D4'],
        trick: [{ seat: 0, card: 'H14' }],
      }),
    );
    expect(suitOf(card)).toBe('S');
  });

  it('plays whole hands legally and always ends them', () => {
    for (let game = 0; game < 200; game++) {
      const rng = seededRng(game + 1);
      const hakem = game % 4;
      const hands = dealHands(fisherYates(newDeck(), rng), hakem);
      const trump = botChooseTrump(hands[hakem].slice(0, 5));
      const tricks: Play[][] = [];
      const won: [number, number] = [0, 0];
      let leader = hakem;
      while (won[0] < TRICKS_TO_WIN_HAND && won[1] < TRICKS_TO_WIN_HAND) {
        const trick: Play[] = [];
        let seat = leader;
        for (let i = 0; i < 4; i++) {
          const card = botPlay({ seat, hand: hands[seat], trump, hakem, trick, tricks });
          expect(isLegalPlay(hands[seat], trick, card)).toBe(true);
          hands[seat] = hands[seat].filter((c) => c !== card);
          trick.push({ seat, card });
          seat = nextSeat(seat);
        }
        leader = trickWinner(trick, trump);
        won[teamOf(leader)]++;
        tricks.push(trick);
      }
      expect(handOutcome(won, teamOf(hakem))).not.toBeNull();
    }
  });
});
