import { type CSSProperties, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { type Card, sortHand, suitOf } from '../../../shared/cards';
import type { MemberView, RoomView } from '../../../shared/protocol';
import { ledSuit, teamOf } from '../../../shared/rules';
import { sfx } from '../../audio/sfx';
import { tableStyle } from '../../cosmetics/patterns';
import { emitFx } from '../../fx/bus';
import { buzz } from '../../fx/haptics';
import { displayName, useLang, useT } from '../../i18n';
import { serverNow } from '../../net/clock';
import { errorText, net } from '../../net/socket';
import { toast, useApp } from '../../state/app';
import { mySeat as seatOfMe, seatMember } from '../../state/selectors';
import { markTipSeen, useSettings } from '../../state/settings';
import { useVoice } from '../../voice/mesh';
import { Avatar } from '../components/Avatar';
import { ChatButton, ChatSheet } from '../components/Chat';
import { VoiceButton } from '../components/VoiceButton';
import { FxLayer } from './Fx';
import { useGeometry } from './geometry';
import { Hand, type PlayOrigin } from './Hand';
import { HandResult, MatchResult } from './Results';
import { Seat, TopBar, actorOf, timerFor } from './Seats';
import { AwayBanner, EmoteSheet, GameMenu, LastTrickSheet, PlayerSheet, SurrenderPrompt } from './Sheets';
import { DealLayer, DeckStage, HakemSelect, TrumpAnnounce, TrumpPicker, TrumpWaiting, useDealCounts } from './Stages';
import { TrickLayer } from './Trick';

const coarsePointer = typeof matchMedia === 'function' && matchMedia('(pointer: coarse)').matches;

function useWakeLock(active: boolean) {
  useEffect(() => {
    if (!active || !('wakeLock' in navigator)) return;
    let lock: WakeLockSentinel | null = null;
    let gone = false;
    const take = async () => {
      try {
        lock = await navigator.wakeLock.request('screen');
      } catch {
        // Battery saver or an unsupported browser: the screen may dim, nothing more.
      }
    };
    const onVisible = () => document.visibilityState === 'visible' && !gone && take();
    void take();
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      gone = true;
      document.removeEventListener('visibilitychange', onVisible);
      void lock?.release().catch(() => {});
    };
  }, [active]);
}

export function Game({ room }: { room: RoomView }) {
  const t = useT();
  const lang = useLang();
  const game = room.game!;
  const profile = useApp((s) => s.profile)!;
  const fourColor = useSettings((s) => s.fourColor);
  const tipsOn = useSettings((s) => s.tips);
  const seenTips = useSettings((s) => s.seenTips);
  const speakingMe = useVoice((s) => !!s.speaking[room.you]);
  const root = useRef<HTMLDivElement>(null);
  const table = useRef<HTMLDivElement>(null);
  const geo = useGeometry(root);
  const mySeat = seatOfMe(room);
  const spectating = mySeat === null;
  const viewSeat = mySeat ?? 0;
  const rel = useCallback((seat: number) => (seat - viewSeat + 4) % 4, [viewSeat]);
  const face = profile.equipped.cardFace;
  const backOf = useCallback((seat: number) => seatMember(room, seat)?.profile.equipped.cardBack ?? 'back_crimson', [room]);

  const [menu, setMenu] = useState(false);
  const [chat, setChat] = useState(false);
  const [emotes, setEmotes] = useState(false);
  const [lastTrick, setLastTrick] = useState(false);
  const [target, setTarget] = useState<MemberView | null>(null);
  const [pending, setPending] = useState<{ card: Card; power: number } | null>(null);
  const origins = useRef(new Map<Card, PlayOrigin>());

  useWakeLock(true);
  // Where your cards left the hand only matters until they land; start each hand fresh.
  useEffect(() => origins.current.clear(), [game.handNumber]);
  const dealCounts = useDealCounts(game);

  // A played card is "pending" until the server's next view has it on the table.
  useEffect(() => {
    if (pending && (game.trick.some((p) => p.card === pending.card) || !game.hand.includes(pending.card))) setPending(null);
  }, [game.trick, game.hand, pending]);

  const hand = useMemo(() => {
    let cards = game.hand;
    if (dealCounts && mySeat !== null) cards = cards.slice(0, dealCounts[mySeat]);
    if (pending) cards = cards.filter((c) => c !== pending.card);
    return sortHand(cards, game.trump);
  }, [game.hand, game.trump, dealCounts, mySeat, pending]);

  const myTurn = game.phase === 'play' && game.turn === mySeat && !pending;
  const legal = useMemo(() => (myTurn ? new Set(game.legal) : null), [myTurn, game.legal]);

  const plays = useMemo(() => {
    if (!pending || mySeat === null || game.trick.some((p) => p.card === pending.card)) return game.trick;
    return [...game.trick, { seat: mySeat, card: pending.card }];
  }, [game.trick, pending, mySeat]);
  const slams = useMemo(() => (pending?.power ? { ...game.trickSlams, [pending.card]: pending.power } : game.trickSlams), [game.trickSlams, pending]);

  const onPlay = (card: Card, power: number, from: PlayOrigin) => {
    origins.current.set(card, from);
    setPending({ card, power });
    if (power > 0) {
      sfx.play('flick');
      emitFx({ type: 'localSlam', power, card });
    } else {
      sfx.play('card');
      buzz('play');
    }
    void net.play(card, power).then((res) => {
      if (!res.ok) {
        origins.current.delete(card);
        setPending((p) => (p?.card === card ? null : p));
        toast(errorText(res.error), 'bad');
      }
    });
    if (!seenTips.includes('flick') && power === 0) markTipSeen('drag');
    if (power > 0) markTipSeen('flick');
  };

  const onReject = (card: Card) => {
    if (!myTurn) {
      toast(t('not_your_turn'), 'info', 1400);
      return;
    }
    const led = ledSuit(game.trick);
    if (led && suitOf(card) !== led) toast(t('must_follow', { suit: t(`suit_${led}`) }), 'info', 1600);
  };

  // Sound and buzz when it becomes your move; ticks for the last seconds.
  const actor = actorOf(game);
  const myAction = actor !== null && actor === mySeat;
  const prevAction = useRef(false);
  useEffect(() => {
    if (myAction && !prevAction.current) {
      sfx.play('turn');
      buzz('turn');
    }
    prevAction.current = myAction;
  }, [myAction, game.phase]);

  useEffect(() => {
    if (!myAction || !game.deadline) return;
    const id = setInterval(() => {
      const left = game.deadline! - serverNow();
      if (left > 0 && left < 5200) sfx.play('tick');
    }, 1000);
    return () => clearInterval(id);
  }, [myAction, game.deadline]);

  // Tell a backgrounded tab it's your turn.
  useEffect(() => {
    const base = 'Hokm · حکم';
    document.title = myAction && document.hidden ? `🔔 ${t('your_turn')}` : base;
    const onVis = () => {
      document.title = !document.hidden || !myAction ? base : `🔔 ${t('your_turn')}`;
    };
    document.addEventListener('visibilitychange', onVis);
    return () => {
      document.removeEventListener('visibilitychange', onVis);
      document.title = base;
    };
  }, [myAction, t]);

  // A trick being taken: a little chime for your side, a lower one for theirs.
  const prevPhase = useRef(game.phase);
  useEffect(() => {
    if (game.phase === 'trickEnd' && prevPhase.current !== 'trickEnd' && game.trickWinner !== null) {
      sfx.play(teamOf(game.trickWinner) === teamOf(viewSeat) ? 'trickWin' : 'trickLose');
    }
    prevPhase.current = game.phase;
  }, [game.phase, game.trickWinner, viewSeat]);

  const tableBg = tableStyle(profile.equipped.table);
  const me = room.members.find((m) => m.id === room.you);
  const hakemName = displayName(seatMember(room, game.hakem ?? -1)?.profile, lang);
  const showTip = tipsOn && mySeat !== null && game.phase === 'play' && (!seenTips.includes('drag') || !seenTips.includes('flick'));
  const away = mySeat !== null && game.away.includes(mySeat);
  const inVoice = room.members.filter((m) => m.inVoice).length;
  const handEnabled = mySeat !== null && !dealCounts;

  return (
    <div className="game" style={{ background: tableBg.background, ['--tint' as string]: tableBg.tint } as CSSProperties}>
      <div className="table-vignette" />
      {/* On a big screen the table keeps a phone's proportions, centred on the felt. */}
      <div ref={root} className="game-stage">
        {geo && (
          <>
            <div ref={table} className="table-shake">
              {[1, 2, 3].map((r) => {
                const seat = (viewSeat + r) % 4;
                const count = dealCounts ? dealCounts[seat] : game.handCounts[seat];
                return <Seat key={seat} room={room} game={game} seat={seat} rel={r} geo={geo} viewSeat={viewSeat} count={count} onTap={setTarget} />;
              })}
              {spectating && seatMember(room, 0) && (
                <Seat
                  room={room}
                  game={game}
                  seat={0}
                  rel={0}
                  geo={geo}
                  viewSeat={viewSeat}
                  count={dealCounts ? dealCounts[0] : game.handCounts[0]}
                  onTap={setTarget}
                />
              )}

              <TrickLayer
                geo={geo}
                rel={rel}
                face={face}
                fourColor={fourColor}
                backOf={backOf}
                plays={plays}
                slams={slams}
                origins={origins.current}
                winner={game.phase === 'trickEnd' ? game.trickWinner : null}
                last={game.lastTrick}
              />

              {game.phase === 'hakemSelect' && <HakemSelect game={game} geo={geo} rel={rel} room={room} face={face} fourColor={fourColor} mySeat={mySeat} />}
              {(game.phase === 'shuffle' || game.phase === 'cut') && (
                <DeckStage game={game} geo={geo} room={room} mySeat={mySeat} back={backOf(game.hakem ?? 0)} />
              )}
              {(game.phase === 'deal1' || game.phase === 'deal2') && (
                <DealLayer key={`${game.phase}-${game.phaseStartedAt}`} game={game} geo={geo} rel={rel} back={backOf(game.hakem ?? 0)} />
              )}
              {game.phase === 'deal2' && game.trump && <TrumpAnnounce key={game.phaseStartedAt} suit={game.trump} game={game} />}
              {game.phase === 'trump' && (game.hakem === mySeat ? <TrumpPicker hand={game.hand} /> : <TrumpWaiting name={hakemName} />)}

              {!spectating && me && (
                <div className={`mybar ltr${myAction ? ' acting' : ''}`} style={{ top: geo.myBarY }}>
                  <div className="mybar-me" data-member={me.id}>
                    <Avatar
                      profile={me.profile}
                      size={44}
                      timer={timerFor(game, mySeat!)}
                      hakem={game.hakem === mySeat}
                      speaking={speakingMe}
                      onClick={() => setEmotes(true)}
                    />
                  </div>
                  <div className="mybar-status">
                    {myTurn ? (
                      <span className="turn-pill">✨ {t('your_turn')}</span>
                    ) : game.phase === 'play' && game.turn !== null ? (
                      <span className="wait-pill">⏳ {displayName(seatMember(room, game.turn)?.profile, lang)}</span>
                    ) : null}
                  </div>
                  <div className="mybar-actions">
                    <button type="button" className="round-btn" onClick={() => setEmotes(true)} aria-label={t('emotes')}>
                      😊
                    </button>
                    <ChatButton room={room} onOpen={() => setChat(true)} />
                    <VoiceButton size={44} inVoiceCount={inVoice} />
                  </div>
                </div>
              )}

              {mySeat !== null && (
                <Hand geo={geo} cards={hand} legal={legal} face={face} fourColor={fourColor} enabled={handEnabled} onPlay={onPlay} onReject={onReject} />
              )}

              {showTip && (
                <div className="tip" style={{ top: Math.min(geo.myBarY - 78, geo.center.y + geo.trickCardH * 0.9 + 12) }}>
                  {!seenTips.includes('drag') ? t('drag_hint') : t('flick_hint')}
                </div>
              )}

              <FxLayer room={room} geo={geo} rel={rel} mySeat={mySeat} table={table} />
            </div>

            <TopBar
              game={game}
              viewSeat={viewSeat}
              spectating={spectating}
              onMenu={() => setMenu(true)}
              onTrump={() => game.trump && toast(t('trump_is', { suit: t(`suit_${game.trump}`) }), 'info', 1500)}
            />

            {spectating && (
              <div className="spectating-bar">
                👁️ {t('spectating')}
                <ChatButton room={room} onOpen={() => setChat(true)} />
                <button type="button" className="round-btn" onClick={() => setEmotes(true)}>
                  😊
                </button>
                <VoiceButton size={40} inVoiceCount={inVoice} />
              </div>
            )}

            {away && <AwayBanner onBack={() => net.back()} />}
            <SurrenderPrompt game={game} mySeat={mySeat} />
            {game.phase === 'handEnd' && game.handResult && <HandResult game={game} room={room} viewSeat={viewSeat} spectating={spectating} />}
            {game.phase === 'matchEnd' && <MatchResult game={game} room={room} viewSeat={viewSeat} spectating={spectating} />}
          </>
        )}
      </div>

      {geo && geo.landscape && geo.h < 500 && coarsePointer && (
        <div className="rotate-hint">
          <div className="rotate-phone">📱</div>
          <b>{t('rotate_title')}</b>
          <span className="muted">{t('rotate_sub')}</span>
        </div>
      )}

      <GameMenu open={menu} onClose={() => setMenu(false)} onLastTrick={() => setLastTrick(true)} seated={mySeat !== null} />
      <LastTrickSheet open={lastTrick} onClose={() => setLastTrick(false)} game={game} room={room} rel={rel} />
      <EmoteSheet open={emotes} onClose={() => setEmotes(false)} />
      <ChatSheet room={room} open={chat} onClose={() => setChat(false)} />
      <PlayerSheet member={target} room={room} onClose={() => setTarget(null)} />
    </div>
  );
}
