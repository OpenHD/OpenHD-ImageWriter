# Rockchip USB flashing

Select the complete firmware ZIP and the connected Rockchip target. Pico Ultra,
Ultra W and Zero packages include the SDK's matching RV1106 `download.bin`, a
`.env.txt` flash plan, and the full GPT disk as `disk.img`. A GitHub artifact
containing a single nested `firmware.zip` is also supported.

ImageWriter downloads the package loader when the board is in MaskROM, waits
for Loader readiness, writes the declared sector ranges, and reads every range
back before reporting success and resetting the board. Verification includes
the padding in the last sector and any separately written `parameter.txt`.
A mismatch, USB read failure, or incomplete source file stops the operation.

On Windows, each loader entry uses its own Rockusb control handle. Bulk commands
open only the active pipe, close it before switching direction, and check the
command status. RV1106 loaders may retain MaskROM-like USB descriptors; after
downloading the loader, a successful readiness command also establishes that
the bulk transport is available.

The native Windows build and the automated readback tests cover the software
path. A successful vendor-tool flash does not by itself establish that the
ImageWriter path works on hardware; test MaskROM loading, the full write and
readback, and boot separately when changing the USB transport.
