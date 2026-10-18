import { useEffect, useState } from 'react';
import { ITEMS, emotesOwned } from '../../../shared/catalog';
import { levelTitle } from '../../../shared/constants';
import type { GameView, MemberView, RoomView } from '../../../shared/protocol';
import { HAND_SIZE, partnerOf, teamOf } from '../../../shared/rules';
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
import { GifPicker } from '../components/Gifs';

const EMOTE_PACKS = ITEMS.filter((i) => i.kind === 'emotes');

export function EmoteSheet({ open, onClose }: { open: boolean; onClose: () => void }) {
  const t = useT();
  const lang = useLang();
  const profile = useApp((s) => s.profile)!;
  const gifsOn = useApp((s) => s.features.gifs);
  const [tab, setTab] = useState<'emoji' | 'phrase' | 'gif'>('emoji');
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
        {gifsOn && (
          <button type="button" className={tab === 'gif' ? 'active' : ''} onClick={() => setTab('gif')}>
            🎞️ {t('gif')}
          </button>
        )}
      </div>
      {tab === 'gif' ? (
        <GifPicker
          onPick={(gif) => {
            void net.sendGif(gif.id);
            onClose();
          }}
        />
      ) : tab === 'emoji' ? (
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
      {tab !== 'gif' && (
        <button type="button" className="btn btn-glass btn-block btn-small" style={{ marginTop: 14 }} onClick={() => (onClose(), go('shop'))}>
          🛍️ {t('locked_more')}
        </button>
      )}
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
      <div className="player-card">
        <Avatar profile={member.profile} size={112} showLevel />
        <div className="pc-name">{displayName(member.profile, lang)}</div>
        <div className="pc-title">
          {t('level', { n: member.profile.level })} · {levelTitle(member.profile.level)[lang]}
        </div>
        {!member.profile.bot && (
          <div className="pc-stats">
            <span>
              <b>{member.profile.stats.won}</b>
              {t('stat_won')}
            </span>
            <span>
              <b>{member.profile.stats.played}</b>
              {t('stat_played')}
            </span>
            <span>
              <b>{member.profile.stats.kots}</b>
              {t('stat_kots')}
            </span>
            <span>
              <b>{member.profile.stats.bestStreak}</b>
              {t('stat_streak')}
            </span>
          </div>
        )}
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

// ——— Boom and swapping hands ———

/** Why you can or can't call Boom right now. */
export function boomStatus(room: RoomView, game: GameView, mySeat: number | null): 'ok' | 'off' | 'taken' | 'late' | 'spectator' {
  if (mySeat === null) return 'spectator';
  if (!room.settings.booms) return 'off';
  if (game.boom) return 'taken';
  if (game.phase !== 'play' || game.tricksWon[0] + game.tricksWon[1] > 0) return 'late';
  return 'ok';
}

/** Why you can or can't offer a swap right now. */
export function swapStatus(room: RoomView, game: GameView, mySeat: number | null): 'ok' | 'off' | 'used' | 'pending' | 'between' | 'spectator' {
  if (mySeat === null) return 'spectator';
  if (!room.settings.swaps) return 'off';
  if (game.swapsUsed.includes(mySeat)) return 'used';
  if (game.swapOffer) return 'pending';
  if (game.phase !== 'play' || game.trick.length > 0) return 'between';
  return 'ok';
}

export function MovesSheet({
  open,
  onClose,
  room,
  game,
  mySeat,
}: {
  open: boolean;
  onClose: () => void;
  room: RoomView;
  game: GameView;
  mySeat: number | null;
}) {
  const t = useT();
  const lang = useLang();
  const [confirm, setConfirm] = useState(false);
  const boom = boomStatus(room, game, mySeat);
  const swap = swapStatus(room, game, mySeat);
  const opponents = mySeat === null ? [] : [(mySeat + 1) % 4, (mySeat + 3) % 4];
  // The moment can pass while the sheet is open.
  useEffect(() => {
    if (boom !== 'ok') setConfirm(false);
  }, [boom]);

  return (
    <>
      <Sheet open={open} onClose={onClose} title={t('moves')}>
        <div className="move-card boom">
          <div className="mc-head">
            <span className="mc-icon">💣</span>
            <div>
              <div className="mc-title">{t('boom')}</div>
              <div className="mc-sub">{t('boom_sub')}</div>
            </div>
          </div>
          <button type="button" className="btn btn-rose btn-block" disabled={boom !== 'ok'} onClick={() => setConfirm(true)}>
            💣 {t('boom_call')}
          </button>
          {boom !== 'ok' && <div className="mc-why">{t(`boom_why_${boom}`)}</div>}
        </div>

        <div className="move-card swap">
          <div className="mc-head">
            <span className="mc-icon">🔄</span>
            <div>
              <div className="mc-title">{t('swap')}</div>
              <div className="mc-sub">{t('swap_sub')}</div>
            </div>
          </div>
          <div className="mc-targets">
            {opponents.map((seat) => {
              const m = seatMember(room, seat);
              if (!m) return null;
              return (
                <button
                  key={seat}
                  type="button"
                  className="mc-target"
                  disabled={swap !== 'ok'}
                  onClick={async () => {
                    sfx.play('whoosh');
                    if (await net.offerSwap(seat)) onClose();
                  }}
                >
                  <Avatar profile={m.profile} size={40} />
                  <span>{t('swap_with', { name: displayName(m.profile, lang) })}</span>
                </button>
              );
            })}
          </div>
          {swap !== 'ok' && <div className="mc-why">{t(`swap_why_${swap}`)}</div>}
        </div>
      </Sheet>
      <Dialog open={confirm} onClose={() => setConfirm(false)} className="boom-dialog">
        <div style={{ fontSize: 50 }}>💣</div>
        <h2>{t('boom_confirm_title')}</h2>
        <p>{t('boom_confirm', { n: HAND_SIZE })}</p>
        <div className="dialog-actions">
          <button type="button" className="btn btn-glass" onClick={() => setConfirm(false)}>
            {t('cancel')}
          </button>
          <button
            type="button"
            className="btn btn-rose"
            onClick={async () => {
              setConfirm(false);
              if (await net.boom()) onClose();
            }}
          >
            {t('boom_go')}
          </button>
        </div>
      </Dialog>
    </>
  );
}

/** The opponent's yes/no to a swap, and a banner for everyone else while it waits. */
export function SwapPrompt({ room, game, mySeat }: { room: RoomView; game: GameView; mySeat: number | null }) {
  const t = useT();
  const lang = useLang();
  const offer = game.swapOffer;
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    if (!offer) return;
    const id = setInterval(() => setNow(Date.now()), 250);
    return () => clearInterval(id);
  }, [offer]);
  useEffect(() => {
    if (offer && offer.to === mySeat) {
      sfx.play('turn');
      buzz('turn');
    }
  }, [offer, mySeat]);
  if (!offer) return null;
  const left = Math.max(0, Math.ceil((toLocal(offer.expires) - now) / 1000));
  const from = displayName(seatMember(room, offer.from)?.profile, lang);
  const to = displayName(seatMember(room, offer.to)?.profile, lang);
  if (offer.to === mySeat) {
    const fromMember = seatMember(room, offer.from);
    return (
      <Dialog open className="swap-dialog">
        {fromMember && <Avatar profile={fromMember.profile} size={72} />}
        <h2>🔄 {t('swap_ask', { name: from })}</h2>
        <p>{t('swap_ask_sub')}</p>
        <div className="dialog-actions">
          <button type="button" className="btn btn-glass" onClick={() => net.answerSwap(false)}>
            {t('swap_no')} ({left})
          </button>
          <button
            type="button"
            className="btn btn-turq"
            onClick={() => {
              sfx.play('whoosh');
              net.answerSwap(true);
            }}
          >
            {t('swap_yes')}
          </button>
        </div>
      </Dialog>
    );
  }
  return (
    <div className="surrender-banner swap-banner">
      🔄 {offer.from === mySeat ? t('swap_waiting', { name: to }) : t('swap_watching', { a: from, b: to })} <b>{left}</b>
    </div>
  );
}
