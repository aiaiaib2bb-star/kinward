import { useT } from '../../i18n';
import { PlayingCard } from './Card';

/** Three fanned aces over the word "Hokm". */
export function Logo({ compact }: { compact?: boolean }) {
  const t = useT();
  const w = compact ? 38 : 46;
  return (
    <div className={`logo${compact ? ' compact' : ''}`}>
      <div className="logo-mark">
        {['S14', 'H14', 'D14'].map((card, i) => (
          <PlayingCard
            key={card}
            card={card}
            face="face_classic"
            width={w}
            style={{ transform: `translateX(-50%) rotate(${(i - 1) * 22}deg)`, zIndex: i === 1 ? 2 : 1 }}
          />
        ))}
      </div>
      <div className="logo-word">{t('app_name')}</div>
      <div className="logo-sub">{t('tagline')}</div>
    </div>
  );
}
