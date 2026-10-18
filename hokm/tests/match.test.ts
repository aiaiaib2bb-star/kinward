import { describe, expect, it } from 'vitest';
import { type Control, Match, type MatchEnd } from '../src/server/match';
import type { RoomSettings } from '../src/shared/protocol';
import { seededRng } from '../src/shared/shuffle';

const settings: RoomSettings = { targetScore: 7, turnTime: 30, shuffleMode: 'real' };

function harness(controls: Control[], opts: Partial<RoomSettings> = {}, seed = 1) {
  const events = { slams: 0, toasts: [] as string[], changes: 0 };
  let ended: MatchEnd | null = null;
  const match = new Match(
    { ...settings, ...opts },
    {
      control: (seat) => controls[seat],
      changed: () => events.changes++,
      slam: () => events.slams++,
      emote: () => {},
      toast: (key) => events.toasts.push(key),
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

  it('carries the deck over between hands in real mode', async () => {
    const h = harness(['bot', 'bot', 'bot', 'bot'], { targetScore: 10 });
    h.match.start();
    await h.until(() => h.match.handNumber === 2 && h.match.phase === 'deal1', 20000);
    const all = [0, 1, 2, 3].flatMap((s) => (h.match as unknown as { hands: string[][] }).hands[s]);
    expect(new Set(all).size).toBe(52);
    h.match.dispose();
  }, 30000);
});
