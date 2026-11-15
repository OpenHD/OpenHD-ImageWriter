# OpenHD offline maps

Open **Offline maps** in ImageWriter before connecting an SD card or selecting
an image. Pick a region and select **Download map**. ImageWriter downloads a
prebuilt Shortbread vector MBTiles pack from Geofabrik, checks the archive and
selects it for the next Ground flash. A successful download is cached locally.
For another area or a smaller extract, select **Choose MBTiles file…** and
open a Shortbread vector pack.

ImageWriter copies the selected file to `openhd/maps` on the Config partition
when flashing Ground. The selection takes precedence over a FleetControl
map. Use **Remove** to clear it. Large regions may exceed the free space on
the Config partition. Use a smaller Shortbread extract in that case. Air
images do not receive offline maps.

In QOpenHD choose **OpenHD Offline**, or use **Jump to map** under **OSD &
Application > Map**. QOpenHD draws the vector tiles from local storage using
an installed vector renderer. The current Windows installer includes a
compatible renderer. Existing GLDMAP1 packages from FleetControl are still
accepted by ImageWriter.

Regional downloads are provided by [Geofabrik](https://download.geofabrik.de/).
Additional [Shortbread downloads](https://shortbread-tiles.org/download/) include
custom MBTiles extracts. Map data is by [OpenStreetMap contributors](https://www.openstreetmap.org/copyright)
under ODbL.

An optional public Mapbox token enables the Mapbox preview. **Save on this
computer** stores it in ImageWriter's local preferences. While signed into
FleetControl, use **Save to FleetControl** or **Restore from FleetControl** to
move the token between your account and a computer. The preview token is
separate from tokens explicitly configured on individual Ground profiles.

The Windows download workflow no longer needs the bundled Node map renderer.
For a locally hosted catalog fixture, set `OPENHD_MAP_CATALOG_BASE_URL` to the
base URL, including a trailing slash. The catalog appends the corresponding
Geofabrik-style region path and filename.
