import type { Lang } from '../../shared/protocol';
import { createStore, useStore } from './store';

export interface Settings {
  lang: Lang;
  sound: boolean;
  volume: number;
  haptics: boolean;
  fourColor: boolean;
  reduceMotion: boolean;
  voiceMode: 'open' | 'ptt';
  muteEmotes: boolean;
  tips: boolean;
  seenTips: string[];
}

const KEY = 'hokm.settings';

function initialLang(): Lang {
  try {
    return navigator.language?.toLowerCase().startsWith('fa') ? 'fa' : 'en';
  } catch {
    return 'en';
  }
}

const defaults: Settings = {
  lang: initialLang(),
  sound: true,
  volume: 0.8,
  haptics: true,
  fourColor: false,
  reduceMotion: false,
  voiceMode: 'open',
  muteEmotes: false,
  tips: true,
  seenTips: [],
};

function load(): Settings {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return { ...defaults, ...JSON.parse(raw) };
  } catch {
    // Private mode or blocked storage: defaults are fine.
  }
  return { ...defaults };
}

export const settings = createStore<Settings>(load());

settings.subscribe(() => {
  try {
    localStorage.setItem(KEY, JSON.stringify(settings.get()));
  } catch {
    // Not persisted this session.
  }
});

export function useSettings<U>(selector: (s: Settings) => U): U {
  return useStore(settings, selector);
}

export function markTipSeen(id: string) {
  const s = settings.get();
  if (!s.seenTips.includes(id)) settings.set({ seenTips: [...s.seenTips, id] });
}
