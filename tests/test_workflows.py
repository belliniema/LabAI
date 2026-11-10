#!/usr/bin/env python3
"""Verifica le convenzioni obbligatorie dei workflow (CLAUDE.md §8.1, §15).

Uso: python3 tests/test_workflows.py
"""
import json
import re
import sys
from pathlib import Path

CARTELLA = Path(__file__).resolve().parent.parent / "kit" / "workflows"
VOCI_NOTA = ["Che cosa fa", "Input", "Output", "Che cosa puoi modificare", "Rischi e limiti"]
TRIGGER = ("manualTrigger", "formTrigger", "executeWorkflowTrigger")
CHIAMATE_MODELLO = [re.compile(r"/api/chat"), re.compile(r"/api/generate"), re.compile(r"/query(/|$)"), re.compile(r"/documents/text")]
VIETATI = ["n8n-nodes-base.code", "n8n-nodes-base.function", "n8n-nodes-base.functionItem", "n8n-nodes-base.executeCommand",
           "@n8n/n8n-nodes-langchain.agent", "@n8n/n8n-nodes-langchain.toolCode", "@n8n/n8n-nodes-langchain.toolHttpRequest"]

errori = []


def errore(wf, msg):
    errori.append(f"{wf}: {msg}")


def controlla(percorso):
    wf = json.loads(percorso.read_text(encoding="utf-8"))
    nome = wf["name"]
    nodi = wf["nodes"]
    per_nome = {n["name"]: n for n in nodi}
    conn = wf["connections"]

    if not re.fullmatch(r"WF0\d · \S.*", nome):
        errore(nome, "nome non nel formato «WF0x · Nome in italiano»")
    if not percorso.name.startswith(nome[:4]):
        errore(nome, f"il file {percorso.name} non corrisponde all'ID")

    primo = nodi[0]
    if primo["type"] != "n8n-nodes-base.stickyNote":
        errore(nome, "il primo elemento del canvas non è una nota adesiva")
    else:
        for voce in VOCI_NOTA:
            if voce not in primo["parameters"]["content"]:
                errore(nome, f"la nota iniziale non ha la voce «{voce}»")

    trigger = [n for n in nodi if n["type"].split(".")[-1] in TRIGGER]
    if len(trigger) != 1:
        errore(nome, f"atteso un solo trigger, trovati {len(trigger)}")
    else:
        dopo = conn.get(trigger[0]["name"], {}).get("main", [[]])[0]
        if [c["node"] for c in dopo] != ["PARAMETRI"] or per_nome["PARAMETRI"]["type"] != "n8n-nodes-base.set":
            errore(nome, "il primo nodo dopo il trigger non è il nodo Set «PARAMETRI»")

    for n in nodi:
        if n["type"] in VIETATI:
            errore(nome, f"nodo vietato: {n['name']} ({n['type']})")
        if "credentials" in n:
            for cred in n["credentials"].values():
                if set(cred) - {"id", "name"}:
                    errore(nome, f"credenziale non solo per riferimento in {n['name']}")

    # Tutte le connessioni puntano a nodi esistenti
    for da, uscite in conn.items():
        if da not in per_nome:
            errore(nome, f"connessione da nodo inesistente {da}")
        for ramo in uscite.get("main", []):
            for c in ramo:
                if c["node"] not in per_nome:
                    errore(nome, f"connessione verso nodo inesistente {c['node']}")

    testo = json.dumps(wf, ensure_ascii=False)
    # Nessun workflow scrive «esito» (lo scrive solo lo studente) né approva documenti in quarantena.
    for n in nodi:
        corpo = json.dumps(n["parameters"], ensure_ascii=False)
        if n["type"] == "n8n-nodes-base.httpRequest" and n["parameters"].get("method") in ("POST", "PATCH"):
            if re.search(r"\besito\s*:", corpo) or re.search(r"stato\s*:\s*\\?'approvato", corpo):
                errore(nome, f"il nodo {n['name']} scrive esito o approva documenti")

    # Ogni chiamata a un modello passa per WF09
    chiama_modello = any(r.search(n["parameters"].get("url", "")) for n in nodi if n["type"] == "n8n-nodes-base.httpRequest"
                         for r in CHIAMATE_MODELLO)
    if chiama_modello and "labWF09registro0" not in testo:
        errore(nome, "chiama un modello ma non registra l'uso in WF09")

    # Ramo d'errore presente
    if not any(n["type"] == "n8n-nodes-base.stopAndError" for n in nodi):
        errore(nome, "manca il ramo d'errore")
    for n in nodi:
        if n.get("onError") == "continueErrorOutput":
            uscite = conn.get(n["name"], {}).get("main", [])
            if len(uscite) < 2 or not uscite[1]:
                errore(nome, f"il nodo {n['name']} ha l'uscita d'errore scollegata")

    # Segnaposto delle tabelle solo nel formato atteso da init
    for t in re.findall(r"__TBL_([a-z_]+)__", testo):
        if t not in ("corpus_documenti", "segnalazioni_sicurezza", "entita", "correzioni_grafo", "interrogazioni",
                     "verifiche", "uso_ia"):
            errore(nome, f"segnaposto di tabella sconosciuto: {t}")


def main():
    file = sorted(CARTELLA.glob("WF*.json"))
    if len(file) != 10:
        errori.append(f"attesi 10 workflow (WF00–WF09), trovati {len(file)}")
    for f in file:
        controlla(f)
    if errori:
        print("\n".join("FAIL " + e for e in errori))
        sys.exit(1)
    print(f"ok   {len(file)} workflow rispettano le convenzioni di CLAUDE.md §8.1")


if __name__ == "__main__":
    main()
