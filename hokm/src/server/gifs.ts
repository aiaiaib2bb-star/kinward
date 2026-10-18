import { LIMITS } from '../shared/constants';
import type { Gif, Lang } from '../shared/protocol';

// GIF search goes through the server, for three reasons: the GIPHY key stays
// off phones, results are cached so a busy table doesn't burn the key's
// rate limit, and only GIFs that came back from our own (rating-filtered)
// search can be sent to a table, never an arbitrary link.

const KEY = process.env.GIPHY_API_KEY?.trim() ?? '';
const RATING = process.env.GIPHY_RATING?.trim() || 'pg-13';
const PAGE = 24;
const CACHE_MS = 10 * 60_000;

export const gifsEnabled = KEY.length > 0;

/** Every GIF handed out recently, by id: what a player may send. */
const vetted = new Map<string, Gif>();
const cache = new Map<string, { at: number; gifs: Gif[] }>();

function remember(gif: Gif) {
  vetted.delete(gif.id);
  vetted.set(gif.id, gif);
  if (vetted.size > 5000) vetted.delete(vetted.keys().next().value!);
}

export function vettedGif(id: unknown): Gif | undefined {
  return typeof id === 'string' ? vetted.get(id) : undefined;
}

function giphyUrl(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  try {
    const url = new URL(raw);
    return url.protocol === 'https:' && (url.hostname === 'giphy.com' || url.hostname.endsWith('.giphy.com')) ? url.toString() : null;
  } catch {
    return null;
  }
}

interface Rendition {
  url?: string;
  webp?: string;
  width?: string;
  height?: string;
}

function toGif(raw: { id?: unknown; images?: Record<string, Rendition> }): Gif | null {
  const id = typeof raw.id === 'string' && /^[A-Za-z0-9]{4,64}$/.test(raw.id) ? raw.id : null;
  const main = raw.images?.fixed_width;
  const small = raw.images?.fixed_width_small ?? main;
  if (!id || !main) return null;
  const url = giphyUrl(main.webp) ?? giphyUrl(main.url);
  const preview = giphyUrl(small?.webp) ?? giphyUrl(small?.url) ?? url;
  const w = Number(main.width);
  const h = Number(main.height);
  if (!url || !preview || !(w > 0) || !(h > 0)) return null;
  return { id, url, preview, w, h };
}

/** Searches GIPHY, or lists what's trending when the query is empty. */
export async function searchGifs(query: string, offset: number, lang: Lang): Promise<Gif[]> {
  if (!gifsEnabled) return [];
  const q = Array.from(query.trim().toLowerCase()).slice(0, LIMITS.gifQuery).join('');
  const off = Math.max(0, Math.min(240, Math.floor(offset) || 0));
  const cacheKey = `${lang}|${off}|${q}`;
  const hit = cache.get(cacheKey);
  if (hit && Date.now() - hit.at < CACHE_MS) {
    hit.gifs.forEach(remember);
    return hit.gifs;
  }
  const params = new URLSearchParams({ api_key: KEY, limit: String(PAGE), offset: String(off), rating: RATING, bundle: 'messaging_non_clips' });
  if (q) {
    params.set('q', q);
    params.set('lang', lang);
  }
  const res = await fetch(`https://api.giphy.com/v1/gifs/${q ? 'search' : 'trending'}?${params}`, { signal: AbortSignal.timeout(6000) });
  if (!res.ok) throw new Error(`GIPHY answered ${res.status}`);
  const body = (await res.json()) as { data?: unknown[] };
  const gifs = (Array.isArray(body.data) ? body.data : []).flatMap((d) => toGif(d as never) ?? []);
  gifs.forEach(remember);
  cache.set(cacheKey, { at: Date.now(), gifs });
  if (cache.size > 300) cache.delete(cache.keys().next().value!);
  return gifs;
}
