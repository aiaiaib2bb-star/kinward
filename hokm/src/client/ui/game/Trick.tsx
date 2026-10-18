import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import type { Card } from '../../../shared/cards';
import type { Play } from '../../../shared/rules';
import { settings } from '../../state/settings';
import { FlipCard, PlayingCard } from '../components/Card';
import type { PlayOrigin } from './Hand';
import { type Geo, tiltFor } from './geometry';

interface Common {
  geo: Geo;
  rel: (seat: number) => number;
  face: string;
  fourColor: boolean;
  backOf: (seat: number) => string;
}

function slotTransform(geo: Geo, r: number, card: Card, scale = 1) {
  const slot = geo.slots[r];
  return `translate(${slot.x - geo.trickCard / 2}px, ${slot.y - geo.trickCardH / 2}px) rotate(${tiltFor(card, r)}deg) scale(${scale})`;
}

function TrickCard({ play, origin, power, winning, ...c }: Common & { play: Play; origin?: PlayOrigin; power: number; winning: boolean }) {
  const ref = useRef<HTMLDivElement>(null);
  const r = c.rel(play.seat);
  const final = slotTransform(c.geo, r, play.card);

  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const { geo } = c;
    const fast = settings.get().reduceMotion;
    let from: string;
    if (origin) {
      from = `translate(${origin.cx - geo.trickCard / 2}px, ${origin.cy - geo.trickCardH / 2}px) rotate(${origin.rot}deg) scale(${origin.w / geo.trickCard})`;
    } else {
      const seat = geo.seats[r];
      from = `translate(${seat.x - geo.trickCard / 2}px, ${seat.y - geo.trickCardH / 2}px) rotate(${tiltFor(play.card, r) - 40}deg) scale(0.42)`;
    }
    const slam = power > 0;
    const duration = fast ? 120 : slam ? 240 : 360;
    const frames: Keyframe[] = slam
      ? [
          { transform: from },
          { transform: slotTransform(geo, r, play.card, 1.32), offset: 0.62 },
          { transform: slotTransform(geo, r, play.card, 0.92), offset: 0.82 },
          { transform: final },
        ]
      : [{ transform: from }, { transform: final }];
    el.animate(frames, { duration, easing: slam ? 'cubic-bezier(.55,0,.7,.2)' : 'cubic-bezier(.2,.75,.25,1)' });
    if (!origin) {
      el.querySelector('.flip-inner')?.animate(
        [{ transform: 'rotateY(180deg)' }, { transform: 'rotateY(180deg)', offset: 0.25 }, { transform: 'rotateY(0deg)' }],
        {
          duration,
          easing: 'ease-out',
        },
      );
    }
    // Only on arrival: the card stays put afterwards.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div ref={ref} className={`trick-card${winning ? ' winning' : ''}${power > 0 ? ' slammed' : ''}`} style={{ transform: final, zIndex: 10 }}>
      {origin ? (
        <PlayingCard card={play.card} face={c.face} fourColor={c.fourColor} width={c.geo.trickCard} />
      ) : (
        <FlipCard card={play.card} back={c.backOf(play.seat)} face={c.face} fourColor={c.fourColor} width={c.geo.trickCard} />
      )}
    </div>
  );
}

/** A finished trick sweeping off toward whoever took it. */
function CollectCard({ play, winner, index, onDone, ...c }: Common & { play: Play; winner: number; index: number; onDone: () => void }) {
  const ref = useRef<HTMLDivElement>(null);
  const r = c.rel(play.seat);
  const start = slotTransform(c.geo, r, play.card);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const target = c.geo.seats[c.rel(winner)];
    const end = `translate(${target.x - c.geo.trickCard / 2}px, ${target.y - c.geo.trickCardH / 2}px) rotate(${tiltFor(play.card, r) * 3}deg) scale(0.3)`;
    const anim = el.animate(
      [
        { transform: start, opacity: 1 },
        { transform: end, opacity: 0 },
      ],
      {
        duration: settings.get().reduceMotion ? 150 : 430,
        delay: index * 35,
        easing: 'cubic-bezier(.5,0,.75,0)',
        fill: 'forwards',
      },
    );
    anim.onfinish = onDone;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return (
    <div ref={ref} className="trick-card" style={{ transform: start, zIndex: 9 }}>
      <PlayingCard card={play.card} face={c.face} fourColor={c.fourColor} width={c.geo.trickCard} />
    </div>
  );
}

interface TrickProps extends Common {
  plays: Play[];
  slams: Record<string, number>;
  origins: Map<Card, PlayOrigin>;
  winner: number | null;
  last: { plays: Play[]; winner: number } | null;
}

export function TrickLayer({ plays, slams, origins, winner, last, ...c }: TrickProps) {
  const [collecting, setCollecting] = useState<{ plays: Play[]; winner: number; key: string } | null>(null);
  const prev = useRef<Play[]>(plays);

  // When a full trick leaves the table, sweep it to the winner.
  useEffect(() => {
    const before = prev.current;
    prev.current = plays;
    if (before.length === 4 && !before.some((p) => plays.some((q) => q.card === p.card)) && last) {
      setCollecting({ plays: last.plays, winner: last.winner, key: last.plays.map((p) => p.card).join() });
    }
  }, [plays, last]);

  return (
    <div className="trick-layer">
      {plays.map((p) => (
        <TrickCard key={p.card} play={p} origin={origins.get(p.card)} power={slams[p.card] ?? 0} winning={winner === p.seat} {...c} />
      ))}
      {collecting &&
        collecting.plays.map((p, i) => (
          <CollectCard
            key={`${collecting.key}-${p.card}`}
            play={p}
            winner={collecting.winner}
            index={i}
            onDone={() => i === collecting.plays.length - 1 && setCollecting(null)}
            {...c}
          />
        ))}
    </div>
  );
}
