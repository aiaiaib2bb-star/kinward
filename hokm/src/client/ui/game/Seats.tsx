import { type CSSProperties, type ReactNode, memo } from 'react';
import type { GameView, MemberView, RoomView } from '../../../shared/protocol';
import { teamOf } from '../../../shared/rules';
import { displayName, useLang, useT } from '../../i18n';
import { toLocal } from '../../net/clock';
import { seatMember } from '../../state/selectors';
import { useVoice } from '../../voice/mesh';
import { Avatar } from '../components/Avatar';
import { PlayingCard, SuitIcon } from '../components/Card';
import { MicIcon } from '../components/VoiceButton';
import type { Geo } from './geometry';

/** The seat the table is waiting on right now, if any. */
export function actorOf(game: GameView): number | null {
  if (game.hakem === null) return null;
  switch (game.phase) {
    case 'shuffle':
    case 'trump':
      return game.hakem;
    case 'cut':
      return game.cutter;
    case 'play':
      return game.turn;
    default:
      return null;
  }
}

export function timerFor(game: GameView, seat: number): { start: number; end: number } | null {
  if (actorOf(game) !== seat || !game.deadline || !game.deadlineFrom) return null;
  return { start: toLocal(game.deadlineFrom), end: toLocal(game.deadline) };
}

export const MiniFan = memo(function MiniFan({ count, back, width = 20 }: { count: number; back: string; width?: number }) {
  if (count <= 0) return null;
  const spacing = count > 1 ? Math.min(width * 0.3, 44 / (count - 1)) : 0;
  const total = spacing * (count - 1) + width;
  return (
    <div className="mini-fan" style={{ width: total, height: width * 1.42 }}>
      {Array.from({ length: count }, (_, i) => {
        const off = count > 1 ? (i - (count - 1) / 2) / ((count - 1) / 2) : 0;
        return (
          <PlayingCard
            key={i}
            down
            back={back}
            face="face_classic"
            width={width}
            style={{ position: 'absolute', left: i * spacing, top: off * off * 3, transform: `rotate(${off * 12}deg)` }}
          />
        );
      })}
    </div>
  );
});

interface SeatProps {
  room: RoomView;
  game: GameView;
  seat: number;
  rel: number;
  geo: Geo;
  viewSeat: number;
  count: number;
  onTap: (m: MemberView) => void;
}

export function Seat({ room, game, seat, rel, geo, viewSeat, count, onTap }: SeatProps) {
  const t = useT();
  const lang = useLang();
  const m = seatMember(room, seat);
  const speaking = useVoice((s) => (m ? !!s.speaking[m.id] : false));
  // Only meaningful while we're in voice too: is sound from this person getting through?
  const link = useVoice((s) => (m && s.joined ? s.links[m.id] : undefined));
  if (!m) return null;
  const pos = geo.seats[rel];
  const side = teamOf(seat) === teamOf(viewSeat) ? 'us' : 'them';
  const away = game.away.includes(seat);
  const badge = m.profile.bot ? t('bot_badge') : !m.online ? t('offline_badge') : away || m.auto ? t('auto_badge') : null;
  const isActor = actorOf(game) === seat;
  const size = Math.round(Math.min(72, geo.w * 0.175, geo.h * 0.09));
  const boomer = game.boom?.by === seat;
  // Anchored on the avatar's centre, so the name and cards below never push it around.
  return (
    <div
      className={`seat rel-${rel}${isActor ? ' acting' : ''}${boomer ? ' boomer' : ''}`}
      data-member={m.id}
      style={{ left: pos.x, top: pos.y - size / 2 } as CSSProperties}
    >
      <Avatar
        profile={m.profile}
        size={size}
        timer={timerFor(game, seat)}
        speaking={speaking}
        hakem={game.hakem === seat}
        dim={!m.online}
        badge={badge}
        onClick={() => onTap(m)}
      />
      <div className={`seat-tag ${side}`}>
        {boomer && <span className="boom-mark">💣</span>}
        <span className="nm">{displayName(m.profile, lang)}</span>
        {m.inVoice && (
          <span className={`mic${m.micOn ? ' on' : ''}${link === 'trying' ? ' trying' : ''}`} title={link === 'trying' ? t('voice_trying') : undefined}>
            <MicIcon size={12} off={!m.micOn} />
          </span>
        )}
      </div>
      <div className="seat-fan">
        <MiniFan count={count} back={m.profile.equipped.cardBack} />
      </div>
    </div>
  );
}

function Pips({ won, side }: { won: number; side: 'us' | 'them' }) {
  return (
    <div className={`pips ${side}`}>
      {Array.from({ length: 7 }, (_, i) => (
        <i key={i} className={i < won ? 'on' : ''} />
      ))}
    </div>
  );
}

export function TopBar({
  game,
  viewSeat,
  spectating,
  onMenu,
  onTrump,
}: {
  game: GameView;
  viewSeat: number;
  spectating: boolean;
  onMenu: () => void;
  onTrump: () => void;
}) {
  const t = useT();
  const mine = teamOf(viewSeat);
  const theirs = 1 - mine;
  const chip = (team: number, side: 'us' | 'them', label: ReactNode) => (
    <div className={`team-chip ${side}`}>
      <div className="tc-row">
        <span className="tc-label">{label}</span>
        <span className="tc-score">
          {game.scores[team]}
          <small>/{game.targetScore}</small>
        </span>
      </div>
      <Pips won={game.tricksWon[team]} side={side} />
    </div>
  );
  const boomSide = game.boom ? (teamOf(game.boom.by) === mine ? 'us' : 'them') : null;
  return (
    <div className="topbar ltr">
      {game.boom && (
        <div className={`boom-chip ${boomSide}`}>
          💣 {t('boom')} · {game.tricksWon[game.boom.team]}/13
        </div>
      )}
      <button type="button" className="icon-btn" onClick={onMenu} aria-label={t('menu')}>
        <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round">
          <path d="M4 7h16M4 12h16M4 17h16" />
        </svg>
      </button>
      {chip(mine, 'us', spectating ? t('team_a') : t('us'))}
      <button type="button" className={`trump-badge${game.trump ? ` suit-${game.trump}` : ' none'}`} onClick={onTrump} aria-label={t('hokm')}>
        {game.trump ? <SuitIcon suit={game.trump} /> : <span className="q">?</span>}
        <span className="tb-label">{t('hokm')}</span>
      </button>
      {chip(theirs, 'them', spectating ? t('team_b') : t('them'))}
    </div>
  );
}
