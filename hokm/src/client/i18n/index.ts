import { useCallback } from 'react';
import { PHRASES, getItem } from '../../shared/catalog';
import type { Lang, PublicProfile } from '../../shared/protocol';
import { settings, useSettings } from '../state/settings';
import { BOT_NAMES, type StringKey, en, fa } from './strings';

const tables: Record<Lang, Record<StringKey, string>> = { en, fa };

export type Params = Record<string, string | number>;

export function fmt(n: number, lang: Lang = settings.get().lang): string {
  return n.toLocaleString(lang === 'fa' ? 'fa-IR' : 'en-US');
}

export function translate(lang: Lang, key: StringKey, params?: Params): string {
  let s = tables[lang][key] ?? en[key] ?? key;
  if (params) {
    for (const [k, v] of Object.entries(params)) s = s.split(`{${k}}`).join(typeof v === 'number' ? fmt(v, lang) : v);
  }
  return s;
}

/** For code outside React (toasts, sounds): uses the current language. */
export function t(key: StringKey, params?: Params): string {
  return translate(settings.get().lang, key, params);
}

export function useT() {
  const lang = useSettings((s) => s.lang);
  return useCallback((key: StringKey, params?: Params) => translate(lang, key, params), [lang]);
}

export function useLang(): Lang {
  return useSettings((s) => s.lang);
}

/** Bots carry a name key; people carry their own name. */
export function displayName(p: PublicProfile | null | undefined, lang: Lang = settings.get().lang): string {
  if (!p) return '';
  if (p.bot) return BOT_NAMES[p.name]?.[lang] ?? p.name;
  return p.name;
}

export function itemName(id: string, lang: Lang = settings.get().lang): string {
  return getItem(id)?.name[lang] ?? id;
}

export function phraseText(id: string, lang: Lang = settings.get().lang): string {
  return PHRASES[id]?.[lang] ?? id;
}

export function applyDocumentLang(lang: Lang) {
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === 'fa' ? 'rtl' : 'ltr';
}

export function isStringKey(key: string): key is StringKey {
  return key in en;
}
