#!/bin/bash
# Doppio clic su macOS: Diagnostica. Il primo avvio va aperto con tasto destro → Apri (scheda 03).
cd "$(dirname "$0")" || exit 1
exec /bin/bash lib/laboratorio.sh diagnostica
