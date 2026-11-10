# ADR-004 · Registri NocoDB raggiunti con nodi HTTP Request

- Stato: accettato
- Data: 2026-11-10

## Contesto

Il nodo NocoDB di n8n 2.47.3 è alla versione 2, con "resource mapper" e selettori di base e
tabella che salvano gli ID interni. Scrivere quel JSON a mano è fragile, e gli ID di base e
tabelle cambiano per ogni installazione.

## Decisione

- I workflow usano nodi **HTTP Request** verso l'API v2 di NocoDB 2026.10.1, verificata nei
  controller del tag:
  - `GET/POST/PATCH /api/v2/tables/{tableId}/records` (`data-table.controller.ts`);
  - autenticazione con intestazione `xc-token`, salvata nella credenziale n8n
    "NocoDB · registri" (tipo `httpHeaderAuth`).
- Nei JSON dei workflow gli ID compaiono come segnaposto `__TBL_corpus_documenti__` ecc.
  Il contenitore `init` crea le tabelle, legge gli ID restituiti da
  `POST /api/v2/meta/bases/{baseId}/tables` e sostituisce i segnaposto prima di importare i
  workflow con `n8n import:workflow`.
- Il token si crea con `POST /api/v2/meta/bases/{baseId}/api-tokens` dopo l'accesso con
  `POST /api/v1/auth/user/signin`. L'utente amministratore locale nasce da `NC_ADMIN_EMAIL` e
  `NC_ADMIN_PASSWORD` (`helpers/initAdminFromEnv.ts`).
- Lo stesso schema vale per LightRAG: credenziale `httpHeaderAuth` con intestazione `X-API-Key`.

## Conseguenze

- I nodi si chiamano in italiano ("Registro corpus · crea record"), con una nota che spiega la
  chiamata. Lo studente non deve toccarli.
- Se una versione futura di NocoDB cambia l'API, si aggiorna un solo punto: i modelli in
  `scripts/genera_workflows.py`.
