# 07 · OpenRefine e riconciliazione

**Obiettivo.** Pulire i metadati e collegare le entità principali a identificativi persistenti (Wikidata, VIAF, GeoNames). *Riconciliare* significa dire: "questa *Garibaldi* del mio corpus è proprio Giuseppe Garibaldi, Q5816 su Wikidata".

1. Installa OpenRefine dal sito ufficiale (applicazione desktop) e aprilo: si apre il browser su `http://127.0.0.1:3333`.
2. In NocoDB, tabella **entita**: menu della vista → **Download** → CSV.
   > [SCHERMATA: download CSV da NocoDB]
3. In OpenRefine: **Create project** → scegli il CSV → **Create project**.
4. Colonna `nome_canonico` → **Reconcile** → **Start reconciling** → servizio **Wikidata** → tipo (es. *human* per le persone) → **Start reconciling**.
   > [SCHERMATA: finestra di riconciliazione]
5. Per ogni proposta controlla date e descrizione: **non accettare in blocco**. Un omonimo sbagliato è un errore di attribuzione.
6. Aggiungi la colonna con il QID: menu della colonna → **Edit column** → **Add column based on this column** → `cell.recon.match.id`.
7. Esporta in CSV e reimporta in NocoDB (oppure copia i QID a mano nei record).
8. Registra in **correzioni_grafo** le fusioni di varianti onomastiche che la riconciliazione ti ha fatto scoprire.

## Errori comuni

- **Nessun candidato:** prova la grafia moderna o aggiungi una colonna con le date.
- **Toponimi storici:** GeoNames ha soprattutto nomi attuali: annota il nome d'epoca in `varianti`.

> **Domanda di riflessione.** Collegare un'entità a Wikidata la rende interoperabile, ma con quale modello del mondo? Che cosa succede a un personaggio minore che Wikidata non conosce?
