import { settings } from '../state/settings';

// Android vibrates; iOS Safari has no vibration API, so this quietly does nothing there.

const PATTERNS = {
  tick: 4,
  tap: 10,
  select: 8,
  play: 14,
  slam: [35, 25, 50],
  turn: [18, 70, 18],
  error: [30, 40, 30],
  win: [25, 50, 25, 50, 80],
  emote: 6,
} as const;

export type Haptic = keyof typeof PATTERNS;

export function buzz(kind: Haptic) {
  if (!settings.get().haptics) return;
  try {
    navigator.vibrate?.(PATTERNS[kind] as number | number[]);
  } catch {
    // Not supported.
  }
}
