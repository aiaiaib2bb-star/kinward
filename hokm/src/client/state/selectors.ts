import { levelOf } from '../../shared/constants';
import type { MemberView, Profile, PublicProfile, RoomView } from '../../shared/protocol';
import { useApp } from './app';

/** Your own profile, shaped like everyone else's. */
export function publicOf(p: Profile): PublicProfile {
  return {
    id: p.id,
    name: p.name,
    level: levelOf(p.xp),
    equipped: p.equipped,
    stats: { played: p.stats.played, won: p.stats.won, kots: p.stats.kots, hakemKots: p.stats.hakemKots, bestStreak: p.stats.bestStreak },
  };
}

export function memberOf(room: RoomView, id: string | null | undefined): MemberView | undefined {
  return id ? room.members.find((m) => m.id === id) : undefined;
}

export function seatMember(room: RoomView, seat: number): MemberView | undefined {
  return memberOf(room, room.seats[seat]);
}

export function mySeat(room: RoomView): number | null {
  const i = room.seats.indexOf(room.you);
  return i < 0 ? null : i;
}

export function useRoom(): RoomView | null {
  return useApp((s) => s.room);
}
