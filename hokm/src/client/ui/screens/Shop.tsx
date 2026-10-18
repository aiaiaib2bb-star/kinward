import { type CSSProperties, useState } from 'react';
import { type Collection, ITEMS, type Item, type ItemKind, KIND_SLOT } from '../../../shared/catalog';
import { SLAM_SOUND, THROW_SOUND, sfx } from '../../audio/sfx';
import { tableStyle } from '../../cosmetics/patterns';
import { buzz } from '../../fx/haptics';
import { fmt, phraseText, useLang, useT } from '../../i18n';
import type { StringKey } from '../../i18n/strings';
import { net } from '../../net/socket';
import { go, toast, useApp } from '../../state/app';
import { publicOf } from '../../state/selectors';
import { useSettings } from '../../state/settings';
import { Avatar } from '../components/Avatar';
import { PlayingCard } from '../components/Card';
import { Coin, CoinAmount, Sheet, TopNav } from '../components/common';

const TABS: { id: string; label: StringKey; kinds: ItemKind[] }[] = [
  { id: 'cards', label: 'tab_cards', kinds: ['cardBack', 'cardFace'] },
  { id: 'table', label: 'tab_table', kinds: ['table'] },
  { id: 'look', label: 'tab_look', kinds: ['avatar', 'frame', 'aura'] },
  { id: 'fun', label: 'tab_fun', kinds: ['slam', 'throwable', 'emotes'] },
];

interface Section {
  kind: ItemKind;
  /** Card backs come in collections; `null` is the rest of that kind. */
  collection?: Collection | null;
}

function sectionsOf(kinds: ItemKind[]): Section[] {
  return kinds.flatMap((kind): Section[] =>
    kind === 'cardBack'
      ? [
          { kind, collection: 'ornate' },
          { kind, collection: 'celestial' },
          { kind, collection: null },
        ]
      : [{ kind }],
  );
}

function sectionTitle(sec: Section): StringKey {
  if (sec.collection) return `collection_${sec.collection}` as StringKey;
  return `cat_${sec.kind}` as StringKey;
}

export const SLAM_ICON: Record<string, string> = {
  slam_thud: '💥',
  slam_confetti: '🎊',
  slam_lightning: '⚡',
  slam_fire: '🔥',
  slam_quake: '🌋',
};

export function ItemPreview({ item, big }: { item: Item; big?: boolean }) {
  const profile = useApp((s) => s.profile)!;
  const fourColor = useSettings((s) => s.fourColor);
  const me = publicOf(profile);
  const scale = big ? 1.7 : 1;
  switch (item.kind) {
    case 'avatar':
      return <Avatar profile={{ ...me, equipped: { ...me.equipped, avatar: item.id } }} size={58 * scale} />;
    case 'frame':
      return <Avatar profile={{ ...me, equipped: { ...me.equipped, frame: item.id, aura: 'aura_none' } }} size={52 * scale} />;
    case 'aura':
      return <Avatar profile={{ ...me, equipped: { ...me.equipped, aura: item.id, frame: 'frame_none' } }} size={44 * scale} />;
    case 'cardBack':
      return <PlayingCard down back={item.id} face="face_classic" width={50 * scale} />;
    case 'cardFace':
      return (
        <div className="face-fan">
          {['S14', 'H13', 'D10'].map((c, i) => (
            <PlayingCard key={c} card={c} face={item.id} fourColor={fourColor} width={40 * scale} style={{ transform: `rotate(${(i - 1) * 8}deg)` }} />
          ))}
        </div>
      );
    case 'table':
      return (
        <div className="table-swatch" style={{ background: tableStyle(item.id).background, minHeight: big ? 160 : 80 } as CSSProperties}>
          <PlayingCard card="H14" face={profile.equipped.cardFace} fourColor={fourColor} width={30 * scale} style={{ transform: 'rotate(-8deg)' }} />
        </div>
      );
    case 'slam':
      return (
        <span className="big-glyph" style={{ fontSize: 46 * scale }}>
          {SLAM_ICON[item.id] ?? '💥'}
        </span>
      );
    case 'throwable':
      return (
        <span className="big-glyph" style={{ fontSize: 44 * scale }}>
          {item.glyph}
        </span>
      );
    case 'emotes':
      return (
        <div className="emote-list" style={{ fontSize: big ? 30 : 20 }}>
          {(item.emotes ?? []).slice(0, big ? 16 : 4).map((e) =>
            e.startsWith('p_') ? (
              <span key={e} className="phrase-chip" style={big ? { fontSize: 14 } : undefined}>
                {big ? phraseText(e) : '💬'}
              </span>
            ) : (
              <span key={e}>{e}</span>
            ),
          )}
        </div>
      );
  }
}

export function Shop() {
  const t = useT();
  const lang = useLang();
  const profile = useApp((s) => s.profile)!;
  const [tab, setTab] = useState('cards');
  const [selected, setSelected] = useState<Item | null>(null);
  const current = TABS.find((x) => x.id === tab)!;

  const isEquipped = (it: Item) => {
    const slot = KIND_SLOT[it.kind];
    return slot ? profile.equipped[slot] === it.id : false;
  };

  return (
    <div className="screen">
      <div className="screen-inner">
        <TopNav
          title={t('shop_title')}
          onBack={() => go('home')}
          right={
            <span className="coin-pill">
              <CoinAmount value={profile.coins} />
            </span>
          }
        />
        <div className="earn-hint">
          <Coin size={26} />
          <span>{t('earn_hint')}</span>
        </div>
        <div className="shop-tabs">
          {TABS.map((x) => (
            <button
              key={x.id}
              type="button"
              className={`shop-tab${x.id === tab ? ' active' : ''}`}
              onClick={() => {
                sfx.play('click');
                setTab(x.id);
              }}
            >
              {t(x.label)}
            </button>
          ))}
        </div>
        {sectionsOf(current.kinds).map((sec) => (
          <section key={`${sec.kind}-${sec.collection ?? ''}`}>
            <div className={`section-title${sec.collection ? ' collection-title' : ''}`}>
              {sec.collection && '✨ '}
              {t(sectionTitle(sec))}
              {sec.collection && <span className="new-chip">{t('new_badge')}</span>}
            </div>
            <div className="shop-grid">
              {ITEMS.filter((i) => i.kind === sec.kind && (sec.collection === undefined || (i.collection ?? null) === sec.collection))
                // What you can buy comes first; what you already have follows.
                .sort((a, b) => Number(profile.owned.includes(a.id)) - Number(profile.owned.includes(b.id)) || a.price - b.price)
                .map((it) => {
                  const owned = profile.owned.includes(it.id);
                  const equipped = isEquipped(it);
                  return (
                    <button
                      key={it.id}
                      type="button"
                      className={`shop-item${equipped ? ' equipped' : ''}`}
                      onClick={() => {
                        sfx.play('select');
                        setSelected(it);
                      }}
                    >
                      <span className={`rarity-dot rarity-${it.rarity}`} />
                      <div className="preview">
                        <ItemPreview item={it} />
                      </div>
                      <div className="item-name">{it.name[lang]}</div>
                      {equipped ? (
                        <div className="state">✓ {t('equipped')}</div>
                      ) : owned ? (
                        <div className="state" style={{ color: 'var(--muted)' }}>
                          {t('owned')}
                        </div>
                      ) : (
                        <div className="price">
                          <CoinAmount value={it.price} size={14} />
                        </div>
                      )}
                    </button>
                  );
                })}
            </div>
          </section>
        ))}
      </div>
      <ItemSheet item={selected} onClose={() => setSelected(null)} />
    </div>
  );
}

function ItemSheet({ item, onClose }: { item: Item | null; onClose: () => void }) {
  const t = useT();
  const lang = useLang();
  const profile = useApp((s) => s.profile)!;
  const [busy, setBusy] = useState(false);
  const [preview, setPreview] = useState(0);
  if (!item)
    return (
      <Sheet open={false} onClose={onClose}>
        {null}
      </Sheet>
    );
  const owned = profile.owned.includes(item.id);
  const slot = KIND_SLOT[item.kind];
  const equipped = slot ? profile.equipped[slot] === item.id : false;
  const short = item.price - profile.coins;

  const buy = async () => {
    setBusy(true);
    const ok = await net.buy(item.id);
    if (ok) {
      sfx.play('coin');
      setTimeout(() => sfx.play('win'), 120);
      buzz('win');
      toast(t('bought'), 'good');
      if (slot) await net.equip(item.id);
    }
    setBusy(false);
  };

  const equip = async () => {
    setBusy(true);
    if (await net.equip(item.id)) {
      sfx.play('chime');
      buzz('tap');
    }
    setBusy(false);
  };

  const playPreview = () => {
    setPreview((n) => n + 1);
    if (item.kind === 'slam') {
      sfx.play('slam', 0.8);
      const extra = SLAM_SOUND[item.id];
      if (extra && extra !== 'slam') sfx.play(extra, 0.8);
      buzz('slam');
    } else if (item.kind === 'throwable') sfx.play(THROW_SOUND[item.id] ?? 'pop');
  };

  return (
    <Sheet open onClose={onClose}>
      <div className="item-detail">
        <div className={`big-preview${preview && item.kind === 'slam' ? ' shaking' : ''}`} key={preview}>
          <ItemPreview item={item} big />
          {preview > 0 && item.kind === 'slam' && <div className={`fx-slam-preview ${item.id}`} />}
        </div>
        <span className={`rarity-text rarity-${item.rarity}`}>{t(`rarity_${item.rarity}` as StringKey)}</span>
        <h3>{item.name[lang]}</h3>
        <p>{t(`hint_${item.kind}` as StringKey)}</p>
        {(item.kind === 'slam' || item.kind === 'throwable') && (
          <button type="button" className="btn btn-glass btn-small" onClick={playPreview}>
            ▶ {t('preview')}
          </button>
        )}
        <div style={{ width: '100%', marginTop: 6 }}>
          {equipped ? (
            <button type="button" className="btn btn-glass btn-block" disabled>
              ✓ {t('equipped')}
            </button>
          ) : owned ? (
            slot ? (
              <button type="button" className="btn btn-turq btn-block" onClick={equip} disabled={busy}>
                {t('equip')}
              </button>
            ) : (
              <button type="button" className="btn btn-glass btn-block" disabled>
                ✓ {t('owned')}
              </button>
            )
          ) : short > 0 ? (
            <button type="button" className="btn btn-glass btn-block" disabled>
              <Coin /> {t('need_more', { n: fmt(short) })}
            </button>
          ) : (
            <button type="button" className="btn btn-gold btn-block" onClick={buy} disabled={busy}>
              <Coin /> {t('buy_for', { n: fmt(item.price) })}
            </button>
          )}
        </div>
      </div>
    </Sheet>
  );
}
