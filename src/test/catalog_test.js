const assert = require("assert")
const fs = require("fs")
const vm = require("vm")

const source = fs.readFileSync(require.resolve("../catalog.js"), "utf8")
    .replace(/^\.pragma library\s*/, "")
const context = {}
vm.createContext(context)
vm.runInContext(source, context)

const images = [
    { name: "OpenHD X20 2.8.0", platform: "x20", channel: "stable", url: "https://example/x20", release_date: "2026-09-03" },
    { name: "OpenHD X21 2.8.0", platform: "x21", channel: "stable", url: "https://example/x21", release_date: "2026-09-02" },
    { name: "OpenHD RPi 2.7.0", platform: "raspberry-pi", channel: "stable", url: "https://example/rpi-270", release_date: "2026-08-01" },
    { name: "OpenHD ROCK 5A 2.8", platform: "radxa", channel: "stable", url: "https://example/rock5a", release_date: "2026-09-01" },
    { name: "OpenHD Rock5B 2.8 dev", platform: "radxa", channel: "development", url: "https://example/rock5-dev", release_date: "2026-09-01" },
    { name: "OpenHD RPi 2.8.0", platform: "raspberry-pi", channel: "stable", url: "https://example/rpi-280", release_date: "2026-09-01" },
    { name: "OpenHD RPi5 2.8.0", platform: "raspberry-pi", channel: "stable", url: "https://example/rpi5", release_date: "2026-09-01" },
    { name: "OpenHD Luckfox Aura", platform: "aura", channel: "stable", url: "https://example/aura", release_date: "2026-09-01" },
    { name: "OpenHD OrangePi CM4", platform: "orangepi-cm4", channel: "stable", url: "https://example/orange-cm4", release_date: "2026-09-01" },
    { name: "OpenHD Orqa GCB", platform: "gcb", channel: "stable", url: "https://example/gcb", release_date: "2026-09-01" },
    { name: "OpenHD UXV Module-35", platform: "module-35", channel: "stable", url: "https://example/module-35", release_date: "2026-09-01" },
    { name: "Duplicate", platform: "raspberry-pi", channel: "stable", url: "https://example/rpi-280", release_date: "2026-09-02" }
]

const grouped = context.normalise(images, "en_US")
assert.strictEqual(grouped.length, 8)
assert.deepStrictEqual(Array.from(grouped.slice(0, 7), item => item.name), [
    "OpenHD Hardware", "Raspberry Pi", "Radxa", "Luckfox", "Orange Pi", "Orqa", "UXV"
])
assert.strictEqual(grouped[0].channel, "stable")
assert.deepStrictEqual(Array.from(grouped[0].subitems, item => item.name), [
    "X20",
    "X21"
])
assert.strictEqual(context._hardware({ platform: "y20" }).manufacturer, "other")
assert.deepStrictEqual(Array.from(grouped[1].subitems, item => item.name), [
    "Raspberry Pi 2–4",
    "Raspberry Pi 5"
])
assert.deepStrictEqual(Array.from(grouped[1].subitems[0].subitems, item => item.name), [
    "OpenHD RPi 2.8.0",
    "OpenHD RPi 2.7.0"
])
assert.strictEqual(grouped[7].name, "Radxa")
assert.strictEqual(grouped[7].channel, "development")
assert.strictEqual(grouped[7].subitems[0].name, "ROCK 5B")

const wrapped = context.normalise({ images: images }, "en_US")
assert.strictEqual(wrapped.length, 8)

const legacy = context.normalise({
    os_list: [{
        name: "Legacy category",
        subitems: [
            { name: "Older", url: "https://example/old", release_date: "2025-01-01" },
            { name: "Newer", url: "https://example/new", release_date: "2026-01-01" }
        ]
    }]
}, "en_US")
assert.strictEqual(legacy[0].name, "Other Hardware")
assert.strictEqual(legacy[0].subitems[0].subitems[0].name, "Newer")
assert.ok(context.flattenSubitems(legacy)[0].subitems_json)

const currentManifest = JSON.parse(fs.readFileSync(
    require.resolve("../OpenHD-download-index.json"), "utf8"))
const currentCatalog = context.normalise(currentManifest, "en_US")
assert.ok(currentCatalog.length > 0)
assert.ok(currentCatalog[0].subitems.length > 0)
assert.ok(context.flattenSubitems(currentCatalog)[0].subitems_json)

console.log("catalog tests passed")
