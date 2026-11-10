# 06 · L'interfaccia di LightRAG

**Obiettivo.** Esplorare il grafo di conoscenza, confrontare il tuo grafo con quello demo e porre domande dall'interfaccia. Un *grafo di conoscenza* è una rete di **entità** (persone, luoghi, eventi…) collegate da **relazioni**, ricavate dai documenti da un modello linguistico.

1. Dal pannello apri **LightRAG · il tuo grafo** (porta 9621) o **LightRAG · grafo demo** (porta 9622, sola lettura).
2. Alla prima apertura l'interfaccia chiede la **chiave API**: copiala da `dati/CREDENZIALI.txt` (è diversa per i due grafi).
   > [SCHERMATA: richiesta della chiave API]
3. Scheda **Documents**: i documenti indicizzati, con il nome `D0001.txt` ecc. (è il `doc_id`).
4. Scheda **Knowledge Graph**: scegli un'etichetta (es. *Garibaldi*) e osserva i collegamenti. Clic su un nodo → descrizione e documenti di origine.
   > [SCHERMATA: vista del grafo con un nodo selezionato]
5. Scheda **Retrieval**: domande di prova. Per le domande da registrare usa **WF06**, che salva tutto in NocoDB.

## Modalità di recupero

| Modalità | Che cosa usa |
| --- | --- |
| `naive` | solo i passi di testo più simili alla domanda (RAG classico) |
| `local` | entità vicine alla domanda e i loro collegamenti diretti |
| `global` | relazioni e temi d'insieme |
| `hybrid` | `local` + `global` |
| `mix` | grafo + passi di testo |

## Correggere il grafo

Ogni correzione (fusione di duplicati, rinomina, relazione sbagliata) va registrata in **correzioni_grafo** con motivazione e `doc_id_fonte`, *anche* se la fai nell'interfaccia. Anche le **conferme** contano: verificare che una relazione è corretta è lavoro di metodo.

## Il grafo demo

Il docente lo ha costruito con un modello più grande. In L11 confronta: quante entità trova in più? Quali errori ha il tuo modello e non il grande, e viceversa? Ogni modifica al grafo demo sparisce al riavvio.

> **Domanda di riflessione.** Il grafo sembra una mappa oggettiva del corpus. Quali scelte (tipi di entità, modello, segmentazione del testo) l'hanno già interpretato prima che tu lo guardassi?
