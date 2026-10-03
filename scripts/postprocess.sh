#!/usr/bin/env bash
# Rewrites runic's output where runic gets Odin wrong. Run by `make generate` after runic,
# once per package: scripts/postprocess.sh adwaita. Deterministic: the same runic output
# always gives the same file. Every rule is listed in docs/PATCHED.md.
# Flag enums become bit_sets (bit_sets below).
#
# The rules are odin-gtk's (MIT, docs/LICENSE-odin-gtk.md), kept where they still apply to
# runic 0.8 on the system headers.
set -euo pipefail

# The GFlags types. runic emits them as `enum u32` of the C values; a value rule cannot tell
# them from sequential enums, so they are listed. The list is the <bitfield> entries of
# Adw-1.gir that libadwaita's headers declare.
adwaita_flags="TabViewShortcuts"

# bit_sets <file> <strip-prefix> <enum>...: `Foo :: enum u32 {A = 1, B = 4, C = 5, NONE = 0}`
# becomes
#   FooBit :: enum u32 {A = 0, B = 2}        bit indices, prefix stripped from the members
#   Foo :: bit_set[FooBit; u32]              same size and bits as the C type
#   C :: Foo{.A, .B}                         composite masks, by their C names
#   NONE :: Foo{}                            zero members, by their C names; a name with no
#                                            underscore (NONE, FAMILY) is prefixed FOO_ so it is unique
# Members that are not one bit or zero are composites; a composite with a bit that has no
# member is a transmute of the C value. Fails if a listed enum is missing, has a negative
# value or has no single-bit member, so a header bump that changes a flag type is noticed.
bit_sets() {
    local file=$1 strip=$2
    shift 2
    STRIP=$strip NAMES="$*" perl -i -ne '
        BEGIN { $strip = $ENV{STRIP}; %want = map { $_ => 1 } split " ", $ENV{NAMES}; }
        if (/^(\w+) :: enum u32 \{(.*)\}\s*$/ && $want{$1}) {
            my ($name, $body) = ($1, $2);
            delete $want{$name};
            my (@bits, @zero, @comp, $all);
            (my $pre = uc($name =~ s/([a-z0-9])([A-Z])/$1_$2/gr)) .= "_";
            for my $m (split /,\s*/, $body =~ s/\s+$//r) {
                $m =~ /^(\w+) = (-?\d+)$/ or die "postprocess: $name: cannot read member $m\n";
                my ($id, $v) = ($1, $2);
                die "postprocess: $name.$id is negative\n" if $v < 0;
                if ($v == 0) { push @zero, $id }
                elsif (($v & ($v - 1)) == 0) { push @bits, [$id, $v] }
                else { push @comp, [$id, $v] }
            }
            die "postprocess: $name has no single-bit member\n" unless @bits;
            my %idx; my $mask = 0;
            for (@bits) {
                my $i = 0; $i++ while (1 << $i) != $_->[1];
                ($id = $_->[0]) =~ s/^\Q$strip\E//;
                $idx{$_->[1]} = $id; $mask |= $_->[1];
                $_ = [$id, $i];
            }
            print "${name}Bit :: enum u32 {", join(", ", map { "$_->[0] = $_->[1]" } @bits), "}\n";
            print "$name :: bit_set[${name}Bit; u32]\n";
            for (@zero) { my $c = /_/ ? $_ : "$pre$_"; print "$c :: $name\{}\n" }
            for (@comp) {
                my ($id, $v) = @$_;
                $id = "$pre$id" unless $id =~ /_/;
                if (($v & ~$mask) == 0) {
                    print "$id :: $name\{", join(", ", map { ".$idx{$_}" } grep { $v & $_ } sort { $a <=> $b } keys %idx), "}\n";
                } else { print "$id :: transmute($name)u32($v)\n" }
            }
        } else { print }
        END { die "postprocess: flag enum(s) not found: " . join(" ", sort keys %want) . "\n" if %want; }
    ' "$file"
}

# rows_for <pkg>: the `scope|name|from|to` rows param_rules applies. `parameters: declared`
# types every procedure parameter ^T, including those of function-pointer types, which the
# `arrays:` list cannot name; a row here gives a callback-type parameter its previous type
# (`[^]T`, the real arrays among them) back. Scope is the callback type's name.
rows_for() {
    case $1 in
    adwaita)
        printf '%s\n' \
            "et_snap_points_func_ptr_anon_10|n_snap_points|^i32|[^]i32"
        ;;
    esac
}

# param_rules <file> <row>...: applies the rows; fails when one matched nothing, so a header
# bump that changes a declaration is noticed.
param_rules() {
    local file=$1
    shift
    [ $# -gt 0 ] || return 0
    RULES=$(printf '%s\n' "$@") perl -i -ne '
        BEGIN { @r = map { [split /\|/, $_, 4] } split /\n/, $ENV{RULES}; @hit = (0) x @r }
        for my $i (0..$#r) {
            my ($scope, $n, $from, $to) = @{$r[$i]};
            if (/^(?:    )?\Q$scope\E :: /) {
                $hit[$i]++ if s/\b\Q$n\E: \Q$from\E(?![\w.])/$n: $to/;
            }
        }
        print;
        END { my $bad = 0; for my $i (0..$#r) { next if $hit[$i]; print STDERR "postprocess: row matched nothing: @{$r[$i]}[0..3]\n"; $bad = 1 } exit $bad }
    ' "$file"
}

pkg=${1:?usage: postprocess.sh adwaita}
cd "$(dirname "$0")/.."
file="$pkg/$pkg.odin"
[ -f "$file" ] || { echo "postprocess: $file not found" >&2; exit 2; }

case "$pkg" in
adwaita)
    # `typedef struct _AdwFoo AdwFoo` comes out as `Foo :: _AdwFoo` plus `_AdwFoo :: ...`: the
    # alias is dropped and the struct renamed. Macros runic quotes as backtick strings become
    # Odin expressions: TYPE_FOO names foo_get_type, the version macros their numbers,
    # DURATION_INFINITE its value. VERSION is `(1.5.0)`, not an expression, and is dropped
    # (VERSION_S carries it). GApplication and GtkApplication both trim to Application, so
    # runic picks one at random per run; AdwApplication's parent, the parent class and
    # adw_application_window_new's argument are all GtkApplication, which is pinned here.
    sed -i "$file" \
        -e 's/\^glib\.char/cstring/g' \
        -e 's/\[\^\]glib\.char/cstring/g' \
        -e 's/\bgio\.Application\(Class\)\?\b/gtk.Application\1/g' \
        -e '/^[A-Z0-9_]* :: `(\?[a-z0-9_]* \?())\?`$/ {s/`(\?//; s/ \?())\?`//; s/ adw_/ /}' \
        -e 's/^DURATION_INFINITE :: .*/DURATION_INFINITE :: 0xffffffff/' \
        -e '/^VERSION :: /d' \
        -e '/^\(MAJOR_VERSION\|MINOR_VERSION\|MICRO_VERSION\|VERSION_[A-Z0-9_]*\) ::/ s/`//g' \
        -e 's#^\([a-zA-Z][a-zA-Z_0-9]*\)\s*::\s*_Adw\1$##' \
        -e 's#\b_Adw\([A-Z]\)#\1#g'
    cat -s "$file" >"$file.tmp"
    mv "$file.tmp" "$file"
    # shellcheck disable=SC2086
    bit_sets "$file" "" $adwaita_flags
    ;;
*)
    echo "postprocess: unknown package $pkg" >&2
    exit 2
    ;;
esac

mapfile -t rules < <(rows_for "$pkg")
param_rules "$file" "${rules[@]}"
