#!/usr/bin/env python3
"""Converte le schede Markdown (docs/schede) in pagine HTML servite dal pannello.

Convertitore minimo senza dipendenze: titoli, paragrafi, elenchi, tabelle, citazioni,
grassetto, corsivo, codice e link. I segnaposto «[SCHERMATA: …]» diventano riquadri
ben visibili, finché il docente non li sostituisce con le immagini.

Uso: python3 scripts/schede_html.py docs/schede kit/pannello/schede
"""
import html
import re
import sys
from pathlib import Path

PAGINA = """<!doctype html>
<html lang="it"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{titolo}</title>
<style>
:root {{ --sfondo:#f6f4ef; --carta:#fff; --testo:#1f2328; --tenue:#5b6168; --bordo:#dcd8cf; --accento:#7a2e1d; --accento-chiaro:#f3e3dc; }}
@media (prefers-color-scheme: dark) {{ :root {{ --sfondo:#16181b; --carta:#1f2226; --testo:#e8e6e1; --tenue:#a3a8ae; --bordo:#33373d; --accento:#e5a48f; --accento-chiaro:#3a2620; }} }}
body {{ margin:0; background:var(--sfondo); color:var(--testo); font:17px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; }}
main {{ max-width:820px; margin:0 auto; padding:24px 16px 64px; }}
h1 {{ font-family:Georgia,serif; font-weight:600; }} h2 {{ margin-top:2em; }}
a {{ color:var(--accento); }} code {{ background:var(--accento-chiaro); padding:1px 5px; border-radius:4px; font-size:.9em; }}
table {{ border-collapse:collapse; width:100%; margin:1em 0; background:var(--carta); display:block; overflow-x:auto; }}
th,td {{ border:1px solid var(--bordo); padding:6px 10px; text-align:left; vertical-align:top; }}
blockquote {{ margin:1em 0; padding:10px 16px; border-left:4px solid var(--accento); background:var(--accento-chiaro); border-radius:6px; }}
.schermata {{ border:2px dashed var(--bordo); color:var(--tenue); padding:18px; border-radius:8px; text-align:center; font-size:.9em; background:var(--carta); }}
nav {{ font-size:.9em; }}
</style></head><body><main>
<nav><a href="../index.html">← Pannello</a> · <a href="index.html">Tutte le schede</a></nav>
{corpo}
</main></body></html>
"""


def in_linea(t):
    t = html.escape(t, quote=False)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"(?<![\w*])\*([^*]+)\*(?![\w*])", r"<em>\1</em>", t)
    t = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", lambda m: f'<a href="{m.group(2).replace(".md", ".html")}">{m.group(1)}</a>', t)
    return t


def converti(md):
    righe = md.splitlines()
    out, i = [], 0
    while i < len(righe):
        r = righe[i]
        if not r.strip():
            i += 1
            continue
        m = re.match(r"(#{1,4}) (.*)", r)
        if m:
            n = len(m.group(1))
            out.append(f"<h{n}>{in_linea(m.group(2))}</h{n}>")
            i += 1
            continue
        if r.lstrip().startswith("> [SCHERMATA"):
            testo = r.strip()[2:].strip("[]")
            out.append(f'<div class="schermata" role="img" aria-label="{html.escape(testo)}">📷 {html.escape(testo)}</div>')
            i += 1
            continue
        if r.startswith(">"):
            blocco = []
            while i < len(righe) and righe[i].startswith(">"):
                blocco.append(righe[i][1:].strip())
                i += 1
            out.append(f"<blockquote>{in_linea(' '.join(blocco))}</blockquote>")
            continue
        if r.startswith("|"):
            blocco = []
            while i < len(righe) and righe[i].startswith("|"):
                blocco.append([c.strip() for c in righe[i].strip("|").split("|")])
                i += 1
            testa, corpo = blocco[0], [b for b in blocco[2:]]
            out.append("<table><thead><tr>" + "".join(f"<th>{in_linea(c)}</th>" for c in testa) + "</tr></thead><tbody>"
                       + "".join("<tr>" + "".join(f"<td>{in_linea(c)}</td>" for c in riga) + "</tr>" for riga in corpo)
                       + "</tbody></table>")
            continue
        m = re.match(r"(\d+\.|-) (.*)", r)
        if m:
            tag = "ol" if m.group(1)[0].isdigit() else "ul"
            voci = []
            while i < len(righe) and (re.match(r"(\d+\.|-) ", righe[i]) or righe[i].startswith("   ")):
                if re.match(r"(\d+\.|-) ", righe[i]):
                    voci.append([re.sub(r"^(\d+\.|-) ", "", righe[i])])
                else:
                    voci[-1].append(righe[i].strip())
                i += 1
            parti = []
            for v in voci:
                testo = in_linea(v[0])
                for extra in v[1:]:
                    if extra.startswith("> [SCHERMATA"):
                        e = extra[2:].strip("[]")
                        testo += f'<div class="schermata" role="img" aria-label="{html.escape(e)}">📷 {html.escape(e)}</div>'
                    else:
                        testo += " " + in_linea(extra.lstrip("> "))
                parti.append(f"<li>{testo}</li>")
            out.append(f"<{tag}>" + "".join(parti) + f"</{tag}>")
            continue
        blocco = []
        while i < len(righe) and righe[i].strip() and not re.match(r"(#|>|\||\d+\. |- )", righe[i]):
            blocco.append(righe[i])
            i += 1
        out.append(f"<p>{in_linea(' '.join(blocco))}</p>")
    return "\n".join(out)


def main():
    sorgente, destinazione = Path(sys.argv[1]), Path(sys.argv[2])
    destinazione.mkdir(parents=True, exist_ok=True)
    for f in sorted(sorgente.glob("*.md")):
        md = f.read_text(encoding="utf-8")
        titolo = re.search(r"^# (.*)$", md, re.M).group(1)
        (destinazione / (f.stem + ".html")).write_text(PAGINA.format(titolo=html.escape(titolo), corpo=converti(md)), encoding="utf-8")
        print(f"{f.name} → {f.stem}.html")


if __name__ == "__main__":
    main()
