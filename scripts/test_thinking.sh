#!/usr/bin/env bash
# Verifica che l'estrazione non produca blocchi di ragionamento (CLAUDE.md §4, ADR-002).
# Invia a lab-estrazione la stessa opzione usata da LightRAG (think=false) e controlla la risposta.
set -euo pipefail
MODELLO="${1:-lab-estrazione}"
risposta="$(curl -fsS -m 600 http://127.0.0.1:11434/api/chat -d "{
  \"model\": \"$MODELLO\", \"stream\": false, \"think\": false,
  \"messages\": [{\"role\": \"user\", \"content\": \"Elenca in JSON le persone e i luoghi: Garibaldi sbarcò a Marsala nel 1860.\"}]
}")"
if echo "$risposta" | grep -q '<think>'; then echo "FAIL: la risposta contiene <think>"; exit 1; fi
if echo "$risposta" | grep -qE '"thinking":"[^"]+'; then echo "FAIL: il campo thinking non è vuoto"; exit 1; fi
echo "ok   $MODELLO risponde senza ragionamento esteso"
