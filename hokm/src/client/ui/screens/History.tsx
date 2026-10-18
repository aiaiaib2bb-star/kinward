import type { GameRecord, RecordPlayer } from '../../../shared/protocol';
import { sfx } from '../../audio/sfx';
import { BOT_NAMES } from '../../i18n/strings';
import { fmt, useLang, useT } from '../../i18n';
import { net } from '../../net/socket';
import { go, useApp } from '../../state/app';
import { Coin, TopNav } from '../components/common';

function playerName(p: RecordPlayer | null, lang: 'en' | 'fa'): string {
  if (!p) return '—';
  if (p.bot) return `${BOT_NAMES[p.name]?.[lang] ?? p.name} 🤖`;
  return p.name;
}

/** "5 min ago", "Yesterday", or a date, in the reader's language. */
function when(at: number, lang: 'en' | 'fa'): string {
  const locale = lang === 'fa' ? 'fa-IR' : 'en-US';
  const rtf = new Intl.RelativeTimeFormat(locale, { numeric: 'auto' });
  const mins = Math.round((Date.now() - at) / 60_000);
  if (mins < 60) return rtf.format(-Math.max(1, mins), 'minute');
  const hours = Math.round(mins / 60);
  if (hours < 24) return rtf.format(-hours, 'hour');
  const days = Math.round(hours / 24);
  if (days < 7) return rtf.format(-days, 'day');
  return new Date(at).toLocaleDateString(locale, { day: 'numeric', month: 'short', year: days > 300 ? 'numeric' : undefined });
}

function GameRow({ g }: { g: GameRecord }) {
  const t = useT();
  const lang = useLang();
  const tags: string[] = [];
  if (g.reason === 'surrender') tags.push(g.won ? `🏳️ ${t('hist_they_surrendered')}` : `🏳️ ${t('hist_surrendered')}`);
  if (g.boom === 'won') tags.push(`💣 ${t('hist_boom_won')}`);
  if (g.boom === 'lost') tags.push(`💣 ${t('hist_boom_lost')}`);
  if (g.kots) tags.push(`🔥 ${t('hist_kots', { n: g.kots })}`);
  return (
    <div className={`hist-row ${g.won ? 'won' : 'lost'}`}>
      <div className="hist-badge">{g.won ? t('hist_win') : t('hist_loss')}</div>
      <div className="hist-main">
        <div className="hist-score ltr">
          <span className="us">{fmt(g.score[0])}</span>
          <span className="dash">–</span>
          <span className="them">{fmt(g.score[1])}</span>
          <span className="hist-when">{when(g.at, lang)}</span>
        </div>
        <div className="hist-people">
          <span>
            🤝 {t('hist_with')} <b>{playerName(g.partner, lang)}</b>
          </span>
          <span>
            ⚔️ {t('hist_vs')} <b>{g.opponents.map((o) => playerName(o, lang)).join(lang === 'fa' ? ' و ' : ' & ')}</b>
          </span>
        </div>
        {tags.length > 0 && (
          <div className="hist-tags">
            {tags.map((tag) => (
              <span key={tag}>{tag}</span>
            ))}
          </div>
        )}
      </div>
      <div className="hist-coins">
        <Coin size={16} />+{fmt(g.coins)}
      </div>
    </div>
  );
}

export function History() {
  const t = useT();
  const profile = useApp((s) => s.profile)!;
  const s = profile.stats;
  const rate = s.played ? Math.round((s.won / s.played) * 100) : 0;
  const summary: [string, string][] = [
    [t('stat_played'), fmt(s.played)],
    [t('stat_won'), fmt(s.won)],
    [t('stat_lost'), fmt(s.lost)],
    [t('stat_rate'), `${fmt(rate)}%`],
    [t('stat_streak'), fmt(s.bestStreak)],
    [t('stat_booms'), fmt(s.booms)],
  ];
  return (
    <div className="screen">
      <div className="screen-inner">
        <TopNav title={t('history_title')} onBack={() => go('home')} />
        <div className="hist-summary">
          {summary.map(([k, v]) => (
            <div key={k} className="stat">
              <div className="v">{v}</div>
              <div className="k">{k}</div>
            </div>
          ))}
        </div>
        <div className="section-title">{t('history_recent')}</div>
        {profile.history.length === 0 ? (
          <div className="panel empty-state">
            <div style={{ fontSize: 44 }}>🃏</div>
            <p>{s.played ? t('history_empty_old') : t('history_empty')}</p>
            <button
              type="button"
              className="btn btn-gold"
              onClick={() => {
                sfx.play('click');
                go('home');
                void net.createRoom({ practice: true });
              }}
            >
              {t('play_computer')}
            </button>
          </div>
        ) : (
          <div className="hist-list">
            {profile.history.map((g) => (
              <GameRow key={g.at} g={g} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
