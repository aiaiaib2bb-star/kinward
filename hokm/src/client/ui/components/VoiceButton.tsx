import { useRef, useState } from 'react';
import { sfx } from '../../audio/sfx';
import { buzz } from '../../fx/haptics';
import { useT } from '../../i18n';
import { useSettings } from '../../state/settings';
import { mesh, useVoice } from '../../voice/mesh';
import { Sheet } from './common';

export function MicIcon({ off, size = 22 }: { off?: boolean; size?: number }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="9" y="3" width="6" height="11" rx="3" fill={off ? 'none' : 'currentColor'} />
      <path d="M5 11a7 7 0 0 0 14 0M12 18v3" />
      {off && <path d="M4 4l16 16" stroke="#ff5468" strokeWidth="2.6" />}
    </svg>
  );
}

function HeadphonesIcon({ size = 22 }: { size?: number }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
      <path d="M4 15v-3a8 8 0 0 1 16 0v3" />
      <rect x="3" y="14" width="5" height="7" rx="2" fill="currentColor" />
      <rect x="16" y="14" width="5" height="7" rx="2" fill="currentColor" />
    </svg>
  );
}

/** Join voice, then: tap to mute and unmute (or hold to talk), long-press for options. */
export function VoiceButton({ size = 46, inVoiceCount = 0 }: { size?: number; inVoiceCount?: number }) {
  const t = useT();
  const joined = useVoice((s) => s.joined);
  const hasMic = useVoice((s) => s.hasMic);
  const micOn = useVoice((s) => s.micOn);
  const needsTap = useVoice((s) => s.needsTap);
  const micLost = useVoice((s) => s.micLost);
  const mode = useSettings((s) => s.voiceMode);
  const [menu, setMenu] = useState(false);
  const pressTimer = useRef<number | null>(null);
  const longPressed = useRef(false);

  const down = (e: React.PointerEvent<HTMLButtonElement>) => {
    longPressed.current = false;
    if (!joined) return;
    // Keep the press even if the finger drifts off the button while talking.
    e.currentTarget.setPointerCapture(e.pointerId);
    pressTimer.current = window.setTimeout(() => {
      longPressed.current = true;
      buzz('select');
      if (mode === 'ptt' && hasMic) mesh.setMic(false);
      setMenu(true);
    }, 550);
    if (mode === 'ptt' && hasMic) {
      mesh.setMic(true);
      buzz('tap');
    }
  };

  const up = () => {
    if (pressTimer.current) clearTimeout(pressTimer.current);
    pressTimer.current = null;
    if (!joined) {
      void mesh.join();
      return;
    }
    if (longPressed.current) return;
    if (mode === 'ptt') {
      if (hasMic) mesh.setMic(false);
      return;
    }
    if (hasMic) {
      mesh.setMic(!micOn);
      sfx.play('click');
      buzz('tap');
    } else setMenu(true);
  };

  const cancel = () => {
    if (pressTimer.current) clearTimeout(pressTimer.current);
    pressTimer.current = null;
    if (joined && mode === 'ptt' && hasMic) mesh.setMic(false);
  };

  const state = !joined ? 'out' : !hasMic ? 'listen' : micOn ? 'live' : 'muted';
  const label = !joined ? t('voice_join') : mode === 'ptt' && hasMic ? t('hold_to_talk') : micOn ? t('mic_on') : t('mic_off');
  return (
    <>
      <button
        type="button"
        className={`voice-btn ${state}${needsTap || micLost ? ' needs-tap' : ''}`}
        style={{ width: size, height: size }}
        aria-label={label}
        title={label}
        onPointerDown={down}
        onPointerUp={up}
        onPointerLeave={cancel}
        onPointerCancel={cancel}
        onContextMenu={(e) => e.preventDefault()}
      >
        {state === 'listen' ? <HeadphonesIcon /> : <MicIcon off={state !== 'live'} />}
        {joined && inVoiceCount > 1 && <span className="voice-count">{inVoiceCount}</span>}
      </button>
      <Sheet open={menu} onClose={() => setMenu(false)} title={t('voice')}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {hasMic && mode === 'open' && (
            <button
              type="button"
              className="btn btn-glass btn-block"
              onClick={() => {
                mesh.setMic(!micOn);
                setMenu(false);
              }}
            >
              <MicIcon off={micOn} /> {micOn ? t('mic_off') : t('mic_on')}
            </button>
          )}
          <button
            type="button"
            className="btn btn-turq btn-block"
            onClick={() => {
              mesh.reconnect();
              setMenu(false);
            }}
          >
            🔄 {t('voice_reconnect')}
          </button>
          <p className="muted" style={{ margin: '-4px 4px 4px', fontSize: 13, textAlign: 'center' }}>
            {t('voice_reconnect_sub')}
          </p>
          <button
            type="button"
            className="btn btn-rose btn-block"
            onClick={() => {
              mesh.leave();
              setMenu(false);
            }}
          >
            {t('voice_leave')}
          </button>
        </div>
      </Sheet>
    </>
  );
}
