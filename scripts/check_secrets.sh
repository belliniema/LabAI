#!/usr/bin/env bash
# Controllo dei segreti (CLAUDE.md §8.1, §15): nessun segreto nel repository, nei JSON dei
# workflow o nel kit distribuito. Uso: make check-secrets   (oppure scripts/check_secrets.sh <cartella>)
set -euo pipefail

RADICE="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$RADICE"

trovati=0
segnala() { echo "SEGRETO? $1"; trovati=1; }

# File che non devono mai esistere nel repository o nel kit
while IFS= read -r f; do segnala "file vietato: $f"; done < <(
  find . -path ./.git -prune -o \( -name '.env' -o -name 'CREDENZIALI.txt' -o -name '*.pem' -o -name '*.key' \
    -o -name 'laboratorio-registri.json' \) -print | grep -v '^./.git$' || true)

# Credenziali nei workflow: solo riferimenti {id, name}
for f in kit/workflows/*.json; do
  python3 - "$f" <<'EOF' || trovati=1
import json, sys
wf = json.load(open(sys.argv[1], encoding="utf-8"))
ok = True
for n in wf["nodes"]:
    for c in n.get("credentials", {}).values():
        if set(c) - {"id", "name"}:
            print(f"SEGRETO? {sys.argv[1]}: credenziale incorporata nel nodo {n['name']}"); ok = False
    for k in ("headerParameters", "queryParameters"):
        for p in n["parameters"].get(k, {}).get("parameters", []):
            if p.get("name", "").lower() in ("x-api-key", "xc-token", "xc-auth", "authorization", "wskey", "x-n8n-api-key") and p.get("value") and not str(p["value"]).startswith("="):
                print(f"SEGRETO? {sys.argv[1]}: valore fisso per {p['name']} nel nodo {n['name']}"); ok = False
sys.exit(0 if ok else 1)
EOF
done

# Schemi tipici di chiavi e token nei file di testo del repository
schemi='(sk-[A-Za-z0-9]{20,}|xox[abpr]-[A-Za-z0-9-]{10,}|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.)'
if grep -rIEn --exclude-dir=.git --exclude-dir=node_modules --exclude='check_secrets.sh' "$schemi" . ; then
  segnala "schema di chiave trovato (vedi sopra)"
fi

# Assegnazioni di segreti con valore letterale nei file di configurazione del kit
if grep -rIEn --include='*.env' --include='*.yml' --include='*.yaml' \
    '^\s*(LIGHTRAG_API_KEY|LIGHTRAG_DEMO_API_KEY|N8N_ENCRYPTION_KEY|NC_ADMIN_PASSWORD|NC_AUTH_JWT_SECRET|NEO4J_PASSWORD|TOKEN_SECRET)\s*[:=]\s*[^$ "{][^ ]*' kit/ ; then
  segnala "segreto con valore letterale in un file di configurazione"
fi

if [ "$trovati" -ne 0 ]; then
  echo "check-secrets: NON superato"
  exit 1
fi
echo "ok   check-secrets: nessun segreto trovato"
