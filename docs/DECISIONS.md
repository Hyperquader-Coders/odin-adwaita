# Decisions — odin-adwaita

Settled choices. An entry that stops being true is rewritten, not appended to.

## 1. Generated, not hand-written

The bindings are generated with runic from the headers Amber ships, so a library bump is a
regeneration. Hand fixes are the exception and are tracked in [PATCHED.md](PATCHED.md).

## 2. One package, `adwaita`

libadwaita is bound as one package from `adwaita.h`. GTK types come from odin-gtk4 as external
sources (`gtk4:gtk4`), so no GTK type is declared here.

## 3. Headers 1.5.0 and 4.14, types 4.16

The bound version is 1.5.0, the libadwaita headers and library on this machine. runic reads the
GTK 4.14.5 headers installed beside them, while the GTK types come from odin-gtk4, which binds
4.16.13. No mismatch showed: every GTK type adwaita.h names exists in both, and the package type-checks
against odin-gtk4. If a libadwaita bump names a type newer than 4.14, generate against amber-gtk4's
staged headers instead.

## 4. The loaded library must be the bound version

Unlike GTK (odin-gtk4 §3), nothing bundles libadwaita: the distro's library is the one linked.
The test therefore requires the loaded library to equal the README's `**Bound version:**` line
exactly, as well as the header macros.

## 5. `GApplication` and `GtkApplication` collide

Both trim to `Application`, so runic emitted either at random, and a regeneration differed from
the last. `scripts/postprocess.sh` rewrites them to the GTK type (PATCHED.md), which
`patched.odin` pins.

## 6. GObject casts are generated: `ALERT_DIALOG(w)`, `IS_ALERT_DIALOG(w)`

The same casts as odin-gtk4's (its DECISIONS §6): `FOO` and `IS_FOO` for every
`TYPE_FOO :: foo_get_type`, written to `adwaita/type_casts.odin` by `scripts/type-casts.sh`, with
the names of the fork's `adw` casts. `FOO(w)` returns `^Foo` through `gobject.type_cast` (a wrong
cast logs a critical under `GTK_SAFE_CAST`), `IS_FOO(w)` returns `glib.boolean`. Enums, flags and
error domains are skipped, and so are the two boxed types, `BreakpointCondition` and
`SpringParams`, which are a fixed list in the script. A name already declared in the package is
skipped, not renamed; none is today. Pascal-case names are looked up among the declared types,
not derived. Every skip is listed on stderr during `make generate`.

## 7. Flag enums are bit_sets, chosen by a list

C flag types are `bit_set[FooBit; u32]`, so callers write `{.TAB_VIEW_SHORTCUT_CONTROL_TAB,
.TAB_VIEW_SHORTCUT_ALT_ZERO}`. `postprocess.sh` rewrites the enums runic emits; the members of
`FooBit` are bit indices, and the type keeps the C size (4 bytes) and bits, so procedures take and
return it by value unchanged. `TAB_VIEW_SHORTCUT_NONE` is the constant `TabViewShortcuts{}` and
`TAB_VIEW_SHORTCUT_ALL_SHORTCUTS` (`0xFFF`) the set of all twelve members. The list is the one
`<bitfield>` entry of Adw-1.gir, `TabViewShortcuts`. A new GFlags type in a header bump is added
to the list by hand; generation fails if a listed enum is missing, negative or has no single-bit
member. A value rule cannot tell them from plain enums: `ToastPriority`, `ColorScheme` and the
other enums are 0, 1, 2 and are not flags.

## 8. Parameters are single objects unless declared

runic 0.8 writes `[^]T` for a pointer parameter whose C name ends in `s` (`settings`, `lines`),
however many elements it holds, which lets a caller index past one element, and drops a trailing
`va_list`, binding the procedure as `#c_vararg ..any`. Amber's runic fork (branch `amber-patched`)
has `parameters: declared`: with it every procedure parameter is `^T` (`T **` is `^^T`) unless
`arrays:` in the package's `rune.yml` lists it, chosen against the C headers, and a va_list
procedure is skipped. Struct members, variables and typedefs keep runic's name guess, and the
parameters of function-pointer types are plain `^T`: a limit of the fork, true in every binding.
Where a binding needs it, the `param_rules` table in `postprocess.sh` restores the `[^]` for
those parameters' real arrays, rewrites single-object struct members and corrects `T ***` outs;
a row that matches nothing fails the build. Rejected: rewriting the output in `postprocess.sh`,
which had to be told each parameter, matched `va_list` procedures by name pattern (it deleted
`list_store_insert_with_values` for containing `_va`) and was a second place to keep in step
with the headers. `scripts/check-generated.sh` stays as the guard that any regeneration, with
any runic, keeps the listed parameters right.

In this repo: the `postprocess.sh` rewrite this replaced had to name 10 single-object parameters.
