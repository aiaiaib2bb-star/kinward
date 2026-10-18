import { SuitIcon } from '../components/Card';
import { useLang, useT } from '../../i18n';
import { go } from '../../state/app';
import { TopNav } from '../components/common';

const RULES = {
  en: {
    sections: [
      {
        icon: '🃏',
        title: 'The basics',
        body: [
          'Hokm is played by four people in two teams of two. Partners sit opposite each other.',
          'A normal 52-card deck is used and the ace is the highest card. Play goes counter-clockwise, so the turn always passes to your right.',
        ],
      },
      {
        icon: '👑',
        title: 'The Hakem',
        body: [
          'To start the game, cards are dealt face up one at a time. The first player to receive an ace becomes the Hakem, the ruler of the hand.',
          'The Hakem keeps the role as long as their team keeps winning hands. When their team loses a hand, the player on the Hakem’s right becomes Hakem.',
        ],
      },
      {
        icon: '🔀',
        title: 'Shuffle and cut',
        body: [
          'The Hakem shuffles, as much as they like. Then an opponent, the player on the Hakem’s left, cuts the deck and decides how deep the cut goes.',
          'With the “Real” deck the cards keep the order of the last hand, so a lazy shuffle deals clumpy hands, just like at a real table. “Random” makes every deal perfectly random.',
        ],
      },
      {
        icon: '🎴',
        title: 'Dealing and calling Hokm',
        body: [
          'The Hakem deals five cards to everyone, starting with the player on their right.',
          'Looking only at those five cards, the Hakem chooses the trump suit. That suit is the Hokm. The rest of the deck is then dealt four and four, thirteen cards each.',
        ],
      },
      {
        icon: '✋',
        title: 'Playing a trick',
        body: [
          'The Hakem leads the first trick. Everyone must follow the suit that was led if they can.',
          'If you can’t follow suit, you may play anything, including a trump. The highest trump takes the trick; if no trump was played, the highest card of the led suit does. Whoever takes the trick leads the next one.',
        ],
      },
    ],
    scoringTitle: 'Scoring',
    scoring: [
      ['First team to take 7 tricks wins the hand', '1'],
      ['Kot: win the hand 7–0', '2'],
      ['Hakem Kot: the Hakem’s team takes no tricks at all', '3'],
    ],
    scoringNote: 'The first team to reach the target score (7 unless the table chose otherwise) wins the game.',
    extras: [
      { icon: '🏳️', title: 'Surrender', body: 'If both partners agree, a team can surrender in the middle of a game. They lose that game and earn no coins.' },
      {
        icon: '💥',
        title: 'Table talk',
        body: 'Flick a card hard to slam it and shake the table. Tap a player’s avatar to throw a rose, or a tomato. Emotes and quick phrases are a tap away, and voice chat is on the mic button.',
      },
      {
        icon: '🪙',
        title: 'Coins',
        body: 'Winners earn 100 coins, plus 15 for every Kot and 30 for every Hakem Kot. The losing team still gets 20. Coins are scaled down when bots fill seats. Spend them in the shop on card designs, tables and profile effects.',
      },
    ],
  },
  fa: {
    sections: [
      {
        icon: '🃏',
        title: 'پایه‌ها',
        body: [
          'حکم را چهار نفر در دو تیم دونفره بازی می‌کنند. هم‌تیمی‌ها روبه‌روی هم می‌نشینند.',
          'با یک دسته ورق ۵۲ تایی بازی می‌شود و آس بالاترین کارت است. بازی خلاف جهت عقربه‌های ساعت پیش می‌رود، یعنی نوبت همیشه به نفر سمت راست می‌رسد.',
        ],
      },
      {
        icon: '👑',
        title: 'حاکم',
        body: [
          'برای شروع، ورق‌ها یکی‌یکی و رو به بالا پخش می‌شوند. اولین کسی که آس بگیرد حاکم می‌شود.',
          'تا وقتی تیم حاکم دست‌ها را می‌برد، حاکم عوض نمی‌شود. اگر تیمش یک دست را ببازد، نفر سمت راست حاکم، حاکم بعدی است.',
        ],
      },
      {
        icon: '🔀',
        title: 'بُر زدن و کات',
        body: [
          'حاکم هر چقدر بخواهد ورق‌ها را بُر می‌زند. بعد حریفِ سمت چپ حاکم دسته را کات می‌کند و خودش انتخاب می‌کند از کجا کات شود.',
          'در حالت «واقعی» ورق‌ها ترتیب دست قبل را نگه می‌دارند؛ اگر کم بُر بخورد، دست‌ها جفت‌جفت پخش می‌شوند، درست مثل میز واقعی. در حالت «تصادفی» هر پخش کاملاً تصادفی است.',
        ],
      },
      {
        icon: '🎴',
        title: 'پخش ورق و انتخاب حکم',
        body: [
          'حاکم به هر نفر پنج کارت می‌دهد و از نفر سمت راستش شروع می‌کند.',
          'حاکم فقط با دیدن همین پنج کارت، خال حکم را انتخاب می‌کند. بعد بقیه ورق‌ها چهارتا‌چهارتا پخش می‌شوند تا هر نفر سیزده کارت داشته باشد.',
        ],
      },
      {
        icon: '✋',
        title: 'بازی هر دست',
        body: [
          'حاکم اولین کارت را بازی می‌کند. هر کس خالِ آمده را دارد، باید همان را بیاورد.',
          'اگر آن خال را نداری، هر کارتی می‌توانی بازی کنی، حتی حکم. بالاترین حکم دست را می‌برد و اگر حکمی نیامده باشد، بالاترین کارتِ خالِ آمده. برنده هر دست، دست بعد را شروع می‌کند.',
        ],
      },
    ],
    scoringTitle: 'امتیاز',
    scoring: [
      ['اولین تیمی که ۷ دست ببرد', '۱'],
      ['کُت: بردن با نتیجه ۷ به ۰', '۲'],
      ['حاکم‌کُت: تیم حاکم هیچ دستی نبرد', '۳'],
    ],
    scoringNote: 'اولین تیمی که به امتیاز هدف برسد (اگر میز چیز دیگری انتخاب نکرده باشد، ۷) برنده بازی است.',
    extras: [
      { icon: '🏳️', title: 'تسلیم', body: 'اگر هر دو هم‌تیمی موافق باشند، تیم می‌تواند وسط بازی تسلیم شود. آن بازی را می‌بازند و سکه‌ای نمی‌گیرند.' },
      {
        icon: '💥',
        title: 'حرف‌های سر میز',
        body: 'کارت را محکم پرت کن تا روی میز بکوبی و میز بلرزد. روی چهره یک بازیکن بزن تا گل رز، یا گوجه، به سمتش پرت کنی. شکلک‌ها و جمله‌های آماده یک ضربه فاصله دارند و گفتگوی صوتی روی دکمه میکروفون است.',
      },
      {
        icon: '🪙',
        title: 'سکه',
        body: 'برنده‌ها ۱۰۰ سکه می‌گیرند، به‌علاوه ۱۵ برای هر کُت و ۳۰ برای هر حاکم‌کُت. تیم بازنده هم ۲۰ سکه می‌گیرد. وقتی ربات‌ها جای کسی بازی می‌کنند سکه کمتر است. سکه‌ها را در فروشگاه برای طرح کارت، میز و جلوه‌های پروفایل خرج کن.',
      },
    ],
  },
};

export function Rules() {
  const t = useT();
  const lang = useLang();
  const r = RULES[lang];
  return (
    <div className="screen">
      <div className="screen-inner rules">
        <TopNav title={t('rules')} onBack={() => go('home')} />
        <div style={{ display: 'flex', justifyContent: 'center', gap: 10, color: '#fff' }}>
          {(['S', 'H', 'C', 'D'] as const).map((s) => (
            <SuitIcon key={s} suit={s} size={30} color={s === 'H' || s === 'D' ? '#ff5d73' : '#f6f3ec'} />
          ))}
        </div>
        {r.sections.map((s) => (
          <section key={s.title}>
            <h2>
              <span>{s.icon}</span>
              {s.title}
            </h2>
            {s.body.map((p) => (
              <p key={p}>{p}</p>
            ))}
          </section>
        ))}
        <h2>
          <span>🏆</span>
          {r.scoringTitle}
        </h2>
        <table className="score-table">
          <tbody>
            {r.scoring.map(([what, pts]) => (
              <tr key={what}>
                <td>{what}</td>
                <td>+{pts}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <p className="callout">{r.scoringNote}</p>
        {r.extras.map((s) => (
          <section key={s.title}>
            <h2>
              <span>{s.icon}</span>
              {s.title}
            </h2>
            <p>{s.body}</p>
          </section>
        ))}
      </div>
    </div>
  );
}
