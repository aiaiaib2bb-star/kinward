import { useState } from 'react';
import { ITEMS } from '../../../shared/catalog';
import { ECONOMY, LIMITS } from '../../../shared/constants';
import { sfx } from '../../audio/sfx';
import { buzz } from '../../fx/haptics';
import { useT } from '../../i18n';
import { net } from '../../net/socket';
import { settings, useSettings } from '../../state/settings';
import { Avatar } from '../components/Avatar';
import { Coin, Segmented } from '../components/common';
import { Logo } from '../components/Logo';
import { DEFAULT_EQUIPPED } from '../../../shared/catalog';

const FREE_AVATARS = ITEMS.filter((i) => i.kind === 'avatar' && i.price === 0);

export function Onboarding() {
  const t = useT();
  const lang = useSettings((s) => s.lang);
  const [name, setName] = useState('');
  const [avatar, setAvatar] = useState(FREE_AVATARS[Math.floor(Math.random() * FREE_AVATARS.length)].id);
  const [busy, setBusy] = useState(false);
  const valid = name.trim().length > 0;

  const submit = async () => {
    if (!valid || busy) return;
    setBusy(true);
    sfx.play('coin');
    buzz('tap');
    await net.createProfile(name.trim(), avatar);
    setBusy(false);
  };

  return (
    <div className="screen">
      <div className="screen-inner onboarding">
        <div style={{ display: 'flex', justifyContent: 'center' }}>
          <div style={{ width: 200 }}>
            <Segmented
              value={lang}
              options={[
                { value: 'en', label: 'English' },
                { value: 'fa', label: 'فارسی' },
              ]}
              onChange={(v) => settings.set({ lang: v })}
            />
          </div>
        </div>
        <Logo />
        <div className="panel" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div>
            <h2 style={{ margin: '0 0 4px', fontSize: 22 }}>{t('welcome_title')}</h2>
            <p className="muted" style={{ margin: 0, lineHeight: 1.45 }}>
              {t('welcome_sub')}
            </p>
          </div>
          <label>
            <span className="field-label">{t('your_name')}</span>
            <input
              className="text-input"
              value={name}
              maxLength={LIMITS.nameLength}
              placeholder={t('name_placeholder')}
              autoComplete="nickname"
              enterKeyHint="go"
              onChange={(e) => setName(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && submit()}
            />
          </label>
          <div>
            <span className="field-label">{t('choose_avatar')}</span>
            <div className="avatar-grid">
              {FREE_AVATARS.map((a) => (
                <button
                  key={a.id}
                  type="button"
                  className={`avatar-choice${a.id === avatar ? ' active' : ''}`}
                  onClick={() => {
                    sfx.play('select');
                    buzz('select');
                    setAvatar(a.id);
                  }}
                  aria-label={a.name[lang]}
                >
                  <Avatar profile={{ id: 'new', level: 1, equipped: { ...DEFAULT_EQUIPPED, avatar: a.id } }} size={58} />
                </button>
              ))}
            </div>
          </div>
        </div>
        <button type="button" className="btn btn-gold btn-block" disabled={!valid || busy} onClick={submit} style={{ minHeight: 58, fontSize: 20 }}>
          {t('lets_play')}
        </button>
        <p className="muted" style={{ textAlign: 'center', margin: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}>
          <Coin size={16} /> {t('start_coins', { n: ECONOMY.startCoins })}
        </p>
      </div>
    </div>
  );
}
