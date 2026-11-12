# Current priority

Keep the existing ImageWriter and OpenHD image flows working. Fix concrete
flashing, configuration and startup bugs. Do not implement the storage
provisioning migration below as part of current release fixes.

# TODO for the next OpenHD release

Move storage provisioning out of OpenHD/SysUtils first boot and into ImageWriter.
This is a deferred proposal, not authorization to start the migration now.

- Define a shared storage manifest for partition layouts, filesystems, labels,
  growable partitions and configuration injection.
- Have ImageWriter complete partitioning, formatting, filesystem expansion and
  verification before declaring a flash successful or rebooting the target.
- Support SD/eMMC, ORQA through NXP UUU, and Luckfox NAND through the appropriate
  loader. Preserve device-side NAND bad-block management.
- Keep camera detection, USB role selection and runtime hardware setup on the
  target.
- Remove automatic storage formatting from normal OpenHD startup. Camera,
  telemetry and radio startup must not depend on recordings storage preparation.
- Preserve existing settings and recordings in update flows; distinguish updates
  from explicitly requested full flashes.

Background: a failed first-boot formatting attempt on an already-mounted ORQA
recordings partition left `/run/openhd/hold.pid` behind and blocked OpenHD.
The current SysUtils fix preserves mounted recordings and releases operation-owned
startup holds on both success and failure. Retain that fix while this migration
is deferred.
