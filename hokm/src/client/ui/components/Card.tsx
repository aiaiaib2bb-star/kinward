import { type CSSProperties, type ReactElement, memo } from 'react';
import { type Card, type Suit, rankOf, rankLabel, suitOf } from '../../../shared/cards';
import { backStyle } from '../../cosmetics/patterns';

// Suits are SVG, never the ♠♥♦♣ characters: iOS turns those into emoji.

const SUIT_PATHS: Record<Suit, ReactElement> = {
  H: <path d="M50 90C45 85 7 59 7 32 7 17 18 7 32 7c8 0 14 4 18 11C54 11 60 7 68 7c14 0 25 10 25 25 0 27-38 53-43 58z" />,
  D: <path d="M50 4Q63 28 89 50 63 72 50 96 37 72 11 50 37 28 50 4z" />,
  S: <path d="M50 5c5 13 43 33 43 58 0 14-10 23-22 23-7 0-13-3-17-9 1 8 4 14 11 19H35c7-5 10-11 11-19-4 6-10 9-17 9C17 86 7 77 7 63 7 38 45 18 50 5z" />,
  C: (
    <g>
      <circle cx="50" cy="29" r="19.5" />
      <circle cx="27" cy="59" r="19.5" />
      <circle cx="73" cy="59" r="19.5" />
      <path d="M44 50h12c0 18 4 30 13 41H31c9-11 13-23 13-41z" />
    </g>
  ),
};

export function SuitIcon({ suit, size, color, className }: { suit: Suit; size?: number | string; color?: string; className?: string }) {
  return (
    <svg className={className} viewBox="0 0 100 100" width={size} height={size} fill={color ?? 'currentColor'} aria-hidden="true">
      {SUIT_PATHS[suit]}
    </svg>
  );
}

const FARSI_DIGITS = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
const FARSI_FACES: Record<number, string> = { 11: 'س', 12: 'ب', 13: 'ش', 14: 'آ' };

function cornerLabel(rank: number, face: string): string {
  if (face === 'face_farsi') {
    if (rank >= 11) return FARSI_FACES[rank];
    return String(rank)
      .split('')
      .map((d) => FARSI_DIGITS[Number(d)])
      .join('');
  }
  return rankLabel(rank);
}

/** King, queen and jack — the shah, the bibi and the sarbaz — each get an emblem in the suit's colour. */
function FaceEmblem({ rank }: { rank: number }) {
  const ink = 'var(--suit)';
  const gold = 'var(--card-gold)';
  if (rank === 13) {
    return (
      <svg viewBox="0 0 100 100" className="emblem">
        <path d="M14 74 18 34l17 18 15-30 15 30 17-18 4 40z" fill={gold} stroke={ink} strokeWidth="3" strokeLinejoin="round" />
        <rect x="13" y="72" width="74" height="12" rx="3" fill={ink} />
        <circle cx="18" cy="31" r="5.5" fill={ink} />
        <circle cx="50" cy="19" r="6" fill={ink} />
        <circle cx="82" cy="31" r="5.5" fill={ink} />
        <circle cx="33" cy="78" r="3" fill={gold} />
        <circle cx="50" cy="78" r="3.4" fill={gold} />
        <circle cx="67" cy="78" r="3" fill={gold} />
      </svg>
    );
  }
  if (rank === 12) {
    return (
      <svg viewBox="0 0 100 100" className="emblem">
        <path d="M16 76c2-22 14-38 34-48 20 10 32 26 34 48z" fill={gold} stroke={ink} strokeWidth="3" strokeLinejoin="round" />
        <path d="M30 76c2-12 9-22 20-28 11 6 18 16 20 28" fill="none" stroke={ink} strokeWidth="2.4" opacity=".7" />
        <path d="M50 38l7 12-7 12-7-12z" fill={ink} />
        <circle cx="22" cy="58" r="3.6" fill={ink} />
        <circle cx="78" cy="58" r="3.6" fill={ink} />
        <circle cx="50" cy="22" r="5" fill={ink} />
        <rect x="15" y="74" width="70" height="9" rx="3" fill={ink} />
      </svg>
    );
  }
  return (
    <svg viewBox="0 0 100 100" className="emblem">
      <path d="M50 12 82 24l-4 32c-3 16-14 27-28 34-14-7-25-18-28-34l-4-32z" fill={gold} stroke={ink} strokeWidth="3" strokeLinejoin="round" />
      <path d="M50 24v52" stroke={ink} strokeWidth="5" strokeLinecap="round" />
      <path d="M38 36h24" stroke={ink} strokeWidth="5" strokeLinecap="round" />
      <circle cx="50" cy="24" r="4.5" fill={ink} />
    </svg>
  );
}

export interface CardFaceProps {
  card: Card;
  face: string;
  fourColor?: boolean;
}

export const CardFace = memo(function CardFace({ card, face, fourColor }: CardFaceProps) {
  const suit = suitOf(card);
  const rank = rankOf(card);
  const label = cornerLabel(rank, face);
  return (
    <div className={`card-front ${face} suit-${suit}${fourColor ? ' four' : ''}`}>
      <div className="corner tl">
        <span className={`rank${label.length > 1 ? ' wide' : ''}`}>{label}</span>
        <SuitIcon suit={suit} className="corner-suit" />
      </div>
      <div className="corner br">
        <span className={`rank${label.length > 1 ? ' wide' : ''}`}>{label}</span>
        <SuitIcon suit={suit} className="corner-suit" />
      </div>
      <div className={`center rank-${rank >= 11 && rank <= 13 ? 'face' : rank === 14 ? 'ace' : 'pip'}`}>
        {rank >= 11 && rank <= 13 ? (
          <>
            <FaceEmblem rank={rank} />
            <SuitIcon suit={suit} className="face-suit" />
          </>
        ) : (
          <SuitIcon suit={suit} className="big-suit" />
        )}
      </div>
    </div>
  );
});

export const CardBack = memo(function CardBack({ back }: { back: string }) {
  const style = backStyle(back);
  return (
    <div className="card-back-face">
      <div className="card-back-art" style={{ background: style.background, ['--frame' as string]: style.frame } as CSSProperties}>
        {style.emblem && <div className="card-back-emblem" style={{ backgroundImage: style.emblem }} />}
      </div>
    </div>
  );
});

export interface CardProps {
  card?: Card;
  /** Show the back instead of the face. */
  down?: boolean;
  back?: string;
  face: string;
  fourColor?: boolean;
  width: number;
  className?: string;
  style?: CSSProperties;
}

export const PlayingCard = memo(function PlayingCard({ card, down, back = 'back_crimson', face, fourColor, width, className, style }: CardProps) {
  return (
    <div className={`card${className ? ` ${className}` : ''}`} style={{ ...style, ['--cw' as string]: `${width}px` } as CSSProperties}>
      {down || !card ? <CardBack back={back} /> : <CardFace card={card} face={face} fourColor={fourColor} />}
    </div>
  );
});

/** A card that can turn over: both faces are drawn back to back. */
export function FlipCard({ card, back, face, fourColor, width, className, style }: CardProps & { card: Card }) {
  return (
    <div className={`card flip${className ? ` ${className}` : ''}`} style={{ ...style, ['--cw' as string]: `${width}px` } as CSSProperties}>
      <div className="flip-inner">
        <CardFace card={card} face={face} fourColor={fourColor} />
        <CardBack back={back ?? 'back_crimson'} />
      </div>
    </div>
  );
}
