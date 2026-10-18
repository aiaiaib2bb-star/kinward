import { type CSSProperties, useEffect, useState } from 'react';
import { ECONOMY, levelOf, levelTitle, xpForLevel } from '../../../shared/constants';
import { sfx } from '../../audio/sfx';
import { buzz } from '../../fx/haptics';
import { useLang, useT } from '../../i18n';
import { net } from '../../net/socket';
import { type Screen, go, toast, useApp } from '../../state/app';
import { publicOf } from '../../state/selectors';
import { Avatar } from '../components/Avatar';
import { PlayingCard } from '../components/Card';
import { CoinAmount, Sheet } from '../components/common';
import { BookIcon, CartIcon, ChevronIcon, ChipIcon, Crest, GearIcon, HistoryIcon, KeyIcon, PeopleIcon, TrophyIcon } from '../components/Icons';

export function Home() {
  const t = useT();
  const lang = useLang();
  const profile = useApp((s) => s.profile)!;
  const [joinOpen, setJoinOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const level = levelOf(profile.xp);
  const into = profile.xp - xpForLevel(level);
  const span = xpForLevel(level + 1) - xpForLevel(level);
  const title = levelTitle(level);

  const create = async (practice: boolean) => {
    if (busy) return;
    setBusy(true);
    sfx.play('click');
    buzz('tap');
    await net.createRoom({ practice });
    setBusy(false);
  };

  const open = (screen: Screen) => {
    sfx.play('click');
    go(screen);
  };

  return (
    <div className="screen home">
      <div className="screen-inner">
        <div className="home-head">
          <button type="button" className="me-pill" onClick={() => open('profile')}>
            <Avatar profile={publicOf(profile)} size={50} showLevel />
            <span className="me-text">
              <span className="name">{profile.name}</span>
              <span className="lvl">{lang === 'fa' ? title.fa : `${title.en} · ${title.fa}`}</span>
              <span className="xp-bar">
                <i style={{ width: `${Math.min(100, (into / span) * 100)}%` }} />
              </span>
            </span>
          </button>
          <div className="home-side">
            <button type="button" className="coin-pill plus" onClick={() => open('shop')}>
              <CoinAmount value={profile.coins} size={20} />
              <span className="plus-dot">+</span>
            </button>
            <div className="home-icons">
              <DailyGift />
              <button type="button" className="icon-btn gold-line" onClick={() => open('settings')} aria-label={t('settings')}>
                <GearIcon size={22} />
              </button>
            </div>
          </div>
        </div>

        <Crest />

        <div className="home-aces" aria-hidden="true">
          {['S14', 'H14', 'C14', 'D14'].map((card, i) => (
            <PlayingCard key={card} card={card} face="face_ivory" width={74} style={{ ['--i' as string]: i - 1.5 } as CSSProperties} />
          ))}
          <div className="home-rim" />
        </div>

        <div className="home-actions">
          <button type="button" className="home-btn gold" onClick={() => create(true)} disabled={busy}>
            <ChipIcon />
            <span className="hb-title">{t('play_computer')}</span>
            <span className="hb-chev">
              <ChevronIcon />
            </span>
          </button>
          <button type="button" className="home-btn felt" onClick={() => create(false)} disabled={busy}>
            <PeopleIcon />
            <span className="hb-title">{t('play_friends')}</span>
            <span className="hb-chev">
              <ChevronIcon />
            </span>
          </button>
          <button
            type="button"
            className="home-btn night"
            onClick={() => {
              sfx.play('click');
              setJoinOpen(true);
            }}
          >
            <KeyIcon />
            <span className="hb-title">{t('join_code')}</span>
            <span className="hb-chev">
              <ChevronIcon />
            </span>
          </button>
        </div>

        <div className="home-tiles">
          <button type="button" className="home-tile shop" onClick={() => open('shop')}>
            <CartIcon />
            <b>{t('shop')}</b>
            <small>{t('tile_shop_sub')}</small>
            <span className="tile-art" aria-hidden="true">
              <PlayingCard down back="back_royal_crimson" face="face_classic" width={44} style={{ transform: 'rotate(12deg)' }} />
              <PlayingCard down back="back_sun_moon" face="face_classic" width={44} style={{ transform: 'rotate(-6deg)' }} />
            </span>
          </button>
          <button type="button" className="home-tile" onClick={() => open('leaderboard')}>
            <TrophyIcon />
            <b>{t('leaderboard')}</b>
            <small>{t('tile_leaderboard_sub')}</small>
            <span className="tile-art trophy" aria-hidden="true">
              🏆
            </span>
          </button>
          <button type="button" className="home-tile" onClick={() => open('history')}>
            <HistoryIcon />
            <b>{t('record_short', { w: profile.stats.won, l: profile.stats.lost })}</b>
            <small>{t('tile_record_sub')}</small>
            <span className="tile-art bars" aria-hidden="true">
              <i style={{ height: '40%' }} />
              <i style={{ height: '65%' }} />
              <i style={{ height: '90%' }} />
            </span>
          </button>
          <button type="button" className="home-tile" onClick={() => open('rules')}>
            <BookIcon />
            <b>{t('rules')}</b>
            <small>{t('tile_rules_sub')}</small>
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
