import { type CSSProperties, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import type { Card } from '../../../shared/cards';
import { SLAM } from '../../../shared/constants';
import { sfx } from '../../audio/sfx';
import { buzz } from '../../fx/haptics';
import { useT } from '../../i18n';
import { PlayingCard } from '../components/Card';
import type { Geo } from './geometry';

export interface CardPose {
  x: number;
  y: number;
  rot: number;
}

/** Where a played card left the hand: its centre, tilt and drawn width. */
export interface PlayOrigin {
  cx: number;
  cy: number;
  rot: number;
  w: number;
}

interface HandProps {
  geo: Geo;
  cards: Card[];
  /** Cards you may play now, or null when it isn't your turn. */
  legal: Set<Card> | null;
  face: string;
  fourColor: boolean;
  enabled: boolean;
  onPlay: (card: Card, power: number, from: PlayOrigin) => void;
  onReject: (card: Card) => void;
}

export function fanLayout(n: number, geo: Geo): { poses: CardPose[]; x0: number; spacing: number } {
  const cw = geo.handCard;
  const ch = geo.handCardH;
  const pad = Math.max(6, geo.safe.l + 4, geo.safe.r + 4);
  const maxRot = n > 1 ? Math.min(8, 1 + n * 0.5) : 0;
  // Tilted cards lean their top corners outward; leave room for that.
  const lean = ch * Math.sin((maxRot * Math.PI) / 180);
  const avail = geo.w - pad * 2 - lean * 2;
  const spacing = n > 1 ? Math.min(cw * 0.7, (avail - cw) / (n - 1)) : 0;
  const total = spacing * (n - 1) + cw;
  const x0 = (geo.w - total) / 2;
  const arc = ch * 0.07;
  const poses = Array.from({ length: n }, (_, i) => {
    const off = n > 1 ? (i - (n - 1) / 2) / ((n - 1) / 2) : 0;
    return { x: x0 + i * spacing, y: geo.handTop + off * off * arc, rot: off * maxRot };
  });
  return { poses, x0, spacing };
}

/** The card under a point, testing each card's real tilted outline from the top of the pile down. */
function hitCard(poses: CardPose[], cw: number, ch: number, px: number, py: number): number | null {
  for (let i = poses.length - 1; i >= 0; i--) {
    const p = poses[i];
    const ox = p.x + cw / 2;
    const oy = p.y + ch;
    const a = (-p.rot * Math.PI) / 180;
    const dx = px - ox;
    const dy = py - oy;
    const lx = dx * Math.cos(a) - dy * Math.sin(a);
    const ly = dx * Math.sin(a) + dy * Math.cos(a);
    if (lx >= -cw / 2 && lx <= cw / 2 && ly >= -ch * 1.3 && ly <= 4) return i;
  }
  return null;
}

interface Sample {
  x: number;
  y: number;
  t: number;
}

type Gesture =
  | { kind: 'none' }
  | { kind: 'press'; id: number; start: Sample; index: number; moved: boolean; el: HTMLElement }
  | { kind: 'drag'; id: number; start: Sample; card: Card; grabX: number; grabY: number; el: HTMLElement };

const LIFT = 0.24;

export function Hand({ geo, cards, legal, face, fourColor, enabled, onPlay, onReject }: HandProps) {
  const t = useT();
  const [hover, setHover] = useState<number | null>(null);
  const [selected, setSelected] = useState<Card | null>(null);
  const [drag, setDrag] = useState<{ card: Card; pose: CardPose } | null>(null);
  const ghost = useRef<HTMLDivElement>(null);
  const layer = useRef<HTMLDivElement>(null);
  const origin = useRef({ x: 0, y: 0 });
  const gesture = useRef<Gesture>({ kind: 'none' });
  const samples = useRef<Sample[]>([]);
  const seen = useRef<Set<Card>>(new Set());
  const { poses, x0, spacing } = useMemo(() => fanLayout(cards.length, geo), [cards.length, geo]);
  const cw = geo.handCard;
  const ch = geo.handCardH;
  const myTurn = legal !== null;

  // Cards that weren't in the hand last time slide in, a few at a time.
  const arriving = useMemo(() => {
    const fresh = cards.filter((c) => !seen.current.has(c));
    return new Map(fresh.map((c, i) => [c, i]));
  }, [cards]);
  useLayoutEffect(() => {
    seen.current = new Set(cards);
  }, [cards]);

  useEffect(() => {
    if (selected && !cards.includes(selected)) setSelected(null);
  }, [cards, selected]);

  /** Which card a finger at (x, y) means: the one under it, else the nearest by position along the fan. */
  const indexAt = (x: number, y?: number) => {
    if (!cards.length) return null;
    if (y !== undefined) {
      const hit = hitCard(poses, cw, ch, x, y);
      if (hit !== null) return hit;
    }
    if (spacing <= 0) return 0;
    return Math.max(0, Math.min(cards.length - 1, Math.floor((x - x0) / spacing)));
  };

  const canPlay = (card: Card) => myTurn && legal!.has(card);

  /**
   * How fast the finger was moving as it let go, over the last tenth of a
   * second of actual movement. The lift itself often arrives a beat after the
   * last move, at the same spot; that pause doesn't make a flick a drop.
   */
  const velocity = () => {
    const s = samples.current;
    const end = s[s.length - 1];
    let i = s.length - 1;
    while (i > 0 && s[i].x === s[i - 1].x && s[i].y === s[i - 1].y) i--;
    const lastMove = s[i];
    if (end.t - lastMove.t > 140) return { vx: 0, vy: 0 };
    let j = i;
    while (j > 0 && lastMove.t - s[j - 1].t <= 100) j--;
    const first = s[j === i ? Math.max(0, i - 1) : j];
    const dt = Math.max(8, lastMove.t - first.t);
    return { vx: (lastMove.x - first.x) / dt, vy: (lastMove.y - first.y) / dt };
  };

  const power = (vx: number, vy: number) => {
    const speed = Math.hypot(vx, vy);
    if (vy > -0.6 || speed < SLAM.minSpeed) return 0;
    return Math.max(0.08, Math.min(1, (speed - SLAM.minSpeed) / (SLAM.maxSpeed - SLAM.minSpeed)));
  };

  const play = (card: Card, pwr: number, from: PlayOrigin) => {
    setSelected(null);
    setHover(null);
    onPlay(card, pwr, from);
  };

  const reject = (card: Card) => {
    sfx.play('error');
    buzz('error');
    onReject(card);
  };

  const onPointerDown = (e: React.PointerEvent<HTMLDivElement>, index: number) => {
    if (!enabled || gesture.current.kind !== 'none') return;
    const el = e.currentTarget;
    el.setPointerCapture(e.pointerId);
    const box = layer.current?.getBoundingClientRect();
    origin.current = { x: box?.left ?? 0, y: box?.top ?? 0 };
    const start = { x: e.clientX - origin.current.x, y: e.clientY - origin.current.y, t: e.timeStamp };
    samples.current = [start];
    const i = indexAt(start.x, start.y) ?? index;
    gesture.current = { kind: 'press', id: e.pointerId, start, index: i, moved: false, el };
    setHover(i);
    sfx.play('select');
    buzz('select');
  };

  const onPointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    const g = gesture.current;
    if (g.kind === 'none' || e.pointerId !== g.id) return;
    const p = { x: e.clientX - origin.current.x, y: e.clientY - origin.current.y, t: e.timeStamp };
    samples.current.push(p);
    if (samples.current.length > 8) samples.current.shift();
    if (g.kind === 'press') {
      const dy = p.y - g.start.y;
      if (dy < -16 && Math.abs(dy) > Math.abs(p.x - g.start.x) * 0.6) {
        const card = cards[g.index];
        const pose = poses[g.index];
        const lifted = { x: pose.x, y: pose.y - ch * LIFT, rot: pose.rot };
        gesture.current = { kind: 'drag', id: g.id, start: g.start, card, grabX: g.start.x - lifted.x, grabY: g.start.y - lifted.y, el: g.el };
        setDrag({ card, pose: lifted });
        sfx.play('flick');
        return;
      }
      // While scrubbing, only the horizontal position matters: the finger can drift up or down.
      const i = indexAt(p.x, Math.max(p.y, geo.handTop + ch * 0.35));
      if (i !== null && i !== g.index) {
        gesture.current = { ...g, index: i, moved: true };
        setHover(i);
        buzz('tick');
        sfx.play('select');
      }
      return;
    }
    // Dragging: the ghost follows the finger, leaning into the motion.
    const { vx } = velocity();
    const tilt = Math.max(-18, Math.min(18, vx * 9));
    const x = p.x - g.grabX;
    const y = p.y - g.grabY;
    if (ghost.current) ghost.current.style.transform = `translate(${x}px, ${y}px) rotate(${tilt}deg) scale(1.08)`;
  };

  const snapBack = (card: Card) => {
    const i = cards.indexOf(card);
    const el = ghost.current;
    if (!el || i < 0) {
      setDrag(null);
      return;
    }
    const pose = poses[i];
    const anim = el.animate([{ transform: el.style.transform }, { transform: `translate(${pose.x}px, ${pose.y}px) rotate(${pose.rot}deg) scale(1)` }], {
      duration: 200,
      easing: 'cubic-bezier(.2,.8,.2,1)',
    });
    anim.onfinish = () => setDrag(null);
  };

  const onPointerUp = (e: React.PointerEvent<HTMLDivElement>) => {
    const g = gesture.current;
    if (g.kind === 'none' || e.pointerId !== g.id) return;
    gesture.current = { kind: 'none' };
    const px = e.clientX - origin.current.x;
    const py = e.clientY - origin.current.y;
    samples.current.push({ x: px, y: py, t: e.timeStamp });
    if (g.kind === 'drag') {
      const { vx, vy } = velocity();
      const dy = py - g.start.y;
      const released = py < geo.handTop - ch * 0.15 || (vy < -0.45 && dy < -36);
      if (released && canPlay(g.card)) {
        const pwr = power(vx, vy);
        const x = px - g.grabX;
        const y = py - g.grabY;
        setDrag(null);
        play(g.card, pwr, { cx: x + cw / 2, cy: y + ch / 2, rot: Math.max(-18, Math.min(18, vx * 9)), w: cw * 1.08 });
      } else {
        if (released) reject(g.card);
        snapBack(g.card);
      }
      setHover(null);
      return;
    }
    // A tap: the first raises the card, the second plays it.
    const card = cards[g.index];
    setHover(null);
    if (!card) return;
    const quick = e.timeStamp - g.start.t < 450;
    if (selected === card && !g.moved && quick) {
      if (canPlay(card)) {
        const pose = poses[g.index];
        play(card, 0, { cx: pose.x + cw / 2, cy: pose.y - ch * LIFT + ch / 2, rot: pose.rot, w: cw * 1.05 });
      } else reject(card);
      return;
    }
    setSelected(card);
  };

  const onPointerCancel = (e: React.PointerEvent<HTMLDivElement>) => {
    const g = gesture.current;
    if (g.kind === 'none' || e.pointerId !== g.id) return;
    gesture.current = { kind: 'none' };
    setHover(null);
    if (g.kind === 'drag') snapBack(g.card);
  };

  // Arrow keys and Enter, for anyone playing on a computer.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!enabled || !cards.length || (e.target as HTMLElement)?.tagName === 'INPUT') return;
      const i = selected ? cards.indexOf(selected) : -1;
      if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
        const next = e.key === 'ArrowRight' ? Math.min(cards.length - 1, i + 1) : Math.max(0, i < 0 ? cards.length - 1 : i - 1);
        setSelected(cards[next]);
        sfx.play('select');
      } else if ((e.key === 'Enter' || e.key === ' ') && selected) {
        e.preventDefault();
        const pose = poses[i];
        if (canPlay(selected)) play(selected, e.shiftKey ? 0.7 : 0, { cx: pose.x + cw / 2, cy: pose.y - ch * LIFT + ch / 2, rot: pose.rot, w: cw });
        else reject(selected);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  const selectedIndex = selected ? cards.indexOf(selected) : -1;
  const slamSelected = () => {
    if (!selected) return;
    const pose = poses[selectedIndex];
    if (canPlay(selected)) play(selected, 0.75, { cx: pose.x + cw / 2, cy: pose.y - ch * LIFT + ch / 2, rot: pose.rot, w: cw * 1.05 });
    else reject(selected);
  };

  return (
    <div ref={layer} className={`hand${myTurn ? ' my-turn' : ''}`} style={{ ['--cw' as string]: `${cw}px` } as CSSProperties}>
      {myTurn && <div className="hand-glow" style={{ top: geo.handTop - 10 }} />}
      {cards.map((card, i) => {
        const pose = poses[i];
        const up = hover === i || (hover === null && selected === card);
        const illegal = myTurn && !legal!.has(card);
        const lift = up ? ch * (illegal ? 0.1 : LIFT) : illegal ? -ch * 0.04 : 0;
        const arrive = arriving.get(card);
        const hidden = drag?.card === card;
        return (
          <div
            key={card}
            className={`hand-card${up ? ' up' : ''}${illegal ? ' illegal' : ''}${hidden ? ' hidden' : ''}${arrive !== undefined ? ' arrive' : ''}`}
            style={
              {
                transform: `translate(${pose.x}px, ${pose.y}px) rotate(${pose.rot}deg) translateY(${-lift}px) scale(${up ? 1.06 : 1})`,
                zIndex: up ? 40 : i + 1,
                animationDelay: arrive !== undefined ? `${arrive * 45}ms` : undefined,
              } as CSSProperties
            }
            onPointerDown={(e) => onPointerDown(e, i)}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onPointerCancel={onPointerCancel}
            onContextMenu={(e) => e.preventDefault()}
          >
            <PlayingCard card={card} face={face} fourColor={fourColor} width={cw} />
          </div>
        );
      })}
      {selected && selectedIndex >= 0 && hover === null && !drag && (
        <div className="play-hint" style={{ left: poses[selectedIndex].x + cw / 2, top: poses[selectedIndex].y - ch * LIFT - 30 }}>
          <span>{canPlay(selected) ? t('tap_to_play') : myTurn ? '🚫' : t('not_your_turn')}</span>
          {canPlay(selected) && (
            <button type="button" className="slam-mini" onClick={slamSelected} aria-label={t('slam_word')}>
              💥
            </button>
          )}
        </div>
      )}
      {drag && (
        <div ref={ghost} className="hand-ghost" style={{ transform: `translate(${drag.pose.x}px, ${drag.pose.y}px) rotate(${drag.pose.rot}deg) scale(1.08)` }}>
          <PlayingCard card={drag.card} face={face} fourColor={fourColor} width={cw} />
        </div>
      )}
    </div>
  );
}
