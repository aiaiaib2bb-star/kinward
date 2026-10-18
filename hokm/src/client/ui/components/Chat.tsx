import { useEffect, useRef, useState } from 'react';
import { LIMITS } from '../../../shared/constants';
import type { RoomView } from '../../../shared/protocol';
import { sfx } from '../../audio/sfx';
import { displayName, useLang, useT } from '../../i18n';
import { net } from '../../net/socket';
import { useApp } from '../../state/app';
import { memberOf } from '../../state/selectors';
import { createStore, useStore } from '../../state/store';
import { Avatar } from './Avatar';
import { Sheet } from './common';
import { GifImage, GifPicker } from './Gifs';

// The id of the newest message the player has seen, for the unread badge.
const seen = createStore({ last: 0 });

export function useUnread(room: RoomView): number {
  const last = useStore(seen, (s) => s.last);
  return room.chat.filter((m) => m.id > last && m.from !== room.you).length;
}

export function ChatButton({ room, onOpen }: { room: RoomView; onOpen: () => void }) {
  const unread = useUnread(room);
  return (
    <button type="button" className="round-btn" onClick={onOpen} aria-label="Chat">
      <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinejoin="round">
        <path d="M4 5h16v11H9l-5 4z" fill="rgba(255,255,255,.12)" />
      </svg>
      {unread > 0 && <span className="badge">{unread > 9 ? '9+' : unread}</span>}
    </button>
  );
}

export function ChatSheet({ room, open, onClose }: { room: RoomView; open: boolean; onClose: () => void }) {
  const t = useT();
  const lang = useLang();
  const gifsOn = useApp((s) => s.features.gifs);
  const [text, setText] = useState('');
  const [picking, setPicking] = useState(false);
  const list = useRef<HTMLDivElement>(null);
  const newest = room.chat[room.chat.length - 1]?.id ?? 0;

  useEffect(() => {
    if (!open) return;
    seen.set({ last: newest });
    list.current?.scrollTo({ top: list.current.scrollHeight });
  }, [open, newest, picking]);

  useEffect(() => {
    if (!open) setPicking(false);
  }, [open]);

  const send = () => {
    const clean = text.trim();
    if (!clean) return;
    net.chat(clean);
    sfx.play('pop');
    setText('');
  };

  return (
    <Sheet open={open} onClose={onClose} title={t('chat')} className="chat-sheet">
      {picking ? (
        <GifPicker
          onPick={(gif) => {
            void net.sendGif(gif.id);
            setPicking(false);
          }}
        />
      ) : (
        <div className="chat-list" ref={list}>
          {room.chat.length === 0 && <div className="chat-empty">{t('chat_empty')}</div>}
          {room.chat.map((m) => {
            const member = memberOf(room, m.from);
            const mine = m.from === room.you;
            return (
              <div key={m.id} className={`chat-msg${mine ? ' mine' : ''}`}>
                {member && !mine && <Avatar profile={member.profile} size={28} />}
                <div className={`bubble${m.gif ? ' has-gif' : ''}`}>
                  {!mine && <div className="who">{displayName(member?.profile, lang)}</div>}
                  {m.gif ? <GifImage gif={m.gif} width={170} /> : <div dir="auto">{m.text}</div>}
                </div>
              </div>
            );
          })}
        </div>
      )}
      <form
        className="chat-input"
        onSubmit={(e) => {
          e.preventDefault();
          send();
        }}
      >
        {gifsOn && (
          <button
            type="button"
            className={`gif-toggle${picking ? ' active' : ''}`}
            onClick={() => {
              sfx.play('click');
              setPicking((v) => !v);
            }}
            aria-label={t('gif')}
          >
            GIF
          </button>
        )}
        <input
          className="text-input"
          value={text}
          dir="auto"
          maxLength={LIMITS.chatLength}
          placeholder={t('chat_placeholder')}
          enterKeyHint="send"
          onChange={(e) => setText(e.target.value)}
          onFocus={() => setPicking(false)}
        />
        <button type="submit" className="btn btn-gold" disabled={!text.trim()}>
          {t('send')}
        </button>
      </form>
    </Sheet>
  );
}
