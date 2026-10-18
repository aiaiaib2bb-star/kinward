import { type CSSProperties, type RefObject, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { getItem } from '../../../shared/catalog';
import type { Gif, RoomView } from '../../../shared/protocol';
import { SLAM_SOUND, THROW_SOUND, sfx } from '../../audio/sfx';
import { type BusEvent, onFx } from '../../fx/bus';
import { buzz } from '../../fx/haptics';
import { displayName, phraseText, t, useLang, useT } from '../../i18n';
import { app, toast } from '../../state/app';
import { seatMember } from '../../state/selectors';
import { settings } from '../../state/settings';
import { PlayingCard } from '../components/Card';
import { GifImage } from '../components/Gifs';
import type { Geo, Pt } from './geometry';

type Item =
  | { id: number; kind: 'bubble'; at: Pt; rel: number; text: string; emoji: boolean; gif?: Gif; ms: number }
  | { id: number; kind: 'throw'; from: Pt; to: Pt; item: string; target: string; ms: number }
  | { id: number; kind: 'impact'; at: Pt; item: string; ms: number }
  | { id: number; kind: 'slam'; at: Pt; effect: string; power: number; name: string; ms: number }
  | { id: number; kind: 'boom'; name: string; mine: boolean; ms: number }
  | { id: number; kind: 'swap'; from: Pt; to: Pt; backs: [string, string]; ms: number };

let seq = 0;

/** Bubbles sit beside the avatar, toward the middle of the table. */
const BUBBLE_OFFSET: Pt[] = [
  { x: 34, y: -64 },
  { x: -70, y: -12 },
  { x: 62, y: 6 },
  { x: 70, y: -12 },
];

export function shake(el: HTMLElement | null, power: number, quake = false) {
  if (!el || settings.get().reduceMotion) return;
  const a = (3 + power * 8) * (quake ? 1.8 : 1);
  const frames: Keyframe[] = [];
  const steps = quake ? 10 : 7;
  for (let i = 0; i <= steps; i++) {
    const k = 1 - i / steps;
    const x = (i % 2 ? 1 : -1) * a * k * (0.6 + Math.random() * 0.4);
    const y = (Math.random() - 0.5) * a * k;
    frames.push({ transform: `translate(${x}px, ${y}px) rotate(${(Math.random() - 0.5) * a * 0.12 * k}deg)` });
  }
  frames.push({ transform: 'none' });
  el.animate(frames, { duration: 360 + power * 260 + (quake ? 300 : 0), easing: 'ease-out' });
}

export function FxLayer({
  room,
  geo,
  rel,
  mySeat,
  table,
}: {
  room: RoomView;
  geo: Geo;
  rel: (seat: number) => number;
  mySeat: number | null;
  table: RefObject<HTMLDivElement | null>;
}) {
  const lang = useLang();
  const [items, setItems] = useState<Item[]>([]);
  const ctx = useRef({ room, geo, rel, mySeat });
  ctx.current = { room, geo, rel, mySeat };

  useEffect(() => {
    const add = (item: Item) => {
      setItems((list) => [...list.slice(-24), item]);
      setTimeout(() => setItems((list) => list.filter((x) => x.id !== item.id)), item.ms);
    };
    const where = (memberId: string): { at: Pt; rel: number } => {
      const { room: r, geo: g, rel: toRel } = ctx.current;
      const seat = r.seats.indexOf(memberId);
      if (seat < 0) return { at: { x: g.w - g.safe.r - 34, y: g.topBarBottom + 34 }, rel: 1 };
      const rr = toRel(seat);
      return { at: g.seats[rr], rel: rr };
    };
    const slotOf = (seat: number) => ctx.current.geo.slots[ctx.current.rel(seat)];

    const handle = (e: BusEvent) => {
      const s = settings.get();
      const me = app.get().room?.you;
      switch (e.type) {
        case 'emote': {
          if (s.muteEmotes && e.from !== me) return;
          const { at, rel: r } = where(e.from);
          const phrase = e.emote.startsWith('p_');
          add({ id: ++seq, kind: 'bubble', at, rel: r, text: phrase ? phraseText(e.emote, s.lang) : e.emote, emoji: !phrase, ms: phrase ? 3200 : 2600 });
          sfx.play('pop');
          buzz('emote');
          return;
        }
        case 'chat': {
          const { at, rel: r } = where(e.message.from);
          add({ id: ++seq, kind: 'bubble', at, rel: r, text: e.message.text, emoji: false, gif: e.message.gif, ms: e.message.gif ? 5200 : 4200 });
          if (e.message.from !== me) sfx.play('pop');
          return;
        }
        case 'boom': {
          const { room: r, mySeat: ms } = ctx.current;
          const name = displayName(seatMember(r, e.seat)?.profile, s.lang);
          const mine = ms !== null && e.seat % 2 === ms % 2;
          add({ id: ++seq, kind: 'boom', name, mine, ms: 2800 });
          shake(table.current, 1, true);
          sfx.play('boom');
          setTimeout(() => sfx.play('stamp'), 260);
          buzz('boom');
          return;
        }
        case 'swap': {
          const { room: r, geo: g, rel: toRel } = ctx.current;
          const a = seatMember(r, e.from);
          const b = seatMember(r, e.to);
          const names = { a: displayName(a?.profile, s.lang), b: displayName(b?.profile, s.lang) };
          if (!e.accepted) {
            toast(`🙅 ${t('swap_declined', names)}`, 'info', 2400);
            return;
          }
          add({
            id: ++seq,
            kind: 'swap',
            from: g.seats[toRel(e.from)],
            to: g.seats[toRel(e.to)],
            backs: [a?.profile.equipped.cardBack ?? 'back_crimson', b?.profile.equipped.cardBack ?? 'back_crimson'],
            ms: 900,
          });
          sfx.play('whoosh');
          setTimeout(() => sfx.play('riffle'), 250);
          if (r.seats[e.from] === me || r.seats[e.to] === me) buzz('turn');
          toast(`🔄 ${t('swap_done', names)}`, 'good', 2800);
          return;
        }
        case 'throw': {
          if (s.muteEmotes && e.from !== me && e.to !== me) return;
          const from = where(e.from).at;
          const to = where(e.to).at;
          add({ id: ++seq, kind: 'throw', from, to, item: e.item, target: e.to, ms: 700 });
          sfx.play('whoosh');
          setTimeout(() => {
            add({ id: ++seq, kind: 'impact', at: to, item: e.item, ms: 2600 });
            sfx.play(THROW_SOUND[e.item] ?? 'pop');
            if (e.to === me) buzz('slam');
            wobble(e.to);
          }, 640);
          return;
        }
        case 'slam': {
          // Your own slam already played the moment you threw it.
          if (e.seat === ctx.current.mySeat) return;
          const m = seatMember(ctx.current.room, e.seat);
          slamAt(slotOf(e.seat), e.effect, e.power, displayName(m?.profile, s.lang), m?.id);
          return;
        }
        case 'localSlam': {
          const { mySeat: ms, room: r } = ctx.current;
          if (ms === null) return;
          const mine = r.members.find((m) => m.id === r.you);
          slamAt(slotOf(ms), mine?.profile.equipped.slam ?? 'slam_thud', e.power, '', mine?.id);
          return;
        }
        default:
      }
    };

    const slamAt = (at: Pt, effect: string, power: number, name: string, memberId?: string) => {
      add({ id: ++seq, kind: 'slam', at, effect, power, name, ms: effect === 'slam_quake' ? 1700 : 1400 });
      // Even the softest slam shakes hard enough to notice.
      shake(table.current, Math.max(0.55, power), effect === 'slam_quake' || power > 0.75);
      const extra = SLAM_SOUND[effect];
      sfx.play('slam', Math.max(0.6, power));
      if (extra && extra !== 'slam') sfx.play(extra, power);
      buzz(power > 0.6 ? 'slamHard' : 'slam');
      if (memberId) pump(memberId);
    };

    /** The slammer's avatar jumps, so everyone sees who did it. */
    const pump = (memberId: string) => {
      const el = document.querySelector(`[data-member="${memberId}"] .avatar`) as HTMLElement | null;
      el?.animate(
        [
          { transform: 'scale(1)' },
          { transform: 'scale(1.32) rotate(-6deg)', offset: 0.3 },
          { transform: 'scale(.94) rotate(3deg)', offset: 0.6 },
          { transform: 'none' },
        ],
        { duration: 560, easing: 'ease-out' },
      );
    };

    const wobble = (memberId: string) => {
      const el = document.querySelector(`[data-member="${memberId}"] .avatar`) as HTMLElement | null;
      el?.animate(
        [
          { transform: 'rotate(0)' },
          { transform: 'rotate(-14deg) scale(.92)' },
          { transform: 'rotate(10deg)' },
          { transform: 'rotate(-6deg)' },
          { transform: 'none' },
        ],
        { duration: 520, easing: 'ease-out' },
      );
    };

    return onFx(handle);
  }, [table]);

  return (
    <div className="fx-layer" aria-hidden="true">
      {items.map((it) => {
        switch (it.kind) {
          case 'bubble': {
            const off = BUBBLE_OFFSET[it.rel] ?? BUBBLE_OFFSET[0];
            return (
              <div
                key={it.id}
                className={`fx-bubble${it.emoji ? ' emoji' : ''}${it.gif ? ' gif' : ''} rel-${it.rel}`}
                style={{ left: it.at.x + off.x, top: it.at.y + off.y, animationDuration: `${it.ms}ms` } as CSSProperties}
                dir="auto"
                lang={lang}
              >
                {it.gif ? <GifImage gif={it.gif} width={Math.min(130, geo.w * 0.34)} /> : it.text}
              </div>
            );
          }
          case 'throw':
            return <Thrown key={it.id} from={it.from} to={it.to} glyph={getItem(it.item)?.glyph ?? '🌹'} />;
          case 'impact':
            return <Impact key={it.id} at={it.at} item={it.item} />;
          case 'slam':
            return <SlamFx key={it.id} at={it.at} effect={it.effect} power={it.power} name={it.name} geo={geo} />;
          case 'boom':
            return <BoomBanner key={it.id} name={it.name} mine={it.mine} />;
          case 'swap':
            return <SwapFx key={it.id} from={it.from} to={it.to} backs={it.backs} />;
          default:
            return null;
        }
      })}
    </div>
  );
}

function Thrown({ from, to, glyph }: { from: Pt; to: Pt; glyph: string }) {
  const ref = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    const mid = { x: (from.x + to.x) / 2, y: Math.min(from.y, to.y) - 90 };
    ref.current?.animate(
      [
        { transform: `translate(${from.x}px, ${from.y}px) rotate(0deg) scale(.7)` },
        { transform: `translate(${mid.x}px, ${mid.y}px) rotate(360deg) scale(1.25)`, offset: 0.5 },
        { transform: `translate(${to.x}px, ${to.y}px) rotate(720deg) scale(1)` },
      ],
      { duration: 650, easing: 'cubic-bezier(.3,.1,.4,1)', fill: 'forwards' },
    );
  }, [from, to]);
  return (
    <div ref={ref} className="fx-thrown">
      <span>{glyph}</span>
    </div>
  );
}

const SPLATS: Record<string, { fill: string; spots: string; seeds?: boolean }> = {
  throw_tomato: { fill: '#e8262f', spots: '#ff6b5e' },
  throw_egg: { fill: '#fff7e6', spots: '#ffc21a' },
  throw_melon: { fill: '#ff4d6a', spots: '#3fae49', seeds: true },
};

function Impact({ at, item }: { at: Pt; item: string }) {
  const splat = SPLATS[item];
  const style = { left: at.x, top: at.y } as CSSProperties;
  if (splat) {
    return (
      <div className="fx-impact splat" style={style}>
        <svg viewBox="0 0 100 100" width="96" height="96">
          <path
            d="M50 12c8 0 10 10 18 9s14-6 18 2-5 13-2 20 13 8 10 17-13 6-17 12 1 15-8 17-11-8-19-8-14 10-21 5 1-13-4-18-16-4-17-13 11-9 10-17-9-13-2-18 13 3 18-2 7-6 16-6z"
            fill={splat.fill}
          />
          <circle cx="40" cy="44" r="9" fill={splat.spots} opacity=".85" />
          <circle cx="62" cy="58" r="5" fill={splat.spots} opacity=".7" />
          {splat.seeds && (
            <g fill="#1d1d1d">
              <ellipse cx="34" cy="62" rx="2" ry="3.4" />
              <ellipse cx="55" cy="34" rx="2" ry="3.4" />
              <ellipse cx="68" cy="46" rx="2" ry="3.4" />
            </g>
          )}
        </svg>
        <i className="drip d1" style={{ background: splat.fill }} />
        <i className="drip d2" style={{ background: splat.fill }} />
      </div>
    );
  }
  if (item === 'throw_slipper') {
    return (
      <div className="fx-impact bonk" style={style}>
        <span className="word">BONK!</span>
        <span className="stars">💫</span>
      </div>
    );
  }
  if (item === 'throw_firecracker') {
    return (
      <div className="fx-impact boom" style={style}>
        <span className="word">💥</span>
        {Array.from({ length: 10 }, (_, i) => (
          <i key={i} className="spark" style={{ ['--a' as string]: `${i * 36}deg` } as CSSProperties} />
        ))}
      </div>
    );
  }
  if (item === 'throw_tea') {
    return (
      <div className="fx-impact tea" style={style}>
        <span className="cup">☕</span>
        <i className="steam s1" />
        <i className="steam s2" />
        <i className="steam s3" />
      </div>
    );
  }
  if (item === 'throw_kiss') {
    return (
      <div className="fx-impact kiss" style={style}>
        <span className="stamp">💋</span>
        {['❤️', '💕', '❤️'].map((h, i) => (
          <span key={i} className="heart" style={{ ['--i' as string]: i } as CSSProperties}>
            {h}
          </span>
        ))}
      </div>
    );
  }
  // Roses and bouquets: a burst of petals.
  const glyph = getItem(item)?.glyph ?? '🌹';
  return (
    <div className="fx-impact petals" style={style}>
      <span className="landed">{glyph}</span>
      {Array.from({ length: 8 }, (_, i) => (
        <i key={i} className="petal" style={{ ['--a' as string]: `${i * 45}deg` } as CSSProperties} />
      ))}
    </div>
  );
}

function BoomBanner({ name, mine }: { name: string; mine: boolean }) {
  const tt = useT();
  return (
    <div className={`fx-boom ${mine ? 'us' : 'them'}`}>
      <div className="fx-boom-word">💣 {tt('boom_shout')}</div>
      <div className="fx-boom-sub">{tt('boom_called', { name })}</div>
    </div>
  );
}

/** Two hands crossing the table as they're traded. */
function SwapFx({ from, to, backs }: { from: Pt; to: Pt; backs: [string, string] }) {
  const a = useRef<HTMLDivElement>(null);
  const b = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    const fly = (el: HTMLDivElement | null, p: Pt, q: Pt, lift: number) => {
      const mid = { x: (p.x + q.x) / 2, y: (p.y + q.y) / 2 + lift };
      el?.animate(
        [
          { transform: `translate(${p.x}px, ${p.y}px) scale(.6)`, opacity: 0 },
          { transform: `translate(${mid.x}px, ${mid.y}px) scale(1.15) rotate(180deg)`, opacity: 1, offset: 0.5 },
          { transform: `translate(${q.x}px, ${q.y}px) scale(.6) rotate(360deg)`, opacity: 0 },
        ],
        { duration: 850, easing: 'cubic-bezier(.4,0,.3,1)', fill: 'forwards' },
      );
    };
    fly(a.current, from, to, -60);
    fly(b.current, to, from, 60);
  }, [from, to]);
  return (
    <>
      {[a, b].map((ref, i) => (
        <div key={i} ref={ref} className="fx-swap-stack">
          {[0, 1, 2].map((k) => (
            <PlayingCard
              key={k}
              down
              back={backs[i]}
              face="face_classic"
              width={30}
              style={{ position: 'absolute', transform: `rotate(${(k - 1) * 12}deg)` }}
            />
          ))}
        </div>
      ))}
    </>
  );
}

function SlamFx({ at, effect, power, name, geo }: { at: Pt; effect: string; power: number; name: string; geo: Geo }) {
  const tt = useT();
  const size = geo.trickCard * (2 + power * 2);
  const style = { left: at.x, top: at.y, ['--size' as string]: `${size}px`, ['--p' as string]: power } as CSSProperties;
  return (
    <>
      {(effect === 'slam_lightning' || power > 0.45) && <div className={`fx-flash${effect === 'slam_lightning' ? '' : ' slam'}`} />}
      <div className="fx-slam-word" style={{ left: at.x, top: at.y - geo.trickCardH * 0.85, ['--p' as string]: power } as CSSProperties}>
        <b>{tt('slam_word')}</b>
        {name && <span>{name}</span>}
      </div>
      <div className={`fx-slam ${effect}`} style={style}>
        <i className="ring" />
        {effect === 'slam_quake' && <i className="ring late" />}
        {effect === 'slam_lightning' && (
          <svg className="bolt" viewBox="0 0 60 200" style={{ height: at.y + 20 }} preserveAspectRatio="none">
            <path d="M34 0 18 84h16L14 200 46 70H30L44 0z" fill="#fff9b0" stroke="#ffe23d" strokeWidth="3" />
          </svg>
        )}
        {effect === 'slam_quake' && (
          <svg className="cracks" viewBox="-100 -100 200 200">
            <path
              d="M0 0l22-12 14 6 30-20M0 0l-18-20-6-24-24-18M0 0l-26 10-20-4-30 16M0 0l8 28 22 10 8 30M0 0l-6 26-20 12"
              fill="none"
              stroke="rgba(10,10,10,.75)"
              strokeWidth="3"
              strokeLinecap="round"
            />
          </svg>
        )}
        {Array.from({ length: effect === 'slam_confetti' ? 22 : 10 }, (_, i) => (
          <i
            key={i}
            className="bit"
            style={{ ['--a' as string]: `${(i * 360) / (effect === 'slam_confetti' ? 22 : 10) + (i % 2) * 9}deg`, ['--i' as string]: i } as CSSProperties}
          />
        ))}
      </div>
    </>
  );
}
