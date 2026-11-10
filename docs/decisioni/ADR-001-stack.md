# ADR-001 · Stack del kit e versioni fissate

- Stato: accettato (fase 0, da confermare con le prove su hardware della fase 4)
- Data: 2026-11-10

## Contesto

CLAUDE.md §3 chiede uno stack leggero (≤ 3 GB di RAM esclusi i modelli), solo su `127.0.0.1`,
senza database server, con versioni fissate e verificate sulla documentazione della versione
scelta.

## Decisione

| Servizio | Immagine fissata | Perché questa versione | Fonte verificata |
| --- | --- | --- | --- |
| Pannello | `caddy:2.11.9-alpine` | ultima 2.x stabile | Docker Hub `library/caddy` |
| n8n | `docker.n8n.io/n8nio/n8n:2.47.3` | è il tag `stable` del 10/11/2026 (stesso digest di `stable`) | Docker Hub `n8nio/n8n`, digest `sha256:6723b440…` |
| NocoDB | `nocodb/nocodb:2026.10.1` | ultima release | GitHub release 2026-10-29 |
| LightRAG | `ghcr.io/hkuds/lightrag:v1.5.7` | ultima release (non rc) | GitHub release 2026-09-02, tag GHCR `v1.5.7` |
| Apache Tika | `apache/tika:3.3.3.0-full` | vedi sotto | Docker Hub, `tika-docker/full/Dockerfile` |
| Neo4j | `neo4j:5.26.33-community` | ultima 5.26 LTS | Docker Hub |
| init, controlli | stessa immagine di n8n | contiene già Node.js: nessuna immagine in più da scaricare | — |

### Apache Tika 3.3.3 e non 4.2

Tika 4.x ha rimosso le intestazioni `X-Tika-OCR*` e `X-Tika-PDF*` (la configurazione passa per
preset JSON lato server). Tika 3.3.3 le conserva (`TesseractServerConfig.X_TIKA_OCR_HEADER_PREFIX`,
`PDFServerConfig.X_TIKA_PDF_HEADER_PREFIX`), e ci servono per:

- `X-Tika-OCRLanguage: ita+eng` (lingua dell'OCR per documento);
- `X-Tika-PDFOcrStrategy: no_ocr` / `ocr_only` per confrontare strato di testo e OCR (CLAUDE.md §10.2).

L'immagine `-full` installa `tesseract-ocr-ita` (`ARG LANGUAGES='eng ita fra spa deu jpn'` nel
Dockerfile di `tika-docker`). Endpoint usati: `PUT /tika/text`, `PUT /meta` (JSON), `GET /tika`
(saluto, usato come controllo di salute).

### Archivi

- n8n: SQLite nel volume `n8n_data` (predefinito).
- NocoDB: SQLite nel volume `nocodb_data` (predefinito senza `NC_DB`).
- LightRAG: `JsonKVStorage`, `JsonDocStatusStorage`, `NetworkXStorage`, `NanoVectorDBStorage`
  (predefiniti in `env.example` v1.5.7), volume `lightrag_data`.

### Memoria

Limiti `mem_limit` per container; la somma dei limiti è il tetto dello stack:

| Servizio | Limite |
| --- | --- |
| caddy | 64 MB |
| n8n | 640 MB |
| nocodb | 448 MB |
| lightrag | 768 MB |
| lightrag-demo | 320 MB |
| tika (JVM `-Xmx448m`) | 640 MB |
| controlli | 96 MB |
| **Totale** | **2976 MB** |

`init` gira solo al primo avvio e poi termina. Neo4j (profilo `avanzato`, 1 GB) è escluso dal
tetto ed è consigliato solo con 16 GB di RAM.

### Rete

Tutte le porte pubblicate con prefisso `127.0.0.1:`. Tika e controlli non pubblicano porte.
I container raggiungono Ollama su `http://host.docker.internal:11434`; per Linux il compose
dichiara `extra_hosts: ["host.docker.internal:host-gateway"]` su tutti i servizi che lo usano
(su Docker Desktop la voce è innocua).

### Opzioni di n8n verificate (`packages/@n8n/config`, tag `n8n@2.47.3`)

| Variabile | Valore | Motivo |
| --- | --- | --- |
| `N8N_RESTRICT_FILE_ACCESS_TO` | `/dati;/kit-prompts` | i nodi file leggono solo la cartella dati e i prompt |
| `NODES_EXCLUDE` | `["n8n-nodes-base.executeCommand","n8n-nodes-base.localFileTrigger","n8n-nodes-base.code"]` | il nodo Code è vietato nei workflow degli studenti (CLAUDE.md §8.1) |
| `N8N_DIAGNOSTICS_ENABLED` | `false` | niente telemetria verso l'esterno |
| `N8N_SSRF_PROTECTION_ENABLED` | `false` (predefinito) | i workflow devono raggiungere i servizi interni; il controllo dei domini web è fatto da `controlli` con l'allowlist |
| `N8N_BLOCK_FILE_ACCESS_TO_N8N_FILES` | `true` (predefinito) | |
| `N8N_LISTEN_ADDRESS` | `0.0.0.0` dentro il container | la porta è pubblicata solo su `127.0.0.1` |

L'account proprietario di n8n non è creato in automatico: `N8N_INSTANCE_OWNER_PASSWORD_HASH`
richiederebbe un hash bcrypt generato dal launcher senza dipendenze. Il pannello e la scheda 03
spiegano la creazione al primo accesso (CLAUDE.md §6 lo consente).

## Conseguenze

- Aggiornare una versione richiede di rifare le verifiche di questo ADR e la `make test`.
- Le prove su hardware (fase 4) misurano la RAM di picco reale; se supera 3 GB si riducono i
  limiti di n8n e Tika.
