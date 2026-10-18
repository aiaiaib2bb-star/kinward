// The server's clock, as seen from here. Deadlines and phase start times
// come from the server; turning them into "seconds left" needs the offset.

let offset = 0;
let samples = 0;

export function syncClock(serverNow: number) {
  const sample = serverNow - Date.now();
  // Smooth a little so one slow packet doesn't make the timers jump.
  offset = samples === 0 ? sample : offset * 0.7 + sample * 0.3;
  samples += 1;
}

export function serverNow(): number {
  return Date.now() + offset;
}

/** Converts a server timestamp to local Date.now() time. */
export function toLocal(serverTime: number): number {
  return serverTime - offset;
}
