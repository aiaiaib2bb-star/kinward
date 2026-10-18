import { settings } from '../state/settings';

// Android vibrates through the Vibration API. iPhones' Safari has none, but
// since iOS 18 flipping a native switch control gives a haptic tick, so on
// iOS each "on" step of a pattern becomes one tick of a hidden switch.

const PATTERNS = {
  tick: 4,
  tap: 10,
  select: 8,
  play: 14,
  slam: [45, 30, 70],
  slamHard: [60, 25, 90, 25, 60],
  boom: [80, 40, 80, 40, 160],
  turn: [18, 70, 18],
  error: [30, 40, 30],
  win: [25, 50, 25, 50, 80],
  emote: 6,
} as const;

export type Haptic = keyof typeof PATTERNS;

const canVibrate = typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function';
const touchDevice = typeof window !== 'undefined' && ('ontouchstart' in window || navigator.maxTouchPoints > 0);

let iosSwitch: HTMLLabelElement | null = null;

function iosTick() {
  if (!iosSwitch) {
    const label = document.createElement('label');
    label.setAttribute('aria-hidden', 'true');
    label.style.cssText = 'position:fixed;left:-200px;top:0;width:1px;height:1px;overflow:hidden;opacity:0;pointer-events:none';
    const input = document.createElement('input');
    input.type = 'checkbox';
    input.setAttribute('switch', '');
    input.tabIndex = -1;
    label.appendChild(input);
    document.body.appendChild(label);
    iosSwitch = label;
  }
  iosSwitch.click();
}

function tickPattern(pattern: number | readonly number[]) {
  const steps = typeof pattern === 'number' ? [pattern] : pattern;
  let at = 0;
  for (let i = 0; i < steps.length && i < 6; i += 2) {
    if (at === 0) iosTick();
    else setTimeout(iosTick, at);
    at += steps[i] + (steps[i + 1] ?? 0);
  }
}

export function buzz(kind: Haptic) {
  if (!settings.get().haptics) return;
  try {
    if (canVibrate) navigator.vibrate(PATTERNS[kind] as number | number[]);
    else if (touchDevice) tickPattern(PATTERNS[kind]);
  } catch {
    // Not supported.
  }
}
