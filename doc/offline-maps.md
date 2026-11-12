# OpenHD offline maps

QOpenHD can use the same `.glidemap` packages as OpenHD Glide. Select **OpenHD Offline** in the map provider list;
the existing QtLocation map, vehicle track, home marker, mission items, ADS-B overlays, pan, and pinch zoom continue to
work normally, but map tile requests remain entirely local.

QOpenHD searches these locations:

- `GLIDE_MAP_PACKAGE_DIR` when explicitly configured;
- `/usr/share/openhd-glide/assets/maps/packages`;
- `/usr/local/share/openhd-glide/assets/maps/packages`;
- the platform application-data `maps` directory;
- `$XDG_DATA_HOME/openhd-glide/maps` on Linux.
- `~/openhd-glide/assets/maps/packages` for side-by-side desktop development.

The embedded adapter binds an ephemeral TCP port on `127.0.0.1` and exposes packaged PNGs as an XYZ endpoint to the
Qt OSM mapping plugin. It never binds a LAN interface and the offline provider has no internet fallback. Packages are
selected from GPS bounds using highest available zoom and then smallest covered area; tile lookup can still fall back
to another installed package when the user pans across package boundaries.

The package format is `GLDMAP1`, shared with OpenHD Glide and FleetControl.

## Create a map in QOpenHD

Open **OSD & Application > Map > Create offline map**. Enter a town or region,
press **Find region**, select a result, then pan/zoom the preview. Press
**50 km radius** to select the map centre, or tap a point on the preview.
The circle always has a 50 km radius (100 km across); its enclosing rectangle
is saved so the entire circle is covered. Alternatively, press **Draw rectangle**
and drag across your flying area. Choose detail and press **Create map**. Download status, rendering progress and a Cancel
button remain available while it runs. After a successful save, QOpenHD selects
**OpenHD Offline** automatically. No restart, account, paid key or Python runtime
is needed on the board.

The preview uses ordinary online OpenStreetMap tiles. Offline generation instead
requests road and waterway geometry from Overpass and renders its own PNG tiles;
it never prefetches the public OSM raster tile service. This is a simple road and
waterway map, rather than satellite imagery or the full online cartographic style.
OpenStreetMap attribution is displayed in the UI, without a watermark across the
saved tiles. Search uses Nominatim only on an explicit submitted search, with a
one-second throttle and an in-memory results cache.

Each package covers one rectangle, with zooms 0 through 13 (overview), 14
(standard), 15 (high) or 16 (maximum). Limits are 11,000 square kilometres,
262,144 tiles, 1 GiB per package and two million geometry points. Geometry is
fetched in sections of at most approximately 25 km per side. Higher detail takes
more time and storage. Polar areas beyond 85 degrees and date-line crossings are
not supported. Downloads require an internet connection. A failed or cancelled
generation never installs a partial package; existing packages stay available.

In Map settings, choose an installed package and press **Jump to map** to frame
its coverage, even when your current position is elsewhere or unavailable. This
disables following without changing GPS or reference position, and never creates
a location marker at the package centre. Use the follow button to return to your
real reference position. Small and expanded maps support pan, pinch/wheel zoom
and the + / - controls; the separate hand handle still moves the HUD widget.

## Include a map when flashing with ImageWriter

Open **Offline maps** from the ImageWriter sidebar. You can create a map before
inserting an SD card or choosing a flash target.

1. Download a [Shortbread vector MBTiles extract](https://shortbread-tiles.org/download/)
   that covers your flying area and open it with **Choose map data**. ImageWriter
   remembers the source file so you can build other maps from it.
2. Find a place or move the map, then select a circle radius or draw a rectangle.
   The package covers the circle's enclosing rectangle. Choose the maximum
   detail and select **Create map**.
3. The completed package is selected for subsequent Ground flashes. Review
   shows which local package will be included. Choose **Remove** to clear the
   selection, or **Open folder** to copy the saved package to another computer.
   Each new map becomes the selected package. Previously generated packages
   remain in the folder.

ImageWriter copies the selected package to **openhd/maps** as part of Ground
image customization. The local selection takes precedence over a FleetControl
map for that flash. QOpenHD discovers it at `/Config/openhd/maps` under
**OpenHD Offline**. The preview and place search use online services. The
actual render uses the local extract and bundled map assets.
The selected package must fit the flash target's configuration storage.
Use a smaller area or lower detail when that space is limited.

### Building ImageWriter with the styled renderer

Configure ImageWriter with `-DOPENHD_BUNDLE_MAP_RENDERER=ON` and build it as usual.
The bundle step uses Node.js 22.13 or newer, npm, and tar. It installs the pinned
MapLibre Native, VersaTiles style and Sharp dependencies, downloads the pinned
glyph and sprite archives, and stages the renderer next to the app. Check the
[MapLibre Native Node platform requirements](https://github.com/maplibre/maplibre-native/tree/main/platform/node)
for the host OS and architecture. The Windows packaging workflow enables this
option and copies the Visual Studio C++ redistributable DLLs beside the bundled
Node executable. For an external developer bundle, set
`OPENHD_MAP_RENDERER_DIR` to its directory.

The renderer opens the SQLite archive read-only and renders VersaTiles
Colorful PNGs for ImageWriter's existing GLDMAP1 writer. Retain the bundled
notices and display OpenStreetMap attribution wherever the map is shown.

For local fixture testing, `OPENHD_MAP_SEARCH_URL` and `OPENHD_MAP_DATA_URL` can
override Nominatim and Overpass endpoints. Normal builds use their public HTTPS
endpoints. Do not point the data endpoint at a raster tile server.

Validation:

- `cmake -S tests/offline-map-builder -B build-offline-builder` and build/run
  `offline-map-builder-test` test search, bounds, generated packages served by
  the production offline provider, incomplete responses and cancellation.
- `python tests/run_offline_map_ui_test.py --qt-bin <Qt-5-bin>` tests the real
  picker, rectangle selection and create action; its generator is a fixture.
- ImageWriter has a corresponding `offline_map_builder_tests` target under
  `src/test` and `scripts/run_offline_map_ui_test.py`.

## Preview tile requests and caches

Online OSM maps and the create-map preview identify the app with a stable
`OpenHD-OfflineMaps/1.0 (+https://openhd.org)` User-Agent, use the explicit HTTPS
OSM tile endpoint, and disable adjacent-zoom prefetching. Qt 5's built-in legacy
HTTP map styles are not selected. Mapbox retains its provider-specific styles.
Preview tiles, normal online tiles, and localhost offline-package tiles have
separate persistent caches below the application's `map-tiles` cache directory,
so Qt's shared custom-map IDs cannot mix tiles or cached error images between
those sources. Tile-header regression tests use a local HTTP fixture rather than
requesting public tiles. On the Pi, live preview tile fetching was also checked.

When a Mapbox key is configured, the preview uses the current Mapbox Styles
raster API through a localhost-only adapter. This also provides the normal Mapbox
map on Pi Qt kits without Mapbox GL; Qt's obsolete v4 raster API is not used.
The token stays in backend requests and is never placed in QML tile URLs or
error messages. Mapbox preview attribution/logo apply only to the online display;
created `.glidemap` files still contain locally rendered OSM geometry only.
Mapbox preview data uses its own cache, separate from OSM and package tiles.
`OPENHD_MAPBOX_TILE_URL` overrides the adapter endpoint for local fixture tests.
