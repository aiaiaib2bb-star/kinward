// Card backs and tables are drawn as SVG patterns inlined into CSS, so they
// scale crisply to any card size and cost nothing to download.

const svg = (body: string, w: number, h: number) =>
  `url("data:image/svg+xml,${encodeURIComponent(`<svg xmlns='http://www.w3.org/2000/svg' width='${w}' height='${h}' viewBox='0 0 ${w} ${h}'>${body}</svg>`)}")`;

export interface BackStyle {
  /** CSS background for the patterned area inside the white border. */
  background: string;
  /** Artwork backs are a picture that fills the whole card, border and all. */
  image?: string;
  /** An optional emblem drawn over the centre. */
  emblem?: string;
  /** Colour of the thin frame line just inside the white border. */
  frame: string;
}

const crimsonLattice = svg(
  `<path d='M0 6 6 0 12 6 6 12Z' fill='none' stroke='rgba(255,255,255,.38)' stroke-width='.9'/><circle cx='6' cy='6' r='1.1' fill='rgba(255,255,255,.55)'/><circle cx='0' cy='0' r='1.1' fill='rgba(255,255,255,.55)'/><circle cx='12' cy='12' r='1.1' fill='rgba(255,255,255,.55)'/><circle cx='12' cy='0' r='1.1' fill='rgba(255,255,255,.55)'/><circle cx='0' cy='12' r='1.1' fill='rgba(255,255,255,.55)'/>`,
  12,
  12,
);

const royalRings = svg(
  `<g fill='none' stroke='rgba(255,255,255,.32)' stroke-width='.9'><circle cx='7' cy='7' r='5.4'/><circle cx='0' cy='0' r='5.4'/><circle cx='14' cy='0' r='5.4'/><circle cx='0' cy='14' r='5.4'/><circle cx='14' cy='14' r='5.4'/></g><circle cx='7' cy='7' r='1' fill='rgba(255,255,255,.5)'/>`,
  14,
  14,
);

const kashiStars = svg(
  `<rect width='24' height='24' fill='#0b5f78'/><g fill='none' stroke='#f2d27b' stroke-width='1.05'><rect x='6.5' y='6.5' width='11' height='11'/><rect x='6.5' y='6.5' width='11' height='11' transform='rotate(45 12 12)'/></g><circle cx='12' cy='12' r='2.3' fill='#2fc6c0'/><path d='M0 0h3.5L0 3.5zM24 0h-3.5L24 3.5zM0 24h3.5L0 20.5zM24 24h-3.5l3.5-3.5z' fill='#e9f6f1'/>`,
  24,
  24,
);

const termehPaisley = svg(
  `<g fill='none' stroke='#e8c66d' stroke-width='1' stroke-linecap='round'><path d='M7 3c4.2 0 6.4 4.2 4.3 7.4-2 3-6.4 3.2-7.3.2-.6-2.4 1.6-3.7 3-2.6 1 .8.6 2.2-.3 2.2'/><path d='M18 16c4.2 0 6.4 4.2 4.3 7.4' /><path d='M-4 16c4.2 0 6.4 4.2 4.3 7.4'/></g><g fill='#e8c66d'><circle cx='17' cy='6' r='1'/><circle cx='6' cy='19' r='1.1'/><circle cx='12' cy='22' r='.6'/><circle cx='21' cy='11' r='.6'/></g>`,
  22,
  26,
);

const starfield = svg(
  `<g fill='#fff'><circle cx='4' cy='6' r='.7' opacity='.9'/><circle cx='22' cy='3' r='.5' opacity='.6'/><circle cx='34' cy='14' r='.9' opacity='.8'/><circle cx='12' cy='22' r='.5' opacity='.5'/><circle cx='28' cy='30' r='.6' opacity='.7'/><circle cx='6' cy='34' r='.8' opacity='.85'/><circle cx='38' cy='38' r='.5' opacity='.5'/><path d='M18 12l.6 1.6 1.6.6-1.6.6-.6 1.6-.6-1.6-1.6-.6 1.6-.6z' opacity='.9'/></g>`,
  40,
  40,
);

const moon = svg(
  `<defs><radialGradient id='g' cx='.4' cy='.4' r='.7'><stop offset='0' stop-color='#fff6cf'/><stop offset='1' stop-color='#f1c75a'/></radialGradient></defs><path d='M58 20a30 30 0 1 0 22 50 25 25 0 1 1-22-50z' fill='url(#g)'/><path d='M74 30l1.8 4.6 4.6 1.8-4.6 1.8-1.8 4.6-1.8-4.6-4.6-1.8 4.6-1.8z' fill='#fff6cf'/>`,
  100,
  100,
);

const pomegranateSeeds = svg(
  `<g fill='#e8344e'><path d='M5 2c2 0 3 2 3 3.4S6.6 9 5 9 2 7 2 5.4 3 2 5 2z'/><path d='M15 10c2 0 3 2 3 3.4S16.6 17 15 17s-3-2-3-3.6S13 10 15 10z'/></g><g fill='#ff8a9b' opacity='.8'><circle cx='4.2' cy='4' r='.8'/><circle cx='14.2' cy='12' r='.8'/></g>`,
  20,
  18,
);

const pomegranate = svg(
  `<path d='M50 18l5 10 9-6-3 11c14 4 23 15 23 29 0 18-15 30-34 30S16 80 16 62c0-14 9-25 23-29l-3-11 9 6z' fill='#c3112f' stroke='#ffd27a' stroke-width='2.4'/><path d='M34 54c4-6 10-9 16-9' stroke='#ff8a9b' stroke-width='3' fill='none' stroke-linecap='round' opacity='.8'/><g fill='#ffd27a'><circle cx='44' cy='66' r='2.4'/><circle cx='54' cy='60' r='2.4'/><circle cx='58' cy='72' r='2.4'/><circle cx='46' cy='77' r='2.4'/></g>`,
  100,
  100,
);

const neonGrid = svg(
  `<rect width='16' height='16' fill='none' stroke='#ff2bd6' stroke-width='.7' opacity='.7'/><path d='M0 16 16 0' stroke='#21e6ff' stroke-width='.4' opacity='.45'/>`,
  16,
  16,
);

const neonDiamond = svg(
  `<g fill='none' stroke-linejoin='round'><path d='M50 14 82 50 50 86 18 50z' stroke='#21e6ff' stroke-width='5' opacity='.35'/><path d='M50 14 82 50 50 86 18 50z' stroke='#bff7ff' stroke-width='2'/><path d='M50 30 66 50 50 70 34 50z' stroke='#ff2bd6' stroke-width='2'/></g>`,
  100,
  100,
);

const marbleVeins = svg(
  `<g fill='none' stroke='#d8b45a' stroke-linecap='round'><path d='M-5 30C20 26 30 50 55 44S85 20 110 30' stroke-width='1.2' opacity='.7'/><path d='M-5 90c25-10 40 8 62 0s30-30 55-26' stroke-width='.8' opacity='.55'/><path d='M10 140c20-14 34-4 52-16s34-12 48-4' stroke-width='1.4' opacity='.65'/><path d='M30 44c6 12 2 24 12 34' stroke-width='.6' opacity='.5'/><path d='M70 100c-6 10 0 22-8 34' stroke-width='.6' opacity='.45'/></g><g fill='none' stroke='#fff' opacity='.06'><path d='M-5 60c30 6 50-12 120 4' stroke-width='6'/><path d='M-5 120c40-8 60 10 120-6' stroke-width='9'/></g>`,
  100,
  150,
);

const sunEmblem = svg(
  `<g fill='#a8710f'>${Array.from({ length: 16 }, (_, i) => `<path d='M50 6 54 30 46 30z' transform='rotate(${i * 22.5} 50 50)' opacity='${i % 2 ? 0.55 : 0.9}'/>`).join('')}</g><circle cx='50' cy='50' r='19' fill='#fbe08a' stroke='#a8710f' stroke-width='2.5'/><circle cx='50' cy='50' r='12' fill='none' stroke='#a8710f' stroke-width='1.2' opacity='.7'/>`,
  100,
  100,
);

const sunRays = svg(`<path d='M0 0 10 10M10 0 0 10' stroke='#b9831c' stroke-width='.5' opacity='.35'/>`, 10, 10);

const peacockEyes = svg(
  `<g><ellipse cx='9' cy='11' rx='7' ry='9.5' fill='#0e8f7c' stroke='#e7c45e' stroke-width='.9'/><ellipse cx='9' cy='12' rx='4.3' ry='6' fill='#1f6fd1'/><ellipse cx='9' cy='12.8' rx='2.2' ry='3' fill='#0a1f45'/><ellipse cx='0' cy='-1' rx='7' ry='9.5' fill='#0e8f7c' stroke='#e7c45e' stroke-width='.9'/><ellipse cx='18' cy='-1' rx='7' ry='9.5' fill='#0e8f7c' stroke='#e7c45e' stroke-width='.9'/><ellipse cx='0' cy='23' rx='7' ry='9.5' fill='#0e8f7c' stroke='#e7c45e' stroke-width='.9'/><ellipse cx='18' cy='23' rx='7' ry='9.5' fill='#0e8f7c' stroke='#e7c45e' stroke-width='.9'/></g>`,
  18,
  24,
);

export const CARD_BACKS: Record<string, BackStyle> = {
  back_crimson: { background: `${crimsonLattice}, linear-gradient(160deg, #c81d36, #8e0f22)`, frame: 'rgba(255,255,255,.7)' },
  back_royal: { background: `${royalRings}, linear-gradient(160deg, #2a4eb4, #142d77)`, frame: 'rgba(255,255,255,.7)' },
  back_kashi: { background: kashiStars, frame: '#f2d27b' },
  back_termeh: { background: `${termehPaisley}, linear-gradient(160deg, #8a1428, #4f0914)`, frame: '#e8c66d' },
  back_starry: { background: `${starfield}, linear-gradient(170deg, #1c2d74, #0a1238)`, emblem: moon, frame: '#f1c75a' },
  back_yalda: { background: `${pomegranateSeeds}, linear-gradient(160deg, #a3122a, #5d0716)`, emblem: pomegranate, frame: '#ffd27a' },
  back_neon: { background: `${neonGrid}, linear-gradient(170deg, #1a0638, #05020d)`, emblem: neonDiamond, frame: '#21e6ff' },
  back_marble: { background: `${marbleVeins}, radial-gradient(circle at 30% 20%, #2a2a2e, #0b0b0d 70%)`, frame: '#d8b45a' },
  back_sun: { background: `${sunRays}, radial-gradient(circle at 50% 45%, #ffe79a, #e7b53c 60%, #b8821c)`, emblem: sunEmblem, frame: '#8b5a06' },
  back_peacock: { background: `${peacockEyes}, linear-gradient(160deg, #075f66, #04313a)`, frame: '#e7c45e' },
};

// The artwork collections: one picture per back, in public/backs.
for (const name of [
  'night-star',
  'ivory-moon',
  'garden',
  'rose',
  'ruby',
  'amethyst',
  'gold-marble',
  'sky-moon',
  'verdant',
  'marble-deco',
  'dream-sky',
  'royal-crimson',
  'sun-moon',
  'silver-spade',
  'lava',
  'galaxy',
]) {
  CARD_BACKS[`back_${name.replace(/-/g, '_')}`] = { background: '#141414', frame: 'transparent', image: `/backs/${name}.webp` };
}

export function backStyle(id: string | undefined): BackStyle {
  return CARD_BACKS[id ?? ''] ?? CARD_BACKS.back_crimson;
}

const preloaded = new Set<string>();

/** Fetches an artwork back ahead of time, so cards don't appear blank the first time they're dealt. */
export function preloadBack(id: string | undefined) {
  const url = backStyle(id).image;
  if (!url || preloaded.has(url)) return;
  preloaded.add(url);
  const img = new Image();
  img.decoding = 'async';
  img.src = url;
}

const grain = svg(
  `<filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='2' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 .55 0'/></filter><rect width='160' height='160' filter='url(#n)'/>`,
  160,
  160,
);

const tileOverlay = svg(
  `<g fill='none' stroke='rgba(255,255,255,.09)' stroke-width='1.2'><rect x='15' y='15' width='30' height='30'/><rect x='15' y='15' width='30' height='30' transform='rotate(45 30 30)'/><circle cx='30' cy='30' r='6'/></g>`,
  60,
  60,
);

const carpetField = svg(
  `<g fill='none' stroke='rgba(255,214,140,.13)' stroke-width='1.2'><path d='M20 2 38 20 20 38 2 20z'/><path d='M20 10 30 20 20 30 10 20z'/></g><circle cx='20' cy='20' r='2' fill='rgba(255,214,140,.16)'/>`,
  40,
  40,
);

const carpetMedallion = svg(
  `<g fill='none' stroke='rgba(255,214,140,.28)' stroke-width='2'><path d='M200 30 C 270 80, 330 120, 370 200 C 330 280, 270 320, 200 370 C 130 320, 70 280, 30 200 C 70 120, 130 80, 200 30Z' fill='rgba(20,30,80,.22)'/><path d='M200 80 C 250 110, 290 150, 320 200 C 290 250, 250 290, 200 320 C 150 290, 110 250, 80 200 C 110 150, 150 110, 200 80Z'/><circle cx='200' cy='200' r='48' fill='rgba(255,214,140,.08)'/><circle cx='200' cy='200' r='22'/></g>`,
  400,
  400,
);

const nightStars = svg(
  `<g fill='#fff'><circle cx='10' cy='14' r='.8' opacity='.5'/><circle cx='70' cy='30' r='1' opacity='.35'/><circle cx='40' cy='80' r='.7' opacity='.4'/><circle cx='100' cy='110' r='.9' opacity='.3'/><circle cx='120' cy='20' r='.6' opacity='.45'/></g>`,
  140,
  140,
);

export interface TableStyle {
  background: string;
  /** The rim colour used for the vignette and seat plates. */
  tint: string;
}

export const TABLES: Record<string, TableStyle> = {
  table_felt: {
    background: `${grain}, radial-gradient(ellipse 120% 85% at 50% 44%, #2f9562 0%, #1a6b43 46%, #0c3d27 100%)`,
    tint: '#0b3b25',
  },
  table_navy: {
    background: `${grain}, radial-gradient(ellipse 120% 85% at 50% 44%, #3555a8 0%, #1a2f6a 48%, #08112e 100%)`,
    tint: '#08112e',
  },
  table_walnut: {
    background: `${grain}, radial-gradient(ellipse 110% 80% at 50% 45%, rgba(255,210,150,.22), rgba(0,0,0,.45)), repeating-linear-gradient(96deg, #6a432a 0 9px, #5a3822 9px 15px, #74492d 15px 26px, #4f311d 26px 31px)`,
    tint: '#2c1a0f',
  },
  table_midnight: {
    background: `${nightStars}, ${grain}, radial-gradient(ellipse 120% 85% at 50% 44%, #3a2a6e 0%, #1a1338 50%, #07050f 100%)`,
    tint: '#07050f',
  },
  table_isfahan: {
    background: `${tileOverlay}, ${grain}, radial-gradient(ellipse 120% 85% at 50% 44%, #1aa3a0 0%, #0d6f73 50%, #053b42 100%)`,
    tint: '#053b42',
  },
  table_carpet: {
    background: `${carpetMedallion} center / min(92vw, 520px) no-repeat, ${carpetField}, ${grain}, radial-gradient(ellipse 120% 85% at 50% 44%, #9a1d2f 0%, #6d1222 52%, #33060f 100%)`,
    tint: '#33060f',
  },
};

export function tableStyle(id: string | undefined): TableStyle {
  return TABLES[id ?? ''] ?? TABLES.table_felt;
}
