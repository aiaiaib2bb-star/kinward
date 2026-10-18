import { t } from '../../i18n';
import { toast } from '../../state/app';

export function roomLink(code: string): string {
  return `${location.origin}/r/${code}`;
}

/** Opens the phone's share sheet (WhatsApp, Telegram…), or copies the link where there isn't one. */
export async function shareRoom(code: string) {
  const url = roomLink(code);
  const text = t('invite_text', { code });
  if (navigator.share) {
    try {
      await navigator.share({ title: t('app_name'), text, url });
      return;
    } catch (err) {
      if ((err as Error).name === 'AbortError') return;
    }
  }
  await copyText(url);
}

export async function copyText(text: string) {
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    ta.remove();
  }
  toast(t('copied'), 'good', 1600);
}
