# 03 · Primo avvio, Gatekeeper e pannello

**Obiettivo.** Avviare il laboratorio con un doppio clic, superare il blocco di sicurezza del Mac la prima volta, aprire il pannello e creare l'account di n8n.

## Prima di iniziare

- Docker Desktop è aperto (scheda 01) e Ollama è aperto (scheda 02).
- Hai decompresso il kit nella cartella **Documenti**: dentro `Documenti/LaboratorioIA` vedi i file *Avvia laboratorio*, *Ferma laboratorio*, *Diagnostica*, *Backup*.
- Il primo avvio scarica circa 8–10 GB: fallo a casa, collegato alla corrente, oppure usa la **chiavetta del dipartimento** (copia la cartella `offline` dentro `LaboratorioIA`).

## Passi

1. Fai doppio clic su **Avvia laboratorio** (`.bat` su Windows, `.command` su Mac, `avvia-laboratorio.sh` su Linux).
2. **Solo Mac, solo la prima volta:** compare l'avviso *"non può essere aperto perché proviene da uno sviluppatore non identificato"*. Chiudilo, poi fai **clic con il tasto destro** (o ctrl+clic) sul file → **Apri** → **Apri**. Ripeti per *Ferma laboratorio*, *Diagnostica*, *Backup*. Se il pulsante "Apri" non compare: Impostazioni di Sistema → Privacy e sicurezza → in fondo, **Apri comunque**.
   > [SCHERMATA: menu del tasto destro con "Apri"]
   > [SCHERMATA: Privacy e sicurezza con "Apri comunque"]
3. Si apre una finestra con dei passaggi: **▶ Controllo Docker**, **▶ Controllo Ollama**, ecc. Ogni ✔ verde è un passaggio riuscito. Non chiudere la finestra.
   > [SCHERMATA: finestra del launcher con i passaggi]
4. Alla fine si apre il browser su **http://localhost:8000**: è il **pannello del laboratorio**. Ogni riquadro ha un indicatore: verde = acceso, rosso = non risponde.
   > [SCHERMATA: pannello con tutti gli indicatori verdi]
5. Apri **n8n** dal pannello. La prima volta n8n chiede di **creare l'account proprietario**: nome, email (anche inventata, es. `nome@laboratorio.local`) e una password che ricordi. Resta solo sul tuo computer.
   > [SCHERMATA: schermata "Set up owner account" di n8n]
6. Nella cartella `LaboratorioIA/dati` trovi **CREDENZIALI.txt** con email e password di NocoDB e le chiavi di LightRAG. Non condividerlo.

Il laboratorio resta acceso finché non fai doppio clic su **Ferma laboratorio**. Se spegni il computer senza fermarlo, al riavvio Docker lo riavvia da solo.

## Errori comuni

| Messaggio | Che cosa fare |
| --- | --- |
| *Docker non è avviato* | Apri Docker Desktop, attendi la balena ferma, rifai doppio clic. |
| *La porta 8080 è già usata* | Un altro programma usa quella porta: chiudi altri programmi di sviluppo o riavvia il computer. |
| *Sul disco restano solo … GB* | Libera spazio: servono 15 GB al primo avvio. |
| Un riquadro resta rosso | Attendi un minuto e ricarica la pagina. Se resta rosso, rifai doppio clic su Avvia laboratorio; poi **Diagnostica**. |

> **Domanda di riflessione.** Il pannello mostra il modello e il profilo scelti per il tuo computer. Perché è importante, per la riproducibilità della tua ricerca, sapere esattamente quale modello hai usato?
