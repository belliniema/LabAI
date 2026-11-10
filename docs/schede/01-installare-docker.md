# 01 · Installare Docker Desktop

**Obiettivo.** Installare Docker Desktop, il programma che fa girare i "contenitori" del laboratorio. Un *contenitore* è un piccolo computer virtuale già configurato: tu non lo vedi, ma dentro gira, per esempio, n8n.

**Tempo:** 20–40 minuti, più il riavvio. **Serve:** connessione a internet, 25 GB liberi sul disco.

## Windows 10/11

1. Apri il sito ufficiale di Docker e scarica **Docker Desktop for Windows** (versione AMD64; se il tuo portatile ha un processore Snapdragon scegli ARM64).
   > [SCHERMATA: pagina di download con il pulsante evidenziato]
2. Fai doppio clic sul file scaricato. Lascia selezionata l'opzione **Use WSL 2 instead of Hyper-V**. *WSL2* è un componente di Windows che permette di far girare Linux: Docker lo usa per i contenitori.
   > [SCHERMATA: finestra di installazione con la casella WSL 2]
3. Al termine, riavvia il computer.
4. Apri Docker Desktop dal menu Start. Accetta le condizioni d'uso (gratuito per uso personale e didattico). Puoi saltare la registrazione.
5. Attendi che in basso a sinistra compaia **Engine running** in verde.
   > [SCHERMATA: Docker Desktop con "Engine running"]

### Errori comuni (Windows)

| Messaggio | Che cosa fare |
| --- | --- |
| *Virtualization must be enabled* / *Hardware assisted virtualization* | La virtualizzazione è spenta nel BIOS. Vieni allo **sportello di installazione**: la accendiamo insieme (il nome cambia per marca: Intel VT-x, AMD-V, SVM). |
| *WSL 2 installation is incomplete* | Segui il link del messaggio, installa l'aggiornamento di WSL, riavvia. |
| Docker resta su *Starting…* per più di 5 minuti | Riavvia il computer. Se non basta, porta il portatile allo sportello. |

## macOS

1. Scarica **Docker Desktop for Mac**: scegli **Apple Silicon** se nel menu  → Informazioni su questo Mac leggi "Chip Apple M…", altrimenti **Intel**.
   > [SCHERMATA: Informazioni su questo Mac con il chip evidenziato]
2. Apri il file `.dmg` e trascina la balena nella cartella Applicazioni.
3. Apri Docker da Applicazioni, conferma le autorizzazioni richieste, accetta le condizioni.
4. Attendi che la **balena** nella barra in alto resti ferma (quando si muove, Docker si sta avviando).
   > [SCHERMATA: barra dei menu con l'icona della balena]

### Memoria assegnata a Docker

Il laboratorio chiede almeno 4 GB a Docker. Su Mac: Docker Desktop → **Settings** → **Resources** → *Memory limit* almeno 4 GB → **Apply & restart**. Su Windows con WSL2 la memoria si adatta da sola.

> **Domanda di riflessione.** Il laboratorio installa i servizi sul tuo computer invece di usarli "nel cloud". Che cosa guadagni e che cosa perdi, per i tuoi documenti e per la tua ricerca?
