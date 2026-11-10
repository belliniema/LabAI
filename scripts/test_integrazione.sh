#!/usr/bin/env bash
# Test d'integrazione con lo stack avviato (CLAUDE.md §13, fasi 2–3). Uso: make test-integrazione
#  1. nessuna porta in ascolto fuori da 127.0.0.1;
#  2. tutte le fixture di sicurezza segnalate dal servizio controlli CON Tika (anche l'immagine);
#  3. thinking disattivato nell'estrazione;
#  4. golden questions sul grafo demo: il documento atteso compare tra i riferimenti (≥ 7/10).
set -uo pipefail

RADICE="$(cd "$(dirname "$0")/.." && pwd)"
KIT="$RADICE/kit"
DOCKER="${DOCKER:-$(command -v docker || echo /Applications/Docker.app/Contents/Resources/bin/docker)}"
compose() { "$DOCKER" compose --project-directory "$KIT" -f "$KIT/compose.yml" "$@"; }
falliti=0
esito() { if [ "$1" -eq 0 ]; then echo "ok   $2"; else echo "FAIL $2"; falliti=1; fi; }

[ -f "$KIT/.env" ] || { echo "Avvia prima il laboratorio (manca kit/.env)"; exit 1; }
# shellcheck disable=SC1091
set -a; source "$KIT/.env"; set +a

# 1. Porte
fuori="$(compose --profile avanzato ps --format '{{.Publishers}}' | grep -oE '[0-9.:]+->' | grep -v '^127\.0\.0\.1:' || true)"
[ -z "$fuori" ]; esito $? "porte pubblicate solo su 127.0.0.1 ${fuori:+(trovate: $fuori)}"

# 2. Fixture con Tika: i file sono inviati in base64 al servizio controlli dall'interno della rete Docker
for atteso in "$RADICE"/samples/security_fixtures/*.atteso.json; do
  file="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["file"])' "$atteso")"
  corpo="$(python3 - "$RADICE/samples/security_fixtures/$file" <<'EOF'
import base64, json, sys, pathlib
p = pathlib.Path(sys.argv[1]); b = p.read_bytes()
testo = b.decode("utf-8", "replace") if p.suffix in (".txt", ".html") else ""
print(json.dumps({"doc_id": "TEST", "nome_file": p.name, "testo": testo, "file_base64": base64.b64encode(b).decode()}))
EOF
)"
  risposta="$(printf '%s' "$corpo" | compose exec -T controlli node -e '
    let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{const r=require("http").request("http://127.0.0.1:8099/controlla",{method:"POST",headers:{"Content-Type":"application/json"}},s=>{let o="";s.on("data",c=>o+=c).on("end",()=>console.log(o))});r.end(d)})')"
  python3 - "$atteso" "$risposta" <<'EOF'
import json, sys
atteso = json.load(open(sys.argv[1])); r = json.loads(sys.argv[2])
mancanti = [s for s in atteso["segnalazioni_attese"]
            if not any(x["tipo"] == s["tipo"] and s["contiene"] in x["estratto"] + " " + x["dettaglio"] for x in r["segnalazioni"])]
if not atteso["segnalazioni_attese"] and r["sospetto"]:
    mancanti = ["nessuna segnalazione attesa"]
sys.exit(1 if mancanti else 0)
EOF
  esito $? "fixture $file segnalata come atteso (con Tika)"
done

# 3. Thinking spento
bash "$RADICE/scripts/test_thinking.sh" >/dev/null; esito $? "lab-estrazione risponde senza blocchi di ragionamento"

# 4. Golden questions sul grafo demo
if [ -f "$KIT/demo/grafo/kv_store_doc_status.json" ]; then
  superate=0
  while IFS=$'\t' read -r id domanda attesi modalita; do
    corpo="$(python3 -c 'import json,sys; print(json.dumps({"query": sys.argv[1], "mode": sys.argv[2], "include_references": True}))' "$domanda" "$modalita")"
    rif="$(curl -sS -m 900 -X POST http://127.0.0.1:9622/query -H "X-API-Key: $LIGHTRAG_DEMO_API_KEY" -H 'Content-Type: application/json' -d "$corpo")"
    if python3 -c 'import json,sys; r=json.loads(sys.argv[1]); f=" ".join(x["file_path"] for x in r.get("references") or []); sys.exit(0 if any(d in f for d in sys.argv[2].split(";")) else 1)' "$rif" "$attesi"; then
      superate=$((superate + 1)); echo "     $id recupera $attesi"
    else echo "     $id NON recupera $attesi"; fi
  done < <(python3 -c 'import csv; [print("\t".join([r["id"], r["domanda"], r["doc_id_attesi"], r["modalita"]])) for r in csv.DictReader(open("'"$RADICE"'/samples/golden_questions.csv", encoding="utf-8"))]')
  [ "$superate" -ge 7 ]; esito $? "golden questions: $superate/10 recuperano il documento atteso (soglia 7)"
else
  echo "skip golden questions: grafo demo non ancora costruito (make demo-graph)"
fi

exit $falliti
