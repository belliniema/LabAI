// Prima configurazione automatica del laboratorio (CLAUDE.md §6, ADR-004).
// Gira nel contenitore "init" (immagine di n8n, Node.js >= 20) prima che parta n8n.
// Idempotente: un marcatore nel volume di n8n impedisce di ripetere il lavoro.
'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const VERSIONE_INIT = 1;
const CARTELLA_N8N = '/home/node/.n8n';
const MARCATORE = path.join(CARTELLA_N8N, '.laboratorio-init-v' + VERSIONE_INIT);
const STATO_INTERNO = path.join(CARTELLA_N8N, 'laboratorio-registri.json');
const STATO_PANNELLO = '/stato/init.json';
const SCHEMA = require('./schema_registri.json');

const NC = process.env.NC_URL;
const LR = process.env.LIGHTRAG_URL;
const TIKA = process.env.TIKA_URL;
const CONTROLLI = process.env.CONTROLLI_URL;

// Identificatori fissi delle credenziali: i workflow li richiamano per id.
const CREDENZIALI = {
  nocodb: { id: 'labCredNocoDB0001', nome: 'NocoDB · registri' },
  lightrag: { id: 'labCredLightRAG01', nome: 'LightRAG · grafo personale' },
  lightragDemo: { id: 'labCredLightRAGDm', nome: 'LightRAG · grafo demo' },
  n8nApi: { id: 'labCredN8nApi0001', nome: 'n8n · API locale' }
};

function log(msg) { console.log('[init] ' + msg); }

function scriviStato(oggetto) {
  try { fs.writeFileSync(STATO_PANNELLO, JSON.stringify(Object.assign({ aggiornato: new Date().toISOString() }, oggetto), null, 2)); } catch (e) { log('stato non scritto: ' + e.message); }
}

function errore(cosa, rimedio) {
  const e = new Error(cosa);
  e.rimedio = rimedio;
  return e;
}

async function attendi(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

async function http(metodo, url, opzioni) {
  const o = opzioni || {};
  const intestazioni = Object.assign({}, o.intestazioni);
  let corpo = o.corpo;
  if (corpo !== undefined && !(corpo instanceof Buffer) && typeof corpo !== 'string') {
    corpo = JSON.stringify(corpo);
    intestazioni['Content-Type'] = 'application/json';
  }
  const r = await fetch(url, { method: metodo, headers: intestazioni, body: corpo, signal: AbortSignal.timeout(o.timeout || 60000) });
  const testo = await r.text();
  let json = null;
  try { json = testo ? JSON.parse(testo) : null; } catch (e) { json = null; }
  if (!r.ok && !o.tollera) throw errore(metodo + ' ' + url.replace(/\/\/[^/]+/, '//…') + ' → ' + r.status + ' ' + testo.slice(0, 300));
  return { stato: r.status, json: json, testo: testo };
}

async function attendiServizio(nome, url, tentativi) {
  for (let i = 0; i < (tentativi || 60); i++) {
    try {
      const r = await fetch(url, { signal: AbortSignal.timeout(5000) });
      if (r.status < 500) return;
    } catch (e) { /* non ancora pronto */ }
    await attendi(3000);
  }
  throw errore(nome + ' non risponde', 'Fai doppio clic su Diagnostica e allega il file nel forum del corso.');
}

// ---------------------------------------------------------------------------
// Cartelle dello studente
// ---------------------------------------------------------------------------
function preparaCartelle() {
  ['inbox', 'testi', 'dossier', 'dossier/backup'].forEach(function (c) { fs.mkdirSync(path.join('/dati', c), { recursive: true }); });
  const leggimi = path.join('/dati', 'LEGGIMI.txt');
  if (!fs.existsSync(leggimi)) {
    fs.writeFileSync(leggimi, [
      'LABORATORIO DI IA PER LA RICERCA STORICA - cartella dei dati',
      '',
      'inbox/    Trascina qui i documenti del tuo corpus (PDF, Word, immagini, testo).',
      '          Poi esegui in n8n il workflow "WF01 · Ingestione da cartella".',
      'testi/    Il testo estratto da ogni documento, con il nome <doc_id>.txt.',
      '          Non modificare questi file a mano: il registro ne conserva l\'impronta (hash).',
      'dossier/  Le esportazioni per l\'esame (WF08) e i backup (cartella backup/).',
      '',
      'CREDENZIALI.txt contiene le password locali del tuo laboratorio. Non condividerlo.',
      'I dati restano su questo computer. Fai un backup regolare con il file "Backup".',
      ''
    ].join('\n'));
  }
}

// ---------------------------------------------------------------------------
// NocoDB: utente locale, base, tabelle, token API (sezione 7)
// ---------------------------------------------------------------------------
function colonna(campo, chiave) {
  const nome = campo[0];
  const tipo = campo[1];
  const c = { column_name: nome, title: nome };
  if (typeof tipo === 'string') c.uidt = tipo;
  else {
    c.uidt = tipo.uidt;
    c.colOptions = { options: tipo.opzioni.map(function (o, i) { return { title: o, order: i + 1 }; }) };
  }
  if (nome === chiave) c.pv = true;
  return c;
}

async function configuraNocoDB() {
  await attendiServizio('NocoDB', NC + '/api/v1/health');
  const accesso = await http('POST', NC + '/api/v1/auth/user/signin', { corpo: { email: process.env.NC_ADMIN_EMAIL, password: process.env.NC_ADMIN_PASSWORD } });
  const auth = { 'xc-auth': accesso.json.token };

  const basi = await http('GET', NC + '/api/v2/meta/bases/', { intestazioni: auth });
  let base = (basi.json.list || []).find(function (b) { return b.title === SCHEMA.base; });
  if (!base) {
    base = (await http('POST', NC + '/api/v2/meta/bases', { intestazioni: auth, corpo: { title: SCHEMA.base, description: 'Registri del Laboratorio di IA per la ricerca storica' } })).json;
    log('creata la base NocoDB "' + SCHEMA.base + '"');
  }

  const esistenti = (await http('GET', NC + '/api/v2/meta/bases/' + base.id + '/tables', { intestazioni: auth })).json.list || [];
  const tabelle = {};
  for (const t of SCHEMA.tabelle) {
    let tab = esistenti.find(function (e) { return e.title === t.nome || e.table_name === t.nome; });
    if (!tab) {
      const colonne = [{ column_name: 'id', title: 'id', uidt: 'ID' }]
        .concat(t.campi.map(function (c) { return colonna(c, t.chiave); }))
        .concat([
          { column_name: 'creato_il', title: 'creato_il', uidt: 'CreatedTime' },
          { column_name: 'modificato_il', title: 'modificato_il', uidt: 'LastModifiedTime' }
        ]);
      tab = (await http('POST', NC + '/api/v2/meta/bases/' + base.id + '/tables', {
        intestazioni: auth, corpo: { table_name: t.nome, title: t.nome, description: t.descrizione, columns: colonne }
      })).json;
      log('creata la tabella ' + t.nome);
    }
    tabelle[t.nome] = tab.id;
  }

  let token = null;
  try { token = JSON.parse(fs.readFileSync(STATO_INTERNO, 'utf8')).token; } catch (e) { token = null; }
  if (token) {
    const prova = await http('GET', NC + '/api/v2/tables/' + tabelle.corpus_documenti + '/records?limit=1', { intestazioni: { 'xc-token': token }, tollera: true });
    if (prova.stato !== 200) token = null;
  }
  if (!token) {
    token = (await http('POST', NC + '/api/v2/meta/bases/' + base.id + '/api-tokens', { intestazioni: auth, corpo: { description: 'n8n · laboratorio' } })).json.token;
    log('creato il token API per n8n');
  }
  fs.writeFileSync(STATO_INTERNO, JSON.stringify({ base: base.id, tabelle: tabelle, token: token }), { mode: 0o600 });
  return { base: base.id, tabelle: tabelle, token: token };
}

// ---------------------------------------------------------------------------
// n8n: credenziali e workflow importati con la CLI (sezione 8)
// ---------------------------------------------------------------------------
function n8n(argomenti) {
  return execFileSync('n8n', argomenti, { stdio: ['ignore', 'pipe', 'pipe'], env: process.env, timeout: 300000 }).toString();
}

function importaCredenziali(nocodb) {
  const file = '/tmp/credenziali-laboratorio.json';
  const dati = [
    { id: CREDENZIALI.nocodb.id, name: CREDENZIALI.nocodb.nome, type: 'httpHeaderAuth', data: { name: 'xc-token', value: nocodb.token } },
    { id: CREDENZIALI.lightrag.id, name: CREDENZIALI.lightrag.nome, type: 'httpHeaderAuth', data: { name: 'X-API-Key', value: process.env.LIGHTRAG_API_KEY } },
    { id: CREDENZIALI.lightragDemo.id, name: CREDENZIALI.lightragDemo.nome, type: 'httpHeaderAuth', data: { name: 'X-API-Key', value: process.env.LIGHTRAG_DEMO_API_KEY } },
    // La chiave API di n8n la crea lo studente dopo il primo accesso (scheda WF08) e la incolla qui.
    { id: CREDENZIALI.n8nApi.id, name: CREDENZIALI.n8nApi.nome, type: 'n8nApi', data: { apiKey: '', baseUrl: 'http://localhost:5678/api/v1' } }
  ];
  fs.writeFileSync(file, JSON.stringify(dati), { mode: 0o600 });
  try {
    n8n(['import:credentials', '--input=' + file]);
  } finally {
    fs.unlinkSync(file);
  }
  log('importate ' + dati.length + ' credenziali in n8n');
}

function importaWorkflow(nocodb) {
  const sorgente = '/kit-workflows';
  const destinazione = '/tmp/workflows-laboratorio';
  fs.rmSync(destinazione, { recursive: true, force: true });
  fs.mkdirSync(destinazione);
  const file = fs.readdirSync(sorgente).filter(function (f) { return /^WF\d\d.*\.json$/.test(f); }).sort();
  file.forEach(function (f) {
    let testo = fs.readFileSync(path.join(sorgente, f), 'utf8');
    Object.keys(nocodb.tabelle).forEach(function (t) { testo = testo.split('__TBL_' + t + '__').join(nocodb.tabelle[t]); });
    if (/__TBL_[a-z_]+__/.test(testo)) throw errore('segnaposto di tabella non sostituito in ' + f);
    fs.writeFileSync(path.join(destinazione, f), testo);
  });
  n8n(['import:workflow', '--separate', '--input=' + destinazione]);
  fs.rmSync(destinazione, { recursive: true, force: true });
  log('importati ' + file.length + ' workflow in n8n');
  return file.length;
}

// ---------------------------------------------------------------------------
// Verifica della catena con un documento di prova (non entra nel corpus)
// ---------------------------------------------------------------------------
async function verificaCatena(nocodb) {
  const esito = {};
  const prova = Buffer.from('Documento di prova del laboratorio. Roma, 20 settembre 1870.\n', 'utf8');

  await attendiServizio('Apache Tika', TIKA + '/tika');
  const testo = (await http('PUT', TIKA + '/tika/text', { corpo: prova, intestazioni: { 'Content-Type': 'text/plain' } })).testo;
  esito.tika = /20 settembre 1870/.test(testo);

  await attendiServizio('controlli', CONTROLLI + '/salute');
  const c = (await http('POST', CONTROLLI + '/controlla', { corpo: { testo: testo, usa_tika: false } })).json;
  esito.controlli = c && c.sospetto === false;

  const tab = nocodb.tabelle.uso_ia;
  const creato = (await http('POST', NC + '/api/v2/tables/' + tab + '/records', { intestazioni: { 'xc-token': nocodb.token }, corpo: { evento_id: 'PROVA-INIT', workflow: 'init' } })).json;
  const id = creato.id !== undefined ? creato.id : creato.Id;
  await http('DELETE', NC + '/api/v2/tables/' + tab + '/records', { intestazioni: { 'xc-token': nocodb.token }, corpo: { id: id } });
  esito.nocodb = true;

  const salute = await http('GET', LR + '/health', { tollera: true });
  esito.lightrag = salute.stato === 200;

  Object.keys(esito).forEach(function (k) { if (!esito[k]) throw errore('verifica della catena non riuscita: ' + k, 'Fai doppio clic su Diagnostica e allega il file nel forum del corso.'); });
  log('catena verificata: ' + JSON.stringify(esito));
  return esito;
}

async function principale() {
  preparaCartelle();
  if (fs.existsSync(MARCATORE)) {
    log('configurazione già eseguita: niente da fare');
    return;
  }
  scriviStato({ stato: 'in_corso', messaggio: 'Prima configurazione in corso…' });
  const nocodb = await configuraNocoDB();
  importaCredenziali(nocodb);
  const nWorkflow = importaWorkflow(nocodb);
  const catena = await verificaCatena(nocodb);
  fs.writeFileSync(MARCATORE, new Date().toISOString());
  scriviStato({ stato: 'completato', messaggio: 'Prima configurazione completata.', workflow: nWorkflow, catena: catena });
  log('prima configurazione completata');
}

principale().catch(function (e) {
  console.error('[init] ERRORE: ' + e.message);
  scriviStato({ stato: 'errore', messaggio: 'La prima configurazione non è riuscita: ' + e.message, rimedio: e.rimedio || 'Fai di nuovo doppio clic su Avvia laboratorio. Se l\'errore resta, fai doppio clic su Diagnostica e allega il file nel forum del corso.' });
  process.exit(1);
});
