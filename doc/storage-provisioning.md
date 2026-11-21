# Storage preparation during full flashes

ImageWriter owns automatic storage preparation. SysUtils first boot and normal
startup discover and mount existing filesystems; they never create, format or
resize partitions. Camera setup and other runtime hardware detection remain on
the target. Explicit GUI storage actions remain available.

For a raw image on 512-byte logical-sector media, ImageWriter recognizes the
OPENHD FAT volume and validates the MBR/GPT layout. It preserves boot, root and
configuration partitions. It grows only a final FAT32 volume labelled RECORDINGS,
or appends a separate RECORDINGS partition in unallocated space after the image.
It never converts the OPENHD partition into recording storage. A missing free
partition entry or insufficient recording space is an error, not a boot-time job.
Unrecognized images and extended/hybrid MBR layouts are not provisioned by this
path. Existing non-final or fully sized recordings volumes retain their geometry.

The FAT32 writer is shared with ImageWriter's native formatter. Recording boot
sectors, FSInfo, both FATs and the root directory are read back before the new
partition table is published. GPT backup metadata and the final first block are
also read back. These checks run even when download verification is disabled.
This is a fresh-flash operation: a source-image recording volume may be rebuilt
to fit the new medium. It is never used by the .ohd update-upload path.

NXP UUU continues to flash the package's prebuilt data/config/recordings images.
Rockchip/NAND continues through the package layout and loader; this code does
not apply block-device partition resizing to raw NAND or replace bad-block
management. Those transport paths require their own physical validation.

ImageBuilder no longer emits resize.txt triggers, including during updates, and
its shrink helper cannot inject a first-boot resizing rc.local. Legacy SysUtils
Pi/Rock/X20/x86 startup helpers also have automatic resizing removed. Storage
preparation no longer requests a first-boot reboot; camera configuration may
still require one. Already installed images need the corresponding updated
SysUtils/startup files; changing ImageWriter alone cannot patch a running board.

# Diagnosing an initial Windows write failure

The former "Write error while zero'ing out MBR" combined write and flush
failures into one generic message. ImageWriter now reports the target, byte
count, native Windows error number and system text. A failed initial write alone
does not establish whether the cause is access/sharing, transport, media readiness
or controller write protection. Preserve that error and the target identity
before attempting further writes. Windows targets reporting no usable capacity
or unsupported logical-sector geometry are rejected before partition removal.
