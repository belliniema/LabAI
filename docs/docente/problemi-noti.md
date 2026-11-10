# Problemi noti e punti da verificare

## Verificato il 2026-11-10 (Mac Apple Silicon, 24 GB, profilo `leggero`, Ollama 0.40.13)

Launcher fino al pannello verde, init completo, tutti i controlli di salute a 200, porte solo su
`127.0.0.1`, `make test-integrazione` superato (8/8 fixture con Tika, thinking spento), un documento
demo indicizzato nel grafo personale in 20 s con `qwen3.5:2b` e interrogato con riferimenti.
Corretti durante la prova:

- **NocoDB va in *heap out of memory*** con `--max-old-space-size=320`: ora 480 MB di heap e
  `mem_limit` 640 MB (ADR-001). Consumo reale a riposo dello stack: circa 2,1 GB.
- **Chiave primaria dei record NocoDB**: l'API v2 la restituisce come `Id` (non `id`) e
  `sort=id` dà `ERR_FIELD_NOT_FOUND`. PATCH e DELETE accettano `id` o `Id` nel corpo. Corretti
  WF02, WF04, WF05. NocoDB aggiunge da sé i campi di sistema `CreatedAt`/`UpdatedAt` accanto a
  `creato_il`/`modificato_il` (ridondanti ma innocui).
- **OCR delle immagini**: Tesseract non legge righe minuscole grigio chiaro, nemmeno con le
  opzioni di preelaborazione di Tika. Il servizio `controlli` fa un secondo passaggio OCR su una
  copia del PNG con contrasto aumentato (solo PNG a 8 bit; JPEG e altri formati solo OCR normale).
- **Download dei modelli**: Ollama può interrompersi con `download stalled`; il launcher ora
  riprova fino a 3 volte (il download riprende da dove si era fermato).
- **Spazio su disco**: i 15 GB sono richiesti solo se mancano immagini Docker da scaricare.

## Ancora da verificare

1. **Import CLI di n8n** prima della creazione dell'account proprietario: l'import riesce;
   resta da controllare che i workflow compaiano al proprietario creato dopo, dal browser.
2. **Esecuzione dei workflow dall'editor** (WF00–WF09) sul corpus demo modificando solo
   `PARAMETRI`, in particolare i nodi Form (WF00, WF06, WF07) e WF08 (Merge a 6 ingressi,
   Aggregate con binari, Compression con cartelle).
3. **Aggiornamento del kit**: init gira una sola volta (marcatore `.laboratorio-init-v1`); una
   nuova versione dei workflow richiede di incrementare la versione del marcatore o un comando
   di aggiornamento. Nella prova i workflow corretti sono stati reimportati cancellando il
   marcatore e rieseguendo init (idempotente: riusa tabelle e token).
4. **Launcher Windows** (`kit/lib/laboratorio.ps1`): mai eseguito; verificare su Windows 11.
5. **Grafo demo** (`make demo-graph`) e golden questions: non ancora costruito.

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
