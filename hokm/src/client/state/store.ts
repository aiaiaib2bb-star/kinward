import { useSyncExternalStore } from 'react';

// A tiny external store. Components subscribe to a slice through a selector;
// selectors must return something already stored (not a fresh object), so a
// re-render only happens when that slice actually changes.

export interface Store<T> {
  get(): T;
  set(patch: Partial<T> | ((state: T) => Partial<T>)): void;
  subscribe(listener: () => void): () => void;
}

export function createStore<T extends object>(initial: T): Store<T> {
  let state = initial;
  const listeners = new Set<() => void>();
  return {
    get: () => state,
    set(patch) {
      const next = typeof patch === 'function' ? patch(state) : patch;
      state = { ...state, ...next };
      for (const l of listeners) l();
    },
    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
  };
}

export function useStore<T extends object, U>(store: Store<T>, selector: (state: T) => U): U {
  return useSyncExternalStore(store.subscribe, () => selector(store.get()));
}
