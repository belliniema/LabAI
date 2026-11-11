// Servizio interno "controlli" del Laboratorio di IA per la ricerca storica (ADR-003).
// Segnala, non corregge: non modifica file, stati o registri e non chiama mai un LLM.
// Nessuna dipendenza esterna: solo moduli di Node.js. Invisibile allo studente.
'use strict';

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { URL } = require('url');

const PORTA = Number(process.env.PORTA || 8099);
const TIKA_URL = process.env.TIKA_URL || 'http://tika:9998';
const ALLOWLIST = process.env.ALLOWLIST || '/config/allowlist_domini.txt';
const CARTELLA_DATI = process.env.CARTELLA_DATI || '/dati';
const RITARDO_WEB_MS = Number(process.env.RITARDO_WEB_MS || 3000);
const USER_AGENT = 'LaboratorioIA-RomaTre/0.1 (ricerca didattica; rispetta robots.txt)';
const MAX_ESTRATTO = 300;
const MAX_SCARICAMENTO = 5 * 1024 * 1024;

// ---------------------------------------------------------------------------
// Estratti resi inerti (CLAUDE.md §10.2): troncati, tra virgolette, con prefisso,
// caratteri invisibili mostrati come <U+XXXX>. Non vanno mai reinviati a un LLM.
// ---------------------------------------------------------------------------
const RE_INVISIBILI = /[\u200B-\u200F\u2060-\u2064\uFEFF\u061C\u202A-\u202E\u2066-\u2069]|\uDB40[\uDC00-\uDC7F]/g;

function codiceUnicode(c) {
  return '<U+' + c.codePointAt(0).toString(16).toUpperCase().padStart(4, '0') + '>';
}

function rendiInerte(testo) {
  let t = String(testo || '').replace(RE_INVISIBILI, codiceUnicode).replace(/\s+/g, ' ').trim();
  if (t.length > MAX_ESTRATTO - 30) t = t.slice(0, MAX_ESTRATTO - 31) + '…';
  t = t.replace(/"/g, '\u201D');
  return '[ESTRATTO SOSPETTO] "' + t + '"';
}

function segnalazione(tipo, estratto, dettaglio) {
  return { tipo: tipo, estratto: rendiInerte(estratto), dettaglio: dettaglio };
}

// ---------------------------------------------------------------------------
// 1. Caratteri invisibili: zero-width, tag Unicode, controlli bidirezionali.
// ---------------------------------------------------------------------------
function controllaInvisibili(testo) {
  const trovati = {};
  const risultati = [];
  const re = new RegExp(RE_INVISIBILI.source, 'g');
  let m;
  while ((m = re.exec(testo)) !== null) {
    const cp = m[0].codePointAt(0);
    const famiglia = cp >= 0xE0000 ? 'tag Unicode' : (cp >= 0x202A || cp === 0x061C || cp === 0x200E || cp === 0x200F) ? 'controllo bidirezionale' : 'zero-width';
    trovati[famiglia] = (trovati[famiglia] || 0) + 1;
    if (!trovati['_pos_' + famiglia]) trovati['_pos_' + famiglia] = m.index;
  }
  Object.keys(trovati).filter(function (k) { return k.indexOf('_pos_') !== 0; }).forEach(function (famiglia) {
    const pos = trovati['_pos_' + famiglia];
    const intorno = testo.slice(Math.max(0, pos - 60), pos + 120);
    let dettaglio = trovati[famiglia] + ' caratteri ' + famiglia;
    if (famiglia === 'tag Unicode') {
      // I caratteri tag ricalcano l'ASCII: li decodifichiamo per mostrare il messaggio nascosto.
      const nascosto = Array.from(testo).filter(function (c) { const p = c.codePointAt(0); return p > 0xE0000 && p < 0xE007F; })
        .map(function (c) { return String.fromCharCode(c.codePointAt(0) - 0xE0000); }).join('');
      if (nascosto) dettaglio += '; testo nascosto decodificato: ' + rendiInerte(nascosto);
    }
    risultati.push(segnalazione('carattere_invisibile', intorno, dettaglio));
  });
  return risultati;
}

// ---------------------------------------------------------------------------
// 2. Frasi d'istruzione rivolte a un modello (italiano e inglese).
// ---------------------------------------------------------------------------
const FRASI_ISTRUZIONE = [
  /ignora\s+(tutte\s+)?(le\s+)?istruzioni\s+(precedenti|ricevute|sopra)/i,
  /dimentica\s+(tutte\s+)?(le\s+)?(istruzioni|regole)/i,
  /ignore\s+(all\s+)?(the\s+)?(previous|prior|above)\s+instructions/i,
  /disregard\s+(all\s+)?(the\s+)?(previous|prior|above)/i,
  /system\s+prompt/i,
  /prompt\s+di\s+sistema/i,
  /\bsei\s+ora\s+(un|una|il|la)\b/i,
  /\byou\s+are\s+now\b/i,
  /\b(scrivi|rispondi|write|answer|reply)\b[^.\n]{0,40}\b(solo|soltanto|only)\b/i,
  /\b(assistente|assistant|modello linguistico|language model|ai|ia|llm)\b[^.\n]{0,60}\b(devi|must|should)\b/i,
  /\b(invia|manda|send|visita|visit|apri|open|clicca|click)\b[^.\n]{0,60}(https?:\/\/|www\.|link|password|credenzial|e-?mail)/i,
  /\b(inserisci|includi|include|insert)\b[^.\n]{0,40}\b(link|url|collegamento)\b/i,
  /CANARINO-\d+/
];

function controllaIstruzioni(testo, tipo) {
  const risultati = [];
  const visti = {};
  FRASI_ISTRUZIONE.forEach(function (re) {
    const m = re.exec(testo);
    if (m && !visti[m.index]) {
      visti[m.index] = true;
      risultati.push(segnalazione(tipo || 'istruzione_sospetta',
        testo.slice(Math.max(0, m.index - 80), m.index + m[0].length + 80),
        'frase d\'istruzione: ' + re.source.slice(0, 60)));
    }
  });
  return risultati;
}

// ---------------------------------------------------------------------------
// 3. Base64 lunghi e URL verso domini fuori allowlist.
// ---------------------------------------------------------------------------
function leggiAllowlist() {
  try {
    return fs.readFileSync(ALLOWLIST, 'utf8').split(/\r?\n/)
      .map(function (r) { return r.trim().toLowerCase(); })
      .filter(function (r) { return r && r.charAt(0) !== '#'; });
  } catch (e) {
    return [];
  }
}

function dominioConsentito(host, allowlist) {
  const h = String(host || '').toLowerCase().replace(/\.$/, '');
  return (allowlist || leggiAllowlist()).some(function (d) { return h === d || h.endsWith('.' + d); });
}

function controllaBase64EUrl(testo, allowlist) {
  const risultati = [];
  const b64 = /[A-Za-z0-9+/]{200,}={0,2}/.exec(testo);
  if (b64) risultati.push(segnalazione('testo_nascosto', b64[0].slice(0, 120), 'sequenza base64 di ' + b64[0].length + ' caratteri'));
  const reUrl = /\bhttps?:\/\/[^\s"'<>)\]]+/gi;
  const domini = {};
  let m;
  while ((m = reUrl.exec(testo)) !== null) {
    let host = '';
    try { host = new URL(m[0]).hostname; } catch (e) { continue; }
    if (!dominioConsentito(host, allowlist) && !domini[host]) {
      domini[host] = true;
      risultati.push(segnalazione('dominio_non_affidabile', m[0], 'URL verso dominio non in allowlist: ' + host));
    }
  }
  return risultati;
}

// ---------------------------------------------------------------------------
// 4. HTML: contenuto nascosto via CSS o attributi, alt/title anomali.
// ---------------------------------------------------------------------------
const RE_STILE_NASCOSTO = /display\s*:\s*none|visibility\s*:\s*hidden|font-size\s*:\s*0*[01](\.\d+)?\s*(px|pt)?\s*(;|"|'|$)|opacity\s*:\s*0(\.0+)?\s*(;|"|'|$)|color\s*:\s*(#fff(fff)?|white|rgba?\(\s*255\s*,\s*255\s*,\s*255)|left\s*:\s*-\d{3,}px|text-indent\s*:\s*-\d{3,}/i;

function testoDaHtml(html) {
  return decodificaEntita(String(html)
    .replace(/<(script|style|noscript|template)[\s\S]*?<\/\1>/gi, ' ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|h[1-6]|li|tr|section|article|blockquote)>/gi, '\n')
    .replace(/<[^>]+>/g, ' '))
    .replace(/[ \t]+/g, ' ').replace(/\n\s*\n\s*\n+/g, '\n\n').trim();
}

function decodificaEntita(s) {
  const nominate = { amp: '&', lt: '<', gt: '>', quot: '"', apos: '\'', nbsp: ' ', egrave: 'è', eacute: 'é', agrave: 'à', ograve: 'ò', ugrave: 'ù', igrave: 'ì', laquo: '«', raquo: '»', rsquo: '\u2019', lsquo: '\u2018', ldquo: '\u201C', rdquo: '\u201D', hellip: '…', ndash: '–', mdash: '—' };
  return s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, function (tutto, e) {
    if (e.charAt(0) === '#') {
      const n = e.charAt(1).toLowerCase() === 'x' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      try { return String.fromCodePoint(n); } catch (err) { return tutto; }
    }
    return Object.prototype.hasOwnProperty.call(nominate, e.toLowerCase()) ? nominate[e.toLowerCase()] : tutto;
  });
}

function controllaHtml(html) {
  const risultati = [];
  const reElemento = /<([a-z][a-z0-9]*)\b([^>]*)>([\s\S]*?)<\/\1>/gi;
  let m;
  while ((m = reElemento.exec(html)) !== null) {
    const attributi = m[2];
    const stile = (/style\s*=\s*("([^"]*)"|'([^']*)')/i.exec(attributi) || [])[0] || '';
    const nascosto = RE_STILE_NASCOSTO.test(stile) || /\shidden(\s|=|$)/i.test(attributi) || /aria-hidden\s*=\s*["']true/i.test(attributi);
    const testo = testoDaHtml(m[3]);
    if (nascosto && testo.length >= 3) {
      risultati.push(segnalazione('testo_nascosto', testo, 'elemento <' + m[1] + '> nascosto (' + (stile || 'attributo hidden') .slice(0, 80) + ')'));
    }
  }
  // Classi nascoste definite in <style>: .x{display:none}
  const reRegola = /\.([a-z0-9_-]+)\s*\{([^}]*)\}/gi;
  const stiliCss = (html.match(/<style[\s\S]*?<\/style>/gi) || []).join('\n');
  while ((m = reRegola.exec(stiliCss)) !== null) {
    if (RE_STILE_NASCOSTO.test(m[2] + ';')) {
      const reClasse = new RegExp('<([a-z][a-z0-9]*)\\b[^>]*class\\s*=\\s*["\'][^"\']*\\b' + m[1] + '\\b[^"\']*["\'][^>]*>([\\s\\S]*?)<\\/\\1>', 'gi');
      let e;
      while ((e = reClasse.exec(html)) !== null) {
        const testo = testoDaHtml(e[2]);
        if (testo.length >= 3) risultati.push(segnalazione('testo_nascosto', testo, 'classe CSS nascosta .' + m[1]));
      }
    }
  }
  const reAttr = /\s(alt|title|aria-label)\s*=\s*("([^"]*)"|'([^']*)')/gi;
  while ((m = reAttr.exec(html)) !== null) {
    const valore = decodificaEntita(m[3] || m[4] || '');
    if (valore.length > 150 || controllaIstruzioni(valore).length) {
      risultati.push(segnalazione('testo_nascosto', valore, 'attributo ' + m[1] + ' anomalo (' + valore.length + ' caratteri)'));
    }
  }
  return risultati;
}

// ---------------------------------------------------------------------------
// 5. File: metadati (XMP, proprietà Office, commenti) e analisi grezza dei PDF.
// ---------------------------------------------------------------------------

// Lettore ZIP minimo (DOCX, ODT): legge la directory centrale e decomprime le voci richieste.
function leggiZip(buf) {
  const voci = {};
  let fine = -1;
  for (let i = buf.length - 22; i >= Math.max(0, buf.length - 65557); i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) { fine = i; break; }
  }
  if (fine < 0) return voci;
  const n = buf.readUInt16LE(fine + 10);
  let p = buf.readUInt32LE(fine + 16);
  for (let k = 0; k < n && p + 46 <= buf.length; k++) {
    if (buf.readUInt32LE(p) !== 0x02014b50) break;
    const metodo = buf.readUInt16LE(p + 10);
    const dimCompressa = buf.readUInt32LE(p + 20);
    const lNome = buf.readUInt16LE(p + 28);
    const lExtra = buf.readUInt16LE(p + 30);
    const lCommento = buf.readUInt16LE(p + 32);
    const offLocale = buf.readUInt32LE(p + 42);
    const nome = buf.slice(p + 46, p + 46 + lNome).toString('utf8');
    const inizioDati = offLocale + 30 + buf.readUInt16LE(offLocale + 26) + buf.readUInt16LE(offLocale + 28);
    const dati = buf.slice(inizioDati, inizioDati + dimCompressa);
    voci[nome] = function () { return metodo === 8 ? zlib.inflateRawSync(dati) : dati; };
    p += 46 + lNome + lExtra + lCommento;
  }
  return voci;
}

function testoDaXml(xml) {
  return decodificaEntita(String(xml).replace(/<w:tab\/>/g, ' ').replace(/<\/w:p>/g, '\n').replace(/<[^>]+>/g, '')).trim();
}

function controllaOffice(buf) {
  const risultati = [];
  const voci = leggiZip(buf);
  if (voci['word/comments.xml']) {
    const commenti = testoDaXml(voci['word/comments.xml']().toString('utf8'));
    if (commenti) {
      const sospetto = controllaIstruzioni(commenti).length > 0;
      risultati.push(segnalazione('metadati', commenti, 'commento nel documento Word' + (sospetto ? ' con frase d\'istruzione' : '')));
    }
  }
  ['docProps/core.xml', 'docProps/app.xml', 'docProps/custom.xml', 'meta.xml'].forEach(function (nome) {
    if (!voci[nome]) return;
    const xml = voci[nome]().toString('utf8');
    const valori = (xml.match(/>([^<]{3,})</g) || []).map(function (v) { return decodificaEntita(v.slice(1, -1)); });
    valori.forEach(function (v) {
      if (v.length > 200 || controllaIstruzioni(v).length) risultati.push(segnalazione('metadati', v, 'proprietà del documento (' + nome + ')'));
    });
  });
  return risultati;
}

// Flussi di un PDF, decompressi quando sono FlateDecode.
function flussiPdf(buf) {
  const flussi = [];
  const testo = buf.toString('latin1');
  const re = /<<([\s\S]*?)>>\s*stream\r?\n/g;
  let m;
  while ((m = re.exec(testo)) !== null) {
    const inizio = m.index + m[0].length;
    const fine = testo.indexOf('endstream', inizio);
    if (fine < 0) break;
    let dati = buf.slice(inizio, fine);
    if (/\/FlateDecode/.test(m[1])) {
      try { dati = zlib.inflateSync(dati); } catch (e) { continue; }
    }
    flussi.push({ dizionario: m[1], contenuto: dati.toString('latin1') });
    re.lastIndex = fine;
  }
  return flussi;
}

// Testo tra parentesi dentro i blocchi BT ... ET, con colore e corpo correnti.
function testiPdf(contenuto) {
  const pezzi = [];
  const reBlocco = /BT([\s\S]*?)ET/g;
  let b;
  while ((b = reBlocco.exec(contenuto)) !== null) {
    let bianco = false;
    let corpo = 12;
    let invisibile = false;
    const reOp = /([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+rg|([\d.]+)\s+g\b|\/[A-Za-z0-9]+\s+([\d.]+)\s+Tf|(\d)\s+Tr|\(((?:\\.|[^\\)])*)\)\s*Tj|\[((?:\\.|[^\]])*)\]\s*TJ/g;
    let o;
    while ((o = reOp.exec(b[1])) !== null) {
      if (o[1] !== undefined) bianco = Number(o[1]) > 0.95 && Number(o[2]) > 0.95 && Number(o[3]) > 0.95;
      else if (o[4] !== undefined) bianco = Number(o[4]) > 0.95;
      else if (o[5] !== undefined) corpo = Number(o[5]);
      else if (o[6] !== undefined) invisibile = o[6] === '3';
      else {
        const grezzo = o[7] !== undefined ? o[7] : (o[8].match(/\(((?:\\.|[^\\)])*)\)/g) || []).map(function (s) { return s.slice(1, -1); }).join('');
        pezzi.push({ testo: grezzo.replace(/\\([()\\])/g, '$1'), bianco: bianco, corpo: corpo, invisibile: invisibile });
      }
    }
  }
  return pezzi;
}

function controllaPdf(buf) {
  const risultati = [];
  const testoGrezzo = buf.toString('latin1');
  flussiPdf(buf).forEach(function (f) {
    if (/\/Type\s*\/Metadata/.test(f.dizionario) || /<x:xmpmeta/.test(f.contenuto)) {
      const valori = (f.contenuto.match(/>([^<]{3,})</g) || []).map(function (v) { return decodificaEntita(v.slice(1, -1)).trim(); }).filter(Boolean);
      valori.forEach(function (v) {
        if (v.length > 200 || controllaIstruzioni(v).length) risultati.push(segnalazione('metadati', v, 'metadati XMP del PDF'));
      });
      return;
    }
    testiPdf(f.contenuto).forEach(function (p) {
      if (p.testo.trim().length < 3) return;
      if (p.bianco) risultati.push(segnalazione('testo_nascosto', p.testo, 'testo bianco nello strato di testo del PDF'));
      else if (p.corpo <= 2) risultati.push(segnalazione('testo_nascosto', p.testo, 'testo in corpo ' + p.corpo + ' nello strato di testo del PDF'));
      else if (p.invisibile) risultati.push(segnalazione('testo_nascosto', p.testo, 'testo con modalità di resa invisibile (3 Tr)'));
    });
  });
  // Dizionario Info: /Title (...) /Subject (...) /Keywords (...)
  const reInfo = /\/(Title|Subject|Keywords|Author|Creator)\s*\(((?:\\.|[^\\)])*)\)/g;
  let m;
  while ((m = reInfo.exec(testoGrezzo)) !== null) {
    if (m[2].length > 200 || controllaIstruzioni(m[2]).length) risultati.push(segnalazione('metadati', m[2], 'proprietà /' + m[1] + ' del PDF'));
  }
  return risultati;
}

// Confronto tra strato di testo e OCR: sequenze di parole presenti solo nello strato di testo.
function normalizzaParole(t) {
  return String(t || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .split(/[^a-z0-9]+/).filter(function (p) { return p.length >= 3; });
}

function confrontaStratoEOcr(stratoTesto, ocr, minimoParole) {
  const soglia = minimoParole || 6;
  const insiemeOcr = {};
  normalizzaParole(ocr).forEach(function (p) { insiemeOcr[p] = true; });
  const parole = normalizzaParole(stratoTesto);
  const sequenze = [];
  let corrente = [];
  parole.forEach(function (p) {
    if (!insiemeOcr[p]) corrente.push(p);
    else { if (corrente.length >= soglia) sequenze.push(corrente.join(' ')); corrente = []; }
  });
  if (corrente.length >= soglia) sequenze.push(corrente.join(' '));
  return sequenze;
}

// ---------------------------------------------------------------------------
// Chiamate HTTP (Tika e web), senza dipendenze.
// ---------------------------------------------------------------------------
function richiesta(indirizzo, opzioni, corpo) {
  return new Promise(function (risolvi, rifiuta) {
    const u = new URL(indirizzo);
    const modulo = u.protocol === 'https:' ? https : http;
    const req = modulo.request(u, Object.assign({ timeout: 120000 }, opzioni), function (res) {
      const pezzi = [];
      let totale = 0;
      res.on('data', function (d) {
        totale += d.length;
        if (totale > MAX_SCARICAMENTO) { req.destroy(new Error('risposta troppo grande')); return; }
        pezzi.push(d);
      });
      res.on('end', function () { risolvi({ stato: res.statusCode, intestazioni: res.headers, corpo: Buffer.concat(pezzi) }); });
    });
    req.on('timeout', function () { req.destroy(new Error('tempo scaduto')); });
    req.on('error', rifiuta);
    if (corpo) req.write(corpo);
    req.end();
  });
}

// ---------------------------------------------------------------------------
// Testo chiaro su fondo chiaro nelle immagini: Tesseract non vede le righe grigio chiaro
// e minuscole. Per i PNG si prepara una copia in scala di grigi con contrasto aumentato
// (grigi tra il 60% e il 95% portati verso il nero) e ingrandita 2-3 volte, che Tika legge
// in un secondo passaggio OCR. Solo PNG a 8 bit non interlacciati; gli altri formati
// passano solo dall'OCR normale.
// ---------------------------------------------------------------------------
const TABELLA_CRC = (function () {
  const t = [];
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    t.push(c >>> 0);
  }
  return t;
})();

function crc32(buf) {
  let c = 0xFFFFFFFF;
  for (let i = 0; i < buf.length; i++) c = TABELLA_CRC[(c ^ buf[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}

function bloccoPng(tipo, dati) {
  const lung = Buffer.alloc(4);
  lung.writeUInt32BE(dati.length, 0);
  const corpo = Buffer.concat([Buffer.from(tipo, 'latin1'), dati]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(corpo), 0);
  return Buffer.concat([lung, corpo, crc]);
}

function pngContrastato(buf) {
  if (buf.length < 33 || buf.slice(1, 4).toString('latin1') !== 'PNG') return null;
  let pos = 8, w = 0, h = 0, profondita = 0, colore = 0, interlacciato = 0;
  const idat = [];
  while (pos + 8 <= buf.length) {
    const lung = buf.readUInt32BE(pos), tipo = buf.slice(pos + 4, pos + 8).toString('latin1');
    const dati = buf.slice(pos + 8, pos + 8 + lung);
    if (tipo === 'IHDR') { w = dati.readUInt32BE(0); h = dati.readUInt32BE(4); profondita = dati[8]; colore = dati[9]; interlacciato = dati[12]; }
    if (tipo === 'IDAT') idat.push(dati);
    if (tipo === 'IEND') break;
    pos += 12 + lung;
  }
  const canali = { 0: 1, 2: 3, 4: 2, 6: 4 }[colore];
  // Il servizio ha 96 MB di memoria: al massimo 16 milioni di pixel dopo l'ingrandimento
  const scala = w * h * 9 <= 16e6 ? 3 : w * h * 4 <= 16e6 ? 2 : 0;
  if (!canali || profondita !== 8 || interlacciato || !scala) return null;
  const grezzo = zlib.inflateSync(Buffer.concat(idat));
  const riga = w * canali;
  const pix = Buffer.alloc(riga * h);
  // Ricostruzione dei filtri PNG (None, Sub, Up, Average, Paeth)
  for (let y = 0; y < h; y++) {
    const f = grezzo[y * (riga + 1)], src = y * (riga + 1) + 1, dst = y * riga;
    for (let x = 0; x < riga; x++) {
      const a = x >= canali ? pix[dst + x - canali] : 0;
      const b = y ? pix[dst - riga + x] : 0;
      const c = x >= canali && y ? pix[dst - riga + x - canali] : 0;
      let p = grezzo[src + x];
      if (f === 1) p += a;
      else if (f === 2) p += b;
      else if (f === 3) p += (a + b) >> 1;
      else if (f === 4) { const pa = Math.abs(b - c), pb = Math.abs(a - c), pc = Math.abs(a + b - 2 * c); p += pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
      pix[dst + x] = p & 0xFF;
    }
  }
  // Grigio (con trasparenza su fondo bianco), livelli 60%–95% → 0–255, ingrandimento
  const W = w * scala, H = h * scala, uscita = Buffer.alloc((W + 1) * H);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = y * riga + x * canali;
      let l = canali >= 3 ? (pix[i] * 299 + pix[i + 1] * 587 + pix[i + 2] * 114) / 1000 : pix[i];
      if (canali === 2 || canali === 4) { const al = pix[i + canali - 1] / 255; l = l * al + 255 * (1 - al); }
      const v = Math.max(0, Math.min(255, Math.round((l - 153) * 255 / (242 - 153))));
      for (let dy = 0; dy < scala; dy++) uscita.fill(v, (y * scala + dy) * (W + 1) + 1 + x * scala, (y * scala + dy) * (W + 1) + 1 + (x + 1) * scala);
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 0;
  return Buffer.concat([buf.slice(0, 8), bloccoPng('IHDR', ihdr), bloccoPng('IDAT', zlib.deflateSync(uscita)), bloccoPng('IEND', Buffer.alloc(0))]);
}

function tika(percorso, buf, intestazioni) {
  return richiesta(TIKA_URL + percorso, { method: 'PUT', headers: Object.assign({ 'Content-Length': buf.length }, intestazioni) }, buf)
    .then(function (r) {
      if (r.stato !== 200) throw new Error('Tika ha risposto ' + r.stato);
      return r.corpo.toString('utf8');
    });
}

// ---------------------------------------------------------------------------
// Controllo completo di un documento.
// ---------------------------------------------------------------------------
function normalizzaTesto(t) {
  return String(t || '').replace(/\r\n?/g, '\n').replace(/[ \t\u00A0]+/g, ' ').replace(/ *\n */g, '\n').replace(/\n{3,}/g, '\n\n').trim();
}

function leggiDaDati(percorso) {
  if (!percorso) return null;
  const pieno = path.resolve(CARTELLA_DATI, String(percorso).replace(/^\/?dati\//, ''));
  if (pieno.indexOf(path.resolve(CARTELLA_DATI) + path.sep) !== 0) throw new Error('percorso fuori dalla cartella dati: ' + percorso);
  return fs.existsSync(pieno) ? fs.readFileSync(pieno) : null;
}

function controllaDocumento(input) {
  const allowlist = leggiAllowlist();
  let testo = input.testo;
  if (testo === undefined && input.doc_id) {
    const b = leggiDaDati('testi/' + input.doc_id + '.txt');
    testo = b ? b.toString('utf8') : '';
  }
  testo = String(testo || '');
  let file = input.file_base64 ? Buffer.from(input.file_base64, 'base64') : leggiDaDati(input.percorso_originale);
  const nome = String(input.nome_file || input.percorso_originale || '').toLowerCase();
  let html = input.html;
  if (html === undefined && input.doc_id) {
    const b = leggiDaDati('testi/' + input.doc_id + '.html');
    if (b) html = b.toString('utf8');
  }
  if (html === undefined && file && /\.html?$/.test(nome)) html = file.toString('utf8');

  let segnalazioni = []
    .concat(controllaInvisibili(testo))
    .concat(controllaIstruzioni(testo))
    .concat(controllaBase64EUrl(testo, allowlist));
  if (html) segnalazioni = segnalazioni.concat(controllaHtml(html)).concat(controllaInvisibili(html));
  if (file && file.slice(0, 5).toString('latin1') === '%PDF-') segnalazioni = segnalazioni.concat(controllaPdf(file));
  if (file && file.readUInt32LE && file.length > 4 && file.readUInt32LE(0) === 0x04034b50) segnalazioni = segnalazioni.concat(controllaOffice(file));
  if (input.metadati && typeof input.metadati === 'object') {
    Object.keys(input.metadati).forEach(function (k) {
      const v = String(input.metadati[k]);
      if (v.length > 300 || controllaIstruzioni(v).length) segnalazioni.push(segnalazione('metadati', v, 'metadato ' + k));
    });
  }

  const passiTika = [];
  const usaTika = input.usa_tika !== false && file;
  if (usaTika && file.slice(0, 5).toString('latin1') === '%PDF-') {
    // Strato di testo contro OCR della pagina: testo solo nello strato = sospetto testo invisibile.
    passiTika.push(Promise.all([
      tika('/tika/text', file, { 'X-Tika-PDFOcrStrategy': 'no_ocr' }),
      tika('/tika/text', file, { 'X-Tika-PDFOcrStrategy': 'ocr_only', 'X-Tika-OCRLanguage': 'ita+eng' })
    ]).then(function (r) {
      return confrontaStratoEOcr(r[0], r[1]).map(function (s) { return segnalazione('testo_nascosto', s, 'testo presente nello strato di testo ma non nell\'OCR della pagina'); });
    }));
  }
  if (usaTika && /\.(png|jpe?g|tiff?|gif|bmp|webp)$/.test(nome)) {
    const varianti = [file];
    const contrastato = /\.png$/.test(nome) ? pngContrastato(file) : null;
    if (contrastato) varianti.push(contrastato);
    varianti.forEach(function (immagine) {
      passiTika.push(tika('/tika/text', immagine, { 'X-Tika-OCRLanguage': 'ita+eng' }).then(function (ocr) {
        return controllaIstruzioni(ocr, 'testo_in_immagine').concat(controllaBase64EUrl(ocr, allowlist));
      }));
    });
  }
  if (usaTika) {
    passiTika.push(richiesta(TIKA_URL + '/meta', { method: 'PUT', headers: { Accept: 'application/json', 'Content-Length': file.length } }, file).then(function (r) {
      const meta = JSON.parse(r.corpo.toString('utf8') || '{}');
      const fuori = [];
      Object.keys(meta).forEach(function (k) {
        if (/^(X-TIKA|Content-Type|Content-Length|resourceName)/i.test(k)) return;
        const v = [].concat(meta[k]).join(' ');
        if (v.length > 300 || controllaIstruzioni(v).length) fuori.push(segnalazione('metadati', v, 'metadato ' + k + ' (Tika)'));
      });
      return fuori;
    }));
  }

  const avvisi = [];
  return Promise.all(passiTika.map(function (p) {
    return p.catch(function (e) { avvisi.push('controllo con Tika non eseguito: ' + e.message); return []; });
  })).then(function (gruppi) {
    gruppi.forEach(function (g) { segnalazioni = segnalazioni.concat(g); });
    // Una sola segnalazione per tipo ed estratto.
    const viste = {};
    segnalazioni = segnalazioni.filter(function (s) {
      const chiave = s.tipo + '|' + s.estratto;
      if (viste[chiave]) return false;
      viste[chiave] = true;
      return true;
    });
    return {
      doc_id: input.doc_id || null,
      sospetto: segnalazioni.length > 0,
      n_segnalazioni: segnalazioni.length,
      segnalazioni: segnalazioni,
      testo_normalizzato: normalizzaTesto(testo),
      avvisi: avvisi
    };
  });
}

// ---------------------------------------------------------------------------
// Web: allowlist, robots.txt, ritardo tra richieste allo stesso dominio.
// ---------------------------------------------------------------------------
const ultimaRichiesta = {};
const cacheRobots = {};

function regoleRobots(testo) {
  // Restituisce i Disallow/Allow validi per il nostro user-agent o per "*".
  const gruppi = [];
  let corrente = null;
  let ultimaEraAgente = false;
  String(testo).split(/\r?\n/).forEach(function (riga) {
    const r = riga.replace(/#.*/, '').trim();
    const m = /^([a-z-]+)\s*:\s*(.*)$/i.exec(r);
    if (!m) return;
    const campo = m[1].toLowerCase();
    if (campo === 'user-agent') {
      if (!ultimaEraAgente) { corrente = { agenti: [], regole: [] }; gruppi.push(corrente); }
      corrente.agenti.push(m[2].toLowerCase());
      ultimaEraAgente = true;
    } else {
      ultimaEraAgente = false;
      if (corrente && (campo === 'disallow' || campo === 'allow')) corrente.regole.push({ consenti: campo === 'allow', percorso: m[2] });
    }
  });
  const nostro = gruppi.filter(function (g) { return g.agenti.some(function (a) { return a !== '*' && 'laboratorioia-romatre'.indexOf(a) === 0; }); });
  const scelti = nostro.length ? nostro : gruppi.filter(function (g) { return g.agenti.indexOf('*') >= 0; });
  return [].concat.apply([], scelti.map(function (g) { return g.regole; }));
}

function robotsConsente(regole, percorso) {
  let migliore = null;
  regole.forEach(function (r) {
    if (!r.percorso) return;
    const re = new RegExp('^' + r.percorso.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*').replace(/\\\$$/, '$'));
    if (re.test(percorso) && (!migliore || r.percorso.length > migliore.percorso.length || (r.percorso.length === migliore.percorso.length && r.consenti))) migliore = r;
  });
  return !migliore || migliore.consenti;
}

function verificaUrl(indirizzo) {
  let u;
  try { u = new URL(indirizzo); } catch (e) { return Promise.resolve({ consentito: false, motivo: 'Indirizzo non valido: controlla di averlo copiato per intero.' }); }
  if (u.protocol !== 'https:' && u.protocol !== 'http:') return Promise.resolve({ consentito: false, motivo: 'Sono ammessi solo indirizzi http o https.' });
  if (!dominioConsentito(u.hostname)) {
    return Promise.resolve({ consentito: false, dominio: u.hostname, motivo: 'Il dominio ' + u.hostname + ' non è nell\'elenco dei domini ammessi (allowlist_domini.txt). Chiedi al docente di valutarlo.' });
  }
  const base = u.protocol + '//' + u.host;
  const promessa = cacheRobots[base] ? Promise.resolve(cacheRobots[base]) : richiesta(base + '/robots.txt', { method: 'GET', headers: { 'User-Agent': USER_AGENT } })
    .then(function (r) { cacheRobots[base] = r.stato === 200 ? regoleRobots(r.corpo.toString('utf8')) : []; return cacheRobots[base]; })
    .catch(function () { return []; });
  return promessa.then(function (regole) {
    const ok = robotsConsente(regole, u.pathname + u.search);
    return { consentito: ok, dominio: u.hostname, robots_consentito: ok, motivo: ok ? 'Dominio ammesso e robots.txt consente la pagina.' : 'Il file robots.txt del sito chiede di non raccogliere questa pagina: non la scarichiamo.' };
  });
}

function attendi(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

function scaricaPagina(indirizzo, salti) {
  return verificaUrl(indirizzo).then(function (v) {
    if (!v.consentito) return Object.assign({ url: indirizzo, scaricato: false }, v);
    const attesa = Math.max(0, (ultimaRichiesta[v.dominio] || 0) + RITARDO_WEB_MS - Date.now());
    return attendi(attesa).then(function () {
      ultimaRichiesta[v.dominio] = Date.now();
      return richiesta(indirizzo, { method: 'GET', headers: { 'User-Agent': USER_AGENT, Accept: 'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.5' } });
    }).then(function (r) {
      if (r.stato >= 300 && r.stato < 400 && r.intestazioni.location && (salti || 0) < 3) {
        return scaricaPagina(new URL(r.intestazioni.location, indirizzo).toString(), (salti || 0) + 1);
      }
      const tipo = String(r.intestazioni['content-type'] || '');
      const corpo = r.corpo.toString('utf8');
      const isHtml = /html/i.test(tipo) || /^\s*<(!doctype|html)/i.test(corpo);
      const titolo = isHtml ? decodificaEntita(((/<title[^>]*>([\s\S]*?)<\/title>/i.exec(corpo) || [])[1] || '').trim()) : '';
      const leggibile = isHtml ? corpo.replace(/<(nav|header|footer|aside|form)[\s\S]*?<\/\1>/gi, ' ') : corpo;
      return {
        url: indirizzo,
        scaricato: r.stato === 200,
        stato_http: r.stato,
        motivo: r.stato === 200 ? 'Pagina scaricata.' : 'Il sito ha risposto con il codice ' + r.stato + '.',
        dominio: v.dominio,
        tipo_contenuto: tipo,
        titolo: titolo,
        html: isHtml ? corpo : '',
        testo: normalizzaTesto(isHtml ? testoDaHtml(leggibile) : corpo),
        data_scaricamento: new Date().toISOString()
      };
    });
  });
}

// ---------------------------------------------------------------------------
// Azioni del pannello: preferenze lette dal launcher al prossimo avvio.
// Scrivono solo tre file in .stato; nessun altro effetto.
// ---------------------------------------------------------------------------
const CARTELLA_STATO = process.env.CARTELLA_STATO || '/stato';

function azionePannello(percorso, input) {
  if (percorso === '/azioni/profilo') {
    const p = String(input.profilo || '');
    if (p === 'automatico') { try { fs.unlinkSync(path.join(CARTELLA_STATO, 'profilo-scelto')); } catch (e) { /* già assente */ } }
    else if (p === 'standard' || p === 'leggero') fs.writeFileSync(path.join(CARTELLA_STATO, 'profilo-scelto'), p + '\n');
    else return { ok: false, messaggio: 'Profilo sconosciuto.' };
    return { ok: true, messaggio: 'Preferenza salvata. Fai doppio clic su «Avvia laboratorio» per applicarla.' };
  }
  const facoltativi = { '/azioni/neo4j': 'neo4j-attivo', '/azioni/docling': 'docling-attivo' };
  if (facoltativi[percorso]) {
    const f = path.join(CARTELLA_STATO, facoltativi[percorso]);
    if (input.attivo === true) fs.writeFileSync(f, 'si\n');
    else { try { fs.unlinkSync(f); } catch (e) { /* già assente */ } }
    return { ok: true, messaggio: 'Preferenza salvata. Fai doppio clic su «Avvia laboratorio» per applicarla.' };
  }
  return null;
}

// ---------------------------------------------------------------------------
// Server HTTP.
// ---------------------------------------------------------------------------
function rispondi(res, stato, oggetto) {
  const corpo = JSON.stringify(oggetto);
  res.writeHead(stato, { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': Buffer.byteLength(corpo) });
  res.end(corpo);
}

function avvia() {
  const server = http.createServer(function (req, res) {
    if (req.method === 'GET' && req.url === '/salute') return rispondi(res, 200, { stato: 'ok', servizio: 'controlli' });
    if (req.method !== 'POST') return rispondi(res, 404, { errore: 'Percorso sconosciuto.' });
    const pezzi = [];
    req.on('data', function (d) { pezzi.push(d); });
    req.on('end', function () {
      let input;
      try { input = JSON.parse(Buffer.concat(pezzi).toString('utf8') || '{}'); } catch (e) { return rispondi(res, 400, { errore: 'Richiesta non valida: serve un JSON.' }); }
      let lavoro;
      if (req.url.indexOf('/azioni/') === 0) {
        // Solo dal pannello: l'intestazione personalizzata blocca le richieste di altri siti.
        if (req.headers['x-laboratorio'] !== '1') return rispondi(res, 403, { errore: 'Azione consentita solo dal pannello del laboratorio.' });
        const esito = azionePannello(req.url, input);
        return esito ? rispondi(res, 200, esito) : rispondi(res, 404, { errore: 'Azione sconosciuta.' });
      }
      if (req.url === '/controlla') lavoro = controllaDocumento(input);
      else if (req.url === '/web/verifica') lavoro = verificaUrl(input.url);
      else if (req.url === '/web/scarica') lavoro = scaricaPagina(input.url);
      else return rispondi(res, 404, { errore: 'Percorso sconosciuto.' });
      lavoro.then(function (r) { rispondi(res, 200, r); }, function (e) { rispondi(res, 500, { errore: 'Controllo non riuscito: ' + e.message }); });
    });
  });
  server.listen(PORTA, '0.0.0.0', function () { console.log('controlli in ascolto sulla porta ' + PORTA); });
}

if (require.main === module) avvia();

module.exports = {
  rendiInerte: rendiInerte,
  controllaInvisibili: controllaInvisibili,
  controllaIstruzioni: controllaIstruzioni,
  controllaBase64EUrl: controllaBase64EUrl,
  controllaHtml: controllaHtml,
  controllaPdf: controllaPdf,
  controllaOffice: controllaOffice,
  confrontaStratoEOcr: confrontaStratoEOcr,
  pngContrastato: pngContrastato,
  controllaDocumento: controllaDocumento,
  regoleRobots: regoleRobots,
  robotsConsente: robotsConsente,
  dominioConsentito: dominioConsentito,
  normalizzaTesto: normalizzaTesto,
  azionePannello: azionePannello,
  testoDaHtml: testoDaHtml
};
