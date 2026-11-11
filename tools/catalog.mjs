import { readFile, rename, rm, writeFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { join } from 'node:path';
import { parseArgs } from 'node:util';

function isID(value) {
    return Number.isInteger(value) && value > 0 && value <= 0x7fffffff;
}

function isModelPath(value) {
    return typeof value === 'string' && value.length <= 250 &&
        /^(Creature|Character|World)\\[^\x00-\x1f|:/]+\.(m2|mdx)$/i.test(value) &&
        value.split('\\').every(part => part && part !== '.' && part !== '..');
}

function validate(catalog) {
    if (catalog?.schema !== 1 || !Array.isArray(catalog.mounts) || catalog.mounts.length === 0 || catalog.mounts.length > 20000) {
        throw new Error('Se esperaba un catálogo schema 1 con 1 a 20000 monturas.');
    }
    const ids = new Set();
    for (const row of catalog.mounts) {
        if (!row || !isID(row.spellID) || ids.has(row.spellID) || typeof row.custom !== 'boolean' ||
            (row.creatureID != null && !isID(row.creatureID)) ||
            (row.displayID != null && !isID(row.displayID)) ||
            (row.name != null && (typeof row.name !== 'string' || !row.name.trim() || row.name.length > 200 || /[\x00-\x1f|]/.test(row.name))) ||
            (row.model != null && !isModelPath(row.model)) ||
            (!row.creatureID && !row.displayID && !row.model)) {
            throw new Error(`Montura inválida o duplicada: ${row?.spellID}`);
        }
        ids.add(row.spellID);
    }
    return catalog;
}

async function readDBC(file, columns) {
    const data = await readFile(file);
    if (data.length < 20 || data.toString('ascii', 0, 4) !== 'WDBC' ||
        data.readUInt32LE(8) !== columns || data.readUInt32LE(12) !== columns * 4) {
        throw new Error(`DBC incompatible con 3.3.5a: ${file}`);
    }
    const count = data.readUInt32LE(4);
    const strings = 20 + count * columns * 4;
    if (strings + data.readUInt32LE(16) !== data.length) throw new Error(`DBC truncado: ${file}`);
    return {
        count,
        number(row, column) { return data.readUInt32LE(20 + (row * columns + column) * 4); },
        string(offset) {
            if (offset === 0) return '';
            const start = strings + offset;
            const end = data.indexOf(0, start);
            if (end < 0) throw new Error(`Cadena inválida en ${file}`);
            return data.toString('utf8', start, end);
        },
    };
}

async function mountsFromSpell(file) {
    const dbc = await readDBC(file, 234);
    const mounts = new Map();
    for (let row = 0; row < dbc.count; row++) {
        for (let effect = 0; effect < 3; effect++) {
            // Spell.dbc 12340, zero-based columns. Mounted aura = 78; MiscValueA = creature entry.
            const creatureID = dbc.number(row, 110 + effect);
            if (dbc.number(row, 95 + effect) !== 78 || !isID(creatureID)) continue;
            const spellID = dbc.number(row, 0);
            let name = '';
            for (let col = 136; col < 152 && !name; col++) name = dbc.string(dbc.number(row, col));
            mounts.set(spellID, { spellID, creatureID, name: name || undefined, custom: false });
            break;
        }
    }
    return mounts;
}

async function applyModels(mounts, tsv, dbcDir) {
    const [mapping, displays, models] = await Promise.all([
        readFile(tsv, 'utf8'),
        readDBC(join(dbcDir, 'CreatureDisplayInfo.dbc'), 16),
        readDBC(join(dbcDir, 'CreatureModelData.dbc'), 28),
    ]);
    const displayForCreature = new Map();
    for (const line of mapping.trim().split(/\r?\n/)) {
        const [creatureID, displayID] = line.split('\t').map(Number);
        if (!isID(creatureID) || !isID(displayID)) throw new Error(`Fila TSV inválida: ${line}`);
        if (!displayForCreature.has(creatureID)) displayForCreature.set(creatureID, displayID);
    }
    const modelForDisplay = new Map();
    for (let row = 0; row < displays.count; row++) modelForDisplay.set(displays.number(row, 0), displays.number(row, 1));
    const pathForModel = new Map();
    for (let row = 0; row < models.count; row++) pathForModel.set(models.number(row, 0), models.string(models.number(row, 2)));
    for (const mount of mounts.values()) {
        const displayID = mount.displayID ?? displayForCreature.get(mount.creatureID);
        const model = pathForModel.get(modelForDisplay.get(displayID))?.replace(/\//g, '\\').replace(/\.mdx$/i, '.m2');
        mount.displayID = displayID;
        if (isModelPath(model)) mount.model ??= model;
    }
}

function luaString(value) {
    return value == null ? 'nil' : JSON.stringify(value);
}

function toLua(catalog, field) {
    const lines = ['-- Archivo generado por catalog.mjs.', `local addon = select(2, ...)`, `addon.${field} = {`];
    for (const row of catalog.mounts) {
        lines.push(`    [${row.spellID}] = { ${row.creatureID ?? 'nil'}, ${luaString(row.name)}, ${row.custom}, ${row.displayID ?? 'nil'}, ${luaString(row.model)} },`);
    }
    return lines.concat('}', '').join('\n');
}

async function writeAtomic(target, content) {
    const staging = `${target}.${randomUUID()}.tmp`;
    try {
        await writeFile(staging, content, { flag: 'wx' });
        await rename(staging, target);
    } finally {
        await rm(staging, { force: true });
    }
}

async function main() {
    const { values: args, positionals: [command] } = parseArgs({ allowPositionals: true, options: {
        spell: { type: 'string' }, baseline: { type: 'string' }, 'baseline-map': { type: 'string' }, custom: { type: 'string' },
        models: { type: 'string' }, 'dbc-dir': { type: 'string' }, out: { type: 'string' },
        url: { type: 'string' }, addon: { type: 'string' },
    } });
    if (command === 'sync' && args.url && args.addon) {
        const url = new URL(args.url);
        if (url.protocol !== 'https:') throw new Error('La URL debe usar HTTPS.');
        const response = await fetch(url, { redirect: 'error', signal: AbortSignal.timeout(15000) });
        if (!response.ok) throw new Error(`El VPS devolvió HTTP ${response.status}.`);
        const catalog = validate(await response.json());
        await writeAtomic(join(args.addon, 'RealmCatalog.lua'), toLua(catalog, 'RealmCatalog'));
        console.log(`Catálogo sincronizado: ${catalog.mounts.length} monturas. Ejecuta /reload en WoW.`);
        return;
    }
    if (['build', 'base', 'client'].includes(command) && args.spell && args.out) {
        if (Boolean(args.models) !== Boolean(args['dbc-dir'])) throw new Error('Usa --models y --dbc-dir juntos.');
        const mounts = await mountsFromSpell(args.spell);
        if (args.baseline || args['baseline-map']) {
            if (args.baseline && args['baseline-map']) throw new Error('Elige un solo catálogo base.');
            const base = args.baseline
                ? Object.fromEntries([...await mountsFromSpell(args.baseline)].map(([id, row]) => [id, row.creatureID]))
                : JSON.parse(await readFile(args['baseline-map'], 'utf8'));
            for (const row of mounts.values()) row.custom = base[row.spellID] !== row.creatureID;
        }
        if (args.custom) {
            const overrides = JSON.parse(await readFile(args.custom, 'utf8'));
            if (!Array.isArray(overrides)) throw new Error('El archivo custom debe contener un array JSON.');
            for (const row of overrides) mounts.set(row.spellID, { ...mounts.get(row.spellID), ...row, custom: row.custom ?? true });
        }
        if (args.models) await applyModels(mounts, args.models, args['dbc-dir']);
        const rows = [...mounts.values()].filter(row => row.name !== '0').sort((a, b) => a.spellID - b.spellID);
        const catalog = validate({ schema: 1, mounts: command === 'client' ? rows.filter(row => row.custom && row.name) : rows });
        const output = command === 'build' ? `${JSON.stringify(catalog)}\n` : toLua(catalog, command === 'base' ? 'BaseCatalog' : 'ClientCatalog');
        await writeAtomic(args.out, output);
        console.log(`Catálogo generado: ${catalog.mounts.length} monturas, ${catalog.mounts.filter(row => row.model).length} rutas de modelo.`);
        return;
    }
    throw new Error('Uso: catalog.mjs build --spell Spell.dbc --out mounts.json | sync --url https://.../mounts.json --addon RUTA');
}

main().catch(error => {
    console.error(error.message);
    process.exitCode = 1;
});
