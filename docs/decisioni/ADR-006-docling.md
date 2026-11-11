# ADR-006 · Docling per i PDF scansionati (profilo facoltativo `scansioni`)

- Stato: accettato
- Data: 2026-11-11

## Contesto

Il corso userà PDF scansionati (documenti d'archivio, stampe ottocentesche). Apache Tika fa già
l'OCR con Tesseract in italiano, ma legge la pagina riga per riga: colonne, tabelle, note a piè
di pagina e intestazioni finiscono mescolate nel testo. Docling ricostruisce impaginazione,
ordine di lettura e tabelle e produce Markdown, che LightRAG divide in blocchi più puliti.

Docling è però pesante e il CLAUDE.md (§2, «Leggero») chiede uno stack di base entro 3 GB su un
portatile da 8 GB. Scelta concordata con il docente: **servizio facoltativo**, come Neo4j.

## Decisione

- Servizio `docling` nel profilo Compose `scansioni`, immagine
  `quay.io/docling-project/docling-serve-cpu:v1.38.2` (solo CPU, multi-architettura
  amd64/arm64), **senza porte pubblicate**: lo raggiungono solo n8n e Caddy (per il controllo di
  salute) sulla rete interna. `mem_limit: 3g`.
- Si attiva dal pannello («Attiva Docling», visibile solo con almeno 16 GB di RAM) e vale dal
  successivo «Avvia laboratorio». Il launcher lo salta con un avviso se Docker ha meno di 6 GB
  assegnati o, quando l'immagine manca ancora, se sul disco restano meno di 12 GB.
- In WF01 il parametro `motore_pdf_e_immagini` (`tika` predefinito, oppure `docling`) sceglie il
  motore per PDF e immagini. Gli altri formati (DOCX, HTML, TXT…) passano sempre da Tika. Tika
  legge comunque i metadati (titolo, autore, lingua) anche quando il testo viene da Docling.
- Se Docling è scelto ma non risponde (profilo spento, memoria esaurita), WF01 **non si ferma**:
  usa il testo di Tika e lo scrive in `note` del registro.
- I controlli di sicurezza di WF04 restano su Tika (strato di testo e OCR a confronto): Docling
  cambia solo il testo che entra nell'indice, non i controlli.

## Configurazione verificata

Fonti: README, `docs/configuration.md`, `docs/usage.md` del repository
`docling-project/docling-serve`; `/openapi.json` e `/v1/capabilities` dell'immagine `v1.38.2`
avviata il 2026-11-11; `docling/datamodel/settings.py` dentro l'immagine.

| Voce | Valore | Verifica |
| --- | --- | --- |
| porta interna | 5001 | `ExposedPorts`, `UVICORN_PORT` |
| salute | `GET /health` → `{"status":"ok"}` | `/openapi.json` |
| conversione sincrona | `POST /v1/convert/file`, multipart: `files`, `to_formats=md`, `do_ocr`, `force_ocr`, `ocr_preset`, `ocr_lang`, `image_export_mode`, `table_mode` | `/openapi.json` |
| risposta | `status` (`success`…), `errors[]`, `document.md_content` | prova reale |
| motori OCR (`ocr_preset`) | `auto`, `easyocr`, `rapidocr`, `tesseract`, `tesserocr`, `ocrmac`, … | `/v1/capabilities` |
| lingue OCR | tag BCP-47 (`it`, `en`, `la`) | descrizione del campo `ocr_lang` |
| pesi dei modelli | inclusi nell'immagine in `DOCLING_SERVE_ARTIFACTS_PATH`; nessun download a runtime | log: «No model weights will be downloaded at runtime» |
| attesa massima sincrona | `DOCLING_SERVE_MAX_SYNC_WAIT` (predefinito 120 s) → 1800 | configuration.md |
| un lavoro alla volta | `DOCLING_SERVE_ENG_LOC_NUM_WORKERS=1` (predefinito 2: un'istanza dei modelli per lavoro) | configuration.md |
| thread CPU | `DOCLING_NUM_THREADS=2`, `OMP_NUM_THREADS=2` (predefiniti 4) | configuration.md, `Config.Env` |
| convertitori in memoria | `DOCLING_SERVE_OPTIONS_CACHE_SIZE=1` (predefinito 2) | configuration.md |
| pagine per lotto | `DOCLING_PERF_PAGE_BATCH_SIZE=1` (predefinito 4) | `settings.py`: prefisso `DOCLING_`, separatore `_` |
| interfaccia web | spenta (`DOCLING_SERVE_ENABLE_UI` predefinito `false`) | configuration.md |

## Motore OCR: RapidOCR

Misure sul Mac di sviluppo (Apple Silicon, Docker con 7,9 GB), con una scansione sintetica a
200 dpi del proclama di Carlo Alberto (`D0003`), leggermente ruotata, sfocata e con rumore:

| Motore | 1 pagina | Picco di RAM | Esito |
| --- | --- | --- | --- |
| `easyocr` (`latin_g2`) | — | > 5 GB | **ucciso per memoria esaurita** anche con limite 5 GB |
| `tesseract` | — | — | nell'immagine c'è solo `eng.traineddata`: niente italiano |
| `rapidocr` (PP-OCRv6, ONNX) | 4 s | 2,6 GB (limite 5 GB) | testo identico all'originale, accenti compresi |

Su 8 pagine con `rapidocr` e limite 3 GB: 24 s (circa 3 s a pagina), picco 2,4 GB, 2,0 GB a
riposo dopo la prima conversione (i modelli restano caricati), 1,3 GB appena avviato. Lotti da
1 o da 4 pagine non cambiano il picco in modo apprezzabile; si tiene 1 per prudenza.

WF01 quindi fissa `ocr_preset=rapidocr` e `table_mode=accurate` (picco misurato in WF01:
2,46 GB). Come `ocr_lang` passa la prima lingua di `lingua_ocr`, convertita in BCP-47
(`ita+eng` → `it`); RapidOCR usa un dizionario multilingue e la lingua conta poco.

`force_ocr=false`: nei PDF nati digitali Docling usa lo strato di testo e fa l'OCR solo sulle
immagini. Il testo nascosto (bianco, corpo 1) entra quindi anche con Docling, come con Tika:
lo segnala WF04.

## Costi

- Disco: 4,8 GB d'immagine in più (lo stack di base pesa meno). Il launcher lo scarica solo
  quando lo studente attiva Docling; `make offline` lo include nella chiavetta.
- RAM: fino a 3 GB oltre allo stack di base. Ecco perché il pulsante compare solo con almeno
  16 GB di RAM e il profilo è spento di default.
- Tempo: circa 3 s a pagina su Apple Silicon; da misurare su Windows e Linux (fase 4,
  `docs/docente/prove-hardware.md`).

## Alternative scartate

- Docling sempre attivo o al posto di Tika per i PDF: supera i 3 GB dello stack e rende
  inutilizzabile il profilo `leggero` (8 GB).
- Aggiungere il pacchetto `tesseract-langpack-ita` all'immagine: richiederebbe un'immagine
  costruita da noi, da mantenere a ogni aggiornamento; RapidOCR basta.
- Immagine `docling-serve` con torch da PyPI: 8,7 GB su amd64, nessun vantaggio senza GPU.
