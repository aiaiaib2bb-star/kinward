import { useEffect } from 'react';
import { applyDocumentLang, useT } from './i18n';
import { net } from './net/socket';
import { useApp } from './state/app';
import { useSettings } from './state/settings';
import { Logo } from './ui/components/Logo';
import { Game } from './ui/game/Game';
import { Home } from './ui/screens/Home';
import { Lobby } from './ui/screens/Lobby';
import { Onboarding } from './ui/screens/Onboarding';
import { Profile } from './ui/screens/Profile';
import { Rules } from './ui/screens/Rules';
import { Settings } from './ui/screens/Settings';
import { Shop } from './ui/screens/Shop';

function Toasts() {
  const toasts = useApp((s) => s.toasts);
  return (
    <div className="toasts" role="status" aria-live="polite">
      {toasts.map((t) => (
        <div key={t.id} className={`toast ${t.tone}`}>
          {t.text}
        </div>
      ))}
    </div>
  );
}

function ConnectionBanner() {
  const t = useT();
  const conn = useApp((s) => s.conn);
  const ready = useApp((s) => s.ready);
  if (conn === 'online' || !ready) return null;
  return (
    <div className="conn-banner">
      <span className="spinner" />
      {t('reconnecting')}
    </div>
  );
}

function Boot() {
  const t = useT();
  return (
    <div className="screen">
      <div className="boot">
        <Logo />
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, justifyContent: 'center' }} className="muted">
          <span className="spinner" /> {t('connecting')}
        </div>
      </div>
    </div>
  );
}

function Elsewhere() {
  const t = useT();
  return (
    <div className="screen">
      <div className="boot">
        <div style={{ fontSize: 54 }}>📱</div>
        <h2 style={{ margin: 0 }}>{t('elsewhere_title')}</h2>
        <p className="muted" style={{ margin: 0, textAlign: 'center' }}>
          {t('elsewhere_sub')}
        </p>
        <button type="button" className="btn btn-gold" onClick={() => net.reconnectHere()}>
          {t('use_here')}
        </button>
      </div>
    </div>
  );
}

export function App() {
  const ready = useApp((s) => s.ready);
  const needsProfile = useApp((s) => s.needsProfile);
  const profile = useApp((s) => s.profile);
  const room = useApp((s) => s.room);
  const screen = useApp((s) => s.screen);
  const elsewhere = useApp((s) => s.elsewhere);
  const lang = useSettings((s) => s.lang);
  const reduceMotion = useSettings((s) => s.reduceMotion);

  useEffect(() => applyDocumentLang(lang), [lang]);
  useEffect(() => {
    document.documentElement.classList.toggle('reduce-motion', reduceMotion);
  }, [reduceMotion]);

  let base;
  if (elsewhere) base = <Elsewhere />;
  else if (!ready) base = <Boot />;
  else if (needsProfile || !profile) base = <Onboarding />;
  else if (room) base = room.game ? <Game room={room} /> : <Lobby room={room} />;
  else base = <Home />;

  const overlay = ready && profile && !elsewhere && screen !== 'home' ? screen : null;
  return (
    <>
      {base}
      {overlay && (
        <div className="overlay-screen">
          {overlay === 'shop' && <Shop />}
          {overlay === 'profile' && <Profile />}
          {overlay === 'settings' && <Settings />}
          {overlay === 'rules' && <Rules />}
        </div>
      )}
      <Toasts />
      <ConnectionBanner />
    </>
  );
}
