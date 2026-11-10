#!/usr/bin/env bash
# Launcher del Laboratorio di IA per la ricerca storica — macOS e Linux (CLAUDE.md §5).
# Lo studente non lo apre mai: lo richiamano i file a doppio clic
#   Avvia laboratorio / Ferma laboratorio / Diagnostica / Backup
# Ogni errore è un messaggio in italiano semplice che dice che cosa è successo e che cosa fare.
# Uso interno: laboratorio.sh avvia|ferma|diagnostica|backup

set -uo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATO="$KIT/.stato"
DATI="$KIT/dati"
OLLAMA="http://127.0.0.1:11434"
PANNELLO="http://localhost:8000"
PORTE=(8000 5678 8080 9621 9622)
SERVIZI_SALUTE=(nocodb lightrag lightrag-demo tika controlli n8n ollama)
IMMAGINE_ATTREZZI="caddy:2.11.9-alpine"
mkdir -p "$STATO"
LOG="$STATO/launcher.log"

# shellcheck source=../config/modelli.env
source "$KIT/config/modelli.env"

# ---------------------------------------------------------------------------
# Messaggi
# ---------------------------------------------------------------------------
if [ -t 1 ]; then VERDE=$'\e[32m'; ROSSO=$'\e[31m'; GIALLO=$'\e[33m'; GRASSETTO=$'\e[1m'; NORMALE=$'\e[0m'
else VERDE=""; ROSSO=""; GIALLO=""; GRASSETTO=""; NORMALE=""; fi

registra() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }
passo()    { echo; echo "${GRASSETTO}▶ $*${NORMALE}"; registra "PASSO $*"; }
ok()       { echo "  ${VERDE}✔${NORMALE} $*"; registra "OK $*"; }
avviso()   { echo "  ${GIALLO}!${NORMALE} $*"; registra "AVVISO $*"; }

# Errore bloccante: che cosa è successo + che cosa fare. La finestra resta aperta.
fallisci() {
  local cosa="$1" rimedio="$2"
  registra "ERRORE $cosa | $rimedio"
  echo
  echo "${ROSSO}${GRASSETTO}✖ $cosa${NORMALE}"
  echo
  echo "${GRASSETTO}Che cosa fare:${NORMALE} $rimedio"
  echo
  echo "Se il problema resta, fai doppio clic su «Diagnostica» e allega il file creato sul Desktop nel forum del corso."
  attendi_invio
  exit 1
}

attendi_invio() {
  if [ -t 0 ]; then echo; read -r -p "Premi Invio per chiudere questa finestra." _; fi
}

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------
trova_docker() {
  if command -v docker >/dev/null 2>&1; then DOCKER="$(command -v docker)"; return 0; fi
  for d in /usr/local/bin/docker /opt/homebrew/bin/docker /Applications/Docker.app/Contents/Resources/bin/docker "$HOME/.docker/bin/docker"; do
    if [ -x "$d" ]; then DOCKER="$d"; export PATH="$(dirname "$d"):$PATH"; return 0; fi
  done
  return 1
}

compose() { "$DOCKER" compose --project-directory "$KIT" -f "$KIT/compose.yml" "$@"; }

docker_attivo() { "$DOCKER" info >/dev/null 2>&1; }

controlla_docker() {
  passo "Controllo Docker"
  trova_docker || fallisci "Docker Desktop non è installato." \
    "Installa Docker Desktop seguendo la scheda «01 · Installare Docker Desktop», poi fai di nuovo doppio clic su Avvia laboratorio."
  if ! docker_attivo; then
    avviso "Docker è installato ma spento: provo ad avviarlo (può volerci fino a 2 minuti)."
    case "$(uname -s)" in
      Darwin) open -a Docker >/dev/null 2>&1 || true ;;
      Linux) systemctl --user start docker-desktop >/dev/null 2>&1 || true ;;
    esac
    local i
    for i in $(seq 1 60); do docker_attivo && break; sleep 2; printf '.'; done
    echo
  fi
  docker_attivo || fallisci "Docker non è avviato." \
    "Apri Docker Desktop, attendi che l'icona della balena nella barra in alto resti ferma e fai di nuovo doppio clic su Avvia laboratorio."
  "$DOCKER" compose version >/dev/null 2>&1 || fallisci "Questa versione di Docker non ha il comando compose." \
    "Aggiorna Docker Desktop all'ultima versione (menu Docker → Check for updates) e riprova."
  ok "Docker è avviato"
}

# ---------------------------------------------------------------------------
# Risorse: RAM, memoria di Docker, disco, porte
# ---------------------------------------------------------------------------
ram_gb() {
  case "$(uname -s)" in
    Darwin) echo $(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 )) ;;
    *) awk '/MemTotal/ {printf "%d", $2/1024/1024 + 0.5}' /proc/meminfo ;;
  esac
}

immagini_mancanti() { compose config --images 2>/dev/null | while read -r i; do "$DOCKER" image inspect "$i" >/dev/null 2>&1 || echo "$i"; done; }

disco_libero_gb() { df -Pk "$KIT" | awk 'NR==2 {printf "%d", $4/1024/1024}'; }

porta_occupata() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

controlla_risorse() {
  passo "Controllo memoria, disco e porte"
  RAM_GB="$(ram_gb)"
  ok "Memoria del computer: ${RAM_GB} GB"
  if [ "$RAM_GB" -lt "$LEGGERO_RAM_MIN_GB" ] 2>/dev/null; then
    avviso "Il computer ha meno di ${LEGGERO_RAM_MIN_GB} GB di memoria: il laboratorio sarà molto lento. Valuta una postazione di dipartimento o un portatile in prestito."
  fi
  local mem_docker
  mem_docker=$(( $("$DOCKER" info --format '{{.MemTotal}}' 2>/dev/null || echo 0) / 1024 / 1024 ))
  if [ "$mem_docker" -gt 0 ] && [ "$mem_docker" -lt 3500 ]; then
    fallisci "Docker può usare solo ${mem_docker} MB di memoria: ne servono almeno 3500." \
      "Apri Docker Desktop → Settings → Resources e porta «Memory limit» ad almeno 4 GB, poi Apply & restart e riprova."
  fi
  [ "$mem_docker" -gt 0 ] && ok "Memoria assegnata a Docker: ${mem_docker} MB"
  DISCO_GB="$(disco_libero_gb)"
  # 15 GB servono solo finché ci sono immagini da scaricare (circa 4 GB compressi, il doppio una volta estratte)
  if [ "$DISCO_GB" -lt 15 ] && ! [ -f "$STATO/primo-avvio-completato" ] && [ -n "$(immagini_mancanti)" ]; then
    fallisci "Sul disco restano solo ${DISCO_GB} GB liberi: per il primo avvio ne servono almeno 15." \
      "Libera spazio (svuota il Cestino, sposta foto e video su un disco esterno) e fai di nuovo doppio clic su Avvia laboratorio."
  fi
  [ "$DISCO_GB" -lt 5 ] && avviso "Restano solo ${DISCO_GB} GB liberi sul disco: libera spazio presto."
  ok "Spazio libero sul disco: ${DISCO_GB} GB"
  if [ -z "$(compose ps -q 2>/dev/null)" ]; then
    local p
    for p in "${PORTE[@]}"; do
      porta_occupata "$p" && fallisci "La porta $p è già usata da un altro programma." \
        "Chiudi gli altri programmi di sviluppo aperti (o riavvia il computer) e fai di nuovo doppio clic su Avvia laboratorio."
    done
    ok "Porte libere"
  fi
}

# ---------------------------------------------------------------------------
# Ollama
# ---------------------------------------------------------------------------
ollama_attivo() { curl -fsS -m 3 "$OLLAMA/api/version" >/dev/null 2>&1; }

controlla_ollama() {
  passo "Controllo Ollama"
  if ! ollama_attivo; then
    avviso "Ollama non risponde: provo ad avviarlo."
    case "$(uname -s)" in
      Darwin) open -a Ollama >/dev/null 2>&1 || true ;;
      Linux) command -v ollama >/dev/null 2>&1 && (nohup ollama serve >/dev/null 2>&1 &) ;;
    esac
    local i
    for i in $(seq 1 30); do ollama_attivo && break; sleep 2; printf '.'; done
    echo
  fi
  ollama_attivo || fallisci "Ollama non è avviato o non è installato." \
    "Installa Ollama dal sito ufficiale seguendo la scheda «02 · Installare Ollama», aprilo (compare l'icona del lama nella barra) e fai di nuovo doppio clic su Avvia laboratorio."
  ok "Ollama risponde ($(curl -fsS -m 3 "$OLLAMA/api/version" | sed -E 's/.*"version":"([^"]*)".*/versione \1/'))"
}

# ---------------------------------------------------------------------------
# Profilo dei modelli
# ---------------------------------------------------------------------------
scegli_profilo() {
  passo "Scelta del profilo dei modelli"
  local forzato=""
  [ -f "$STATO/profilo-scelto" ] && forzato="$(tr -dc 'a-z' < "$STATO/profilo-scelto")"
  if [ "$forzato" = "standard" ] || [ "$forzato" = "leggero" ]; then
    PROFILO="$forzato"; ok "Profilo «${PROFILO}» scelto dal pannello"
  elif [ "$RAM_GB" -ge "$STANDARD_RAM_MIN_GB" ]; then
    PROFILO="standard"; ok "Profilo «standard» (${STANDARD_LLM}, contesto ${STANDARD_NUM_CTX} token)"
  else
    PROFILO="leggero"; ok "Profilo «leggero» (${LEGGERO_LLM}, contesto ${LEGGERO_NUM_CTX} token)"
  fi
  if [ "$PROFILO" = "standard" ]; then LLM="$STANDARD_LLM"; NUM_CTX="$STANDARD_NUM_CTX"; CORPUS_MAX="$STANDARD_CORPUS_MAX"
  else LLM="$LEGGERO_LLM"; NUM_CTX="$LEGGERO_NUM_CTX"; CORPUS_MAX="$LEGGERO_CORPUS_MAX"; fi
}

# ---------------------------------------------------------------------------
# Segreti locali (.env) e credenziali dello studente
# ---------------------------------------------------------------------------
casuale() { LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c "$1"; }

imposta_env() {
  # Aggiorna o aggiunge VARIABILE=valore in .env
  local chiave="$1" valore="$2" f="$KIT/.env"
  if grep -q "^$chiave=" "$f" 2>/dev/null; then
    sed -i.bak "s|^$chiave=.*|$chiave=$valore|" "$f" && rm -f "$f.bak"
  else
    echo "$chiave=$valore" >> "$f"
  fi
}

prepara_segreti() {
  passo "Segreti locali"
  if [ ! -f "$KIT/.env" ]; then
    umask 077
    cat > "$KIT/.env" <<EOF
# Generato al primo avvio: segreti locali di QUESTA installazione. Non condividere questo file.
N8N_ENCRYPTION_KEY=$(casuale 48)
LIGHTRAG_API_KEY=lab-$(casuale 32)
LIGHTRAG_DEMO_API_KEY=demo-$(casuale 32)
NC_ADMIN_EMAIL=studente@laboratorio.local
NC_ADMIN_PASSWORD=Lab-$(casuale 20)!Aa9
NC_AUTH_JWT_SECRET=$(casuale 48)
NEO4J_PASSWORD=neo4j-$(casuale 24)
EOF
    umask 022
    ok "Creati segreti casuali per questa installazione"
  else
    ok "Segreti già presenti"
  fi
  imposta_env LAB_PROFILO "$PROFILO"
  imposta_env LAB_KIT_VERSION "$KIT_VERSION"
  # shellcheck disable=SC1091
  set -a; source "$KIT/.env"; set +a
  mkdir -p "$DATI"
  cat > "$DATI/CREDENZIALI.txt" <<EOF
LABORATORIO DI IA PER LA RICERCA STORICA — le tue credenziali locali
Valgono solo su questo computer. Non condividerle e non allegarle nel forum.

NocoDB (registri)          http://localhost:8080
  email:    $NC_ADMIN_EMAIL
  password: $NC_ADMIN_PASSWORD

LightRAG grafo personale   http://localhost:9621
  chiave API: $LIGHTRAG_API_KEY

LightRAG grafo demo        http://localhost:9622
  chiave API: $LIGHTRAG_DEMO_API_KEY

n8n (workflow)             http://localhost:5678
  al primo accesso crei tu l'account (scheda 03).

Neo4j (solo profilo avanzato) http://localhost:7474
  utente: neo4j   password: $NEO4J_PASSWORD
EOF
  chmod 600 "$DATI/CREDENZIALI.txt" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Immagini e modelli: da chiavetta (offline/) o da internet
# ---------------------------------------------------------------------------
carica_offline() {
  [ -d "$KIT/offline" ] || return 0
  passo "Carico immagini e modelli dalla chiavetta (cartella offline)"
  local t
  for t in "$KIT"/offline/immagini/*.tar; do
    [ -f "$t" ] || continue
    echo "  carico $(basename "$t")…"
    "$DOCKER" load -i "$t" >/dev/null || fallisci "Non riesco a caricare $(basename "$t") dalla chiavetta." \
      "Copia di nuovo la cartella offline dalla chiavetta del dipartimento e riprova."
  done
  if [ -d "$KIT/offline/modelli" ]; then
    local destinazione="${OLLAMA_MODELS:-$HOME/.ollama/models}"
    mkdir -p "$destinazione"
    cp -Rn "$KIT/offline/modelli/." "$destinazione/" 2>/dev/null || cp -R "$KIT/offline/modelli/." "$destinazione/"
    ok "Modelli copiati in $destinazione"
  fi
}

scarica_immagini() {
  passo "Immagini Docker"
  local mancanti
  mancanti="$(immagini_mancanti)"
  if [ -z "$mancanti" ]; then ok "Tutte le immagini sono già presenti"; return; fi
  echo "  Scarico le immagini mancanti (circa 4 GB la prima volta: può richiedere molti minuti)."
  compose pull --quiet 2>&1 | tee -a "$LOG" >/dev/null &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do printf '.'; sleep 5; done
  echo
  wait "$pid" || fallisci "Lo scaricamento delle immagini Docker non è riuscito." \
    "Controlla la connessione a internet (o usa la chiavetta del dipartimento con la cartella offline) e fai di nuovo doppio clic su Avvia laboratorio."
  ok "Immagini scaricate"
}

modello_presente() { curl -fsS -m 10 "$OLLAMA/api/tags" | grep -q "\"name\":\"$1\""; }

scarica_modello() {
  local m="$1"
  if modello_presente "$m"; then ok "Modello $m già presente"; return; fi
  echo "  Scarico il modello ${m}…"
  # Ollama riprende i download interrotti: in caso di errore («download stalled») si riprova fino a 3 volte
  local tentativo
  for tentativo in 1 2 3; do
    rm -f "$STATO/pull-errore"
    [ "$tentativo" -gt 1 ] && printf '\n  Il download si è interrotto: riprovo (tentativo %d di 3)…\n' "$tentativo"
    scarica_modello_una_volta "$m"
    [ -f "$STATO/pull-errore" ] || break
  done
  echo
  if [ -f "$STATO/pull-errore" ] || ! modello_presente "$m"; then
    rm -f "$STATO/pull-errore"
    fallisci "Non riesco a scaricare il modello $m." \
      "Controlla la connessione a internet e lo spazio su disco (o usa la chiavetta del dipartimento) e fai di nuovo doppio clic su Avvia laboratorio."
  fi
  ok "Modello $m scaricato"
}

scarica_modello_una_volta() {
  local m="$1" ultimo=""
  curl -sS -N -m 7200 "$OLLAMA/api/pull" -d "{\"model\":\"$m\",\"stream\":true}" 2>>"$LOG" | while IFS= read -r riga; do
    case "$riga" in
      *'"error"'*) echo "$riga" >> "$LOG"; echo "ERRORE" > "$STATO/pull-errore" ;;
      *'"completed"'*)
        local tot com
        tot=$(echo "$riga" | sed -E 's/.*"total":([0-9]+).*/\1/')
        com=$(echo "$riga" | sed -E 's/.*"completed":([0-9]+).*/\1/')
        # stampa solo quando la percentuale cambia, per non riempire il registro
        [ "$tot" -gt 0 ] 2>/dev/null && [ "$((com * 100 / tot))" != "$ultimo" ] && {
          ultimo=$((com * 100 / tot))
          printf '\r  %s: %3d%% (%d MB di %d MB)   ' "$m" "$ultimo" $((com / 1048576)) $((tot / 1048576)); } ;;
    esac
  done
}

prepara_modelli() {
  passo "Modelli linguistici (profilo $PROFILO)"
  scarica_modello "$EMBEDDING_MODEL"
  scarica_modello "$LLM"
  # Modelli derivati con contesto e temperatura fissati (ADR-002). Si rifanno se cambia il profilo.
  local firma="$PROFILO|$LLM|$NUM_CTX|$TEMPERATURA_ESTRAZIONE|$TEMPERATURA_RISPOSTA"
  if [ "$(cat "$STATO/modelli-derivati" 2>/dev/null)" != "$firma" ] || ! modello_presente "$MODEL_ESTRAZIONE:latest" || ! modello_presente "$MODEL_RISPOSTA:latest"; then
    local nome temp
    for nome in "$MODEL_ESTRAZIONE" "$MODEL_RISPOSTA"; do
      [ "$nome" = "$MODEL_ESTRAZIONE" ] && temp="$TEMPERATURA_ESTRAZIONE" || temp="$TEMPERATURA_RISPOSTA"
      local risposta
      risposta="$(curl -sS -m 600 "$OLLAMA/api/create" -d "{\"model\":\"$nome\",\"from\":\"$LLM\",\"parameters\":{\"num_ctx\":$NUM_CTX,\"temperature\":$temp},\"stream\":false}" 2>&1)"
      echo "$risposta" | grep -q '"success"' || fallisci "Non riesco a creare il modello $nome." \
        "Aggiorna Ollama all'ultima versione e fai di nuovo doppio clic su Avvia laboratorio. (Dettaglio: ${risposta:0:200})"
      # Copia del Modelfile equivalente, per la documentazione del progetto
      sed -e "s|__LLM__|$LLM|" -e "s|__NUM_CTX__|$NUM_CTX|" -e "s|__TEMPERATURA__|$temp|" \
        "$KIT/config/Modelfile.${nome#lab-}.tmpl" > "$STATO/Modelfile.$nome"
    done
    echo "$firma" > "$STATO/modelli-derivati"
    ok "Creati i modelli $MODEL_ESTRAZIONE e $MODEL_RISPOSTA (contesto $NUM_CTX token)"
  else
    ok "Modelli $MODEL_ESTRAZIONE e $MODEL_RISPOSTA già pronti"
  fi
  # La dimensione dichiarata a LightRAG deve coincidere con quella di Ollama (CLAUDE.md §4).
  local dim
  dim="$(curl -fsS -m 120 "$OLLAMA/api/embed" -d "{\"model\":\"$EMBEDDING_MODEL\",\"input\":\"prova\"}" | sed -E 's/.*"embeddings":\[\[([^]]*)\]\].*/\1/' | awk -F, '{print NF}')"
  [ "$dim" = "$EMBEDDING_DIM" ] || fallisci "Il modello di embedding restituisce vettori di dimensione ${dim:-sconosciuta} invece di $EMBEDDING_DIM." \
    "Segnala il problema al docente con il file di Diagnostica: non indicizzare documenti finché non è risolto."
  ok "Embedding verificato: $EMBEDDING_MODEL, dimensione $dim"
}

# ---------------------------------------------------------------------------
# Avvio dei servizi
# ---------------------------------------------------------------------------
scrivi_stato() {
  cat > "$STATO/stato.json" <<EOF
{
  "versione_kit": "$KIT_VERSION",
  "profilo": "$PROFILO",
  "llm": "$LLM",
  "contesto": $NUM_CTX,
  "embedding": "$EMBEDDING_MODEL",
  "corpus_consigliato": $CORPUS_MAX,
  "ram_gb": $RAM_GB,
  "disco_libero_gb": $(disco_libero_gb),
  "neo4j": $([ -f "$STATO/neo4j-attivo" ] && echo true || echo false),
  "avviato_il": "$(date '+%Y-%m-%dT%H:%M:%S')"
}
EOF
}

attendi_salute() {
  local servizio="$1" massimo="$2" i
  for i in $(seq 1 "$massimo"); do
    curl -fsS -m 5 -o /dev/null "$PANNELLO/salute/$servizio" 2>/dev/null && return 0
    sleep 3
  done
  return 1
}

avvia_servizi() {
  passo "Avvio dei servizi (la prima volta prepara anche tabelle e workflow)"
  mkdir -p "$DATI"/{inbox,testi,dossier/backup}
  scrivi_stato
  local profili=()
  [ -f "$STATO/neo4j-attivo" ] && profili=(--profile avanzato)
  # ${a[@]+...}: compatibile con bash 3.2 di macOS anche con array vuoto e set -u
  if ! compose ${profili[@]+"${profili[@]}"} up -d --remove-orphans >>"$LOG" 2>&1; then
    local messaggio
    messaggio="$(sed -n 's/.*"messaggio": "\(.*\)",*/\1/p' "$STATO/init.json" 2>/dev/null | head -1)"
    fallisci "I servizi del laboratorio non sono partiti. ${messaggio}" \
      "Fai di nuovo doppio clic su Avvia laboratorio: spesso il secondo tentativo basta (la prima configurazione riprende da dove si era fermata)."
  fi
  local s
  for s in "${SERVIZI_SALUTE[@]}"; do
    if attendi_salute "$s" 60; then ok "$s pronto"; else avviso "$s non risponde ancora: controlla il pannello tra qualche minuto"; fi
  done
  touch "$STATO/primo-avvio-completato"
}

# ---------------------------------------------------------------------------
# Comandi
# ---------------------------------------------------------------------------
apri_browser() {
  case "$(uname -s)" in
    Darwin) open "$1" ;;
    *) xdg-open "$1" >/dev/null 2>&1 || true ;;
  esac
}

cmd_avvia() {
  echo "${GRASSETTO}Laboratorio di IA per la ricerca storica · kit $KIT_VERSION${NORMALE}"
  echo "Non chiudere questa finestra finché non si apre il pannello nel browser."
  registra "=== avvio kit $KIT_VERSION"
  controlla_docker
  controlla_risorse
  controlla_ollama
  scegli_profilo
  prepara_segreti
  carica_offline
  scarica_immagini
  prepara_modelli
  avvia_servizi
  scrivi_stato
  passo "Fatto"
  ok "Il pannello del laboratorio si apre nel browser: $PANNELLO"
  apri_browser "$PANNELLO"
  echo
  echo "Puoi chiudere questa finestra. Il laboratorio resta acceso finché non fai doppio clic su «Ferma laboratorio»."
  attendi_invio
}

cmd_ferma() {
  echo "${GRASSETTO}Fermo il laboratorio${NORMALE}"
  trova_docker || fallisci "Docker Desktop non è installato." "Non c'è niente da fermare."
  docker_attivo || { ok "Docker è già spento: il laboratorio è fermo."; attendi_invio; return; }
  compose --profile avanzato down >>"$LOG" 2>&1 || fallisci "Non riesco a fermare i servizi." "Chiudi Docker Desktop dal suo menu: i dati sono al sicuro."
  ok "Laboratorio fermato. I tuoi dati restano nella cartella dati e nei registri."
  attendi_invio
}

cartella_desktop() {
  local d
  d="$(command -v xdg-user-dir >/dev/null 2>&1 && xdg-user-dir DESKTOP || true)"
  [ -n "$d" ] && [ -d "$d" ] && { echo "$d"; return; }
  for d in "$HOME/Desktop" "$HOME/Scrivania"; do [ -d "$d" ] && { echo "$d"; return; }; done
  echo "$HOME"
}

cmd_diagnostica() {
  echo "${GRASSETTO}Diagnostica del laboratorio${NORMALE}"
  local data dir
  data="$(date '+%Y-%m-%d-%H%M')"
  dir="$(mktemp -d)/Diagnostica-$data"
  mkdir -p "$dir/log"
  {
    echo "kit: $KIT_VERSION"; echo "data: $(date)"
    echo "sistema: $(uname -a)"
    [ "$(uname -s)" = "Darwin" ] && sw_vers
    [ -f /etc/os-release ] && cat /etc/os-release
    echo "ram_gb: $(ram_gb)"; echo "disco_libero_gb: $(disco_libero_gb)"
    echo "cartella del kit: $KIT"
  } > "$dir/sistema.txt" 2>&1
  if trova_docker && docker_attivo; then
    "$DOCKER" version > "$dir/docker-version.txt" 2>&1
    "$DOCKER" info > "$dir/docker-info.txt" 2>&1
    compose --profile avanzato ps -a > "$dir/compose-ps.txt" 2>&1
    "$DOCKER" stats --no-stream > "$dir/docker-stats.txt" 2>&1
    local s
    for s in pannello n8n init nocodb lightrag lightrag-demo tika controlli neo4j; do
      compose logs --no-color --tail 500 "$s" > "$dir/log/$s.txt" 2>&1
    done
  else
    echo "Docker non installato o non avviato" > "$dir/docker-version.txt"
  fi
  { curl -sS -m 5 "$OLLAMA/api/version"; echo; curl -sS -m 5 "$OLLAMA/api/tags"; } > "$dir/ollama.txt" 2>&1
  {
    for s in "${SERVIZI_SALUTE[@]}" lightrag-demo neo4j; do
      printf '%-15s %s\n' "$s" "$(curl -s -m 5 -o /dev/null -w '%{http_code}' "$PANNELLO/salute/$s" 2>/dev/null)"
    done
  } > "$dir/salute.txt"
  cp "$STATO"/*.json "$STATO"/*.log "$STATO"/Modelfile.* "$dir/" 2>/dev/null || true
  ls -la "$DATI" "$DATI/inbox" "$DATI/testi" > "$dir/cartelle.txt" 2>&1
  # Rimozione dei segreti: ogni valore di .env e i token in chiaro diventano [RIMOSSO].
  if [ -f "$KIT/.env" ]; then
    local valore
    while IFS='=' read -r _ valore; do
      [ ${#valore} -ge 8 ] || continue
      # I segreti generati contengono solo lettere, cifre, "-" e "!": sicuri dentro sed.
      grep -rlF -- "$valore" "$dir" 2>/dev/null | while read -r f; do
        LC_ALL=C sed -i.bak "s|$valore|[RIMOSSO]|g" "$f"
      done
    done < <(grep -E '^[A-Z0-9_]+=' "$KIT/.env")
  fi
  find "$dir" -name '*.bak' -delete
  LC_ALL=C sed -i.bak -E 's/(xc-token|xc-auth|X-API-Key|x-api-key|apiKey|password|token)(["]?[:=] ?["]?)[A-Za-z0-9._!-]{8,}/\1\2[RIMOSSO]/g' "$dir"/*.txt "$dir"/log/*.txt 2>/dev/null
  find "$dir" -name '*.bak' -delete
  local zipfile
  zipfile="$(cartella_desktop)/Diagnostica-$data.zip"
  if command -v zip >/dev/null 2>&1; then
    (cd "$(dirname "$dir")" && zip -qr "$zipfile" "$(basename "$dir")")
  else
    zipfile="${zipfile%.zip}.tar.gz"
    tar -czf "$zipfile" -C "$(dirname "$dir")" "$(basename "$dir")"
  fi
  rm -rf "$(dirname "$dir")"
  ok "Rapporto creato: $zipfile"
  echo "Allegalo nel forum del corso. Non contiene password né chiavi."
  attendi_invio
}

cmd_backup() {
  echo "${GRASSETTO}Backup del laboratorio${NORMALE}"
  controlla_docker
  local data dest
  data="$(date '+%Y-%m-%d-%H%M')"
  dest="$DATI/dossier/backup/backup-$data"
  mkdir -p "$dest"
  passo "Fermo i servizi per copiare i dati in modo coerente"
  compose --profile avanzato stop >>"$LOG" 2>&1
  local progetto vol
  progetto="laboratorio-ia"
  for vol in n8n_data nocodb_data lightrag_data lightrag_inputs neo4j_data; do
    "$DOCKER" volume inspect "${progetto}_$vol" >/dev/null 2>&1 || continue
    "$DOCKER" run --rm -v "${progetto}_$vol:/volume:ro" -v "$dest:/backup" --entrypoint tar "$IMMAGINE_ATTREZZI" \
      -czf "/backup/$vol.tar.gz" -C /volume . >>"$LOG" 2>&1 || {
        compose start >>"$LOG" 2>&1
        fallisci "Il backup del registro $vol non è riuscito." "Controlla lo spazio su disco e riprova."
      }
    ok "Copiato $vol"
  done
  tar -czf "$dest/dati.tar.gz" -C "$DATI" --exclude './dossier/backup' . && ok "Copiata la cartella dati"
  cp "$KIT/.env" "$dest/segreti.env" && chmod 600 "$dest/segreti.env"
  echo "Backup del $(date) · kit $KIT_VERSION. Per il ripristino vedi la scheda «Backup e Diagnostica»." > "$dest/LEGGIMI.txt"
  passo "Riavvio i servizi"
  compose start >>"$LOG" 2>&1 || avviso "Riavvio non riuscito: fai doppio clic su Avvia laboratorio."
  ok "Backup completato: $dest"
  echo "Copia la cartella del backup su un disco esterno o in un cloud di ateneo: contiene anche le tue chiavi locali."
  attendi_invio
}

case "${1:-}" in
  avvia) cmd_avvia ;;
  ferma) cmd_ferma ;;
  diagnostica) cmd_diagnostica ;;
  backup) cmd_backup ;;
  *) echo "Uso: $0 avvia|ferma|diagnostica|backup"; exit 2 ;;
esac
