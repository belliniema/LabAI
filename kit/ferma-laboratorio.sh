#!/bin/bash
# Doppio clic su Linux (o "Esegui come programma"): Ferma laboratorio.
cd "$(dirname "$0")" || exit 1
if [ -t 1 ] || [ -n "${LABORATORIO_IN_TERMINALE:-}" ]; then exec /bin/bash lib/laboratorio.sh ferma; fi
# Aperto dal file manager senza terminale: ne apre uno per mostrare i messaggi.
export LABORATORIO_IN_TERMINALE=1
for t in gnome-terminal konsole xfce4-terminal x-terminal-emulator xterm; do
  if command -v "$t" >/dev/null 2>&1; then
    case "$t" in
      gnome-terminal) exec gnome-terminal -- /bin/bash lib/laboratorio.sh ferma ;;
      *) exec "$t" -e /bin/bash lib/laboratorio.sh ferma ;;
    esac
  fi
done
exec /bin/bash lib/laboratorio.sh ferma
