#+test
package adwaita

import "core:strings"
import "core:testing"

import glib "glib:glib"

// Version recorded in README.md: "**Bound version:** X.Y.Z".
README :: #load("../README.md", string)

bound_version :: proc() -> (major, minor, micro: int, ok: bool) {
    marker :: "**Bound version:** "
    readme := README
    i := strings.index(readme, marker)
    if i < 0 do return
    rest := readme[i + len(marker):]
    end := strings.index_any(rest, " \n")
    if end < 0 do return
    parts := strings.split(rest[:end], ".", context.temp_allocator)
    if len(parts) != 3 do return
    nums: [3]int
    for p, n in parts {
        v := 0
        if len(p) == 0 do return
        for c in p {
            if c < '0' || c > '9' do return
            v = v * 10 + int(c - '0')
        }
        nums[n] = v
    }
    return nums[0], nums[1], nums[2], true
}

@(test)
test_readme_version_matches_header_macros :: proc(t: ^testing.T) {
    major, minor, micro, ok := bound_version()
    testing.expect(t, ok, "README.md has no '**Bound version:** X.Y.Z'")
    testing.expect_value(t, major, MAJOR_VERSION)
    testing.expect_value(t, minor, MINOR_VERSION)
    testing.expect_value(t, micro, MICRO_VERSION)
    testing.expect_value(t, VERSION_S, "1.5.0")
}

@(test)
test_loaded_library_matches_bound_version :: proc(t: ^testing.T) {
    major, minor, micro, _ := bound_version()
    testing.expect_value(t, int(get_major_version()), major)
    testing.expect_value(t, int(get_minor_version()), minor)
    testing.expect_value(t, int(get_micro_version()), micro)
}

@(test)
test_breakpoint_condition_round_trip :: proc(t: ^testing.T) {
    cond := breakpoint_condition_parse("max-width: 400px")
    testing.expect(t, cond != nil, "breakpoint_condition_parse rejected 'max-width: 400px'")
    if cond == nil do return
    defer breakpoint_condition_free(cond)
    s := breakpoint_condition_to_string(cond)
    defer glib.free(rawptr(s))
    testing.expect_value(t, string(s), "max-width: 400px")
}

@(test)
test_animation_helpers :: proc(t: ^testing.T) {
    testing.expect_value(t, lerp(10, 20, 0.5), 15)
    testing.expect_value(t, easing_ease(.LINEAR, 0.25), 0.25)
    testing.expect_value(t, easing_ease(.EASE_IN_QUAD, 0.5), 0.25)
    testing.expect_value(t, DURATION_INFINITE, 0xffffffff)
}

@(test)
test_type_macros_are_get_type_procs :: proc(t: ^testing.T) {
    testing.expect(t, TYPE_DIALOG() != 0, "adw_dialog_get_type returned G_TYPE_INVALID")
    testing.expect(t, TYPE_ALERT_DIALOG() != TYPE_DIALOG(), "AdwAlertDialog and AdwDialog share a type")
}

// Flag enums are bit_sets of the C bits (docs/DECISIONS.md §7): the size is that of the C enum
// (4 bytes) and a member's index is the position of its bit in the header (adw-tab-view.h).

bits :: proc(s: $S) -> u32 {
    return transmute(u32)s
}

@(test)
test_flag_sets_are_the_size_of_the_c_enum :: proc(t: ^testing.T) {
    testing.expect_value(t, size_of(TabViewShortcuts), 4)
}

@(test)
test_flag_bits_match_the_header :: proc(t: ^testing.T) {
    testing.expect_value(t, bits(TabViewShortcuts{.TAB_VIEW_SHORTCUT_CONTROL_TAB}), 1 << 0)
    testing.expect_value(t, bits(TabViewShortcuts{.TAB_VIEW_SHORTCUT_CONTROL_SHIFT_TAB}), 1 << 1)
    testing.expect_value(t, bits(TabViewShortcuts{.TAB_VIEW_SHORTCUT_CONTROL_PAGE_UP}), 1 << 2)
    testing.expect_value(t, bits(TabViewShortcuts{.TAB_VIEW_SHORTCUT_CONTROL_PAGE_DOWN}), 1 << 3)
    testing.expect_value(t, bits(TabViewShortcuts{.TAB_VIEW_SHORTCUT_CONTROL_HOME}), 1 << 4)
    testing.expect_value(t, bits(TabViewShortcuts{.TAB_VIEW_SHORTCUT_CONTROL_END}), 1 << 5)
    testing.expect_value(t, bits(TabViewShortcuts{.TAB_VIEW_SHORTCUT_CONTROL_SHIFT_PAGE_UP}), 1 << 6)
    testing.expect_value(t, bits(TabViewShortcuts{.TAB_VIEW_SHORTCUT_CONTROL_SHIFT_PAGE_DOWN}), 1 << 7)
    testing.expect_value(t, bits(TabViewShortcuts{.TAB_VIEW_SHORTCUT_CONTROL_SHIFT_HOME}), 1 << 8)
    testing.expect_value(t, bits(TabViewShortcuts{.TAB_VIEW_SHORTCUT_CONTROL_SHIFT_END}), 1 << 9)
    testing.expect_value(t, bits(TabViewShortcuts{.TAB_VIEW_SHORTCUT_ALT_DIGITS}), 1 << 10)
    testing.expect_value(t, bits(TabViewShortcuts{.TAB_VIEW_SHORTCUT_ALT_ZERO}), 1 << 11)
}

@(test)
test_zero_members_are_the_empty_set :: proc(t: ^testing.T) {
    testing.expect_value(t, TAB_VIEW_SHORTCUT_NONE, TabViewShortcuts{})
}

@(test)
test_composite_masks_are_sets :: proc(t: ^testing.T) {
    testing.expect_value(t, bits(TAB_VIEW_SHORTCUT_ALL_SHORTCUTS), 0xfff)
}
