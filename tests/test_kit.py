#!/usr/bin/env python3
"""Controlli statici del kit (CLAUDE.md §2, §3, §9, §10.3, §15). Non serve Docker.

Uso: python3 tests/test_kit.py
"""
import csv
import json
import re
import sys
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
KIT = RADICE / "kit"
errori = []


def controlla(condizione, messaggio):
    if not condizione:
        errori.append(messaggio)


def compose():
    import yaml  # PyYAML: solo per il docente
    return yaml.safe_load((KIT / "compose.yml").read_text(encoding="utf-8"))


def mb(valore):
    m = re.fullmatch(r"(\d+)([mg])", str(valore).lower())
    return int(m.group(1)) * (1024 if m.group(2) == "g" else 1) if m else 0


def test_compose():
    c = compose()
    servizi = c["services"]
    totale = 0
    for nome, s in servizi.items():
        img = s.get("image", "")
        controlla(":" in img and not img.endswith(":latest") and not re.search(r":\d+$", img.split("/")[-1]) or nome == "nocodb",
                  f"{nome}: immagine senza versione precisa ({img})")
        controlla("latest" not in img, f"{nome}: tag latest vietato")
        for p in s.get("ports", []):
            controlla(str(p).startswith("127.0.0.1:"), f"{nome}: porta pubblicata fuori da 127.0.0.1 ({p})")
        controlla("mem_limit" in s, f"{nome}: manca il limite di memoria")
        if nome not in ("init", "neo4j"):
            totale += mb(s.get("mem_limit", "0m"))
    controlla(not servizi["tika"].get("ports"), "tika non deve pubblicare porte")
    controlla(not servizi["controlli"].get("ports"), "controlli non deve pubblicare porte")
    controlla(servizi["neo4j"].get("profiles") == ["avanzato"], "neo4j deve stare solo nel profilo avanzato")
    controlla(totale <= 3072, f"somma dei limiti di memoria {totale} MB oltre 3 GB")
    controlla("postgres" not in json.dumps(c).lower(), "niente Postgres né altri server di database")
    print(f"ok   compose: immagini fissate, porte su 127.0.0.1, memoria totale {totale} MB")


def test_tag_esatti():
    attesi = {"caddy:2.11.9-alpine", "docker.n8n.io/n8nio/n8n:2.47.3", "nocodb/nocodb:2026.10.1",
              "ghcr.io/hkuds/lightrag:v1.5.7", "apache/tika:3.3.3.0-full", "neo4j:5.26.33-community"}
    trovati = {s["image"] for s in compose()["services"].values()}
    controlla(trovati == attesi, f"immagini diverse da ADR-001: {sorted(trovati ^ attesi)}")


def test_prompt():
    for f in sorted((KIT / "prompts").glob("*.md")):
        t = f.read_text(encoding="utf-8")
        m = re.match(r"---\n(.*?)\n---\n", t, re.S)
        controlla(m is not None, f"{f.name}: manca l'intestazione YAML")
        if m:
            for campo in ("id", "versione", "data", "uso"):
                controlla(re.search(rf"^{campo}:\s*\S", m.group(1), re.M), f"{f.name}: manca «{campo}»")
            controlla(re.search(rf"^id:\s*{f.stem}$", m.group(1), re.M), f"{f.name}: id diverso dal nome del file")
    rs = (KIT / "prompts" / "risposta_storica.md").read_text(encoding="utf-8")
    controlla("Il corpus non contiene informazioni sufficienti" in rs, "risposta_storica: manca la frase d'incertezza")
    print("ok   prompt versionati con intestazione YAML")


def test_fixture():
    cartella = RADICE / "samples" / "security_fixtures"
    attesi = sorted(cartella.glob("*.atteso.json"))
    controlla(len(attesi) >= 7, "servono almeno 7 fixture (CLAUDE.md §10.3)")
    for a in attesi:
        dati = json.loads(a.read_text(encoding="utf-8"))
        controlla((cartella / dati["file"]).exists(), f"manca il file della fixture {dati['file']}")
    for f in cartella.iterdir():
        if f.suffix in (".pdf", ".docx", ".html", ".txt", ".png"):
            contenuto = f.read_bytes()
            controlla(b"http://" not in contenuto.replace(b"http://schemas", b"").replace(b"http://purl", b"").replace(b"http://www.w3.org", b"")
                      .replace(b"http://ns.adobe", b""), f"{f.name}: la fixture non deve contenere link reali")
    print(f"ok   {len(attesi)} fixture di sicurezza con segnalazioni attese")


def test_golden():
    f = RADICE / "samples" / "golden_questions.csv"
    righe = list(csv.DictReader(f.open(encoding="utf-8")))
    controlla(len(righe) == 10, "golden_questions.csv: servono 10 domande")
    corpus = {p.stem for p in (KIT / "demo" / "corpus").glob("D*.txt")}
    for r in righe:
        for d in r["doc_id_attesi"].split(";"):
            controlla(d.strip() in corpus, f"golden {r['id']}: doc_id {d} non presente nel corpus demo")
        controlla(r["modalita"] in ("naive", "local", "global", "hybrid", "mix"), f"golden {r['id']}: modalità non valida")
    print("ok   10 golden questions con doc_id presenti nel corpus demo")


def test_schema_registri():
    s = json.loads((KIT / "init" / "schema_registri.json").read_text(encoding="utf-8"))
    nomi = [t["nome"] for t in s["tabelle"]]
    controlla(nomi == ["corpus_documenti", "segnalazioni_sicurezza", "entita", "correzioni_grafo", "interrogazioni",
                       "verifiche", "uso_ia"], "tabelle diverse da CLAUDE.md §7")
    for t in s["tabelle"]:
        for campo, _ in t["campi"]:
            controlla(re.fullmatch(r"[a-z0-9_]+", campo), f"{t['nome']}.{campo}: non snake_case")
    print("ok   schema dei registri come CLAUDE.md §7")


def test_lightrag_env():
    t = (KIT / "config" / "lightrag.env").read_text(encoding="utf-8")
    for riga in ("OLLAMA_LLM_THINK=false", "EXTRACT_OLLAMA_LLM_THINK=false", "SUMMARY_LANGUAGE=Italian",
                 "EMBEDDING_MODEL=embeddinggemma:300m", "EMBEDDING_DIM=768", "LLM_BINDING_HOST=http://host.docker.internal:11434"):
        controlla(riga in t, f"lightrag.env: manca {riga}")
    for profilo, gleaning in (("leggero", "0"), ("standard", "1")):
        p = (KIT / "config" / "profili" / f"{profilo}.env").read_text(encoding="utf-8")
        controlla(f"MAX_GLEANING={gleaning}" in p, f"{profilo}: MAX_GLEANING atteso {gleaning}")
        ctx = int(re.search(r"OLLAMA_LLM_NUM_CTX=(\d+)", p).group(1))
        tot = int(re.search(r"MAX_TOTAL_TOKENS=(\d+)", p).group(1))
        controlla(ctx > tot + 2000, f"{profilo}: OLLAMA_LLM_NUM_CTX deve superare MAX_TOTAL_TOKENS + 2000")
    m = (KIT / "config" / "modelli.env").read_text(encoding="utf-8")
    controlla("EMBEDDING_MODEL=embeddinggemma:300m" in m, "modelli.env e lightrag.env devono usare lo stesso embedding")
    print("ok   LightRAG: thinking spento, italiano, embedding unico, contesto coerente")


for t in (test_compose, test_tag_esatti, test_prompt, test_fixture, test_golden, test_schema_registri, test_lightrag_env):
    try:
        t()
    except Exception as e:  # un test rotto non deve nascondere gli altri
        errori.append(f"{t.__name__}: {e}")

if errori:
    print("\n".join("FAIL " + e for e in errori))
    sys.exit(1)
