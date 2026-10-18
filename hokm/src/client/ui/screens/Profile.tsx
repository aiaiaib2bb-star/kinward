import { useState } from 'react';
import { LIMITS, levelOf, xpForLevel } from '../../../shared/constants';
import { sfx } from '../../audio/sfx';
import { fmt, useT } from '../../i18n';
import { getToken, net } from '../../net/socket';
import { go, toast, useApp } from '../../state/app';
import { publicOf } from '../../state/selectors';
import { Avatar } from '../components/Avatar';
import { CoinAmount, Dialog, TopNav } from '../components/common';
import { copyText } from '../components/share';

export function Profile() {
  const t = useT();
  const profile = useApp((s) => s.profile)!;
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(profile.name);
  const [restoreCode, setRestoreCode] = useState('');
  const level = levelOf(profile.xp);
  const into = profile.xp - xpForLevel(level);
  const span = xpForLevel(level + 1) - xpForLevel(level);
  const s = profile.stats;
  const rate = s.played ? Math.round((s.won / s.played) * 100) : 0;

  const stats: [string, string][] = [
    [t('stat_played'), fmt(s.played)],
    [t('stat_won'), fmt(s.won)],
    [t('stat_rate'), `${fmt(rate)}%`],
    [t('stat_streak'), fmt(s.bestStreak)],
    [t('stat_kots'), fmt(s.kots)],
    [t('stat_hakemKots'), fmt(s.hakemKots)],
    [t('stat_hakem'), fmt(s.timesHakem)],
    [t('stat_slams'), fmt(s.slams)],
    [t('stat_coins'), fmt(s.coinsEarned)],
  ];

  const saveName = async () => {
    if (name.trim() && name.trim() !== profile.name) await net.rename(name.trim());
    setEditing(false);
  };

  const restore = async () => {
    if (!restoreCode.trim()) return;
    const ok = await net.restore(restoreCode);
    if (!ok) {
      sfx.play('error');
      toast(t('restore_bad'), 'bad');
    }
  };

  return (
    <div className="screen">
      <div className="screen-inner">
        <TopNav title={t('profile_title')} onBack={() => go('home')} />
        <div className="profile-head">
          <Avatar profile={publicOf(profile)} size={104} showLevel />
          <div className="p-name">
            {profile.name}
            <button
              type="button"
              className="icon-btn"
              style={{ width: 34, height: 34, fontSize: 15 }}
              onClick={() => setEditing(true)}
              aria-label={t('edit_name')}
            >
              ✏️
            </button>
          </div>
          <div className="muted">
            {t('level', { n: level })} · {t('xp_to_next', { n: span - into, l: level + 1 })}
          </div>
          <div className="xp-bar" style={{ width: 200 }}>
            <i style={{ width: `${Math.min(100, (into / span) * 100)}%` }} />
          </div>
          <span className="coin-pill">
            <CoinAmount value={profile.coins} size={20} />
          </span>
        </div>

        <div className="section-title">{t('stats')}</div>
        <div className="stats-grid">
          {stats.map(([k, v]) => (
            <div key={k} className="stat">
              <div className="v">{v}</div>
              <div className="k">{k}</div>
            </div>
          ))}
        </div>

        <div className="section-title">{t('backup')}</div>
        <div className="panel backup-box">
          <p>{t('backup_sub')}</p>
          <button type="button" className="btn btn-glass btn-block" onClick={() => copyText(getToken() ?? '')}>
            📋 {t('copy_backup')}
          </button>
          <div style={{ display: 'flex', gap: 8 }}>
            <input
              className="text-input"
              style={{ fontSize: 14, height: 48 }}
              value={restoreCode}
              placeholder={t('restore_placeholder')}
              onChange={(e) => setRestoreCode(e.target.value)}
            />
            <button type="button" className="btn btn-turq" onClick={restore} disabled={!restoreCode.trim()}>
              {t('restore')}
            </button>
          </div>
        </div>
      </div>

      <Dialog open={editing} onClose={() => setEditing(false)}>
        <h2>{t('edit_name')}</h2>
        <input
          className="text-input"
          value={name}
          autoFocus
          maxLength={LIMITS.nameLength}
          onChange={(e) => setName(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && saveName()}
          style={{ margin: '6px 0 16px' }}
        />
        <div className="dialog-actions">
          <button type="button" className="btn btn-glass" onClick={() => setEditing(false)}>
            {t('cancel')}
          </button>
          <button type="button" className="btn btn-gold" onClick={saveName} disabled={!name.trim()}>
            {t('save')}
          </button>
        </div>
      </Dialog>
    </div>
  );
}
