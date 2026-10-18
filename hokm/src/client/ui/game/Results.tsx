import { type CSSProperties, useEffect, useMemo, useState } from 'react';
import { T } from '../../../shared/constants';
import type { GameView, RoomView } from '../../../shared/protocol';
import { teamOf } from '../../../shared/rules';
import { sfx } from '../../audio/sfx';
import { buzz } from '../../fx/haptics';
import { displayName, fmt, useLang, useT } from '../../i18n';
import { toLocal } from '../../net/clock';
import { net } from '../../net/socket';
import { seatMember } from '../../state/selectors';
import { Coin } from '../components/common';

export function Confetti({ count = 46 }: { count?: number }) {
  const pieces = useMemo(
    () =>
      Array.from({ length: count }, (_, i) => ({
        left: Math.random() * 100,
        delay: Math.random() * 0.9,
        dur: 2.2 + Math.random() * 1.8,
        drift: (Math.random() - 0.5) * 140,
        spin: (Math.random() - 0.5) * 1080,
        color: ['#f7c654', '#43dccb', '#ff5d73', '#7c8cff', '#ffffff', '#5dff7a'][i % 6],
        w: 6 + Math.random() * 6,
        h: 8 + Math.random() * 8,
      })),
    [count],
  );
  return (
    <div className="confetti" aria-hidden="true">
      {pieces.map((p, i) => (
        <i
          key={i}
          style={
            {
              left: `${p.left}%`,
              width: p.w,
              height: p.h,
              background: p.color,
              animationDelay: `${p.delay}s`,
              animationDuration: `${p.dur}s`,
              ['--drift' as string]: `${p.drift}px`,
              ['--spin' as string]: `${p.spin}deg`,
            } as CSSProperties
          }
        />
      ))}
    </div>
  );
}

function useCountUp(target: number, ms = 1200) {
  const [value, setValue] = useState(0);
  useEffect(() => {
    const start = performance.now();
    let raf = 0;
    let lastTick = 0;
    const step = (now: number) => {
      const k = Math.min(1, (now - start) / ms);
      const v = Math.round(target * (1 - Math.pow(1 - k, 3)));
      setValue(v);
      if (now - lastTick > 90 && k < 1) {
        lastTick = now;
        sfx.play('coin');
      }
      if (k < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [target, ms]);
  return value;
}

export function HandResult({ game, room, viewSeat, spectating }: { game: GameView; room: RoomView; viewSeat: number; spectating: boolean }) {
  const t = useT();
  const lang = useLang();
  const r = game.handResult!;
  const mine = teamOf(viewSeat);
  const won = r.winnerTeam === mine;
  const nextName = displayName(seatMember(room, r.nextHakem)?.profile, lang);
  const left = Math.max(0, T.handEnd - (Date.now() - toLocal(game.phaseStartedAt)));

  useEffect(() => {
    if (r.kot) {
      sfx.play('kot');
      buzz('win');
    } else if (won || spectating) sfx.play('trickWin');
    else sfx.play('trickLose');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const title = spectating ? t('team_won_hand', { team: r.winnerTeam === 0 ? t('team_a') : t('team_b') }) : won ? t('hand_won') : t('hand_lost');
  return (
    <div className="result-overlay">
      <div className={`result-card ${won ? 'won' : 'lost'}`}>
        {r.kot && <div className={`kot-stamp${r.hakemKot ? ' hakem' : ''}`}>{r.hakemKot ? t('hakem_kot') : t('kot')}</div>}
        <h2>{title}</h2>
        <div className="trick-score ltr">
          <span className="us">{fmt(r.tricks[mine])}</span>
          <span className="dash">–</span>
          <span className="them">{fmt(r.tricks[1 - mine])}</span>
        </div>
        <div className={`points ${won ? 'us' : 'them'}`}>+{fmt(r.points)}</div>
        <div className="scoreline">
          <span className="us">
            {spectating ? t('team_a') : t('us')} {fmt(game.scores[mine])}
          </span>
          <span className="muted"> · {t('to_points', { n: game.targetScore })} · </span>
          <span className="them">
            {spectating ? t('team_b') : t('them')} {fmt(game.scores[1 - mine])}
          </span>
        </div>
        <div className="next">👑 {r.nextHakem === r.hakem ? t('stays_hakem', { name: nextName }) : t('next_hakem', { name: nextName })}</div>
        <div className="countdown">
          <i style={{ animationDuration: `${left}ms` }} />
        </div>
      </div>
    </div>
  );
}

export function MatchResult({ game, room, viewSeat, spectating }: { game: GameView; room: RoomView; viewSeat: number; spectating: boolean }) {
  const t = useT();
  const res = game.matchResult;
  const mine = teamOf(viewSeat);
  const winnerTeam = res?.winnerTeam ?? (game.scores[0] >= game.scores[1] ? 0 : 1);
  const won = !spectating && winnerTeam === mine;
  const reward = res?.rewards[room.you];
  const coins = useCountUp(reward?.coins ?? 0, 1300);
  const isHost = room.hostId === room.you;
  const seatedHumans = room.seats.map((id) => room.members.find((m) => m.id === id)).filter((m) => m && !m.profile.bot && m.online);
  const voted = room.rematch.includes(room.you);
  const seated = room.seats.includes(room.you);

  useEffect(() => {
    sfx.play(won || spectating ? 'win' : 'lose');
    if (won) buzz('win');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const subtitle = res?.reason === 'surrender' ? (winnerTeam === mine && !spectating ? t('surrendered_them') : spectating ? '' : t('surrendered_us')) : '';
  return (
    <div className="result-overlay match">
      {(won || spectating) && <Confetti />}
      <div className={`result-card big ${won ? 'won' : spectating ? '' : 'lost'}`}>
        <div className="trophy">{won ? '🏆' : spectating ? '🎉' : '🥈'}</div>
        <h2>{spectating ? t('team_wins', { team: winnerTeam === 0 ? t('team_a') : t('team_b') }) : won ? t('victory') : t('defeat')}</h2>
        {subtitle && <div className="muted">{subtitle}</div>}
        <div className="trick-score ltr">
          <span className="us">{fmt(game.scores[mine])}</span>
          <span className="dash">–</span>
          <span className="them">{fmt(game.scores[1 - mine])}</span>
        </div>
        {reward && (
          <div className="rewards">
            <div className="rw-title">{t('rewards')}</div>
            <div className="rw-row">
              <span className="rw-coins">
                <Coin size={28} /> +{fmt(coins)}
              </span>
              <span className="rw-xp">+{fmt(reward.xp)} XP</span>
            </div>
            {reward.levelUp && <div className="level-up">⭐ {t('level_up', { n: reward.levelUp })}</div>}
          </div>
        )}
        <div className="result-actions">
          {seated && (
            <button
              type="button"
              className={`btn ${voted ? 'btn-glass' : 'btn-gold'} btn-block`}
              onClick={() => {
                sfx.play('click');
                net.rematch();
              }}
            >
              🔁 {t('play_again_votes', { n: room.rematch.length, m: seatedHumans.length })}
            </button>
          )}
          {voted && (
            <div className="muted" style={{ fontSize: 14 }}>
              {t('waiting_others')}
            </div>
          )}
          <div style={{ display: 'flex', gap: 10, width: '100%' }}>
            {isHost && (
              <button type="button" className="btn btn-glass" style={{ flex: 1 }} onClick={() => net.lobby()}>
                {t('to_lobby')}
              </button>
            )}
            <button type="button" className="btn btn-glass" style={{ flex: 1 }} onClick={() => net.leaveRoom()}>
              {t('home')}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
