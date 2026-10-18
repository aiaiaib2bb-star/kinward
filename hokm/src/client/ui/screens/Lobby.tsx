import { useState } from 'react';
import { TARGET_SCORES, TURN_TIMES } from '../../../shared/constants';
import type { MemberView, RoomView } from '../../../shared/protocol';
import { teamOf } from '../../../shared/rules';
import { sfx } from '../../audio/sfx';
import { buzz } from '../../fx/haptics';
import { displayName, useLang, useT } from '../../i18n';
import { net } from '../../net/socket';
import { go } from '../../state/app';
import { mySeat, seatMember } from '../../state/selectors';
import { Avatar } from '../components/Avatar';
import { ChatButton, ChatSheet } from '../components/Chat';
import { Dialog, Segmented, Sheet, Toggle } from '../components/common';
import { shareRoom } from '../components/share';
import { VoiceButton } from '../components/VoiceButton';
import { useVoice } from '../../voice/mesh';

// Seats drawn around a little table, rotated so you're always at the bottom.
const SPOTS = [
  { left: '50%', top: '86%' },
  { left: '87%', top: '50%' },
  { left: '50%', top: '13%' },
  { left: '13%', top: '50%' },
];

export function Lobby({ room }: { room: RoomView }) {
  const t = useT();
  const lang = useLang();
  const isHost = room.hostId === room.you;
  const me = mySeat(room);
  const view = me ?? 0;
  const [chat, setChat] = useState(false);
  const [target, setTarget] = useState<MemberView | null>(null);
  const [leaving, setLeaving] = useState(false);
  const host = room.members.find((m) => m.id === room.hostId);
  const full = room.seats.every(Boolean);
  const spectators = room.members.filter((m) => m.seat === null);
  const inVoice = room.members.filter((m) => m.inVoice).length;
  const speaking = useVoice((s) => s.speaking);

  const start = async () => {
    sfx.play('stamp');
    buzz('tap');
    await net.start();
  };

  return (
    <div className="screen lobby">
      <div className="screen-inner">
        <header className="topnav">
          <button type="button" className="icon-btn" onClick={() => setLeaving(true)} aria-label={t('leave_room')}>
            <svg viewBox="0 0 24 24" width="22" height="22" className="flip-rtl">
              <path d="M15 5l-7 7 7 7" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </button>
          <h1>{t('room')}</h1>
          <div className="topnav-right" style={{ gap: 8 }}>
            <ChatButton room={room} onOpen={() => setChat(true)} />
          </div>
        </header>

        <div className="lobby-code">
          <span className="label">{t('room_code')}</span>
          <button type="button" className="code" onClick={() => shareRoom(room.code)}>
            {room.code}
          </button>
          <button type="button" className="btn btn-turq btn-small" onClick={() => shareRoom(room.code)} style={{ marginTop: 8 }}>
            📨 {t('invite')}
          </button>
        </div>

        <div className="lobby-table">
          <div className="lobby-felt">{t('partner_of')}</div>
          {[0, 1, 2, 3].map((seat) => {
            const rel = (seat - view + 4) % 4;
            const m = seatMember(room, seat);
            const team = teamOf(seat);
            return (
              <div key={seat} className="lobby-seat" style={SPOTS[rel]}>
                {m ? (
                  <>
                    <Avatar
                      profile={m.profile}
                      size={62}
                      showLevel
                      dim={!m.online}
                      speaking={!!speaking[m.id]}
                      badge={m.profile.bot ? t('bot_badge') : m.id === room.hostId ? t('host') : null}
                      onClick={() => m.id !== room.you && setTarget(m)}
                    />
                    <span className="seat-name">{m.id === room.you ? t('you') : displayName(m.profile, lang)}</span>
                    <span className={`seat-team team-${team}`}>{team === 0 ? t('team_a') : t('team_b')}</span>
                    {isHost && m.profile.bot && (
                      <button type="button" className="mini-btn" onClick={() => net.bot(seat, false)}>
                        ✕ {t('remove_bot')}
                      </button>
                    )}
                  </>
                ) : (
                  <>
                    <button
                      type="button"
                      className="empty-seat"
                      onClick={() => {
                        sfx.play('select');
                        void net.sit(seat);
                      }}
                      aria-label={t('sit_here')}
                    >
                      +
                    </button>
                    <span className="seat-name muted">{t('sit_here')}</span>
                    <span className={`seat-team team-${team}`}>{team === 0 ? t('team_a') : t('team_b')}</span>
                    {isHost && (
                      <button type="button" className="mini-btn gold" onClick={() => net.bot(seat, true)}>
                        🤖 {t('add_bot')}
                      </button>
                    )}
                  </>
                )}
              </div>
            );
          })}
        </div>

        <div style={{ display: 'flex', justifyContent: 'center', gap: 10, marginTop: 8, flexWrap: 'wrap' }}>
          {isHost && (
            <button type="button" className="btn btn-glass btn-small" onClick={() => net.shuffleSeats()}>
              🔀 {t('shuffle_teams')}
            </button>
          )}
          {me !== null && (
            <button type="button" className="btn btn-glass btn-small" onClick={() => net.stand()}>
              {t('stand_up')}
            </button>
          )}
          <button type="button" className="btn btn-glass btn-small" onClick={() => go('shop')}>
            🛍️ {t('shop')}
          </button>
        </div>

        {spectators.length > 0 && (
          <>
            <div className="section-title">{t('spectators')}</div>
            <div className="spectators">
              {spectators.map((m) => (
                <div key={m.id} className="spectator">
                  <Avatar profile={m.profile} size={28} />
                  {m.id === room.you ? t('you') : displayName(m.profile, lang)}
                </div>
              ))}
            </div>
          </>
        )}

        <div className="section-title">{t('settings')}</div>
        <div className="panel lobby-settings">
          <div className="setting-line">
            <span>{t('settings_target')}</span>
            <Segmented
              value={room.settings.targetScore}
              disabled={!isHost}
              options={TARGET_SCORES.map((n) => ({ value: n, label: n }))}
              onChange={(v) => net.roomSettings({ targetScore: v })}
            />
          </div>
          <div className="setting-line">
            <span>{t('settings_timer')}</span>
            <Segmented
              value={room.settings.turnTime}
              disabled={!isHost}
              options={TURN_TIMES.map((n) => ({ value: n, label: n ? t('seconds', { n }) : '∞' }))}
              onChange={(v) => net.roomSettings({ turnTime: v })}
            />
          </div>
          <div className="setting-line">
            <span>{t('settings_shuffle')}</span>
            <Segmented
              value={room.settings.shuffleMode}
              disabled={!isHost}
              options={[
                { value: 'real', label: `🃏 ${t('shuffle_real')}` },
                { value: 'random', label: `🎲 ${t('shuffle_random')}` },
              ]}
              onChange={(v) => net.roomSettings({ shuffleMode: v })}
            />
            <p className="setting-hint">{room.settings.shuffleMode === 'real' ? t('shuffle_real_hint') : t('shuffle_random_hint')}</p>
          </div>
          <Toggle
            on={room.settings.booms}
            disabled={!isHost}
            label={`💣 ${t('settings_booms')}`}
            sub={t('settings_booms_sub')}
            onChange={(v) => net.roomSettings({ booms: v })}
          />
          <Toggle
            on={room.settings.swaps}
            disabled={!isHost}
            label={`🔄 ${t('settings_swaps')}`}
            sub={t('settings_swaps_sub')}
            onChange={(v) => net.roomSettings({ swaps: v })}
          />
        </div>

        <div className="lobby-footer">
          <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            <VoiceButton size={54} inVoiceCount={inVoice} />
            {isHost ? (
              <button type="button" className="btn btn-gold" style={{ flex: 1, minHeight: 54, fontSize: 19 }} disabled={!full} onClick={start}>
                ▶ {t('start_game')}
              </button>
            ) : (
              <div className="panel" style={{ flex: 1, padding: '14px 12px', textAlign: 'center', fontSize: 15 }}>
                {t('waiting_host', { name: displayName(host?.profile, lang) })}
              </div>
            )}
          </div>
          {isHost && !full && <div className="hint">{t('need_four')}</div>}
        </div>
      </div>

      <ChatSheet room={room} open={chat} onClose={() => setChat(false)} />

      <Sheet open={!!target} onClose={() => setTarget(null)} title={displayName(target?.profile, lang)}>
        {target && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'center' }}>
            <Avatar profile={target.profile} size={84} showLevel />
            <div className="muted">{t('player_stats', { w: target.profile.stats.won, k: target.profile.stats.kots })}</div>
            {isHost && !target.profile.bot && (
              <button
                type="button"
                className="btn btn-rose btn-block"
                onClick={() => {
                  net.kick(target.id);
                  setTarget(null);
                }}
              >
                {t('kick')}
              </button>
            )}
          </div>
        )}
      </Sheet>

      <Dialog open={leaving} onClose={() => setLeaving(false)}>
        <h2>{t('leave_room')}?</h2>
        <div className="dialog-actions">
          <button type="button" className="btn btn-glass" onClick={() => setLeaving(false)}>
            {t('cancel')}
          </button>
          <button
            type="button"
            className="btn btn-rose"
            onClick={() => {
              setLeaving(false);
              net.leaveRoom();
            }}
          >
            {t('leave_room')}
          </button>
        </div>
      </Dialog>
    </div>
  );
}
