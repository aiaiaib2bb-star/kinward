import { type ReactNode, useEffect } from 'react';
import { fmt } from '../../i18n';
import { sfx } from '../../audio/sfx';

export function Coin({ size = 18 }: { size?: number }) {
  return (
    <svg className="coin-icon" viewBox="0 0 32 32" width={size} height={size} aria-hidden="true">
      <circle cx="16" cy="16" r="15" fill="#e3a21a" />
      <circle cx="16" cy="16" r="12.5" fill="#ffd34d" />
      <circle cx="16" cy="16" r="9.5" fill="none" stroke="#e3a21a" strokeWidth="1.6" />
      <path d="M16 9.5l1.9 4.3 4.6.4-3.5 3 1.1 4.6-4.1-2.5-4.1 2.5 1.1-4.6-3.5-3 4.6-.4z" fill="#e3a21a" />
    </svg>
  );
}

export function CoinAmount({ value, size }: { value: number; size?: number }) {
  return (
    <span className="coin-amount">
      <Coin size={size} />
      <b>{fmt(value)}</b>
    </span>
  );
}

/** A panel that slides up from the bottom of the screen. */
export function Sheet({
  open,
  onClose,
  title,
  children,
  className,
}: {
  open: boolean;
  onClose: () => void;
  title?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);
  if (!open) return null;
  return (
    <div className="sheet-backdrop" onPointerDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className={`sheet${className ? ` ${className}` : ''}`} role="dialog" aria-modal="true">
        <div className="sheet-grip" />
        {title && <div className="sheet-title">{title}</div>}
        {children}
      </div>
    </div>
  );
}

/** A centred dialog for decisions. */
export function Dialog({ open, children, onClose, className }: { open: boolean; children: ReactNode; onClose?: () => void; className?: string }) {
  if (!open) return null;
  return (
    <div className="dialog-backdrop" onPointerDown={(e) => onClose && e.target === e.currentTarget && onClose()}>
      <div className={`dialog${className ? ` ${className}` : ''}`} role="dialog" aria-modal="true">
        {children}
      </div>
    </div>
  );
}

export function Toggle({
  on,
  onChange,
  label,
  sub,
  disabled,
}: {
  on: boolean;
  onChange: (v: boolean) => void;
  label: ReactNode;
  sub?: ReactNode;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      className="row-toggle"
      disabled={disabled}
      onClick={() => {
        sfx.play('click');
        onChange(!on);
      }}
      aria-pressed={on}
    >
      <span className="row-text">
        <span className="row-label">{label}</span>
        {sub && <span className="row-sub">{sub}</span>}
      </span>
      <span className={`switch${on ? ' on' : ''}`}>
        <span className="knob" />
      </span>
    </button>
  );
}

export function Segmented<T extends string | number>({
  value,
  options,
  onChange,
  disabled,
}: {
  value: T;
  options: { value: T; label: ReactNode }[];
  onChange: (v: T) => void;
  disabled?: boolean;
}) {
  return (
    <div className={`segmented${disabled ? ' disabled' : ''}`} role="radiogroup">
      {options.map((o) => (
        <button
          key={String(o.value)}
          type="button"
          role="radio"
          aria-checked={o.value === value}
          className={o.value === value ? 'active' : ''}
          disabled={disabled}
          onClick={() => {
            sfx.play('click');
            onChange(o.value);
          }}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function TopNav({ title, onBack, right }: { title: ReactNode; onBack: () => void; right?: ReactNode }) {
  return (
    <header className="topnav">
      <button type="button" className="icon-btn" onClick={onBack} aria-label="Back">
        <svg viewBox="0 0 24 24" width="22" height="22" className="flip-rtl">
          <path d="M15 5l-7 7 7 7" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </button>
      <h1>{title}</h1>
      <div className="topnav-right">{right}</div>
    </header>
  );
}
