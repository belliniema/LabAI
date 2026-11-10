# Costruzione del kit (docente)

## Requisiti sulla macchina del docente

Docker Desktop, Ollama, Python 3 con PyYAML (solo per `tests/test_kit.py`), Node.js ≥ 12, `zip`, `rsync`.
Facoltativi: `shellcheck`, `pwsh` (per verificare la sintassi del launcher Windows).

## Sequenza prima del corso

1. **Fase 0 — modelli.** `scripts/confronta_modelli.sh` su 5 documenti del corpus demo; compila la
   tabella in `docs/decisioni/ADR-002-modelli.md` e, se cambi modello, aggiorna `kit/config/modelli.env`.
2. **Corpus demo.** `python3 scripts/scarica_corpus_demo.py` (già eseguito: `kit/demo/corpus/`,
   con `registro_demo.csv` importabile in NocoDB).
3. **Grafo demo.** Su una macchina potente: `ollama pull qwen3.5:27b embeddinggemma:300m`, poi
   `MODELLO_GRANDE=qwen3.5:27b make demo-graph`. Il risultato va in `kit/demo/grafo/`.
4. **Fixture.** `make fixtures` (già eseguito: `samples/security_fixtures/`).
5. **Workflow.** Si modificano solo in `scripts/genera_workflows.py`, poi `make workflows`.
   Non modificare a mano i JSON in `kit/workflows/`.
6. **Test.** `make test` (senza Docker) e, con lo stack avviato, `make test-integrazione`.
7. **Schermate.** Sostituisci i segnaposto `> [SCHERMATA: …]` nelle schede con immagini in
   `docs/schede/img/` (formato `![descrizione](img/nome.png)`) e rigenera con `make schede`.
8. **LEGGIMI.pdf.** Esporta `docs/LEGGIMI.md` in PDF come `docs/LEGGIMI.pdf`.
9. **Kit.** `make kit` → `dist/LaboratorioIA-<versione>.zip` (lo zip conserva i permessi di esecuzione).
10. **Chiavetta.** `make offline` su un Mac Apple Silicon e su un PC x86 (le immagini dipendono
    dall'architettura): due chiavette etichettate.

## Versionamento

Ogni modifica distribuita incrementa `KIT_VERSION` in `kit/config/modelli.env`. Le versioni delle
immagini restano fissate per tutto il semestre (ADR-001). Ogni modifica a un prompt incrementa la
sua `versione`.

## Aggiornare il kit di uno studente

Lo studente sostituisce i file del kit **tenendo** la cartella `dati/`, il file `.env` e la cartella
`.stato/`. I registri e il grafo sono nei volumi Docker e non vengono toccati. Se cambiano i
workflow, cancellare il marcatore non serve: si importano a mano da n8n (*Import from file*).
