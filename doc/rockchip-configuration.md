# Luckfox and X21 configuration through MaskROM/Loader

With **apply settings** enabled, ImageWriter stages the normal OpenHD settings,
selected QOpenHD config, certificate and optional map before any USB flash writes.
The supplied firmware ZIP and its matching loader remain required. Configuration
disabled leaves the existing flash flow unchanged.

- Luckfox Pico full-disk firmware: validate both GPT headers, checksums, matching
  partition tables and non-overlapping bounds. Find the unique Microsoft Basic
  Data `ohd_config` partition and install the staged files through a FAT adapter
  whose sector access is confined to that partition. A raw `.img` is copied first;
  the user's input image is never edited. Separate `ohd_config.img` partition
  packages also use the FAT adapter.
- Production X21B NAND firmware: new ImageBuilder bundles reserve static UBI
  volume 1, named `openhd-provision`, inside the existing 100 MiB OHD partition.
  It reserves 16 logical eraseblocks (1984 KiB). ImageWriter validates the UBI
  headers, both identical volume tables and their checksums, then replaces only
  this volume's PEBs and uses fully erased PEBs for expansion. The application
  UBIFS volume, partition offsets and both volume tables remain unchanged.

The X21 payload is a bounded `OHDCFG1` binary capsule containing relative file
paths and contents, with length and CRC32 protection. Paths are limited to the
known OpenHD files and a single map directory. New SysUtils discovers this volume
only on an attached MTD partition named `ohd`, validates the complete capsule,
and installs files under `/Config` using temporary files, fsync and rename before
processing settings or starting services. A completion marker prevents consumed
settings from reappearing on later boots. An interrupted import is retried.
Symlink destinations and invalid capsules are rejected.

Selected Air/Ground markers replace factory role markers. ImageWriter reads
installed FAT files or UBI eraseblocks back before USB flashing, then the existing
Rockusb flow reads back the entire customized flashed image before reset.

Large offline maps may not fit X21's reservation and fail before flashing.
Older X21 images without the reserved volume, devboard ext4 layouts, SWUpdate
`.ohd` inputs and raw NAND formats without this contract cannot accept settings
through this path; ImageWriter reports this before flash writes. Update them with
the appropriate new full firmware ZIP or disable configuration deliberately.

No mass-storage mode, Windows mounting, WSL, Python, ext4 writer or UBIFS repack
tool is needed on the ImageWriter user's computer. Hardware flash/boot testing
remains separate from host filesystem and capsule validation.
