import { type CSSProperties, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { botChooseTrump } from '../../../shared/bot';
import { type Card, SUITS, type Suit, rankOf, suitOf } from '../../../shared/cards';
import { T } from '../../../shared/constants';
import type { GameView, RoomView } from '../../../shared/protocol';
import { dealOrder } from '../../../shared/rules';
import { sfx } from '../../audio/sfx';
import { buzz } from '../../fx/haptics';
import { displayName, useLang, useT } from '../../i18n';
import { toLocal } from '../../net/clock';
import { net } from '../../net/socket';
import { seatMember } from '../../state/selectors';
import { settings } from '../../state/settings';
import { backStyle } from '../../cosmetics/patterns';
import { CardBack, PlayingCard, SuitIcon } from '../components/Card';
import type { Geo, Pt } from './geometry';

// ——— Deal timing, shared by the flying cards and the hand that fills up ———

interface DealCard {
  seat: number;
  start: number;
  land: number;
}

export function dealSchedule(stage: 1 | 2, hakem: number): DealCard[] {
  const order = dealOrder(hakem);
  const out: DealCard[] = [];
  if (stage === 1) {
    order.forEach((seat, p) => {
      for (let k = 0; k < 5; k++) {
        const start = p * T.dealPacketGap1 + k * T.dealCardGap;
        out.push({ seat, start, land: start + T.dealFlight });
      }
    });
  } else {
    for (let round = 0; round < 2; round++) {
      order.forEach((seat, p) => {
        for (let k = 0; k < 4; k++) {
          const start = T.trumpAnnounce + (round * 4 + p) * T.dealPacketGap2 + k * T.dealCardGap;
          out.push({ seat, start, land: start + T.dealFlight });
        }
      });
    }
  }
  return out;
}

/** How many cards each seat holds right now, counting only those that have landed. Re-renders as they land. */
export function useDealCounts(game: GameView): number[] | null {
  const dealing = game.phase === 'deal1' || game.phase === 'deal2';
  const [, tick] = useState(0);
  const start = toLocal(game.phaseStartedAt);
  const schedule = useMemo(
    () => (dealing && game.hakem !== null ? dealSchedule(game.phase === 'deal1' ? 1 : 2, game.hakem) : null),
    [dealing, game.phase, game.hakem],
  );
  const elapsed = Date.now() - start;
  useEffect(() => {
    if (!schedule) return;
    const next = schedule
      .map((c) => c.land)
      .filter((l) => l > elapsed)
      .sort((a, b) => a - b)[0];
    if (next === undefined) return;
    const id = setTimeout(() => tick((n) => n + 1), next - elapsed + 5);
    return () => clearTimeout(id);
  });
  if (!schedule) return null;
  const base = game.phase === 'deal1' ? 0 : 5;
  const counts = [base, base, base, base];
  for (const c of schedule) if (c.land <= elapsed) counts[c.seat] += 1;
  return counts;
}

/** Card backs flying from the deck to each player. */
export function DealLayer({ game, geo, rel, back }: { game: GameView; geo: Geo; rel: (s: number) => number; back: string }) {
  const stage = game.phase === 'deal1' ? 1 : 2;
  const schedule = useMemo(() => (game.hakem === null ? [] : dealSchedule(stage, game.hakem)), [stage, game.hakem]);
  const start = toLocal(game.phaseStartedAt);
  const cw = Math.round(geo.trickCard * 0.72);
  const ch = cw * 1.42;
  const [layerKey] = useState(() => `${game.phaseStartedAt}`);

  useEffect(() => {
    const elapsed = Date.now() - start;
    const timers = schedule.filter((c) => c.start >= elapsed).map((c) => window.setTimeout(() => sfx.play('deal'), c.start - elapsed));
    return () => timers.forEach(clearTimeout);
  }, [schedule, start]);

  const remaining = schedule.length;
  const lastStart = schedule.length ? schedule[schedule.length - 1].start : 0;
  const elapsedNow = Date.now() - start;
  return (
    <div className="deal-layer" key={layerKey}>
      <div
        className="deck-pile"
        style={
          {
            left: geo.center.x - cw / 2,
            top: geo.center.y - ch / 2,
            ['--cw' as string]: `${cw}px`,
            animationDuration: `${lastStart + 80}ms`,
            animationDelay: `-${Math.min(elapsedNow, lastStart)}ms`,
          } as CSSProperties
        }
      >
        <div className="card deck-depth" style={{ ['--cw' as string]: `${cw}px` } as CSSProperties}>
          <CardBack back={back} />
        </div>
      </div>
      {schedule.map((c, i) => (
        <FlyingBack key={i} card={c} start={start} geo={geo} to={c.seat} rel={rel} back={back} cw={cw} total={remaining} />
      ))}
    </div>
  );
}

function FlyingBack({
  card,
  start,
  geo,
  to,
  rel,
  back,
  cw,
}: {
  card: DealCard;
  start: number;
  geo: Geo;
  to: number;
  rel: (s: number) => number;
  back: string;
  cw: number;
  total: number;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const ch = cw * 1.42;
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const elapsed = Date.now() - start;
    if (card.land <= elapsed) {
      el.style.display = 'none';
      return;
    }
    const r = rel(to);
    const target: Pt = r === 0 ? { x: geo.w / 2 + (Math.random() - 0.5) * geo.handCard * 2, y: geo.handTop + geo.handCardH / 2 } : geo.fans[r];
    const from = `translate(${geo.center.x - cw / 2}px, ${geo.center.y - ch / 2}px) rotate(0deg) scale(1)`;
    const spin = (Math.random() - 0.5) * 40 + (r === 1 ? 90 : r === 3 ? -90 : 0);
    const endScale = r === 0 ? geo.handCard / cw : 0.5;
    const to2 = `translate(${target.x - cw / 2}px, ${target.y - ch / 2}px) rotate(${spin}deg) scale(${endScale})`;
    // Invisible until its turn to fly; the deck pile stands in for it until then.
    const anim = el.animate(
      [
        { transform: from, opacity: 0 },
        { transform: from, opacity: 1, offset: 0.01 },
        { transform: to2, opacity: r === 0 ? 0.2 : 0 },
      ],
      {
        duration: T.dealFlight,
        delay: Math.max(0, card.start - elapsed),
        easing: 'cubic-bezier(.3,.6,.3,1)',
        fill: 'both',
      },
    );
    anim.onfinish = () => {
      el.style.display = 'none';
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return (
    <div ref={ref} className="flying-back card" style={{ ['--cw' as string]: `${cw}px` } as CSSProperties}>
      <CardBack back={back} />
    </div>
  );
}

// ——— Choosing the first hakem ———

export function HakemSelect({
  game,
  geo,
  rel,
  room,
  face,
  fourColor,
  mySeat,
}: {
  game: GameView;
  geo: Geo;
  rel: (s: number) => number;
  room: RoomView;
  face: string;
  fourColor: boolean;
  mySeat: number | null;
}) {
  const t = useT();
  const lang = useLang();
  const start = toLocal(game.phaseStartedAt);
  const [now, setNow] = useState(Date.now());
  const reveals = game.hakemReveals;
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 80);
    return () => clearInterval(id);
  }, []);
  const shown = Math.max(0, Math.min(reveals.length, Math.floor((now - start) / T.hakemRevealStep) + 1));
  const prevShown = useRef(0);
  useEffect(() => {
    if (shown > prevShown.current) {
      const last = reveals[shown - 1];
      if (shown === reveals.length && last && rankOf(last.card) === 14) {
        setTimeout(() => {
          sfx.play('stamp');
          sfx.play('win');
          buzz('win');
        }, 300);
      } else sfx.play('deal');
    }
    prevShown.current = shown;
  }, [shown, reveals]);

  const cw = Math.round(geo.trickCard * 0.78);
  const perSeat = [0, 0, 0, 0];
  const finished = shown === reveals.length;
  const winner = reveals[reveals.length - 1];
  const name = winner ? (winner.seat === mySeat ? null : displayName(seatMember(room, winner.seat)?.profile, lang)) : '';
  return (
    <div className="stage-layer">
      {reveals.slice(0, shown).map((r, i) => {
        const k = perSeat[r.seat]++;
        const seatPos = geo.seats[rel(r.seat)];
        const target = { x: geo.center.x + (seatPos.x - geo.center.x) * 0.48 + k * 3, y: geo.center.y + (seatPos.y - geo.center.y) * 0.48 + k * 2 };
        const isAce = finished && i === reveals.length - 1;
        return <RevealCard key={i} card={r.card} from={geo.center} to={target} cw={cw} face={face} fourColor={fourColor} ace={isAce} />;
      })}
      <div className="stage-banner" style={{ top: geo.center.y - 18 }}>
        {finished && winner && now - start > reveals.length * T.hakemRevealStep ? (
          <span className="pop">👑 {name === null ? t('you_are_hakem') : t('is_hakem', { name })}</span>
        ) : (
          <span>{t('picking_hakem')}</span>
        )}
      </div>
    </div>
  );
}

function RevealCard({
  card,
  from,
  to,
  cw,
  face,
  fourColor,
  ace,
}: {
  card: Card;
  from: Pt;
  to: Pt;
  cw: number;
  face: string;
  fourColor: boolean;
  ace: boolean;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const ch = cw * 1.42;
  const final = `translate(${to.x - cw / 2}px, ${to.y - ch / 2}px) rotate(${((card.charCodeAt(1) * 7) % 20) - 10}deg)`;
  useLayoutEffect(() => {
    ref.current?.animate([{ transform: `translate(${from.x - cw / 2}px, ${from.y - ch / 2}px) scale(.6)` }, { transform: final }], {
      duration: settings.get().reduceMotion ? 80 : 300,
      easing: 'cubic-bezier(.2,.75,.25,1)',
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return (
    <div ref={ref} className={`trick-card${ace ? ' winning ace-reveal' : ''}`} style={{ transform: final, zIndex: ace ? 30 : 5 }}>
      <PlayingCard card={card} face={face} fourColor={fourColor} width={cw} />
    </div>
  );
}

// ——— The deck: shuffling and cutting ———

const DECK_LINES = 52;

export function DeckStage({ game, geo, room, mySeat, back }: { game: GameView; geo: Geo; room: RoomView; mySeat: number | null; back: string }) {
  const t = useT();
  const lang = useLang();
  const shuffling = game.phase === 'shuffle';
  const actor = shuffling ? game.hakem : game.cutter;
  const mine = actor !== null && actor === mySeat;
  const actorName = displayName(seatMember(room, actor ?? -1)?.profile, lang);
  const op = game.deckOps.last;
  const [anim, setAnim] = useState<{ kind: 'riffle' | 'cut'; frac: number; seq: number } | null>(null);
  const lastSeq = useRef(op?.seq ?? 0);
  const animTimer = useRef<number | null>(null);
  const [busyUntil, setBusyUntil] = useState(0);

  // Each new deck move on the server plays its animation once, for everyone.
  useEffect(() => {
    if (!op || op.seq === lastSeq.current) return;
    lastSeq.current = op.seq;
    const frac = op.kind === 'cut' && op.count && op.of ? op.count / op.of : 0.5;
    setAnim({ kind: op.kind, frac, seq: op.seq });
    sfx.play(op.kind === 'riffle' ? 'riffle' : 'cut');
    buzz('tap');
    if (animTimer.current) clearTimeout(animTimer.current);
    const seq = op.seq;
    animTimer.current = window.setTimeout(() => setAnim((a) => (a?.seq === seq ? null : a)), op.kind === 'riffle' ? 700 : T.cutAnim + 60);
  }, [op]);
  useEffect(() => () => void (animTimer.current && clearTimeout(animTimer.current)), []);

  const cw = Math.round(geo.trickCard * 1.05);
  const doOp = (kind: 'riffle' | 'cut') => {
    if (Date.now() < busyUntil) return;
    setBusyUntil(Date.now() + T.shuffleOp);
    net.shuffle(kind);
  };

  return (
    <div className="stage-layer deck-stage">
      <div className="deck-zone" style={{ left: geo.center.x, top: geo.center.y }}>
        {shuffling ? <ShuffleDeck back={back} cw={cw} anim={anim} /> : <CutDeck back={back} cw={cw} anim={anim} interactive={mine} />}
      </div>
      <div className="stage-panel" style={{ top: geo.center.y + cw * 0.95 + 14 }}>
        {shuffling ? (
          mine ? (
            <>
              <div className="stage-title">{t('you_shuffle')}</div>
              <div className="stage-buttons">
                <button type="button" className="btn btn-turq btn-small" onClick={() => doOp('riffle')}>
                  🔀 {t('riffle')}
                </button>
                <button type="button" className="btn btn-glass btn-small" onClick={() => doOp('cut')}>
                  ✂️ {t('cut')}
                </button>
                <button
                  type="button"
                  className="btn btn-gold btn-small"
                  onClick={() => {
                    sfx.play('click');
                    net.shuffleDone();
                  }}
                >
                  ✅ {t('done_shuffle')}
                </button>
              </div>
            </>
          ) : (
            <div className="stage-title">{t('shuffling', { name: actorName })}</div>
          )
        ) : mine ? (
          <>
            <div className="stage-title">{game.deckOps.cuts ? t('cut_count', { n: op?.count ?? 0 }) : t('you_cut')}</div>
            <div className="stage-buttons">
              {!game.deckOps.cuts && (
                <button type="button" className="btn btn-glass btn-small" onClick={() => net.cut(20 + Math.floor(Math.random() * 13))}>
                  ✂️ {t('quick_cut')}
                </button>
              )}
              {game.deckOps.cuts > 0 && (
                <button
                  type="button"
                  className="btn btn-gold btn-small"
                  onClick={() => {
                    sfx.play('click');
                    net.cutDone();
                  }}
                >
                  🎴 {t('deal')}
                </button>
              )}
            </div>
          </>
        ) : (
          <div className="stage-title">{t('cutting', { name: actorName })}</div>
        )}
      </div>
      {game.deckOps.shuffles > 0 && (
        <div className="stage-sub deck-count" style={{ left: geo.center.x, top: geo.center.y - cw * 0.95 - 30 }}>
          {t('shuffled_n', { n: game.deckOps.shuffles })}
        </div>
      )}
    </div>
  );
}

function ShuffleDeck({ back, cw, anim }: { back: string; cw: number; anim: { kind: string; frac: number; seq: number } | null }) {
  const style = { ['--cw' as string]: `${cw}px` } as CSSProperties;
  const kind = anim?.kind;
  return (
    <div className={`shuffle-deck${kind ? ` anim-${kind}` : ''}`} key={anim?.seq ?? 0} style={style}>
      <div className="card half bottom">
        <CardBack back={back} />
      </div>
      <div className="card half top">
        <CardBack back={back} />
      </div>
      {kind === 'riffle' &&
        Array.from({ length: 10 }, (_, i) => (
          <div key={i} className={`sliver ${i % 2 ? 'r' : 'l'}`} style={{ animationDelay: `${150 + i * 32}ms` } as CSSProperties} />
        ))}
    </div>
  );
}

/** The deck seen edge-on. The cutter drags down it to choose how many cards to lift. */
function CutDeck({
  back,
  cw,
  anim,
  interactive,
}: {
  back: string;
  cw: number;
  anim: { kind: string; frac: number; seq: number } | null;
  interactive: boolean;
}) {
  const t = useT();
  const [pick, setPick] = useState<number | null>(null);
  const box = useRef<HTMLDivElement>(null);
  const lastBuzz = useRef(0);
  const width = Math.round(cw * 1.2);
  const height = Math.round(cw * 1.25);

  const countAt = (clientY: number) => {
    const r = box.current!.getBoundingClientRect();
    return Math.max(4, Math.min(48, Math.round(((clientY - r.top) / r.height) * DECK_LINES)));
  };

  const onDown = (e: React.PointerEvent) => {
    if (!interactive || anim) return;
    e.currentTarget.setPointerCapture(e.pointerId);
    const k = countAt(e.clientY);
    lastBuzz.current = k;
    setPick(k);
    sfx.play('select');
    buzz('select');
  };
  const onMove = (e: React.PointerEvent) => {
    if (pick === null) return;
    const k = countAt(e.clientY);
    if (k === pick) return;
    setPick(k);
    if (Math.abs(k - lastBuzz.current) >= 2) {
      lastBuzz.current = k;
      buzz('tick');
      sfx.play('select');
    }
  };
  const onUp = () => {
    if (pick === null) return;
    net.cut(pick);
    setPick(null);
  };

  const cutting = anim?.kind === 'cut';
  const frac = cutting ? anim!.frac : pick !== null ? pick / DECK_LINES : null;
  const topH = frac !== null ? Math.round(frac * height) : 0;
  const lid = { background: backStyle(back).background };
  return (
    <div
      ref={box}
      className={`cut-deck${interactive ? ' interactive' : ''}${pick !== null ? ' picking' : ''}${cutting ? ' cutting' : ''}`}
      key={anim?.seq ?? 'idle'}
      style={
        {
          width,
          height,
          ['--line' as string]: `${height / DECK_LINES}px`,
          ['--top-h' as string]: `${topH}px`,
          ['--bot-h' as string]: `${height - topH}px`,
        } as CSSProperties
      }
      onPointerDown={onDown}
      onPointerMove={onMove}
      onPointerUp={onUp}
      onPointerCancel={() => setPick(null)}
    >
      {frac === null ? (
        <div className="cut-block" style={{ top: 0, height }}>
          <div className="cut-lid" style={lid} />
        </div>
      ) : (
        <>
          <div className="cut-block upper" style={{ top: 0, height: topH }}>
            <div className="cut-lid" style={lid} />
          </div>
          <div className="cut-block lower" style={{ top: topH, height: height - topH }}>
            <div className="cut-lid" style={lid} />
          </div>
          {pick !== null && (
            <div className="cut-marker" style={{ top: topH }}>
              <span>✂️ {t('cut_count', { n: pick })}</span>
            </div>
          )}
        </>
      )}
      {interactive && pick === null && !cutting && <div className="cut-hint">👆</div>}
    </div>
  );
}

// ——— Calling the hokm ———

export function TrumpPicker({ hand }: { hand: Card[] }) {
  const t = useT();
  const firstFive = hand.slice(0, 5);
  const suggestion = firstFive.length ? botChooseTrump(firstFive) : null;
  const pick = (s: Suit) => {
    sfx.play('stamp');
    buzz('slam');
    net.trump(s);
  };
  return (
    <div className="trump-picker">
      <div className="tp-title">👑 {t('choose_hokm')}</div>
      <div className="tp-sub">{t('choose_hokm_sub')}</div>
      <div className="tp-suits">
        {SUITS.map((s) => {
          const n = firstFive.filter((c) => suitOf(c) === s).length;
          return (
            <button key={s} type="button" className={`tp-suit suit-${s}${s === suggestion ? ' suggested' : ''}`} onClick={() => pick(s)}>
              <SuitIcon suit={s} />
              <span className="tp-name">{t(`suit_${s}`)}</span>
              <span className="tp-count">×{n}</span>
              {s === suggestion && <span className="tp-star">★ {t('recommended')}</span>}
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function TrumpWaiting({ name }: { name: string }) {
  const t = useT();
  return (
    <div className="trump-waiting">
      <div className="tw-suits">
        {SUITS.map((s, i) => (
          <span key={s} className="tw-suit" style={{ animationDelay: `${i * 180}ms` }}>
            <SuitIcon suit={s} size={34} color={s === 'H' || s === 'D' ? '#ff5d73' : '#f6f3ec'} />
          </span>
        ))}
      </div>
      <div>{t('choosing_hokm', { name })}</div>
    </div>
  );
}

export function TrumpAnnounce({ suit, game }: { suit: Suit; game: GameView }) {
  const t = useT();
  const [show, setShow] = useState(() => Date.now() - toLocal(game.phaseStartedAt) < T.trumpAnnounce);
  useEffect(() => {
    if (!show) return;
    sfx.play('stamp');
    buzz('slam');
    const id = setTimeout(() => setShow(false), Math.max(0, T.trumpAnnounce - (Date.now() - toLocal(game.phaseStartedAt))));
    return () => clearTimeout(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  if (!show) return null;
  return (
    <div className={`trump-announce suit-${suit}`}>
      <SuitIcon suit={suit} />
      <div className="ta-text">{t('trump_is', { suit: t(`suit_${suit}`) })}</div>
    </div>
  );
}
