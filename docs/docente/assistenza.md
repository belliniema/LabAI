# Assistenza e sportello

## Leggere un file di Diagnostica

| File | Che cosa guardare |
| --- | --- |
| `salute.txt` | codici HTTP dei servizi tramite il pannello (200 = acceso, 502 = spento) |
| `compose-ps.txt` | servizi in esecuzione, riavvii continui (`Restarting`) |
| `init.json` | esito della prima configurazione e messaggio d'errore |
| `launcher.log` | ultimo passo riuscito del launcher |
| `log/<servizio>.txt` | ultime 500 righe; per la memoria cercare `OOMKilled` o `Killed` |
| `docker-info.txt` | `Total Memory` assegnata a Docker |
| `ollama.txt` | modelli presenti, compresi `lab-estrazione` e `lab-risposta` |

## Casi frequenti

| Sintomo | Causa | Rimedio |
| --- | --- | --- |
| `init` in errore su NocoDB | primo avvio interrotto | rilanciare Avvia laboratorio: init è idempotente |
| LightRAG risponde ma l'indicizzazione fallisce subito | Ollama non raggiungibile dai container | vedi problemi noti (Linux) |
| `lightrag` riavvia in continuazione | memoria | profilo leggero; chiudere altri programmi |
| Workflow con credenziali mancanti | import credenziali fallito | rilanciare; in ultima istanza ricrearle in n8n con i valori di `CREDENZIALI.txt` |

## Ripristino da backup

Su un computer con il kit installato e avviato almeno una volta:

```bash
cd LaboratorioIA
# 1. ferma i servizi (doppio clic su Ferma laboratorio)
# 2. ripristina i segreti: senza la stessa N8N_ENCRYPTION_KEY le credenziali n8n non si aprono
cp dati/dossier/backup/backup-<data>/segreti.env .env
# 3. ripristina ogni volume
for v in n8n_data nocodb_data lightrag_data lightrag_inputs; do
  docker volume create laboratorio-ia_$v
  docker run --rm -v laboratorio-ia_$v:/volume -v "$PWD/dati/dossier/backup/backup-<data>:/backup:ro" \
    --entrypoint sh caddy:2.11.9-alpine -c "rm -rf /volume/* && tar -xzf /backup/$v.tar.gz -C /volume"
done
# 4. ripristina la cartella dati se serve: tar -xzf …/dati.tar.gz -C dati
# 5. doppio clic su Avvia laboratorio
```

Il ripristino si fa allo sportello con il tutor: richiede il terminale.
