import { useT } from '../../i18n';
import { go } from '../../state/app';
import { settings, useSettings } from '../../state/settings';
import { PlayingCard } from '../components/Card';
import { Segmented, Toggle, TopNav } from '../components/common';

export function Settings() {
  const t = useT();
  const s = useSettings((x) => x);
  return (
    <div className="screen">
      <div className="screen-inner">
        <TopNav title={t('settings')} onBack={() => go('home')} />
        <div className="panel" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div className="setting-line">
            <span>{t('language')}</span>
            <Segmented
              value={s.lang}
              options={[
                { value: 'en', label: 'English' },
                { value: 'fa', label: 'فارسی' },
              ]}
              onChange={(v) => settings.set({ lang: v })}
            />
          </div>
          <div className="setting-line">
            <span>{t('voice_mode')}</span>
            <Segmented
              value={s.voiceMode}
              options={[
                { value: 'open', label: `🎙️ ${t('voice_open')}` },
                { value: 'ptt', label: `✋ ${t('voice_ptt')}` },
              ]}
              onChange={(v) => settings.set({ voiceMode: v })}
            />
          </div>
        </div>
        <div className="panel" style={{ marginTop: 14, paddingTop: 4, paddingBottom: 4 }}>
          <Toggle on={s.sound} onChange={(v) => settings.set({ sound: v })} label={t('sound')} />
          {s.sound && (
            <div style={{ padding: '12px 4px', borderBottom: '1px solid var(--line)' }}>
              <span className="row-label">{t('volume')}</span>
              <input
                type="range"
                min={0}
                max={1}
                step={0.05}
                value={s.volume}
                onChange={(e) => settings.set({ volume: Number(e.target.value) })}
                style={{ width: '100%', accentColor: '#f7c654', marginTop: 10 }}
              />
            </div>
          )}
          <Toggle on={s.haptics} onChange={(v) => settings.set({ haptics: v })} label={t('haptics')} />
          <Toggle
            on={s.fourColor}
            onChange={(v) => settings.set({ fourColor: v })}
            label={t('four_color')}
            sub={
              <span style={{ display: 'flex', gap: 4, marginTop: 6 }}>
                {['S13', 'H13', 'D13', 'C13'].map((c) => (
                  <PlayingCard key={c} card={c} face="face_classic" fourColor={s.fourColor} width={26} />
                ))}
              </span>
            }
          />
          <Toggle on={s.reduceMotion} onChange={(v) => settings.set({ reduceMotion: v })} label={t('reduce_motion')} />
          <Toggle on={s.muteEmotes} onChange={(v) => settings.set({ muteEmotes: v })} label={t('mute_emotes')} />
          <Toggle on={s.tips} onChange={(v) => settings.set({ tips: v, seenTips: v ? [] : s.seenTips })} label={t('tips')} />
        </div>
        <div className="section-title">{t('about')}</div>
        <p className="muted" style={{ lineHeight: 1.5, margin: '0 4px' }}>
          {t('about_text')}
        </p>
      </div>
    </div>
  );
}
