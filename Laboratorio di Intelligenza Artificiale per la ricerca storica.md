# Laboratorio di Intelligenza Artificiale per la ricerca storica

Programma del corso · Dipartimento di Studi Umanistici, Università Roma Tre · 10 novembre 2026

## Presentazione

Il laboratorio insegna a progettare un piccolo ambiente di ricerca storica assistita dall'IA: corpus esplicito, grafo di entità e relazioni documentato, risposte verificate, uso dell'IA dichiarato. Lo studente non si limita a interrogare un chatbot: costruisce e governa l'intero processo, dall'ingestione delle fonti alla verifica delle risposte.

| Voce | Valore |
| --- | --- |
| Tipologia | Laboratorio |
| Crediti | 6 CFU (150 ore di impegno complessivo dello studente) |
| Ore in aula | 40, in 20 lezioni da 2 ore |
| Approccio | No-code: strumenti visuali, nessuna programmazione richiesta; ambiente installato sul proprio portatile con un doppio clic |
| Prova finale | Idoneità: progetto individuale e discussione orale con dimostrazione |
| Destinatari | Studenti dei corsi del Dipartimento di Studi Umanistici |

**Competenza centrale.** Progettare un processo di ricerca assistita in cui la macchina estrae, collega e propone, mentre lo studioso seleziona le fonti, valida le relazioni, verifica le affermazioni e firma le conclusioni.

**Principi didattici**

- **Corpus esplicito.** Ogni documento ha provenienza, licenza, data di acquisizione e metadati registrati.
- **Grafo documentato.** Entità e relazioni si possono ispezionare, correggere e motivare; ogni correzione resta tracciata.
- **Risposte verificate.** Ogni affermazione prodotta dall'LLM rimanda a un passo del corpus e passa un controllo umano.
- **IA trasparente.** Modelli, versioni, prompt e parametri usati sono registrati e dichiarati nel progetto.
- **Teoria in laboratorio.** Ogni nodo concettuale (backpropagation, pareidolia semantica, sicurezza) ha un esercizio pratico.
- **Locale per impostazione predefinita.** Modelli leggeri girano sul portatile dello studente; i documenti non lasciano il computer senza una scelta consapevole e documentata.

## Obiettivi formativi

Al termine del laboratorio lo studente sa costruire, interrogare e valutare criticamente un ambiente GraphRAG su un corpus storico scelto da lui, e sa spiegare che cosa la macchina fa e che cosa non fa.

| Descrittore | Risultato atteso |
| --- | --- |
| Conoscenza e comprensione | Spiega come apprende una rete neurale (discesa del gradiente e backpropagation), come un modello linguistico genera testo e come funzionano RAG e GraphRAG. Conosce il dibattito tra la tesi della pareidolia semantica (Floridi) e quella delle macchine che comprendono in modo non umano (Cristianini). |
| Capacità di applicare | Costruisce con n8n un flusso che acquisisce fonti da cartelle locali, siti web e banche dati; indicizza il corpus in un grafo di conoscenza; interroga il grafo con un LLM locale. |
| Autonomia di giudizio | Riconosce allucinazioni, attribuzioni errate, anacronismi, distorsioni del corpus e tentativi di manipolazione (LLM grooming, istruzioni nascoste). Decide quando una risposta è accettabile e perché. |
| Abilità comunicative | Documenta corpus, schema del grafo, decisioni e verifiche; redige una dichiarazione d'uso dell'IA chiara e riproducibile. |
| Capacità di apprendimento | Trasferisce il metodo a nuovi corpora, domande e strumenti, distinguendo i principi stabili dagli strumenti che cambiano. |

## Ambiente di laboratorio

Ogni studente installa l'ambiente sul proprio portatile: i servizi girano in Docker, i modelli in Ollama installato come normale applicazione. n8n coordina il processo, LightRAG costruisce il grafo, NocoDB tiene i registri; i documenti non lasciano il computer.

**La macchina estrae e propone; lo studioso decide a ogni passaggio**

| Passaggio automatico (orchestrato da n8n) | Controllo dello studioso (tracciato in NocoDB) |
| --- | --- |
| 1 · Fonti: cartelle locali, siti web, banche dati e API | Seleziona e motiva le fonti — registro del corpus: provenienza e licenza |
| 2 · Ingestione (n8n + Apache Tika): testo, OCR e metadati Dublin Core | Controlla l'OCR a campione — registro del corpus: qualità del testo |
| 3 · Controllo e pulizia: testo nascosto, duplicati, segmentazione | Esamina i documenti segnalati — registro di sicurezza: esito e decisione |
| 4 · Grafo (LightRAG): entità e relazioni estratte da un modello leggero locale | Corregge e collega le entità — registro delle correzioni e riconciliazione |
| 5 · Interrogazione: recupero dal grafo e risposta con riferimenti | **Verifica ogni affermazione** — registro delle verifiche, uso dell'IA |

Se una verifica fallisce, lo studioso torna al passaggio che ha prodotto l'errore: la fonte, l'estrazione o la domanda.

| Componente | Dove gira | Ruolo nel processo | Che cosa vede lo studente |
| --- | --- | --- | --- |
| Pannello del laboratorio | Docker | Pagina iniziale con collegamenti e stato dei servizi | Una pagina nel browser con indicatori verdi o rossi |
| [n8n](https://github.com/n8n-io/n8n) (Community Edition) | Docker | Orchestrazione: ingestione, indicizzazione, interrogazione, registrazione | Editor visuale dei workflow |
| Apache Tika | Docker | Testo da PDF, Word e immagini, con OCR | Nulla: è richiamato da n8n |
| NocoDB | Docker | Registri: corpus, entità, interrogazioni, verifiche, uso dell'IA | Tabelle simili a un foglio di calcolo |
| [LightRAG Server](https://github.com/HKUDS/LightRAG) | Docker | Estrazione di entità e relazioni; recupero ibrido grafo + vettori | Interfaccia web: caricamento, grafo, interrogazione |
| Ollama | Applicazione nativa | LLM e modello di embedding | Icona nella barra di sistema |
| OpenRefine | Applicazione desktop | Pulizia dei metadati, riconciliazione con Wikidata | Interfaccia tipo foglio di calcolo |
| Neo4j Community | Docker, facoltativo | Esplorazione avanzata del grafo | Neo4j Browser, solo con 16 GB di RAM |

Ollama si installa come applicazione e non in Docker perché Docker su Mac non può usare la GPU Apple: un modello in container girerebbe solo sulla CPU, molto più lentamente ([fonte](https://bestllmfor.com/guides/ollama-docker-setup/)). n8n, NocoDB e LightRAG usano archivi su file, senza database server, per ridurre memoria e punti di guasto.

LightRAG è stato scelto perché il suo server offre già un'interfaccia web per indicizzare documenti, esplorare il grafo e porre domande, e dialoga con Ollama ([fonte](https://github.com/HKUDS/LightRAG)). Il docente mostra a confronto il [Neo4j LLM Knowledge Graph Builder](https://neo4j.com/labs/genai-ecosystem/llm-graph-builder/), che nasconde di più il processo.

### Modelli leggeri

Tutta la classe usa lo stesso modello di embedding, così il grafo dimostrativo preparato dal docente funziona su ogni portatile; il modello linguistico si sceglie in base alla RAM.

| Portatile | Modello linguistico | Embedding | Corpus consigliato |
| --- | --- | --- | --- |
| 16 GB di RAM o più | [Qwen3.5 4B](https://www.promptquorum.com/local-llms/small-local-llm-models) (`qwen3.5:4b`, circa 3,4 GB) | [EmbeddingGemma](https://huggingface.co/blog/embeddinggemma) (`embeddinggemma`, 308M parametri, oltre 100 lingue) | Fino a 40 documenti |
| 8 GB di RAM | Qwen3.5 2B (`qwen3.5:2b`) | EmbeddingGemma | Fino a 20 documenti |
| Meno di 8 GB, Chromebook, tablet | — | — | Postazione di dipartimento o portatile in prestito |

Alternative da provare in L3: Gemma 3 4B, forte sulle lingue, e Phi-4 mini. La scelta definitiva si fa con un test sul corpus dimostrativo prima dell'inizio del corso.

**Limiti da dichiarare agli studenti**

- I modelli da 2–4B estraggono entità e relazioni in modo meno affidabile dei modelli grandi; su documenti complessi possono restituirne poche o nessuna ([fonte](https://github.com/LeDat98/NexusRAG)). Il docente prepara quindi il grafo dimostrativo con un modello più grande, e in L11 gli studenti lo confrontano con il proprio.
- Con modelli piccoli vanno disattivati il ragionamento esteso (thinking) e ampliata la finestra di contesto rispetto ai 4.096 token predefiniti di Ollama, altrimenti l'estrazione fallisce per timeout ([fonte](https://github.com/av/harbor/wiki/2.3.93-Satellite-LightRAG)). Il kit lo imposta automaticamente.
- Sulla CPU di un portatile l'indicizzazione di un corpus può richiedere ore (stima da misurare nel test preliminare): si avvia a fine lezione e prosegue a casa.
- Un modello piccolo sbaglia di più e in modo più visibile. Per un corso che insegna a verificare è un vantaggio didattico, non solo un limite.

### Installazione senza competenze tecniche

Lo studente installa due programmi e avvia il laboratorio con un doppio clic, senza mai aprire il terminale.

1. Installa Docker Desktop. Su Windows servono WSL2 e la virtualizzazione attiva: se ne occupa lo sportello di installazione.
2. Installa Ollama dal sito ufficiale.
3. Scarica il kit del laboratorio e lo decomprime nella cartella Documenti.
4. Fa doppio clic su **Avvia laboratorio**: il programma controlla i prerequisiti, scarica immagini e modelli, prepara workflow e tabelle e apre il pannello nel browser.

I documenti si aggiungono trascinandoli nella cartella `LaboratorioIA/dati/inbox` con Esplora risorse o Finder. Altri comandi a doppio clic: **Ferma laboratorio**, **Diagnostica** (crea un rapporto da inviare al tutor), **Backup**. Immagini e modelli pesano circa 8–10 GB: si scaricano a casa prima di L1 o da chiavetta USB del dipartimento, per non saturare la rete dell'aula.

### Valutazione di n8n

**Verdetto: adottare n8n come orchestratore, non come motore GraphRAG.** Rende il processo di ricerca un diagramma leggibile, documentabile ed esportabile; il lavoro sul grafo resta a LightRAG.

| Aspetto | A favore | Attenzione |
| --- | --- | --- |
| Didattica | Il workflow è un diagramma del metodo; le note nel canvas documentano le scelte | È no-code, non no-logic: espressioni e struttura JSON degli item richiedono 2 lezioni di familiarizzazione |
| Costi e licenza | Community Edition self-hosted gratuita con [Sustainable Use License](https://www.promptquorum.com/power-local-llm/n8n-review) | Licenza fair-code, non open source in senso OSI; nessun limite rilevante per l'uso individuale |
| IA locale | Nodi AI Agent e Ollama Chat Model collegati all'Ollama del portatile | Con modelli da 2–4B l'estrazione è lenta e meno affidabile |
| Integrazione | Nodi per cartelle, HTTP, RSS, database; il nodo HTTP Request chiama l'API di LightRAG | Nessun nodo nativo per LightRAG: richieste HTTP preconfigurate nel kit |
| Riproducibilità | Workflow esportabili in JSON e consegnabili nel progetto | Interfaccia e nodi cambiano spesso: versioni fissate nel kit per tutto il semestre |
| Sicurezza | Esecuzione locale, servizi raggiungibili solo dal portatile stesso | Un agente con strumenti esterni è esposto a prompt injection: nei workflow didattici l'LLM non attiva azioni |

Alternative scartate: Zapier e Make (cloud, tariffati a operazione, dati fuori ateneo). Langflow e Flowise sono possibili, ma sono più centrati sulla catena LLM che sull'acquisizione documentale.

## Calendario delle lezioni

Le 20 lezioni seguono il percorso della ricerca: 5 per capire la macchina, 4 per il corpus, 5 per il grafo, 4 per interrogare e verificare, 2 per il progetto. Ogni lezione alterna circa 45 minuti di inquadramento e 75 minuti di laboratorio. Prima di L1 uno sportello di installazione di 2 ore, fuori dalle 40 ore, aiuta chi ha difficoltà con Docker.

### Modulo 1 · Capire la macchina (L1–L5)

| Lez. | Tema | Laboratorio | Consegna |
| --- | --- | --- | --- |
| L1 | L'IA nella ricerca umanistica; il patto del laboratorio: corpus esplicito, verifica, trasparenza | Verifica dell'installazione con il pannello del laboratorio (30 minuti). Stessa domanda storica posta al modello locale e confrontata con una fonte primaria: annotare differenze e vuoti | Diario di laboratorio avviato |
| L2 | Come apprende una rete neurale: percettrone, funzione di errore, discesa del gradiente, backpropagation | TensorFlow Playground; backpropagation svolta a mano in un foglio di calcolo su una rete minima | — |
| L3 | Dai neuroni ai modelli linguistici: token, embedding, attenzione, predizione del token successivo, temperatura | Tokenizzazione di un testo storico; mappa degli embedding; stessa domanda a temperature diverse e a modelli di taglia diversa nella chat di prova n8n | — |
| L4 | Seminario: pareidolia semantica (Floridi) e macchine che comprendono in modo non umano (Cristianini) | Dibattito a squadre; riscrittura di 5 risposte LLM da linguaggio mentalistico a linguaggio meccanicistico | Scheda di posizione, 1 pagina |
| L5 | Sicurezza e affidabilità: allucinazioni, LLM grooming, prompt injection indiretta in testi e immagini | Prova controllata su documenti predisposti con istruzioni-esca innocue (testo bianco, metadati, immagini); regole di igiene della pipeline | — |

### Modulo 2 · Costruire il corpus (L6–L9)

| Lez. | Tema | Laboratorio | Consegna |
| --- | --- | --- | --- |
| L6 | Dalla domanda di ricerca al corpus: selezione, silenzi dell'archivio, diritti, licenze, GDPR, metadati Dublin Core | Definire domanda e perimetro; creare il registro del corpus in NocoDB | Proposta di progetto |
| L7 | Documenti locali: PDF nativi e scansioni, OCR e suoi errori | Primo workflow n8n: cartella → Apache Tika → testo e metadati → registro. Introduzione a nodi, item, esecuzioni | — |
| L8 | Web e banche dati: pagine, feed, API (Wikidata, Europeana, Internet Archive); robots.txt e raccolta etica; provenienza dei domini | Workflow HTTP Request → estrazione del testo → controllo del dominio → registro | — |
| L9 | Pulizia e segmentazione: normalizzazione, duplicati, chunking come scelta interpretativa | OpenRefine sui metadati; workflow di normalizzazione con scansione del testo nascosto | **Checkpoint 1**: corpus documentato |

### Modulo 3 · Il grafo di conoscenza (L10–L14)

| Lez. | Tema | Laboratorio | Consegna |
| --- | --- | --- | --- |
| L10 | Grafi per la storia: entità, relazioni, ontologie (cenni a CIDOC CRM e Wikidata); schema minimo: Persona, Luogo, Organizzazione, Evento, Documento, Data | Annotazione manuale di 2 documenti e disegno del grafo di riferimento | Schema del grafo v1 |
| L11 | Estrazione automatica: come LightRAG ricava entità e relazioni; tipi di entità personalizzati | Esplorazione del grafo dimostrativo preparato dal docente con un modello grande; avvio dell'indicizzazione del proprio corpus con il modello leggero, da completare a casa; confronto con il grafo manuale (precisione e richiamo intuitivi) | — |
| L12 | Esplorare e correggere: duplicati, varianti onomastiche, relazioni spurie, anacronismi | Vista del grafo nell'interfaccia LightRAG (Neo4j Browser facoltativo con 16 GB di RAM); registro delle correzioni | — |
| L13 | Collegare il grafo: identificatori persistenti, date e toponimi storici | Riconciliazione delle entità principali con Wikidata, VIAF o GeoNames tramite OpenRefine | — |
| L14 | Revisione tra pari | Un collega verifica 10 relazioni a campione del grafo altrui e ne discute l'esito | **Checkpoint 2**: grafo documentato |

### Modulo 4 · Interrogare e verificare (L15–L18)

| Lez. | Tema | Laboratorio | Consegna |
| --- | --- | --- | --- |
| L15 | RAG e GraphRAG a confronto: modalità naive, local, global, hybrid | Workflow domanda → LightRAG → risposta con riferimenti → registro; stessa domanda nelle 4 modalità | — |
| L16 | Progettare le domande: fattuali, relazionali, comparative, interpretative; prompt che impone citazioni e dichiarazione d'incertezza | Batteria di 15 domande sul proprio corpus | Batteria di domande |
| L17 | Protocollo di verifica: scomporre la risposta in affermazioni, risalire al passo, classificare l'errore | Verifica della batteria nel registro NocoDB; tipologia: allucinazione, attribuzione errata, anacronismo, omissione, sovrainterpretazione, distorsione del corpus | — |
| L18 | Trasparenza e responsabilità: dichiarazione d'uso dell'IA, riproducibilità, alfabetizzazione IA (AI Act, art. 4), costo ambientale | Stesura della dichiarazione; prova di iniezione sul proprio ambiente | Dichiarazione d'uso dell'IA (bozza) |

### Modulo 5 · Progetto (L19–L20)

| Lez. | Tema | Laboratorio | Consegna |
| --- | --- | --- | --- |
| L19 | Clinica di progetto | Revisioni individuali di 10 minuti; lavoro guidato; prova di esportazione e backup del dossier | — |
| L20 | Presentazioni lampo e bilancio: che cosa abbiamo delegato alla macchina, che cosa no | Presentazione di 5 minuti per studente | Dossier finale all'appello |

## Progetto finale individuale

Il laboratorio si chiude con un giudizio di idoneità: è idoneo chi consegna un ambiente funzionante e documentato e dimostra di aver verificato le risposte con metodo. Non contano la quantità di dati né la bravura del modello, che su un portatile è per forza limitata.

**Requisiti minimi del corpus**: 15–40 documenti (fino a 20 con un portatile da 8 GB di RAM), da almeno due provenienze diverse (cartelle locali e web o banca dati), con diritti d'uso verificati.

**Contenuto del dossier**

1. Relazione di progetto (10.000–20.000 battute): domanda di ricerca, criteri del corpus, schema del grafo, decisioni prese, risultati, limiti.
2. Registro del corpus, esportato da NocoDB.
3. Schema del grafo e registro delle correzioni manuali, con motivazione per ciascuna.
4. Workflow n8n esportati in JSON, con note che spiegano ogni passaggio.
5. Registro delle interrogazioni: almeno 15 domande; per ognuna risposta, modalità di recupero, affermazioni verificate, fonte, esito, tipo di errore.
6. Dichiarazione d'uso dell'IA: modelli e versioni, prompt di sistema, parametri, che cosa è stato delegato e che cosa no.

**Discussione orale**: 15 minuti con dimostrazione dal vivo; il docente pone una domanda nuova al sistema e lo studente ne verifica la risposta davanti alla commissione.

**Requisiti per l'idoneità** (servono tutti)

| Componente | Requisito minimo |
| --- | --- |
| Corpus | Registro completo: provenienza, licenza e motivazione per ogni documento |
| Grafo | Schema dichiarato; almeno 20 correzioni o conferme motivate di entità e relazioni |
| Processo | Workflow WF01–WF06 eseguiti sul proprio corpus ed esportati con le note |
| Verifica | Almeno 15 domande; ogni risposta scomposta in affermazioni con esito e fonte; almeno 3 errori analizzati per tipo |
| Trasparenza | Dichiarazione d'uso dell'IA completa: modelli, prompt, parametri, che cosa è stato delegato |
| Discussione | Verifica dal vivo di una risposta nuova e spiegazione motivata di una scelta di metodo |

Se manca un requisito il giudizio è "non idoneo": la commissione indica le integrazioni e lo studente ripresenta il dossier a un appello successivo.

I tre checkpoint (corpus a L9, grafo a L14, batteria di domande a L16) ricevono un riscontro formativo senza voto e sono requisito per l'ammissione alla discussione.

**Esempi di temi** (disponibilità e diritti da verificare caso per caso)

- Carteggio di una figura del Risorgimento in edizione digitalizzata di pubblico dominio.
- Stampa periodica romana 1943–1944 da collezioni digitali.
- Verbali di un consiglio comunale del Lazio nel secondo dopoguerra.
- Lettere di emigranti italiani nelle Americhe.
- Inventario di un fondo archivistico familiare.
- Resoconti di viaggiatori stranieri a Roma nel Settecento (Internet Archive).

## Organizzazione

Il carico di 150 ore si divide in 40 ore in aula, circa 30 di studio e circa 80 di lavoro sul progetto; non servono competenze di programmazione.

| Attività | Ore |
| --- | --- |
| Lezioni-laboratorio in aula | 40 |
| Letture e schede di studio | 30 |
| Costruzione del corpus e del grafo | 45 |
| Verifica, dossier e preparazione della discussione | 35 |

**Prerequisiti**: uso corrente di computer e browser; inglese sufficiente a leggere documentazione tecnica di base.

**Requisiti tecnici**

- Portatile con Windows 10/11, macOS (preferibilmente Apple Silicon) o Linux; 16 GB di RAM consigliati, 8 GB minimo; 25 GB liberi su disco.
- Docker Desktop, gratuito per uso personale e didattico (verificare i termini di licenza correnti), e Ollama installato come applicazione.
- Connessione necessaria solo per il primo scaricamento e per l'ingestione dal web; per il resto il laboratorio funziona senza rete.
- Questionario sull'hardware all'iscrizione; postazioni di dipartimento o portatili in prestito per chi non ha un computer adatto.
- Uno sportello di installazione prima di L1 e un canale di assistenza (forum del corso), con il rapporto di diagnostica generato dal kit.
- Il docente prepara il kit con il file CLAUDE.md allegato e lo prova su almeno un Windows, un Mac e un portatile da 8 GB prima del corso.

**Diritti e dati personali**

- Estrazione di testo e dati a fini di ricerca: eccezione dell'art. 70-ter della legge 633/1941; licenze dei siti e delle banche dati da rispettare comunque.
- Niente dati personali di persone viventi senza una valutazione con il docente (GDPR).
- I documenti restano sul portatile dello studente; nessun invio a servizi esterni per impostazione predefinita. Il backup è responsabilità dello studente, con il comando Backup del kit.

**Questioni aperte**

- [ ] Esito del questionario sui portatili e numero di postazioni di riserva.
- [ ] Tutor disponibile per lo sportello di installazione.
- [ ] Chiavette USB con immagini e modelli per l'aula.
- [ ] Soglia di frequenza obbligatoria.

## Bibliografia e risorse

**Questioni concettuali**

- Floridi, L. (2026). [AI and Semantic Pareidolia: When We See Intelligent Consciousness where there is None](https://philarchive.org/rec/FLOAAS-4). *Philosophy & Technology*, 39(1), 36. Versione italiana originale in *Harvard Business Review Italia*, giugno 2025.
- Cristianini, N. (2023). *La scorciatoia. Come le macchine sono diventate intelligenti senza pensare in modo umano*. Il Mulino.
- Cristianini, N. (2024). *Machina sapiens. L'algoritmo che ci ha rubato il segreto della conoscenza*. Il Mulino.
- Cristianini, N. (2025). *Sovrumano. Oltre i limiti della nostra intelligenza*. Il Mulino.
- Bonasera, J. (2025). [Macchine e noi. Note sulla storia dell'intelligenza artificiale a partire da Nello Cristianini](https://storicamente.org/sites/default/images/articles/media/2325/bonasera_cristianini_intelligenza_artificiale.pdf). *Storicamente*, 21.
- Bender, E. M., Gebru, T., McMillan-Major, A., Shmitchell, S. (2021). On the Dangers of Stochastic Parrots. *FAccT '21*.

**Funzionamento dei modelli**

- Rumelhart, D. E., Hinton, G. E., Williams, R. J. (1986). Learning representations by back-propagating errors. *Nature*, 323, 533–536.
- Vaswani, A. et al. (2017). Attention Is All You Need. *NeurIPS*.
- Edge, D. et al. (2024). From Local to Global: A Graph RAG Approach to Query-Focused Summarization. arXiv:2404.16130.
- Guo, Z. et al. (2024). LightRAG: Simple and Fast Retrieval-Augmented Generation. arXiv:2410.05779.

**Sicurezza**

- NewsGuard (marzo 2025). [Rapporto sulla rete Pravda e l'LLM grooming](https://www.newsguardrealitycheck.com/p/a-well-funded-moscow-based-global).
- Greshake, K. et al. (2023). Not what you've signed up for: Compromising Real-World LLM-Integrated Applications with Indirect Prompt Injection. arXiv:2302.12173.
- Bagdasaryan, E. et al. (2023). [(Ab)using Images and Sounds for Indirect Instruction Injection in Multi-Modal LLMs](https://deepai.org/publication/ab-using-images-and-sounds-for-indirect-instruction-injection-in-multi-modal-llms).
- Cloud Security Alliance (2026). [Image-Based Prompt Injection in Multimodal LLMs](https://labs.cloudsecurityalliance.org/research/csa-research-note-image-prompt-injection-multimodal-llm-2026/).
- OWASP (2025). Top 10 for LLM Applications, voce LLM01 Prompt Injection.
- Regolamento (UE) 2024/1689 (AI Act), art. 4 sull'alfabetizzazione in materia di IA.

**Strumenti**

- [n8n](https://github.com/n8n-io/n8n) · [LightRAG](https://github.com/HKUDS/LightRAG) · [Neo4j LLM Knowledge Graph Builder](https://neo4j.com/labs/genai-ecosystem/llm-graph-builder/) · OpenRefine · Ollama · NocoDB · Apache Tika · Docker Desktop · TensorFlow Playground
