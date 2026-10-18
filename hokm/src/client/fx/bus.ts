import type { FxEvent } from '../../shared/protocol';

// Transient table effects (emotes, throws, slams, chat bubbles) don't belong
// in state: they happen once. Components subscribe to them here.

type Local = { type: 'shake'; power: number } | { type: 'localSlam'; power: number; card: string };
export type BusEvent = FxEvent | Local;

const listeners = new Set<(e: BusEvent) => void>();

export function onFx(listener: (e: BusEvent) => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function emitFx(e: BusEvent) {
  for (const l of listeners) l(e);
}
