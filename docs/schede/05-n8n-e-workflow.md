# 05 · n8n e i workflow WF00–WF09

**Obiettivo.** Eseguire i workflow del laboratorio in n8n e leggerne i risultati. Un *workflow* è un diagramma di passaggi (i *nodi*) collegati da frecce: ogni nodo fa una cosa sola e passa il risultato al successivo.

## Regole d'oro

1. In ogni workflow modifichi **solo il nodo PARAMETRI** (il primo dopo l'avvio). Doppio clic sul nodo → cambia il valore → chiudi → **Save**.
2. Leggi sempre la **nota gialla** in alto a sinistra: *Che cosa fa · Input · Output · Che cosa puoi modificare · Rischi e limiti*.
3. Per eseguire: pulsante **Execute workflow** in basso. Per i workflow con modulo (WF00, WF06, WF07) si apre una pagina dove scrivi la domanda.
4. Se un passaggio fallisce, il workflow si ferma con un messaggio in italiano (nodo **Ferma con messaggio**): leggilo in **Executions**.
   > [SCHERMATA: canvas di un workflow con la nota gialla e il nodo PARAMETRI]

## I workflow

| ID | Quando | Che cosa fare | Che cosa controllare dopo |
| --- | --- | --- | --- |
| **WF00 · Chat di prova** | L1, L3 | Scrivi una domanda; prova temperature 0, 0.7, 1.2 in PARAMETRI | Come cambia la risposta? Inventa? |
| **WF01 · Ingestione da cartella** | L7 | Trascina i file in `dati/inbox`, esegui | Nuovi record `acquisito` in NocoDB; testo in `dati/testi`; controlla l'OCR a campione e compila `qualita_ocr` |
| **WF02 · Ingestione dal web** | L8 | Crea in NocoDB record `da_acquisire` con l'URL; esegui | Record `acquisito`; le pagine non scaricate spiegano il motivo (dominio non ammesso, robots.txt) |
| **WF03 · Banche dati** | L8 | In PARAMETRI scegli `fonte` e `ricerca`; esegui | Schede `da_acquisire` con licenza dichiarata: verificala; poi WF02 scarica i testi |
| **WF04 · Controllo di sicurezza** | L5, L9 | Esegui dopo ogni ingestione | Documenti `in_quarantena` e righe in `segnalazioni_sicurezza`: decidi tu |
| **WF05 · Indicizzazione** | L11 | Porta i documenti ad `approvato`, esegui, **lascia il computer acceso e collegato** | Stato `indicizzato`; tempo stimato nel nodo *Tempo stimato* |
| **WF06 · Interrogazione** | L15–L16 | Scrivi domanda, tipologia, grafo, modalità | Risposta con `[doc_id]`; record in `interrogazioni` con il codice Q… |
| **WF07 · Preparazione della verifica** | L17 | Scrivi il codice Q… della domanda | Righe in `verifiche` con `esito` vuoto: lo compili tu |
| **WF08 · Esportazione del dossier** | L19 | Scrivi il tuo nome in PARAMETRI; esegui | Archivio zip in `dati/dossier` |
| **WF09 · Registro uso IA** | — | Non si esegue a mano: lo chiamano gli altri | Righe in `uso_ia` |

## WF05: lavori lunghi

Su un portatile un documento può richiedere da 2 a 20 minuti. WF05 lavora **un documento alla volta** e aggiorna lo stato dopo ciascuno: se il computer va in stop, riesegui WF05 e riprende dal primo documento non ancora indicizzato. Avvialo a fine lezione e lascialo lavorare a casa, con il computer collegato e il coperchio aperto.

## WF08: esportare anche i workflow (una volta sola)

1. In n8n: **Settings** → **n8n API** → **Create an API key** → copia la chiave.
2. **Overview** → **Credentials** → apri **n8n · API locale** → incolla la chiave in *API Key* → **Save**.
   > [SCHERMATA: credenziale n8n · API locale]

Senza chiave WF08 crea comunque l'archivio, senza la cartella `workflow`.

## Errori comuni

| Messaggio | Che cosa fare |
| --- | --- |
| *Il passaggio «…» non è riuscito* | Controlla che il pannello sia tutto verde e riesegui. |
| WF06: *Il corpus non contiene informazioni sufficienti* | Non è un errore: il contesto recuperato non basta. Prova un'altra modalità o riformula. |
| WF05 fermo su *Aspetta l'estrazione* per molto | È normale con modelli piccoli. Vedi la scheda 09. |

> **Domanda di riflessione.** n8n è *no-code* ma non *no-logic*: quali scelte di metodo sono "nascoste" nei nodi che non puoi modificare? Dove le trovi documentate?
