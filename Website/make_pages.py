#!/usr/bin/env python3
"""Builds Kinward's website pages — privacy.html, terms.html and support.html.

The privacy policy and terms come from Kinward/Resources/Legal.json, the same
file the app reads, so the site and the app always say the same thing. Change
the wording there, then run this again:

    python3 Website/make_pages.py

Your details go in Website/publisher.json. Anything left empty shows up in the
pages as a highlighted [placeholder], so it can't be published by accident.
"""

import html
import json
import re
from pathlib import Path

HERE = Path(__file__).parent
LEGAL = json.loads((HERE.parent / "Kinward/Resources/Legal.json").read_text())
PUB = json.loads((HERE / "publisher.json").read_text())


def val(key, placeholder):
    v = (PUB.get(key) or "").strip()
    return v if v else None, f"<mark>[{placeholder}]</mark>"


NAME, NAME_PH = val("name", "Your name or company")
EMAIL, EMAIL_PH = val("supportEmail", "support email")
LAW, LAW_PH = val("lawOf", "your country")


def developer():
    return html.escape(NAME) if NAME else NAME_PH


def email_link():
    return f'<a href="mailto:{html.escape(EMAIL)}">{html.escape(EMAIL)}</a>' if EMAIL else EMAIL_PH


def inline(text):
    """Escapes a paragraph, then turns its Markdown links and tokens into HTML."""
    out = html.escape(text, quote=False)
    out = re.sub(r"\[([^\]]+)\]\(([^)]+)\)",
                 lambda m: f'<a href="{m.group(2)}">{m.group(1)}</a>', out)
    out = out.replace("{developer}", developer())
    out = out.replace("{contact}", f"Questions about this, or anything else? Write to {email_link()}.")
    out = out.replace("{law}", f"the laws of {html.escape(LAW) if LAW else LAW_PH}")
    return out


def paragraphs(items):
    parts, bullets = [], []

    def flush():
        if bullets:
            parts.append("<ul>" + "".join(f"<li>{b}</li>" for b in bullets) + "</ul>")
            bullets.clear()

    for p in items:
        if p.startswith("• "):
            bullets.append(inline(p[2:]))
        else:
            flush()
            parts.append(f"<p>{inline(p)}</p>")
    flush()
    return "\n".join(parts)


STYLE = """
:root { --bg:#F5F1E8; --card:#FBF9F4; --ink:#252522; --soft:#5F5D57; --faint:#8C897F;
        --line:#DDD6C8; --accent:#3B4238; --gold:#A8946A; --mark:#F3DFA2; }
@media (prefers-color-scheme: dark) {
  :root { --bg:#161513; --card:#201F1C; --ink:#F1EDE4; --soft:#BDB8AD; --faint:#8C877C;
          --line:#34322D; --accent:#C9D1BF; --gold:#C8B488; --mark:#5A4B1F; } }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--ink);
       font: 17px/1.62 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
       -webkit-font-smoothing: antialiased; }
main { max-width: 680px; margin: 0 auto; padding: 40px 20px 72px; }
header { display:flex; justify-content:space-between; align-items:baseline; flex-wrap:wrap; gap:8px 20px;
         padding-bottom: 18px; border-bottom: 1px solid var(--line); margin-bottom: 36px; }
.brand { font-family: "New York", "Iowan Old Style", Georgia, serif; font-size: 22px; color: var(--ink);
         text-decoration: none; }
nav a { color: var(--soft); text-decoration: none; margin-left: 16px; font-size: 15px; }
nav a:first-child { margin-left: 0; }
nav a[aria-current] { color: var(--ink); font-weight: 600; }
.eyebrow { font-size: 12px; letter-spacing: .18em; text-transform: uppercase; color: var(--gold); margin: 0 0 6px; }
h1 { font-family: "New York", "Iowan Old Style", Georgia, serif; font-weight: 400; font-size: 40px;
     line-height: 1.12; margin: 0 0 8px; }
.updated { color: var(--faint); font-size: 14px; margin: 0 0 30px; }
.short { background: var(--card); border: 1px solid var(--line); border-radius: 18px; padding: 20px 22px; margin-bottom: 36px; }
.short h2 { font-family: inherit; font-size: 12px; letter-spacing: .18em; text-transform: uppercase;
            color: var(--faint); margin: 0 0 10px; font-weight: 600; }
.short ul { margin: 0; padding: 0; list-style: none; }
.short li { padding-left: 26px; position: relative; margin: 8px 0; }
.short li::before { content: "✓"; position: absolute; left: 2px; color: var(--accent); font-weight: 600; }
section h2 { font-family: "New York", "Iowan Old Style", Georgia, serif; font-weight: 400; font-size: 25px;
             margin: 34px 0 10px; }
p, li { color: var(--soft); }
section ul { padding-left: 22px; }
section li { margin: 6px 0; }
a { color: var(--accent); text-underline-offset: 2px; }
mark { background: var(--mark); color: var(--ink); padding: 0 3px; border-radius: 3px; }
footer { margin-top: 56px; padding-top: 18px; border-top: 1px solid var(--line); color: var(--faint); font-size: 14px; }
"""

PAGES = [("privacy.html", "Privacy"), ("terms.html", "Terms"), ("support.html", "Support")]


def page(filename, title, eyebrow, content, description):
    def link(f, label):
        current = ' aria-current="page"' if f == filename else ""
        return f'<a href="{f}"{current}>{label}</a>'
    nav = "".join(link(f, label) for f, label in PAGES)
    year = LEGAL["updated"][-4:]
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} · Kinward</title>
<meta name="description" content="{html.escape(description)}">
<style>{STYLE}</style>
</head>
<body>
<main>
<header><a class="brand" href="privacy.html">Kinward</a><nav>{nav}</nav></header>
<p class="eyebrow">{eyebrow}</p>
<h1>{title}</h1>
{content}
<footer>© {year} {developer()}. Kinward keeps what you keep on your iPhone.</footer>
</main>
</body>
</html>
"""


def legal_page(key, filename):
    doc = LEGAL[key]
    short = "".join(f"<li>{inline(s)}</li>" for s in doc["summary"])
    sections = "\n".join(
        f"<section><h2>{html.escape(s['heading'])}</h2>\n{paragraphs(s['paragraphs'])}</section>"
        for s in doc["sections"])
    content = (f'<p class="updated">Last updated {LEGAL["updated"]}</p>\n'
               f'<div class="short"><h2>In short</h2><ul>{short}</ul></div>\n{sections}')
    return page(filename, doc["title"], "Kinward", content, f"Kinward {doc['title']}")


SUPPORT = [
    ("Where is everything I keep?",
     ["Only on your iPhone. Kinward has no account and no server, so nothing you write or record is stored anywhere else."]),
    ("How do I make sure I don’t lose it?",
     ["Keep your iPhone backed up — iCloud Backup (Settings → your name → iCloud → iCloud Backup) or a backup to your computer. Kinward is included in those backups, and restoring one brings it back.",
      "To hand things to someone, open them in People and choose Send what they can see, or use Pass it on in Legacy. Either makes a file you can send however you like."]),
    ("I subscribed to Kinward Plus. How do I restore it on a new iPhone?",
     ["Open Kinward → Settings → Kinward Plus, then Restore purchases on the Kinward Plus screen. Use the same Apple Account you subscribed with."]),
    ("How do I cancel Kinward Plus?",
     ["On your iPhone: Settings → your name → Subscriptions → Kinward. Or in Kinward: Settings → Terms & privacy → Manage subscription. Plus stays on until the end of the period you’ve paid for, and nothing you’ve kept is removed."]),
    ("Can I get a refund?",
     ["Refunds are handled by Apple. Request one at [reportaproblem.apple.com](https://reportaproblem.apple.com)."]),
    ("Can you recover something I deleted?",
     ["We can’t — it never reaches us. A backup of your iPhone from before it was deleted is the only way back."]),
]


def support_page():
    faqs = "\n".join(f"<section><h2>{html.escape(q)}</h2>\n{paragraphs(a)}</section>" for q, a in SUPPORT)
    content = (f'<p class="updated">We’re glad to help. Write to {email_link()}.</p>\n'
               f"{faqs}\n<section><h2>More</h2><p>Read the <a href=\"privacy.html\">privacy policy</a> "
               f"and the <a href=\"terms.html\">terms of use</a>.</p></section>")
    return page("support.html", "Support", "Kinward", content, "Help with Kinward")


if __name__ == "__main__":
    (HERE / "privacy.html").write_text(legal_page("privacy", "privacy.html"))
    (HERE / "terms.html").write_text(legal_page("terms", "terms.html"))
    (HERE / "support.html").write_text(support_page())
    missing = [k for k in ("name", "supportEmail", "lawOf") if not (PUB.get(k) or "").strip()]
    print("Wrote privacy.html, terms.html and support.html.")
    if missing:
        print("Still placeholders in the pages — fill these in Website/publisher.json:", ", ".join(missing))
