# Kit del Laboratorio di IA per la ricerca storica

Repository del docente per il kit che ogni studente installa sul portatile (Roma Tre, DSU).
Leggi prima `CLAUDE.md` (requisiti) e `docs/decisioni/` (ADR con le versioni verificate).

| Cartella | Contenuto |
| --- | --- |
| `kit/` | ciò che si distribuisce: launcher, `compose.yml`, configurazione, pannello, init, workflow, prompt, corpus demo |
| `scripts/` | generatori (workflow, fixture, corpus demo, schede), grafo demo, pacchetto offline, test |
| `samples/` | golden questions e fixture di sicurezza |
| `tests/` | test senza Docker |
| `docs/` | ADR, schede per gli studenti, documentazione del docente |

Comandi: `make test`, `make kit`, `make offline`, `make demo-graph`, `make test-integrazione`,
`make check-secrets`. Stato e punti ancora da provare: `docs/docente/problemi-noti.md`.
