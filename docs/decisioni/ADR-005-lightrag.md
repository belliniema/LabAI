# ADR-005 · Configurazione di LightRAG v1.5.7 e grafo demo

- Stato: accettato
- Data: 2026-11-10

Fonti: `env.example`, `lightrag/lightrag.py`, `lightrag/api/routers/*.py`,
`docker-entrypoint.sh` del tag `v1.5.7`.

## Opzioni impostate (CLAUDE.md §4.1)

| Requisito | Variabile v1.5.7 | `leggero` | `standard` |
| --- | --- | --- | --- |
| un lavoro LLM alla volta | `MAX_ASYNC_LLM`, `EXTRACT_MAX_ASYNC_LLM`, `KEYWORD_MAX_ASYNC_LLM`, `QUERY_MAX_ASYNC_LLM` | 1 | 2 |
| un documento alla volta | `MAX_PARALLEL_INSERT` | 1 | 1 |
| timeout aumentato | `LLM_TIMEOUT` (secondi) | 1200 | 900 |
| niente gleaning | `MAX_GLEANING` (`entity_extract_max_gleaning`, predefinito 1) | 0 | 1 |
| descrizioni in italiano | `SUMMARY_LANGUAGE` | Italian | Italian |
| tipi di entità | `ENTITY_TYPE_PROMPT_FILE=entity_type_storico.yml`, letto da `PROMPT_DIR/entity_type/` | sì | sì |
| contesto | `OLLAMA_LLM_NUM_CTX` (deve superare `MAX_TOTAL_TOKENS` + 2000) | 8192 | 16384 |
| budget di contesto per la risposta | `MAX_TOTAL_TOKENS` / `MAX_ENTITY_TOKENS` / `MAX_RELATION_TOKENS` | 6000 / 2000 / 2500 | 12000 / 4000 / 5000 |
| ingresso massimo all'estrazione | `MAX_EXTRACT_INPUT_TOKENS` | 6000 | 12000 |
| thinking spento | `OLLAMA_LLM_THINK`, `EXTRACT_OLLAMA_LLM_THINK`, `KEYWORD_OLLAMA_LLM_THINK` | false | false |
| modelli per ruolo | `LLM_MODEL` / `EXTRACT_LLM_MODEL` / `QUERY_LLM_MODEL` | `lab-risposta` / `lab-estrazione` / `lab-risposta` | idem |

I tipi di entità sono nel file YAML `kit/config/lightrag-prompts/entity_type/entity_type_storico.yml`
(chiave `entity_types_guidance` ed esempi `entity_extraction_json_examples`, come nel campione
`prompts/samples/entity_type_prompt.sample.yml`, perché `ENTITY_EXTRACTION_USE_JSON=true`).

## API usate dai workflow (verificate su `/docs` e nei router)

| Uso | Chiamata |
| --- | --- |
| inserire un testo | `POST /documents/text` `{text, file_source}` → `{status, message, track_id}` |
| stato dell'indicizzazione | `GET /documents/track_status/{track_id}` → `documents[].status` (`pending`, `parsing`, `analyzing`, `processing`, `processed`, `failed`) |
| domanda | `POST /query` `{query, mode, include_references: true, include_chunk_content: true, user_prompt}` → `{response, references[{reference_id, file_path, content[]}]}` |
| contesto recuperato | incluso in `references[].content` con `include_chunk_content`: **una sola chiamata** basta |
| salute | `GET /health` (sempre raggiungibile) |
| grafo per l'esportazione | `GET /graphs?label=*&max_depth=…&max_nodes=…` |

`file_source` è `<doc_id>.txt`: così ogni riferimento restituito porta il `doc_id`.

## Grafo demo in sola lettura

LightRAG non ha una modalità di sola lettura e scrive file di stato nella cartella di lavoro.
Il servizio `lightrag-demo`:

- monta `kit/demo/grafo/` in sola lettura su `/demo-ro`;
- all'avvio copia il grafo in un `tmpfs` (64 MB) che fa da cartella di lavoro;
- qualsiasi modifica fatta dall'interfaccia sparisce al riavvio: il grafo demo torna sempre
  quello distribuito dal docente;
- ha una chiave API propria.

Il grafo demo si costruisce con `make demo-graph` (modello grande, **stesso embedding**).

## Conseguenze

- Una domanda al grafo demo funziona solo se il grafo è stato costruito e copiato in
  `kit/demo/grafo/` prima di `make kit`. Il pannello mostra "grafo demo non installato" se la
  cartella è vuota.
