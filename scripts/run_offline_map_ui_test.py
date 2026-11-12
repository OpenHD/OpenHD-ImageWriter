"""Exercise the production picker and the standalone Offline Maps tab.

Uses Qt 5 Location with a real map canvas; map generation is a small UI fixture.
"""
import argparse
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import contextlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
@contextlib.contextmanager
def tile_fixture():
    requests = []
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
        def log_message(self, *_args): pass
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    Thread(target=server.serve_forever, daemon=True).start()
    try: yield f"http://127.0.0.1:{server.server_port}/", requests
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
        id: builder
        property string previewCacheDirectory: "CACHE_DIR"
        property bool busy: false
        property bool searching: false
        property string status: "Choose a search result, then draw your area."
        property double progress: 0
        property var searchResults: []
        property int generatedCount: 0
        property var lastBounds: []
        signal generated(string path)
        function tileCount(s, w, n, e, zoom) { return s < n && w < e ? 20 : -1 }
        function search(query) {
            searchResults = [{name: "Test region", north: 50.01, south: 49.99, west: 7.99, east: 8.01}]
        }
        function generate(name, s, w, n, e, zoom) {
            generatedCount++
            lastBounds = [s, w, n, e]
            generated("test.glidemap")
        }
        function cancel() { busy = false }
    }
    OfflineMapDialog {
        id: dialog
        builder: builder
        initialLatitude: 50
        initialLongitude: 8
        onMapReady: scene.packageReady = true
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
            canvas.item.radiusMode = false
            canvas.item.drawing = true
            mousePress(selection, 120, 25)
            mouseMove(selection, 400, 95)
            mouseRelease(selection, 400, 95)
            verify(canvas.item.selectionValid)
            verify(canvas.item.north > canvas.item.south)
            verify(canvas.item.east > canvas.item.west)
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
            builder.busy = true
            builder.progress = 0.45
            builder.status = "Creating offline map..."
            wait(50)
            var progress = findChild(dialog, "offlineMapProgress")
            verify(progress.visible)
            verify(!progress.indeterminate)
            compare(progress.value, 0.45)
            verify(!create.enabled)
            verify(create.mapToItem(dialog.contentItem, 0, create.height).y <= dialog.contentItem.height + 1)
            mouseClick(findChild(dialog, "cancelOfflineMap"))
            verify(!builder.busy)
            verify(create.enabled)
            mouseClick(create)
            compare(builder.generatedCount, 1)
            compare(builder.lastBounds[0], canvas.item.south)
            compare(builder.lastBounds[3], canvas.item.east)
            verify(scene.packageReady)
            dialog.close()
        }
    }
}
'''

STYLED_TEST = '''import QtQuick 2.12
import QtTest 1.2
import "qmlcomponents"

Item {
    id: scene
    width: 950; height: 740
    property string currentView: "home"
    QtObject {
        id: imageWriter
        function getValue(key) { return "" }
        function setSetting(key, value) {
            if (key === "offlineMapCreatorPackagePath")
                shell.localOfflineMapPath = value
        }
    }
    QtObject { id: shell; property string localOfflineMapPath: "" }
    QtObject {
        id: builder
        property bool busy: false
        property bool searching: false
        property real progress: 0
        property string status: ""
        property string previewCacheDirectory: "CACHE_DIR"
        property var searchResults: []
        property int created: 0
        signal generated(string path)
        function tileCount(s, w, n, e, zoom) { return s < n && w < e ? 20 : -1 }
        function generateStyled(archive, name, s, w, n, e, zoom) {
            if (String(archive).endsWith("area.mbtiles") && s < n && w < e && zoom === 14) {
                created++
                generated("created.glidemap")
            }
        }
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
        builder: builder
    }
    TestCase {
        name: "OfflineMapsTab"; when: windowShown
        function test_createWithoutStorage() {
            var tab = findChild(sidebar, "navigation-offlinemaps")
            verify(tab.visible && tab.enabled)
            mouseClick(tab)
            tryCompare(page, "visible", true)
            compare(page.tileCount, 0)
            var circle = findChild(page, "selectMapCircle")
            tryCompare(circle, "enabled", true)
            circle.clicked()
            tryCompare(page, "tileCount", 20)
            page.archive = "file:///area.mbtiles"
            var create = findChild(page, "createStyledMap")
            verify(create.enabled)
            create.clicked()
            compare(builder.created, 1)
            compare(page.stagedMap, "created.glidemap")
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
    with tile_fixture() as (tile_url, requests), tempfile.TemporaryDirectory(prefix="openhd-offline-ui-") as temp:
        folder = Path(temp)
        for name in ["OfflineMapDialog.qml", "OfflineMapSelection.qml", "OfflineMapButton.qml", "OfflineMapsPage.qml"]:
            source = (ROOT / "src/offlinemaps" / name).read_text(encoding="utf-8")
            source = source.replace("https://tile.openstreetmap.org/", tile_url)
            (folder / name).write_text(source, encoding="utf-8")
        (folder / "tst_picker.qml").write_text(TEST.replace("SCREENSHOT", args.screenshot.as_posix()).replace("CACHE_DIR", (folder / "tiles").as_posix()), encoding="utf-8")
        (folder / "tst_styled.qml").write_text(STYLED_TEST.replace("CACHE_DIR", (folder / "styled-tiles").as_posix()), encoding="utf-8")
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
            assert headers.get("User-Agent") == "OpenHD-OfflineMaps/1.0 (+https://openhd.org)", headers
            assert "no-cache" not in headers.get("Cache-Control", ""), headers
        print("Preview tile headers verified against local HTTP fixture")
        return result.returncode or (0 if "0 failed" in output else 1)


if __name__ == "__main__":
    raise SystemExit(main())
