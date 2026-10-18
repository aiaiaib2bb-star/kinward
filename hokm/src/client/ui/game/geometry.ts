import { type RefObject, useLayoutEffect, useState } from 'react';

export interface Pt {
  x: number;
  y: number;
}

/**
 * Where everything sits on the table, in pixels from the top-left of the
 * game screen. Positions are indexed by seat *relative to you*: 0 is you at
 * the bottom, then counter-clockwise like the turn order — 1 on your right,
 * 2 your partner across the table, 3 on your left.
 */
export interface Geo {
  w: number;
  h: number;
  safe: { t: number; b: number; l: number; r: number };
  topBarBottom: number;
  handCard: number;
  handCardH: number;
  /** Top edge of the middle card in your hand. */
  handTop: number;
  myBarY: number;
  trickCard: number;
  trickCardH: number;
  center: Pt;
  seats: Pt[];
  slots: Pt[];
  /** Where a seat's hand of face-down cards is drawn. */
  fans: Pt[];
  landscape: boolean;
}

function readSafeArea(): Geo['safe'] {
  const probe = document.createElement('div');
  probe.style.cssText =
    'position:fixed;visibility:hidden;pointer-events:none;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
  document.body.appendChild(probe);
  const cs = getComputedStyle(probe);
  const safe = {
    t: parseFloat(cs.paddingTop) || 0,
    r: parseFloat(cs.paddingRight) || 0,
    b: parseFloat(cs.paddingBottom) || 0,
    l: parseFloat(cs.paddingLeft) || 0,
  };
  probe.remove();
  return safe;
}

const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));

export function computeGeo(w: number, h: number, safe: Geo['safe']): Geo {
  const landscape = w > h * 1.15;
  const topBarBottom = safe.t + 68;
  const handCard = Math.round(landscape ? clamp(h * 0.19, 48, 84) : clamp(Math.min(w * 0.195, h * 0.112), 52, 96));
  const handCardH = Math.round(handCard * 1.42);
  // Leave room under the fan for its curve and for the phone's home bar.
  const handTop = h - Math.max(safe.b, 6) - 10 - handCardH * 1.07;
  const myBarY = landscape ? handTop - 26 : handTop - 32;
  const tableTop = topBarBottom + 4;
  const tableBottom = landscape ? handTop - 4 : myBarY - 28;
  const tableH = Math.max(160, tableBottom - tableTop);
  const center = { x: w / 2, y: tableTop + tableH * (landscape ? 0.5 : 0.55) };
  const trickCard = Math.round(clamp(Math.min(w * 0.18, tableH * 0.22), 46, 90));
  const trickCardH = Math.round(trickCard * 1.42);
  // Room for the bigger avatars and their name tags at the sides.
  const sideX = Math.max(46, Math.min(w * 0.135, 72));
  const seats: Pt[] = [
    { x: safe.l + 39, y: myBarY },
    { x: w - safe.r - sideX, y: center.y - tableH * 0.12 },
    { x: w / 2, y: tableTop + (landscape ? 36 : 46) },
    { x: safe.l + sideX, y: center.y - tableH * 0.12 },
  ];
  const dy = trickCardH * 0.36;
  const dx = trickCard * 0.64;
  const slots: Pt[] = [
    { x: center.x, y: center.y + dy },
    { x: center.x + dx, y: center.y },
    { x: center.x, y: center.y - dy },
    { x: center.x - dx, y: center.y },
  ];
  const fans: Pt[] = [
    { x: w / 2, y: handTop },
    { x: seats[1].x, y: seats[1].y + 76 },
    { x: seats[2].x, y: seats[2].y + 76 },
    { x: seats[3].x, y: seats[3].y + 76 },
  ];
  return { w, h, safe, topBarBottom, handCard, handCardH, handTop, myBarY, trickCard, trickCardH, center, seats, slots, fans, landscape };
}

export function useGeometry(ref: RefObject<HTMLElement | null>): Geo | null {
  const [geo, setGeo] = useState<Geo | null>(null);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    let safe = readSafeArea();
    const measure = () => {
      const r = el.getBoundingClientRect();
      if (r.width && r.height) setGeo(computeGeo(r.width, r.height, safe));
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    const onOrient = () => {
      safe = readSafeArea();
      measure();
    };
    window.addEventListener('orientationchange', onOrient);
    return () => {
      ro.disconnect();
      window.removeEventListener('orientationchange', onOrient);
    };
  }, [ref]);
  return geo;
}

/** A small, stable tilt for a card on the table, so tricks look dropped rather than placed. */
export function tiltFor(card: string, rel: number): number {
  let h = rel * 7;
  for (let i = 0; i < card.length; i++) h = (h * 31 + card.charCodeAt(i)) % 997;
  return (h % 15) - 7 + (rel === 1 ? 4 : rel === 3 ? -4 : 0);
}
