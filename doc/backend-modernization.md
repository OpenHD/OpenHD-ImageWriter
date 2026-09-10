# Backend modernization notes

This document compares OpenHD ImageWriter with the official Raspberry Pi
Imager backend. It deliberately excludes QML, visual assets, and user-interface
redesign work.

## Comparison point

- OpenHD branch: `release`, commit `1474f8d` (2026-09-10)
- Raspberry Pi Imager: `main`, commit `cf71bec` (2026-09-03)
- Latest inspected Raspberry Pi Imager release: `v2.0.11.1` (2026-08-17)
- The OpenHD backend is structurally closest to Raspberry Pi Imager 1.7.x.
  Some imported files, including `downloadextractthread.cpp` and
  `drivelistmodel.cpp`, still match the 1.7.x implementation exactly before
  OpenHD-specific changes are applied.

The current backends should not be merged file-for-file. OpenHD has important
product-specific behavior in `imagewriter.cpp` and `downloadthread.cpp`, while
Raspberry Pi Imager 2.x moved their old responsibilities into many smaller
components. The useful approach is to port those components behind OpenHD's
existing public `ImageWriter` API.

## Highest-priority ports

### 1. Platform file-operations layer

Port the upstream `FileOperations` abstraction and its Linux, Windows, and
macOS implementations first. This is the foundation for nearly every other
write-pipeline improvement.

Benefits present in upstream:

- exclusive device locking, with controlled fallback;
- direct-I/O support with alignment handling;
- correct platform-native device sizing and error classification;
- cancellation-aware flush/sync operations and bounded syscall handling;
- asynchronous I/O (`io_uring` on supported Linux systems and IOCP on Windows);
- queue-depth reduction and synchronous fallback for troublesome media;
- safer Windows volume locking without indiscriminately deleting drive
  letters;
- tests that exercise ordinary files, scratch images, and loop devices.

OpenHD currently writes through `QFile`/`WinFile` directly. Retain
OpenHD-specific image customization above the new abstraction rather than
putting product logic into the platform implementations.

Relevant upstream files:

- `src/file_operations.{h,cpp}`
- `src/linux/file_operations_linux.{h,cpp}`
- `src/windows/file_operations_windows.{h,cpp}`
- `src/mac/file_operations_macos.{h,cpp}`
- `src/timeout_utils.h`
- `src/test/file_operations_test.cpp`
- `src/test/timeout_utils_test.cpp`

### 2. Bounded producer/consumer write pipeline

Replace the current two-buffer `QtConcurrent` extraction/write path with the
upstream bounded ring-buffer pipeline:

- `RingBuffer` provides explicit backpressure and cancellation;
- `BlockBatcher` coalesces small archive blocks into efficient writes;
- `AlignedBuffer` makes direct I/O safe;
- `SystemMemoryManager` sizes input, write, verification, and async queues for
  the host instead of relying on fixed sizes;
- `AsyncCacheWriter` prevents a slow cache disk from stalling an otherwise
  healthy image write.

The upstream implementation also fixes slot-recycling and lock-recursion bugs
that are easy to reintroduce if only part of the pipeline is copied. Port this
as one unit and port its ring-buffer/block-batcher tests with it.

### 3. Stall detection and recovery

Port `WriteProgressWatchdog` after the file-operations layer. It observes
download, write, verification, and pending-I/O progress and attempts recovery
in stages: poll completions, reduce queue depth, drain and switch to synchronous
I/O, then abort on a hard timeout.

This addresses a major weakness in the current backend: a device can block in
write or final flush with no coordinated recovery policy. The watchdog should
remain backend-only; existing QML can continue consuming the current progress
and error signals.

### 4. Download and network hardening

Port the behavior of `CurlNetworkConfig` and `CurlFetcher`, but keep OpenHD's
URLs, update manifests, certificate checks, and telemetry policy.

Useful upstream behavior includes:

- one process-wide curl initialization and user-agent source;
- system proxy detection;
- automatic IPv4 fallback when the normal request path fails;
- HTTP/1.1 retry for HTTP/2 TLS failures;
- effective-URL tracking after redirects;
- consistent timeouts, cancellation, and error reporting.

Do not copy upstream endpoints or Raspberry Pi telemetry/customization logic.

### 5. Extraction and verification correctness

Port the upstream extraction fixes independently of its UI changes:

- discover decompressed sizes for local gzip and zstd images;
- support multi-frame zstd using `ZSTD_findDecompressedSize`;
- coalesce libarchive output into larger writes;
- never emit success after extraction, flush, or cancellation failure;
- handle unaligned writes on raw macOS devices;
- use adaptive verification buffers and bypass stale OS caches;
- preserve the existing OpenHD rule that validates disk-image size and its
  separate `.ohd`/SWUpdate flow.

### 6. Drive enumeration and safe target handling

Replace the old bundled `drivelist` plus `mountutils` integration with the
current upstream drive-list implementation. Important improvements include:

- more reliable Windows system-drive detection;
- UASP devices classified as USB;
- macOS lifetime/crash fixes;
- clearer enumeration errors;
- Linux loop-device and util-linux compatibility fixes;
- explicit exclusive-open behavior that prevents automounters racing a write.

This needs tests before it becomes the default because target selection is the
highest-consequence part of an image writer.

### 7. Formatting implementation

Replace shelling out to `diskpart`/`fat32format` and ad-hoc platform formatting
with upstream `DiskFormatter` where feasible. Its formatter handles large
media and FAT metadata consistently and has a dedicated test suite. Keep the
OpenHD update-partition semantics as acceptance tests before changing this
path.

### 8. Build and dependency modernization

The existing build uses CMake 3.9, Qt 5, OpenSSL 1.1.1, zlib 1.2.11, zstd 1.5.0,
and libarchive 3.5.2-era sources. Modernize the dependency system before
copying large portions of upstream code:

- move to a current CMake baseline and generated build-time version metadata;
- move to Qt 6 as a separate compatibility step, without modifying QML during
  the backend work;
- replace checked-in dependency source trees/binaries with pinned, auditable
  dependencies (upstream now centralizes this in CMake modules/submodules);
- use native cryptography where appropriate (CNG on Windows, CommonCrypto on
  macOS, GnuTLS on Linux) and remove the OpenSSL 1.1.1 runtime bundle;
- enable warnings, sanitizers where available, and a headless test target.

Qt 6 migration and backend porting should be separate commits. Combining them
would make regressions much harder to isolate.

## OpenHD code that must be preserved

The following behavior is product-specific and should be separated into small
services before replacing the old Raspberry Pi backend:

- OpenHD release/dev manifest selection and downloads;
- `.ohd`/SWUpdate validation and upload;
- premium certificate validation and installation;
- OpenHD `settings.json` generation and configuration-partition selection;
- Rockchip device detection and flashing;
- OpenHD telemetry decisions and identifiers;
- the current QML-facing properties, invokables, and signals until the UI is
  redesigned separately.

Suggested extraction boundaries are `OpenHDManifestService`,
`OpenHDImageCustomizer`, `OpenHDUpdateWriter`, `CertificateService`, and a
common `FlashTarget` interface implemented by block-device and Rockchip
targets.

## Upstream features not recommended for this port

Do not initially import Raspberry Pi-specific hardware/OS models, rpiboot,
fastboot provisioning, Pi Connect registration, EEPROM/secure-boot tooling,
Raspberry Pi cloud-init/preseed generation, icons, sounds, native dialogs, or
wizard/QML code. They add substantial coupling without improving OpenHD's
ordinary SD/USB image-writing path.

## Proposed delivery sequence

1. Repair the repository Git index, establish a clean baseline, and add a
   headless test target.
2. Add characterization tests for OpenHD manifests, image type routing,
   `.ohd` updates, certificate flow, and generated settings.
3. Port `FileOperations`, timeout utilities, and platform tests.
4. Port `RingBuffer`, `BlockBatcher`, memory sizing, and async cache writing.
5. Integrate the new pipeline into `DownloadThread` while retaining its public
   API and OpenHD customization hooks.
6. Add the watchdog and recovery state machine.
7. Port network/retry and extraction correctness improvements.
8. Replace drive enumeration and formatting after destructive-operation tests
   exist.
9. Modernize dependencies, then migrate the backend build to Qt 6.

Each stage should remain buildable and should avoid QML changes. This sequence
also keeps the existing OpenHD release path usable while the backend is being
replaced incrementally.

## Refactoring progress

- `OpenHDStorageService` now owns OpenHD media discovery, FAT-partition
  selection, `.ohd` recognition, and the target-card file helpers.
- `ImageWriter` retains its existing invokable methods as thin delegates, so
  this first extraction does not require any QML changes.
- `OpenHDImageCustomizer` now owns `settings.json` generation, camera-type
  mapping, optional `QOpenHD.conf` installation, and premium-certificate
  installation. `DownloadThread` is left responsible for locating/mounting the
  boot partition and translating errors for the existing UI contract.
- A headless `openhd_backend_tests` CTest target characterizes camera mapping,
  role overrides, display settings, file installation, invalid-certificate
  rejection, and FAT-mount scoring without accessing a real target disk.
- The first upstream-inspired write foundation is now present: a common
  `FileOperations` contract with Windows, Linux, and macOS implementations,
  plus tested bounded `RingBuffer` and `BlockBatcher` primitives. The
  production `DownloadThread` block-device path now uses this contract for
  exclusive open, native sizing, seek, write, flush, cancellation, and verify
  reads. macOS privileged `authopen` remains a narrow adapter around the new
  platform layer.
- The compressed-download handoff now uses the bounded `RingBuffer` in the
  production extraction path, replacing its unbounded-bytes deque/condition
  variable implementation. `BlockBatcher` now coalesces production writes into
  one-megabyte device operations and flushes the final partial batch before
  hash validation and read-back verification.
- A backend-only `WriteProgressWatchdog` now watches actual native write and
  flush operations through the existing progress poller. It logs a warning at
  30 seconds, requests native cancellation plus one offset-safe retry at 60
  seconds, and reports a hard device timeout at 180 seconds. Network idle time
  is deliberately excluded, and the transition policy has deterministic
  headless tests.
- Curl configuration and retry decisions now live in `CurlNetworkConfig` and
  `CurlRetryPolicy`. Large downloads use system proxy discovery, TCP
  keepalives, HTTP/2 with HTTP/1.1 recovery, a one-time IPv4 fallback, bounded
  resumable retries, and redirect protocol restrictions. Effective URL and
  server-IP diagnostics are collected before the curl handle is destroyed.
- Image extraction now pads only the final image extent (rather than arbitrary
  libarchive chunks), checks the final asynchronous write, rejects multi-entry
  disk-image archives, and cannot report success after cancellation. Multi-file
  extraction rejects absolute/traversal paths, links, special files, overly
  long names, and excessive entry counts before creating them.
- `DriveSafetyPolicy` now normalizes and deduplicates stable device keys before
  they reach the existing model, treats UASP devices as USB, sanitizes deceptive
  Unicode/control characters in device descriptions, protects system mount
  points, filters unsafe virtual disks, and retains the previous list after a
  transient enumeration error.
- Drive enumeration now uses a small native `DeviceDescriptor` contract with
  separate Windows, Linux, and macOS implementations. Windows uses Unicode
  SetupAPI/DeviceIoControl discovery with UASP and system-volume detection;
  Linux uses bounded `lsblk` JSON parsing with an older-util-linux fallback;
  macOS uses Disk Arbitration with corrected IOKit/APFS object lifetimes. The
  polling thread now stops cooperatively without racing its termination flag.
- Windows preparation locks and dismounts every target volume with RAII before
  changing the disk, clears the old layout through bounded native IOCTLs, and
  holds the physical disk without permitting competing writers. The old
  unbounded pre-lock `diskpart clean` and `WinFile` preparation path are no
  longer used.
- `DiskFormatter` now creates the MBR and FAT32 filesystem directly through
  `FileOperations`, writing the primary and backup boot/FSInfo sectors, clearing
  both FATs, and publishing the MBR only after the filesystem is complete.
  Windows reset/format no longer launches `diskpart` or ships the separate
  `fat32format.exe`. Post-write partition refresh and missing drive-letter
  assignment use bounded native volume APIs instead.
