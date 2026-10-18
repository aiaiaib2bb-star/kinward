import { useEffect, useState } from 'react';
import { ITEMS, emotesOwned } from '../../../shared/catalog';
import type { GameView, MemberView, RoomView } from '../../../shared/protocol';
import { partnerOf, teamOf } from '../../../shared/rules';
import { sfx } from '../../audio/sfx';
import { buzz } from '../../fx/haptics';
import { displayName, phraseText, useLang, useT } from '../../i18n';
import { toLocal } from '../../net/clock';
import { net } from '../../net/socket';
import { go, useApp } from '../../state/app';
import { seatMember } from '../../state/selectors';
import { settings, useSettings } from '../../state/settings';
import { mesh, useVoice } from '../../voice/mesh';
import { Avatar } from '../components/Avatar';
import { PlayingCard } from '../components/Card';
import { Dialog, Sheet } from '../components/common';

const EMOTE_PACKS = ITEMS.filter((i) => i.kind === 'emotes');

export function EmoteSheet({ open, onClose }: { open: boolean; onClose: () => void }) {
  const t = useT();
  const lang = useLang();
  const profile = useApp((s) => s.profile)!;
  const [tab, setTab] = useState<'emoji' | 'phrase'>('emoji');
  const owned = emotesOwned(profile.owned);
  const all = EMOTE_PACKS.flatMap((p) => (p.emotes ?? []).map((e) => ({ e, pack: p.id })));
  const list = all.filter(({ e }) => (tab === 'phrase') === e.startsWith('p_'));
  const send = (e: string) => {
    net.emote(e);
    buzz('emote');
    onClose();
  };
  return (
    <Sheet open={open} onClose={onClose} title={t('emotes')}>
      <div className="segmented" style={{ marginBottom: 14 }}>
        <button type="button" className={tab === 'emoji' ? 'active' : ''} onClick={() => setTab('emoji')}>
          😊 {t('emotes')}
        </button>
        <button type="button" className={tab === 'phrase' ? 'active' : ''} onClick={() => setTab('phrase')}>
          💬 {t('phrases')}
        </button>
      </div>
      {tab === 'emoji' ? (
        <div className="emote-grid">
          {list.map(({ e }) => (
            <button
              key={e}
              type="button"
              className={`emote-btn${owned.has(e) ? '' : ' locked'}`}
              onClick={() => (owned.has(e) ? send(e) : (onClose(), go('shop')))}
            >
              {e}
            </button>
          ))}
        </div>
      ) : (
        <div className="phrase-grid">
          {list.map(({ e }) => (
            <button
              key={e}
              type="button"
              className={`phrase-btn${owned.has(e) ? '' : ' locked'}`}
              onClick={() => (owned.has(e) ? send(e) : (onClose(), go('shop')))}
            >
              {phraseText(e, lang)}
              {!owned.has(e) && ' 🔒'}
            </button>
          ))}
        </div>
      )}
      <button type="button" className="btn btn-glass btn-block btn-small" style={{ marginTop: 14 }} onClick={() => (onClose(), go('shop'))}>
        🛍️ {t('locked_more')}
      </button>
    </Sheet>
  );
}

export function PlayerSheet({ member, room, onClose }: { member: MemberView | null; room: RoomView; onClose: () => void }) {
  const t = useT();
  const lang = useLang();
  const profile = useApp((s) => s.profile)!;
  const inVoice = useVoice((s) => s.joined);
  const muted = useVoice((s) => (member ? !!s.muted[member.id] : false));
  const throwables = ITEMS.filter((i) => i.kind === 'throwable');
  if (!member)
    return (
      <Sheet open={false} onClose={onClose}>
        {null}
      </Sheet>
    );
  const isMe = member.id === room.you;
  return (
    <Sheet open onClose={onClose}>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
        <Avatar profile={member.profile} size={80} showLevel />
        <div style={{ fontSize: 20, fontWeight: 600 }}>{displayName(member.profile, lang)}</div>
        <div className="muted" style={{ fontSize: 14 }}>
          {t('level', { n: member.profile.level })} · {t('player_stats', { w: member.profile.stats.won, k: member.profile.stats.kots })}
        </div>
      </div>
      {!isMe && (
        <>
          <div className="section-title">{t('throw_at', { name: displayName(member.profile, lang) })}</div>
          <div className="throw-grid">
            {throwables.map((it) => {
              const owns = profile.owned.includes(it.id);
              return (
                <button
                  key={it.id}
                  type="button"
                  className={`throw-btn${owns ? '' : ' locked'}`}
                  onClick={() => {
                    if (!owns) {
                      onClose();
                      go('shop');
                      return;
                    }
                    net.throwItem(member.id, it.id);
                    sfx.play('whoosh');
                    onClose();
                  }}
                >
                  <span className="g">{it.glyph}</span>
                  <span className="n">{owns ? it.name[lang] : '🔒'}</span>
                </button>
              );
            })}
          </div>
          {inVoice && member.inVoice && (
            <button type="button" className="btn btn-glass btn-block" style={{ marginTop: 14 }} onClick={() => mesh.toggleMute(member.id)}>
              {muted ? `🔊 ${t('unmute_player')}` : `🔇 ${t('mute_player')}`}
            </button>
          )}
        </>
      )}
    </Sheet>
  );
}

export function LastTrickSheet({
  open,
  onClose,
  game,
  room,
  rel,
}: {
  open: boolean;
  onClose: () => void;
  game: GameView;
  room: RoomView;
  rel: (s: number) => number;
}) {
  const t = useT();
  const lang = useLang();
  const face = useApp((s) => s.profile?.equipped.cardFace ?? 'face_classic');
  const fourColor = useSettings((s) => s.fourColor);
  const last = game.lastTrick;
  const pos = ['bottom', 'right', 'top', 'left'];
  return (
    <Sheet open={open} onClose={onClose} title={t('last_trick')}>
      {!last ? (
        <p className="muted" style={{ textAlign: 'center' }}>
          {t('no_last_trick')}
        </p>
      ) : (
        <>
          <div className="last-trick">
            {last.plays.map((p) => (
              <div key={p.card} className={`lt-card ${pos[rel(p.seat)]}${p.seat === last.winner ? ' win' : ''}`}>
                <PlayingCard card={p.card} face={face} fourColor={fourColor} width={58} />
                <span>{displayName(seatMember(room, p.seat)?.profile, lang)}</span>
              </div>
            ))}
          </div>
          <p style={{ textAlign: 'center', margin: '8px 0 0' }}>🏆 {t('won_by', { name: displayName(seatMember(room, last.winner)?.profile, lang) })}</p>
        </>
      )}
    </Sheet>
  );
}

export function GameMenu({ open, onClose, onLastTrick, seated }: { open: boolean; onClose: () => void; onLastTrick: () => void; seated: boolean }) {
  const t = useT();
  const sound = useSettings((s) => s.sound);
  const [confirm, setConfirm] = useState<'surrender' | 'leave' | null>(null);
  return (
    <>
      <Sheet open={open} onClose={onClose} title={t('menu')}>
        <div className="menu-list">
          <button type="button" className="menu-item" onClick={() => (onClose(), onLastTrick())}>
            <span>👁️</span> {t('last_trick')}
          </button>
          <button type="button" className="menu-item" onClick={() => settings.set({ sound: !sound })}>
            <span>{sound ? '🔊' : '🔇'}</span> {sound ? t('sound_on') : t('sound_off')}
          </button>
          <button type="button" className="menu-item" onClick={() => (onClose(), go('settings'))}>
            <span>⚙️</span> {t('settings')}
          </button>
          <button type="button" className="menu-item" onClick={() => (onClose(), go('rules'))}>
            <span>📖</span> {t('rules')}
          </button>
          {seated && (
            <button type="button" className="menu-item warn" onClick={() => setConfirm('surrender')}>
              <span>🏳️</span> {t('surrender')}
            </button>
          )}
          <button type="button" className="menu-item danger" onClick={() => setConfirm('leave')}>
            <span>🚪</span> {t('leave_table')}
          </button>
        </div>
      </Sheet>
      <Dialog open={confirm !== null} onClose={() => setConfirm(null)}>
        <div style={{ fontSize: 42 }}>{confirm === 'surrender' ? '🏳️' : '🚪'}</div>
        <h2>{confirm === 'surrender' ? t('surrender') : t('leave_table')}</h2>
        <p>{confirm === 'surrender' ? t('surrender_confirm') : t('leave_confirm')}</p>
        <div className="dialog-actions">
          <button type="button" className="btn btn-glass" onClick={() => setConfirm(null)}>
            {t('cancel')}
          </button>
          <button
            type="button"
            className="btn btn-rose"
            onClick={() => {
              if (confirm === 'surrender') net.surrender();
              else net.leaveRoom();
              setConfirm(null);
              onClose();
            }}
          >
            {confirm === 'surrender' ? t('surrender') : t('leave_table')}
          </button>
        </div>
      </Dialog>
    </>
  );
}

/** The partner's yes/no, or a quiet banner for the one who asked. */
export function SurrenderPrompt({ game, mySeat }: { game: GameView; mySeat: number | null }) {
  const t = useT();
  const s = game.surrender;
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    if (!s) return;
    const id = setInterval(() => setNow(Date.now()), 250);
    return () => clearInterval(id);
  }, [s]);
  useEffect(() => {
    if (s && mySeat !== null && teamOf(mySeat) === s.team && s.by !== mySeat) {
      sfx.play('turn');
      buzz('turn');
    }
  }, [s, mySeat]);
  if (!s || mySeat === null || teamOf(mySeat) !== s.team) return null;
  const left = Math.max(0, Math.ceil((toLocal(s.expires) - now) / 1000));
  if (s.by === mySeat) {
    return (
      <div className="surrender-banner">
        🏳️ {t('surrender_waiting')} <b>{left}</b>
      </div>
    );
  }
  if (partnerOf(s.by) !== mySeat) return null;
  return (
    <Dialog open>
      <div style={{ fontSize: 46 }}>🏳️</div>
      <h2>{t('surrender_ask')}</h2>
      <p>{t('surrender_ask_sub')}</p>
      <div className="dialog-actions">
        <button type="button" className="btn btn-turq" onClick={() => net.surrenderVote(false)}>
          💪 {t('surrender_no')}
        </button>
        <button type="button" className="btn btn-rose" onClick={() => net.surrenderVote(true)}>
          {t('surrender_yes')} ({left})
        </button>
      </div>
    </Dialog>
  );
}

export function AwayBanner({ onBack }: { onBack: () => void }) {
  const t = useT();
  return (
    <div className="away-banner">
      <div>
        <b>🤖 {t('autoplay_title')}</b>
        <div className="muted">{t('autoplay_sub')}</div>
      </div>
      <button type="button" className="btn btn-gold btn-small" onClick={onBack}>
        {t('im_back')}
      </button>
    </div>
  );
}
