import type { Profile, RTCIceServerLike, RoomView } from '../../shared/protocol';
import { createStore, useStore } from './store';

export type Screen = 'home' | 'shop' | 'profile' | 'settings' | 'rules' | 'history' | 'leaderboard';

export interface Toast {
  id: number;
  text: string;
  tone: 'info' | 'good' | 'bad';
}

export interface AppState {
  conn: 'connecting' | 'online' | 'offline';
  /** The server has answered our hello (or said we need a profile). */
  ready: boolean;
  needsProfile: boolean;
  profile: Profile | null;
  room: RoomView | null;
  screen: Screen;
  toasts: Toast[];
  iceServers: RTCIceServerLike[];
  /** Another tab or phone took over this profile. */
  elsewhere: boolean;
  /** A table code from the link that opened the app, joined once we're signed in. */
  pendingJoin: string | null;
  /** What this server has switched on. */
  features: { gifs: boolean };
}

export const app = createStore<AppState>({
  conn: 'connecting',
  ready: false,
  needsProfile: false,
  profile: null,
  room: null,
  screen: 'home',
  toasts: [],
  iceServers: [],
  elsewhere: false,
  pendingJoin: null,
  features: { gifs: false },
});

export function useApp<U>(selector: (s: AppState) => U): U {
  return useStore(app, selector);
}

let toastSeq = 0;

export function toast(text: string, tone: Toast['tone'] = 'info', ms = 2600) {
  const id = ++toastSeq;
  app.set((s) => ({ toasts: [...s.toasts.slice(-2), { id, text, tone }] }));
  setTimeout(() => app.set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })), ms);
}

export function go(screen: Screen) {
  app.set({ screen });
}
