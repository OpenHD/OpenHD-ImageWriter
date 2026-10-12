# Initial configuration and FleetControl

Select a craft in FleetControl, configure its image options, then use **Save
configuration** to save a version-1 initial snapshot on that craft. **Export JSON**
saves the initial `settings.json` locally. The snapshot uses the image-writing
builder and excludes FleetControl login credentials and enrollment tokens.

Selecting the craft again restores the editable settings and typed
`parameter_defaults`. A profile without a plan clears the previous craft's plan.
Open initial-default controls follow profile changes; Ground removes camera
component defaults. OpenHD seeds new persistent owners only, preserving existing
device preferences.

Hardware selectors use generated platform IDs and labels from OpenHD's
`settings/platforms.json`. The online craft editor refreshes the platform catalog
from `/api/imagewriter/platforms`; offline use retains the bundled list. Combined
legacy board names require a concrete selection. Image availability and flashing
transport still depend on the selected image.

FleetControl's Hangar editor shows and downloads the captured initial file.
Ordinary craft edits preserve that snapshot until it is explicitly saved again.
The full contract is documented in OpenHD's `OpenHD/settings/README.md`.

Tests: `node src/test/fleet_profiles_test.js`, `node src/test/catalog_test.js`,
`node src/test/fleetcontrol_catalog_test.js`, and the CMake targets
`openhd_backend_tests` / `initialsettings_qml_test` under `src/test`.
