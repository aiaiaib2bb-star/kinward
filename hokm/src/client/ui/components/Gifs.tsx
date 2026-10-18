import { type CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import { LIMITS } from '../../../shared/constants';
import type { Gif } from '../../../shared/protocol';
import { sfx } from '../../audio/sfx';
import { buzz } from '../../fx/haptics';
import { useT } from '../../i18n';
import { net } from '../../net/socket';

const PAGE = 24;

/** Search GIPHY (trending when the box is empty) and pick one to send. */
export function GifPicker({ onPick }: { onPick: (gif: Gif) => void }) {
  const t = useT();
  const [query, setQuery] = useState('');
  const [gifs, setGifs] = useState<Gif[]>([]);
  const [state, setState] = useState<'loading' | 'ready' | 'error'>('loading');
  const [more, setMore] = useState(false);
  const seq = useRef(0);

  const load = useCallback(async (q: string, offset: number) => {
    const id = ++seq.current;
    if (!offset) setState('loading');
    const res = await net.searchGifs(q, offset);
    if (id !== seq.current) return;
    if (!res.ok) {
      setState('error');
      return;
    }
    const list = res.data ?? [];
    setGifs((prev) => (offset ? [...prev, ...list.filter((g) => !prev.some((p) => p.id === g.id))] : list));
    setMore(list.length >= PAGE);
    setState('ready');
  }, []);

  useEffect(() => {
    const q = query.trim();
    const timer = setTimeout(() => void load(q, 0), q ? 380 : 0);
    return () => clearTimeout(timer);
  }, [query, load]);

  return (
    <div className="gif-picker">
      <input
        className="text-input gif-search"
        value={query}
        dir="auto"
        maxLength={LIMITS.gifQuery}
        placeholder={t('gif_search')}
        enterKeyHint="search"
        onChange={(e) => setQuery(e.target.value)}
      />
      <div className="gif-scroll">
        <div className="gif-grid">
          {gifs.map((g) => (
            <button
              key={g.id}
              type="button"
              className="gif-cell"
              style={{ aspectRatio: `${g.w} / ${g.h}` } as CSSProperties}
              onClick={() => {
                sfx.play('pop');
                buzz('tap');
                onPick(g);
              }}
            >
              <img src={g.preview} alt="" loading="lazy" decoding="async" referrerPolicy="no-referrer" draggable={false} />
            </button>
          ))}
        </div>
        {state === 'loading' && (
          <div className="gif-note">
            <span className="spinner" />
          </div>
        )}
        {state === 'error' && <div className="gif-note muted">{t('gif_error')}</div>}
        {state === 'ready' && !gifs.length && <div className="gif-note muted">{t('gif_none')}</div>}
        {state === 'ready' && more && (
          <button type="button" className="btn btn-glass btn-small btn-block" onClick={() => void load(query.trim(), gifs.length)}>
            {t('gif_more')}
          </button>
        )}
      </div>
      <div className="giphy-credit">Powered by GIPHY</div>
    </div>
  );
}

/** A GIF in a chat bubble, sized before it loads so the list doesn't jump. */
export function GifImage({ gif, width }: { gif: Gif; width: number }) {
  const height = Math.round((width * gif.h) / gif.w);
  return (
    <img
      className="gif-img"
      src={gif.url}
      width={width}
      height={height}
      alt="GIF"
      loading="lazy"
      decoding="async"
      referrerPolicy="no-referrer"
      draggable={false}
    />
  );
}
