#!/usr/bin/env node
'use strict';

// Converts Chronicle export strings (made by Oath NF TTS Chronicle Exporter) to and from JSON.
// Card, relic, edifice and site names live in the MAPPING object below.
//
//   node chronicle-codec.js decode <export string | ->      export string -> JSON on stdout
//   node chronicle-codec.js inspect <export string | ->     readable breakdown of every section, for validation
//   node chronicle-codec.js encode <file.json | ->          JSON -> export string on stdout
//   node chronicle-codec.js selftest
//   Add --plain to skip the version/scramble/checksum wrapper (the raw string the exporter builds before scrambling)
//
//   Pass export strings in single quotes: '02H3uk...' (' is not in the alphabet, so nothing inside needs escaping).
//   Double quotes corrupt them, since $ starts a variable in PowerShell and bash. Or pipe it in: Get-Clipboard | node chronicle-codec.js inspect -
//
// Also usable as a module: decodeExportString, encodeExportObject, decodeChronicle, encodeChronicle, inspectExportString

const fs = require('fs');

const ENCODING_VERSION = 2;
const SCRAMBLE_SEED = 468529063; // Random seed for scrambling world output to make it less readable
// Our 'Base82' alphabet. Printable ASCII minus ' \ ` * _ | [ ] < and ", so it is safe to use in most places
const BASE82 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+-=/~!@$%^&(){};:,.?';
const BASE82_PLUS = BASE82 + '#>'; //Base82 with the structural characters
const CHECKSUM_MODULUS = 82 * 82;
const DECK_RADIX = 400;   // World Deck and Dispossessed: card ids
const RELIC_RADIX = 100;  // Relic Deck: relic id - RELIC_ID_OFFSET (1-47)
const RELIC_ID_OFFSET = 400;
const CHUNK_SIZE = 5;     // ids per chunk
const CHUNK_WIDTH = 7;    // base-82 characters per chunk

// Players get one section each, in this order. A player with nothing is an empty section (so '>>' in the string)
const PLAYER_COLORS = ['red', 'blue', 'yellow', 'black', 'white', 'brown', 'pink'];

// Order the exporter writes its sections, each separated by '>' character. Player sections are named 'players.<color>'
const SECTIONS = ['atlasBox', 'world', 'worldDeck', 'relicDeck', 'dispossessed', 'reliquary', 'foundations',
    ...PLAYER_COLORS.map(color => `players.${color}`)];

// ---------- base 82 encoding/deconding ----------

// Converts a positive number to base82 string
function toBase82(value) {
    if (!Number.isSafeInteger(value) || value < 0) throw new Error(`Cannot encode ${value} exactly`);
    let n = value;
    if (n === 0) return BASE82[0];
    let result = '';
    while (n > 0) {
        result = BASE82[n % 82] + result;
        n = Math.floor(n / 82);
    }
    return result;
}

// Converts base82 string to a positive number
function fromBase82(text) {
    let n = 0;
    for (const c of text) {
        const digit = BASE82.indexOf(c);
        if (digit < 0) throw new Error(`Invalid base-82 character "${c}"`);
        n = n * 82 + digit;
    }
    if (!Number.isSafeInteger(n)) throw new Error(`Value too large to decode exactly: ${text}`);
    return n;
}

//Encodes with extra 0s in front to fit a width
const padEncode = (value, width) => toBase82(value).padStart(width, BASE82[0]);

// ---------- scramble and checksum ----------

const mod = (a, m) => ((a % m) + m) % m; // forces positive modulo, like Lua's %

// To prevent the chronicle export from being readable, we scramble it in a deterministic, length-agnostic way
function scramble(input, isDecoding) {
    const n = BASE82_PLUS.length;
    let seed = SCRAMBLE_SEED;
    let result = '';
    for (const c of input) { // For each 'digit' of our input
        seed = (seed * 16807) % 2147483647; // Modify the seed
        const idx = BASE82_PLUS.indexOf(c);
        if (idx < 0) throw new Error(`scramble: invalid character "${c}" in string`);
        if (!isDecoding) {
            result += BASE82_PLUS[mod(idx + seed, n)]; // Shift the digit forward by our seed (wrapping around). Then write it to ouput.
            seed = (seed + idx) % 2147483647; // Shift the seed based on the digit as well
        } else {
            const realIdx = mod(idx - seed, n); // Shift the scrambled digit backward by our seed (wrapping around)
            result += BASE82_PLUS[realIdx]; // Write the true digit to output
            seed = (seed + realIdx) % 2147483647; // Shift the seed based on the true digit
        }
    }
    return result;
}

// Returns the sum of all Base82+ characters mod 82^2 to verify correctness
function checksum(text) {
    let sum = 0;
    for (let i = 0; i < text.length; i++) {
        sum = (sum + (i + 1) * BASE82_PLUS.indexOf(text[i])) % CHECKSUM_MODULUS;
    }
    return sum;
}


// ---------- Id->Name mapping tools ----------

let cachedData = null;

function loadMapping() {
    if (cachedData) return cachedData;
    const idToName = new Map();
    const nameToId = new Map();
    for (const [id, name] of Object.entries(MAPPING.ids)) {
        idToName.set(Number(id), name);
        nameToId.set(name, Number(id));
    }

    const siteIdToName = new Map();
    const siteNameToId = new Map();
    for (const [name, id] of Object.entries(MAPPING.sites)) {
        if (!siteIdToName.has(id)) siteIdToName.set(id, name);
        siteNameToId.set(name, id);
    }

    const legacyIdToName = new Map();
    const legacyNameToId = new Map();
    for (const [id, name] of Object.entries(MAPPING.legacies)) {
        legacyIdToName.set(Number(id), name);
        legacyNameToId.set(name, Number(id));
    }

    cachedData = { idToName, nameToId, siteIdToName, siteNameToId, legacyIdToName, legacyNameToId };
    return cachedData;
}

function lookup(map, key, what) {
    if (!map.has(key)) throw new Error(`Unknown ${what}: ${key}`);
    return map.get(key);
}

// Card ids: 1-399 deck cards, 401-447 relics
const isCardId = id => id >= 1 && id < 400;
const isRelicId = id => id > RELIC_ID_OFFSET && id < 500;

// ---------- sites (Atlas Box and Empire) ----------
// Each site is one token: the site index in the lowest 2 digits, then each item (card/relic/edifice) id in 3 digits above it:
// siteIndex + item1 * 100 + item2 * 100000 + item3 * 100000000
// or [Item3 in 3 digits][Item2 in 3 digits][Item1 in 3 digits][Site in 2 digits]

function encodeSite({ site, items }) {
    const data = loadMapping();
    let n = lookup(data.siteNameToId, site, 'site');
    let mult = 100;
    for (const name of items) {
        n += lookup(data.nameToId, name, 'card') * mult;
        mult *= 1000;
    }
    return toBase82(n);
}

function decodeSite(token) {
    const data = loadMapping();
    let n = fromBase82(token);
    const site = lookup(data.siteIdToName, n % 100, 'site index');
    n = Math.floor(n / 100);
    const items = [];
    while (n > 0) {
        items.push(lookup(data.idToName, n % 1000, 'card id'));
        n = Math.floor(n / 1000);
    }
    return { site, items };
}

// The AtlasBox/Empire section is a list of per-site tokens, each ending in '#'
function encodeSites(sites) { 
    return sites.map(site => encodeSite(site) + '#').join('');
}

function decodeSites(section) {
    return section === '' ? [] : section.split('#').slice(0, -1).map(decodeSite);
}


// ---------- decks (World Deck, Relic Deck, Dispossessed) ----------
// Decks are stored in chunks. Every CHUNK_SIZE (currently 5) items is encoded, then padded out to CHUNK_WIDTH (currently 7) digits, then appended.
// Chunks are outputted such that the rightmost is the first chunk read and leftmost is the last.
// Similar to site compression, when making a chunk we multiply items so theyre spread out by digit (3 digits for cards, 2 for relics)

function packIds(ids, radix) {
    let result = '';
    for (let i = 0; i < ids.length; i += CHUNK_SIZE) {
        let n = 0;
        let mult = 1;
        for (const id of ids.slice(i, i + CHUNK_SIZE)) {
            if (id < 1 || id >= radix) throw new Error(`Id ${id} does not fit in radix ${radix}`);
            n += id * mult;
            mult *= radix;
        }
        result = padEncode(n, CHUNK_WIDTH) + result;
    }
    return result;
}

function unpackIds(section, radix) {
    if (section.length % CHUNK_WIDTH !== 0) {
        throw new Error(`Deck section length ${section.length} is not a multiple of ${CHUNK_WIDTH}`);
    }
    const chunks = [];
    for (let i = 0; i < section.length; i += CHUNK_WIDTH) chunks.push(section.slice(i, i + CHUNK_WIDTH));
    const ids = [];
    for (const chunk of chunks.reverse()) {
        let n = fromBase82(chunk);
        for (let k = 0; k < CHUNK_SIZE && n > 0; k++) {
            ids.push(n % radix);
            n = Math.floor(n / radix);
        }
    }
    return ids;
}

function encodeCardDeck(names) {
    const data = loadMapping();
    return packIds(names.map(name => {
        const id = lookup(data.nameToId, name, 'card');
        if (!isCardId(id)) throw new Error(`${name} is not a deck card`);
        return id;
    }), DECK_RADIX);
}

function decodeCardDeck(section) {
    const data = loadMapping();
    return unpackIds(section, DECK_RADIX).map(id => {
        if (!isCardId(id)) throw new Error(`Id ${id} is not a deck card`);
        return lookup(data.idToName, id, 'card id');
    });
}

const encodeRelicDeck = names => {
    const data = loadMapping();
    return packIds(names.map(name => {
        const id = lookup(data.nameToId, name, 'relic');
        if (!isRelicId(id)) throw new Error(`${name} is not a relic`);
        return id - RELIC_ID_OFFSET;
    }), RELIC_RADIX);
};

const decodeRelicDeck = section => {
    const data = loadMapping();
    return unpackIds(section, RELIC_RADIX).map(id => lookup(data.idToName, id + RELIC_ID_OFFSET, 'relic id'));
};

// ---------- small lists (Reliquary, player cards, player relics) ----------
// Every id is packed into one unpadded number. Holds at most 6 cards/legacies or 7 relics

function packNumber(ids, radix) {
    let n = 0;
    let mult = 1;
    for (const id of ids) {
        if (id < 1 || id >= radix) throw new Error(`Id ${id} does not fit in radix ${radix}`);
        n += id * mult;
        mult *= radix;
    }
    return n === 0 ? '' : toBase82(n); // toBase82 throws if the list is too long to be exact
}

function unpackNumber(text, radix) {
    let n = text === '' ? 0 : fromBase82(text);
    const ids = [];
    while (n > 0) {
        ids.push(n % radix);
        n = Math.floor(n / radix);
    }
    return ids;
}

const relicIdOf = (data, name) => {
    const id = lookup(data.nameToId, name, 'relic');
    if (!isRelicId(id)) throw new Error(`${name} is not a relic`);
    return id - RELIC_ID_OFFSET;
};
const relicNameOf = (data, id) => lookup(data.idToName, id + RELIC_ID_OFFSET, 'relic id');

// ---------- Reliquary ----------
// A list of relics as one number. Skipping the step writes an empty section and an empty Reliquary writes '0', both read as []

function encodeReliquary(names) {
    const data = loadMapping();
    return packNumber(names.map(name => relicIdOf(data, name)), RELIC_RADIX);
}

function decodeReliquary(section) {
    const data = loadMapping();
    return unpackNumber(section, RELIC_RADIX).map(id => relicNameOf(data, id));
}

// ---------- Foundations ----------
// A bitmask of the flipped Foundations: Foundation I is 1, II is 2, III is 4 and so on

function encodeFoundations(names) {
    let mask = 0;
    for (const name of names) {
        const bit = MAPPING.foundations.indexOf(name);
        if (bit < 0) throw new Error(`Unknown Foundation: ${name}`);
        mask |= 1 << bit;
    }
    return toBase82(mask);
}

function decodeFoundations(section) {
    const mask = section === '' ? 0 : fromBase82(section);
    if (mask >= 1 << MAPPING.foundations.length) throw new Error(`Invalid Foundations value: ${section}`);
    return MAPPING.foundations.filter((_, bit) => mask & (1 << bit));
}

// ---------- players ----------
// [status: 1 digit][cards]#[legacies]#[relics]
// status: 0 Exile, 1 Citizen, 2 Chancellor. Cards and relicsare single numbers.
// Legacies are id + LEGACY_FLIPPED if flipped, in radix 200. Fewer than CHUNK_SIZE are one unpadded number (at most 5 characters),
// otherwise they are packed like a deck (a multiple of CHUNK_WIDTH characters), so the length tells the two apart.
// A player missing from the export is written as an empty Exile, '0##'

const STATUSES = ['Exile', 'Citizen', 'Chancellor'];
const LEGACY_RADIX = 200;
const LEGACY_FLIPPED = 100;

function encodeLegacies(legacies) {
    const data = loadMapping();
    const values = legacies.map(({ name, flipped }) =>
        lookup(data.legacyNameToId, name, 'legacy') + (flipped ? LEGACY_FLIPPED : 0));
    return values.length < CHUNK_SIZE ? packNumber(values, LEGACY_RADIX) : packIds(values, LEGACY_RADIX);
}

function decodeLegacies(field) {
    const data = loadMapping();
    const values = field.length < CHUNK_WIDTH ? unpackNumber(field, LEGACY_RADIX) : unpackIds(field, LEGACY_RADIX);
    return values.map(value => ({
        name: lookup(data.legacyIdToName, value % LEGACY_FLIPPED, 'legacy id'),
        flipped: value > LEGACY_FLIPPED,
    }));
}

function encodePlayer({ status = 'Exile', cards = [], legacies = [], relics = [] }) {
    const data = loadMapping();
    const statusNum = STATUSES.indexOf(status);
    if (statusNum < 0) throw new Error(`Unknown player status: ${status}`);
    const cardIds = cards.map(name => {
        const id = lookup(data.nameToId, name, 'card');
        if (!isCardId(id)) throw new Error(`${name} is not a deck card`);
        return id;
    });
    return toBase82(statusNum) + packNumber(cardIds, DECK_RADIX) + '#'
        + encodeLegacies(legacies) + '#'
        + packNumber(relics.map(name => relicIdOf(data, name)), RELIC_RADIX);
}

function decodePlayer(section) {
    const data = loadMapping();
    const fields = section.split('#');
    if (fields.length !== 3) throw new Error(`Player section should have 3 fields, found ${fields.length}: ${section}`);
    const [head, legacies, relics] = fields;
    const status = STATUSES[BASE82.indexOf(head[0])];
    if (!status) throw new Error(`Invalid player status in: ${section}`);
    return {
        status,
        cards: unpackNumber(head.slice(1), DECK_RADIX).map(id => {
            if (!isCardId(id)) throw new Error(`Id ${id} is not a deck card`);
            return lookup(data.idToName, id, 'card id');
        }),
        legacies: decodeLegacies(legacies),
        relics: unpackNumber(relics, RELIC_RADIX).map(id => relicNameOf(data, id)),
    };
}

// ---------- whole chronicle ----------

const CODECS = {
    atlasBox: { decode: decodeSites, encode: encodeSites },
    world: { decode: decodeSites, encode: encodeSites },
    worldDeck: { decode: decodeCardDeck, encode: encodeCardDeck },
    relicDeck: { decode: decodeRelicDeck, encode: encodeRelicDeck },
    dispossessed: { decode: decodeCardDeck, encode: encodeCardDeck },
    reliquary: { decode: decodeReliquary, encode: encodeReliquary },
    foundations: { decode: decodeFoundations, encode: encodeFoundations },
};
for (const color of PLAYER_COLORS) {
    CODECS[`players.${color}`] = { decode: decodePlayer, encode: encodePlayer };
}

// 'players.red' lives at chronicle.players.red, every other key at chronicle[key]
function getSection(chronicle, key) {
    const [group, color] = key.split('.');
    return color ? (chronicle[group] || {})[color] : chronicle[group];
}

function setSection(chronicle, key, value) {
    const [group, color] = key.split('.');
    if (color) {
        chronicle[group] = chronicle[group] || {};
        chronicle[group][color] = value;
    } else {
        chronicle[group] = value;
    }
}

// The unscrambled string: every section separated by '>'
function encodeChronicle(chronicle) {
    const values = SECTIONS.map(key => getSection(chronicle, key));
    let count = values.length;
    while (count > 0 && values[count - 1] === undefined) count--; // sections are written in order, so stop after the last one present
    // A missing section before that point is written empty, which keeps every later section in its place
    return SECTIONS.slice(0, count)
        .map((key, i) => values[i] === undefined ? '' : CODECS[key].encode(values[i]))
        .join('>');
}

// Every '>' starts a new section, including a trailing one (a string ending in '>' ends with an empty section)
function decodeChronicle(plain) {
    const sections = plain.split('>');
    if (sections.length > SECTIONS.length) throw new Error(`Expected at most ${SECTIONS.length} sections, found ${sections.length}`);
    const chronicle = {};
    sections.forEach((section, i) => {
        setSection(chronicle, SECTIONS[i], CODECS[SECTIONS[i]].decode(section));
    });
    return chronicle;
}

// The string users copy: a 2-character version number for this encoding, the scrambled chronicle, then a 2-character checksum of the plain chronicle
function encodeExportObject(chronicle) {
    const plain = encodeChronicle(chronicle);
    return padEncode(ENCODING_VERSION, 2) + scramble(plain, false) + padEncode(checksum(plain), 2);
}

function decodeExportString(exportString) {
    const text = exportString.replace(/\s/g, '');
    if (text.length < 5) throw new Error('Export string is too short');
    if (text.slice(0, 2) !== padEncode(ENCODING_VERSION, 2)) {
        throw new Error(`This export string uses a different encoding version (expected ${ENCODING_VERSION})`);
    }
    const plain = scramble(text.slice(2, -2), true);
    if (text.slice(-2) !== padEncode(checksum(plain), 2)) {
        throw new Error('Checksum failure, the export string is likely corrupted');
    }
    return { version: ENCODING_VERSION, ...decodeChronicle(plain) };
}

// ---------- inspect ----------
// A readable breakdown of an export string for validation: every section's raw text, split into its tokens/chunks,
// with the number each one encodes, the ids inside it and their names. Problems are reported inline instead of thrown.

function inspectExportString(exportString, isPlain = false) {
    const lines = [];
    let problems = 0;
    const problem = message => { problems++; return `!! ${message}`; };
    // Runs fn and returns its text, or the error as a problem line
    const attempt = fn => { try { return fn(); } catch (err) { return problem(err.message); } };

    let plain = exportString.replace(/\s/g, '');
    if (!isPlain) {
        const version = plain.slice(0, 2);
        const body = plain.slice(2, -2);
        const check = plain.slice(-2);
        lines.push(`Version   ${version}` + (version === padEncode(ENCODING_VERSION, 2) ? '' : `  ${problem(`expected ${padEncode(ENCODING_VERSION, 2)}`)}`));
        plain = attempt(() => scramble(body, true));
        if (plain.startsWith('!!')) return { text: [...lines, plain].join('\n'), problems };
        const expected = padEncode(checksum(plain), 2);
        lines.push(`Checksum  ${check}` + (check === expected ? '  ok' : `  ${problem(`expected ${expected}, the string is corrupted`)}`));
        lines.push(`Plain     ${plain}`);
    }

    const data = loadMapping();
    const idList = (ids, nameOf) => ids.map(id => `${id} ${attempt(() => nameOf(id))}`).join(', ');
    const cardName = id => { if (!isCardId(id)) throw new Error(`${id} is not a deck card`); return lookup(data.idToName, id, 'card id'); };
    const relicName = id => relicNameOf(data, id);
    const legacyName = v => `${lookup(data.legacyIdToName, v % LEGACY_FLIPPED, 'legacy id')}${v > LEGACY_FLIPPED ? ' (flipped)' : ''}`;
    const row = (raw, value, detail) => `    ${raw.padEnd(CHUNK_WIDTH)} = ${String(value).padEnd(14)} ${detail}`;
    const single = (label, raw, radix, nameOf) => raw === ''
        ? `  ${label}(none)`
        : attempt(() => { const n = fromBase82(raw); return `  ${label}${row(raw, n, idList(unpackNumber(raw, radix), nameOf)).trimStart()}`; });
    const chunked = (raw, radix, nameOf) => {
        if (raw.length % CHUNK_WIDTH !== 0) return [`    ${problem(`length ${raw.length} is not a multiple of ${CHUNK_WIDTH}`)}`];
        const chunks = [];
        for (let i = raw.length - CHUNK_WIDTH; i >= 0; i -= CHUNK_WIDTH) chunks.push(raw.slice(i, i + CHUNK_WIDTH)); // first chunk is rightmost
        return chunks.map(chunk => attempt(() => row(chunk, fromBase82(chunk), idList(unpackIds(chunk, radix), nameOf))));
    };

    const sections = plain.split('>');
    if (sections.length > SECTIONS.length) lines.push(problem(`expected at most ${SECTIONS.length} sections, found ${sections.length}`));
    sections.forEach((raw, i) => {
        const key = SECTIONS[i] || `extra${i + 1}`;
        lines.push('', `[${i + 1}] ${key}  (${raw.length} chars)  ${raw}`);
        if (key === 'atlasBox' || key === 'world') {
            const tokens = raw.split('#');
            if (tokens.pop() !== '') lines.push(`    ${problem('section should end with #')}`);
            for (const token of tokens) {
                lines.push(attempt(() => {
                    let n = fromBase82(token);
                    const site = `${n % 100} ${attempt(() => lookup(data.siteIdToName, n % 100, 'site index'))}`;
                    const items = [];
                    for (n = Math.floor(n / 100); n > 0; n = Math.floor(n / 1000)) items.push(n % 1000);
                    return row(token, fromBase82(token), `site ${site}` + (items.length ? ` | ${idList(items, id => lookup(data.idToName, id, 'card id'))}` : ''));
                }));
            }
        } else if (key === 'worldDeck' || key === 'dispossessed') {
            lines.push(...chunked(raw, DECK_RADIX, cardName));
        } else if (key === 'relicDeck') {
            lines.push(...chunked(raw, RELIC_RADIX, relicName));
        } else if (key === 'reliquary') {
            lines.push(single('', raw, RELIC_RADIX, relicName));
        } else if (key === 'foundations') {
            lines.push(attempt(() => {
                const mask = raw === '' ? 0 : fromBase82(raw);
                const flipped = MAPPING.foundations.map((name, bit) => mask & (1 << bit) ? `${bit + 1} ${name}` : null).filter(Boolean);
                if (mask >= 1 << MAPPING.foundations.length) throw new Error(`bitmask ${mask} has bits past Foundation ${MAPPING.foundations.length}`);
                return row(raw, `0b${mask.toString(2).padStart(MAPPING.foundations.length, '0')}`, flipped.length ? `flipped: ${flipped.join(', ')}` : 'none flipped');
            }));
        } else if (key.startsWith('players.')) {
            const fields = raw.split('#');
            if (fields.length !== 3) { lines.push(`    ${problem(`expected 3 fields separated by #, found ${fields.length}`)}`); return; }
            const [head, legacies, relics] = fields;
            const status = STATUSES[BASE82.indexOf(head[0])];
            lines.push(`    status    ${head[0] || ''} = ${status || problem(`invalid status "${head[0] || ''}"`)}`);
            lines.push(single('  cards     ', head.slice(1), DECK_RADIX, cardName));
            if (legacies.length < CHUNK_WIDTH) {
                lines.push(single('  legacies  ', legacies, LEGACY_RADIX, legacyName));
            } else {
                lines.push(`    legacies  (${legacies.length / CHUNK_WIDTH} chunks)`, ...chunked(legacies, LEGACY_RADIX, legacyName));
            }
            lines.push(single('  relics    ', relics, RELIC_RADIX, relicName));
        }
    });

    // The decoded chronicle must encode back to the same plain string
    lines.push('');
    try {
        const roundTrip = encodeChronicle(decodeChronicle(plain));
        lines.push(roundTrip === plain ? 'Round trip  ok' : problem(`round trip differs:\n   ${roundTrip}`));
    } catch (err) {
        lines.push(problem(`round trip failed: ${err.message}`));
    }
    lines.push(problems === 0 ? 'No problems found' : `${problems} problem(s) found`);
    return { text: lines.join('\n'), problems };
}

// ---------- command line ----------

function readArg(arg) {
    return arg === '-' ? fs.readFileSync(0, 'utf8') : arg;
}

function selfTest() {
    const assert = require('assert');
    // A plain chronicle string as the exporter produces it to test (Atlas Box, Empire, World Deck, Relic Deck, Dispossessed)
    const plain = 'M#5#F#7f,#6#66)#7#8#K#623#:n@-#7sK#1#0#)oy~#6Bu#6f6#L#6cv#,&CK#3#6M/#>' +
                  'D&1?8w#8U{9#>' +
                  '7+-x;V08oZ8huHKQPKOQ4J)es4@aDMR,5JBHv,5)~EF/OybDN2D5rps-D;1311dFNUBqTQ6L~;A5a>' +
                  '00yuz%g00g:LA100{N:i(01IG=nz00il1!!012G;R2>' +
                  '00005QqFZ:dW^&Hg{t!5-4ONLOau9x/yb37AIM2pZqK@pO3p00/c17BaBG-@qHk';
    const chronicle = decodeChronicle(plain);
    assert.strictEqual(chronicle.worldDeck.length, 55, 'World Deck should have 55 cards');
    assert.strictEqual(encodeChronicle(chronicle), plain, 'plain round trip');

    const exported = encodeExportObject(chronicle);
    assert.deepStrictEqual(decodeExportString(exported), { version: ENCODING_VERSION, ...chronicle }, 'export round trip');
    assert.deepStrictEqual(decodeExportString(`\n ${exported} \n`), { version: ENCODING_VERSION, ...chronicle }, 'whitespace is ignored');

    // Any changed character in the middle must fail the checksum
    const bad = exported.slice(0, 10) + (exported[10] === 'a' ? 'b' : 'a') + exported.slice(11);
    assert.throws(() => decodeExportString(bad), /Checksum failure/);

    // A skipped Reliquary (empty section) and an empty one ('0') both read as no relics
    assert.deepStrictEqual(decodeChronicle(plain + '>').reliquary, []);
    assert.deepStrictEqual(decodeChronicle(plain + '>0').reliquary, []);

    // Legacies: fewer than 5 are one unpadded number, 5 or more are packed in 7-character chunks
    const legacies = ['Iron Hand', 'Chronicler', 'Steadfast', 'Peacemaker', 'The Needle', 'Pathfinder']
        .map((name, i) => ({ name, flipped: i % 2 === 1 }));
    for (const count of [0, 1, 4, 5, 6]) {
        const player = { status: 'Citizen', cards: ['Scouts'], legacies: legacies.slice(0, count), relics: ['Whistle'] };
        const field = encodePlayer(player).split('#')[1];
        assert.ok(count < 5 ? field.length <= 5 : field.length % CHUNK_WIDTH === 0, `legacy field length for ${count}`);
        assert.deepStrictEqual(decodePlayer(encodePlayer(player)), player, `player round trip with ${count} legacies`);
    }
    assert.throws(() => encodePlayer({ cards: Array(7).fill('Scouts') }), /exactly/, 'more than 6 player cards cannot be exact');

    // Every Foundation combination round trips
    for (let mask = 0; mask < 64; mask++) {
        const flipped = MAPPING.foundations.filter((_, bit) => mask & (1 << bit));
        assert.deepStrictEqual(decodeFoundations(encodeFoundations(flipped)), flipped);
    }

    // A full version 2 export from the Lua exporter in TTS, with Reliquary, Foundations and players (flipped legacies included).
    // Re-encoding it must give the exact same string, which checks that Lua and JS agree
    const fullExport = '02H3uk5&m#lvuYL;KIO:Mg9FjOs)5.yU!bk{6k9tUwlHwZ}z%uTY3.}IvkwdiP9.r)s-g,XAxa!)JRjGCc5ze$;93~2=J;chc)06a}66Pn:tI#vWs~QDbnK5PpZ#&Xq36lcTLE-g359{rq/DBYLh@RBb~R;?$:iMT},~=/N@)J+fh9Ip8T1#dMl?Gf:M?tM%r/8%cL,lF{RGZOorax@0pONlP@9O.&SmJ>G6bq2t^7FJFmI>W$a,3r4:&ohBXUX)$&d%DuAJl%i~Y,c)@b!/eoUQ9Qs!w223^(:%Lf.{eA5@(1u^DqWE$Kv#=iyHXC/5T';
    const full = decodeExportString(fullExport);
    assert.deepStrictEqual(full.reliquary, ['Spiteful Mirror', 'Sigil of the Eye', 'Whistle', 'Lost Tapestry', 'Cracked Horn']);
    assert.deepStrictEqual(full.foundations, ['Teeming World']);
    assert.deepStrictEqual(full.players.yellow, {
        status: 'Chancellor', cards: ['Scouts'], relics: [],
        legacies: [{ name: 'Light Fingers', flipped: false }, { name: 'Arbiter', flipped: true }],
    });
    assert.deepStrictEqual(full.players.brown.legacies, [
        { name: 'Beloved', flipped: true }, { name: 'The Ear', flipped: false }, { name: 'Chronicler', flipped: true }]);
    assert.deepStrictEqual(full.players.black, { status: 'Exile', cards: [], legacies: [], relics: [] });
    const { version, ...fullChronicle } = full;
    assert.strictEqual(encodeExportObject(fullChronicle), fullExport, 'full Lua export round trip');

    // A pair from one run of the real Lua exporter in TTS: the plain string, and the scrambled string it produced.
    // The plain string ends in '>', which leaves an empty (skipped) reliquary section.
    // Re-encoded from a version 1 run for the version 2 alphabet (the full export above covers Lua and JS agreeing)
    const luaPlain = 'M#5#F#7f,#6#66)#7#8#K#623#:n@-#7sK#1#0#)oy~#6Bu#6f6#L#6cv#,&CK#3#6M/#>' +
                     'D&1?8w#8U{9#>' +
                     '7+-x;V08oZ8huHKQPKOQ4J)es4@aDMR,5JBHv,5)~EF/OybDN2D5rps-D;1311dFNUBqTQ6L~;A5a>' +
                     '00wjXpz00,,9Hd00cGcDm00aVgF=00F?%0}00i%s(Z>' +
                     '00005QqFZ:dW^&Hg{t!5-4ONLOau9x/yb37AIM2pZqK@pO3p00/c17BaBG-@qHk>';
    const luaExport = '02H3uk5&m#lvuYL;KIO:Mg9FjOs)5.yU!bk{6k9tUwlHwZ}z%uTY3.}IvkwdiP9.r)s-g,XAxa!)JRjGCc5ze$;93~2=J;chc)06a}66Pn:tI#vWs~QDbnK5PpZ#&Xq36lcTLE-g359{rq/DBYLh@RBb~R;?$:iMT},~=/N@)J+fh9Ip8T1#dMl?Gf:M?tM%r/8%cL,lF{RGZOorax@0pONlP@9O.&SmJ>G6bq2t^7FJFmI>W$a,3r4:&ohBXUX)$&d%DuAJl%i~Y,:P';
    const luaChronicle = decodeChronicle(luaPlain);
    assert.strictEqual(encodeChronicle(luaChronicle), luaPlain, 'Lua plain string round trip');
    assert.strictEqual(encodeExportObject(luaChronicle), luaExport, 'JS produces the same export string as the Lua exporter');
    assert.deepStrictEqual(decodeExportString(luaExport), { version: ENCODING_VERSION, ...luaChronicle }, 'JS decodes the Lua export string');
}

function main(argv) {
    const args = argv.filter(a => a !== '--plain');
    const plain = argv.includes('--plain');
    const [command, input] = args;
    if (command === 'selftest') return selfTest();
    if (command === 'decode' && input) {
        const text = readArg(input).trim();
        const json = plain ? decodeChronicle(text) : decodeExportString(text);
        return console.log(JSON.stringify(json, null, 2));
    }
    if (command === 'inspect' && input) {
        const { text, problems } = inspectExportString(readArg(input), plain);
        console.log(text);
        if (problems > 0) process.exitCode = 1;
        return;
    }
    if (command === 'encode' && input) {
        const json = JSON.parse(input === '-' ? fs.readFileSync(0, 'utf8') : fs.readFileSync(input, 'utf8'));
        return console.log(plain ? encodeChronicle(json) : encodeExportObject(json));
    }
    console.error('Usage: node chronicle-codec.js decode <export string | -> [--plain]\n'
        + '       node chronicle-codec.js inspect <export string | -> [--plain]\n'
        + '       node chronicle-codec.js encode <file.json | -> [--plain]\n'
        + '       node chronicle-codec.js selftest');
    process.exitCode = 1;
}

// ---------- card and site names ----------
// Names for every id the exporter can write.
const MAPPING = {
    // id -> name
    ids: {
        // Deck cards
        1: "Wrestlers",
        2: "Battle Honors",
        3: "Bear Traps",
        4: "Longbows",
        5: "Keep",
        6: "Pressgangs",
        7: "Garrison",
        8: "Scouts",
        9: "Alchemist",
        10: "Martial Culture",
        11: "Errand Boy",
        12: "Mercenaries",
        13: "Tinker's Fair",
        14: "Rain Boots",
        15: "A Small Favor",
        16: "Second Wind",
        17: "Sleight of Hand",
        18: "Key to the City",
        19: "Scryer",
        20: "Disgraced Captain",
        21: "Naysayers",
        22: "Book Burning",
        23: "Ancient Binding",
        24: "Horse Archers",
        25: "Warning Signals",
        26: "Elders",
        27: "The Gathering",
        28: "Faithful Friend",
        29: "Tents",
        30: "Great Herd",
        31: "Fire Talkers",
        32: "Magician's Code",
        33: "Spirit Snare",
        34: "Wizard School",
        35: "Dazzle",
        36: "Acting Troupe",
        37: "Taming Charm",
        38: "Inquisitor",
        39: "Wolves",
        40: "Animal Playmates",
        41: "True Names",
        42: "The Old Oak",
        43: "Forest Paths",
        44: "Long-Lost Heir",
        45: "Rangers",
        46: "Roving Terror",
        47: "Wayside Inn",
        48: "Extra Provisions",
        49: "Memory of Home",
        50: "Welcoming Party",
        51: "Traveling Doctor",
        52: "Storyteller",
        53: "Armed Mob",
        54: "Tavern Songs",
        55: "Secret Signal",
        56: "Augury",
        57: "Rusting Ray",
        58: "Quick Exit",
        59: "Billowing Fog",
        60: "Kindred Warriors",
        61: "Terror Spells",
        62: "Blood Pact",
        63: "Revelation",
        64: "Observatory",
        65: "Plague Engines",
        66: "Gleaming Armor",
        67: "Bewitch",
        68: "Jinx",
        69: "Tutor",
        70: "Dream Thief",
        71: "Cracking Ground",
        72: "Sealing Ward",
        73: "Initiation Rite",
        74: "Vow of Silence",
        75: "Forgotten Vault",
        76: "Map Library",
        77: "Witch's Bargain",
        78: "Master of Disguise",
        79: "Charlatan",
        80: "Assassin",
        81: "Downtrodden",
        82: "Blackmail",
        83: "Cracked Sage",
        84: "Dissent",
        85: "False Prophet",
        86: "Vow of Division",
        87: "Zealots",
        88: "Royal Ambitions",
        89: "Salt the Earth",
        90: "Beast Tamer",
        91: "Riots",
        92: "Silver Tongue",
        93: "Gambling Hall",
        // No ID 94. Card was removed
        95: "Relic Thief",
        96: "Enchantress",
        97: "Insomnia",
        98: "Sneak Attack",
        99: "Gossip",
        100: "Bandit Chief",
        101: "Chaos Cult",
        102: "Defame",
        103: "Code of Honor",
        104: "Outriders",
        105: "Messenger",
        106: "Field Promotion",
        107: "Palanquin",
        108: "Shield Wall",
        109: "Military Parade",
        // No ID 110. Card was removed
        111: "Tyrant",
        112: "Forced Labor",
        113: "Secret Police",
        114: "Specialist",
        115: "Captains",
        116: "Siege Engines",
        117: "Royal Tax",
        118: "Toll Roads",
        119: "Curfew",
        120: "Knights Errant",
        121: "Vow of Obedience",
        122: "Hunting Party",
        123: "Council Seat",
        124: "Encirclement",
        125: "Peace Envoy",
        126: "Relic Hunter",
        127: "Homesteaders",
        128: "Crop Rotation",
        129: "A Round of Ale",
        130: "Land Warden",
        131: "Charming Friend",
        132: "Village Constable",
        133: "Family Heirloom",
        134: "News from Afar",
        135: "Levelers",
        136: "Fabled Feast",
        137: "The Great Levy",
        138: "Hearts and Minds",
        139: "Relic Breaker",
        140: "Book Binders",
        141: "Ballot Box",
        142: "Saddle Makers",
        143: "Herald",
        144: "Rowdy Pub",
        145: "Vow of Peace",
        146: "Deed Writer",
        147: "Salad Days",
        148: "Marriage",
        149: "Hospital",
        150: "Awaited Return",
        151: "Convoys",
        152: "Vow of Kinship",
        153: "Wild Mounts",
        154: "Lancers",
        155: "Mountain Giant",
        156: "Rival Khan",
        157: "Lost Tongue",
        158: "Special Envoy",
        159: "Resettle",
        160: "Oracle",
        161: "Pilgrimage",
        162: "Spell Breaker",
        163: "Mounted Patrol",
        164: "Great Crusade",
        165: "Ancient Bloodline",
        166: "Ancient Pact",
        167: "Storm Caller",
        168: "Family Wagon",
        169: "Way Station",
        170: "Twin Brother",
        171: "Hospitality",
        172: "A Fast Steed",
        173: "Relic Worship",
        // No ID 174. Card was removed
        175: "Nature Worship",
        176: "Birdsong",
        177: "Small Friends",
        178: "Grasping Vines",
        179: "Threatening Roar",
        180: "Fae Merchant",
        181: "Second Chance",
        182: "Pied Piper",
        183: "Mushrooms",
        184: "Insect Swarm",
        185: "Vow of Union",
        186: "Giant Python",
        187: "War Tortoise",
        188: "New Growth",
        189: "Wild Cry",
        190: "Animal Host",
        191: "Memory of Nature",
        192: "Marsh Spirit",
        193: "Vow of Poverty",
        194: "Forest Council",
        195: "Walled Garden",
        196: "Vow of Beastkin",
        197: "Bracken",
        198: "Wild Allies",
        199: "Golem Legions",
        200: "Council Arbiter",
        201: "Catacombs",
        202: "Ward of Silence",
        203: "Vow of Wisdom",
        204: "Arcane Brokers",
        205: "Disciples",
        206: "Arcane Armor",
        207: "Glamor",
        208: "Wizard's Conclave",
        209: "True Oath",
        210: "Bog",
        211: "Whispering Leaves",
        212: "Bed of Roots",
        213: "Autumn Wind",
        214: "Shifting Fog",
        215: "Fae Battalion",
        216: "Hunger",
        217: "Signal Trees",
        218: "Forest Warden",
        219: "Bandit Paymaster",
        220: "Reliquary Raid",
        221: "Tracker",
        222: "Banner Breakers",
        223: "Pledge to Discord",
        224: "Friendly Familiar",
        225: "Unstable Summon",
        226: "Bandit Prince",
        227: "Dark Enforcer",
        228: "Spoiled Supplies",
        229: "Old Songs",
        230: "Diplomat",
        231: "Village Idiot",
        232: "Spinning Bee",
        233: "Firebrand",
        234: "Watchdog",
        235: "Favored Son",
        236: "Town Meeting",
        237: "League Treaty",
        238: "Skilled Merchants",
        239: "Tribute Spoils",
        240: "Search Party",
        241: "Moving Market",
        242: "Traveling Negotiator",
        243: "Pledge of Defense",
        244: "The Red Seer",
        245: "Royal Stables",
        246: "Call for Help",
        247: "Vow of Wandering",
        248: "Mounted Library",
        249: "Master at Arms",
        250: "Baron",
        251: "Honor Guard",
        252: "City Wall",
        253: "Fearsome General",
        254: "Careful Plans",
        255: "Garrison Armory",
        256: "Battle Axes",
        257: "Great Feast",
        258: "Quartermaster",
        // Gap in case more cards are added

        // Relics
        401: "Sticky Fire",
        402: "Cursed Cauldron",
        403: "Brass Horse",
        404: "Truthful Harp",
        405: "Grand Mask",
        406: "Horned Mask",
        407: "Cup of Plenty",
        408: "Whistle",
        409: "Dowsing Sticks",
        410: "Cracked Horn",
        411: "Bandit Crown",
        412: "Ring of Devotion",
        413: "Skeleton Key",
        414: "Oracular Pig",
        415: "Circlet of Command",
        416: "Ivory Eye",
        417: "Shifting Map",
        418: "Obsidian Cage",
        419: "Book of Records",
        420: "Dragonskin Drum",
        421: "Crystal Vial",
        422: "Ancient Writ",
        423: "Painted Trumpet",
        424: "Bone Dice",
        425: "Brass Army",
        426: "Imperial Seal",
        427: "Fearsome Shield",
        428: "Singing Mask",
        429: "Lost Tapestry",
        430: "Bandit Standard",
        431: "Silver Charm",
        432: "Amber Flame",
        433: "Wine of Welcome",
        434: "Whispering Stone",
        435: "Black Sword",
        436: "Barbed Net",
        437: "Bag of Siegeworks",
        438: "Secret Testament",
        439: "Magic Carpet",
        440: "Yew Staff",
        441: "Spiteful Mirror",
        442: "Weeping Banner",
        443: "Sigil of the Eye",
        444: "Sigil of the Heart",
        445: "Magic Waterskin",
        446: "Demon Tail",
        447: "Clay Rattle",
        // Gap in case more relics are added


        // Edifices
        501: "Hall of Debate",
        502: "Great Market",
        503: "Grand Canal",
        504: "Stone Baths",
        505: "Amber Doors",
        506: "Great Forge",
        507: "Wild Pastures",
        508: "Sacred Ground",
        509: "Giant's Path",
        510: "Temple of Ancestors",
        511: "Great Spire",
        512: "Great Clock",
        513: "Underground Library",
        514: "Stone Portal",
        515: "Marble Fountains",
        516: "Hall of Ministers",
        517: "Relic Patrols",
        518: "Tome Guardians",
        519: "The Tribunal",
        520: "Towering Rampart",
        521: "Festival District",
        522: "Proving Grounds",
        523: "Spiral Castle",
        524: "Boiling Lake",
        525: "Hidden Passages",
        526: "Hallowed Spring",
        527: "School of Vines",
        528: "Oaken Fortress",
        529: "Forbidden Forest",
        530: "Forest Horn",
    },
    legacies: {
        1: "Iron Hand",
        2: "Chronicler",
        3: "Steadfast",
        4: "Peacemaker",
        5: "The Needle",
        6: "Circle of Swords",
        7: "Great Architect",
        8: "Ancestral Lands",
        9: "Scepter Bearer",
        10: "Royal Line",
        11: "Keeper of Order",
        12: "Golden Key",
        13: "World Crafter",
        14: "Matchmaker",
        15: "Revolutionary",
        16: "Populist",
        17: "Rival",
        18: "The Standard Bearer",
        19: "The Ear",
        20: "Heirloom",
        21: "High Priest",
        22: "Seer",
        23: "Arbiter",
        24: "The Bright Beacon",
        25: "Oaths of Loyalty",
        26: "Conspirator",
        27: "Light Fingers",
        28: "Secret Society",
        29: "Ruthless",
        30: "Quest to Distant Lands",
        31: "Wealthy",
        32: "Gatekeeper",
        33: "Beloved",
        34: "The Mouth",
        35: "Reformer",
        36: "Pathfinder",
    },
    // Foundations in bit order (I to VI)
    foundations: ["Imperial Maps", "Powerful Tribes", "Quiet Ambitions", "Teeming World", "Mob's Favor", "Wandering Flame"],
    // site name -> site index. Several names can share an index for legacy reasons, and the first one listed is the canonical name
    sites: {
        "Ancient City": 0,
        "Broken Peaks": 1,
        "Buried Giant": 2,
        "Sleeping Giant": 2,
        "Gray Barrows": 2,
        "Deep Woods": 3,
        "Desolate Shore": 4,
        "Dunes": 5,
        "Fair Isle": 6,
        "Golden Valley": 7,
        "Great Slum": 8,
        "Green Shore": 9,
        "Headwaters": 10,
        "Hidden Place": 11,
        "Hidden City": 11,
        "Mines": 12,
        "Narrow Pass": 13,
        "Painted Towers": 14,
        "Riverbank": 15,
        "Rocky Coast": 16,
        "Salt Flats": 17,
        "Shrouded Woods": 18,
        "Solitary Pillar": 19,
        "Standing Stones": 20,
        "StandingStones": 20,
        "Steppe": 21,
        "Sunken Isles": 22,
        "Tidal Marshes": 23,
    },
};

module.exports = { decodeExportString, encodeExportObject, decodeChronicle, encodeChronicle, inspectExportString, scramble, checksum };

if (require.main === module) {
    try {
        main(process.argv.slice(2));
    } catch (err) {
        console.error(`Error: ${err.message}`);
        process.exitCode = 1;
    }
}
