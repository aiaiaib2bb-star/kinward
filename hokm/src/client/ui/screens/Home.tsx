import { useEffect, useState } from 'react';
import { ECONOMY, levelOf, xpForLevel } from '../../../shared/constants';
import { sfx } from '../../audio/sfx';
import { buzz } from '../../fx/haptics';
import { useT } from '../../i18n';
import { net } from '../../net/socket';
import { go, toast, useApp } from '../../state/app';
import { publicOf } from '../../state/selectors';
import { Avatar } from '../components/Avatar';
import { CoinAmount, Sheet } from '../components/common';
import { Logo } from '../components/Logo';

export function Home() {
  const t = useT();
  const profile = useApp((s) => s.profile)!;
  const [joinOpen, setJoinOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const level = levelOf(profile.xp);
  const into = profile.xp - xpForLevel(level);
  const span = xpForLevel(level + 1) - xpForLevel(level);

  const create = async (practice: boolean) => {
    if (busy) return;
    setBusy(true);
    sfx.play('click');
    buzz('tap');
    await net.createRoom({ practice });
    setBusy(false);
  };

  return (
    <div className="screen">
      <div className="screen-inner">
        <div className="home-head">
          <button type="button" className="me-chip" onClick={() => go('profile')}>
            <Avatar profile={publicOf(profile)} size={52} showLevel />
            <span style={{ minWidth: 0 }}>
              <div className="name">{profile.name}</div>
              <div className="lvl">{t('level', { n: level })}</div>
              <div className="xp-bar">
                <i style={{ width: `${Math.min(100, (into / span) * 100)}%` }} />
              </div>
            </span>
          </button>
          <DailyGift />
          <button type="button" className="coin-pill" onClick={() => go('shop')}>
            <CoinAmount value={profile.coins} size={20} />
          </button>
        </div>

        <div className="home-hero">
          <Logo compact />
        </div>

        <div className="home-actions">
          <button type="button" className="big-action gold" onClick={() => create(false)} disabled={busy}>
            <span className="ba-icon">🃏</span>
            <span>
              <div className="ba-title">{t('play_friends')}</div>
              <div className="ba-sub">{t('play_friends_sub')}</div>
            </span>
          </button>
          <button
            type="button"
            className="big-action turq"
            onClick={() => {
              sfx.play('click');
              setJoinOpen(true);
            }}
          >
            <span className="ba-icon">🔑</span>
            <span>
              <div className="ba-title">{t('join_code')}</div>
              <div className="ba-sub">{t('join_code_sub')}</div>
            </span>
          </button>
          <button type="button" className="big-action glass" onClick={() => create(true)} disabled={busy}>
            <span className="ba-icon">🤖</span>
            <span>
              <div className="ba-title">{t('practice')}</div>
              <div className="ba-sub">{t('practice_sub')}</div>
            </span>
          </button>
        </div>

        <div className="home-grid">
          <button type="button" className="tile" onClick={() => go('shop')}>
            <span className="tile-icon">🛍️</span>
            {t('shop')}
          </button>
          <button type="button" className="tile" onClick={() => go('profile')}>
            <span className="tile-icon">👤</span>
            {t('profile')}
          </button>
          <button type="button" className="tile" onClick={() => go('rules')}>
            <span className="tile-icon">📖</span>
            {t('rules')}
          </button>
          <button type="button" className="tile" onClick={() => go('settings')}>
            <span className="tile-icon">⚙️</span>
            {t('settings')}
          </button>
        </div>
      </div>
      <JoinSheet open={joinOpen} onClose={() => setJoinOpen(false)} />
    </div>
  );
}

/** The gift box in the header: it bounces when there's one to open. */
function DailyGift() {
  const t = useT();
  const profile = useApp((s) => s.profile)!;
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(id);
  }, []);
  const readyAt = profile.daily.last + ECONOMY.dailyCooldownHours * 3_600_000;
  const ready = now >= readyAt;
  const claim = async () => {
    if (!ready) {
      const left = readyAt - Date.now();
      toast(t('daily_wait', { t: t('hours_minutes', { h: Math.floor(left / 3_600_000), m: Math.floor((left % 3_600_000) / 60_000) }) }), 'info');
      return;
    }
    const gift = await net.claimDaily();
    if (gift) {
      sfx.play('coin');
      setTimeout(() => sfx.play('coin'), 140);
      buzz('win');
      toast(`🎁 ${t('daily_got', { n: gift.coins, d: gift.streak })}`, 'good', 3200);
    }
  };
  return (
    <button type="button" className={`gift-btn${ready ? ' ready' : ''}`} onClick={claim} aria-label={ready ? t('daily_ready') : t('daily_gift')}>
      🎁
      {ready && <span className="dot" />}
    </button>
  );
}

function JoinSheet({ open, onClose }: { open: boolean; onClose: () => void }) {
  const t = useT();
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const join = async () => {
    if (code.length !== 4 || busy) return;
    setBusy(true);
    const ok = await net.joinRoom(code);
    setBusy(false);
    if (ok) {
      sfx.play('chime');
      onClose();
      setCode('');
    } else {
      sfx.play('error');
      buzz('error');
    }
  };
  return (
    <Sheet open={open} onClose={onClose} title={t('enter_code')}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <input
          className="text-input code-input"
          value={code}
          autoFocus
          inputMode="text"
          autoCapitalize="characters"
          autoComplete="off"
          spellCheck={false}
          maxLength={4}
          placeholder="ABCD"
          enterKeyHint="go"
          onChange={(e) => setCode(e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, ''))}
          onKeyDown={(e) => e.key === 'Enter' && join()}
        />
        <button type="button" className="btn btn-turq btn-block" disabled={code.length !== 4 || busy} onClick={join}>
          {t('join')}
        </button>
      </div>
    </Sheet>
  );
}
