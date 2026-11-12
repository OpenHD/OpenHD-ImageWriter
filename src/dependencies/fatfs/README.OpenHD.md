# FatFs R0.16, patches 1 and 2

Upstream: https://elm-chan.org/fsw/ff/

Source archive: https://elm-chan.org/fsw/ff/arc/ff16.zip
SHA256: `99f7dc1f7e095356e4a9e3dbe29959090d8b948afe2bbc5441e52fdf4b85449e`

Applied official patches:

- https://elm-chan.org/fsw/ff/patch/ff16p1.diff
  SHA256 `7996ddc3135f3d534a8153f7d75d587030e5c8551b003c3b7ee823ffb7fc64bf`
- https://elm-chan.org/fsw/ff/patch/ff16p2.diff
  SHA256 `5cd39f1fc299f0f1dec9fa1ce544dc0bc048b2f6eb3b8161476ed20f9cf1e290`

Copyright and permissive redistribution terms are in the source headers.
OpenHD configures `ffconf.h`: code page 437, stack-based long filename buffers,
UTF-8 API filenames and fixed timestamps. Formatting and exFAT remain disabled.
Upstream whitespace errors were normalized in `ff.c` and `ffconf.h`.
All filesystem access is serialized by the Qt adapter's mutex.
