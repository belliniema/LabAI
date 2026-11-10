# ADR-003 · Servizio interno `controlli`

- Stato: accettato
- Data: 2026-11-10

## Contesto

CLAUDE.md §10.2 chiede controlli che con i soli nodi n8n (senza nodo Code) non si possono fare in
modo affidabile: confronto tra strato di testo e OCR dei PDF, contenuto HTML nascosto via CSS,
caratteri tag Unicode, robots.txt. Il §10.2 prevede in questo caso "un piccolo servizio interno
leggero, documentato in un ADR, invisibile allo studente".

## Decisione

`kit/servizi/controlli/server.js`: server HTTP in Node.js **senza dipendenze**, eseguito con
l'immagine di n8n già scaricata (nessuna immagine in più), limite 96 MB, nessuna porta pubblicata.

| Endpoint | Uso | Chiamato da |
| --- | --- | --- |
| `GET /salute` | controllo di salute | Caddy `/salute/controlli` |
| `POST /controlla` | testo + (facoltativo) file in base64 + metadati → elenco di segnalazioni | WF04 |
| `POST /web/verifica` | URL → dominio in allowlist? robots.txt consente? | WF02 |
| `POST /web/scarica` | URL verificato → HTML grezzo e testo leggibile, con ritardo minimo tra richieste allo stesso dominio | WF02 |

Regole:

- il servizio **segnala e non corregge**: non modifica testi né stati;
- gli estratti sono resi inerti (troncati a 300 caratteri, tra virgolette, prefisso
  `[ESTRATTO SOSPETTO]`, caratteri invisibili sostituiti da `<U+XXXX>`);
- non chiama mai un LLM;
- `/web/*` rifiuta qualsiasi dominio non presente in `config/allowlist_domini.txt`
  (difesa in profondità: anche WF02 controlla) e rispetta `robots.txt` con user-agent
  `LaboratorioIA-RomaTre`.

Il codice è commentato in italiano e coperto da `tests/controlli.test.js`, che verifica le
segnalazioni attese di ogni fixture (`samples/security_fixtures/*.atteso.json`).

## Conseguenze

- Il nodo Code resta vietato nei workflow: la logica è nel servizio, testata.
- Lo studente vede nel workflow un nodo HTTP "Controlli di sicurezza" con una nota che spiega che
  cosa fa il servizio.
