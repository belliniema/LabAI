#!/usr/bin/env bash
# Prepara la cartella "offline" per la chiavetta USB del dipartimento (CLAUDE.md §5 punto 5).
# Contiene le immagini Docker (docker save) e i modelli Ollama del kit (manifest + blob).
# Lo studente copia la cartella "offline" dentro LaboratorioIA/: il launcher la usa da solo.
#
# Uso (docente): make offline   oppure   scripts/pacchetto_offline.sh <cartella-destinazione>
# Attenzione: le immagini sono per l'architettura di QUESTO computer. Per una classe mista
# (Apple Silicon + Intel/AMD) prepara due chiavette, una per architettura, o usa PIATTAFORMA.
set -euo pipefail

RADICE="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$RADICE/build/offline}"
DOCKER="${DOCKER:-$(command -v docker || echo /Applications/Docker.app/Contents/Resources/bin/docker)}"
MODELLI_OLLAMA="${OLLAMA_MODELS:-$HOME/.ollama/models}"
PIATTAFORMA="${PIATTAFORMA:-}"
# shellcheck source=../kit/config/modelli.env
source "$RADICE/kit/config/modelli.env"

mkdir -p "$DEST/immagini" "$DEST/modelli"

echo "== Immagini Docker"
cd "$RADICE/kit"
immagini="$(N8N_ENCRYPTION_KEY=x NC_ADMIN_EMAIL=a@b.it NC_ADMIN_PASSWORD=x NC_AUTH_JWT_SECRET=x LIGHTRAG_API_KEY=x \
  LIGHTRAG_DEMO_API_KEY=x NEO4J_PASSWORD=x "$DOCKER" compose -f compose.yml --profile avanzato --profile scansioni config --images | sort -u)"
for img in $immagini; do
  file="$DEST/immagini/$(echo "$img" | tr '/:' '__').tar"
  if [ -f "$file" ]; then echo "  già presente: $img"; continue; fi
  echo "  $img"
  if [ -n "$PIATTAFORMA" ]; then "$DOCKER" pull -q --platform "$PIATTAFORMA" "$img" >/dev/null; else "$DOCKER" pull -q "$img" >/dev/null; fi
  "$DOCKER" save -o "$file" "$img"
done

echo "== Modelli Ollama (da $MODELLI_OLLAMA)"
copia_modello() {
  local nome="$1" tag="latest" base
  case "$nome" in *:*) tag="${nome##*:}"; nome="${nome%%:*}";; esac
  base="manifests/registry.ollama.ai/library/$nome/$tag"
  if [ ! -f "$MODELLI_OLLAMA/$base" ]; then
    echo "  manca $nome:$tag in Ollama: esegui prima «ollama pull $nome:${tag}»" >&2; exit 1
  fi
  mkdir -p "$DEST/modelli/$(dirname "$base")" "$DEST/modelli/blobs"
  cp "$MODELLI_OLLAMA/$base" "$DEST/modelli/$base"
  grep -oE 'sha256:[a-f0-9]{64}' "$MODELLI_OLLAMA/$base" | sort -u | while read -r d; do
    local blob="sha256-${d#sha256:}"
    [ -f "$DEST/modelli/blobs/$blob" ] || cp "$MODELLI_OLLAMA/blobs/$blob" "$DEST/modelli/blobs/$blob"
  done
  echo "  $nome:$tag"
}
copia_modello "$EMBEDDING_MODEL"
copia_modello "$LEGGERO_LLM"
copia_modello "$STANDARD_LLM"

du -sh "$DEST"
echo "Copia la cartella $DEST sulla chiavetta con il nome «offline»."
