// Everything the shop sells, and everything a new player already owns.
// The server prices and validates purchases from this list; the client
// renders items from the same ids, so the two can never disagree.

export type ItemKind = 'avatar' | 'cardBack' | 'cardFace' | 'table' | 'frame' | 'aura' | 'slam' | 'throwable' | 'emotes';
export type Rarity = 'common' | 'rare' | 'epic' | 'legendary';
export type EquipSlot = 'avatar' | 'cardBack' | 'cardFace' | 'table' | 'frame' | 'aura' | 'slam';

export interface Item {
  id: string;
  kind: ItemKind;
  price: number;
  rarity: Rarity;
  name: { en: string; fa: string };
  /** An emoji for avatars and throwables, the emote list for emote packs. */
  glyph?: string;
  emotes?: string[];
}

export const EQUIP_SLOTS: readonly EquipSlot[] = ['avatar', 'cardBack', 'cardFace', 'table', 'frame', 'aura', 'slam'];

const item = (id: string, kind: ItemKind, price: number, rarity: Rarity, en: string, fa: string, extra: Partial<Item> = {}): Item => ({
  id,
  kind,
  price,
  rarity,
  name: { en, fa },
  ...extra,
});

const avatar = (id: string, glyph: string, price: number, rarity: Rarity, en: string, fa: string) => item(id, 'avatar', price, rarity, en, fa, { glyph });

const throwable = (id: string, glyph: string, price: number, rarity: Rarity, en: string, fa: string) => item(id, 'throwable', price, rarity, en, fa, { glyph });

export const ITEMS: readonly Item[] = [
  // Avatars
  avatar('av_lion', '🦁', 0, 'common', 'Lion', 'شیر'),
  avatar('av_tiger', '🐯', 0, 'common', 'Tiger', 'ببر'),
  avatar('av_fox', '🦊', 0, 'common', 'Fox', 'روباه'),
  avatar('av_bear', '🐻', 0, 'common', 'Bear', 'خرس'),
  avatar('av_panda', '🐼', 0, 'common', 'Panda', 'پاندا'),
  avatar('av_koala', '🐨', 0, 'common', 'Koala', 'کوالا'),
  avatar('av_frog', '🐸', 0, 'common', 'Frog', 'قورباغه'),
  avatar('av_monkey', '🐵', 0, 'common', 'Monkey', 'میمون'),
  avatar('av_owl', '🦉', 0, 'common', 'Owl', 'جغد'),
  avatar('av_wolf', '🐺', 0, 'common', 'Wolf', 'گرگ'),
  avatar('av_cat', '🐱', 0, 'common', 'Cat', 'گربه'),
  avatar('av_dog', '🐶', 0, 'common', 'Dog', 'سگ'),
  avatar('av_camel', '🐫', 250, 'common', 'Camel', 'شتر'),
  avatar('av_eagle', '🦅', 300, 'rare', 'Eagle', 'عقاب'),
  avatar('av_shark', '🦈', 350, 'rare', 'Shark', 'کوسه'),
  avatar('av_octopus', '🐙', 350, 'rare', 'Octopus', 'هشت‌پا'),
  avatar('av_cheetah', '🐆', 450, 'rare', 'Persian Cheetah', 'یوزپلنگ ایرانی'),
  avatar('av_peacock', '🦚', 450, 'rare', 'Peacock', 'طاووس'),
  avatar('av_unicorn', '🦄', 550, 'epic', 'Unicorn', 'تک‌شاخ'),
  avatar('av_wizard', '🧙', 600, 'epic', 'Wizard', 'جادوگر'),
  avatar('av_dragon', '🐉', 700, 'epic', 'Dragon', 'اژدها'),
  avatar('av_genie', '🧞', 800, 'epic', 'Genie', 'غول چراغ'),
  avatar('av_prince', '🤴', 1000, 'legendary', 'Prince', 'شاهزاده'),
  avatar('av_princess', '👸', 1000, 'legendary', 'Princess', 'شاهدخت'),

  // Card backs — the back of your hand is what everyone else at the table sees.
  item('back_crimson', 'cardBack', 0, 'common', 'Crimson Classic', 'کلاسیک قرمز'),
  item('back_royal', 'cardBack', 0, 'common', 'Royal Blue', 'آبی سلطنتی'),
  item('back_kashi', 'cardBack', 300, 'rare', 'Kashi Tile', 'کاشی'),
  item('back_termeh', 'cardBack', 450, 'rare', 'Termeh Paisley', 'ترمه'),
  item('back_starry', 'cardBack', 500, 'rare', 'Starry Night', 'شب پرستاره'),
  item('back_yalda', 'cardBack', 650, 'epic', 'Yalda Pomegranate', 'انار یلدا'),
  item('back_neon', 'cardBack', 700, 'epic', 'Neon Grid', 'شبکه نئون'),
  item('back_marble', 'cardBack', 800, 'epic', 'Black Marble', 'مرمر سیاه'),
  item('back_sun', 'cardBack', 1200, 'legendary', 'Golden Sun', 'خورشید طلایی'),
  item('back_peacock', 'cardBack', 1500, 'legendary', 'Peacock Feather', 'پر طاووس'),

  // Card faces — how cards look on your own screen.
  item('face_classic', 'cardFace', 0, 'common', 'Classic', 'کلاسیک'),
  item('face_farsi', 'cardFace', 350, 'rare', 'Farsi Numerals', 'اعداد فارسی'),
  item('face_ivory', 'cardFace', 400, 'rare', 'Vintage Ivory', 'عاج قدیمی'),
  item('face_noir', 'cardFace', 600, 'epic', 'Noir', 'نوآر'),
  item('face_gilded', 'cardFace', 1000, 'legendary', 'Gilded', 'زرنگار'),

  // Tables
  item('table_felt', 'table', 0, 'common', 'Green Felt', 'ماهوت سبز'),
  item('table_navy', 'table', 250, 'common', 'Navy Felt', 'ماهوت سرمه‌ای'),
  item('table_walnut', 'table', 400, 'rare', 'Walnut', 'چوب گردو'),
  item('table_midnight', 'table', 500, 'rare', 'Midnight', 'نیمه‌شب'),
  item('table_isfahan', 'table', 650, 'epic', 'Isfahan Tiles', 'کاشی اصفهان'),
  item('table_carpet', 'table', 900, 'epic', 'Persian Carpet', 'فرش ایرانی'),

  // Avatar frames
  item('frame_none', 'frame', 0, 'common', 'No Frame', 'بدون قاب'),
  item('frame_silver', 'frame', 150, 'common', 'Silver', 'نقره‌ای'),
  item('frame_gold', 'frame', 350, 'rare', 'Gold', 'طلایی'),
  item('frame_turquoise', 'frame', 450, 'rare', 'Turquoise', 'فیروزه‌ای'),
  item('frame_neon', 'frame', 600, 'epic', 'Neon Pulse', 'نئون'),
  item('frame_fire', 'frame', 800, 'epic', 'Ring of Fire', 'حلقه آتش'),
  item('frame_rainbow', 'frame', 1000, 'legendary', 'Rainbow', 'رنگین‌کمان'),
  item('frame_crown', 'frame', 1500, 'legendary', 'Jeweled Gold', 'طلای جواهرنشان'),

  // Profile effects — they surround your avatar wherever you appear.
  item('aura_none', 'aura', 0, 'common', 'No Effect', 'بدون جلوه'),
  item('aura_sparkle', 'aura', 400, 'rare', 'Sparkles', 'درخشش'),
  item('aura_hearts', 'aura', 450, 'rare', 'Hearts', 'قلب‌ها'),
  item('aura_snow', 'aura', 500, 'rare', 'Snowfall', 'بارش برف'),
  item('aura_petals', 'aura', 550, 'epic', 'Rose Petals', 'گلبرگ رز'),
  item('aura_flames', 'aura', 800, 'epic', 'Flames', 'شعله‌ها'),
  item('aura_stars', 'aura', 900, 'epic', 'Orbiting Stars', 'ستاره‌های چرخان'),
  item('aura_storm', 'aura', 1300, 'legendary', 'Storm', 'طوفان'),

  // Slams — what the table does when you throw a card down hard.
  item('slam_thud', 'slam', 0, 'common', 'Thud', 'تق'),
  item('slam_confetti', 'slam', 400, 'rare', 'Confetti', 'کاغذ رنگی'),
  item('slam_lightning', 'slam', 600, 'epic', 'Lightning', 'صاعقه'),
  item('slam_fire', 'slam', 700, 'epic', 'Fireball', 'گوی آتش'),
  item('slam_quake', 'slam', 1000, 'legendary', 'Earthquake', 'زلزله'),

  // Throwables — tap someone's avatar to throw one at them.
  throwable('throw_rose', '🌹', 0, 'common', 'Rose', 'گل رز'),
  throwable('throw_tomato', '🍅', 0, 'common', 'Tomato', 'گوجه'),
  throwable('throw_tea', '🫖', 150, 'common', 'Cup of Chai', 'چای'),
  throwable('throw_egg', '🥚', 200, 'common', 'Egg', 'تخم‌مرغ'),
  throwable('throw_kiss', '💋', 200, 'common', 'Kiss', 'بوس'),
  throwable('throw_melon', '🍉', 300, 'rare', 'Watermelon', 'هندوانه'),
  throwable('throw_bouquet', '💐', 300, 'rare', 'Bouquet', 'دسته گل'),
  throwable('throw_slipper', '🩴', 400, 'rare', "Mom's Slipper", 'دمپایی مامان'),
  throwable('throw_firecracker', '🧨', 450, 'epic', 'Firecracker', 'ترقه'),

  // Emote packs
  item('emotes_basic', 'emotes', 0, 'common', 'Basic Emotes', 'شکلک‌ها', {
    emotes: ['😂', '😎', '😡', '😱', '🤔', '👏', '🔥', '😭', '😍', '🙏'],
  }),
  item('emotes_animals', 'emotes', 300, 'rare', 'Animal Pack', 'بسته حیوانات', {
    emotes: ['🐒', '🐢', '🐔', '🦁', '🐍', '🦊', '🐌', '🐷'],
  }),
  item('emotes_royal', 'emotes', 400, 'rare', 'Royal Pack', 'بسته شاهانه', {
    emotes: ['👑', '💎', '🏆', '💰', '🗡️', '🛡️', '🎯', '🧿'],
  }),
  item('phrases_basic', 'emotes', 0, 'common', 'Table Talk', 'حرف‌های سر میز', {
    emotes: ['p_bahbah', 'p_eyval', 'p_luck', 'p_hurry', 'p_sorry', 'p_nice', 'p_think', 'p_gg', 'p_kot', 'p_watch'],
  }),
  item('phrases_spicy', 'emotes', 350, 'rare', 'Spicy Talk', 'حرف‌های تند', {
    emotes: ['p_cry', 'p_again', 'p_trump', 'p_oops', 'p_tea', 'p_master'],
  }),
];

export const PHRASES: Record<string, { en: string; fa: string }> = {
  p_bahbah: { en: 'Bah bah! 👌', fa: 'به به! 👌' },
  p_eyval: { en: 'Eyval! 👏', fa: 'ایول! 👏' },
  p_luck: { en: 'Pure luck 🍀', fa: 'شانسی بود 🍀' },
  p_hurry: { en: 'Hurry up ⏳', fa: 'زود باش ⏳' },
  p_sorry: { en: 'Sorry partner 🙏', fa: 'ببخشید رفیق 🙏' },
  p_nice: { en: 'Nice one, partner!', fa: 'دمت گرم رفیق!' },
  p_think: { en: 'Let me think 🤔', fa: 'بذار فکر کنم 🤔' },
  p_gg: { en: 'Good game 🤝', fa: 'بازی خوبی بود 🤝' },
  p_kot: { en: 'Kot is coming! 🔥', fa: 'کُت در راهه! 🔥' },
  p_watch: { en: 'Watch this 😏', fa: 'اینو ببین 😏' },
  p_cry: { en: "Don't cry 😢", fa: 'گریه نکن 😢' },
  p_again: { en: 'We won again 😎', fa: 'باز هم بردیم 😎' },
  p_trump: { en: 'Got any trump? 😈', fa: 'حکم داری؟ 😈' },
  p_oops: { en: 'Oops 🙈', fa: 'اوپس 🙈' },
  p_tea: { en: 'Tea break? ☕', fa: 'چای بخوریم؟ ☕' },
  p_master: { en: 'The master is here 👑', fa: 'استاد اومد 👑' },
};

const BY_ID = new Map(ITEMS.map((i) => [i.id, i]));

export function getItem(id: string): Item | undefined {
  return BY_ID.get(id);
}

export const KIND_SLOT: Partial<Record<ItemKind, EquipSlot>> = {
  avatar: 'avatar',
  cardBack: 'cardBack',
  cardFace: 'cardFace',
  table: 'table',
  frame: 'frame',
  aura: 'aura',
  slam: 'slam',
};

export type Equipped = Record<EquipSlot, string>;

export const DEFAULT_EQUIPPED: Equipped = {
  avatar: 'av_lion',
  cardBack: 'back_crimson',
  cardFace: 'face_classic',
  table: 'table_felt',
  frame: 'frame_none',
  aura: 'aura_none',
  slam: 'slam_thud',
};

/** Everything free is owned from the start. */
export const STARTER_ITEMS: readonly string[] = ITEMS.filter((i) => i.price === 0).map((i) => i.id);

/** All emotes (emoji or phrase ids) a player with these items may send. */
export function emotesOwned(owned: readonly string[]): Set<string> {
  const out = new Set<string>();
  for (const id of owned) {
    const it = BY_ID.get(id);
    if (it?.kind === 'emotes') for (const e of it.emotes ?? []) out.add(e);
  }
  return out;
}
