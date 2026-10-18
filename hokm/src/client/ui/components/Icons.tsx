import type { ReactNode } from 'react';

// Line icons for the menus, drawn in the current colour so they take the
// gold of the buttons they sit on.

function Icon({ size = 26, children, fill }: { size?: number; children: ReactNode; fill?: boolean }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      fill={fill ? 'currentColor' : 'none'}
      stroke={fill ? 'none' : 'currentColor'}
      strokeWidth="1.9"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {children}
    </svg>
  );
}

export const ChipIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <rect x="6" y="6" width="12" height="12" rx="2" />
    <rect x="9.5" y="9.5" width="5" height="5" rx="1" />
    <path d="M9 2.5V6M15 2.5V6M9 18v3.5M15 18v3.5M2.5 9H6M2.5 15H6M18 9h3.5M18 15h3.5" />
  </Icon>
);

export const PeopleIcon = ({ size }: { size?: number }) => (
  <Icon size={size} fill>
    <circle cx="8.5" cy="8" r="3.6" />
    <circle cx="16.5" cy="9" r="3" />
    <path d="M1.8 19.5c.4-3.8 3.2-6.3 6.7-6.3s6.3 2.5 6.7 6.3c0 .5-.4.9-.9.9H2.7c-.5 0-.9-.4-.9-.9zM15.8 20.4c.2-.4.3-.8.2-1.3-.2-1.9-1-3.6-2.2-4.8.8-.4 1.7-.6 2.7-.6 3 0 5.3 2.1 5.7 5.3 0 .7-.4 1.4-1.2 1.4z" />
  </Icon>
);

export const KeyIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <circle cx="8" cy="15" r="4.5" />
    <path d="M11.3 11.7 20 3M16.5 6.5l2.5 2.5M14 9l2 2" />
  </Icon>
);

export const GlobeIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <circle cx="12" cy="12" r="9" />
    <path d="M3 12h18M12 3c2.6 2.6 3.8 5.6 3.8 9S14.6 18.4 12 21c-2.6-2.6-3.8-5.6-3.8-9S9.4 5.6 12 3z" />
  </Icon>
);

export const CartIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <path d="M2.5 3.5h2.6l2.4 11.2h10.6l2.3-8H6.3" />
    <circle cx="9" cy="19.5" r="1.5" />
    <circle cx="17" cy="19.5" r="1.5" />
  </Icon>
);

export const TrophyIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <path d="M7 3.5h10v5a5 5 0 0 1-10 0z" />
    <path d="M7 5.5H3.8c0 3 1.2 4.6 3.6 5M17 5.5h3.2c0 3-1.2 4.6-3.6 5M12 13.5v3.5M8 20.5h8M9.5 17h5l.8 3.5H8.7z" />
  </Icon>
);

export const HistoryIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <path d="M3.5 12a8.5 8.5 0 1 0 2.5-6" />
    <path d="M3 3.5V8h4.5M12 7.5V12l3 2" />
  </Icon>
);

export const BookIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <path d="M12 6.5C10 4.8 7 4.2 3 4.5v14c4-.3 7 .3 9 2 2-1.7 5-2.3 9-2v-14c-4-.3-7 .3-9 2zM12 6.5v14" />
  </Icon>
);

export const GearIcon = ({ size }: { size?: number }) => (
  <Icon size={size}>
    <circle cx="12" cy="12" r="3.2" />
    <path d="M12 2.8v2.4M12 18.8v2.4M21.2 12h-2.4M5.2 12H2.8M18.5 5.5l-1.7 1.7M7.2 16.8l-1.7 1.7M18.5 18.5l-1.7-1.7M7.2 7.2 5.5 5.5" />
  </Icon>
);

export const ChevronIcon = ({ size = 18 }: { size?: number }) => (
  <svg viewBox="0 0 24 24" width={size} height={size} className="flip-rtl" aria-hidden="true">
    <path d="M9 5l7 7-7 7" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
);

/** A crown in one of the podium metals. */
export function Crown({ size = 30, metal = 'gold' }: { size?: number; metal?: 'gold' | 'silver' | 'bronze' }) {
  const fill = { gold: ['#fff1b8', '#f7c654', '#b97c12'], silver: ['#ffffff', '#cfd6df', '#7f8b99'], bronze: ['#ffd9b8', '#e09a5f', '#8a4c1c'] }[metal];
  const id = `crown-${metal}`;
  return (
    <svg viewBox="0 0 40 30" width={size} height={(size * 30) / 40} aria-hidden="true">
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={fill[0]} />
          <stop offset=".55" stopColor={fill[1]} />
          <stop offset="1" stopColor={fill[2]} />
        </linearGradient>
      </defs>
      <path d="M4 25 2.5 8l9.5 8L20 3l8 13 9.5-8L36 25z" fill={`url(#${id})`} stroke={fill[2]} strokeWidth="1.2" strokeLinejoin="round" />
      <rect x="4" y="24" width="32" height="4.5" rx="1.5" fill={`url(#${id})`} stroke={fill[2]} strokeWidth="1" />
      <circle cx="20" cy="3.5" r="2.4" fill={fill[0]} stroke={fill[2]} strokeWidth="1" />
      <circle cx="2.8" cy="8" r="2" fill={fill[0]} stroke={fill[2]} strokeWidth="1" />
      <circle cx="37.2" cy="8" r="2" fill={fill[0]} stroke={fill[2]} strokeWidth="1" />
      <path d="M20 13.5l2.2 3.5-2.2 3.5-2.2-3.5z" fill="#e8344e" opacity=".85" />
    </svg>
  );
}

/** The arched crest with the crown and the name, as on the home screen. */
export function Crest({ compact }: { compact?: boolean }) {
  return (
    <div className={`crest${compact ? ' compact' : ''}`}>
      {!compact && (
        <svg className="crest-arch" viewBox="0 0 300 200" preserveAspectRatio="none" aria-hidden="true">
          <path
            d="M20 196V92C20 70 40 62 58 58 78 54 96 44 110 28 122 14 136 6 150 2c14 4 28 12 40 26 14 16 32 26 52 30 18 4 38 12 38 34v104"
            fill="rgba(6, 40, 28, .55)"
            stroke="rgba(231, 190, 98, .55)"
            strokeWidth="1.6"
          />
          <path
            d="M34 196V96c0-16 16-23 31-26 21-4 40-16 54-32 10-12 20-19 31-23 11 4 21 11 31 23 14 16 33 28 54 32 15 3 31 10 31 26v100"
            fill="none"
            stroke="rgba(231, 190, 98, .25)"
            strokeWidth="1"
          />
          <path d="M60 120l4-6 4 6-4 6zM232 120l4-6 4 6-4 6z" fill="rgba(231, 190, 98, .6)" />
        </svg>
      )}
      <div className="crest-crown">
        <Crown size={compact ? 26 : 38} />
      </div>
      <div className="crest-word" lang="fa">
        حکم
      </div>
      <div className="crest-latin">HOKM</div>
    </div>
  );
}
