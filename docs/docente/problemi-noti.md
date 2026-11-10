# Problemi noti e punti da verificare

## Da verificare in fase 0–1 (non provati su hardware reale durante la scrittura del kit)

Il kit è stato scritto su un Mac con 4 GB liberi su disco: **lo stack completo non è stato avviato**.
Sono stati verificati: test statici (`make test`), servizio `controlli` sulle fixture, sintassi del
launcher bash con la bash 3.2 di macOS, validità di `compose.yml`. Restano da provare (fase 1):

1. **Creazione delle tabelle NocoDB** con l'API v2 (`init.js`): in particolare le colonne
   `CreatedTime`/`LastModifiedTime` con titolo `creato_il`/`modificato_il` accanto ai campi di
   sistema, e la colonna `id` di tipo `ID`.
2. **PATCH e DELETE dei record NocoDB** con chiave primaria `id` nel corpo (WF02, WF04, WF05, init).
3. **Import CLI di n8n** (`import:credentials`, `import:workflow --separate`) prima della creazione
   dell'account proprietario, e assegnazione dei workflow al proprietario creato dopo.
4. **Nodi Form** (WF00, WF06, WF07): pagina finale con *Form Ending* (`n8n-nodes-base.form`,
   `operation: completion`) dopo un Form Trigger v2.2.
5. **WF08**: `Merge` a 6 ingressi, `Aggregate` con `includeBinaries`, `Compression` con nomi di file
   contenenti cartelle (`registri/…`).
6. **Launcher Windows** (`kit/lib/laboratorio.ps1`): mai eseguito; verificare su Windows 11.
7. `GET /graphs?label=*` di LightRAG per l'esportazione dell'intero grafo.
8. Dimensione degli embedding (768) verificata dal launcher a ogni avvio.

## Linux: Ollama non raggiungibile dai container

Su Linux Ollama ascolta su `127.0.0.1`, che i container non raggiungono tramite
`host.docker.internal` (che punta all'interfaccia `docker0`). Soluzioni, da applicare allo sportello:
far ascoltare Ollama anche sull'indirizzo del bridge Docker con un override di systemd
(`Environment="OLLAMA_HOST=172.17.0.1:11434"`, poi aggiornare `OLLAMA` nel launcher), oppure usare
Docker Desktop per Linux, che si comporta come su Mac e Windows. Da decidere in un ADR dopo la prova
su Ubuntu.

## macOS: Gatekeeper

I file `.command` scaricati sono in quarantena: serve "tasto destro → Apri" (scheda 03). Il kit
è distribuito come zip che conserva i permessi di esecuzione (`zip -y` da `make kit`). In alternativa,
dopo la decompressione: `xattr -dr com.apple.quarantine LaboratorioIA` (solo docente/sportello).

## Windows: percorsi con OneDrive

Se *Documenti* è sincronizzata con OneDrive, la cartella `dati` può essere "solo online" e i bind
mount di Docker falliscono. Consigliare di disattivare la sincronizzazione per `LaboratorioIA`.
