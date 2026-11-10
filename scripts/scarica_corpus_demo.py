#!/usr/bin/env python3
"""Scarica il corpus demo (CLAUDE.md §11) da it.wikisource.org in kit/demo/corpus/.

Solo testi di pubblico dominio (autori morti da oltre 70 anni, atti pubblici ottocenteschi);
la trascrizione di Wikisource è CC BY-SA 4.0 e va citata. Per ogni documento registra URL,
revisione, data di acquisizione, impronta SHA-256 e licenza in registro_demo.csv, con le
stesse colonne di corpus_documenti, così si può importare in NocoDB.

I testi lunghi sono troncati a MAX_CARATTERI per contenere i tempi d'indicizzazione su un
portatile: il troncamento è dichiarato nelle note.

Uso (docente): python3 scripts/scarica_corpus_demo.py
"""
import csv
import hashlib
import html
import json
import re
import time
import urllib.parse
import urllib.error
import urllib.request
from datetime import date
from pathlib import Path

CARTELLA = Path(__file__).resolve().parent.parent / "kit" / "demo" / "corpus"
API = "https://it.wikisource.org/w/api.php"
UA = "LaboratorioIA-RomaTre/0.1 (corpus didattico; contatto: docente del corso)"
MAX_CARATTERI = 12000
LICENZA = "Testo di pubblico dominio; trascrizione Wikisource CC BY-SA 4.0"

# doc_id, pagina Wikisource, titolo, autore, data (EDTF), tipologia, motivazione
DOCUMENTI = [
    ("D0001", "A Carlo Alberto di Savoia un Italiano/A Carlo Alberto di Savoia un Italiano",
     "A Carlo Alberto di Savoia un Italiano", "Giuseppe Mazzini", "1831", "lettera",
     "Lettera aperta che chiede al nuovo re di guidare l'Italia: punto di partenza del rapporto tra Mazzini e i Savoia."),
    ("D0002", "Proclama di Rimini", "Proclama di Rimini", "Gioacchino Murat", "1815-03-30", "altro",
     "Primo appello all'indipendenza italiana rivolto a tutti gli italiani."),
    ("D0003", "Proclama per l'adozione delle basi del nuovo Statuto", "Proclama per l'adozione delle basi del nuovo Statuto",
     "Carlo Alberto di Savoia", "1848-02-08", "altro", "Annuncio dello Statuto: confronto con il testo dello Statuto."),
    ("D0004", "Italia, Regno - Statuto albertino", "Statuto albertino", "Carlo Alberto di Savoia", "1848-03-04", "altro",
     "Carta costituzionale del Regno di Sardegna, poi del Regno d'Italia."),
    ("D0005", "Saggio sulla rivoluzione/Testamento politico di Carlo Pisacane", "Testamento politico", "Carlo Pisacane",
     "1857-06-24", "lettera", "Scritto alla vigilia della spedizione di Sapri: visione democratica e socialista."),
    ("D0006", "Storia dei Mille/A Salemi", "Storia dei Mille · A Salemi", "Giuseppe Cesare Abba", "1904", "altro",
     "Memoria di un garibaldino sulla spedizione dei Mille (scritta a distanza di anni)."),
    ("D0007", "Diario di Nicola Roncalli/1870", "Diario · 1870", "Nicola Roncalli", "1870", "diario",
     "Cronaca romana dell'anno della presa di Roma, vista da un contemporaneo."),
    ("D0008", "Canto nazionale", "Canto nazionale", "Goffredo Mameli", "1847", "altro",
     "Il canto patriottico del 1847: lessico e riferimenti storici."),
    ("D0009", "Bollettino delle leggi e disposizioni della Repubblica Romana/Bollettino N. 41",
     "Bollettino delle leggi della Repubblica Romana · N. 41", "Repubblica Romana", "1849", "verbale",
     "Atti ufficiali della Repubblica Romana del 1849."),
    ("D0010", "Roma italiana, 1870-1895/Il 1870", "Roma italiana, 1870-1895 · Il 1870", "Emma Perodi", "1896", "altro",
     "Ricostruzione storica della fine del potere temporale scritta a fine Ottocento."),
]


def api(parametri, tentativi=6):
    url = API + "?" + urllib.parse.urlencode(dict(parametri, format="json", formatversion="2"))
    richiesta = urllib.request.Request(url, headers={"User-Agent": UA})
    for n in range(tentativi):
        try:
            with urllib.request.urlopen(richiesta, timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            # 429/503: il sito chiede di rallentare. Rispettiamo Retry-After o aspettiamo sempre di più.
            if e.code not in (429, 503) or n == tentativi - 1:
                raise
            attesa = int(e.headers.get("Retry-After") or 0) or 30 * (n + 1)
            print(f"  il sito chiede di rallentare: attendo {attesa} s")
            time.sleep(attesa)


def testo_da_html(h):
    h = re.sub(r"<(script|style|sup)[^>]*>.*?</\1>", " ", h, flags=re.S | re.I)
    # Elementi di servizio di Wikisource: intestazioni, numeri di pagina, note di edizione
    h = re.sub(r'<(div|span|table)[^>]*class="[^"]*(ws-noexport|noprint|pagenum|PageNumber|mw-editsection|reference|intestazione|wst-header)[^"]*"[^>]*>.*?</\1>',
               " ", h, flags=re.S | re.I)
    h = re.sub(r"<br\s*/?>", "\n", h, flags=re.I)
    h = re.sub(r"</(p|div|h\d|li|tr|dd|dt)>", "\n", h, flags=re.I)
    h = re.sub(r"<[^>]+>", " ", h)
    t = html.unescape(h)
    t = re.sub(r"[ \t ]+", " ", t)
    t = re.sub(r" *\n *", "\n", t)
    # Residui dell'impaginazione di Wikisource: ancore di pagina "]" e avvisi sullo stato del testo
    t = re.sub(r"(?m)^\s*\]\s*$", "", t)
    t = re.sub(r" \] ", " ", t)
    t = re.sub(r"(?m) \]$", "", t)
    t = re.sub(r"(?m)^Questo testo è [^\n]*\.\s*$", "", t)
    t = re.sub(r"\n{3,}", "\n\n", t)
    return t.strip()


def main():
    CARTELLA.mkdir(parents=True, exist_ok=True)
    righe = []
    for doc_id, pagina, titolo, autore, data_doc, tipologia, motivazione in DOCUMENTI:
        dati = api({"action": "parse", "page": pagina, "prop": "text|revid", "redirects": "1"})
        if "error" in dati:
            raise SystemExit(f"{doc_id}: pagina non trovata: {pagina} ({dati['error'].get('info')})")
        testo = testo_da_html(dati["parse"]["text"])
        note = f"Revisione Wikisource {dati['parse']['revid']}."
        if len(testo) > MAX_CARATTERI:
            taglio = testo.rfind("\n", 0, MAX_CARATTERI)
            testo = testo[: taglio if taglio > MAX_CARATTERI // 2 else MAX_CARATTERI].rstrip() + "\n\n[Testo troncato per il corpus demo.]"
            note += f" Testo troncato a circa {MAX_CARATTERI} caratteri per contenere i tempi d'indicizzazione."
        (CARTELLA / f"{doc_id}.txt").write_text(testo + "\n", encoding="utf-8")
        url = "https://it.wikisource.org/wiki/" + urllib.parse.quote(dati["parse"]["title"].replace(" ", "_"))
        righe.append({
            "doc_id": doc_id, "titolo": titolo, "autore": autore, "data_documento": data_doc, "tipologia": tipologia,
            "provenienza": "web", "url_o_percorso": url, "istituzione_conservatrice": "Wikisource (it)",
            "licenza": LICENZA, "data_acquisizione": date.today().isoformat(),
            "hash_sha256": hashlib.sha256((testo + "\n").encode("utf-8")).hexdigest(), "lingua": "it",
            "qualita_ocr": "non_applicabile", "stato": "approvato", "motivazione_inclusione": motivazione, "note": note,
        })
        print(f"{doc_id}  {len(testo):6d} caratteri  {titolo}")
        time.sleep(5)
    with open(CARTELLA / "registro_demo.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(righe[0]))
        w.writeheader()
        w.writerows(righe)


if __name__ == "__main__":
    main()
