# ADR-002 · Modelli linguistici e di embedding

- Stato: proposto — **le misure della tabella vanno compilate in fase 0** con
  `scripts/confronta_modelli.sh` su un portatile di riferimento
- Data: 2026-11-10

## Decisione provvisoria

| Profilo | LLM (tag Ollama) | Embedding | Contesto | Concorrenza LightRAG | Gleaning |
| --- | --- | --- | --- | --- | --- |
| `standard` (≥ 16 GB) | `qwen3.5:4b` | `embeddinggemma:300m` | 16384 | 2 | 1 |
| `leggero` (8–15 GB) | `qwen3.5:2b` | `embeddinggemma:300m` | 8192 | 1 | 0 |

Tag verificati sulla pagina `ollama.com/library/qwen3.5/tags` e
`ollama.com/library/embeddinggemma/tags` (10/11/2026). Si usa `embeddinggemma:300m` invece di
`embeddinggemma` (alias di `latest`) per non dipendere da un tag mobile.

### Dimensione dell'embedding

`EMBEDDING_DIM=768` (dimensione nativa di EmbeddingGemma). Il launcher la **verifica** a ogni
avvio con una chiamata `POST /api/embed` e si ferma con un messaggio chiaro se Ollama restituisce
un'altra dimensione. `EMBEDDING_TOKEN_LIMIT=2048` e `OLLAMA_EMBEDDING_NUM_CTX=2048`: è il
contesto di EmbeddingGemma; i chunk di LightRAG (≤ 1200 token) ci stanno.

### Modelli derivati

Il launcher crea con `ollama create` (Modelfile generato da `config/Modelfile.*.tmpl`):

- `lab-estrazione` — `FROM <llm del profilo>`, `PARAMETER num_ctx <contesto>`,
  `PARAMETER temperature 0.1`;
- `lab-risposta` — `FROM <llm del profilo>`, `PARAMETER num_ctx <contesto>`,
  `PARAMETER temperature 0.3`.

### Ragionamento esteso disattivato

Il Modelfile non ha un parametro per il thinking: si disattiva per richiesta. LightRAG v1.5.7
espone `OLLAMA_LLM_THINK`, `EXTRACT_OLLAMA_LLM_THINK`, `KEYWORD_OLLAMA_LLM_THINK`
(`env.example`, sezione "Ollama Specific Parameters", con il riferimento all'issue #3597 sulle
estrazioni vuote dei modelli con thinking). Il kit li imposta tutti a `false`. I workflow n8n che
chiamano Ollama direttamente (WF00, WF07) inviano `"think": false`.

Test di accettazione: `scripts/test_thinking.sh` invia a `lab-estrazione` un testo di prova e
fallisce se la risposta contiene `<think>` o il campo `thinking` non vuoto.

## Misure da compilare (fase 0)

5 documenti italiani del corpus demo, stesso prompt di estrazione di LightRAG.

| Modello | Entità corrette / attese | Relazioni corrette / attese | Tempo per documento | RAM di picco | Note |
| --- | --- | --- | --- | --- | --- |
| `qwen3.5:4b` | | | | | |
| `qwen3.5:2b` | | | | | |
| `gemma3:4b` | | | | | |
| `phi4-mini` | | | | | |

## Conseguenze

Cambiare embedding obbliga a cancellare e rifare tutti gli indici, compreso il grafo demo.
