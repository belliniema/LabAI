# Launcher del Laboratorio di IA per la ricerca storica — Windows (CLAUDE.md §5).
# Lo studente non lo apre mai: lo richiamano i file .bat a doppio clic.
# Stessa logica di lib/laboratorio.sh (macOS e Linux): tenere i due file allineati.
# Il file è salvato in UTF-8 con BOM, necessario a Windows PowerShell 5.1 per le lettere accentate.
param([Parameter(Mandatory = $true)][ValidateSet('avvia', 'ferma', 'diagnostica', 'backup')][string]$Comando)

# 'Continue': in PowerShell 5.1 con 'Stop' le righe di avanzamento che docker scrive su stderr
# diventerebbero errori bloccanti. Gli errori dei cmdlet si gestiscono con try/catch.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Kit = Split-Path -Parent $PSScriptRoot
$Stato = Join-Path $Kit '.stato'
$Dati = Join-Path $Kit 'dati'
$Ollama = 'http://127.0.0.1:11434'
$Pannello = 'http://localhost:8000'
$Porte = 8000, 5678, 8080, 9621, 9622
$ServiziSalute = 'nocodb', 'lightrag', 'lightrag-demo', 'tika', 'controlli', 'n8n', 'ollama'
$TuttiIProfili = '--profile', 'avanzato', '--profile', 'scansioni'
$ProfiliCompose = @()   # profili facoltativi attivi in questo avvio (Scegli-Facoltativi)
$DoclingAttivo = $false
$DoclingAvviso = ''
$ImmagineAttrezzi = 'caddy:2.11.9-alpine'
New-Item -ItemType Directory -Force -Path $Stato | Out-Null
$Log = Join-Path $Stato 'launcher.log'

# config/modelli.env → variabili
$M = @{}
Get-Content (Join-Path $Kit 'config\modelli.env') | Where-Object { $_ -match '^\s*([A-Z0-9_]+)=(.*)$' } | ForEach-Object {
    $null = $_ -match '^\s*([A-Z0-9_]+)=(.*)$'; $M[$Matches[1]] = $Matches[2].Trim()
}

# ---------------------------------------------------------------------------
# Messaggi
# ---------------------------------------------------------------------------
function Registra($t) { Add-Content -Path $Log -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $t) -Encoding UTF8 }
function Passo($t) { Write-Host ''; Write-Host "▶ $t" -ForegroundColor White; Registra "PASSO $t" }
function Ok($t) { Write-Host "  ✔ $t" -ForegroundColor Green; Registra "OK $t" }
function Avviso($t) { Write-Host "  ! $t" -ForegroundColor Yellow; Registra "AVVISO $t" }
function Attendi-Invio { Write-Host ''; Read-Host 'Premi Invio per chiudere questa finestra' | Out-Null }
function Fallisci($cosa, $rimedio) {
    Registra "ERRORE $cosa | $rimedio"
    Write-Host ''
    Write-Host "✖ $cosa" -ForegroundColor Red
    Write-Host ''
    Write-Host "Che cosa fare: $rimedio"
    Write-Host ''
    Write-Host 'Se il problema resta, fai doppio clic su «Diagnostica» e allega il file creato sul Desktop nel forum del corso.'
    Attendi-Invio
    exit 1
}

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------
function Trova-Docker {
    $c = Get-Command docker.exe -ErrorAction SilentlyContinue
    if ($c) { $script:Docker = $c.Source; return $true }
    $p = Join-Path $Env:ProgramFiles 'Docker\Docker\resources\bin\docker.exe'
    if (Test-Path $p) { $script:Docker = $p; $Env:Path = (Split-Path $p) + ';' + $Env:Path; return $true }
    return $false
}
function Docker-Attivo { & $script:Docker info *> $null; return ($LASTEXITCODE -eq 0) }
function Compose { & $script:Docker compose --project-directory $Kit -f (Join-Path $Kit 'compose.yml') @args }

function Controlla-Docker {
    Passo 'Controllo Docker'
    if (-not (Trova-Docker)) {
        Fallisci 'Docker Desktop non è installato.' 'Installa Docker Desktop seguendo la scheda «01 · Installare Docker Desktop» (servono WSL2 e la virtualizzazione attiva), poi fai di nuovo doppio clic su Avvia laboratorio.'
    }
    if (-not (Docker-Attivo)) {
        Avviso 'Docker è installato ma spento: provo ad avviarlo (può volerci fino a 2 minuti).'
        $exe = Join-Path $Env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
        if (Test-Path $exe) { Start-Process $exe | Out-Null }
        for ($i = 0; $i -lt 60; $i++) { if (Docker-Attivo) { break }; Start-Sleep 2; Write-Host -NoNewline '.' }
        Write-Host ''
    }
    if (-not (Docker-Attivo)) {
        Fallisci 'Docker non è avviato.' 'Apri Docker Desktop, attendi che in basso a sinistra compaia «Engine running» e fai di nuovo doppio clic su Avvia laboratorio.'
    }
    Ok 'Docker è avviato'
}

# ---------------------------------------------------------------------------
# Risorse
# ---------------------------------------------------------------------------
function Ram-GB { [int]([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)) }
function Disco-Libero-GB { $d = New-Object System.IO.DriveInfo((Get-Item $Kit).PSDrive.Root); [int]($d.AvailableFreeSpace / 1GB) }
function Porta-Occupata($p) {
    $c = New-Object System.Net.Sockets.TcpClient
    try { $r = $c.BeginConnect('127.0.0.1', $p, $null, $null); $ok = $r.AsyncWaitHandle.WaitOne(300) -and $c.Connected; return $ok } catch { return $false } finally { $c.Close() }
}

function Controlla-Risorse {
    Passo 'Controllo memoria, disco e porte'
    $script:RamGB = Ram-GB
    Ok "Memoria del computer: $RamGB GB"
    if ($RamGB -lt [int]$M.LEGGERO_RAM_MIN_GB) { Avviso "Il computer ha meno di $($M.LEGGERO_RAM_MIN_GB) GB di memoria: il laboratorio sarà molto lento. Valuta una postazione di dipartimento o un portatile in prestito." }
    $script:memDocker = 0
    try { $script:memDocker = [int64](& $script:Docker info --format '{{.MemTotal}}') / 1MB } catch {}
    if ($memDocker -gt 0 -and $memDocker -lt 3500) {
        Fallisci "Docker può usare solo $([int]$memDocker) MB di memoria: ne servono almeno 3500." 'Se usi WSL2, chiudi gli altri programmi e riavvia il computer; se il problema resta, chiedi allo sportello di installazione di impostare la memoria di WSL (file .wslconfig).'
    }
    if ($memDocker -gt 0) { Ok "Memoria assegnata a Docker: $([int]$memDocker) MB" }
    $script:DiscoGB = Disco-Libero-GB
    if ($DiscoGB -lt 15 -and -not (Test-Path (Join-Path $Stato 'primo-avvio-completato'))) {
        Fallisci "Sul disco restano solo $DiscoGB GB liberi: per il primo avvio ne servono almeno 15." 'Libera spazio (svuota il Cestino, sposta foto e video su un disco esterno) e fai di nuovo doppio clic su Avvia laboratorio.'
    }
    Ok "Spazio libero sul disco: $DiscoGB GB"
    $attivi = Compose ps -q 2>$null
    if (-not $attivi) {
        foreach ($p in $Porte) {
            if (Porta-Occupata $p) { Fallisci "La porta $p è già usata da un altro programma." 'Chiudi gli altri programmi di sviluppo aperti (o riavvia il computer) e fai di nuovo doppio clic su Avvia laboratorio.' }
        }
        Ok 'Porte libere'
    }
}

# ---------------------------------------------------------------------------
# Ollama
# ---------------------------------------------------------------------------
function Ollama-Get($percorso) { Invoke-RestMethod -UseBasicParsing -TimeoutSec 10 -Uri "$Ollama$percorso" }
function Ollama-Post($percorso, $corpo, $timeout = 600) {
    Invoke-RestMethod -UseBasicParsing -TimeoutSec $timeout -Method Post -ContentType 'application/json' -Uri "$Ollama$percorso" -Body ([System.Text.Encoding]::UTF8.GetBytes(($corpo | ConvertTo-Json -Depth 5 -Compress)))
}
function Ollama-Attivo { try { Ollama-Get '/api/version' | Out-Null; return $true } catch { return $false } }
function Trova-OllamaExe {
    $c = Get-Command ollama.exe -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $p = Join-Path $Env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'
    if (Test-Path $p) { return $p }
    return $null
}

function Controlla-Ollama {
    Passo 'Controllo Ollama'
    if (-not (Ollama-Attivo)) {
        Avviso 'Ollama non risponde: provo ad avviarlo.'
        $app = Join-Path $Env:LOCALAPPDATA 'Programs\Ollama\ollama app.exe'
        if (Test-Path $app) { Start-Process $app | Out-Null }
        for ($i = 0; $i -lt 30; $i++) { if (Ollama-Attivo) { break }; Start-Sleep 2; Write-Host -NoNewline '.' }
        Write-Host ''
    }
    if (-not (Ollama-Attivo)) {
        Fallisci 'Ollama non è avviato o non è installato.' 'Installa Ollama dal sito ufficiale seguendo la scheda «02 · Installare Ollama», aprilo (compare l''icona del lama vicino all''orologio) e fai di nuovo doppio clic su Avvia laboratorio.'
    }
    Ok ("Ollama risponde (versione {0})" -f (Ollama-Get '/api/version').version)
}

# ---------------------------------------------------------------------------
# Profilo e segreti
# ---------------------------------------------------------------------------
function Scegli-Profilo {
    Passo 'Scelta del profilo dei modelli'
    $forzato = ''
    $f = Join-Path $Stato 'profilo-scelto'
    if (Test-Path $f) { $forzato = ((Get-Content $f -Raw) -replace '[^a-z]', '') }
    if ($forzato -in 'standard', 'leggero') { $script:Profilo = $forzato; Ok "Profilo «$Profilo» scelto dal pannello" }
    elseif ($RamGB -ge [int]$M.STANDARD_RAM_MIN_GB) { $script:Profilo = 'standard' }
    else { $script:Profilo = 'leggero' }
    $P = $Profilo.ToUpper()
    $script:LLM = $M["${P}_LLM"]; $script:NumCtx = [int]$M["${P}_NUM_CTX"]; $script:CorpusMax = [int]$M["${P}_CORPUS_MAX"]
    Ok "Profilo «$Profilo» ($LLM, contesto $NumCtx token)"
}

function Casuale($n) {
    $b = New-Object byte[] $n
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
    return (($b | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, $n)
}
$Utf8SenzaBom = New-Object System.Text.UTF8Encoding($false)
function Scrivi-Testo($percorso, $testo) { [System.IO.File]::WriteAllText($percorso, ($testo -replace "`r`n", "`n"), $Utf8SenzaBom) }

function Leggi-Env {
    $e = [ordered]@{}
    $f = Join-Path $Kit '.env'
    if (Test-Path $f) { Get-Content $f | Where-Object { $_ -match '^[A-Z0-9_]+=' } | ForEach-Object { $k, $v = $_ -split '=', 2; $e[$k] = $v } }
    return $e
}
function Scrivi-Env($e) {
    $righe = @('# Generato al primo avvio: segreti locali di QUESTA installazione. Non condividere questo file.')
    foreach ($k in $e.Keys) { $righe += "$k=$($e[$k])" }
    Scrivi-Testo (Join-Path $Kit '.env') (($righe -join "`n") + "`n")
}

function Prepara-Segreti {
    Passo 'Segreti locali'
    $e = Leggi-Env
    if (-not $e.Contains('N8N_ENCRYPTION_KEY')) {
        $e['N8N_ENCRYPTION_KEY'] = Casuale 48
        $e['LIGHTRAG_API_KEY'] = 'lab-' + (Casuale 32)
        $e['LIGHTRAG_DEMO_API_KEY'] = 'demo-' + (Casuale 32)
        $e['NC_ADMIN_EMAIL'] = 'studente@laboratorio.local'
        $e['NC_ADMIN_PASSWORD'] = 'Lab-' + (Casuale 20) + '!Aa9'
        $e['NC_AUTH_JWT_SECRET'] = Casuale 48
        $e['NEO4J_PASSWORD'] = 'neo4j-' + (Casuale 24)
        Ok 'Creati segreti casuali per questa installazione'
    } else { Ok 'Segreti già presenti' }
    $e['LAB_PROFILO'] = $Profilo
    $e['LAB_KIT_VERSION'] = $M.KIT_VERSION
    Scrivi-Env $e
    $script:Env_ = $e
    New-Item -ItemType Directory -Force -Path $Dati | Out-Null
    Scrivi-Testo (Join-Path $Dati 'CREDENZIALI.txt') @"
LABORATORIO DI IA PER LA RICERCA STORICA — le tue credenziali locali
Valgono solo su questo computer. Non condividerle e non allegarle nel forum.

NocoDB (registri)          http://localhost:8080
  email:    $($e.NC_ADMIN_EMAIL)
  password: $($e.NC_ADMIN_PASSWORD)

LightRAG grafo personale   http://localhost:9621
  chiave API: $($e.LIGHTRAG_API_KEY)

LightRAG grafo demo        http://localhost:9622
  chiave API: $($e.LIGHTRAG_DEMO_API_KEY)

n8n (workflow)             http://localhost:5678
  al primo accesso crei tu l'account (scheda 03).

Neo4j (solo profilo avanzato) http://localhost:7474
  utente: neo4j   password: $($e.NEO4J_PASSWORD)
"@
}

# ---------------------------------------------------------------------------
# Immagini e modelli
# ---------------------------------------------------------------------------
function Carica-Offline {
    $off = Join-Path $Kit 'offline'
    if (-not (Test-Path $off)) { return }
    Passo 'Carico immagini e modelli dalla chiavetta (cartella offline)'
    Get-ChildItem (Join-Path $off 'immagini') -Filter *.tar -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  carico $($_.Name)…"
        & $script:Docker load -i $_.FullName | Out-Null
        if ($LASTEXITCODE -ne 0) { Fallisci "Non riesco a caricare $($_.Name) dalla chiavetta." 'Copia di nuovo la cartella offline dalla chiavetta del dipartimento e riprova.' }
    }
    $mod = Join-Path $off 'modelli'
    if (Test-Path $mod) {
        $dest = if ($Env:OLLAMA_MODELS) { $Env:OLLAMA_MODELS } else { Join-Path $Env:USERPROFILE '.ollama\models' }
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        robocopy $mod $dest /E /XC /XN /XO /NFL /NDL /NJH /NJS | Out-Null
        Ok "Modelli copiati in $dest"
    }
}

# Servizi facoltativi scelti dal pannello: Neo4j (avanzato) e Docling (scansioni, ADR-006)
function Scegli-Facoltativi {
    $script:ProfiliCompose = @(); $script:DoclingAttivo = $false; $script:DoclingAvviso = ''
    if (Test-Path (Join-Path $Stato 'neo4j-attivo')) { $script:ProfiliCompose += '--profile', 'avanzato' }
    if (-not (Test-Path (Join-Path $Stato 'docling-attivo'))) { return }
    Passo 'Docling per i PDF scansionati'
    $immagine = Compose --profile scansioni config --images 2>$null | Where-Object { $_ -match 'docling' }
    & $script:Docker image inspect $immagine *> $null; $presente = ($LASTEXITCODE -eq 0)
    if ($memDocker -gt 0 -and $memDocker -lt 6000) {
        $script:DoclingAvviso = "Docling non è stato avviato: Docker può usare solo $([int]$memDocker) MB di memoria e Docling ne chiede altri 3 GB. Chiedi allo sportello di installazione di portare la memoria di WSL ad almeno 6 GB (file .wslconfig), poi fai di nuovo doppio clic su Avvia laboratorio. Intanto WF01 usa Tika."
    } elseif (-not $presente -and (Disco-Libero-GB) -lt 12) {
        $script:DoclingAvviso = "Docling non è stato avviato: per scaricarlo (circa 5 GB) servono almeno 12 GB liberi sul disco e ne restano $(Disco-Libero-GB). Libera spazio e fai di nuovo doppio clic su Avvia laboratorio. Intanto WF01 usa Tika."
    }
    if ($DoclingAvviso) { Avviso $DoclingAvviso; return }
    $script:ProfiliCompose += '--profile', 'scansioni'; $script:DoclingAttivo = $true
    Ok 'Docling attivo (fino a 3 GB di memoria in più)'
}

function Scarica-Immagini {
    Passo 'Immagini Docker'
    $mancanti = @(Compose @ProfiliCompose config --images | Where-Object { & $script:Docker image inspect $_ *> $null; $LASTEXITCODE -ne 0 })
    if ($mancanti.Count -eq 0) { Ok 'Tutte le immagini sono già presenti'; return }
    Write-Host '  Scarico le immagini mancanti (circa 4 GB la prima volta: può richiedere molti minuti).'
    if ($mancanti -match 'docling') { Write-Host '  Docling da solo pesa circa 5 GB: tieni il computer collegato a internet e alla corrente.' }
    Compose @ProfiliCompose pull 2>&1 | Tee-Object -FilePath $Log -Append | Out-Null
    if ($LASTEXITCODE -ne 0) { Fallisci 'Lo scaricamento delle immagini Docker non è riuscito.' 'Controlla la connessione a internet (o usa la chiavetta del dipartimento con la cartella offline) e fai di nuovo doppio clic su Avvia laboratorio.' }
    Ok 'Immagini scaricate'
}

function Modello-Presente($m) { try { return [bool]((Ollama-Get '/api/tags').models | Where-Object { $_.name -eq $m }) } catch { return $false } }

function Scarica-Modello($m) {
    if (Modello-Presente $m) { Ok "Modello $m già presente"; return }
    Write-Host "  Scarico il modello $m…"
    $exe = Trova-OllamaExe
    if ($exe) { & $exe pull $m }
    else { try { Ollama-Post '/api/pull' @{ model = $m; stream = $false } 7200 | Out-Null } catch {} }
    if (-not (Modello-Presente $m)) { Fallisci "Non riesco a scaricare il modello $m." 'Controlla la connessione a internet e lo spazio su disco (o usa la chiavetta del dipartimento) e fai di nuovo doppio clic su Avvia laboratorio.' }
    Ok "Modello $m scaricato"
}

function Prepara-Modelli {
    Passo "Modelli linguistici (profilo $Profilo)"
    Scarica-Modello $M.EMBEDDING_MODEL
    Scarica-Modello $LLM
    $firma = "$Profilo|$LLM|$NumCtx|$($M.TEMPERATURA_ESTRAZIONE)|$($M.TEMPERATURA_RISPOSTA)"
    $fFirma = Join-Path $Stato 'modelli-derivati'
    $attuale = if (Test-Path $fFirma) { (Get-Content $fFirma -Raw).Trim() } else { '' }
    if ($attuale -ne $firma -or -not (Modello-Presente "$($M.MODEL_ESTRAZIONE):latest") -or -not (Modello-Presente "$($M.MODEL_RISPOSTA):latest")) {
        foreach ($coppia in @(@($M.MODEL_ESTRAZIONE, $M.TEMPERATURA_ESTRAZIONE, 'estrazione'), @($M.MODEL_RISPOSTA, $M.TEMPERATURA_RISPOSTA, 'risposta'))) {
            $nome, $temp, $tipo = $coppia
            try {
                $r = Ollama-Post '/api/create' @{ model = $nome; from = $LLM; parameters = @{ num_ctx = $NumCtx; temperature = [double]$temp }; stream = $false }
            } catch { Fallisci "Non riesco a creare il modello $nome." "Aggiorna Ollama all'ultima versione e fai di nuovo doppio clic su Avvia laboratorio. (Dettaglio: $($_.Exception.Message))" }
            $tmpl = Get-Content (Join-Path $Kit "config\Modelfile.$tipo.tmpl") -Raw
            Scrivi-Testo (Join-Path $Stato "Modelfile.$nome") ($tmpl -replace '__LLM__', $LLM -replace '__NUM_CTX__', $NumCtx -replace '__TEMPERATURA__', $temp)
        }
        Scrivi-Testo $fFirma $firma
        Ok "Creati i modelli $($M.MODEL_ESTRAZIONE) e $($M.MODEL_RISPOSTA) (contesto $NumCtx token)"
    } else { Ok "Modelli $($M.MODEL_ESTRAZIONE) e $($M.MODEL_RISPOSTA) già pronti" }
    $dim = 0
    try { $dim = (Ollama-Post '/api/embed' @{ model = $M.EMBEDDING_MODEL; input = 'prova' } 120).embeddings[0].Count } catch {}
    if ($dim -ne [int]$M.EMBEDDING_DIM) { Fallisci "Il modello di embedding restituisce vettori di dimensione $dim invece di $($M.EMBEDDING_DIM)." 'Segnala il problema al docente con il file di Diagnostica: non indicizzare documenti finché non è risolto.' }
    Ok "Embedding verificato: $($M.EMBEDDING_MODEL), dimensione $dim"
}

# ---------------------------------------------------------------------------
# Avvio
# ---------------------------------------------------------------------------
function Scrivi-Stato {
    $s = [ordered]@{
        versione_kit = $M.KIT_VERSION; profilo = $Profilo; llm = $LLM; contesto = $NumCtx; embedding = $M.EMBEDDING_MODEL
        corpus_consigliato = $CorpusMax; ram_gb = $RamGB; disco_libero_gb = (Disco-Libero-GB)
        neo4j = (Test-Path (Join-Path $Stato 'neo4j-attivo')); docling = $DoclingAttivo; docling_avviso = $DoclingAvviso
        avviato_il = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
    }
    Scrivi-Testo (Join-Path $Stato 'stato.json') ($s | ConvertTo-Json)
}

function Attendi-Salute($servizio, $massimo) {
    for ($i = 0; $i -lt $massimo; $i++) {
        try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri "$Pannello/salute/$servizio" | Out-Null; return $true } catch { Start-Sleep 3 }
    }
    return $false
}

function Avvia-Servizi {
    Passo 'Avvio dei servizi (la prima volta prepara anche tabelle e workflow)'
    foreach ($c in 'inbox', 'testi', 'dossier\backup') { New-Item -ItemType Directory -Force -Path (Join-Path $Dati $c) | Out-Null }
    Scrivi-Stato
    # Un servizio facoltativo appena disattivato dal pannello va spento: «up» non lo fa da solo.
    if (-not (Test-Path (Join-Path $Stato 'neo4j-attivo'))) { Compose --profile avanzato rm -sf neo4j 2>&1 | Out-File -Append $Log -Encoding UTF8 }
    if (-not $DoclingAttivo) { Compose --profile scansioni rm -sf docling 2>&1 | Out-File -Append $Log -Encoding UTF8 }
    Compose @ProfiliCompose up -d --remove-orphans 2>&1 | Tee-Object -FilePath $Log -Append | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $msg = ''
        try { $msg = (Get-Content (Join-Path $Stato 'init.json') -Raw | ConvertFrom-Json).messaggio } catch {}
        Fallisci "I servizi del laboratorio non sono partiti. $msg" 'Fai di nuovo doppio clic su Avvia laboratorio: spesso il secondo tentativo basta (la prima configurazione riprende da dove si era fermata).'
    }
    foreach ($s in $ServiziSalute) {
        if (Attendi-Salute $s 60) { Ok "$s pronto" } else { Avviso "$s non risponde ancora: controlla il pannello tra qualche minuto" }
    }
    if ($DoclingAttivo) {
        if (Attendi-Salute 'docling' 60) { Ok 'docling pronto' } else { Avviso 'docling non risponde ancora: controlla il pannello tra qualche minuto' }
    }
    New-Item -ItemType File -Force -Path (Join-Path $Stato 'primo-avvio-completato') | Out-Null
}

# ---------------------------------------------------------------------------
# Comandi
# ---------------------------------------------------------------------------
function Cmd-Avvia {
    Write-Host "Laboratorio di IA per la ricerca storica · kit $($M.KIT_VERSION)" -ForegroundColor White
    Write-Host 'Non chiudere questa finestra finché non si apre il pannello nel browser.'
    Registra "=== avvio kit $($M.KIT_VERSION)"
    Controlla-Docker; Controlla-Risorse; Controlla-Ollama; Scegli-Profilo; Scegli-Facoltativi; Prepara-Segreti
    Carica-Offline; Scarica-Immagini; Prepara-Modelli; Avvia-Servizi; Scrivi-Stato
    Passo 'Fatto'
    Ok "Il pannello del laboratorio si apre nel browser: $Pannello"
    Start-Process $Pannello
    Write-Host ''
    Write-Host 'Puoi chiudere questa finestra. Il laboratorio resta acceso finché non fai doppio clic su «Ferma laboratorio».'
    Attendi-Invio
}

function Cmd-Ferma {
    Write-Host 'Fermo il laboratorio' -ForegroundColor White
    if (-not (Trova-Docker)) { Fallisci 'Docker Desktop non è installato.' "Non c'è niente da fermare." }
    if (-not (Docker-Attivo)) { Ok 'Docker è già spento: il laboratorio è fermo.'; Attendi-Invio; return }
    Compose @TuttiIProfili down 2>&1 | Tee-Object -FilePath $Log -Append | Out-Null
    Ok 'Laboratorio fermato. I tuoi dati restano nella cartella dati e nei registri.'
    Attendi-Invio
}

function Cmd-Diagnostica {
    Write-Host 'Diagnostica del laboratorio' -ForegroundColor White
    $data = Get-Date -Format 'yyyy-MM-dd-HHmm'
    $tmp = Join-Path $Env:TEMP "Diagnostica-$data"
    New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'log') | Out-Null
    @(
        "kit: $($M.KIT_VERSION)", "data: $(Get-Date)", "sistema: $((Get-CimInstance Win32_OperatingSystem).Caption) $([Environment]::OSVersion.Version)",
        "ram_gb: $(Ram-GB)", "disco_libero_gb: $(Disco-Libero-GB)", "cartella del kit: $Kit"
    ) | Set-Content (Join-Path $tmp 'sistema.txt') -Encoding UTF8
    try { wsl.exe --status 2>&1 | Out-File (Join-Path $tmp 'wsl.txt') -Encoding UTF8 } catch {}
    if ((Trova-Docker) -and (Docker-Attivo)) {
        & $script:Docker version 2>&1 | Out-File (Join-Path $tmp 'docker-version.txt') -Encoding UTF8
        & $script:Docker info 2>&1 | Out-File (Join-Path $tmp 'docker-info.txt') -Encoding UTF8
        Compose @TuttiIProfili ps -a 2>&1 | Out-File (Join-Path $tmp 'compose-ps.txt') -Encoding UTF8
        & $script:Docker stats --no-stream 2>&1 | Out-File (Join-Path $tmp 'docker-stats.txt') -Encoding UTF8
        foreach ($s in 'pannello', 'n8n', 'init', 'nocodb', 'lightrag', 'lightrag-demo', 'tika', 'controlli', 'neo4j', 'docling') {
            Compose logs --no-color --tail 500 $s 2>&1 | Out-File (Join-Path $tmp "log\$s.txt") -Encoding UTF8
        }
    } else { 'Docker non installato o non avviato' | Set-Content (Join-Path $tmp 'docker-version.txt') }
    try { (Ollama-Get '/api/version' | ConvertTo-Json), (Ollama-Get '/api/tags' | ConvertTo-Json -Depth 5) | Out-File (Join-Path $tmp 'ollama.txt') -Encoding UTF8 } catch { 'Ollama non risponde' | Out-File (Join-Path $tmp 'ollama.txt') }
    $salute = foreach ($s in $ServiziSalute + 'neo4j', 'docling') {
        $codice = try { (Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri "$Pannello/salute/$s").StatusCode } catch { 'errore' }
        '{0,-15} {1}' -f $s, $codice
    }
    $salute | Set-Content (Join-Path $tmp 'salute.txt') -Encoding UTF8
    Get-ChildItem $Stato -Include *.json, *.log, Modelfile.* -Recurse -ErrorAction SilentlyContinue | Copy-Item -Destination $tmp
    Get-ChildItem $Dati -Recurse -Depth 1 -ErrorAction SilentlyContinue | Select-Object FullName, Length, LastWriteTime | Out-File (Join-Path $tmp 'cartelle.txt') -Encoding UTF8
    # Rimozione dei segreti
    $segreti = (Leggi-Env).Values | Where-Object { $_.Length -ge 8 }
    Get-ChildItem $tmp -Recurse -File | ForEach-Object {
        $t = [System.IO.File]::ReadAllText($_.FullName)
        foreach ($v in $segreti) { $t = $t.Replace($v, '[RIMOSSO]') }
        $t = [regex]::Replace($t, '(xc-token|xc-auth|X-API-Key|apiKey|password|token)("?[:=] ?"?)[A-Za-z0-9._!-]{8,}', '$1$2[RIMOSSO]', 'IgnoreCase')
        [System.IO.File]::WriteAllText($_.FullName, $t, $Utf8SenzaBom)
    }
    $zip = Join-Path ([Environment]::GetFolderPath('Desktop')) "Diagnostica-$data.zip"
    Compress-Archive -Path $tmp -DestinationPath $zip -Force
    Remove-Item -Recurse -Force $tmp
    Ok "Rapporto creato: $zip"
    Write-Host 'Allegalo nel forum del corso. Non contiene password né chiavi.'
    Attendi-Invio
}

function Cmd-Backup {
    Write-Host 'Backup del laboratorio' -ForegroundColor White
    Controlla-Docker
    $data = Get-Date -Format 'yyyy-MM-dd-HHmm'
    $dest = Join-Path $Dati "dossier\backup\backup-$data"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Passo 'Fermo i servizi per copiare i dati in modo coerente'
    Compose @TuttiIProfili stop 2>&1 | Out-File -Append $Log -Encoding UTF8
    foreach ($vol in 'n8n_data', 'nocodb_data', 'lightrag_data', 'lightrag_inputs', 'neo4j_data') {
        & $script:Docker volume inspect "laboratorio-ia_$vol" *> $null
        if ($LASTEXITCODE -ne 0) { continue }
        & $script:Docker run --rm -v "laboratorio-ia_${vol}:/volume:ro" -v "${dest}:/backup" --entrypoint tar $ImmagineAttrezzi -czf "/backup/$vol.tar.gz" -C /volume . 2>&1 | Out-File -Append $Log -Encoding UTF8
        if ($LASTEXITCODE -ne 0) { Compose start | Out-Null; Fallisci "Il backup del registro $vol non è riuscito." 'Controlla lo spazio su disco e riprova.' }
        Ok "Copiato $vol"
    }
    & $script:Docker run --rm -v "${Dati}:/dati:ro" -v "${dest}:/backup" --entrypoint tar $ImmagineAttrezzi -czf /backup/dati.tar.gz -C /dati --exclude ./dossier/backup . 2>&1 | Out-File -Append $Log -Encoding UTF8
    Ok 'Copiata la cartella dati'
    Copy-Item (Join-Path $Kit '.env') (Join-Path $dest 'segreti.env')
    "Backup del $(Get-Date) · kit $($M.KIT_VERSION). Per il ripristino vedi la scheda «Backup e Diagnostica»." | Set-Content (Join-Path $dest 'LEGGIMI.txt') -Encoding UTF8
    Passo 'Riavvio i servizi'
    Compose start 2>&1 | Out-File -Append $Log -Encoding UTF8
    Ok "Backup completato: $dest"
    Write-Host 'Copia la cartella del backup su un disco esterno o in un cloud di ateneo: contiene anche le tue chiavi locali.'
    Attendi-Invio
}

try {
    switch ($Comando) {
        'avvia' { Cmd-Avvia }
        'ferma' { Cmd-Ferma }
        'diagnostica' { Cmd-Diagnostica }
        'backup' { Cmd-Backup }
    }
} catch {
    Fallisci "Errore imprevisto: $($_.Exception.Message)" 'Fai di nuovo doppio clic sul file. Se l''errore resta, fai doppio clic su Diagnostica e allega il file nel forum del corso.'
}
