# 08 · Backup e Diagnostica

**Obiettivo.** Mettere al sicuro il lavoro e chiedere aiuto in modo efficace.

## Backup

1. Fai doppio clic su **Backup**. Il laboratorio si ferma per qualche minuto, copia registri, workflow, grafo e la cartella `dati`, poi riparte.
2. Il backup è in `dati/dossier/backup/backup-<data>`.
3. **Copia quella cartella fuori dal computer** (disco esterno o cloud di ateneo): un backup sullo stesso disco non protegge da un guasto.
4. Il backup contiene `segreti.env` (le tue chiavi locali): tienilo privato.

Fai un backup almeno a ogni checkpoint (L9, L14, L16) e prima dell'appello. Consiglio: attiva la cifratura del disco (BitLocker su Windows, FileVault su Mac).

**Ripristino** (su un computer nuovo o dopo un guasto): porta la cartella del backup allo sportello o segui con il tutor `docs/docente/assistenza.md`.

## Diagnostica

1. Fai doppio clic su **Diagnostica**.
2. Sul Desktop compare **Diagnostica-<data>.zip**: contiene versioni, stato dei servizi e messaggi di errore, **senza password né chiavi** (vengono sostituite da `[RIMOSSO]`).
3. Allegalo nel forum del corso con una frase su che cosa stavi facendo.

> **Domanda di riflessione.** La riproducibilità di un progetto dipende anche dalla conservazione dei dati. Che cosa resterebbe verificabile del tuo lavoro se perdessi il computer domani?
