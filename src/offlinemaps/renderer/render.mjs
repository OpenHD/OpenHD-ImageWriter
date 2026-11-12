import {readFile} from 'node:fs/promises';
import {createInterface} from 'node:readline';
import {DatabaseSync} from 'node:sqlite';
import {gunzipSync} from 'node:zlib';
import maplibre from '@maplibre/maplibre-gl-native';
import {osm} from '@versatiles/style';
import sharp from 'sharp';

const resourceHost = 'https://offline-map.invalid';
const size = 256;
const margin = 32;
const emptyTile = Buffer.alloc(0);

function write(message) {
    return new Promise((resolve, reject) => {
        process.stdout.write(JSON.stringify(message) + '\n', error => error ? reject(error) : resolve());
    });
}

async function renderArchive(filename, selection) {
    const database = new DatabaseSync(filename, {readOnly: true});
    let map;
    try {
        const metadata = Object.fromEntries(database.prepare('SELECT name, value FROM metadata')
            .all().map(({name, value}) => [name, value]));
        const layers = new Set(JSON.parse(metadata.json || '{}').vector_layers?.map(layer => layer.id));
        if (metadata.format !== 'pbf' || !layers.has('streets') || !layers.has('place_labels'))
            throw new Error('Choose a vector MBTiles archive using the Shortbread schema.');

        const bounds = metadata.bounds?.split(',').map(Number);
        if (bounds?.length !== 4 || !bounds.every(Number.isFinite) || selection.length !== 4 ||
            !selection.every(Number.isFinite))
            throw new Error('The selected MBTiles archive must include valid geographic bounds.');
        const [west, south, east, north] = selection;
        if (west < bounds[0] || south < bounds[1] || east > bounds[2] || north > bounds[3])
            throw new Error('The selected area extends outside the map data. Choose a larger extract or a smaller area.');

        const sourceMinZoom = Number(metadata.minzoom);
        const sourceMaxZoom = Number(metadata.maxzoom);
        if (!Number.isInteger(sourceMinZoom) || !Number.isInteger(sourceMaxZoom) ||
            sourceMinZoom < 0 || sourceMaxZoom > 22 || sourceMinZoom > sourceMaxZoom)
            throw new Error('The MBTiles archive has an invalid zoom range.');

        const tile = database.prepare(
            'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?');
        const style = osm({theme: 'colorful'});
        delete style.projection;
        delete style.sky;
        style.sources['versatiles-shortbread'] = {
            type: 'vector',
            tiles: [resourceHost + '/tile/{z}/{x}/{y}.pbf'],
            minzoom: sourceMinZoom,
            maxzoom: sourceMaxZoom,
        };
        style.layers = style.layers.filter(layer => !layer['source-layer'] || layers.has(layer['source-layer']));
        style.glyphs = resourceHost + '/fonts/{fontstack}/{range}.pbf';
        style.sprite = [{id: 'base', url: resourceHost + '/sprites/base'}];

        // Check the renderer assets before starting a job. MapLibre treats missing
        // fonts or sprites as recoverable, which would otherwise hide missing labels.
        await Promise.all([
            readFile(new URL('./assets/fonts/noto_sans_regular/0-255.pbf', import.meta.url)),
            readFile(new URL('./assets/fonts/noto_sans_bold/0-255.pbf', import.meta.url)),
            readFile(new URL('./assets/sprites/base.json', import.meta.url)),
            readFile(new URL('./assets/sprites/base.png', import.meta.url)),
        ]).catch(() => { throw new Error('The offline map renderer is missing its fonts or icons.'); });

        let resourceError;
        async function resource(url) {
            if (!url.startsWith(resourceHost + '/'))
                throw new Error('Unexpected resource in the offline map style.');
            const path = decodeURIComponent(url.slice(resourceHost.length + 1));
            const coordinates = /^tile\/(\d+)\/(\d+)\/(\d+)\.pbf$/.exec(path);
            if (coordinates) {
                const [z, x, y] = coordinates.slice(1).map(Number);
                const row = tile.get(z, x, 2 ** z - 1 - y);
                if (!row) return emptyTile;
                const data = Buffer.from(row.tile_data);
                return data[0] === 0x1f && data[1] === 0x8b ? gunzipSync(data) : data;
            }
            if (/^(fonts\/noto_sans_(regular|bold)\/\d+-\d+\.pbf|sprites\/base(@2x)?\.(png|json))$/.test(path)) {
                try {
                    return await readFile(new URL('./assets/' + path, import.meta.url));
                } catch (error) {
                    // The bundled font has no glyphs for some Unicode ranges.
                    if (error.code === 'ENOENT' && path.startsWith('fonts/')) return emptyTile;
                    throw error;
                }
            }
            throw new Error('Unexpected resource in the offline map style.');
        }

        map = new maplibre.Map({
            ratio: 1,
            request(request, callback) {
                resource(request.url).then(data => callback(null, {data}), error => {
                    resourceError = error;
                    callback(error);
                });
            },
        });
        map.load(style);
        await write({ready: true});

        const commands = createInterface({input: process.stdin, crlfDelay: Infinity});
        for await (const line of commands) {
            if (!/^\d+ \d+ \d+$/.test(line)) throw new Error('Invalid tile coordinates.');
            const [z, x, y] = line.split(' ').map(Number);
            if (z > 16 || x >= 2 ** z || y >= 2 ** z) throw new Error('Invalid tile coordinates.');
            const world = 2 ** z;
            const center = [
                (x + 0.5) * 360 / world - 180,
                Math.atan(Math.sinh(Math.PI * (1 - 2 * (y + 0.5) / world))) * 180 / Math.PI,
            ];
            // MapLibre uses a 512px world at zoom zero. For the XYZ root tile,
            // render the full world and reduce it to the GLDMAP1 tile size.
            const width = z === 0 ? 512 : size + 2 * margin;
            const pixels = await new Promise((resolve, reject) => {
                map.render({width, height: width, center, zoom: Math.max(0, z - 1)},
                    (error, data) => error ? reject(error) : resolve(data));
            });
            if (resourceError) throw resourceError;
            const image = sharp(pixels, {raw: {width, height: width, channels: 4}});
            const cropped = z === 0 ? image.resize(size, size) :
                image.extract({left: margin, top: margin, width: size, height: size});
            const png = await cropped.png().toBuffer();
            await write({png: png.toString('base64')});
        }
    } finally {
        map?.release();
        database.close();
    }
}

try {
    await renderArchive(process.argv[2], process.argv.slice(3).map(Number));
} catch (error) {
    await write({error: error.message});
    process.exitCode = 1;
}
