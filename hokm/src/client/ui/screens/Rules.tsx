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
          'Every hand starts from a fully random deck, shuffled by the server. The shuffles and the cut are real: they move the actual cards before the deal, so they decide who gets what, but they can never make a deal less random.',
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
      {
        icon: '💣',
        title: 'Boom',
        body: 'Think your team can take all 13 tricks? Call Boom from the 💣 button, any time before the first trick is taken. Take every trick and your team wins the whole game on the spot, with 150 bonus coins. Lose a single trick and the hand is over: the other team wins it. One Boom per hand; the host can switch Booms off.',
      },
      {
        icon: '🔄',
        title: 'Swap hands',
        body: 'Between tricks, you can offer to trade your whole hand with one of your opponents, blind. If they accept, you swap cards. Each player gets one offer per hand, and the table waits while the other player decides (12 seconds). The host can switch swaps off.',
      },
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
          'هر دست از یک دسته کاملاً تصادفی شروع می‌شود که سرور بُر زده است. بُر زدن و کات کردن واقعی‌اند: کارت‌های واقعی را قبل از پخش جابه‌جا می‌کنند و تعیین می‌کنند چه کسی چه بگیرد، ولی هیچ‌وقت پخش را کمتر تصادفی نمی‌کنند.',
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
      {
        icon: '💣',
        title: 'بوم',
        body: 'فکر می‌کنی تیمت هر ۱۳ دست را می‌برد؟ قبل از اینکه اولین دست برده شود، از دکمه 💣 «بوم» بده. اگر همه دست‌ها را ببرید، همان لحظه کل بازی را برده‌اید و ۱۵۰ سکه جایزه می‌گیرید. اگر حتی یک دست را ببازید، آن دست تمام است و تیم مقابل آن را می‌برد. در هر دست فقط یک بوم؛ میزبان می‌تواند بوم را خاموش کند.',
      },
      {
        icon: '🔄',
        title: 'عوض کردن دست',
        body: 'بین دست‌ها می‌توانی پیشنهاد بدهی کل کارت‌هایت را، ندیده، با یکی از حریف‌ها عوض کنی. اگر قبول کند، کارت‌هایتان جابه‌جا می‌شود. هر نفر در هر دست یک بار می‌تواند پیشنهاد بدهد و تا حریف تصمیم بگیرد (۱۲ ثانیه) میز منتظر می‌ماند. میزبان می‌تواند این را خاموش کند.',
      },
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
