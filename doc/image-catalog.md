# Image catalog format

The catalog source should be a flat YAML list. ImageWriter owns grouping,
deduplication, and display order; the source does not contain categories or
`subitems`.

```yaml
- name: OpenHD 2.7.1 for Raspberry Pi
  manufacturer: raspberry-pi
  board: raspberry-pi-2-4
  channel: stable
  url: https://example.org/OpenHD-rpi-2.7.1.img.xz
  release_date: 2026-08-28
  image_download_size: 812345678
  extract_size: 4294967296
  extract_sha256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  description: OpenHD for Raspberry Pi 4 and 5

- name: OpenHD 2.7.1 for Radxa Rock 5B
  manufacturer: radxa
  board: rock5b
  channel: stable
  url: https://example.org/OpenHD-rock5b-2.7.1.img.xz
  release_date: 2026-08-27
  image_download_size: 912345678
  extract_size: 8589934592
  extract_sha256: abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789
```

The publishing step may convert this directly to a bare JSON array or wrap it
as `{ "images": [...] }`. For migration safety, ImageWriter also accepts the
legacy `{ "os_list": [...] }` format, including nested `subitems`.

Required image fields are `name` and `url`. Production entries should also
provide `release_date`, `image_download_size`, `extract_size`, and
`extract_sha256` so ImageWriter can verify the download and destination.

`manufacturer` and `board` are recommended but optional. ImageWriter falls back
to classifying the platform, target, name, description, and URL. `channel`
should be `stable` or `development`.

ImageWriter owns this display hierarchy and order:

1. OpenHD Hardware: X20, X21
2. Raspberry Pi: Raspberry Pi 2–4, Compute Module 3 / 4, Raspberry CM0,
   Raspberry Pi 5
3. Radxa: ROCK 5A, ROCK 5B, ROCK 3A, ROCK CM3, Cubie A7
4. Luckfox: Aura, Pico, Lyra
5. Orange Pi: Zero 3W, CM4
6. Orqa: GCB
7. UXV: Module-35
8. Other Hardware

The same hierarchy is used for stable and development images. Entries are
deduplicated by URL, board groups have a fixed local order, and releases are
sorted newest-first by `release_date` and then version. Manufacturer icons are
local monochrome assets controlled by ImageWriter; catalog-provided icons are
ignored.
