# 04 · I registri in NocoDB

**Obiettivo.** Usare NocoDB, un programma che mostra i registri del laboratorio come fogli di calcolo, per documentare corpus, segnalazioni, grafo e verifiche.

1. Dal pannello apri **NocoDB** ed entra con email e password di `dati/CREDENZIALI.txt`.
   > [SCHERMATA: login di NocoDB]
2. Apri la base **Laboratorio IA**: trovi sette tabelle.

| Tabella | A che cosa serve | Chi scrive |
| --- | --- | --- |
| `corpus_documenti` | Un record per documento: provenienza, licenza, impronta, stato | WF01–WF03 creano; **tu** completi e approvi |
| `segnalazioni_sicurezza` | Problemi trovati da WF04 | WF04 crea; **tu** decidi |
| `entita` | Entità principali con identificativi (Wikidata, VIAF, GeoNames) | **tu** (anche con OpenRefine) |
| `correzioni_grafo` | Ogni correzione o conferma del grafo, motivata | **tu** |
| `interrogazioni` | Domande, risposte, contesto, modello e prompt | WF06 |
| `verifiche` | Affermazioni da verificare: passo, esito, errore | WF07 prepara; **l'esito lo scrivi tu** |
| `uso_ia` | Ogni chiamata a un modello | WF09 |

## Gli stati di un documento

`da_acquisire` → `acquisito` → (WF04) → `in_quarantena` oppure resta `acquisito` → **tu** scegli `approvato` o `escluso` → WF05 → `indicizzato`.

Nessun documento entra nel grafo senza che **tu** l'abbia portato ad `approvato`, compilando prima **licenza** e **motivazione_inclusione**.

3. Per approvare: apri il record, cambia **stato** in `approvato`, scrivi la motivazione.
   > [SCHERMATA: record con il campo stato aperto]
4. Per una segnalazione: leggi l'estratto (è "reso inerte": troncato e tra virgolette), scegli la **decisione** e scrivi la **motivazione**. Se decidi di mantenere un documento in quarantena, scrivi il perché e solo dopo portalo ad `approvato`.
5. Date incerte in `data_documento`: usa il formato EDTF, es. `1848-03?` (marzo 1848, incerto) o `184X` (anni Quaranta).

## Errori comuni

- **Ho cancellato un record per sbaglio:** NocoDB non ha il cestino. Usa l'ultimo Backup o ricrea il record.
- **Non vedo una colonna:** clic su *Fields* in alto e rendila visibile.

> **Domanda di riflessione.** Il registro del corpus rende visibile ciò che hai scelto di includere. Che cosa rende visibile di ciò che hai *escluso*, e dei silenzi dell'archivio?
