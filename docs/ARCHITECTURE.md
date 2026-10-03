# Architecture — odin-adwaita

## Generation

`make generate` runs runic over each package's `rune.yml`. The headers are /usr/include/libadwaita-1 (libadwaita-1-dev).
The output is committed, so consumers need neither runic nor the headers to build.

## Patches

Where runic gets a signature wrong, the fix is made by hand, listed in
[PATCHED.md](PATCHED.md), and pinned in `<pkg>/patched.odin` by a typed variable. A
regeneration that drops a patch then fails to compile.

## Collections

The collection `adwaita` points at this repo's root. Packages import their siblings and the
bindings below them through collections, never by relative path.

![dependency graph](../diags/odin-adwaita.svg)
