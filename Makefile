# Comandi del docente (CLAUDE.md §12). Gli studenti non usano mai questo file.
#   make test              test senza Docker: controlli, workflow, segreti, sintassi, compose
#   make test-integrazione test con lo stack avviato (fixture con Tika, porte, golden questions)
#   make kit               zip versionato del kit in dist/
#   make offline           cartella per la chiavetta USB (immagini Docker + modelli Ollama)
#   make demo-graph        costruisce il grafo demo con un modello grande (stesso embedding)
#   make check-secrets     nessun segreto nel repository o nei workflow
#   make workflows         rigenera i JSON dei workflow da scripts/genera_workflows.py
#   make fixtures          rigenera le fixture di sicurezza

SHELL := /bin/bash
VERSIONE := $(shell sed -n 's/^KIT_VERSION=//p' kit/config/modelli.env)
NOME_KIT := LaboratorioIA
BUILD := build
DIST := dist
DOCKER ?= $(shell command -v docker || echo /Applications/Docker.app/Contents/Resources/bin/docker)
PYTHON ?= python3

.PHONY: test test-integrazione kit offline demo-graph check-secrets workflows fixtures schede clean

test: check-secrets
	node tests/controlli.test.js
	$(PYTHON) tests/test_workflows.py
	$(PYTHON) tests/test_kit.py
	bash -n kit/lib/laboratorio.sh
	@for f in kit/*.command kit/*.sh scripts/*.sh; do bash -n "$$f" || exit 1; done
	@if command -v shellcheck >/dev/null; then shellcheck -S warning kit/lib/laboratorio.sh scripts/*.sh; else echo "shellcheck non installato: controllo saltato"; fi
	@if command -v pwsh >/dev/null; then pwsh -NoProfile -Command "\$$e=\$$null; [void][System.Management.Automation.Language.Parser]::ParseFile('kit/lib/laboratorio.ps1',[ref]\$$null,[ref]\$$e); if(\$$e){\$$e; exit 1}"; else echo "pwsh non installato: sintassi PowerShell non verificata"; fi
	@cd kit && N8N_ENCRYPTION_KEY=x NC_ADMIN_EMAIL=a@b.it NC_ADMIN_PASSWORD=x NC_AUTH_JWT_SECRET=x LIGHTRAG_API_KEY=x LIGHTRAG_DEMO_API_KEY=x NEO4J_PASSWORD=x \
	  $(DOCKER) compose -f compose.yml --profile avanzato --profile scansioni config -q && echo "ok   compose.yml valido"

test-integrazione:
	bash scripts/test_integrazione.sh

check-secrets:
	bash scripts/check_secrets.sh

workflows:
	$(PYTHON) scripts/genera_workflows.py

fixtures:
	$(PYTHON) scripts/genera_fixtures.py

schede:
	$(PYTHON) scripts/schede_html.py docs/schede kit/pannello/schede

kit: test schede
	rm -rf $(BUILD)/$(NOME_KIT) && mkdir -p $(BUILD)/$(NOME_KIT) $(DIST)
	rsync -a --exclude '.env' --exclude '.stato' --exclude 'dati' --exclude 'offline' --exclude '.DS_Store' kit/ $(BUILD)/$(NOME_KIT)/
	mkdir -p $(BUILD)/$(NOME_KIT)/dati/{inbox,testi,dossier} $(BUILD)/$(NOME_KIT)/.stato
	cp samples/security_fixtures/*.{pdf,docx,html,txt,png} $(BUILD)/$(NOME_KIT)/demo/ 2>/dev/null; mkdir -p $(BUILD)/$(NOME_KIT)/demo/fixture-sicurezza && mv $(BUILD)/$(NOME_KIT)/demo/*.{pdf,docx,html,png} $(BUILD)/$(NOME_KIT)/demo/testo_*.txt $(BUILD)/$(NOME_KIT)/demo/fixture-sicurezza/ 2>/dev/null || true
	@test -f docs/LEGGIMI.pdf && cp docs/LEGGIMI.pdf $(BUILD)/$(NOME_KIT)/ || echo "ATTENZIONE: manca docs/LEGGIMI.pdf (esporta docs/LEGGIMI.md in PDF prima della distribuzione)"
	bash scripts/check_secrets.sh $(BUILD)/$(NOME_KIT)
	# zip conserva i permessi di esecuzione dei file .command e .sh (CLAUDE.md §5)
	cd $(BUILD) && rm -f ../$(DIST)/$(NOME_KIT)-$(VERSIONE).zip && zip -qry ../$(DIST)/$(NOME_KIT)-$(VERSIONE).zip $(NOME_KIT)
	@echo "Kit pronto: $(DIST)/$(NOME_KIT)-$(VERSIONE).zip"

offline:
	bash scripts/pacchetto_offline.sh $(BUILD)/offline

demo-graph:
	bash scripts/costruisci_grafo_demo.sh

clean:
	rm -rf $(BUILD) $(DIST)
