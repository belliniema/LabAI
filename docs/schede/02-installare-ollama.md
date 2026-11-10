# 02 · Installare Ollama

**Obiettivo.** Installare Ollama, il programma che fa girare i modelli linguistici sul tuo computer. Un *modello linguistico* è un programma che, dato un testo, prevede le parole successive: è il "motore" che estrae entità e scrive risposte.

1. Scarica Ollama dal sito ufficiale (ollama.com) per il tuo sistema.
   > [SCHERMATA: pagina di download]
2. **Windows:** fai doppio clic sul file e segui l'installazione. **Mac:** apri il file, trascina Ollama in Applicazioni e aprilo.
3. Controlla che vicino all'orologio (Windows) o nella barra in alto (Mac) compaia l'icona del **lama**.
   > [SCHERMATA: icona del lama nella barra]
4. Non devi scaricare modelli a mano: lo fa **Avvia laboratorio**, scegliendo quelli adatti alla memoria del tuo computer.

**Perché Ollama non è dentro Docker?** Sul Mac, Docker non può usare la scheda grafica del chip Apple: un modello dentro Docker sarebbe molto più lento. Come applicazione normale, Ollama la usa.

## Errori comuni

| Problema | Che cosa fare |
| --- | --- |
| Il lama non compare | Apri Ollama da Applicazioni o dal menu Start. |
| *Ollama non è avviato* nel launcher | Apri Ollama, attendi 10 secondi, rifai doppio clic su Avvia laboratorio. |
| Disco quasi pieno | I modelli pesano 3–5 GB: libera spazio prima del primo avvio. |

> **Domanda di riflessione.** Il modello gira sul tuo portatile e non vede internet. Da dove viene allora quello che "sa"? E che cosa non può sapere?
