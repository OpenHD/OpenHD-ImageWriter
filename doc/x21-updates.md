# X21B system and application updates

ImageBuilder produces three different outputs:

- `firmware-*.zip` is the complete USB recovery image. Select it when the X21
  is connected in Loader/MaskROM mode.
- `OpenHD-X21B-full-*.ohd_base` updates the kernel, system and applications
  through SWUpdate. Copy it to the root of the update card. The device selects
  the inactive A/B slot during installation.
- `OpenHD-X21B-applications-*.ohd` updates applications only. It cannot install
  camera driver changes.

ImageWriter recognizes both update extensions, preserves the selected filename,
places them at the card root and removes older updates of either type. Package
checksums are verified before the new file is committed. A full update needs a
card large enough for the system and application images; the standard X21 USB
virtual disk is not enlarged to fit debugging or full-system packages.

SWUpdate containers are not raw NAND images. Use the complete firmware ZIP for
USB recovery. The device's updater must interpret `.ohd_base` to choose the
correct A/B slot.

The current ImageWriter development source is on `dev-branch`; legacy release
history remains available separately. Public product camera naming is
`arducam_openhd`.
