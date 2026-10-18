import { type CSSProperties, memo } from 'react';
import { getItem } from '../../../shared/catalog';
import type { PublicProfile } from '../../../shared/protocol';

function hue(id: string): number {
  let h = 0;
  for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) % 360;
  return h;
}

export function avatarGlyph(avatarId: string | undefined): string {
  return getItem(avatarId ?? '')?.glyph ?? '🦁';
}

/** Particles around an avatar for each profile effect. */
function Aura({ aura }: { aura: string }) {
  if (!aura || aura === 'aura_none') return null;
  const count = { aura_sparkle: 7, aura_hearts: 5, aura_snow: 7, aura_petals: 6, aura_flames: 5, aura_stars: 3, aura_storm: 4 }[aura] ?? 0;
  const glyph = { aura_sparkle: '✦', aura_hearts: '❤', aura_snow: '❄', aura_petals: '', aura_flames: '', aura_stars: '★', aura_storm: '⚡' }[aura] ?? '';
  return (
    <div className={`aura ${aura}`} aria-hidden="true">
      {Array.from({ length: count }, (_, i) => (
        <span key={i} className="p" style={{ ['--i' as string]: i, ['--n' as string]: count } as CSSProperties}>
          {glyph}
        </span>
      ))}
    </div>
  );
}

export interface AvatarProps {
  profile: Pick<PublicProfile, 'id' | 'equipped' | 'level'> & { bot?: boolean };
  size: number;
  speaking?: boolean;
  /** A countdown ring: local start and end times. */
  timer?: { start: number; end: number } | null;
  hakem?: boolean;
  dim?: boolean;
  badge?: string | null;
  showLevel?: boolean;
  onClick?: () => void;
  className?: string;
}

export const Avatar = memo(function Avatar({ profile, size, speaking, timer, hakem, dim, badge, showLevel, onClick, className }: AvatarProps) {
  const { equipped } = profile;
  const h = hue(equipped.avatar + profile.id);
  const style = {
    ['--s' as string]: `${size}px`,
    ['--h' as string]: h,
  } as CSSProperties;
  const total = timer ? Math.max(1, timer.end - timer.start) : 0;
  const elapsed = timer ? Math.min(total, Math.max(0, Date.now() - timer.start)) : 0;
  const Tag = onClick ? 'button' : 'div';
  return (
    <Tag
      className={`avatar ${equipped.frame}${speaking ? ' speaking' : ''}${dim ? ' dim' : ''}${className ? ` ${className}` : ''}`}
      style={style}
      onClick={onClick}
      type={onClick ? 'button' : undefined}
    >
      <Aura aura={equipped.aura} />
      <div className="avatar-disc">
        <span className="avatar-glyph">{avatarGlyph(equipped.avatar)}</span>
      </div>
      <div className="avatar-frame" />
      {timer && (
        <svg className="timer-ring" viewBox="0 0 100 100" key={`${timer.start}-${timer.end}`}>
          <circle cx="50" cy="50" r="47" pathLength="100" style={{ animationDuration: `${total}ms`, animationDelay: `-${elapsed}ms` }} />
        </svg>
      )}
      {hakem && (
        <span className="hakem-crown" aria-label="Hakem">
          👑
        </span>
      )}
      {showLevel && <span className="level-badge">{profile.level}</span>}
      {badge && <span className="avatar-badge">{badge}</span>}
    </Tag>
  );
});
