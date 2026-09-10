# Backend characterization tests

These tests exercise OpenHD settings generation and storage selection without
opening, formatting, or writing a real block device. They can be built through
the application CMake project or independently of its legacy bundled
dependencies.

The suite also exercises `FileOperations` against a temporary scratch image,
including exclusive locking, native sizing, flush, read-back, and cancellation,
as well as ring-buffer backpressure, archive block batching, deterministic
write-stall watchdog transitions, safe archive paths, and curl retry policy.
Drive-target policy tests also cover system mounts, UASP-as-USB classification,
unsafe display characters, and non-removable virtual disks. The native FAT32
formatter is exercised against a scratch image, including its MBR, partition
offset, primary/backup boot records, label, and target-size preservation.

Example standalone Windows build for the current 32-bit application toolchain:

```powershell
cmake -S src/test -B build-src-tests-win32 -A Win32 `
  -DCMAKE_PREFIX_PATH=C:\Qt\5.15.19\msvc2019 `
  -DOPENSSL_ROOT_DIR=$PWD\openssl111\openssl-1.1\x86
cmake --build build-src-tests-win32 --config Release
ctest --test-dir build-src-tests-win32 -C Release --output-on-failure
```

Use matching Qt and OpenSSL directories when building another architecture.
The `Backend tests` GitHub Actions workflow runs the same standalone suite on
Windows, Ubuntu, and macOS.
