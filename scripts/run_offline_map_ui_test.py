"""Exercise the production picker and the standalone Offline Maps tab.

Uses Qt 5 Location with a real map canvas and a mock FleetControl endpoint.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import contextlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Event, Thread
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
@contextlib.contextmanager
def tile_fixture():
    requests = []
    generated = []
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 256, 256, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress((b"\0" + b"\x80\x90\x80" * 256) * 256)) + chunk(b"IEND", b""))
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            requests.append(dict(self.headers))
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(png)))
            self.send_header("Cache-Control", "public,max-age=604800")
            self.end_headers()
            self.wfile.write(png)
        def do_POST(self):
            assert self.path == "/api/imagewriter/maps/generate-region"
            assert not self.headers.get("Cookie")
            bounds = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            assert bounds["west"] < bounds["east"]
            assert bounds["south"] < bounds["north"]
            generated.append(bounds)
            Event().wait(0.15)
            body = json.dumps({
                "id": "vector-test",
                "sha256": "a" * 64,
                "downloadUrl": "/api/region-download/vector-test?ticket=test",
            }).encode()
            try:
                self.send_response(201)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            except ConnectionError:
                pass
        def log_message(self, *_args): pass
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    Thread(target=server.serve_forever, daemon=True).start()
    try: yield f"http://127.0.0.1:{server.server_port}/", requests, generated
    finally:
        server.shutdown()
        server.server_close()


TEST = '''import QtQuick 2.12
import QtQuick.Controls 2.12
import QtTest 1.2
import QtPositioning 5.15
Item {
    id: scene
    width: 850; height: 480
    property bool packageReady: false
    QtObject {
        id: imageWriter
        signal fleetControlOfflineMapStaged(string mapId, string path, string error)
        property int stagedCount: 0
        function getValue(key) { return "" }
        function setSetting(key, value) {
            if (key === "offlineMapCreatorPackagePath") shell.localOfflineMapPath = value
        }
        function stageFleetControlOfflineMap(profileId, mapId, url, sha) {
            if (profileId !== "custom-region" || mapId !== "vector-test" ||
                    url !== "API_ORIGIN/api/region-download/vector-test?ticket=test" || sha.length !== 64) {
                fleetControlOfflineMapStaged(mapId, "", "Invalid download response")
                return
            }
            ++stagedCount
            fleetControlOfflineMapStaged(mapId, "test.mbtiles", "")
        }
    }
    QtObject {
        id: shell
        property string localOfflineMapPath: ""
        property bool fleetControlSignedIn: false
    }
    QtObject {
        id: builder
        property string previewCacheDirectory: "CACHE_DIR"
        property bool searching: false
        property string status: "Choose a search result, then draw your area."
        property var searchResults: []
        function search(query) {
            searchResults = [{name: "Test region", north: 50.01, south: 49.99, west: 7.99, east: 8.01}]
        }
        function cancel() { searching = false }
    }
    OfflineMapDialog {
        id: dialog
        builder: builder
        generationOrigin: "API_ORIGIN"
        initialLatitude: 50
        initialLongitude: 8
        onMapReady: scene.packageReady = true
    }
    OfflineMapsPage {
        id: page
        anchors.fill: parent
        mainWindow: shell
        previewBuilder: builder
    }
    TestCase {
        name: "OfflineMapPicker"; when: windowShown
        function test_rectangleAndGenerate() {
            dialog.open()
            var canvas = findChild(dialog, "offlineMapCanvas")
            verify(canvas !== null)
            tryCompare(canvas, "status", Loader.Ready, 10000)
            var map = findChild(canvas.item, "offlineSelectionMap")
            tryCompare(map, "mapReady", true, 10000)
            verify(canvas.item.selectionValid)
            var centre = canvas.item.radiusCenter
            verify(Math.abs(centre.distanceTo(QtPositioning.coordinate(canvas.item.north, centre.longitude)) - 50000) < 100)
            var oldZoom = map.zoomLevel
            map.zoomLevel = oldZoom + 1
            verify(map.zoomLevel > oldZoom)
            var oldLongitude = map.center.longitude
            mouseDrag(map, map.width / 2, map.height / 2, 70, 0, Qt.LeftButton)
            wait(100)
            verify(Math.abs(map.center.longitude - oldLongitude) > 0.00001)
            var search = findChild(dialog, "offlineRegionSearch")
            search.text = "Test region"
            search.accepted()
            wait(100)
            var selection = findChild(canvas.item, "offlineRectangleInput")
            mouseClick(findChild(dialog, "drawOfflineRectangle"))
            mousePress(selection, 120, 25)
            mouseMove(selection, 400, 95)
            mouseRelease(selection, 400, 95)
            verify(canvas.item.selectionValid)
            verify(canvas.item.north > canvas.item.south)
            verify(canvas.item.east > canvas.item.west)
            verify(!canvas.item.drawing)
            var create = findChild(dialog, "createOfflineMap")
            verify(create.enabled)
            verify(canvas.height >= 120)
            verify(create.mapToItem(dialog.contentItem, 0, create.height).y <= dialog.contentItem.height + 1)
            var content = findChild(dialog, "offlineMapDialogContent")
            waitForRendering(content)
            var saved = false
            verify(content.grabToImage(function(result) {
                saved = result.saveToFile("SCREENSHOT")
            }))
            tryVerify(function() { return saved })
            var progress = findChild(dialog, "offlineMapProgress")
            mouseClick(create)
            verify(progress.visible)
            verify(progress.indeterminate)
            verify(!create.enabled)
            verify(create.mapToItem(dialog.contentItem, 0, create.height).y <= dialog.contentItem.height + 1)
            mouseClick(findChild(dialog, "cancelOfflineMap"))
            verify(!dialog.working)
            verify(create.enabled)
            var previous = imageWriter.stagedCount
            mouseClick(create)
            tryCompare(scene, "packageReady", true)
            compare(imageWriter.stagedCount, previous + 1)
            dialog.close()
        }
        function test_standaloneDrawingWithoutAccount() {
            var open = findChild(page, "openOfflineAreaDialog")
            verify(open.enabled)
            mouseClick(open)
            var picker = findChild(page, "offlineAreaDialog")
            picker.generationOrigin = "API_ORIGIN"
            tryCompare(picker, "opened", true)
            var canvas = findChild(picker, "offlineMapCanvas")
            tryCompare(canvas, "status", Loader.Ready)
            tryCompare(canvas.item, "ready", true)
            verify(!canvas.item.selectionValid)
            var create = findChild(picker, "createOfflineMap")
            verify(!create.enabled)

            var draw = findChild(picker, "drawOfflineRectangle")
            mouseClick(draw)
            var selection = findChild(canvas.item, "offlineRectangleInput")
            mouseClick(selection, 200, 50)
            verify(canvas.item.drawing)
            verify(canvas.item.drawingError.length > 0)
            mousePress(selection, 240, 80)
            mouseMove(selection, 170, 30)
            mouseRelease(selection, 170, 30)
            verify(canvas.item.selectionValid)
            verify(create.enabled)

            var previous = imageWriter.stagedCount
            mouseClick(create)
            tryCompare(picker, "opened", false)
            compare(imageWriter.stagedCount, previous + 1)
            compare(page.stagedMap, "test.mbtiles")
        }
    }
}
'''

CATALOG_TEST = '''import QtQuick 2.12
import QtTest 1.2
import "qmlcomponents"

Item {
    id: scene
    width: 950; height: 740
    property string currentView: "home"
    QtObject {
        id: imageWriter
        signal fleetControlOfflineMapStaged(string mapId, string path, string error)
        function getValue(key) { return "" }
        function setSetting(key, value) {
            if (key === "offlineMapCreatorPackagePath")
                shell.localOfflineMapPath = value
        }
    }
    QtObject { id: shell; property string localOfflineMapPath: "" }
    QtObject {
        id: catalog
        property bool busy: false
        property real progress: 0
        property string status: ""
        property var regions: ["Berlin", "Luxembourg"]
        property int downloaded: -1
        signal selected(string path)
        function download(index) {
            downloaded = index
            busy = true
        }
        function cancel() { busy = false }
    }
    ModernSidebar {
        id: sidebar
        width: 210
        anchors.top: parent.top; anchors.bottom: parent.bottom
        currentView: scene.currentView
        openHdDeviceAvailable: false
        onNavigate: scene.currentView = view
    }
    OfflineMapsPage {
        id: page
        anchors.left: sidebar.right; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        visible: scene.currentView === "offlinemaps"
        mainWindow: shell
        catalog: catalog
    }
    TestCase {
        name: "OfflineMapsTab"; when: windowShown
        function test_downloadWithoutStorage() {
            var tab = findChild(sidebar, "navigation-offlinemaps")
            verify(tab.visible && tab.enabled)
            mouseClick(tab)
            tryCompare(page, "visible", true)
            var region = findChild(page, "offlineMapRegion")
            region.currentIndex = 1
            var download = findChild(page, "downloadVectorMap")
            verify(download.enabled)
            download.clicked()
            compare(catalog.downloaded, 1)
            verify(!download.enabled)
            findChild(page, "cancelVectorMap").clicked()
            verify(download.enabled)
            catalog.selected("luxembourg.mbtiles")
            compare(page.stagedMap, "luxembourg.mbtiles")
        }
    }
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--qt-bin", required=True, type=Path)
    parser.add_argument("--screenshot", type=Path, default=ROOT / "build-offline-builder-qt5/picker.png")
    args = parser.parse_args()
    args.screenshot.parent.mkdir(parents=True, exist_ok=True)
    with tile_fixture() as (tile_url, requests, generated), tempfile.TemporaryDirectory(prefix="openhd-offline-ui-") as temp:
        folder = Path(temp)
        for name in ["OfflineMapDialog.qml", "OfflineMapSelection.qml", "OfflineMapButton.qml", "OfflineMapsPage.qml"]:
            source = (ROOT / "src/offlinemaps" / name).read_text(encoding="utf-8")
            source = source.replace("https://tile.openstreetmap.org/", tile_url)
            (folder / name).write_text(source, encoding="utf-8")
        (folder / "tst_picker.qml").write_text(TEST.replace("SCREENSHOT", args.screenshot.as_posix())
            .replace("CACHE_DIR", (folder / "tiles").as_posix()).replace("API_ORIGIN", tile_url.rstrip("/")), encoding="utf-8")
        (folder / "tst_catalog.qml").write_text(CATALOG_TEST, encoding="utf-8")
        (folder / "qmlcomponents").mkdir()
        shutil.copyfile(ROOT / "src/qmlcomponents/ModernSidebar.qml", folder / "qmlcomponents/ModernSidebar.qml")
        shutil.copytree(ROOT / "src/icons/ui", folder / "icons/ui")
        fonts = folder / "fonts"
        fonts.mkdir()
        for name in ["segoeui.ttf", "segoeuib.ttf"]:
            source = Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts" / name
            if source.exists(): shutil.copyfile(source, fonts / name)
        env = os.environ.copy()
        env["PATH"] = str(args.qt_bin) + os.pathsep + env.get("PATH", "")
        env.setdefault("QT_QPA_PLATFORM", "offscreen")
        env["QT_QPA_FONTDIR"] = str(fonts)
        env.setdefault("QT_QUICK_BACKEND", "software")
        log = folder / "results.txt"
        try:
            result = subprocess.run([str(args.qt_bin / ("qmltestrunner.exe" if os.name == "nt" else "qmltestrunner")), "-input", str(folder),
                                     "-o", str(log) + ",txt"], env=env, timeout=45)
        except subprocess.TimeoutExpired:
            print(log.read_text(encoding="utf-8") if log.exists() else "No Qt test output", flush=True)
            raise
        output = log.read_text(encoding="utf-8") if log.exists() else "No test results"
        print(output)
        assert requests, "Map preview did not request fixture tiles"
        for headers in requests:
            assert headers.get("User-Agent") == "OpenHD-ImageWriter/1.0 (+https://openhd.tech)", headers
            assert "no-cache" not in headers.get("Cache-Control", ""), headers
        print("Preview tile headers verified against local HTTP fixture")
        assert len(generated) >= 2, "Picker did not submit drawn regions without cookies"
        return result.returncode or (0 if "0 failed" in output else 1)


if __name__ == "__main__":
    raise SystemExit(main())
