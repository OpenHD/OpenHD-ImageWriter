const assert = require("assert")
const fs = require("fs")
const vm = require("vm")

const context = {
    Qt: { locale: () => ({ name: "en_US" }) },
    qsTr: text => ({ arg: value => text.replace("%1", value) }),
    githubDevImageCount: 0,
    osmodel: {
        entries: [{ name: "USB" }, { name: "Custom" }],
        get count() { return this.entries.length },
        insert(index, entry) { this.entries.splice(index, 0, entry) }
    }
}
vm.createContext(context)
vm.runInContext(fs.readFileSync(require.resolve("../catalog.js"), "utf8")
    .replace(/^\.pragma library\s*/, ""), context)
context.Catalog = { normalise: context.normalise, flattenSubitems: context.flattenSubitems }

// Exercise the importer used by the QML page, including its model insertion.
const flash = fs.readFileSync(require.resolve("../flash.qml"), "utf8")
for (const name of ["githubArtifactKey", "isFlashableGithubArtifact", "populateGithubDevImages"]) {
    const match = flash.match(new RegExp("        function " + name + "\\([^]*?(?=\\n        function )"))
    assert.ok(match, "Missing QML function: " + name)
    vm.runInContext(match[0], context)
}

const ticketUrl = "https://openhd.tech/api/imagewriter/dev-images/123/firmware-2026-10-04-12-00-00.zip/download?ticket=test&archive=.zip"
context.populateGithubDevImages({ artifacts: [
    { name: "firmware-2026-10-03-12-00-00", filename: "firmware-2026-10-03-12-00-00.zip", platform: "x21b", created_at: "2026-10-03T12:00:00Z", archive_download_url: "https://example/older.zip" },
    { name: "firmware-2026-10-04-12-00-00", filename: "firmware-2026-10-04-12-00-00.zip", platform: "x21b", source: "fleetcontrol", created_at: "2026-10-04T12:00:00Z", archive_download_url: ticketUrl, size_in_bytes: 123456, extract_sha256: "" },
    { name: "OpenHD-X21B-full-2026-10-04-12-00-00", filename: "OpenHD-X21B-full-2026-10-04-12-00-00.ohd", platform: "x21b-update", archive_download_url: "https://example/update.ohd" },
    { name: "openhd-image-pi-2026-10-04-12-00-00", platform: "pi", archive_download_url: "https://example/pi.img.xz", extract_sha256: "a".repeat(64) },
    { name: "openhd-image-rock5b-2026-10-04-12-00-00", archive_download_url: "https://example/rock5b.img.xz" },
    { name: "debug-symbols", archive_download_url: "https://example/debug.zip" }
] })
assert.strictEqual(context.githubDevImageCount, 3)
assert.strictEqual(context.githubDevLoading, false)
const hardware = context.osmodel.entries.find(entry => entry.manufacturer === "openhd")
assert.ok(hardware, "X21 must appear under OpenHD Hardware")
assert.strictEqual(hardware.catalog_source, "fleetcontrol")
assert.strictEqual(hardware.channel, "development")
const boards = JSON.parse(hardware.subitems_json)
assert.strictEqual(boards.length, 1)
assert.strictEqual(boards[0].name, "X21")
assert.strictEqual(boards[0].subitems.length, 1)
const firmware = boards[0].subitems[0]
assert.strictEqual(firmware.url, ticketUrl)
assert.strictEqual(firmware.platform, "x21", "X21 selection must require Rockchip USB flashing")
assert.strictEqual(firmware.image_download_size, 123456)
assert.strictEqual(firmware.extract_sha256, "")
assert.strictEqual(context.isFlashableGithubArtifact({ platform: "x21b", filename: "update.ohd" }), false)
assert.strictEqual(context.isFlashableGithubArtifact({ platform: "x21b", filename: "debug.zip" }), false)
assert.strictEqual(context.isFlashableGithubArtifact({ platform: "x21b-update", name: "openhd-image-x21b-update" }), false)
assert.strictEqual(context.osmodel.entries.at(-1).name, "Custom")
assert.strictEqual(context.osmodel.entries.at(-2).name, "USB")
console.log("FleetControl catalog tests passed")
