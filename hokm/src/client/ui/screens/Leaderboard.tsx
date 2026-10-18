import { useEffect, useState } from 'react';
import { levelTitle } from '../../../shared/constants';
import type { LeaderboardEntry, LeaderboardView } from '../../../shared/protocol';
import { sfx } from '../../audio/sfx';
import { fmt, useLang, useT } from '../../i18n';
import { net } from '../../net/socket';
import { go } from '../../state/app';
import { Avatar } from '../components/Avatar';
import { Crest, Crown, GlobeIcon, PeopleIcon, TrophyIcon } from '../components/Icons';

type Period = LeaderboardView['period'];
type Scope = LeaderboardView['scope'];

function Wins({ n }: { n: number }) {
  return (
    <span className="lb-wins">
      <span className="lb-trophy">
        <TrophyIcon size={15} />
      </span>
      {fmt(n)}
    </span>
  );
}

function Podium({ entry, place }: { entry: LeaderboardEntry | undefined; place: 1 | 2 | 3 }) {
  const metal = place === 1 ? 'gold' : place === 2 ? 'silver' : 'bronze';
  if (!entry) return <div className={`podium p${place} empty`} />;
  return (
    <div className={`podium p${place} ${metal}`}>
      <div className="podium-crown">
        <Crown size={place === 1 ? 46 : 36} metal={metal} />
      </div>
      <div className="podium-avatar">
        <Avatar profile={{ id: entry.id, level: entry.level, equipped: entry.equipped }} size={place === 1 ? 84 : 66} />
        <span className="podium-rank">{fmt(place)}</span>
      </div>
      <div className="podium-name">{entry.name}</div>
      <Wins n={entry.won} />
    </div>
  );
}

function Row({ entry, you }: { entry: LeaderboardEntry; you?: boolean }) {
  const lang = useLang();
  const t = useT();
  return (
    <div className={`lb-row${you ? ' you' : ''}`}>
      <span className="lb-rank">{fmt(entry.rank)}</span>
      <Avatar profile={{ id: entry.id, level: entry.level, equipped: entry.equipped }} size={46} />
      <span className="lb-who">
        <b>{entry.name}</b>
        <small>
          {levelTitle(entry.level)[lang]} · {t('lb_played', { n: entry.played })}
        </small>
      </span>
      <Wins n={entry.won} />
    </div>
  );
}

export function Leaderboard() {
  const t = useT();
  const [period, setPeriod] = useState<Period>('all');
  const [scope, setScope] = useState<Scope>('global');
  const [view, setView] = useState<LeaderboardView | null>(null);
  const [state, setState] = useState<'loading' | 'ready' | 'error'>('loading');

  useEffect(() => {
    let live = true;
    setState('loading');
    void net.leaderboard(period, scope).then((res) => {
      if (!live) return;
      if (res.ok && res.data) {
        setView(res.data);
        setState('ready');
      } else setState('error');
    });
    return () => {
      live = false;
    };
  }, [period, scope]);

  const entries = state === 'ready' && view ? view.entries : [];
  const [first, second, third] = entries;
  const rest = entries.slice(3);
  const you = view?.you;
  const youShown = you && you.rank <= 3;

  return (
    <div className="screen leaderboard">
      <div className="screen-inner">
        <header className="lb-head">
          <button type="button" className="icon-btn round-gold" onClick={() => go('home')} aria-label={t('back')}>
            <svg viewBox="0 0 24 24" width="22" height="22" className="flip-rtl">
              <path d="M15 5l-7 7 7 7" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </button>
          <Crest compact />
          <label className="period-pill">
            <select
              value={period}
              onChange={(e) => {
                sfx.play('click');
                setPeriod(e.target.value as Period);
              }}
            >
              <option value="all">{t('lb_all_time')}</option>
              <option value="week">{t('lb_this_week')}</option>
            </select>
            <svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true">
              <path d="M6 9l6 6 6-6" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
            </svg>
          </label>
        </header>

        <div className="lb-tabs" role="tablist">
          {(
            [
              ['global', <GlobeIcon key="g" size={22} />, t('lb_global')],
              ['played', <PeopleIcon key="p" size={22} />, t('lb_played_with')],
            ] as const
          ).map(([id, icon, label]) => (
            <button
              key={id}
              type="button"
              role="tab"
              aria-selected={scope === id}
              className={scope === id ? 'active' : ''}
              onClick={() => {
                sfx.play('click');
                setScope(id);
              }}
            >
              {icon}
              {label}
            </button>
          ))}
        </div>

        {state === 'loading' && (
          <div className="lb-note">
            <span className="spinner" />
          </div>
        )}
        {state === 'error' && <div className="lb-note muted">{t('lb_error')}</div>}
        {state === 'ready' && entries.length === 0 && (
          <div className="panel empty-state">
            <div style={{ fontSize: 44 }}>🏆</div>
            <p>{scope === 'played' ? t('lb_empty_played') : t('lb_empty')}</p>
          </div>
        )}

        {entries.length > 0 && (
          <>
            <div className="podiums">
              <Podium entry={second} place={2} />
              <Podium entry={first} place={1} />
              <Podium entry={third} place={3} />
            </div>
            <div className="lb-list">
              {rest.map((e) => (
                <Row key={e.id} entry={e} you={e.id === you?.id} />
              ))}
            </div>
          </>
        )}

        {state === 'ready' && view && (
          <div className="lb-you">
            <div className="lb-you-label">{t('lb_your_rank')}</div>
            {you ? (
              <Row entry={you} you />
            ) : (
              <p className="muted" style={{ margin: '4px 0 0' }}>
                {period === 'week' ? t('lb_you_none_week') : t('lb_you_none')}
              </p>
            )}
            {youShown && <div className="lb-you-cheer">{t('lb_podium_you')}</div>}
          </div>
        )}
        <p className="lb-foot muted">{t('lb_foot', { n: view?.total ?? 0 })}</p>
      </div>
    </div>
  );
}
