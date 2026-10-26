# NXP configuration during flashing

Current ORQA image packages contain a Windows-readable `openhd` FAT32 config
partition and a separate `recordings` partition. ImageWriter requires this layout
when configuration is selected; older packages fail before UUU writes anything.
When configuration is disabled, the package is flashed without customization.

ImageWriter customizes the disposable extracted `config.img` **before flashing**.
The existing OpenHD configuration writer stages `openhd/settings.json`, the
selected QOpenHD config, certificate and optional offline map. A bundled FatFs
adapter installs these files into the FAT image, including long filenames and
subdirectories, then reads every installed file back and compares its contents.
The original downloaded archive remains unchanged.

Only after successful preparation does ImageWriter launch the package's normal
UUU script, which flashes the customized config image alongside the firmware
and retains the normal board reset. Configuration errors, insufficient space and
cancellation stop before flashing. No Windows drive-letter assignment, mass
storage switch or mounted Linux filesystem is involved.

The standalone package `uuu-mass-storage.auto` helper remains available for
manual access later. It is unnecessary for normal ImageWriter configuration.

Luckfox and production X21B now use their MaskROM/Loader transport for the same
prepare-before-flash flow. See [Rockchip configuration](rockchip-configuration.md)
for the FAT partition and static UBI provisioning paths.

Source tests and Windows builds do not prove physical flashing or boot. Test
with the matching ORQA board/bootloader; do not substitute its bootloader onto a
different i.MX8MP board.
