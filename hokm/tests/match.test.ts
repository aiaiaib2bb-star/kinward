import { describe, expect, it } from 'vitest';
import { type Control, Match, type MatchEnd } from '../src/server/match';
import { type Suit, makeCard } from '../src/shared/cards';
import type { RoomSettings } from '../src/shared/protocol';
import { legalPlays } from '../src/shared/rules';
import { seededRng } from '../src/shared/shuffle';

const settings: RoomSettings = { targetScore: 7, turnTime: 30, swaps: true, booms: true };

function harness(controls: Control[], opts: Partial<RoomSettings> = {}, seed = 1) {
  const events = { slams: 0, toasts: [] as string[], changes: 0, booms: [] as number[], swaps: [] as [number, number, boolean][] };
  let ended: MatchEnd | null = null;
  const match = new Match(
    { ...settings, ...opts },
    {
      control: (seat) => controls[seat],
      changed: () => events.changes++,
      slam: () => events.slams++,
      emote: () => {},
      toast: (key) => events.toasts.push(key),
      boom: (seat) => events.booms.push(seat),
      swapped: (from, to, accepted) => events.swaps.push([from, to, accepted]),
      ended: (end) => (ended = end),
    },
    seededRng(seed),
    0.002,
  );
  const until = async (pred: () => boolean, ms = 8000) => {
    const start = Date.now();
    while (!pred()) {
      if (Date.now() - start > ms) throw new Error(`timed out in phase ${match.phase}`);
      await new Promise((r) => setTimeout(r, 2));
    }
  };
  return { match, events, until, ended: () => ended };
}

describe('match flow', () => {
  it('plays a whole match between four bots to the target score', async () => {
    const h = harness(['bot', 'bot', 'bot', 'bot']);
    h.match.start();
    expect(h.match.phase).toBe('hakemSelect');
    await h.until(() => !!h.ended(), 20000);
    const end = h.ended()!;
    expect(end.reason).toBe('score');
    expect(h.match.scores[end.winnerTeam]).toBeGreaterThanOrEqual(7);
    expect(h.match.phase).toBe('matchEnd');
    expect(end.stats.hands).toBeGreaterThan(0);
    expect(end.stats.timesHakem.reduce((a, b) => a + b, 0)).toBe(end.stats.hands);
  }, 30000);

  it('goes through every phase of a hand in order', async () => {
    const h = harness(['bot', 'bot', 'bot', 'bot'], { targetScore: 3 }, 9);
    const seen: string[] = [];
    h.match.start();
    await h.until(() => {
      if (seen[seen.length - 1] !== h.match.phase) seen.push(h.match.phase);
      return h.match.phase === 'handEnd';
    });
    expect(seen.slice(0, 7)).toEqual(['hakemSelect', 'shuffle', 'cut', 'deal1', 'trump', 'deal2', 'play']);
    expect(seen).toContain('trickEnd');
    h.match.dispose();
  });

  it('only shows the first five cards while trump is being called', async () => {
    const h = harness(['human', 'human', 'human', 'human']);
    h.match.start();
    await h.until(() => h.match.phase === 'shuffle');
    const hakem = h.match.hakem!;
    h.match.shuffle(hakem, 'riffle');
    expect(h.match.viewFor(hakem).deckOps.shuffles).toBe(1);
    h.match.shuffleDone(hakem);
    expect(h.match.phase).toBe('cut');
    const cutter = h.match.viewFor(0).cutter!;
    expect(cutter).toBe((hakem + 3) % 4);
    // The hakem can't cut their own deal.
    h.match.cut(hakem, 20);
    expect(h.match.viewFor(0).deckOps.cuts).toBe(0);
    h.match.cut(cutter, 20);
    expect(h.match.viewFor(0).deckOps.cuts).toBe(1);
    h.match.cutDone(cutter);
    expect(h.match.phase).toBe('deal1');
    expect(h.match.viewFor(hakem).hand).toHaveLength(5);
    expect(h.match.viewFor(null).hand).toHaveLength(0);
    await h.until(() => h.match.phase === 'trump');
    h.match.chooseTrump(hakem, 'H');
    expect(h.match.trump).toBe('H');
    await h.until(() => h.match.phase === 'play');
    expect(h.match.viewFor(hakem).hand).toHaveLength(13);
    expect(h.match.turn).toBe(hakem);
    // Playing out of turn or an unheld card is refused.
    expect(h.match.play((hakem + 1) % 4, h.match.viewFor((hakem + 1) % 4).hand[0], 0)).toBe('not_your_turn');
    expect(h.match.play(hakem, 'X9', 0)).toBe('illegal');
    const card = h.match.viewFor(hakem).legal[0];
    expect(h.match.play(hakem, card, 0.8)).toBeNull();
    expect(h.events.slams).toBe(1);
    expect(h.match.trick).toEqual([{ seat: hakem, card }]);
    h.match.dispose();
  });

  it('plays for a player who keeps timing out and marks them away', async () => {
    const h = harness(['human', 'bot', 'bot', 'bot'], { turnTime: 15 });
    h.match.start();
    await h.until(() => h.match.away.has(0), 15000);
    expect(h.match.viewFor(0).away).toContain(0);
    h.match.back(0);
    expect(h.match.away.has(0)).toBe(false);
    h.match.dispose();
  }, 20000);

  it('lets a team with a bot partner surrender at once', async () => {
    const h = harness(['human', 'bot', 'bot', 'bot']);
    h.match.start();
    expect(h.match.requestSurrender(0)).toBeNull();
    expect(h.ended()).toMatchObject({ winnerTeam: 1, reason: 'surrender', surrenderTeam: 0 });
  });

  it('needs both partners to agree to surrender', async () => {
    const h = harness(['human', 'bot', 'human', 'bot']);
    h.match.start();
    expect(h.match.requestSurrender(0)).toBeNull();
    expect(h.match.surrender).toMatchObject({ team: 0, by: 0 });
    // The requester can't vote on their own request; opponents can't vote at all.
    h.match.voteSurrender(0, true);
    h.match.voteSurrender(1, true);
    expect(h.ended()).toBeNull();
    h.match.voteSurrender(2, false);
    expect(h.match.surrender).toBeNull();
    expect(h.events.toasts).toContain('surrender_declined');
    expect(h.match.requestSurrender(2)).toBe('cooldown');
    h.match.dispose();

    const h2 = harness(['human', 'bot', 'human', 'bot']);
    h2.match.start();
    h2.match.requestSurrender(2);
    h2.match.voteSurrender(0, true);
    expect(h2.ended()).toMatchObject({ winnerTeam: 1, reason: 'surrender', surrenderTeam: 0 });
  });

  it('stops the clock while paused and picks up again', async () => {
    const h = harness(['bot', 'bot', 'bot', 'bot'], { targetScore: 3 });
    h.match.start();
    await h.until(() => h.match.phase === 'play');
    h.match.pause();
    const snapshot = JSON.stringify(h.match.viewFor(0));
    await new Promise((r) => setTimeout(r, 60));
    expect(JSON.stringify(h.match.viewFor(0))).toBe(snapshot);
    h.match.resume();
    await h.until(() => !!h.ended(), 20000);
  }, 30000);

  it('starts every hand from a freshly shuffled full deck, then applies the real shuffles and cut', async () => {
    // Idle humans: the clock plays for them, and the shuffle phase waits long enough to look at the deck.
    const h = harness(['human', 'human', 'human', 'human'], { targetScore: 10, turnTime: 15 });
    const inner = h.match as unknown as { deck: string[]; hands: string[][] };
    h.match.start();
    await h.until(() => h.match.phase === 'handEnd', 20000);
    const gathered = inner.deck.slice();
    expect(new Set(gathered).size).toBe(52);
    await h.until(() => h.match.handNumber === 2 && h.match.phase === 'shuffle', 20000);
    expect(h.match.viewFor(0).deckOps.shuffles).toBe(0);
    const fresh = inner.deck.slice();
    expect(new Set(fresh).size).toBe(52);
    // Not the order the last hand left on the table.
    expect(fresh).not.toEqual(gathered);
    // The hakem's riffle and the cutter's cut really move the cards that get dealt.
    h.match.shuffle(h.match.hakem!, 'riffle');
    expect(inner.deck).not.toEqual(fresh);
    h.match.shuffleDone(h.match.hakem!);
    const beforeCut = inner.deck.slice();
    h.match.cut(h.match.viewFor(0).cutter!, 20);
    expect(inner.deck).toEqual([...beforeCut.slice(20), ...beforeCut.slice(0, 20)]);
    h.match.dispose();
  }, 30000);
});

const suit = (s: Suit) => [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14].map((r) => makeCard(s, r));

/**
 * Brings four idle humans to the first lead with no turn clock, then deals
 * a rigged hand: seat 0 holds every spade (trump), so team 0 takes every trick.
 */
async function riggedPlay(opts: Partial<RoomSettings> = {}) {
  const h = harness(['human', 'human', 'human', 'human'], { turnTime: 0, ...opts });
  h.match.start();
  await h.until(() => h.match.phase === 'play');
  h.match.trump = 'S';
  h.match.hands = [suit('S'), suit('D'), suit('H'), suit('C')];
  /** Plays the first legal card for whoever's turn it is, until `stop` says so. */
  const playOut = async (stop: () => boolean) => {
    while (!stop()) {
      if (h.match.phase === 'play' && h.match.turn !== null) {
        const seat = h.match.turn;
        expect(h.match.play(seat, legalPlays(h.match.hands[seat], h.match.trick)[0], 0)).toBeNull();
      } else await new Promise((r) => setTimeout(r, 2));
    }
  };
  return { ...h, playOut };
}

describe('boom', () => {
  it('wins the whole game when the caller takes all thirteen tricks', async () => {
    const h = await riggedPlay();
    expect(h.match.callBoom(2)).toBeNull();
    expect(h.match.viewFor(1).boom).toEqual({ team: 0, by: 2 });
    expect(h.events.booms).toEqual([2]);
    expect(h.match.callBoom(0)).toBe('boom_taken');
    // Past seven tricks the hand keeps going.
    await h.playOut(() => h.match.phase === 'handEnd');
    expect(h.match.tricksWon).toEqual([13, 0]);
    expect(h.match.handResult?.boom).toEqual({ team: 0, by: 2, won: true });
    expect(h.match.scores[0]).toBe(7);
    await h.until(() => !!h.ended());
    expect(h.ended()).toMatchObject({ winnerTeam: 0, reason: 'boom' });
    expect(h.ended()!.stats.booms).toEqual([1, 0]);
  });

  it('loses the hand at the first trick the callers drop', async () => {
    const h = await riggedPlay();
    expect(h.match.callBoom(1)).toBeNull();
    await h.playOut(() => h.match.phase === 'handEnd');
    expect(h.match.tricksWon).toEqual([1, 0]);
    expect(h.match.handResult).toMatchObject({ winnerTeam: 0, points: 1, boom: { team: 1, by: 1, won: false } });
    expect(h.match.scores).toEqual([1, 0]);
    expect(h.ended()).toBeNull();
    h.match.dispose();
  });

  it('can only be called before the first trick is taken, and only where the table allows it', async () => {
    const h = await riggedPlay();
    await h.playOut(() => h.match.tricksWon[0] === 1 && h.match.phase === 'play');
    expect(h.match.callBoom(0)).toBe('boom_late');
    h.match.dispose();
    const off = await riggedPlay({ booms: false });
    expect(off.match.callBoom(0)).toBe('boom_off');
    off.match.dispose();
  });
});

describe('hand swaps', () => {
  it('trades hands when the opponent accepts, holding the clock meanwhile', async () => {
    const h = await riggedPlay();
    const turn = h.match.turn!;
    const mine = h.match.hands[0].slice();
    const theirs = h.match.hands[1].slice();
    expect(h.match.offerSwap(0, 2)).toBe('swap_target'); // your partner isn't an opponent
    expect(h.match.offerSwap(0, 1)).toBeNull();
    expect(h.match.viewFor(1).swapOffer).toMatchObject({ from: 0, to: 1 });
    expect(h.match.viewFor(1).deadline).toBeNull();
    expect(h.match.offerSwap(2, 3)).toBe('swap_pending');
    expect(h.match.play(turn, legalPlays(h.match.hands[turn], [])[0], 0)).toBe('swap_pending');
    h.match.answerSwap(3, true); // only the one asked can answer
    expect(h.match.swapOffer).not.toBeNull();
    h.match.answerSwap(1, true);
    expect(h.match.swapOffer).toBeNull();
    expect(h.match.hands[0]).toEqual(theirs);
    expect(h.match.hands[1]).toEqual(mine);
    expect(h.events.swaps).toEqual([[0, 1, true]]);
    expect(h.match.offerSwap(0, 3)).toBe('swap_used');
    h.match.dispose();
  });

  it('treats no answer as a no, and is refused mid-trick', async () => {
    const h = await riggedPlay();
    const before = h.match.hands.map((x) => x.slice());
    expect(h.match.offerSwap(1, 2)).toBeNull();
    await h.until(() => h.match.swapOffer === null);
    expect(h.events.swaps).toEqual([[1, 2, false]]);
    expect(h.match.hands).toEqual(before);
    const turn = h.match.turn!;
    h.match.play(turn, legalPlays(h.match.hands[turn], [])[0], 0);
    const other = (turn + 1) % 4;
    expect(h.match.offerSwap(other, (other + 1) % 4)).toBe('swap_between');
    h.match.dispose();
  });

  it('lets a bot answer on its own', async () => {
    const h = harness(['human', 'bot', 'bot', 'bot'], { turnTime: 0 }, 4);
    h.match.start();
    await h.until(() => h.match.phase === 'play' && h.match.trick.length === 0 && h.match.turn !== 0);
    // Wait for a moment between tricks to offer.
    await h.until(() => h.match.offerSwap(0, 1) === null || h.match.swapsUsed.has(0));
    await h.until(() => h.events.swaps.length === 1);
    expect(h.events.swaps[0].slice(0, 2)).toEqual([0, 1]);
    h.match.dispose();
  });
});
